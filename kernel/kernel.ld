OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  ram (wxa) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
  .text : {
    *(.text.init)
    *(.text.trampoline)
    *(.text)
  } > ram

  .rodata : {
    *(.rodata)
  } > ram

  .data : {
    *(.data)
  } > ram

  .bss (NOLOAD) : {
    __bss_start = .;
    *(.bss)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > ram

  .stack : {
    . = ALIGN(16);
    __stack_limit = .;
    . += 4K;
    __stack_top = .;
  } > ram

  . = ALIGN(4K);
  PROVIDE(__kernel_end = .);
}
