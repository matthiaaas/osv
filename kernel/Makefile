LIBGCC=/opt/homebrew/Cellar/riscv-gnu-toolchain/main/lib/gcc/riscv64-unknown-elf/15.1.0/rv32i/ilp32/libgcc.a

CC = riscv64-unknown-elf-gcc
CFLAGS = \
	-march=rv32i_zicsr \
	-mabi=ilp32 \
	-Os \
	-T kernel.ld \
	-ffreestanding \
	-nostdlib \
	-fno-builtin \
	-Wno-int-to-pointer-cast \
	-Wno-pointer-to-int-cast

V ?= ../v/v
VFLAGS = \
	-arch rv32 \
	-m32 \
	-freestanding \
	-bare-builtin-dir bare \
	-nofloat \
	-gc none \
	-cc $(CC) \
	-d no_backtrace \
	-d no_bool \
	-d no_main
# VFLAGS = -arch rv32 \
# 	-m32 \
# 	-freestanding \
# 	-bare-builtin-dir \
# 	-d no_main \
# 	-d no_bool \
# 	-gc none \
# 	-cc $(CC)
# VFLAGS = \
# 	-arch rv32 \
# 	-m32 \
# 	-os vinix \
#     -enable-globals \
#     -nofloat \
#     -manualfree \
#     -experimental \
#     -message-limit 10000 \
#     -gc none \
#     -d no_backtrace \
# 	-d no_bool \
# 	-d no_main
VSOURCES := $(wildcard *.v)

ASM = nasm

READELF = riscv64-unknown-elf-readelf
OBJDUMP = riscv64-unknown-elf-objdump
HEXDUMP = hexdump

BUILD_DIR = target

SED = sed

all: $(BUILD_DIR)/kernel.elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/kernel.c: $(VSOURCES) | $(BUILD_DIR)
	$(V) $(VFLAGS) -o $@ .

$(BUILD_DIR)/kernel.fixed.c: $(BUILD_DIR)/kernel.c | $(BUILD_DIR)
		$(SED) '/typedef.*size_t;/d' $< > $@

$(BUILD_DIR)/kernel.elf: start.s kernel.ld $(BUILD_DIR)/kernel.fixed.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) \
		-o $@ \
		start.s $(BUILD_DIR)/kernel.fixed.c $(LIBGCC)

readelf: $(BUILD_DIR)/kernel.elf
	$(READELF) -a $<

objdump: $(BUILD_DIR)/kernel.elf
	$(OBJDUMP) -d $<

hexdump: $(BUILD_DIR)/kernel.elf
	$(HEXDUMP) -C $<

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all readelf objdump hexdump clean
