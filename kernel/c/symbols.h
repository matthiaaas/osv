#ifndef SYMBOLS_H
#define SYMBOLS_H

extern char __kernel_end[];

extern char __kernel_tmp_heap_start[];
extern char __kernel_tmp_heap_end[];

extern void trap_return(void *, unsigned int);

#endif // SYMBOLS_H
