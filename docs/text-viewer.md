# Text Viewer

Displays `.txt` files on the 480x800 e-ink display with word wrapping, scrolling, and Unicode support.

## Font System

Two rendering paths depending on whether `font.bin` is present on the SD card.

### Bitmap Font (font.bin)

Place a **Xteink X4 format** bitmap font at the SD card root as `font.bin`.

File format:
- Headerless raw bitmap array
- 65,536 glyphs covering the Unicode BMP (U+0000-U+FFFF)
- Glyph for code point N at byte offset `N * bytesPerGlyph`
- Each row stored MSB-first, `ceil(width/8)` bytes per row

Glyph dimensions are **auto-detected from file size**:

```
bytesPerGlyph = fileSize / 65536
```

The loader tries `rowBytes` from 1 to 8 and picks the first
`(width = rowBytes*8, height = bytesPerGlyph/rowBytes)` pair
where the aspect ratio (w/h) falls between 0.5 and 0.9.

Examples:

| Font file size | bytesPerGlyph | Detected size |
|----------------|---------------|---------------|
| 12,058,624     | 184           | 32x46         |
| 3,145,728      | 48            | 16x24         |
| 6,291,456      | 96            | 16x48         |

### ASCII Fallback

When `font.bin` is absent or invalid, falls back to the built-in 8x16
bitmap font (95 ASCII glyphs, 0x20-0x7E) rendered at 2x scale (16x32 pixels).
Non-ASCII characters display as tofu (empty rectangle).

## Layout

Layout parameters adapt to the active font:

| Parameter       | ASCII (fallback)   | 32x46 font       | Formula                              |
|-----------------|--------------------|-------------------|--------------------------------------|
| Char width      | 16px               | 32px              | `glyphWidth`                         |
| Char height     | 32px               | 46px              | `glyphHeight`                        |
| Line height     | 34px               | 48px              | `glyphHeight + 2`                    |
| Chars per line  | 29                 | 14                | `(480 - 16) / charWidth`             |
| Lines per page  | 22                 | 15                | `(800 - 50) / lineHeight`            |

Fixed layout:
- Header: 48px (filename + battery indicator)
- Separator: 2px
- Content top: 50px
- Left/right margin: 8px each
- Scrollbar: 6px wide on right edge

## Streaming Architecture

The text viewer uses a **ring buffer** design to support arbitrarily large files
with fixed memory (~7 KB):

**Ring buffer line index:**
A 256-entry ring buffer holds `(fileOffset: Int32, byteLength: Int16)` pairs for
word-wrapped lines around the current scroll position. As the user scrolls,
old entries are overwritten and new ones are computed on demand.

**Forward scrolling** appends new lines to the ring without resetting it
(`scanLines(resetRing: false)`). Old lines at the head are naturally evicted
as the ring wraps. This keeps recently viewed lines accessible for small
backward movements.

**Backward scrolling** past the ring triggers a re-scan from the nearest
checkpoint (`scanLines(resetRing: true)` replaces the ring contents).

**Checkpoints:**
Every 256 lines, a `(fileOffset, lineIndex)` checkpoint is recorded (up to 64).
When scrolling backward past the ring, the nearest checkpoint is used as a
starting point for re-scanning — at most 256 lines of word-wrap computation
(~50 ms, well under the e-ink refresh time).

**On-demand rendering (at draw time):**
`readVisibleLines()` reads only the bytes needed for the currently visible page
(typically < 2 KB) from the SD card into the shared IO buffer, then renders from
that buffer.

A cluster map is built once at load time via `FATFileSystem.buildClusterMap()`,
enabling O(1) random access to any file offset.

## Word Wrapping

`scanLines()` scans the file in 4 KB chunks from a given offset and builds
line entries in the ring buffer. The algorithm:

1. Decode UTF-8 characters one at a time via `UTF8Decoder`
2. Count characters (not bytes) against `effectiveCharsPerLine`
3. On reaching the line width limit:
   - If a space was seen: break at the last space (word wrap)
   - Otherwise: hard break at the current position (CJK-friendly)
4. Handle LF, CR, and CRLF line endings
5. Handle UTF-8 sequences and CRLF pairs that straddle chunk boundaries

Line offsets and lengths are stored as **file byte offsets** (Int32 and Int16
respectively). Characters are re-decoded from the SD card during rendering.

## Glyph Cache

`BitmapFont` maintains a 128-slot LRU cache to avoid repeated SD card reads.
Memory is allocated **lazily** in `load()` — when no `font.bin` is present,
zero heap is consumed.

| Component       | Size (32x46 font) |
|-----------------|--------------------|
| Glyph data      | 128 x 184 = 23KB   |
| Code points     | 128 x 4 = 512B     |
| Age counters    | 128 x 4 = 512B     |
| Cluster map     | 4096 x 4 = 16KB    |
| **Total**       | **~40KB**           |

Cache slots are allocated at the actual `bytesPerGlyph` determined during
font loading, keeping memory usage proportional to glyph size.

On cache miss, the LRU (lowest age counter) slot is evicted and the new glyph
is read from SD via `FATFileSystem.readBytes()` using the pre-built cluster map.
Common characters (particles, punctuation) stay cached across page turns.

## UTF-8 Decoder

`UTF8Decoder.decode()` is a stateless single-codepoint decoder:

- 1-byte sequences (ASCII): U+0000-U+007F
- 2-byte: U+0080-U+07FF
- 3-byte: U+0800-U+FFFF (CJK, kana, etc.)
- 4-byte: U+10000-U+10FFFF (emoji, etc. — beyond BMP, rendered as tofu)
- Invalid/overlong sequences: U+FFFD, consume 1 byte

## Resume

Reading position is automatically saved to `READHIST.DAT` on the SD card root
(8.3 FAT name, 1024 bytes = 16 entries × 64 bytes each, 2 SD sectors).

`READHIST.DAT` is the TextViewer's *per-file* scroll history (LRU cache of
the last 16 files). It is independent from the device-wide deep-sleep
snapshot in `RESUME.DAT` (see `docs/sleep.md`). After a deep-sleep wake,
`Application.main()` first uses `RESUME.DAT` to figure out *which* file to
re-open, then `TextViewer.loadFile()` consults `READHIST.DAT` to figure out
*where in that file* to scroll to. Both files are written by `enterSleep()`
before deep-sleep entry.

**Save triggers:**
- Back button (returning to file browser)
- Power button (entering sleep)
- Every 60 seconds while reading (skipped if position unchanged)

**Entry format (64 bytes, little-endian):**

| Offset | Size | Field |
|--------|------|-------|
| 0      | 4    | File start cluster (identifies the file) |
| 4      | 4    | File size (secondary validation) |
| 8      | 4    | scrollLine (Int32) |
| 12     | 4    | scrollOffset (Int32 — file byte offset of scrollLine, sanity-check field) |
| 16     | 8    | checkpoint[0] = (fileOffset: Int32, lineIndex: Int32) |
| 24     | 8    | checkpoint[1] |
| 32     | 8    | checkpoint[2] |
| 40     | 8    | checkpoint[3] |
| 48     | 8    | checkpoint[4] |
| 56     | 8    | checkpoint[5] |

The 6 checkpoint slots hold the **most recent** entries from the in-memory
checkpoint array (which records one entry every 256 lines). Unused slots are
all-zero; `lineIndex == 0` is the sentinel for "empty" because line 0 is
never recorded as a checkpoint.

On save, `saveResumeState()` reads the existing file (if any), updates or
allocates a slot for the current `(fileCluster)`, zeroes that slot to wipe
stale checkpoints, and writes the header + the tail `min(checkpointCount, 6)`
checkpoints. Stale data in unused slots is preserved so other files'
positions are not lost.

On `loadFile()`, the viewer searches `READHIST.DAT` for a matching
`(cluster, fileSize)` entry. If found, it:

1. Restores the persisted checkpoints into the in-memory `_checkpoints`
   array.
2. Calls `findCheckpointBefore(scrollLine)` to locate the nearest
   checkpoint at or before the saved scroll line.
3. Calls `scanLines(fromOffset: cpOffset, startLine: cpLine, ...)` to
   scan **forward only from that checkpoint** — typically ~37 lines for
   a mid-file resume — instead of rescanning the whole file from offset 0.

This is the key reason `loadFile()` for a resume is fast (~35 ms even for
files with thousands of lines): the bulk of the work is reduced from
"scan everything up to scrollLine" to "scan one checkpoint interval".

`addCheckpoint()` deduplicates against the most recent in-memory entry, so
the first emitted line after resuming a scan from a checkpoint boundary
does not insert a duplicate.

If the file has been modified (different size), the stale entry is ignored.

Up to 16 files' positions are remembered. When all slots are full, the last
slot is overwritten.

## File Limits

- No file size limit (streamed from SD card, never loaded entirely into memory)
- No line count limit (ring buffer holds 256 lines at a time; checkpoints enable navigation)
- Cluster map supports files up to ~1 MB (256 clusters × 4 KB)

### Memory Usage

All buffers except `nameBuffer` are **lazily allocated** on `loadFile()` and
**deallocated** via `releaseBuffers()` when the user leaves the text viewer.
This frees ~7 KB of heap for other uses (e.g. image decoding).

| Component       | Size            | Lifetime          |
|-----------------|-----------------|-------------------|
| IO buffer       | 4 KB            | loadFile → back   |
| Cluster map     | 1 KB            | loadFile → back   |
| Ring offsets    | 256 × 4 = 1 KB | loadFile → back   |
| Ring lengths    | 256 × 2 = 512 B| loadFile → back   |
| Checkpoints     | 64 × 8 = 512 B | loadFile → back   |
| Name buffer     | 64 B            | always            |
| **Total (active)** | **~7.2 KB** |                   |
| **Total (idle)**   | **64 B**    |                   |

## Navigation

| Button | Action     |
|--------|------------|
| Up     | Scroll up 1 line |
| Down   | Scroll down 1 line |
| Left   | Page up    |
| Right  | Page down  |
| Back   | Save position & return to file browser |

## Scrollbar

The scrollbar uses **byte-position approximation** since the total line count
is not known until EOF is reached:

```
thumbPosition = currentFileOffset / totalFileSize
```

This gives a proportional indicator that is accurate for uniformly distributed
text. Scrollbar appears whenever the file has more content than one page or
the end has not been scanned yet.

## Source Files

| File | Role |
|------|------|
| `Sources/Application/UI/TextViewer.swift` | Ring buffer, scanning, navigation, resume, rendering |
| `Sources/Application/UI/BitmapFont.swift` | Font loading, glyph cache, size detection |
| `Sources/Application/UI/UTF8Decoder.swift` | UTF-8 to Unicode code point decoder |
| `Sources/Application/UI/FontData.swift` | Built-in 8x16 ASCII font bitmap |
| `Sources/Application/Drivers/Framebuffer.swift` | `drawGlyph()`, `drawChar()`, pixel operations |
| `Sources/Application/Drivers/FATFileSystem.swift` | `findFile()`, `readBytes()`, `writeFile()` for resume |
