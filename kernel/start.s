.section .text.init
.global _start

_start:
    la sp, __stack_top

    la t0, __bss_start
    la t1, __bss_end
bss_clear:
    beq t0, t1, bss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j bss_clear
bss_done:

    la t0, trap_vector
    csrw mtvec, t0

    tail kmain

spin:
    j spin
