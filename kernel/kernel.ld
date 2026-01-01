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
    *(.text)
  } > ram

  .rodata : {
    *(.rodata)
  } > ram

  .data : {
    *(.data)
  } > ram

  .bss : {
    *(.bss)
  } > ram

  .stack : {
    . = ALIGN(16);
    __stack_limit = .;
    . += 4K;
    _stack_top = .;
  } > ram

  . = ALIGN(4K);
  PROVIDE(_end = .);
}
