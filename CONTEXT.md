# OSV — RISC-V Emulator + Bare Metal Kernel

Educational bare-metal OS project. Custom RISC-V emulator (Rust) runs a kernel (V language, cross-compiled to RV32I). The goal is not production-grade, but to implement classical OS concepts in a functional, extendable skeleton.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Rust Emulator (riscv/)                             │
│  ┌───────────────────────────────────────────────┐  │
│  │ Cpu { pc, next_pc, reg_file, csr_file, bus }  │  │
│  │   step() → fetch → execute → handle_trap      │  │
│  │   translate(vaddr) → Sv32 two-level walk       │  │
│  └────────────────┬──────────────────────────────┘  │
│                   │ load/store                      │
│  ┌────────────────▼──────────────────────────────┐  │
│  │ Bus { mappings: Vec<MappedDevice> }           │  │
│  │   probe(addr) → route to device by range      │  │
│  │   ┌──────────────┐  ┌────────────────────┐    │  │
│  │   │ DRAM         │  │ UART               │    │  │
│  │   │ 0x8000_0000  │  │ 0x1000_0000        │    │  │
│  │   │ 1MB Vec<u8>  │  │ store → stdout     │    │  │
│  │   └──────────────┘  └────────────────────┘    │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  Loads kernel ELF → flashes PT_LOAD segments to RAM │
│  Reset vector: 0x8000_0000 (Machine mode)           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  V Kernel (kernel/)                                 │
│  Compiled: V → C → riscv64-unknown-elf-gcc (RV32I) │
│  Linker script: RAM at 0x8000_0000, 1MB             │
│  Sections: .text.init, .text.trampoline, .text,     │
│            .rodata, .data, .bss, .stack (4K)        │
│  Symbol: __kernel_end marks heap/free-page start    │
└─────────────────────────────────────────────────────┘
```

---

## Emulator (Rust)

### Bus & Device Trait

```rust
// Any memory-mapped peripheral implements Device
pub trait Device {
    fn load(&mut self, addr: u32, size: u8) -> Result<u32, BusError>;
    fn store(&mut self, addr: u32, size: u8, val: u32) -> Result<(), BusError>;
    fn size(&self) -> u32;
}

pub struct Bus { mappings: Vec<MappedDevice> }
// probe(addr) finds which device owns an address range

// DRAM: Vec<u8>, supports 1/2/4-byte LE load/store
// UART: store prints char to host stdout, load returns 0
```

### CPU Core

```rust
pub struct Cpu {
    pub pc: u32,
    pub next_pc: u32,
    pub reg_file: RegFile,   // 32 x u32, x0 hardwired to 0
    pub csr_file: CsrFile,   // mstatus, mepc, mcause, mtval, mtvec, mscratch, satp, ...
    pub bus: Bus,
    pub priv_mode: PrivilegeMode,  // Machine | User (Supervisor defined but unused)
}

impl Cpu {
    // Main loop: step() called in infinite loop
    pub fn step(&mut self) {
        if let Err(trap) = self.try_step() {
            self.handle_trap(trap);
        } else {
            self.csr_file.increment_instret();
        }
        self.pc = self.next_pc;
        self.csr_file.increment_cycle();
    }

    fn try_step(&mut self) -> Result<(), Trap> {
        let instr = self.fetch()?;           // translate(pc) → bus.load
        self.next_pc = self.pc + 4;
        self.execute(instr)?;                // dispatch by opcode
        Ok(())
    }

    fn handle_trap(&mut self, trap: Trap) {
        self.csr_file.set_exception_pc(self.pc);    // mepc = pc
        self.csr_file.set_cause(trap.cause_code()); // mcause
        self.csr_file.set_mtval(trap.value());      // mtval
        self.csr_file.enter_exception_mode(self.priv_mode); // save MIE→MPIE, MPP
        self.priv_mode = PrivilegeMode::Machine;
        self.next_pc = self.csr_file.get_mtvec();   // jump to trap vector
    }
}
```

### Instruction Decoding & Execution

```rust
// Instr is a transparent u32 wrapper with field extractors
pub struct Instr(u32);
// Format types: IType, RType, UType, JType, SType, BType — each extracts rd, rs1, rs2, imm

// Opcode dispatch in execute():
match instr.opcode() {
    OP_IMM  => rv32i::exec_op_imm,   // ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
    OP_REG  => rv32i::exec_op_reg,   // ADD, SUB, SRL, XOR, OR, AND, SLTU
    LUI     => rv32i::exec_lui,      // rd = imm << 12
    AUIPC   => rv32i::exec_auipc,    // rd = pc + (imm << 12)
    JAL     => rv32i::exec_jal,      // rd = pc+4; pc += imm
    JALR    => rv32i::exec_jalr,     // rd = pc+4; pc = (rs1+imm) & ~1
    BRANCH  => rv32i::exec_branch,   // BEQ, BNE, BLT, BGE, BLTU, BGEU
    LOAD    => rv32i::exec_load,     // LB, LH, LW, LBU (translate addr, bus.load)
    STORE   => rv32i::exec_store,    // SB, SH, SW (translate addr, bus.store)
    SYSTEM  => privileged | zicsr,
}

// Privileged instructions:
//   ECALL → Trap::EnvironmentCall(current_priv_mode)
//   MRET  → restore MPP→priv_mode, MPIE→MIE, pc=mepc

// Zicsr instructions: CSRRW, CSRRS, CSRRC
//   read old CSR → write new → store old to rd
```

### Address Translation (Sv32)

```rust
// Triggered on every fetch/load/store
pub fn translate(&mut self, virt_addr: u32) -> Result<u32, Trap> {
    let satp = self.csr_file.get_satp();
    if satp & 0x8000_0000 == 0 { return Ok(virt_addr); } // paging disabled

    // Sv32: two-level page table walk
    let root_ppn = satp & 0x003f_ffff;
    let root_pt_addr = root_ppn << 12;

    // Level 1: VPN[1] = vaddr[31:22]
    let vpn1 = (virt_addr >> 22) & 0x3ff;
    let pte1 = bus.load(root_pt_addr + vpn1 * 4, 4)?;
    let pt0_addr = ((pte1 >> 10) & 0x003f_ffff) << 12;

    // Level 0: VPN[0] = vaddr[21:12]
    let vpn0 = (virt_addr >> 12) & 0x3ff;
    let pte0 = bus.load(pt0_addr + vpn0 * 4, 4)?;
    let final_ppn = ((pte0 >> 10) & 0x003f_ffff) << 12;

    Ok(final_ppn | (virt_addr & 0xfff))  // phys = PPN | offset
}
```

### Trap Types

```rust
pub enum Trap {
    IllegalInstruction(Instr),     // cause 2
    LoadAccessFault(u32),          // cause 5
    StoreAccessFault(u32),         // cause 7
    EnvironmentCall(PrivilegeMode), // cause 8 (U-mode), 11 (M-mode)
}
```

### CSR File

```rust
pub struct CsrFile {
    mstatus: u32,    // MIE, MPIE, MPP bits
    mtvec: u32,      // trap vector base address
    mepc: u32,       // exception PC (saved on trap)
    mcause: u32,     // trap cause code
    mtval: u32,      // trap value (faulting addr or instr)
    mscratch: u32,   // scratch register (kernel uses for stack pointer swap)
    satp: u32,       // bit 31 = enable paging; bits [21:0] = root page table PPN
    mie: u32, mip: u32, misa: u32,
    mcycle: u64, minstret: u64,
}

// enter_exception_mode: MPIE=MIE, MIE=0, MPP=prev_priv
// return_from_exception_mode (MRET): MIE=MPIE, clear MPIE & MPP
```

---

## Kernel (V Language)

### Build Pipeline

```
V source → V compiler (-freestanding, -arch rv32, -bare-builtin-dir bare)
         → C output → riscv64-unknown-elf-gcc (-march=rv32i_zicsr, -ffreestanding, -nostdlib)
         → linked with start.s, trampoline.s, kernel.ld → kernel.elf
```

### Boot Sequence (start.s)

```asm
_start:
    la sp, __stack_top      # initial stack from linker script (4K)
    la t0, trap_vector
    csrw mtvec, t0          # install trap handler
    tail kmain              # jump to V kernel entry
```

### Kernel Entry (kernel.v)

```v
fn kmain() {
    Uart.puts("Hello, World\n")

    kmem.init()                         // build physical page free list

    kernel_pagetable = Pagetable.new()  // allocate root page table
    map_kernel(kernel_pagetable)        // identity-map kernel RAM + UART MMIO
    w_satp(1 << 31 | pagetable.to_ppn()) // enable Sv32 paging

    stack_page := kmem.alloc()          // allocate dedicated kernel stack
    w_mscratch(kernel_stack_top)        // store in mscratch for trap handler
    call_with_stack(kernel_stack_top, kernel_main) // switch stack, enter kernel_main
}

fn kernel_main() {
    proc0 := Process.new(pid: 1)        // allocate process (kernel stack + trapframe page)

    // Write raw RISC-V user program into allocated page:
    //   li a0, 0; ecall; ecall; ecall; ecall; j .
    user_code := kmem.alloc()
    user_stack := kmem.alloc()

    // Create process page table: kernel mappings + user code/stack pages with PTE_U
    proc0.pagetable = Pagetable.new()
    map_kernel(proc0.pagetable)
    proc0.pagetable.map_pages(0x0000, page_size, user_code, pte_r | pte_x | pte_u)
    proc0.pagetable.map_pages(0x1000, page_size, user_stack, pte_r | pte_w | pte_u)

    proc0.trapframe.epc = 0x0000          // user entry point
    proc0.trapframe.sp  = 0x1000 + 4096   // user stack top

    w_mscratch(proc0.kernel_sp)           // kernel stack for trap reentry
    w_satp(1 << 31 | proc0.pagetable.to_ppn())  // switch to process page table
    trap_return(proc0.trapframe)          // drop to user mode
}

fn map_kernel(pagetable Pagetable) {
    pagetable.map_pages(0x8000_0000, 1MB, 0x8000_0000, pte_r | pte_w | pte_x)  // kernel code+data
    pagetable.map_pages(0x1000_0000, 4K,  0x1000_0000, pte_r | pte_w)           // UART MMIO
}
```

### Trap Handling

```asm
# trampoline.s — trap_vector (set as mtvec)
trap_vector:
    csrrw sp, mscratch, sp   # swap sp ↔ mscratch (user sp saved, kernel sp loaded)
    addi sp, sp, -128        # allocate TrapFrame on kernel stack
    # save all 31 GPRs + mepc into TrapFrame struct at sp
    mv a0, sp                # pass &TrapFrame as argument
    call trap_handler        # → V function
    # restore all GPRs + mepc from TrapFrame
    csrrw sp, mscratch, sp   # swap back to user sp
    mret                     # return to mepc in previous privilege mode
```

```v
// trap.v
pub struct TrapFrame {
    ra, sp, gp, tp u32
    t0..t6, s0..s11, a0..a7 u32
    epc u32                    // saved mepc
}

fn trap_handler(mut trapframe TrapFrame) {
    mcause := r_mcause()
    match mcause {
        2 => Uart.puts("Illegal Instruction\n"); trapframe.epc += 4
        8 => Uart.puts("Environment Call (U)\n"); trapframe.epc += 4
        3 => Uart.puts("Breakpoint\n");           trapframe.epc += 4
        _ => Uart.puts("Unknown Exception\n")
    }
}

fn trap_return(mut trapframe TrapFrame) {
    // Set mstatus.MPP = User (00), set MPIE
    mstatus &= ~(3 << 11)   // clear MPP
    mstatus |= 1 << 7       // set MPIE
    w_mstatus(mstatus)
    w_mepc(trapframe.epc)
    mret()                   // enters user mode at epc
}
```

### Physical Memory Allocator

```v
// memory/physical.v — simple free-list page allocator
const phystop = 0x8000_0000 + 1MB

struct Run { next &Run }    // free page is reinterpreted as linked list node

pub struct Kmem { free_list &Run }

fn (mut self Kmem) init() {
    // add every 4K page from __kernel_end to phystop into free list
    for i := pgroundup(__kernel_end); i < phystop; i += page_size {
        self.kfree(i)
    }
}

fn (mut self Kmem) alloc() voidptr {
    // pop head of free list, zero the page, return it
    r := self.free_list
    self.free_list = r.next
    memset(r, 0, page_size)
    return r
}

fn (mut self Kmem) kfree(pa voidptr) {
    // push page onto free list head
    r := &Run(pa)
    r.next = self.free_list
    self.free_list = r
}
```

### Virtual Memory (Sv32 Page Tables)

```v
// memory/virtual.v — Sv32 two-level page table management
// PTE flags: V(valid), R(read), W(write), X(exec), U(user), G, A, D

pub type Pagetable = &u32         // pointer to 1024-entry array of PTEs
pub type PagetableEntry = &u32

fn (pagetable Pagetable) walk(vaddr VirtAddr, alloc bool) ?PagetableEntry {
    // Level 1: index by VPN[1] = vaddr[31:22]
    pte1 := &pt[vaddr.vpn1()]
    if pte1.is_valid() {
        pt0 = ppn_to_pa(pte1)    // follow to level-0 table
    } else if alloc {
        pt0 = kmem.alloc()        // allocate new level-0 table
        pte1.set(pa_to_ppn(pt0) | PTE_V)
    } else { return none }

    // Level 0: index by VPN[0] = vaddr[21:12]
    return &pt0[vaddr.vpn0()]
}

fn (pagetable Pagetable) map_pages(vaddr, size, paddr, perm u32) {
    // Walk page-by-page, set leaf PTE = pa_to_ppn(paddr) | perm | PTE_V
    for each page in range [vaddr, vaddr+size):
        pte := pagetable.walk(vaddr, alloc: true)
        pte.set(pa_to_ppn(paddr) | perm | PTE_V)
}

// PPN ↔ PA conversions:
fn pa_to_ppn(pa u32) u32 { (pa >> 12) << 10 }  // shift right 12, left 10 (PTE format)
fn ppn_to_pa(ppn u32) u32 { (ppn >> 10) << 12 } // inverse
```

### Process Structure

```v
pub enum ProcState { unused, running, sleeping, zombie }

pub struct Process {
    pid u32
    state ProcState
    pagetable Pagetable       // per-process page table (includes kernel mappings + user pages)
    trapframe &TrapFrame      // saved registers on trap entry
    kernel_sp voidptr         // top of per-process kernel stack
}

fn Process.new(pid u32) ?Process {
    stack_page := kmem.alloc()        // 4K kernel stack for this process
    trapframe_page := kmem.alloc()    // page to hold TrapFrame
    return Process{
        pid: pid,
        state: .unused,
        trapframe: &TrapFrame(trapframe_page),
        kernel_sp: stack_page + kstack_size,
    }
}
```

### Bare Builtins (kernel/bare/builtin.v)

Freestanding replacements for V's runtime: `malloc` (bump allocator from 0x8008_0000), `free` (no-op), `memset`, `memcpy`, `memmove`, `memcmp`, `strlen`, `bare_print` (MMIO UART), `bare_panic`, `exit` (spin loop).

### UART

```v
pub fn Uart.put(c u8) {
    volatile uart0_base := &int(0x1000_0000)
    *uart0_base = int(c)        // MMIO write → emulator UART device → host stdout
}
pub fn Uart.puts(s string) { for c in s { Uart.put(c) } }
```

### Inline Assembly (riscv/asm.v)

V's inline asm syntax for CSR access:

```v
fn w_satp(val u32)      { asm rv32 { csrw satp, val } }
fn w_mepc(val u32)      { asm rv32 { csrw mepc, val } }
fn w_mstatus(val u32)   { asm rv32 { csrw mstatus, val } }
fn w_mtvec(val u32)     { asm rv32 { csrw mtvec, val } }
fn w_mscratch(val u32)  { asm rv32 { csrw mscratch, val } }
fn r_mcause() u32       { asm rv32 { csrr ret, mcause } }
fn r_mstatus() u32      { asm rv32 { csrr ret, mstatus } }
fn mret()               { asm rv32 { mret } }
fn call_with_stack(sp voidptr, func fn()) { mv sp, new_sp; jalr zero, func, 0 }
```

---

## Memory Map

| Range       | Size | Device        |
| ----------- | ---- | ------------- |
| 0x1000_0000 | 4K   | UART (MMIO)   |
| 0x8000_0000 | 1MB  | DRAM (kernel) |

User virtual addresses (per-process):

| VA           | Mapping               |
| ------------ | --------------------- | --- | --- |
| 0x0000_0000  | User code (PTE_R      | X   | U)  |
| 0x0000_1000  | User stack (PTE_R     | W   | U)  |
| 0x1000_0000  | UART (kernel mapped)  |
| 0x8000_0000+ | Kernel (identity map) |

---

## Current Execution Flow

1. Emulator loads kernel.elf, flashes PT_LOAD into DRAM at offset 0
2. CPU starts at 0x8000_0000 in Machine mode → `_start`
3. `_start`: set stack, install `trap_vector` into mtvec, jump to `kmain`
4. `kmain`: init page allocator, create kernel page table, enable Sv32, switch to kernel stack
5. `kernel_main`: create process, write user program (ecall loop), set up user page table, `trap_return` to user mode
6. User executes ecall → trap_vector saves regs → `trap_handler` prints "Environment Call (U)" → advances epc+4 → mret back to user
7. Cycle repeats for remaining ecalls, then user hits infinite loop `j .`

---

## What Exists / What Doesn't

**Implemented:**

- RV32I instruction set (most instructions, some `todo!()` stubs: SLTIU, SLL, SLT, SRA)
- RV32M extension: stub file exists, not implemented
- Sv32 two-level page table (both emulator-side translation and kernel-side table construction)
- Physical page allocator (free-list, page-granularity)
- Trap entry/exit (full register save/restore, mscratch stack swap)
- Single process creation with user/kernel page table separation
- UART output (kernel → emulator → host stdout)
- CSR read/write (mstatus, mepc, mcause, mtval, mtvec, mscratch, satp, mie, mip, mcycle, minstret)
- Privilege mode transitions (Machine ↔ User via MRET/ECALL)
- ELF loading in emulator

**Not yet implemented:**

- Scheduler / multiple processes / context switching between processes
- Timer interrupts (no CLINT/MTIME device)
- Interrupt handling (only synchronous exceptions)
- System calls beyond bare ecall acknowledgment
- File system
- IPC mechanisms
- Threads
- Page fault handling / demand paging / page replacement
- Disk/block device
- User-space program loading (currently hand-assembled instructions)
- Process lifecycle (fork, exec, exit, wait)
- Supervisor mode (kernel runs in Machine mode)

---

## Extension Points

To extend this system, these are the natural next steps and where they plug in:

- **Timer interrupts**: Add CLINT device to bus (mtime/mtimecmp registers), handle interrupt bit in mcause in trap_handler
- **Scheduler**: Add process table, timer-driven preemption in trap_handler, context switch = save/restore TrapFrame + switch satp + mscratch
- **System calls**: Dispatch on a0/a7 in the ecall handler (mcause=8), implement write, exit, fork, exec
- **Block device**: Add Device impl to bus, add filesystem layer on top
- **Demand paging**: Handle page faults (mcause 12/13/15) in trap_handler, allocate + map pages on fault
- **User program loading**: Parse ELF in kernel, map segments into process page table
- **Threads**: Share pagetable between processes, separate kernel stacks and TrapFrames
- **IPC**: Shared memory pages (map same physical page in two processes) or kernel-buffered message passing
