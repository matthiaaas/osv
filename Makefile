CC = riscv64-unknown-elf-gcc
V = ./v/v
ASM=nasm

all: os

os:
	$(V) run ./riscv

# -d use_c_bool
os.c:
	$(V) \
		-arch rv32 \
		-freestanding \
		-no-std \
		-no-builtin \
		-m32 \
		-d no_main \
		-d no_bool \
		-gc none \
		-cc riscv64-unknown-elf-gcc \
		-o os.c \
		main.v

os.elf: os.c
	$(CC) \
	    -march=rv32i_zicsr \
	    -mabi=ilp32 \
	    -Os \
	    -ffreestanding \
	    -nostdlib \
		-fno-builtin \
	    -o os.elf \
	    os.c

.PHONY: os
