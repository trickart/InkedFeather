TOOLCHAINS := org.swift.630202603201a
TRIPLE := riscv32-none-none-eabi
ELF := .build/$(TRIPLE)/debug/Application
BIN := build/app.bin
BOOTLOADER_ELF := .build/$(TRIPLE)/debug/Bootloader
BOOTLOADER_BIN := build/bootloader.bin
PARTITION_BIN := build/partition-table.bin

# Add ld.lld from Swift toolchain to PATH
LLD_DIR := $(shell xcrun --toolchain $(TOOLCHAINS) -f ld.lld 2>/dev/null | xargs dirname)
export PATH := $(LLD_DIR):$(PATH)

.PHONY: build flash clean image_info partition-table bootloader reset generate-registers monitor bootlogo

SWIFT_RUN := TOOLCHAINS=$(TOOLCHAINS) swift

build:
	@mkdir -p build
	TOOLCHAINS=$(TOOLCHAINS) swift build --triple $(TRIPLE) --toolset toolset.json --product Application
	$(SWIFT_RUN) Tools/elf2image.swift \
		--flash_mode dio --flash_freq 80m --flash_size 16MB \
		-o $(BIN) $(ELF)

bootloader:
	@mkdir -p build
	TOOLCHAINS=$(TOOLCHAINS) swift build --triple $(TRIPLE) --toolset toolset-bootloader.json --product Bootloader
	$(SWIFT_RUN) Tools/elf2image.swift \
		--flash_mode dio --flash_freq 80m --flash_size 16MB \
		-o $(BOOTLOADER_BIN) $(BOOTLOADER_ELF)

partition-table:
	@mkdir -p build
	$(SWIFT_RUN) Tools/gen-partition-table.swift -o $(PARTITION_BIN)

flash: build bootloader partition-table
	$(SWIFT_RUN) Tools/write-flash.swift \
		-b 460800 \
		0x0     $(BOOTLOADER_BIN) \
		0x8000  $(PARTITION_BIN) \
		0x10000 $(BIN)

image_info: build
	$(SWIFT_RUN) Tools/image-info.swift $(BIN)

reset:
	$(SWIFT_RUN) Tools/reset.swift

generate-registers:
	$(SWIFT_RUN) Tools/generate-registers.swift Sources/Registers/esp32c3.svd Sources/Registers/ \
		--peripherals GPIO,UART0,SPI2,IO_MUX,SYSTEM,SYSTIMER,TIMG0,TIMG1,APB_SARADC,RTC_CNTL,USB_DEVICE,INTERRUPT_CORE0,EXTMEM,SPI0,SPI1

monitor:
	$(SWIFT_RUN) Tools/monitor.swift

bootlogo:
	$(SWIFT_RUN) Tools/convert-bootlogo.swift

clean:
	TOOLCHAINS=$(TOOLCHAINS) swift package clean
	rm -rf build
