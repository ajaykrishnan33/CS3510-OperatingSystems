# /* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>

#include <kern/picirq.h>


###################################################################
# exceptions/interrupts
###################################################################

/* TRAPHANDLER defines a globally-visible function for handling a trap.
 * It pushes a trap number onto the stack, then jumps to _alltraps.
 * Use TRAPHANDLER for traps where the CPU automatically pushes an error code.
 *
 * You shouldn't call a TRAPHANDLER function from C, but you may
 * need to _declare_ one in C (for instance, to get a function pointer
 * during IDT setup).  You can declare the function with
 *   void NAME();
 * where NAME is the argument passed to TRAPHANDLER.
 */
#define TRAPHANDLER(name, num)						\
	.globl name;		/* define global symbol for 'name' */	\
	.type name, @function;	/* symbol type is function */		\
	.align 2;		/* align function definition */		\
	name:			/* function starts here */		\
	pushl $(num);							\
	jmp _alltraps

/* Use TRAPHANDLER_NOEC for traps where the CPU doesn't push an error code.
 * It pushes a 0 in place of the error code, so the trap frame has the same
 * format in either case.
 */
#define TRAPHANDLER_NOEC(name, num)					\
	.globl name;							\
	.type name, @function;						\
	.align 2;							\
	name:								\
	pushl $0;							\
	pushl $(num);							\
	jmp _alltraps

.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */

TRAPHANDLER_NOEC(t_divide, 0);
TRAPHANDLER_NOEC(t_debug, 1);
TRAPHANDLER_NOEC(t_nmi, 2);
TRAPHANDLER_NOEC(t_brkpt, 3);
TRAPHANDLER_NOEC(t_oflow, 4);
TRAPHANDLER_NOEC(t_bound, 5);
TRAPHANDLER_NOEC(t_illop, 6);
TRAPHANDLER_NOEC(t_device, 7);

TRAPHANDLER(t_dblflt, 8);

TRAPHANDLER_NOEC(t_coproc, 9);  /*reserved*/

TRAPHANDLER(t_tss, 10);
TRAPHANDLER(t_segnp, 11);
TRAPHANDLER(t_stack, 12);
TRAPHANDLER(t_gpflt, 13);
TRAPHANDLER(t_pgflt, 14);

TRAPHANDLER_NOEC(t_res, 15);   /*reserved*/

TRAPHANDLER_NOEC(t_fperr, 16);

TRAPHANDLER(t_align, 17);

TRAPHANDLER_NOEC(t_mchk, 18);
TRAPHANDLER_NOEC(t_simderr, 19);

TRAPHANDLER_NOEC(t_syscall, 48);
TRAPHANDLER_NOEC(t_default, 500);

TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
/*
 * Lab 3: Your code here for _alltraps
 */

_alltraps:

 pushw $0x0;
 pushw %ds;
 pushw $0x0;
 pushw %es;
 pushal;
 movl $GD_KD, %ax;
 movl %ax, %ds ;
 movl %ax, %es ;
 pushl %esp;
 call trap;

