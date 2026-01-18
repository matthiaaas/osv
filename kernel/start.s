.section .text.init
.global _start

_start:
    la sp, __stack_top

    la t0, trap_vector
    csrw mtvec, t0

    tail kmain

spin:
    j spin
