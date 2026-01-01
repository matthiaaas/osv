CC = riscv64-unknown-elf-gcc
CFLAGS = -march=rv32i_zicsr \
	    -mabi=ilp32 \
	    -Os \
		-T kernel.ld \
	    -ffreestanding \
	    -nostdlib \
		-fno-builtin

V ?= ../v/v
VFLAGS = -arch rv32 \
	-no-std \
	-no-builtin \
	-m32 \
	-d no_main \
	-d no_bool \
	-gc none \
	-cc $(CC)

ASM = nasm

READELF = riscv64-unknown-elf-readelf
OBJDUMP = riscv64-unknown-elf-objdump
HEXDUMP = hexdump

BUILD_DIR = target

all: $(BUILD_DIR)/kernel.elf

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/kernel.c: kernel.v | $(BUILD_DIR)
	$(V) $(VFLAGS) -o $@ $<

$(BUILD_DIR)/trap.c: trap.v | $(BUILD_DIR)
	$(V) $(VFLAGS) -o $@ $<

$(BUILD_DIR)/kernel.elf: start.s kernel.ld $(BUILD_DIR)/kernel.c $(BUILD_DIR)/trap.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) \
		-o $@ \
		start.s $(BUILD_DIR)/kernel.c $(BUILD_DIR)/trap.c

readelf: $(BUILD_DIR)/kernel.elf
	$(READELF) -a $<

objdump: $(BUILD_DIR)/kernel.elf
	$(OBJDUMP) -d $<

hexdump: $(BUILD_DIR)/kernel.elf
	$(HEXDUMP) -C $<

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all readelf objdump hexdump clean
