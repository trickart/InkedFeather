# Image Decoding

Streaming image decoders for BMP, PNG, and JPEG. All decoders read from the FAT
filesystem via cluster-mapped random access and write directly to the 1-bit
e-ink framebuffer (480×800 portrait, 270° rotation).

## Architecture

```
SD Card (FAT) ──readBytes──► Decoder ──setPixel/write1bitRow──► Framebuffer (48KB)
                               │
                               ├─ BMPDecoder   (~10.5 KB)
                               ├─ PNGDecoder   (~54 KB)
                               └─ JPEGDecoder  (~45 KB)
```

All decoders share the same interface pattern:

1. `parseHeader()` — read file headers, build cluster map for random access
2. `decode()` — stream row-by-row into the framebuffer with centering

`ImageViewer` always owns a `BMPDecoder` instance. `PNGDecoder` and `JPEGDecoder`
are **lazily allocated** — their buffers (~103 KB combined) are only allocated
when a PNG or JPEG file is actually opened. When the user leaves the image viewer,
`releaseHeavyDecoders()` deallocates these buffers to free heap for other uses
(e.g. the text viewer's line index).

For sleep screen rendering, only `SLEEP.BMP` is supported. `Application` reuses
the `BMPDecoder` instance from `ImageViewer` and draws fullscreen (no header,
area = 480×800).

## Source Files

| File | Description |
|------|-------------|
| `Decoders/BMPDecoder.swift` | BMP decoder (1/4/8/24/32-bit) with 1-bit fast path |
| `Decoders/PNGDecoder.swift` | PNG decoder with built-in DEFLATE decompressor |
| `Decoders/JPEGDecoder.swift` | Baseline JPEG decoder (SOF0, MCU-row streaming) |
| `Decoders/ImageDither.swift` | 8×8 Bayer ordered dithering for grayscale → 1-bit |
| `UI/ImageViewer.swift` | Image viewer UI (format detection, header, layout) |

## Supported Formats

### BMP

| Feature | Support |
|---------|---------|
| Bit depths | 1, 4, 8, 24, 32 |
| Compression | BI_RGB (0), BI_BITFIELDS (3) |
| Row order | Top-down and bottom-up |
| Palette | Up to 256 entries (for ≤8-bit) |

Memory: 3,200 B row buffer + 4,096 B IO buffer + 4,096 B cluster map + 1,024 B palette ≈ **10.5 KB**.

### PNG

| Feature | Support |
|---------|---------|
| Color types | 0 (Gray), 2 (RGB), 3 (Palette), 4 (GrayAlpha), 6 (RGBA) |
| Bit depths | 1, 2, 4, 8 |
| Interlacing | None only (Adam7 not supported) |
| Compression | DEFLATE with 32 KB sliding window |

Memory: 32 KB DEFLATE window + 2 × 3,201 B row buffers + cluster map + IDAT map ≈ **54 KB**.

### JPEG

| Feature | Support |
|---------|---------|
| Encoding | Baseline (SOF0) only |
| Color spaces | Grayscale, YCbCr |
| Subsampling | 4:4:4, 4:2:2, 4:2:0 |
| Progressive | Not supported |

Memory: 4,096 B IO buffer + quantization/Huffman tables + MCU row buffer ≈ **45 KB**.

## Grayscale Conversion and Dithering

All multi-bit formats go through the same pixel pipeline:

```
Source pixel → RGB extraction → Grayscale → 8×8 Bayer dithering → 1-bit
```

- **RGB → Gray**: `Y = (R×77 + G×150 + B×29) >> 8` (integer-only BT.601 luminance)
- **Dithering**: 8×8 Bayer ordered dither (stateless, no row buffers needed).
  Pure black (0) and pure white (255) bypass the threshold comparison.

## 1-Bit BMP Fast Path

When `bitsPerPixel == 1`, the decoder bypasses the entire pixel pipeline
(palette lookup → RGB → grayscale → dithering → `setPixel`) and writes
packed bits directly to the framebuffer.

### Why it matters

On ESP32-C3, a 480×800 24-bit BMP takes ~8 seconds to decode. The dominant
costs are SD card I/O (1.15 MB read in 800 individual 1,440-byte row reads)
and per-pixel processing (384,000 × palette/RGB/gray/dither/setPixel).

A 1-bit BMP of the same dimensions is 48 KB — **24× smaller** — and the pixel
data is already in the framebuffer's native format (MSB-first packed bits).

### Optimizations

**1. Batch SD reads** — Instead of reading one 60-byte row at a time (800 SD
accesses), rows are batched into the existing 3,200-byte row buffer. At 53 rows
per batch (`3200 / 60`), only **16 SD accesses** are needed for 800 rows.

**2. Direct bit writes via `Framebuffer.write1bitRow()`** — Skips the per-pixel
`setPixel()` call (which includes coordinate mapping, bounds check, byte index
calculation, and bit masking per pixel). For rotated mode, the native byte
column and bit mask are constant across the entire row, so only the destination
byte index varies per pixel.

**3. Palette inversion detection** — Checks palette entry 0 once to determine
if source bits match framebuffer convention (0 = black). If inverted, each bit
is flipped during write. No per-pixel palette lookup.

### Measured Performance (ESP32-C3 @ 160 MHz, SD SPI ~10 MHz)

480×800 1-bit BMP (48 KB file) as sleep screen:

| Stage | Time |
|-------|------|
| `findSleepImage` (root dir scan) | 9 ms |
| `parseHeader` (header + cluster map) | 35 ms |
| `decode` (SD read + FB write) | 339 ms |
| `writeFramebuffer` (48 KB SPI to display) | 92 ms |
| `fullRefresh` (e-ink waveform) | 3,772 ms |
| **Total** | **4,247 ms** |

For comparison, the same image as 24-bit BMP (1.15 MB) took ~8,400 ms for
decode alone before the fast path was added.

### Sleep Screen Image Preparation

The sleep screen image is loaded from `SLEEP.BMP` in the SD card root directory.
Only BMP format is supported for sleep images to avoid allocating the heavy
PNG/JPEG decoders (~103 KB) during sleep entry.

For optimal performance, prepare a 1-bit BMP with ImageMagick:

```bash
magick input.png -colorspace Gray -ordered-dither o8x8 \
  -type bilevel BMP3:SLEEP.BMP
```

- `-colorspace Gray` — convert to grayscale
- `-ordered-dither o8x8` — 8×8 Bayer dithering (matches device dithering method)
- `-type bilevel` — **required** for actual 1-bit output (without this, ImageMagick
  may produce a 24-bit BMP with bilevel pixel values)
- `BMP3:` — BITMAPINFOHEADER format (V3), compatible with the decoder

The input image should be 480×800 pixels to match the display exactly.
If the image dimensions differ, the decoder centers it within the display area.
