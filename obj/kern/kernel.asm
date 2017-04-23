
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# sufficient until we set up our real page table in mem_init
	# in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we are still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 f0 11 f0       	mov    $0xf011f000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 6a 00 00 00       	call   f01000a8 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	56                   	push   %esi
f0100044:	53                   	push   %ebx
f0100045:	83 ec 10             	sub    $0x10,%esp
f0100048:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010004b:	83 3d 80 1e 23 f0 00 	cmpl   $0x0,0xf0231e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 1e 23 f0    	mov    %esi,0xf0231e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 15 68 00 00       	call   f0106879 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 60 6f 10 f0 	movl   $0xf0106f60,(%esp)
f010007d:	e8 b5 3e 00 00       	call   f0103f37 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 76 3e 00 00       	call   f0103f04 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 0d 81 10 f0 	movl   $0xf010810d,(%esp)
f0100095:	e8 9d 3e 00 00       	call   f0103f37 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 2c 09 00 00       	call   f01009d2 <monitor>
f01000a6:	eb f2                	jmp    f010009a <_panic+0x5a>

f01000a8 <i386_init>:
static void boot_aps(void);


void
i386_init(void)
{
f01000a8:	55                   	push   %ebp
f01000a9:	89 e5                	mov    %esp,%ebp
f01000ab:	53                   	push   %ebx
f01000ac:	83 ec 24             	sub    $0x24,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000af:	b8 08 30 27 f0       	mov    $0xf0273008,%eax
f01000b4:	2d e8 00 23 f0       	sub    $0xf02300e8,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 e8 00 23 f0 	movl   $0xf02300e8,(%esp)
f01000cc:	e8 56 61 00 00       	call   f0106227 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 e9 05 00 00       	call   f01006bf <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 cc 6f 10 f0 	movl   $0xf0106fcc,(%esp)
f01000e5:	e8 4d 3e 00 00       	call   f0103f37 <cprintf>

	unsigned int i = 0x0a646c72;
f01000ea:	c7 45 f4 72 6c 64 0a 	movl   $0xa646c72,-0xc(%ebp)
    cprintf("H%x Wo%s", 57616, &i);
f01000f1:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01000f4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000f8:	c7 44 24 04 10 e1 00 	movl   $0xe110,0x4(%esp)
f01000ff:	00 
f0100100:	c7 04 24 e7 6f 10 f0 	movl   $0xf0106fe7,(%esp)
f0100107:	e8 2b 3e 00 00       	call   f0103f37 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f010010c:	e8 6c 13 00 00       	call   f010147d <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f0100111:	e8 f6 35 00 00       	call   f010370c <env_init>
	trap_init();
f0100116:	e8 3d 3f 00 00       	call   f0104058 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f010011b:	90                   	nop
f010011c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100120:	e8 45 64 00 00       	call   f010656a <mp_init>
	lapic_init();
f0100125:	e8 6a 67 00 00       	call   f0106894 <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f010012a:	e8 38 3d 00 00       	call   f0103e67 <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010012f:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f0100136:	e8 bc 69 00 00       	call   f0106af7 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010013b:	83 3d 88 1e 23 f0 07 	cmpl   $0x7,0xf0231e88
f0100142:	77 24                	ja     f0100168 <i386_init+0xc0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100144:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f010014b:	00 
f010014c:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0100153:	f0 
f0100154:	c7 44 24 04 5a 00 00 	movl   $0x5a,0x4(%esp)
f010015b:	00 
f010015c:	c7 04 24 f0 6f 10 f0 	movl   $0xf0106ff0,(%esp)
f0100163:	e8 d8 fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct CpuInfo *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100168:	b8 a2 64 10 f0       	mov    $0xf01064a2,%eax
f010016d:	2d 28 64 10 f0       	sub    $0xf0106428,%eax
f0100172:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100176:	c7 44 24 04 28 64 10 	movl   $0xf0106428,0x4(%esp)
f010017d:	f0 
f010017e:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100185:	e8 ea 60 00 00       	call   f0106274 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f010018a:	bb 20 20 23 f0       	mov    $0xf0232020,%ebx
f010018f:	eb 4d                	jmp    f01001de <i386_init+0x136>
		if (c == cpus + cpunum())  // We've started already.
f0100191:	e8 e3 66 00 00       	call   f0106879 <cpunum>
f0100196:	6b c0 74             	imul   $0x74,%eax,%eax
f0100199:	05 20 20 23 f0       	add    $0xf0232020,%eax
f010019e:	39 c3                	cmp    %eax,%ebx
f01001a0:	74 39                	je     f01001db <i386_init+0x133>
f01001a2:	89 d8                	mov    %ebx,%eax
f01001a4:	2d 20 20 23 f0       	sub    $0xf0232020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f01001a9:	c1 f8 02             	sar    $0x2,%eax
f01001ac:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001b2:	c1 e0 0f             	shl    $0xf,%eax
f01001b5:	8d 80 00 b0 23 f0    	lea    -0xfdc5000(%eax),%eax
f01001bb:	a3 84 1e 23 f0       	mov    %eax,0xf0231e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001c0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001c7:	00 
f01001c8:	0f b6 03             	movzbl (%ebx),%eax
f01001cb:	89 04 24             	mov    %eax,(%esp)
f01001ce:	e8 11 68 00 00       	call   f01069e4 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001d3:	8b 43 04             	mov    0x4(%ebx),%eax
f01001d6:	83 f8 01             	cmp    $0x1,%eax
f01001d9:	75 f8                	jne    f01001d3 <i386_init+0x12b>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001db:	83 c3 74             	add    $0x74,%ebx
f01001de:	6b 05 c4 23 23 f0 74 	imul   $0x74,0xf02323c4,%eax
f01001e5:	05 20 20 23 f0       	add    $0xf0232020,%eax
f01001ea:	39 c3                	cmp    %eax,%ebx
f01001ec:	72 a3                	jb     f0100191 <i386_init+0xe9>
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	// ENV_CREATE(user_primes, ENV_TYPE_USER);
	ENV_CREATE(user_yield, ENV_TYPE_USER);
f01001ee:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01001f5:	00 
f01001f6:	c7 04 24 92 96 19 f0 	movl   $0xf0199692,(%esp)
f01001fd:	e8 08 37 00 00       	call   f010390a <env_create>
	ENV_CREATE(user_yield, ENV_TYPE_USER);
f0100202:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100209:	00 
f010020a:	c7 04 24 92 96 19 f0 	movl   $0xf0199692,(%esp)
f0100211:	e8 f4 36 00 00       	call   f010390a <env_create>
	ENV_CREATE(user_yield, ENV_TYPE_USER);
f0100216:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010021d:	00 
f010021e:	c7 04 24 92 96 19 f0 	movl   $0xf0199692,(%esp)
f0100225:	e8 e0 36 00 00       	call   f010390a <env_create>
	// ENV_CREATE(user_dumbfork, ENV_TYPE_USER);
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010022a:	e8 47 4c 00 00       	call   f0104e76 <sched_yield>

f010022f <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f010022f:	55                   	push   %ebp
f0100230:	89 e5                	mov    %esp,%ebp
f0100232:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f0100235:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010023a:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010023f:	77 20                	ja     f0100261 <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100241:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100245:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f010024c:	f0 
f010024d:	c7 44 24 04 71 00 00 	movl   $0x71,0x4(%esp)
f0100254:	00 
f0100255:	c7 04 24 f0 6f 10 f0 	movl   $0xf0106ff0,(%esp)
f010025c:	e8 df fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100261:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100266:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100269:	e8 0b 66 00 00       	call   f0106879 <cpunum>
f010026e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100272:	c7 04 24 fc 6f 10 f0 	movl   $0xf0106ffc,(%esp)
f0100279:	e8 b9 3c 00 00       	call   f0103f37 <cprintf>

	lapic_init();
f010027e:	e8 11 66 00 00       	call   f0106894 <lapic_init>
	env_init_percpu();
f0100283:	e8 5a 34 00 00       	call   f01036e2 <env_init_percpu>
	trap_init_percpu();
f0100288:	e8 d3 3c 00 00       	call   f0103f60 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f010028d:	8d 76 00             	lea    0x0(%esi),%esi
f0100290:	e8 e4 65 00 00       	call   f0106879 <cpunum>
f0100295:	6b d0 74             	imul   $0x74,%eax,%edx
f0100298:	81 c2 20 20 23 f0    	add    $0xf0232020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010029e:	b8 01 00 00 00       	mov    $0x1,%eax
f01002a3:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002a7:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f01002ae:	e8 44 68 00 00       	call   f0106af7 <spin_lock>
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();

	sched_yield();
f01002b3:	e8 be 4b 00 00       	call   f0104e76 <sched_yield>

f01002b8 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002b8:	55                   	push   %ebp
f01002b9:	89 e5                	mov    %esp,%ebp
f01002bb:	53                   	push   %ebx
f01002bc:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002bf:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002c2:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002c5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002c9:	8b 45 08             	mov    0x8(%ebp),%eax
f01002cc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002d0:	c7 04 24 12 70 10 f0 	movl   $0xf0107012,(%esp)
f01002d7:	e8 5b 3c 00 00       	call   f0103f37 <cprintf>
	vcprintf(fmt, ap);
f01002dc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002e0:	8b 45 10             	mov    0x10(%ebp),%eax
f01002e3:	89 04 24             	mov    %eax,(%esp)
f01002e6:	e8 19 3c 00 00       	call   f0103f04 <vcprintf>
	cprintf("\n");
f01002eb:	c7 04 24 0d 81 10 f0 	movl   $0xf010810d,(%esp)
f01002f2:	e8 40 3c 00 00       	call   f0103f37 <cprintf>
	va_end(ap);
}
f01002f7:	83 c4 14             	add    $0x14,%esp
f01002fa:	5b                   	pop    %ebx
f01002fb:	5d                   	pop    %ebp
f01002fc:	c3                   	ret    
f01002fd:	66 90                	xchg   %ax,%ax
f01002ff:	90                   	nop

f0100300 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100300:	55                   	push   %ebp
f0100301:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100303:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100308:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100309:	a8 01                	test   $0x1,%al
f010030b:	74 08                	je     f0100315 <serial_proc_data+0x15>
f010030d:	b2 f8                	mov    $0xf8,%dl
f010030f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100310:	0f b6 c0             	movzbl %al,%eax
f0100313:	eb 05                	jmp    f010031a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100315:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010031a:	5d                   	pop    %ebp
f010031b:	c3                   	ret    

f010031c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010031c:	55                   	push   %ebp
f010031d:	89 e5                	mov    %esp,%ebp
f010031f:	53                   	push   %ebx
f0100320:	83 ec 04             	sub    $0x4,%esp
f0100323:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100325:	eb 2a                	jmp    f0100351 <cons_intr+0x35>
		if (c == 0)
f0100327:	85 d2                	test   %edx,%edx
f0100329:	74 26                	je     f0100351 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010032b:	a1 24 12 23 f0       	mov    0xf0231224,%eax
f0100330:	8d 48 01             	lea    0x1(%eax),%ecx
f0100333:	89 0d 24 12 23 f0    	mov    %ecx,0xf0231224
f0100339:	88 90 20 10 23 f0    	mov    %dl,-0xfdcefe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010033f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100345:	75 0a                	jne    f0100351 <cons_intr+0x35>
			cons.wpos = 0;
f0100347:	c7 05 24 12 23 f0 00 	movl   $0x0,0xf0231224
f010034e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100351:	ff d3                	call   *%ebx
f0100353:	89 c2                	mov    %eax,%edx
f0100355:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100358:	75 cd                	jne    f0100327 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010035a:	83 c4 04             	add    $0x4,%esp
f010035d:	5b                   	pop    %ebx
f010035e:	5d                   	pop    %ebp
f010035f:	c3                   	ret    

f0100360 <kbd_proc_data>:
f0100360:	ba 64 00 00 00       	mov    $0x64,%edx
f0100365:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100366:	a8 01                	test   $0x1,%al
f0100368:	0f 84 ef 00 00 00    	je     f010045d <kbd_proc_data+0xfd>
f010036e:	b2 60                	mov    $0x60,%dl
f0100370:	ec                   	in     (%dx),%al
f0100371:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100373:	3c e0                	cmp    $0xe0,%al
f0100375:	75 0d                	jne    f0100384 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100377:	83 0d 00 10 23 f0 40 	orl    $0x40,0xf0231000
		return 0;
f010037e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100383:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100384:	55                   	push   %ebp
f0100385:	89 e5                	mov    %esp,%ebp
f0100387:	53                   	push   %ebx
f0100388:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010038b:	84 c0                	test   %al,%al
f010038d:	79 37                	jns    f01003c6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010038f:	8b 0d 00 10 23 f0    	mov    0xf0231000,%ecx
f0100395:	89 cb                	mov    %ecx,%ebx
f0100397:	83 e3 40             	and    $0x40,%ebx
f010039a:	83 e0 7f             	and    $0x7f,%eax
f010039d:	85 db                	test   %ebx,%ebx
f010039f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003a2:	0f b6 d2             	movzbl %dl,%edx
f01003a5:	0f b6 82 80 71 10 f0 	movzbl -0xfef8e80(%edx),%eax
f01003ac:	83 c8 40             	or     $0x40,%eax
f01003af:	0f b6 c0             	movzbl %al,%eax
f01003b2:	f7 d0                	not    %eax
f01003b4:	21 c1                	and    %eax,%ecx
f01003b6:	89 0d 00 10 23 f0    	mov    %ecx,0xf0231000
		return 0;
f01003bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003c1:	e9 9d 00 00 00       	jmp    f0100463 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003c6:	8b 0d 00 10 23 f0    	mov    0xf0231000,%ecx
f01003cc:	f6 c1 40             	test   $0x40,%cl
f01003cf:	74 0e                	je     f01003df <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003d1:	83 c8 80             	or     $0xffffff80,%eax
f01003d4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003d6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003d9:	89 0d 00 10 23 f0    	mov    %ecx,0xf0231000
	}

	shift |= shiftcode[data];
f01003df:	0f b6 d2             	movzbl %dl,%edx
f01003e2:	0f b6 82 80 71 10 f0 	movzbl -0xfef8e80(%edx),%eax
f01003e9:	0b 05 00 10 23 f0    	or     0xf0231000,%eax
	shift ^= togglecode[data];
f01003ef:	0f b6 8a 80 70 10 f0 	movzbl -0xfef8f80(%edx),%ecx
f01003f6:	31 c8                	xor    %ecx,%eax
f01003f8:	a3 00 10 23 f0       	mov    %eax,0xf0231000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003fd:	89 c1                	mov    %eax,%ecx
f01003ff:	83 e1 03             	and    $0x3,%ecx
f0100402:	8b 0c 8d 60 70 10 f0 	mov    -0xfef8fa0(,%ecx,4),%ecx
f0100409:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010040d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100410:	a8 08                	test   $0x8,%al
f0100412:	74 1b                	je     f010042f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100414:	89 da                	mov    %ebx,%edx
f0100416:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100419:	83 f9 19             	cmp    $0x19,%ecx
f010041c:	77 05                	ja     f0100423 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010041e:	83 eb 20             	sub    $0x20,%ebx
f0100421:	eb 0c                	jmp    f010042f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100423:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100426:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100429:	83 fa 19             	cmp    $0x19,%edx
f010042c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010042f:	f7 d0                	not    %eax
f0100431:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100433:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100435:	f6 c2 06             	test   $0x6,%dl
f0100438:	75 29                	jne    f0100463 <kbd_proc_data+0x103>
f010043a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100440:	75 21                	jne    f0100463 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100442:	c7 04 24 2c 70 10 f0 	movl   $0xf010702c,(%esp)
f0100449:	e8 e9 3a 00 00       	call   f0103f37 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010044e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100453:	b8 03 00 00 00       	mov    $0x3,%eax
f0100458:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100459:	89 d8                	mov    %ebx,%eax
f010045b:	eb 06                	jmp    f0100463 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010045d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100462:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100463:	83 c4 14             	add    $0x14,%esp
f0100466:	5b                   	pop    %ebx
f0100467:	5d                   	pop    %ebp
f0100468:	c3                   	ret    

f0100469 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100469:	55                   	push   %ebp
f010046a:	89 e5                	mov    %esp,%ebp
f010046c:	57                   	push   %edi
f010046d:	56                   	push   %esi
f010046e:	53                   	push   %ebx
f010046f:	83 ec 1c             	sub    $0x1c,%esp
f0100472:	89 c7                	mov    %eax,%edi
f0100474:	bb 01 32 00 00       	mov    $0x3201,%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100479:	be fd 03 00 00       	mov    $0x3fd,%esi
f010047e:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100483:	eb 06                	jmp    f010048b <cons_putc+0x22>
f0100485:	89 ca                	mov    %ecx,%edx
f0100487:	ec                   	in     (%dx),%al
f0100488:	ec                   	in     (%dx),%al
f0100489:	ec                   	in     (%dx),%al
f010048a:	ec                   	in     (%dx),%al
f010048b:	89 f2                	mov    %esi,%edx
f010048d:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;

	for (i = 0;
f010048e:	a8 20                	test   $0x20,%al
f0100490:	75 05                	jne    f0100497 <cons_putc+0x2e>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f0100492:	83 eb 01             	sub    $0x1,%ebx
f0100495:	75 ee                	jne    f0100485 <cons_putc+0x1c>
	     i++)
		delay();

	outb(COM1 + COM_TX, c);
f0100497:	89 f8                	mov    %edi,%eax
f0100499:	0f b6 c0             	movzbl %al,%eax
f010049c:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010049f:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004a4:	ee                   	out    %al,(%dx)
f01004a5:	bb 01 32 00 00       	mov    $0x3201,%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004aa:	be 79 03 00 00       	mov    $0x379,%esi
f01004af:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004b4:	eb 06                	jmp    f01004bc <cons_putc+0x53>
f01004b6:	89 ca                	mov    %ecx,%edx
f01004b8:	ec                   	in     (%dx),%al
f01004b9:	ec                   	in     (%dx),%al
f01004ba:	ec                   	in     (%dx),%al
f01004bb:	ec                   	in     (%dx),%al
f01004bc:	89 f2                	mov    %esi,%edx
f01004be:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004bf:	84 c0                	test   %al,%al
f01004c1:	78 05                	js     f01004c8 <cons_putc+0x5f>
f01004c3:	83 eb 01             	sub    $0x1,%ebx
f01004c6:	75 ee                	jne    f01004b6 <cons_putc+0x4d>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004c8:	ba 78 03 00 00       	mov    $0x378,%edx
f01004cd:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004d1:	ee                   	out    %al,(%dx)
f01004d2:	b2 7a                	mov    $0x7a,%dl
f01004d4:	b8 0d 00 00 00       	mov    $0xd,%eax
f01004d9:	ee                   	out    %al,(%dx)
f01004da:	b8 08 00 00 00       	mov    $0x8,%eax
f01004df:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f01004e0:	89 fa                	mov    %edi,%edx
f01004e2:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f01004e8:	89 f8                	mov    %edi,%eax
f01004ea:	80 cc 07             	or     $0x7,%ah
f01004ed:	85 d2                	test   %edx,%edx
f01004ef:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f01004f2:	89 f8                	mov    %edi,%eax
f01004f4:	0f b6 c0             	movzbl %al,%eax
f01004f7:	83 f8 09             	cmp    $0x9,%eax
f01004fa:	74 76                	je     f0100572 <cons_putc+0x109>
f01004fc:	83 f8 09             	cmp    $0x9,%eax
f01004ff:	7f 0a                	jg     f010050b <cons_putc+0xa2>
f0100501:	83 f8 08             	cmp    $0x8,%eax
f0100504:	74 16                	je     f010051c <cons_putc+0xb3>
f0100506:	e9 9b 00 00 00       	jmp    f01005a6 <cons_putc+0x13d>
f010050b:	83 f8 0a             	cmp    $0xa,%eax
f010050e:	66 90                	xchg   %ax,%ax
f0100510:	74 3a                	je     f010054c <cons_putc+0xe3>
f0100512:	83 f8 0d             	cmp    $0xd,%eax
f0100515:	74 3d                	je     f0100554 <cons_putc+0xeb>
f0100517:	e9 8a 00 00 00       	jmp    f01005a6 <cons_putc+0x13d>
	case '\b':
		if (crt_pos > 0) {
f010051c:	0f b7 05 28 12 23 f0 	movzwl 0xf0231228,%eax
f0100523:	66 85 c0             	test   %ax,%ax
f0100526:	0f 84 e5 00 00 00    	je     f0100611 <cons_putc+0x1a8>
			crt_pos--;
f010052c:	83 e8 01             	sub    $0x1,%eax
f010052f:	66 a3 28 12 23 f0    	mov    %ax,0xf0231228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100535:	0f b7 c0             	movzwl %ax,%eax
f0100538:	66 81 e7 00 ff       	and    $0xff00,%di
f010053d:	83 cf 20             	or     $0x20,%edi
f0100540:	8b 15 2c 12 23 f0    	mov    0xf023122c,%edx
f0100546:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010054a:	eb 78                	jmp    f01005c4 <cons_putc+0x15b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010054c:	66 83 05 28 12 23 f0 	addw   $0x50,0xf0231228
f0100553:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100554:	0f b7 05 28 12 23 f0 	movzwl 0xf0231228,%eax
f010055b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100561:	c1 e8 16             	shr    $0x16,%eax
f0100564:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100567:	c1 e0 04             	shl    $0x4,%eax
f010056a:	66 a3 28 12 23 f0    	mov    %ax,0xf0231228
f0100570:	eb 52                	jmp    f01005c4 <cons_putc+0x15b>
		break;
	case '\t':
		cons_putc(' ');
f0100572:	b8 20 00 00 00       	mov    $0x20,%eax
f0100577:	e8 ed fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f010057c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100581:	e8 e3 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f0100586:	b8 20 00 00 00       	mov    $0x20,%eax
f010058b:	e8 d9 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f0100590:	b8 20 00 00 00       	mov    $0x20,%eax
f0100595:	e8 cf fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f010059a:	b8 20 00 00 00       	mov    $0x20,%eax
f010059f:	e8 c5 fe ff ff       	call   f0100469 <cons_putc>
f01005a4:	eb 1e                	jmp    f01005c4 <cons_putc+0x15b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005a6:	0f b7 05 28 12 23 f0 	movzwl 0xf0231228,%eax
f01005ad:	8d 50 01             	lea    0x1(%eax),%edx
f01005b0:	66 89 15 28 12 23 f0 	mov    %dx,0xf0231228
f01005b7:	0f b7 c0             	movzwl %ax,%eax
f01005ba:	8b 15 2c 12 23 f0    	mov    0xf023122c,%edx
f01005c0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005c4:	66 81 3d 28 12 23 f0 	cmpw   $0x7cf,0xf0231228
f01005cb:	cf 07 
f01005cd:	76 42                	jbe    f0100611 <cons_putc+0x1a8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005cf:	a1 2c 12 23 f0       	mov    0xf023122c,%eax
f01005d4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005db:	00 
f01005dc:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005e2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005e6:	89 04 24             	mov    %eax,(%esp)
f01005e9:	e8 86 5c 00 00       	call   f0106274 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005ee:	8b 15 2c 12 23 f0    	mov    0xf023122c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01005f4:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f01005f9:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01005ff:	83 c0 01             	add    $0x1,%eax
f0100602:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100607:	75 f0                	jne    f01005f9 <cons_putc+0x190>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100609:	66 83 2d 28 12 23 f0 	subw   $0x50,0xf0231228
f0100610:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100611:	8b 0d 30 12 23 f0    	mov    0xf0231230,%ecx
f0100617:	b8 0e 00 00 00       	mov    $0xe,%eax
f010061c:	89 ca                	mov    %ecx,%edx
f010061e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010061f:	0f b7 1d 28 12 23 f0 	movzwl 0xf0231228,%ebx
f0100626:	8d 71 01             	lea    0x1(%ecx),%esi
f0100629:	89 d8                	mov    %ebx,%eax
f010062b:	66 c1 e8 08          	shr    $0x8,%ax
f010062f:	89 f2                	mov    %esi,%edx
f0100631:	ee                   	out    %al,(%dx)
f0100632:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100637:	89 ca                	mov    %ecx,%edx
f0100639:	ee                   	out    %al,(%dx)
f010063a:	89 d8                	mov    %ebx,%eax
f010063c:	89 f2                	mov    %esi,%edx
f010063e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010063f:	83 c4 1c             	add    $0x1c,%esp
f0100642:	5b                   	pop    %ebx
f0100643:	5e                   	pop    %esi
f0100644:	5f                   	pop    %edi
f0100645:	5d                   	pop    %ebp
f0100646:	c3                   	ret    

f0100647 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100647:	80 3d 34 12 23 f0 00 	cmpb   $0x0,0xf0231234
f010064e:	74 11                	je     f0100661 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100650:	55                   	push   %ebp
f0100651:	89 e5                	mov    %esp,%ebp
f0100653:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100656:	b8 00 03 10 f0       	mov    $0xf0100300,%eax
f010065b:	e8 bc fc ff ff       	call   f010031c <cons_intr>
}
f0100660:	c9                   	leave  
f0100661:	f3 c3                	repz ret 

f0100663 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100663:	55                   	push   %ebp
f0100664:	89 e5                	mov    %esp,%ebp
f0100666:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100669:	b8 60 03 10 f0       	mov    $0xf0100360,%eax
f010066e:	e8 a9 fc ff ff       	call   f010031c <cons_intr>
}
f0100673:	c9                   	leave  
f0100674:	c3                   	ret    

f0100675 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100675:	55                   	push   %ebp
f0100676:	89 e5                	mov    %esp,%ebp
f0100678:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010067b:	e8 c7 ff ff ff       	call   f0100647 <serial_intr>
	kbd_intr();
f0100680:	e8 de ff ff ff       	call   f0100663 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100685:	a1 20 12 23 f0       	mov    0xf0231220,%eax
f010068a:	3b 05 24 12 23 f0    	cmp    0xf0231224,%eax
f0100690:	74 26                	je     f01006b8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100692:	8d 50 01             	lea    0x1(%eax),%edx
f0100695:	89 15 20 12 23 f0    	mov    %edx,0xf0231220
f010069b:	0f b6 88 20 10 23 f0 	movzbl -0xfdcefe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006a2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006a4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006aa:	75 11                	jne    f01006bd <cons_getc+0x48>
			cons.rpos = 0;
f01006ac:	c7 05 20 12 23 f0 00 	movl   $0x0,0xf0231220
f01006b3:	00 00 00 
f01006b6:	eb 05                	jmp    f01006bd <cons_getc+0x48>
		return c;
	}
	return 0;
f01006b8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006bd:	c9                   	leave  
f01006be:	c3                   	ret    

f01006bf <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006bf:	55                   	push   %ebp
f01006c0:	89 e5                	mov    %esp,%ebp
f01006c2:	57                   	push   %edi
f01006c3:	56                   	push   %esi
f01006c4:	53                   	push   %ebx
f01006c5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006c8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006cf:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01006d6:	5a a5 
	if (*cp != 0xA55A) {
f01006d8:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01006df:	66 3d 5a a5          	cmp    $0xa55a,%ax
f01006e3:	74 11                	je     f01006f6 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f01006e5:	c7 05 30 12 23 f0 b4 	movl   $0x3b4,0xf0231230
f01006ec:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f01006ef:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f01006f4:	eb 16                	jmp    f010070c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f01006f6:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f01006fd:	c7 05 30 12 23 f0 d4 	movl   $0x3d4,0xf0231230
f0100704:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100707:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}

	/* Extract cursor location */
	outb(addr_6845, 14);
f010070c:	8b 0d 30 12 23 f0    	mov    0xf0231230,%ecx
f0100712:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100717:	89 ca                	mov    %ecx,%edx
f0100719:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010071a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010071d:	89 da                	mov    %ebx,%edx
f010071f:	ec                   	in     (%dx),%al
f0100720:	0f b6 f0             	movzbl %al,%esi
f0100723:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100726:	b8 0f 00 00 00       	mov    $0xf,%eax
f010072b:	89 ca                	mov    %ecx,%edx
f010072d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010072e:	89 da                	mov    %ebx,%edx
f0100730:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100731:	89 3d 2c 12 23 f0    	mov    %edi,0xf023122c

	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100737:	0f b6 d8             	movzbl %al,%ebx
f010073a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010073c:	66 89 35 28 12 23 f0 	mov    %si,0xf0231228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that QEMU generates interrupts.
	kbd_intr();
f0100743:	e8 1b ff ff ff       	call   f0100663 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100748:	0f b7 05 a8 13 12 f0 	movzwl 0xf01213a8,%eax
f010074f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100754:	89 04 24             	mov    %eax,(%esp)
f0100757:	e8 9c 36 00 00       	call   f0103df8 <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010075c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100761:	b8 00 00 00 00       	mov    $0x0,%eax
f0100766:	89 f2                	mov    %esi,%edx
f0100768:	ee                   	out    %al,(%dx)
f0100769:	b2 fb                	mov    $0xfb,%dl
f010076b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100770:	ee                   	out    %al,(%dx)
f0100771:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f0100776:	b8 0c 00 00 00       	mov    $0xc,%eax
f010077b:	89 da                	mov    %ebx,%edx
f010077d:	ee                   	out    %al,(%dx)
f010077e:	b2 f9                	mov    $0xf9,%dl
f0100780:	b8 00 00 00 00       	mov    $0x0,%eax
f0100785:	ee                   	out    %al,(%dx)
f0100786:	b2 fb                	mov    $0xfb,%dl
f0100788:	b8 03 00 00 00       	mov    $0x3,%eax
f010078d:	ee                   	out    %al,(%dx)
f010078e:	b2 fc                	mov    $0xfc,%dl
f0100790:	b8 00 00 00 00       	mov    $0x0,%eax
f0100795:	ee                   	out    %al,(%dx)
f0100796:	b2 f9                	mov    $0xf9,%dl
f0100798:	b8 01 00 00 00       	mov    $0x1,%eax
f010079d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010079e:	b2 fd                	mov    $0xfd,%dl
f01007a0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007a1:	3c ff                	cmp    $0xff,%al
f01007a3:	0f 95 c1             	setne  %cl
f01007a6:	88 0d 34 12 23 f0    	mov    %cl,0xf0231234
f01007ac:	89 f2                	mov    %esi,%edx
f01007ae:	ec                   	in     (%dx),%al
f01007af:	89 da                	mov    %ebx,%edx
f01007b1:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007b2:	84 c9                	test   %cl,%cl
f01007b4:	75 0c                	jne    f01007c2 <cons_init+0x103>
		cprintf("Serial port does not exist!\n");
f01007b6:	c7 04 24 38 70 10 f0 	movl   $0xf0107038,(%esp)
f01007bd:	e8 75 37 00 00       	call   f0103f37 <cprintf>
}
f01007c2:	83 c4 1c             	add    $0x1c,%esp
f01007c5:	5b                   	pop    %ebx
f01007c6:	5e                   	pop    %esi
f01007c7:	5f                   	pop    %edi
f01007c8:	5d                   	pop    %ebp
f01007c9:	c3                   	ret    

f01007ca <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007ca:	55                   	push   %ebp
f01007cb:	89 e5                	mov    %esp,%ebp
f01007cd:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01007d0:	8b 45 08             	mov    0x8(%ebp),%eax
f01007d3:	e8 91 fc ff ff       	call   f0100469 <cons_putc>
}
f01007d8:	c9                   	leave  
f01007d9:	c3                   	ret    

f01007da <getchar>:

int
getchar(void)
{
f01007da:	55                   	push   %ebp
f01007db:	89 e5                	mov    %esp,%ebp
f01007dd:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f01007e0:	e8 90 fe ff ff       	call   f0100675 <cons_getc>
f01007e5:	85 c0                	test   %eax,%eax
f01007e7:	74 f7                	je     f01007e0 <getchar+0x6>
		/* do nothing */;
	return c;
}
f01007e9:	c9                   	leave  
f01007ea:	c3                   	ret    

f01007eb <iscons>:

int
iscons(int fdnum)
{
f01007eb:	55                   	push   %ebp
f01007ec:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f01007ee:	b8 01 00 00 00       	mov    $0x1,%eax
f01007f3:	5d                   	pop    %ebp
f01007f4:	c3                   	ret    
f01007f5:	66 90                	xchg   %ax,%ax
f01007f7:	66 90                	xchg   %ax,%ax
f01007f9:	66 90                	xchg   %ax,%ax
f01007fb:	66 90                	xchg   %ax,%ax
f01007fd:	66 90                	xchg   %ax,%ax
f01007ff:	90                   	nop

f0100800 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100800:	55                   	push   %ebp
f0100801:	89 e5                	mov    %esp,%ebp
f0100803:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100806:	c7 44 24 08 80 72 10 	movl   $0xf0107280,0x8(%esp)
f010080d:	f0 
f010080e:	c7 44 24 04 9e 72 10 	movl   $0xf010729e,0x4(%esp)
f0100815:	f0 
f0100816:	c7 04 24 a3 72 10 f0 	movl   $0xf01072a3,(%esp)
f010081d:	e8 15 37 00 00       	call   f0103f37 <cprintf>
f0100822:	c7 44 24 08 30 73 10 	movl   $0xf0107330,0x8(%esp)
f0100829:	f0 
f010082a:	c7 44 24 04 ac 72 10 	movl   $0xf01072ac,0x4(%esp)
f0100831:	f0 
f0100832:	c7 04 24 a3 72 10 f0 	movl   $0xf01072a3,(%esp)
f0100839:	e8 f9 36 00 00       	call   f0103f37 <cprintf>
f010083e:	c7 44 24 08 b5 72 10 	movl   $0xf01072b5,0x8(%esp)
f0100845:	f0 
f0100846:	c7 44 24 04 bf 72 10 	movl   $0xf01072bf,0x4(%esp)
f010084d:	f0 
f010084e:	c7 04 24 a3 72 10 f0 	movl   $0xf01072a3,(%esp)
f0100855:	e8 dd 36 00 00       	call   f0103f37 <cprintf>
	return 0;
}
f010085a:	b8 00 00 00 00       	mov    $0x0,%eax
f010085f:	c9                   	leave  
f0100860:	c3                   	ret    

f0100861 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100861:	55                   	push   %ebp
f0100862:	89 e5                	mov    %esp,%ebp
f0100864:	83 ec 18             	sub    $0x18,%esp
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100867:	c7 04 24 c9 72 10 f0 	movl   $0xf01072c9,(%esp)
f010086e:	e8 c4 36 00 00       	call   f0103f37 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f0100873:	c7 44 24 04 0c 00 10 	movl   $0x10000c,0x4(%esp)
f010087a:	00 
f010087b:	c7 04 24 58 73 10 f0 	movl   $0xf0107358,(%esp)
f0100882:	e8 b0 36 00 00       	call   f0103f37 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100887:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010088e:	00 
f010088f:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100896:	f0 
f0100897:	c7 04 24 80 73 10 f0 	movl   $0xf0107380,(%esp)
f010089e:	e8 94 36 00 00       	call   f0103f37 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008a3:	c7 44 24 08 47 6f 10 	movl   $0x106f47,0x8(%esp)
f01008aa:	00 
f01008ab:	c7 44 24 04 47 6f 10 	movl   $0xf0106f47,0x4(%esp)
f01008b2:	f0 
f01008b3:	c7 04 24 a4 73 10 f0 	movl   $0xf01073a4,(%esp)
f01008ba:	e8 78 36 00 00       	call   f0103f37 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008bf:	c7 44 24 08 e8 00 23 	movl   $0x2300e8,0x8(%esp)
f01008c6:	00 
f01008c7:	c7 44 24 04 e8 00 23 	movl   $0xf02300e8,0x4(%esp)
f01008ce:	f0 
f01008cf:	c7 04 24 c8 73 10 f0 	movl   $0xf01073c8,(%esp)
f01008d6:	e8 5c 36 00 00       	call   f0103f37 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008db:	c7 44 24 08 08 30 27 	movl   $0x273008,0x8(%esp)
f01008e2:	00 
f01008e3:	c7 44 24 04 08 30 27 	movl   $0xf0273008,0x4(%esp)
f01008ea:	f0 
f01008eb:	c7 04 24 ec 73 10 f0 	movl   $0xf01073ec,(%esp)
f01008f2:	e8 40 36 00 00       	call   f0103f37 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		ROUNDUP(end - entry, 1024) / 1024);
f01008f7:	b8 07 34 27 f0       	mov    $0xf0273407,%eax
f01008fc:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
f0100901:	25 00 fc ff ff       	and    $0xfffffc00,%eax
	cprintf("  _start                  %08x (phys)\n", _start);
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100906:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010090c:	85 c0                	test   %eax,%eax
f010090e:	0f 48 c2             	cmovs  %edx,%eax
f0100911:	c1 f8 0a             	sar    $0xa,%eax
f0100914:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100918:	c7 04 24 10 74 10 f0 	movl   $0xf0107410,(%esp)
f010091f:	e8 13 36 00 00       	call   f0103f37 <cprintf>
		ROUNDUP(end - entry, 1024) / 1024);
	return 0;
}
f0100924:	b8 00 00 00 00       	mov    $0x0,%eax
f0100929:	c9                   	leave  
f010092a:	c3                   	ret    

f010092b <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010092b:	55                   	push   %ebp
f010092c:	89 e5                	mov    %esp,%ebp
f010092e:	56                   	push   %esi
f010092f:	53                   	push   %ebx
f0100930:	83 ec 40             	sub    $0x40,%esp
	// Your code here.
	uint32_t *p = (uint32_t *) read_ebp();
f0100933:	89 eb                	mov    %ebp,%ebx
	// int flag = 0;
	while(1)
	{
		if(p==NULL)
			break;
		if(debuginfo_eip((uintptr_t)(*(p+1)), &info)==0)
f0100935:	8d 75 e0             	lea    -0x20(%ebp),%esi
	struct Eipdebuginfo info;
	int line_offset = 0;
	// int flag = 0;
	while(1)
	{
		if(p==NULL)
f0100938:	85 db                	test   %ebx,%ebx
f010093a:	0f 84 86 00 00 00    	je     f01009c6 <mon_backtrace+0x9b>
			break;
		if(debuginfo_eip((uintptr_t)(*(p+1)), &info)==0)
f0100940:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100944:	8b 43 04             	mov    0x4(%ebx),%eax
f0100947:	89 04 24             	mov    %eax,(%esp)
f010094a:	e8 b7 4d 00 00       	call   f0105706 <debuginfo_eip>
f010094f:	85 c0                	test   %eax,%eax
f0100951:	75 73                	jne    f01009c6 <mon_backtrace+0x9b>
		{
			cprintf("ebp %08x eip %08x args %08x %08x %08x %08x %08x\n", p, *(p+1), *(p+2), *(p+3), *(p+4), *(p+5), *(p+6));
f0100953:	8b 43 18             	mov    0x18(%ebx),%eax
f0100956:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f010095a:	8b 43 14             	mov    0x14(%ebx),%eax
f010095d:	89 44 24 18          	mov    %eax,0x18(%esp)
f0100961:	8b 43 10             	mov    0x10(%ebx),%eax
f0100964:	89 44 24 14          	mov    %eax,0x14(%esp)
f0100968:	8b 43 0c             	mov    0xc(%ebx),%eax
f010096b:	89 44 24 10          	mov    %eax,0x10(%esp)
f010096f:	8b 43 08             	mov    0x8(%ebx),%eax
f0100972:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100976:	8b 43 04             	mov    0x4(%ebx),%eax
f0100979:	89 44 24 08          	mov    %eax,0x8(%esp)
f010097d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100981:	c7 04 24 3c 74 10 f0 	movl   $0xf010743c,(%esp)
f0100988:	e8 aa 35 00 00       	call   f0103f37 <cprintf>
			line_offset = (uintptr_t)(*(p+1)) - info.eip_fn_addr;
f010098d:	8b 43 04             	mov    0x4(%ebx),%eax
f0100990:	2b 45 f0             	sub    -0x10(%ebp),%eax
			cprintf("\t%s:%d: %.*s+%d\n", info.eip_file, info.eip_line, info.eip_fn_namelen, info.eip_fn_name, line_offset);
f0100993:	89 44 24 14          	mov    %eax,0x14(%esp)
f0100997:	8b 45 e8             	mov    -0x18(%ebp),%eax
f010099a:	89 44 24 10          	mov    %eax,0x10(%esp)
f010099e:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01009a1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009a5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01009a8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01009ac:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01009af:	89 44 24 04          	mov    %eax,0x4(%esp)
f01009b3:	c7 04 24 e2 72 10 f0 	movl   $0xf01072e2,(%esp)
f01009ba:	e8 78 35 00 00       	call   f0103f37 <cprintf>
			p = (uint32_t*)(*p);	
f01009bf:	8b 1b                	mov    (%ebx),%ebx
		}
		else
			break;
	}
f01009c1:	e9 72 ff ff ff       	jmp    f0100938 <mon_backtrace+0xd>
	return 0;
}
f01009c6:	b8 00 00 00 00       	mov    $0x0,%eax
f01009cb:	83 c4 40             	add    $0x40,%esp
f01009ce:	5b                   	pop    %ebx
f01009cf:	5e                   	pop    %esi
f01009d0:	5d                   	pop    %ebp
f01009d1:	c3                   	ret    

f01009d2 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01009d2:	55                   	push   %ebp
f01009d3:	89 e5                	mov    %esp,%ebp
f01009d5:	57                   	push   %edi
f01009d6:	56                   	push   %esi
f01009d7:	53                   	push   %ebx
f01009d8:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009db:	c7 04 24 70 74 10 f0 	movl   $0xf0107470,(%esp)
f01009e2:	e8 50 35 00 00       	call   f0103f37 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009e7:	c7 04 24 94 74 10 f0 	movl   $0xf0107494,(%esp)
f01009ee:	e8 44 35 00 00       	call   f0103f37 <cprintf>

	if (tf != NULL)
f01009f3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009f7:	74 0b                	je     f0100a04 <monitor+0x32>
		print_trapframe(tf);
f01009f9:	8b 45 08             	mov    0x8(%ebp),%eax
f01009fc:	89 04 24             	mov    %eax,(%esp)
f01009ff:	e8 3f 3d 00 00       	call   f0104743 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100a04:	c7 04 24 f3 72 10 f0 	movl   $0xf01072f3,(%esp)
f0100a0b:	e8 c0 55 00 00       	call   f0105fd0 <readline>
f0100a10:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100a12:	85 c0                	test   %eax,%eax
f0100a14:	74 ee                	je     f0100a04 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100a16:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a1d:	be 00 00 00 00       	mov    $0x0,%esi
f0100a22:	eb 0a                	jmp    f0100a2e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a24:	c6 03 00             	movb   $0x0,(%ebx)
f0100a27:	89 f7                	mov    %esi,%edi
f0100a29:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a2c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a2e:	0f b6 03             	movzbl (%ebx),%eax
f0100a31:	84 c0                	test   %al,%al
f0100a33:	74 63                	je     f0100a98 <monitor+0xc6>
f0100a35:	0f be c0             	movsbl %al,%eax
f0100a38:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a3c:	c7 04 24 f7 72 10 f0 	movl   $0xf01072f7,(%esp)
f0100a43:	e8 a2 57 00 00       	call   f01061ea <strchr>
f0100a48:	85 c0                	test   %eax,%eax
f0100a4a:	75 d8                	jne    f0100a24 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a4c:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a4f:	74 47                	je     f0100a98 <monitor+0xc6>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a51:	83 fe 0f             	cmp    $0xf,%esi
f0100a54:	75 16                	jne    f0100a6c <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a56:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a5d:	00 
f0100a5e:	c7 04 24 fc 72 10 f0 	movl   $0xf01072fc,(%esp)
f0100a65:	e8 cd 34 00 00       	call   f0103f37 <cprintf>
f0100a6a:	eb 98                	jmp    f0100a04 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a6c:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a6f:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
f0100a73:	eb 03                	jmp    f0100a78 <monitor+0xa6>
		while (*buf && !strchr(WHITESPACE, *buf))
			buf++;
f0100a75:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a78:	0f b6 03             	movzbl (%ebx),%eax
f0100a7b:	84 c0                	test   %al,%al
f0100a7d:	74 ad                	je     f0100a2c <monitor+0x5a>
f0100a7f:	0f be c0             	movsbl %al,%eax
f0100a82:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a86:	c7 04 24 f7 72 10 f0 	movl   $0xf01072f7,(%esp)
f0100a8d:	e8 58 57 00 00       	call   f01061ea <strchr>
f0100a92:	85 c0                	test   %eax,%eax
f0100a94:	74 df                	je     f0100a75 <monitor+0xa3>
f0100a96:	eb 94                	jmp    f0100a2c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100a98:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100a9f:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100aa0:	85 f6                	test   %esi,%esi
f0100aa2:	0f 84 5c ff ff ff    	je     f0100a04 <monitor+0x32>
f0100aa8:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100aad:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100ab0:	8b 04 85 c0 74 10 f0 	mov    -0xfef8b40(,%eax,4),%eax
f0100ab7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100abb:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100abe:	89 04 24             	mov    %eax,(%esp)
f0100ac1:	e8 c6 56 00 00       	call   f010618c <strcmp>
f0100ac6:	85 c0                	test   %eax,%eax
f0100ac8:	75 24                	jne    f0100aee <monitor+0x11c>
			return commands[i].func(argc, argv, tf);
f0100aca:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100acd:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ad0:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100ad4:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ad7:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100adb:	89 34 24             	mov    %esi,(%esp)
f0100ade:	ff 14 85 c8 74 10 f0 	call   *-0xfef8b38(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100ae5:	85 c0                	test   %eax,%eax
f0100ae7:	78 25                	js     f0100b0e <monitor+0x13c>
f0100ae9:	e9 16 ff ff ff       	jmp    f0100a04 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100aee:	83 c3 01             	add    $0x1,%ebx
f0100af1:	83 fb 03             	cmp    $0x3,%ebx
f0100af4:	75 b7                	jne    f0100aad <monitor+0xdb>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100af6:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100af9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100afd:	c7 04 24 19 73 10 f0 	movl   $0xf0107319,(%esp)
f0100b04:	e8 2e 34 00 00       	call   f0103f37 <cprintf>
f0100b09:	e9 f6 fe ff ff       	jmp    f0100a04 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100b0e:	83 c4 5c             	add    $0x5c,%esp
f0100b11:	5b                   	pop    %ebx
f0100b12:	5e                   	pop    %esi
f0100b13:	5f                   	pop    %edi
f0100b14:	5d                   	pop    %ebp
f0100b15:	c3                   	ret    
f0100b16:	66 90                	xchg   %ax,%ax
f0100b18:	66 90                	xchg   %ax,%ax
f0100b1a:	66 90                	xchg   %ax,%ax
f0100b1c:	66 90                	xchg   %ax,%ax
f0100b1e:	66 90                	xchg   %ax,%ax

f0100b20 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b20:	55                   	push   %ebp
f0100b21:	89 e5                	mov    %esp,%ebp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b23:	83 3d 38 12 23 f0 00 	cmpl   $0x0,0xf0231238
f0100b2a:	75 11                	jne    f0100b3d <boot_alloc+0x1d>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b2c:	ba 07 40 27 f0       	mov    $0xf0274007,%edx
f0100b31:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b37:	89 15 38 12 23 f0    	mov    %edx,0xf0231238
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.

	if(n==0)
f0100b3d:	85 c0                	test   %eax,%eax
f0100b3f:	75 07                	jne    f0100b48 <boot_alloc+0x28>
		return nextfree;
f0100b41:	a1 38 12 23 f0       	mov    0xf0231238,%eax
f0100b46:	eb 19                	jmp    f0100b61 <boot_alloc+0x41>

	result = nextfree;
f0100b48:	8b 15 38 12 23 f0    	mov    0xf0231238,%edx
	nextfree += n;
	nextfree = ROUNDUP(nextfree, PGSIZE);
f0100b4e:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f0100b55:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b5a:	a3 38 12 23 f0       	mov    %eax,0xf0231238

	// cprintf("Nextfree:%x\n", nextfree);

	return result;
f0100b5f:	89 d0                	mov    %edx,%eax
}
f0100b61:	5d                   	pop    %ebp
f0100b62:	c3                   	ret    

f0100b63 <page2kva>:
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b63:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f0100b69:	c1 f8 03             	sar    $0x3,%eax
f0100b6c:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b6f:	89 c2                	mov    %eax,%edx
f0100b71:	c1 ea 0c             	shr    $0xc,%edx
f0100b74:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f0100b7a:	72 26                	jb     f0100ba2 <page2kva+0x3f>
	return &pages[PGNUM(pa)];
}

static inline void*
page2kva(struct PageInfo *pp)
{
f0100b7c:	55                   	push   %ebp
f0100b7d:	89 e5                	mov    %esp,%ebp
f0100b7f:	83 ec 18             	sub    $0x18,%esp

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b82:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b86:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0100b8d:	f0 
f0100b8e:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0100b95:	00 
f0100b96:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0100b9d:	e8 9e f4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ba2:	2d 00 00 00 10       	sub    $0x10000000,%eax

static inline void*
page2kva(struct PageInfo *pp)
{
	return KADDR(page2pa(pp));
}
f0100ba7:	c3                   	ret    

f0100ba8 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100ba8:	89 d1                	mov    %edx,%ecx
f0100baa:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100bad:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bb0:	a8 01                	test   $0x1,%al
f0100bb2:	74 5d                	je     f0100c11 <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100bb4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bb9:	89 c1                	mov    %eax,%ecx
f0100bbb:	c1 e9 0c             	shr    $0xc,%ecx
f0100bbe:	3b 0d 88 1e 23 f0    	cmp    0xf0231e88,%ecx
f0100bc4:	72 26                	jb     f0100bec <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100bc6:	55                   	push   %ebp
f0100bc7:	89 e5                	mov    %esp,%ebp
f0100bc9:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bcc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bd0:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0100bd7:	f0 
f0100bd8:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f0100bdf:	00 
f0100be0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100be7:	e8 54 f4 ff ff       	call   f0100040 <_panic>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	
	// cprintf("page_table_entry from check:%x\n", &p[PTX(va)]);

	if (!(p[PTX(va)] & PTE_P)){
f0100bec:	c1 ea 0c             	shr    $0xc,%edx
f0100bef:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100bf5:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100bfc:	89 c2                	mov    %eax,%edx
f0100bfe:	83 e2 01             	and    $0x1,%edx
		return ~0;
	}

	return PTE_ADDR(p[PTX(va)]);
f0100c01:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c06:	85 d2                	test   %edx,%edx
f0100c08:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c0d:	0f 44 c2             	cmove  %edx,%eax
f0100c10:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c11:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	if (!(p[PTX(va)] & PTE_P)){
		return ~0;
	}

	return PTE_ADDR(p[PTX(va)]);
}
f0100c16:	c3                   	ret    

f0100c17 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c17:	55                   	push   %ebp
f0100c18:	89 e5                	mov    %esp,%ebp
f0100c1a:	57                   	push   %edi
f0100c1b:	56                   	push   %esi
f0100c1c:	53                   	push   %ebx
f0100c1d:	83 ec 4c             	sub    $0x4c,%esp
	struct PageInfo *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c20:	84 c0                	test   %al,%al
f0100c22:	0f 85 31 03 00 00    	jne    f0100f59 <check_page_free_list+0x342>
f0100c28:	e9 3e 03 00 00       	jmp    f0100f6b <check_page_free_list+0x354>
	char *first_free_page;

	// cprintf("Here-3!\n");

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c2d:	c7 44 24 08 e4 74 10 	movl   $0xf01074e4,0x8(%esp)
f0100c34:	f0 
f0100c35:	c7 44 24 04 f9 02 00 	movl   $0x2f9,0x4(%esp)
f0100c3c:	00 
f0100c3d:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100c44:	e8 f7 f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct PageInfo *pp1, *pp2;
		struct PageInfo **tp[2] = { &pp1, &pp2 };
f0100c49:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c4c:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c4f:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c52:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c55:	89 c2                	mov    %eax,%edx
f0100c57:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			// cprintf("Here-7!\n");
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c5d:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c63:	0f 95 c2             	setne  %dl
f0100c66:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c69:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c6d:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c6f:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct PageInfo *pp1, *pp2;
		struct PageInfo **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c73:	8b 00                	mov    (%eax),%eax
f0100c75:	85 c0                	test   %eax,%eax
f0100c77:	75 dc                	jne    f0100c55 <check_page_free_list+0x3e>
			// cprintf("Here-7!\n");
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c79:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c7c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c82:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c85:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c88:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c8a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c8d:	a3 40 12 23 f0       	mov    %eax,0xf0231240
//
static void
check_page_free_list(bool only_low_memory)
{
	struct PageInfo *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c92:	be 01 00 00 00       	mov    $0x1,%esi

	// cprintf("Here-1!\n");

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c97:	8b 1d 40 12 23 f0    	mov    0xf0231240,%ebx
f0100c9d:	eb 63                	jmp    f0100d02 <check_page_free_list+0xeb>
f0100c9f:	89 d8                	mov    %ebx,%eax
f0100ca1:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f0100ca7:	c1 f8 03             	sar    $0x3,%eax
f0100caa:	c1 e0 0c             	shl    $0xc,%eax
		if (PDX(page2pa(pp)) < pdx_limit)
f0100cad:	89 c2                	mov    %eax,%edx
f0100caf:	c1 ea 16             	shr    $0x16,%edx
f0100cb2:	39 f2                	cmp    %esi,%edx
f0100cb4:	73 4a                	jae    f0100d00 <check_page_free_list+0xe9>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cb6:	89 c2                	mov    %eax,%edx
f0100cb8:	c1 ea 0c             	shr    $0xc,%edx
f0100cbb:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f0100cc1:	72 20                	jb     f0100ce3 <check_page_free_list+0xcc>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cc3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100cc7:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0100cce:	f0 
f0100ccf:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0100cd6:	00 
f0100cd7:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0100cde:	e8 5d f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100ce3:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100cea:	00 
f0100ceb:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100cf2:	00 
	return (void *)(pa + KERNBASE);
f0100cf3:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100cf8:	89 04 24             	mov    %eax,(%esp)
f0100cfb:	e8 27 55 00 00       	call   f0106227 <memset>

	// cprintf("Here-1!\n");

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d00:	8b 1b                	mov    (%ebx),%ebx
f0100d02:	85 db                	test   %ebx,%ebx
f0100d04:	75 99                	jne    f0100c9f <check_page_free_list+0x88>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	// cprintf("Here0\n");

	first_free_page = (char *) boot_alloc(0);
f0100d06:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d0b:	e8 10 fe ff ff       	call   f0100b20 <boot_alloc>
f0100d10:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d13:	8b 15 40 12 23 f0    	mov    0xf0231240,%edx
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d19:	8b 0d 90 1e 23 f0    	mov    0xf0231e90,%ecx
		assert(pp < pages + npages);
f0100d1f:	a1 88 1e 23 f0       	mov    0xf0231e88,%eax
f0100d24:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d27:	8d 04 c1             	lea    (%ecx,%eax,8),%eax
f0100d2a:	89 45 d0             	mov    %eax,-0x30(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d2d:	89 4d cc             	mov    %ecx,-0x34(%ebp)
static void
check_page_free_list(bool only_low_memory)
{
	struct PageInfo *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100d30:	bf 00 00 00 00       	mov    $0x0,%edi
f0100d35:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
			memset(page2kva(pp), 0x97, 128);

	// cprintf("Here0\n");

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d38:	e9 c4 01 00 00       	jmp    f0100f01 <check_page_free_list+0x2ea>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d3d:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d40:	73 24                	jae    f0100d66 <check_page_free_list+0x14f>
f0100d42:	c7 44 24 0c fb 7d 10 	movl   $0xf0107dfb,0xc(%esp)
f0100d49:	f0 
f0100d4a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100d51:	f0 
f0100d52:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0100d59:	00 
f0100d5a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100d61:	e8 da f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d66:	3b 55 d0             	cmp    -0x30(%ebp),%edx
f0100d69:	72 24                	jb     f0100d8f <check_page_free_list+0x178>
f0100d6b:	c7 44 24 0c 1c 7e 10 	movl   $0xf0107e1c,0xc(%esp)
f0100d72:	f0 
f0100d73:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100d7a:	f0 
f0100d7b:	c7 44 24 04 1b 03 00 	movl   $0x31b,0x4(%esp)
f0100d82:	00 
f0100d83:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100d8a:	e8 b1 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d8f:	89 d0                	mov    %edx,%eax
f0100d91:	2b 45 cc             	sub    -0x34(%ebp),%eax
f0100d94:	a8 07                	test   $0x7,%al
f0100d96:	74 24                	je     f0100dbc <check_page_free_list+0x1a5>
f0100d98:	c7 44 24 0c 08 75 10 	movl   $0xf0107508,0xc(%esp)
f0100d9f:	f0 
f0100da0:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100da7:	f0 
f0100da8:	c7 44 24 04 1c 03 00 	movl   $0x31c,0x4(%esp)
f0100daf:	00 
f0100db0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100db7:	e8 84 f2 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0100dbc:	c1 f8 03             	sar    $0x3,%eax
f0100dbf:	c1 e0 0c             	shl    $0xc,%eax

		// cprintf("Here1!\n");
		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100dc2:	85 c0                	test   %eax,%eax
f0100dc4:	75 24                	jne    f0100dea <check_page_free_list+0x1d3>
f0100dc6:	c7 44 24 0c 30 7e 10 	movl   $0xf0107e30,0xc(%esp)
f0100dcd:	f0 
f0100dce:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100dd5:	f0 
f0100dd6:	c7 44 24 04 20 03 00 	movl   $0x320,0x4(%esp)
f0100ddd:	00 
f0100dde:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100de5:	e8 56 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100dea:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100def:	75 24                	jne    f0100e15 <check_page_free_list+0x1fe>
f0100df1:	c7 44 24 0c 41 7e 10 	movl   $0xf0107e41,0xc(%esp)
f0100df8:	f0 
f0100df9:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100e00:	f0 
f0100e01:	c7 44 24 04 21 03 00 	movl   $0x321,0x4(%esp)
f0100e08:	00 
f0100e09:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100e10:	e8 2b f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e15:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e1a:	75 24                	jne    f0100e40 <check_page_free_list+0x229>
f0100e1c:	c7 44 24 0c 3c 75 10 	movl   $0xf010753c,0xc(%esp)
f0100e23:	f0 
f0100e24:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100e2b:	f0 
f0100e2c:	c7 44 24 04 22 03 00 	movl   $0x322,0x4(%esp)
f0100e33:	00 
f0100e34:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100e3b:	e8 00 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e40:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e45:	75 24                	jne    f0100e6b <check_page_free_list+0x254>
f0100e47:	c7 44 24 0c 5a 7e 10 	movl   $0xf0107e5a,0xc(%esp)
f0100e4e:	f0 
f0100e4f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100e56:	f0 
f0100e57:	c7 44 24 04 23 03 00 	movl   $0x323,0x4(%esp)
f0100e5e:	00 
f0100e5f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100e66:	e8 d5 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100e6b:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100e70:	0f 86 1c 01 00 00    	jbe    f0100f92 <check_page_free_list+0x37b>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e76:	89 c1                	mov    %eax,%ecx
f0100e78:	c1 e9 0c             	shr    $0xc,%ecx
f0100e7b:	39 4d c4             	cmp    %ecx,-0x3c(%ebp)
f0100e7e:	77 20                	ja     f0100ea0 <check_page_free_list+0x289>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100e80:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100e84:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0100e8b:	f0 
f0100e8c:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0100e93:	00 
f0100e94:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0100e9b:	e8 a0 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ea0:	8d 88 00 00 00 f0    	lea    -0x10000000(%eax),%ecx
f0100ea6:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100ea9:	0f 86 d3 00 00 00    	jbe    f0100f82 <check_page_free_list+0x36b>
f0100eaf:	c7 44 24 0c 60 75 10 	movl   $0xf0107560,0xc(%esp)
f0100eb6:	f0 
f0100eb7:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100ebe:	f0 
f0100ebf:	c7 44 24 04 24 03 00 	movl   $0x324,0x4(%esp)
f0100ec6:	00 
f0100ec7:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100ece:	e8 6d f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100ed3:	c7 44 24 0c 74 7e 10 	movl   $0xf0107e74,0xc(%esp)
f0100eda:	f0 
f0100edb:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100ee2:	f0 
f0100ee3:	c7 44 24 04 26 03 00 	movl   $0x326,0x4(%esp)
f0100eea:	00 
f0100eeb:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100ef2:	e8 49 f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100ef7:	83 c3 01             	add    $0x1,%ebx
f0100efa:	eb 03                	jmp    f0100eff <check_page_free_list+0x2e8>
		else
			++nfree_extmem;
f0100efc:	83 c7 01             	add    $0x1,%edi
			memset(page2kva(pp), 0x97, 128);

	// cprintf("Here0\n");

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100eff:	8b 12                	mov    (%edx),%edx
f0100f01:	85 d2                	test   %edx,%edx
f0100f03:	0f 85 34 fe ff ff    	jne    f0100d3d <check_page_free_list+0x126>
			++nfree_extmem;
	}

	// cprintf("Here2!\n");

	assert(nfree_basemem > 0);
f0100f09:	85 db                	test   %ebx,%ebx
f0100f0b:	7f 24                	jg     f0100f31 <check_page_free_list+0x31a>
f0100f0d:	c7 44 24 0c 91 7e 10 	movl   $0xf0107e91,0xc(%esp)
f0100f14:	f0 
f0100f15:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100f1c:	f0 
f0100f1d:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f0100f24:	00 
f0100f25:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100f2c:	e8 0f f1 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f31:	85 ff                	test   %edi,%edi
f0100f33:	7f 70                	jg     f0100fa5 <check_page_free_list+0x38e>
f0100f35:	c7 44 24 0c a3 7e 10 	movl   $0xf0107ea3,0xc(%esp)
f0100f3c:	f0 
f0100f3d:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0100f44:	f0 
f0100f45:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f0100f4c:	00 
f0100f4d:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0100f54:	e8 e7 f0 ff ff       	call   f0100040 <_panic>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	// cprintf("Here-3!\n");

	if (!page_free_list)
f0100f59:	a1 40 12 23 f0       	mov    0xf0231240,%eax
f0100f5e:	85 c0                	test   %eax,%eax
f0100f60:	0f 85 e3 fc ff ff    	jne    f0100c49 <check_page_free_list+0x32>
f0100f66:	e9 c2 fc ff ff       	jmp    f0100c2d <check_page_free_list+0x16>
f0100f6b:	83 3d 40 12 23 f0 00 	cmpl   $0x0,0xf0231240
f0100f72:	0f 84 b5 fc ff ff    	je     f0100c2d <check_page_free_list+0x16>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct PageInfo *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100f78:	be 00 04 00 00       	mov    $0x400,%esi
f0100f7d:	e9 15 fd ff ff       	jmp    f0100c97 <check_page_free_list+0x80>
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f82:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f87:	0f 85 6f ff ff ff    	jne    f0100efc <check_page_free_list+0x2e5>
f0100f8d:	e9 41 ff ff ff       	jmp    f0100ed3 <check_page_free_list+0x2bc>
f0100f92:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f97:	0f 85 5a ff ff ff    	jne    f0100ef7 <check_page_free_list+0x2e0>
f0100f9d:	8d 76 00             	lea    0x0(%esi),%esi
f0100fa0:	e9 2e ff ff ff       	jmp    f0100ed3 <check_page_free_list+0x2bc>
	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);

	// cprintf("Here3!\n");
	// cprintf("Free page list checked successfully\n");
}
f0100fa5:	83 c4 4c             	add    $0x4c,%esp
f0100fa8:	5b                   	pop    %ebx
f0100fa9:	5e                   	pop    %esi
f0100faa:	5f                   	pop    %edi
f0100fab:	5d                   	pop    %ebp
f0100fac:	c3                   	ret    

f0100fad <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100fad:	55                   	push   %ebp
f0100fae:	89 e5                	mov    %esp,%ebp
f0100fb0:	56                   	push   %esi
f0100fb1:	53                   	push   %ebx
f0100fb2:	83 ec 10             	sub    $0x10,%esp
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	page_free_list = NULL;
	size_t i;
	for (i = 1; i < npages_basemem; i++) {
f0100fb5:	8b 35 44 12 23 f0    	mov    0xf0231244,%esi
f0100fbb:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100fc0:	b8 01 00 00 00       	mov    $0x1,%eax
f0100fc5:	eb 27                	jmp    f0100fee <page_init+0x41>
		if(i==PGNUM(MPENTRY_PADDR))
f0100fc7:	83 f8 07             	cmp    $0x7,%eax
f0100fca:	74 1f                	je     f0100feb <page_init+0x3e>
f0100fcc:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
			continue;
		pages[i].pp_ref = 0;
f0100fd3:	8b 0d 90 1e 23 f0    	mov    0xf0231e90,%ecx
f0100fd9:	66 c7 44 11 04 00 00 	movw   $0x0,0x4(%ecx,%edx,1)
		pages[i].pp_link = page_free_list;
f0100fe0:	89 1c c1             	mov    %ebx,(%ecx,%eax,8)
		page_free_list = &pages[i];
f0100fe3:	03 15 90 1e 23 f0    	add    0xf0231e90,%edx
f0100fe9:	89 d3                	mov    %edx,%ebx
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	page_free_list = NULL;
	size_t i;
	for (i = 1; i < npages_basemem; i++) {
f0100feb:	83 c0 01             	add    $0x1,%eax
f0100fee:	39 f0                	cmp    %esi,%eax
f0100ff0:	72 d5                	jb     f0100fc7 <page_init+0x1a>
f0100ff2:	89 1d 40 12 23 f0    	mov    %ebx,0xf0231240
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}	

	size_t low = ((uint32_t)PADDR(ROUNDUP((char*)(envs + NENV*sizeof(struct Env)), PGSIZE)))/(PGSIZE);
f0100ff8:	a1 48 12 23 f0       	mov    0xf0231248,%eax
f0100ffd:	8d 90 ff 4f f0 00    	lea    0xf04fff(%eax),%edx
f0101003:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101009:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f010100f:	77 20                	ja     f0101031 <page_init+0x84>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101011:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101015:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f010101c:	f0 
f010101d:	c7 44 24 04 50 01 00 	movl   $0x150,0x4(%esp)
f0101024:	00 
f0101025:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010102c:	e8 0f f0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101031:	81 c2 00 00 00 10    	add    $0x10000000,%edx
f0101037:	c1 ea 0c             	shr    $0xc,%edx
f010103a:	8d 04 d5 00 00 00 00 	lea    0x0(,%edx,8),%eax

	// cprintf("npages_basemem:%x\nlow:%x\n", npages_basemem*PGSIZE, PADDR(ROUNDUP((char*)(pages + npages*sizeof(struct PageInfo)), PGSIZE)));

	for(i = low ; i < npages ; i++) {
f0101041:	eb 1e                	jmp    f0101061 <page_init+0xb4>
		pages[i].pp_ref = 0;
f0101043:	89 c1                	mov    %eax,%ecx
f0101045:	03 0d 90 1e 23 f0    	add    0xf0231e90,%ecx
f010104b:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101051:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0101053:	89 c3                	mov    %eax,%ebx
f0101055:	03 1d 90 1e 23 f0    	add    0xf0231e90,%ebx

	size_t low = ((uint32_t)PADDR(ROUNDUP((char*)(envs + NENV*sizeof(struct Env)), PGSIZE)))/(PGSIZE);

	// cprintf("npages_basemem:%x\nlow:%x\n", npages_basemem*PGSIZE, PADDR(ROUNDUP((char*)(pages + npages*sizeof(struct PageInfo)), PGSIZE)));

	for(i = low ; i < npages ; i++) {
f010105b:	83 c2 01             	add    $0x1,%edx
f010105e:	83 c0 08             	add    $0x8,%eax
f0101061:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f0101067:	72 da                	jb     f0101043 <page_init+0x96>
f0101069:	89 1d 40 12 23 f0    	mov    %ebx,0xf0231240
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}
}
f010106f:	83 c4 10             	add    $0x10,%esp
f0101072:	5b                   	pop    %ebx
f0101073:	5e                   	pop    %esi
f0101074:	5d                   	pop    %ebp
f0101075:	c3                   	ret    

f0101076 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct PageInfo *
page_alloc(int alloc_flags)
{
f0101076:	55                   	push   %ebp
f0101077:	89 e5                	mov    %esp,%ebp
f0101079:	53                   	push   %ebx
f010107a:	83 ec 14             	sub    $0x14,%esp
	// Fill this function in

	struct PageInfo* result;

	result = page_free_list;
f010107d:	8b 1d 40 12 23 f0    	mov    0xf0231240,%ebx

	if(page_free_list==NULL){
f0101083:	85 db                	test   %ebx,%ebx
f0101085:	74 6f                	je     f01010f6 <page_alloc+0x80>
		return NULL;
	}

	page_free_list = page_free_list->pp_link;
f0101087:	8b 03                	mov    (%ebx),%eax
f0101089:	a3 40 12 23 f0       	mov    %eax,0xf0231240

	result->pp_link = NULL; 
f010108e:	c7 03 00 00 00 00    	movl   $0x0,(%ebx)

	if(alloc_flags & ALLOC_ZERO){
		memset(page2kva(result), 0, PGSIZE);
	}

	return result;
f0101094:	89 d8                	mov    %ebx,%eax

	page_free_list = page_free_list->pp_link;

	result->pp_link = NULL; 

	if(alloc_flags & ALLOC_ZERO){
f0101096:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f010109a:	74 5f                	je     f01010fb <page_alloc+0x85>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f010109c:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f01010a2:	c1 f8 03             	sar    $0x3,%eax
f01010a5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010a8:	89 c2                	mov    %eax,%edx
f01010aa:	c1 ea 0c             	shr    $0xc,%edx
f01010ad:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f01010b3:	72 20                	jb     f01010d5 <page_alloc+0x5f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01010b5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01010b9:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01010c0:	f0 
f01010c1:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f01010c8:	00 
f01010c9:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f01010d0:	e8 6b ef ff ff       	call   f0100040 <_panic>
		memset(page2kva(result), 0, PGSIZE);
f01010d5:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01010dc:	00 
f01010dd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01010e4:	00 
	return (void *)(pa + KERNBASE);
f01010e5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01010ea:	89 04 24             	mov    %eax,(%esp)
f01010ed:	e8 35 51 00 00       	call   f0106227 <memset>
	}

	return result;
f01010f2:	89 d8                	mov    %ebx,%eax
f01010f4:	eb 05                	jmp    f01010fb <page_alloc+0x85>
	struct PageInfo* result;

	result = page_free_list;

	if(page_free_list==NULL){
		return NULL;
f01010f6:	b8 00 00 00 00       	mov    $0x0,%eax
	if(alloc_flags & ALLOC_ZERO){
		memset(page2kva(result), 0, PGSIZE);
	}

	return result;
}
f01010fb:	83 c4 14             	add    $0x14,%esp
f01010fe:	5b                   	pop    %ebx
f01010ff:	5d                   	pop    %ebp
f0101100:	c3                   	ret    

f0101101 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct PageInfo *pp)
{
f0101101:	55                   	push   %ebp
f0101102:	89 e5                	mov    %esp,%ebp
f0101104:	83 ec 18             	sub    $0x18,%esp
f0101107:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
	// Hint: You may want to panic if pp->pp_ref is nonzero or
	// pp->pp_link is not NULL.

	if(pp->pp_link!=NULL)
f010110a:	83 38 00             	cmpl   $0x0,(%eax)
f010110d:	74 1c                	je     f010112b <page_free+0x2a>
		panic("Page -> pp_link is not null");
f010110f:	c7 44 24 08 b4 7e 10 	movl   $0xf0107eb4,0x8(%esp)
f0101116:	f0 
f0101117:	c7 44 24 04 8b 01 00 	movl   $0x18b,0x4(%esp)
f010111e:	00 
f010111f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101126:	e8 15 ef ff ff       	call   f0100040 <_panic>
	else
	if(pp->pp_ref!=0)
f010112b:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0101130:	74 1c                	je     f010114e <page_free+0x4d>
		panic("Page -> pp_ref is not null");
f0101132:	c7 44 24 08 d0 7e 10 	movl   $0xf0107ed0,0x8(%esp)
f0101139:	f0 
f010113a:	c7 44 24 04 8e 01 00 	movl   $0x18e,0x4(%esp)
f0101141:	00 
f0101142:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101149:	e8 f2 ee ff ff       	call   f0100040 <_panic>

	pp->pp_link = page_free_list;
f010114e:	8b 15 40 12 23 f0    	mov    0xf0231240,%edx
f0101154:	89 10                	mov    %edx,(%eax)

	page_free_list = pp;
f0101156:	a3 40 12 23 f0       	mov    %eax,0xf0231240

}
f010115b:	c9                   	leave  
f010115c:	c3                   	ret    

f010115d <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct PageInfo* pp)
{
f010115d:	55                   	push   %ebp
f010115e:	89 e5                	mov    %esp,%ebp
f0101160:	83 ec 18             	sub    $0x18,%esp
f0101163:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0101166:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f010116a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010116d:	66 89 50 04          	mov    %dx,0x4(%eax)
f0101171:	66 85 d2             	test   %dx,%dx
f0101174:	75 08                	jne    f010117e <page_decref+0x21>
		page_free(pp);
f0101176:	89 04 24             	mov    %eax,(%esp)
f0101179:	e8 83 ff ff ff       	call   f0101101 <page_free>
}
f010117e:	c9                   	leave  
f010117f:	c3                   	ret    

f0101180 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0101180:	55                   	push   %ebp
f0101181:	89 e5                	mov    %esp,%ebp
f0101183:	56                   	push   %esi
f0101184:	53                   	push   %ebx
f0101185:	83 ec 10             	sub    $0x10,%esp
f0101188:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in

	pde_t *page_dir_entry;

	page_dir_entry = (pde_t*)(&pgdir[PDX(va)]);
f010118b:	89 f3                	mov    %esi,%ebx
f010118d:	c1 eb 16             	shr    $0x16,%ebx
f0101190:	c1 e3 02             	shl    $0x2,%ebx
f0101193:	03 5d 08             	add    0x8(%ebp),%ebx
	// cprintf("Walk1!\n");

	pte_t* pgtable;
	pte_t* page_table_entry = NULL;

	if(!(PTE_P & *page_dir_entry))
f0101196:	f6 03 01             	testb  $0x1,(%ebx)
f0101199:	75 2c                	jne    f01011c7 <pgdir_walk+0x47>
	{
		if(create==false)
f010119b:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010119f:	74 6c                	je     f010120d <pgdir_walk+0x8d>
			return NULL;
		else
		{
			struct PageInfo *pp = page_alloc(1);
f01011a1:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01011a8:	e8 c9 fe ff ff       	call   f0101076 <page_alloc>
			if(pp==NULL)
f01011ad:	85 c0                	test   %eax,%eax
f01011af:	74 63                	je     f0101214 <pgdir_walk+0x94>
				return NULL;
			pp->pp_ref++;
f01011b1:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f01011b6:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f01011bc:	c1 f8 03             	sar    $0x3,%eax
f01011bf:	c1 e0 0c             	shl    $0xc,%eax
			*page_dir_entry = page2pa(pp)|PTE_P|PTE_U|PTE_W;
f01011c2:	83 c8 07             	or     $0x7,%eax
f01011c5:	89 03                	mov    %eax,(%ebx)
		}
	}
	// cprintf("Walk2!\n");
	pgtable = (pte_t*) KADDR(PTE_ADDR(*page_dir_entry));
f01011c7:	8b 03                	mov    (%ebx),%eax
f01011c9:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011ce:	89 c2                	mov    %eax,%edx
f01011d0:	c1 ea 0c             	shr    $0xc,%edx
f01011d3:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f01011d9:	72 20                	jb     f01011fb <pgdir_walk+0x7b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01011db:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011df:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01011e6:	f0 
f01011e7:	c7 44 24 04 d3 01 00 	movl   $0x1d3,0x4(%esp)
f01011ee:	00 
f01011ef:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01011f6:	e8 45 ee ff ff       	call   f0100040 <_panic>
	page_table_entry = (pte_t*)(&pgtable[PTX(va)]);	
f01011fb:	c1 ee 0a             	shr    $0xa,%esi
f01011fe:	81 e6 fc 0f 00 00    	and    $0xffc,%esi

	return page_table_entry;
f0101204:	8d 84 30 00 00 00 f0 	lea    -0x10000000(%eax,%esi,1),%eax
f010120b:	eb 0c                	jmp    f0101219 <pgdir_walk+0x99>
	pte_t* page_table_entry = NULL;

	if(!(PTE_P & *page_dir_entry))
	{
		if(create==false)
			return NULL;
f010120d:	b8 00 00 00 00       	mov    $0x0,%eax
f0101212:	eb 05                	jmp    f0101219 <pgdir_walk+0x99>
		else
		{
			struct PageInfo *pp = page_alloc(1);
			if(pp==NULL)
				return NULL;
f0101214:	b8 00 00 00 00       	mov    $0x0,%eax
	// cprintf("Walk2!\n");
	pgtable = (pte_t*) KADDR(PTE_ADDR(*page_dir_entry));
	page_table_entry = (pte_t*)(&pgtable[PTX(va)]);	

	return page_table_entry;
}
f0101219:	83 c4 10             	add    $0x10,%esp
f010121c:	5b                   	pop    %ebx
f010121d:	5e                   	pop    %esi
f010121e:	5d                   	pop    %ebp
f010121f:	c3                   	ret    

f0101220 <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f0101220:	55                   	push   %ebp
f0101221:	89 e5                	mov    %esp,%ebp
f0101223:	57                   	push   %edi
f0101224:	56                   	push   %esi
f0101225:	53                   	push   %ebx
f0101226:	83 ec 2c             	sub    $0x2c,%esp
f0101229:	89 c7                	mov    %eax,%edi
f010122b:	89 d6                	mov    %edx,%esi
f010122d:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
	// Fill this function in
	pte_t *page_table_entry;
	size_t offset = 0;
f0101230:	bb 00 00 00 00       	mov    $0x0,%ebx
	while(offset<size){
		page_table_entry = pgdir_walk(pgdir, (void*)(va + offset), true);
		*page_table_entry = (pa+offset)|perm|PTE_P;	
f0101235:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101238:	83 c8 01             	or     $0x1,%eax
f010123b:	89 45 e0             	mov    %eax,-0x20(%ebp)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// Fill this function in
	pte_t *page_table_entry;
	size_t offset = 0;
	while(offset<size){
f010123e:	eb 27                	jmp    f0101267 <boot_map_region+0x47>
		page_table_entry = pgdir_walk(pgdir, (void*)(va + offset), true);
f0101240:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101247:	00 
f0101248:	8d 04 33             	lea    (%ebx,%esi,1),%eax
f010124b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010124f:	89 3c 24             	mov    %edi,(%esp)
f0101252:	e8 29 ff ff ff       	call   f0101180 <pgdir_walk>
f0101257:	89 da                	mov    %ebx,%edx
f0101259:	03 55 08             	add    0x8(%ebp),%edx
		*page_table_entry = (pa+offset)|perm|PTE_P;	
f010125c:	0b 55 e0             	or     -0x20(%ebp),%edx
f010125f:	89 10                	mov    %edx,(%eax)
		offset += PGSIZE;
f0101261:	81 c3 00 10 00 00    	add    $0x1000,%ebx
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// Fill this function in
	pte_t *page_table_entry;
	size_t offset = 0;
	while(offset<size){
f0101267:	3b 5d e4             	cmp    -0x1c(%ebp),%ebx
f010126a:	72 d4                	jb     f0101240 <boot_map_region+0x20>
		page_table_entry = pgdir_walk(pgdir, (void*)(va + offset), true);
		*page_table_entry = (pa+offset)|perm|PTE_P;	
		offset += PGSIZE;
	}
}
f010126c:	83 c4 2c             	add    $0x2c,%esp
f010126f:	5b                   	pop    %ebx
f0101270:	5e                   	pop    %esi
f0101271:	5f                   	pop    %edi
f0101272:	5d                   	pop    %ebp
f0101273:	c3                   	ret    

f0101274 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct PageInfo *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101274:	55                   	push   %ebp
f0101275:	89 e5                	mov    %esp,%ebp
f0101277:	53                   	push   %ebx
f0101278:	83 ec 14             	sub    $0x14,%esp
f010127b:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in

	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);
f010127e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101285:	00 
f0101286:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101289:	89 44 24 04          	mov    %eax,0x4(%esp)
f010128d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101290:	89 04 24             	mov    %eax,(%esp)
f0101293:	e8 e8 fe ff ff       	call   f0101180 <pgdir_walk>

	if(page_table_entry==NULL){
f0101298:	85 c0                	test   %eax,%eax
f010129a:	74 3e                	je     f01012da <page_lookup+0x66>
		return NULL;
	}

	if(pte_store!=NULL){
f010129c:	85 db                	test   %ebx,%ebx
f010129e:	74 02                	je     f01012a2 <page_lookup+0x2e>
		*pte_store = page_table_entry;		
f01012a0:	89 03                	mov    %eax,(%ebx)
	}

	if(!(PTE_P & *page_table_entry)){
f01012a2:	8b 00                	mov    (%eax),%eax
f01012a4:	a8 01                	test   $0x1,%al
f01012a6:	74 39                	je     f01012e1 <page_lookup+0x6d>
}

static inline struct PageInfo*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01012a8:	c1 e8 0c             	shr    $0xc,%eax
f01012ab:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f01012b1:	72 1c                	jb     f01012cf <page_lookup+0x5b>
		panic("pa2page called with invalid pa");
f01012b3:	c7 44 24 08 a8 75 10 	movl   $0xf01075a8,0x8(%esp)
f01012ba:	f0 
f01012bb:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f01012c2:	00 
f01012c3:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f01012ca:	e8 71 ed ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01012cf:	8b 15 90 1e 23 f0    	mov    0xf0231e90,%edx
f01012d5:	8d 04 c2             	lea    (%edx,%eax,8),%eax

		return NULL;
	}

	return pa2page(PTE_ADDR(*page_table_entry));
f01012d8:	eb 0c                	jmp    f01012e6 <page_lookup+0x72>
	// Fill this function in

	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);

	if(page_table_entry==NULL){
		return NULL;
f01012da:	b8 00 00 00 00       	mov    $0x0,%eax
f01012df:	eb 05                	jmp    f01012e6 <page_lookup+0x72>
		*pte_store = page_table_entry;		
	}

	if(!(PTE_P & *page_table_entry)){

		return NULL;
f01012e1:	b8 00 00 00 00       	mov    $0x0,%eax
	}

	return pa2page(PTE_ADDR(*page_table_entry));

}
f01012e6:	83 c4 14             	add    $0x14,%esp
f01012e9:	5b                   	pop    %ebx
f01012ea:	5d                   	pop    %ebp
f01012eb:	c3                   	ret    

f01012ec <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f01012ec:	55                   	push   %ebp
f01012ed:	89 e5                	mov    %esp,%ebp
f01012ef:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01012f2:	e8 82 55 00 00       	call   f0106879 <cpunum>
f01012f7:	6b c0 74             	imul   $0x74,%eax,%eax
f01012fa:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f0101301:	74 16                	je     f0101319 <tlb_invalidate+0x2d>
f0101303:	e8 71 55 00 00       	call   f0106879 <cpunum>
f0101308:	6b c0 74             	imul   $0x74,%eax,%eax
f010130b:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0101311:	8b 55 08             	mov    0x8(%ebp),%edx
f0101314:	39 50 60             	cmp    %edx,0x60(%eax)
f0101317:	75 06                	jne    f010131f <tlb_invalidate+0x33>
}

static __inline void
invlpg(void *addr)
{
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0101319:	8b 45 0c             	mov    0xc(%ebp),%eax
f010131c:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f010131f:	c9                   	leave  
f0101320:	c3                   	ret    

f0101321 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0101321:	55                   	push   %ebp
f0101322:	89 e5                	mov    %esp,%ebp
f0101324:	56                   	push   %esi
f0101325:	53                   	push   %ebx
f0101326:	83 ec 10             	sub    $0x10,%esp
f0101329:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010132c:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	struct PageInfo *pp = page_lookup(pgdir, va, NULL);
f010132f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101336:	00 
f0101337:	89 74 24 04          	mov    %esi,0x4(%esp)
f010133b:	89 1c 24             	mov    %ebx,(%esp)
f010133e:	e8 31 ff ff ff       	call   f0101274 <page_lookup>

	if(pp==NULL){
f0101343:	85 c0                	test   %eax,%eax
f0101345:	74 44                	je     f010138b <page_remove+0x6a>
		return;
	}

	page_decref(pp);
f0101347:	89 04 24             	mov    %eax,(%esp)
f010134a:	e8 0e fe ff ff       	call   f010115d <page_decref>

	pte_t* x = pgdir_walk(pgdir, va, false);
f010134f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101356:	00 
f0101357:	89 74 24 04          	mov    %esi,0x4(%esp)
f010135b:	89 1c 24             	mov    %ebx,(%esp)
f010135e:	e8 1d fe ff ff       	call   f0101180 <pgdir_walk>

	if(x!=NULL){
f0101363:	85 c0                	test   %eax,%eax
f0101365:	74 18                	je     f010137f <page_remove+0x5e>
		memset(x, 0, sizeof(pte_t));	
f0101367:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f010136e:	00 
f010136f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101376:	00 
f0101377:	89 04 24             	mov    %eax,(%esp)
f010137a:	e8 a8 4e 00 00       	call   f0106227 <memset>
	}

	tlb_invalidate(pgdir, va);
f010137f:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101383:	89 1c 24             	mov    %ebx,(%esp)
f0101386:	e8 61 ff ff ff       	call   f01012ec <tlb_invalidate>

}
f010138b:	83 c4 10             	add    $0x10,%esp
f010138e:	5b                   	pop    %ebx
f010138f:	5e                   	pop    %esi
f0101390:	5d                   	pop    %ebp
f0101391:	c3                   	ret    

f0101392 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm)
{
f0101392:	55                   	push   %ebp
f0101393:	89 e5                	mov    %esp,%ebp
f0101395:	57                   	push   %edi
f0101396:	56                   	push   %esi
f0101397:	53                   	push   %ebx
f0101398:	83 ec 1c             	sub    $0x1c,%esp
f010139b:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010139e:	8b 7d 10             	mov    0x10(%ebp),%edi
	// Fill this function in

	pte_t* page_table_entry = pgdir_walk(pgdir, va, true);	
f01013a1:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01013a8:	00 
f01013a9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01013ad:	8b 45 08             	mov    0x8(%ebp),%eax
f01013b0:	89 04 24             	mov    %eax,(%esp)
f01013b3:	e8 c8 fd ff ff       	call   f0101180 <pgdir_walk>
f01013b8:	89 c6                	mov    %eax,%esi

	if(page_table_entry==NULL)
f01013ba:	85 c0                	test   %eax,%eax
f01013bc:	74 49                	je     f0101407 <page_insert+0x75>
		return -E_NO_MEM;

	page_remove(pgdir, va);
f01013be:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01013c2:	8b 45 08             	mov    0x8(%ebp),%eax
f01013c5:	89 04 24             	mov    %eax,(%esp)
f01013c8:	e8 54 ff ff ff       	call   f0101321 <page_remove>

	if(page_free_list == pp){
f01013cd:	39 1d 40 12 23 f0    	cmp    %ebx,0xf0231240
f01013d3:	75 0e                	jne    f01013e3 <page_insert+0x51>
		pp = page_alloc(0);
f01013d5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013dc:	e8 95 fc ff ff       	call   f0101076 <page_alloc>
f01013e1:	89 c3                	mov    %eax,%ebx
	}

	*page_table_entry = page2pa(pp)|perm|PTE_P;
f01013e3:	8b 55 14             	mov    0x14(%ebp),%edx
f01013e6:	83 ca 01             	or     $0x1,%edx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f01013e9:	89 d8                	mov    %ebx,%eax
f01013eb:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f01013f1:	c1 f8 03             	sar    $0x3,%eax
f01013f4:	c1 e0 0c             	shl    $0xc,%eax
f01013f7:	09 d0                	or     %edx,%eax
f01013f9:	89 06                	mov    %eax,(%esi)
	pp->pp_ref++;
f01013fb:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0;
f0101400:	b8 00 00 00 00       	mov    $0x0,%eax
f0101405:	eb 05                	jmp    f010140c <page_insert+0x7a>
	// Fill this function in

	pte_t* page_table_entry = pgdir_walk(pgdir, va, true);	

	if(page_table_entry==NULL)
		return -E_NO_MEM;
f0101407:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

	*page_table_entry = page2pa(pp)|perm|PTE_P;
	pp->pp_ref++;

	return 0;
}
f010140c:	83 c4 1c             	add    $0x1c,%esp
f010140f:	5b                   	pop    %ebx
f0101410:	5e                   	pop    %esi
f0101411:	5f                   	pop    %edi
f0101412:	5d                   	pop    %ebp
f0101413:	c3                   	ret    

f0101414 <mmio_map_region>:
// location.  Return the base of the reserved region.  size does *not*
// have to be multiple of PGSIZE.
//
void *
mmio_map_region(physaddr_t pa, size_t size)
{
f0101414:	55                   	push   %ebp
f0101415:	89 e5                	mov    %esp,%ebp
f0101417:	53                   	push   %ebx
f0101418:	83 ec 14             	sub    $0x14,%esp
	//
	// Hint: The staff solution uses boot_map_region.
	//
	// Your code here:

	size_t rounded_size = ROUNDUP(size, PGSIZE);
f010141b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010141e:	8d 88 ff 0f 00 00    	lea    0xfff(%eax),%ecx
f0101424:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
	uintptr_t addr = base;
f010142a:	8b 1d 00 13 12 f0    	mov    0xf0121300,%ebx
	base += rounded_size;
f0101430:	8d 04 19             	lea    (%ecx,%ebx,1),%eax
f0101433:	a3 00 13 12 f0       	mov    %eax,0xf0121300
	if(base>MMIOLIM)
f0101438:	3d 00 00 c0 ef       	cmp    $0xefc00000,%eax
f010143d:	76 1c                	jbe    f010145b <mmio_map_region+0x47>
		panic("MMIO memory overflow");
f010143f:	c7 44 24 08 eb 7e 10 	movl   $0xf0107eeb,0x8(%esp)
f0101446:	f0 
f0101447:	c7 44 24 04 99 02 00 	movl   $0x299,0x4(%esp)
f010144e:	00 
f010144f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101456:	e8 e5 eb ff ff       	call   f0100040 <_panic>
	boot_map_region(kern_pgdir, addr, rounded_size, pa, PTE_PCD|PTE_PWT|PTE_W);
f010145b:	c7 44 24 04 1a 00 00 	movl   $0x1a,0x4(%esp)
f0101462:	00 
f0101463:	8b 45 08             	mov    0x8(%ebp),%eax
f0101466:	89 04 24             	mov    %eax,(%esp)
f0101469:	89 da                	mov    %ebx,%edx
f010146b:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101470:	e8 ab fd ff ff       	call   f0101220 <boot_map_region>
	return (void*)addr;
}
f0101475:	89 d8                	mov    %ebx,%eax
f0101477:	83 c4 14             	add    $0x14,%esp
f010147a:	5b                   	pop    %ebx
f010147b:	5d                   	pop    %ebp
f010147c:	c3                   	ret    

f010147d <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f010147d:	55                   	push   %ebp
f010147e:	89 e5                	mov    %esp,%ebp
f0101480:	57                   	push   %edi
f0101481:	56                   	push   %esi
f0101482:	53                   	push   %ebx
f0101483:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101486:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f010148d:	e8 3c 29 00 00       	call   f0103dce <mc146818_read>
f0101492:	89 c3                	mov    %eax,%ebx
f0101494:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010149b:	e8 2e 29 00 00       	call   f0103dce <mc146818_read>
f01014a0:	c1 e0 08             	shl    $0x8,%eax
f01014a3:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014a5:	89 d8                	mov    %ebx,%eax
f01014a7:	c1 e0 0a             	shl    $0xa,%eax
f01014aa:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014b0:	85 c0                	test   %eax,%eax
f01014b2:	0f 48 c2             	cmovs  %edx,%eax
f01014b5:	c1 f8 0c             	sar    $0xc,%eax
f01014b8:	a3 44 12 23 f0       	mov    %eax,0xf0231244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014bd:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014c4:	e8 05 29 00 00       	call   f0103dce <mc146818_read>
f01014c9:	89 c3                	mov    %eax,%ebx
f01014cb:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01014d2:	e8 f7 28 00 00       	call   f0103dce <mc146818_read>
f01014d7:	c1 e0 08             	shl    $0x8,%eax
f01014da:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01014dc:	89 d8                	mov    %ebx,%eax
f01014de:	c1 e0 0a             	shl    $0xa,%eax
f01014e1:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014e7:	85 c0                	test   %eax,%eax
f01014e9:	0f 48 c2             	cmovs  %edx,%eax
f01014ec:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f01014ef:	85 c0                	test   %eax,%eax
f01014f1:	74 0e                	je     f0101501 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f01014f3:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f01014f9:	89 15 88 1e 23 f0    	mov    %edx,0xf0231e88
f01014ff:	eb 0c                	jmp    f010150d <mem_init+0x90>
	else
		npages = npages_basemem;
f0101501:	8b 15 44 12 23 f0    	mov    0xf0231244,%edx
f0101507:	89 15 88 1e 23 f0    	mov    %edx,0xf0231e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f010150d:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101510:	c1 e8 0a             	shr    $0xa,%eax
f0101513:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101517:	a1 44 12 23 f0       	mov    0xf0231244,%eax
f010151c:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f010151f:	c1 e8 0a             	shr    $0xa,%eax
f0101522:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101526:	a1 88 1e 23 f0       	mov    0xf0231e88,%eax
f010152b:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f010152e:	c1 e8 0a             	shr    $0xa,%eax
f0101531:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101535:	c7 04 24 c8 75 10 f0 	movl   $0xf01075c8,(%esp)
f010153c:	e8 f6 29 00 00       	call   f0103f37 <cprintf>
	// Remove this line when you're ready to test this function.
	// panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f0101541:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101546:	e8 d5 f5 ff ff       	call   f0100b20 <boot_alloc>
f010154b:	a3 8c 1e 23 f0       	mov    %eax,0xf0231e8c
	memset(kern_pgdir, 0, PGSIZE);
f0101550:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101557:	00 
f0101558:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010155f:	00 
f0101560:	89 04 24             	mov    %eax,(%esp)
f0101563:	e8 bf 4c 00 00       	call   f0106227 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following line.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f0101568:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010156d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101572:	77 20                	ja     f0101594 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101574:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101578:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f010157f:	f0 
f0101580:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f0101587:	00 
f0101588:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010158f:	e8 ac ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101594:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010159a:	83 ca 05             	or     $0x5,%edx
f010159d:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// each physical page, there is a corresponding struct PageInfo in this
	// array.  'npages' is the number of physical pages in memory.  Use memset
	// to initialize all fields of each struct PageInfo to 0.
	// Your code goes here:

	pages = (struct PageInfo*) boot_alloc(npages*sizeof(struct PageInfo));
f01015a3:	a1 88 1e 23 f0       	mov    0xf0231e88,%eax
f01015a8:	c1 e0 03             	shl    $0x3,%eax
f01015ab:	e8 70 f5 ff ff       	call   f0100b20 <boot_alloc>
f01015b0:	a3 90 1e 23 f0       	mov    %eax,0xf0231e90

	memset(pages, 0, npages*sizeof(struct PageInfo));
f01015b5:	8b 0d 88 1e 23 f0    	mov    0xf0231e88,%ecx
f01015bb:	8d 14 cd 00 00 00 00 	lea    0x0(,%ecx,8),%edx
f01015c2:	89 54 24 08          	mov    %edx,0x8(%esp)
f01015c6:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015cd:	00 
f01015ce:	89 04 24             	mov    %eax,(%esp)
f01015d1:	e8 51 4c 00 00       	call   f0106227 <memset>

	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.

	envs = (struct Env*) boot_alloc(NENV*sizeof(struct Env));
f01015d6:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015db:	e8 40 f5 ff ff       	call   f0100b20 <boot_alloc>
f01015e0:	a3 48 12 23 f0       	mov    %eax,0xf0231248

	memset(envs, 0, NENV*sizeof(struct Env));
f01015e5:	c7 44 24 08 00 f0 01 	movl   $0x1f000,0x8(%esp)
f01015ec:	00 
f01015ed:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015f4:	00 
f01015f5:	89 04 24             	mov    %eax,(%esp)
f01015f8:	e8 2a 4c 00 00       	call   f0106227 <memset>
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f01015fd:	e8 ab f9 ff ff       	call   f0100fad <page_init>

	check_page_free_list(1);
f0101602:	b8 01 00 00 00       	mov    $0x1,%eax
f0101607:	e8 0b f6 ff ff       	call   f0100c17 <check_page_free_list>
	char *c;
	int i;

	// cprintf("Here-3!\n");

	if (!pages)
f010160c:	83 3d 90 1e 23 f0 00 	cmpl   $0x0,0xf0231e90
f0101613:	75 1c                	jne    f0101631 <mem_init+0x1b4>
		panic("'pages' is a null pointer!");
f0101615:	c7 44 24 08 00 7f 10 	movl   $0xf0107f00,0x8(%esp)
f010161c:	f0 
f010161d:	c7 44 24 04 47 03 00 	movl   $0x347,0x4(%esp)
f0101624:	00 
f0101625:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010162c:	e8 0f ea ff ff       	call   f0100040 <_panic>

	// cprintf("Here-2!\n");
	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101631:	a1 40 12 23 f0       	mov    0xf0231240,%eax
f0101636:	bb 00 00 00 00       	mov    $0x0,%ebx
f010163b:	eb 05                	jmp    f0101642 <mem_init+0x1c5>
		++nfree;
f010163d:	83 c3 01             	add    $0x1,%ebx
	if (!pages)
		panic("'pages' is a null pointer!");

	// cprintf("Here-2!\n");
	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101640:	8b 00                	mov    (%eax),%eax
f0101642:	85 c0                	test   %eax,%eax
f0101644:	75 f7                	jne    f010163d <mem_init+0x1c0>

	// cprintf("Here-1!\n");

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101646:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010164d:	e8 24 fa ff ff       	call   f0101076 <page_alloc>
f0101652:	89 c7                	mov    %eax,%edi
f0101654:	85 c0                	test   %eax,%eax
f0101656:	75 24                	jne    f010167c <mem_init+0x1ff>
f0101658:	c7 44 24 0c 1b 7f 10 	movl   $0xf0107f1b,0xc(%esp)
f010165f:	f0 
f0101660:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101667:	f0 
f0101668:	c7 44 24 04 52 03 00 	movl   $0x352,0x4(%esp)
f010166f:	00 
f0101670:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101677:	e8 c4 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010167c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101683:	e8 ee f9 ff ff       	call   f0101076 <page_alloc>
f0101688:	89 c6                	mov    %eax,%esi
f010168a:	85 c0                	test   %eax,%eax
f010168c:	75 24                	jne    f01016b2 <mem_init+0x235>
f010168e:	c7 44 24 0c 31 7f 10 	movl   $0xf0107f31,0xc(%esp)
f0101695:	f0 
f0101696:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010169d:	f0 
f010169e:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f01016a5:	00 
f01016a6:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01016ad:	e8 8e e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016b2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016b9:	e8 b8 f9 ff ff       	call   f0101076 <page_alloc>
f01016be:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016c1:	85 c0                	test   %eax,%eax
f01016c3:	75 24                	jne    f01016e9 <mem_init+0x26c>
f01016c5:	c7 44 24 0c 47 7f 10 	movl   $0xf0107f47,0xc(%esp)
f01016cc:	f0 
f01016cd:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01016d4:	f0 
f01016d5:	c7 44 24 04 54 03 00 	movl   $0x354,0x4(%esp)
f01016dc:	00 
f01016dd:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01016e4:	e8 57 e9 ff ff       	call   f0100040 <_panic>

	// cprintf("Here0!\n");

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01016e9:	39 f7                	cmp    %esi,%edi
f01016eb:	75 24                	jne    f0101711 <mem_init+0x294>
f01016ed:	c7 44 24 0c 5d 7f 10 	movl   $0xf0107f5d,0xc(%esp)
f01016f4:	f0 
f01016f5:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01016fc:	f0 
f01016fd:	c7 44 24 04 59 03 00 	movl   $0x359,0x4(%esp)
f0101704:	00 
f0101705:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010170c:	e8 2f e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101711:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101714:	39 c6                	cmp    %eax,%esi
f0101716:	74 04                	je     f010171c <mem_init+0x29f>
f0101718:	39 c7                	cmp    %eax,%edi
f010171a:	75 24                	jne    f0101740 <mem_init+0x2c3>
f010171c:	c7 44 24 0c 04 76 10 	movl   $0xf0107604,0xc(%esp)
f0101723:	f0 
f0101724:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010172b:	f0 
f010172c:	c7 44 24 04 5a 03 00 	movl   $0x35a,0x4(%esp)
f0101733:	00 
f0101734:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010173b:	e8 00 e9 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0101740:	8b 15 90 1e 23 f0    	mov    0xf0231e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101746:	a1 88 1e 23 f0       	mov    0xf0231e88,%eax
f010174b:	c1 e0 0c             	shl    $0xc,%eax
f010174e:	89 f9                	mov    %edi,%ecx
f0101750:	29 d1                	sub    %edx,%ecx
f0101752:	c1 f9 03             	sar    $0x3,%ecx
f0101755:	c1 e1 0c             	shl    $0xc,%ecx
f0101758:	39 c1                	cmp    %eax,%ecx
f010175a:	72 24                	jb     f0101780 <mem_init+0x303>
f010175c:	c7 44 24 0c 6f 7f 10 	movl   $0xf0107f6f,0xc(%esp)
f0101763:	f0 
f0101764:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010176b:	f0 
f010176c:	c7 44 24 04 5b 03 00 	movl   $0x35b,0x4(%esp)
f0101773:	00 
f0101774:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010177b:	e8 c0 e8 ff ff       	call   f0100040 <_panic>
f0101780:	89 f1                	mov    %esi,%ecx
f0101782:	29 d1                	sub    %edx,%ecx
f0101784:	c1 f9 03             	sar    $0x3,%ecx
f0101787:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f010178a:	39 c8                	cmp    %ecx,%eax
f010178c:	77 24                	ja     f01017b2 <mem_init+0x335>
f010178e:	c7 44 24 0c 8c 7f 10 	movl   $0xf0107f8c,0xc(%esp)
f0101795:	f0 
f0101796:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010179d:	f0 
f010179e:	c7 44 24 04 5c 03 00 	movl   $0x35c,0x4(%esp)
f01017a5:	00 
f01017a6:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01017ad:	e8 8e e8 ff ff       	call   f0100040 <_panic>
f01017b2:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017b5:	29 d1                	sub    %edx,%ecx
f01017b7:	89 ca                	mov    %ecx,%edx
f01017b9:	c1 fa 03             	sar    $0x3,%edx
f01017bc:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017bf:	39 d0                	cmp    %edx,%eax
f01017c1:	77 24                	ja     f01017e7 <mem_init+0x36a>
f01017c3:	c7 44 24 0c a9 7f 10 	movl   $0xf0107fa9,0xc(%esp)
f01017ca:	f0 
f01017cb:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01017d2:	f0 
f01017d3:	c7 44 24 04 5d 03 00 	movl   $0x35d,0x4(%esp)
f01017da:	00 
f01017db:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01017e2:	e8 59 e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01017e7:	a1 40 12 23 f0       	mov    0xf0231240,%eax
f01017ec:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f01017ef:	c7 05 40 12 23 f0 00 	movl   $0x0,0xf0231240
f01017f6:	00 00 00 

	// cprintf("Here1!\n");

	// should be no free memory
	assert(!page_alloc(0));
f01017f9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101800:	e8 71 f8 ff ff       	call   f0101076 <page_alloc>
f0101805:	85 c0                	test   %eax,%eax
f0101807:	74 24                	je     f010182d <mem_init+0x3b0>
f0101809:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0101810:	f0 
f0101811:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101818:	f0 
f0101819:	c7 44 24 04 66 03 00 	movl   $0x366,0x4(%esp)
f0101820:	00 
f0101821:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101828:	e8 13 e8 ff ff       	call   f0100040 <_panic>

	// cprintf("Here112!\n");

	// free and re-allocate?
	page_free(pp0);
f010182d:	89 3c 24             	mov    %edi,(%esp)
f0101830:	e8 cc f8 ff ff       	call   f0101101 <page_free>
	page_free(pp1);
f0101835:	89 34 24             	mov    %esi,(%esp)
f0101838:	e8 c4 f8 ff ff       	call   f0101101 <page_free>
	page_free(pp2);
f010183d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101840:	89 04 24             	mov    %eax,(%esp)
f0101843:	e8 b9 f8 ff ff       	call   f0101101 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101848:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010184f:	e8 22 f8 ff ff       	call   f0101076 <page_alloc>
f0101854:	89 c6                	mov    %eax,%esi
f0101856:	85 c0                	test   %eax,%eax
f0101858:	75 24                	jne    f010187e <mem_init+0x401>
f010185a:	c7 44 24 0c 1b 7f 10 	movl   $0xf0107f1b,0xc(%esp)
f0101861:	f0 
f0101862:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101869:	f0 
f010186a:	c7 44 24 04 6f 03 00 	movl   $0x36f,0x4(%esp)
f0101871:	00 
f0101872:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101879:	e8 c2 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010187e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101885:	e8 ec f7 ff ff       	call   f0101076 <page_alloc>
f010188a:	89 c7                	mov    %eax,%edi
f010188c:	85 c0                	test   %eax,%eax
f010188e:	75 24                	jne    f01018b4 <mem_init+0x437>
f0101890:	c7 44 24 0c 31 7f 10 	movl   $0xf0107f31,0xc(%esp)
f0101897:	f0 
f0101898:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010189f:	f0 
f01018a0:	c7 44 24 04 70 03 00 	movl   $0x370,0x4(%esp)
f01018a7:	00 
f01018a8:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01018af:	e8 8c e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018b4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018bb:	e8 b6 f7 ff ff       	call   f0101076 <page_alloc>
f01018c0:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018c3:	85 c0                	test   %eax,%eax
f01018c5:	75 24                	jne    f01018eb <mem_init+0x46e>
f01018c7:	c7 44 24 0c 47 7f 10 	movl   $0xf0107f47,0xc(%esp)
f01018ce:	f0 
f01018cf:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01018d6:	f0 
f01018d7:	c7 44 24 04 71 03 00 	movl   $0x371,0x4(%esp)
f01018de:	00 
f01018df:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01018e6:	e8 55 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018eb:	39 fe                	cmp    %edi,%esi
f01018ed:	75 24                	jne    f0101913 <mem_init+0x496>
f01018ef:	c7 44 24 0c 5d 7f 10 	movl   $0xf0107f5d,0xc(%esp)
f01018f6:	f0 
f01018f7:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01018fe:	f0 
f01018ff:	c7 44 24 04 73 03 00 	movl   $0x373,0x4(%esp)
f0101906:	00 
f0101907:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010190e:	e8 2d e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101913:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101916:	39 c7                	cmp    %eax,%edi
f0101918:	74 04                	je     f010191e <mem_init+0x4a1>
f010191a:	39 c6                	cmp    %eax,%esi
f010191c:	75 24                	jne    f0101942 <mem_init+0x4c5>
f010191e:	c7 44 24 0c 04 76 10 	movl   $0xf0107604,0xc(%esp)
f0101925:	f0 
f0101926:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010192d:	f0 
f010192e:	c7 44 24 04 74 03 00 	movl   $0x374,0x4(%esp)
f0101935:	00 
f0101936:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010193d:	e8 fe e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f0101942:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101949:	e8 28 f7 ff ff       	call   f0101076 <page_alloc>
f010194e:	85 c0                	test   %eax,%eax
f0101950:	74 24                	je     f0101976 <mem_init+0x4f9>
f0101952:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0101959:	f0 
f010195a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101961:	f0 
f0101962:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
f0101969:	00 
f010196a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101971:	e8 ca e6 ff ff       	call   f0100040 <_panic>
f0101976:	89 f0                	mov    %esi,%eax
f0101978:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f010197e:	c1 f8 03             	sar    $0x3,%eax
f0101981:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101984:	89 c2                	mov    %eax,%edx
f0101986:	c1 ea 0c             	shr    $0xc,%edx
f0101989:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f010198f:	72 20                	jb     f01019b1 <mem_init+0x534>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101991:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101995:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f010199c:	f0 
f010199d:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f01019a4:	00 
f01019a5:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f01019ac:	e8 8f e6 ff ff       	call   f0100040 <_panic>

	// cprintf("Here2!\n");

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019b1:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019b8:	00 
f01019b9:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019c0:	00 
	return (void *)(pa + KERNBASE);
f01019c1:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019c6:	89 04 24             	mov    %eax,(%esp)
f01019c9:	e8 59 48 00 00       	call   f0106227 <memset>
	page_free(pp0);
f01019ce:	89 34 24             	mov    %esi,(%esp)
f01019d1:	e8 2b f7 ff ff       	call   f0101101 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019d6:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019dd:	e8 94 f6 ff ff       	call   f0101076 <page_alloc>
f01019e2:	85 c0                	test   %eax,%eax
f01019e4:	75 24                	jne    f0101a0a <mem_init+0x58d>
f01019e6:	c7 44 24 0c d5 7f 10 	movl   $0xf0107fd5,0xc(%esp)
f01019ed:	f0 
f01019ee:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01019f5:	f0 
f01019f6:	c7 44 24 04 7c 03 00 	movl   $0x37c,0x4(%esp)
f01019fd:	00 
f01019fe:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101a05:	e8 36 e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a0a:	39 c6                	cmp    %eax,%esi
f0101a0c:	74 24                	je     f0101a32 <mem_init+0x5b5>
f0101a0e:	c7 44 24 0c f3 7f 10 	movl   $0xf0107ff3,0xc(%esp)
f0101a15:	f0 
f0101a16:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101a1d:	f0 
f0101a1e:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0101a25:	00 
f0101a26:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101a2d:	e8 0e e6 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a32:	89 f0                	mov    %esi,%eax
f0101a34:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f0101a3a:	c1 f8 03             	sar    $0x3,%eax
f0101a3d:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a40:	89 c2                	mov    %eax,%edx
f0101a42:	c1 ea 0c             	shr    $0xc,%edx
f0101a45:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f0101a4b:	72 20                	jb     f0101a6d <mem_init+0x5f0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a4d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101a51:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0101a58:	f0 
f0101a59:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0101a60:	00 
f0101a61:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0101a68:	e8 d3 e5 ff ff       	call   f0100040 <_panic>
f0101a6d:	8d 90 00 10 00 f0    	lea    -0xffff000(%eax),%edx
	return (void *)(pa + KERNBASE);
f0101a73:	8d 80 00 00 00 f0    	lea    -0x10000000(%eax),%eax
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a79:	80 38 00             	cmpb   $0x0,(%eax)
f0101a7c:	74 24                	je     f0101aa2 <mem_init+0x625>
f0101a7e:	c7 44 24 0c 03 80 10 	movl   $0xf0108003,0xc(%esp)
f0101a85:	f0 
f0101a86:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101a8d:	f0 
f0101a8e:	c7 44 24 04 80 03 00 	movl   $0x380,0x4(%esp)
f0101a95:	00 
f0101a96:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101a9d:	e8 9e e5 ff ff       	call   f0100040 <_panic>
f0101aa2:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101aa5:	39 d0                	cmp    %edx,%eax
f0101aa7:	75 d0                	jne    f0101a79 <mem_init+0x5fc>
		assert(c[i] == 0);

	// cprintf("Here3!\n");

	// give free list back
	page_free_list = fl;
f0101aa9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101aac:	a3 40 12 23 f0       	mov    %eax,0xf0231240

	// free the pages we took
	page_free(pp0);
f0101ab1:	89 34 24             	mov    %esi,(%esp)
f0101ab4:	e8 48 f6 ff ff       	call   f0101101 <page_free>
	page_free(pp1);
f0101ab9:	89 3c 24             	mov    %edi,(%esp)
f0101abc:	e8 40 f6 ff ff       	call   f0101101 <page_free>
	page_free(pp2);
f0101ac1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ac4:	89 04 24             	mov    %eax,(%esp)
f0101ac7:	e8 35 f6 ff ff       	call   f0101101 <page_free>

	// cprintf("Here4!\n");

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101acc:	a1 40 12 23 f0       	mov    0xf0231240,%eax
f0101ad1:	eb 05                	jmp    f0101ad8 <mem_init+0x65b>
		--nfree;
f0101ad3:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp2);

	// cprintf("Here4!\n");

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101ad6:	8b 00                	mov    (%eax),%eax
f0101ad8:	85 c0                	test   %eax,%eax
f0101ada:	75 f7                	jne    f0101ad3 <mem_init+0x656>
		--nfree;
	assert(nfree == 0);
f0101adc:	85 db                	test   %ebx,%ebx
f0101ade:	74 24                	je     f0101b04 <mem_init+0x687>
f0101ae0:	c7 44 24 0c 0d 80 10 	movl   $0xf010800d,0xc(%esp)
f0101ae7:	f0 
f0101ae8:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101aef:	f0 
f0101af0:	c7 44 24 04 91 03 00 	movl   $0x391,0x4(%esp)
f0101af7:	00 
f0101af8:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101aff:	e8 3c e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b04:	c7 04 24 24 76 10 f0 	movl   $0xf0107624,(%esp)
f0101b0b:	e8 27 24 00 00       	call   f0103f37 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b10:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b17:	e8 5a f5 ff ff       	call   f0101076 <page_alloc>
f0101b1c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b1f:	85 c0                	test   %eax,%eax
f0101b21:	75 24                	jne    f0101b47 <mem_init+0x6ca>
f0101b23:	c7 44 24 0c 1b 7f 10 	movl   $0xf0107f1b,0xc(%esp)
f0101b2a:	f0 
f0101b2b:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101b32:	f0 
f0101b33:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
f0101b3a:	00 
f0101b3b:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101b42:	e8 f9 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b47:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b4e:	e8 23 f5 ff ff       	call   f0101076 <page_alloc>
f0101b53:	89 c3                	mov    %eax,%ebx
f0101b55:	85 c0                	test   %eax,%eax
f0101b57:	75 24                	jne    f0101b7d <mem_init+0x700>
f0101b59:	c7 44 24 0c 31 7f 10 	movl   $0xf0107f31,0xc(%esp)
f0101b60:	f0 
f0101b61:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101b68:	f0 
f0101b69:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
f0101b70:	00 
f0101b71:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101b78:	e8 c3 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101b7d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b84:	e8 ed f4 ff ff       	call   f0101076 <page_alloc>
f0101b89:	89 c6                	mov    %eax,%esi
f0101b8b:	85 c0                	test   %eax,%eax
f0101b8d:	75 24                	jne    f0101bb3 <mem_init+0x736>
f0101b8f:	c7 44 24 0c 47 7f 10 	movl   $0xf0107f47,0xc(%esp)
f0101b96:	f0 
f0101b97:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101b9e:	f0 
f0101b9f:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f0101ba6:	00 
f0101ba7:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101bae:	e8 8d e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bb3:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0101bb6:	75 24                	jne    f0101bdc <mem_init+0x75f>
f0101bb8:	c7 44 24 0c 5d 7f 10 	movl   $0xf0107f5d,0xc(%esp)
f0101bbf:	f0 
f0101bc0:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101bc7:	f0 
f0101bc8:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f0101bcf:	00 
f0101bd0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101bd7:	e8 64 e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101bdc:	39 c3                	cmp    %eax,%ebx
f0101bde:	74 05                	je     f0101be5 <mem_init+0x768>
f0101be0:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101be3:	75 24                	jne    f0101c09 <mem_init+0x78c>
f0101be5:	c7 44 24 0c 04 76 10 	movl   $0xf0107604,0xc(%esp)
f0101bec:	f0 
f0101bed:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101bf4:	f0 
f0101bf5:	c7 44 24 04 03 04 00 	movl   $0x403,0x4(%esp)
f0101bfc:	00 
f0101bfd:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101c04:	e8 37 e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c09:	a1 40 12 23 f0       	mov    0xf0231240,%eax
f0101c0e:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c11:	c7 05 40 12 23 f0 00 	movl   $0x0,0xf0231240
f0101c18:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c1b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c22:	e8 4f f4 ff ff       	call   f0101076 <page_alloc>
f0101c27:	85 c0                	test   %eax,%eax
f0101c29:	74 24                	je     f0101c4f <mem_init+0x7d2>
f0101c2b:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0101c32:	f0 
f0101c33:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101c3a:	f0 
f0101c3b:	c7 44 24 04 0a 04 00 	movl   $0x40a,0x4(%esp)
f0101c42:	00 
f0101c43:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101c4a:	e8 f1 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c4f:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c52:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c56:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c5d:	00 
f0101c5e:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101c63:	89 04 24             	mov    %eax,(%esp)
f0101c66:	e8 09 f6 ff ff       	call   f0101274 <page_lookup>
f0101c6b:	85 c0                	test   %eax,%eax
f0101c6d:	74 24                	je     f0101c93 <mem_init+0x816>
f0101c6f:	c7 44 24 0c 44 76 10 	movl   $0xf0107644,0xc(%esp)
f0101c76:	f0 
f0101c77:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101c7e:	f0 
f0101c7f:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f0101c86:	00 
f0101c87:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101c8e:	e8 ad e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101c93:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101c9a:	00 
f0101c9b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101ca2:	00 
f0101ca3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101ca7:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101cac:	89 04 24             	mov    %eax,(%esp)
f0101caf:	e8 de f6 ff ff       	call   f0101392 <page_insert>
f0101cb4:	85 c0                	test   %eax,%eax
f0101cb6:	78 24                	js     f0101cdc <mem_init+0x85f>
f0101cb8:	c7 44 24 0c 7c 76 10 	movl   $0xf010767c,0xc(%esp)
f0101cbf:	f0 
f0101cc0:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101cc7:	f0 
f0101cc8:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f0101ccf:	00 
f0101cd0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101cd7:	e8 64 e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101cdc:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cdf:	89 04 24             	mov    %eax,(%esp)
f0101ce2:	e8 1a f4 ff ff       	call   f0101101 <page_free>

	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101ce7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cee:	00 
f0101cef:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cf6:	00 
f0101cf7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101cfb:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101d00:	89 04 24             	mov    %eax,(%esp)
f0101d03:	e8 8a f6 ff ff       	call   f0101392 <page_insert>
f0101d08:	85 c0                	test   %eax,%eax
f0101d0a:	74 24                	je     f0101d30 <mem_init+0x8b3>
f0101d0c:	c7 44 24 0c ac 76 10 	movl   $0xf01076ac,0xc(%esp)
f0101d13:	f0 
f0101d14:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101d1b:	f0 
f0101d1c:	c7 44 24 04 15 04 00 	movl   $0x415,0x4(%esp)
f0101d23:	00 
f0101d24:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101d2b:	e8 10 e3 ff ff       	call   f0100040 <_panic>

	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d30:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d36:	a1 90 1e 23 f0       	mov    0xf0231e90,%eax
f0101d3b:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101d3e:	8b 17                	mov    (%edi),%edx
f0101d40:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101d46:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0101d49:	29 c1                	sub    %eax,%ecx
f0101d4b:	89 c8                	mov    %ecx,%eax
f0101d4d:	c1 f8 03             	sar    $0x3,%eax
f0101d50:	c1 e0 0c             	shl    $0xc,%eax
f0101d53:	39 c2                	cmp    %eax,%edx
f0101d55:	74 24                	je     f0101d7b <mem_init+0x8fe>
f0101d57:	c7 44 24 0c dc 76 10 	movl   $0xf01076dc,0xc(%esp)
f0101d5e:	f0 
f0101d5f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101d66:	f0 
f0101d67:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f0101d6e:	00 
f0101d6f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101d76:	e8 c5 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101d7b:	ba 00 00 00 00       	mov    $0x0,%edx
f0101d80:	89 f8                	mov    %edi,%eax
f0101d82:	e8 21 ee ff ff       	call   f0100ba8 <check_va2pa>
f0101d87:	89 da                	mov    %ebx,%edx
f0101d89:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101d8c:	c1 fa 03             	sar    $0x3,%edx
f0101d8f:	c1 e2 0c             	shl    $0xc,%edx
f0101d92:	39 d0                	cmp    %edx,%eax
f0101d94:	74 24                	je     f0101dba <mem_init+0x93d>
f0101d96:	c7 44 24 0c 04 77 10 	movl   $0xf0107704,0xc(%esp)
f0101d9d:	f0 
f0101d9e:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101da5:	f0 
f0101da6:	c7 44 24 04 18 04 00 	movl   $0x418,0x4(%esp)
f0101dad:	00 
f0101dae:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101db5:	e8 86 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101dba:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101dbf:	74 24                	je     f0101de5 <mem_init+0x968>
f0101dc1:	c7 44 24 0c 18 80 10 	movl   $0xf0108018,0xc(%esp)
f0101dc8:	f0 
f0101dc9:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101dd0:	f0 
f0101dd1:	c7 44 24 04 19 04 00 	movl   $0x419,0x4(%esp)
f0101dd8:	00 
f0101dd9:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101de0:	e8 5b e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101de5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101de8:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101ded:	74 24                	je     f0101e13 <mem_init+0x996>
f0101def:	c7 44 24 0c 29 80 10 	movl   $0xf0108029,0xc(%esp)
f0101df6:	f0 
f0101df7:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101dfe:	f0 
f0101dff:	c7 44 24 04 1a 04 00 	movl   $0x41a,0x4(%esp)
f0101e06:	00 
f0101e07:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101e0e:	e8 2d e2 ff ff       	call   f0100040 <_panic>
	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e13:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e1a:	00 
f0101e1b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e22:	00 
f0101e23:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e27:	89 3c 24             	mov    %edi,(%esp)
f0101e2a:	e8 63 f5 ff ff       	call   f0101392 <page_insert>
f0101e2f:	85 c0                	test   %eax,%eax
f0101e31:	74 24                	je     f0101e57 <mem_init+0x9da>
f0101e33:	c7 44 24 0c 34 77 10 	movl   $0xf0107734,0xc(%esp)
f0101e3a:	f0 
f0101e3b:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101e42:	f0 
f0101e43:	c7 44 24 04 1c 04 00 	movl   $0x41c,0x4(%esp)
f0101e4a:	00 
f0101e4b:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101e52:	e8 e9 e1 ff ff       	call   f0100040 <_panic>
	// cprintf("func:%x\norig:%x\n", check_va2pa(kern_pgdir, PGSIZE), page2pa(pp2));
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e57:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e5c:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101e61:	e8 42 ed ff ff       	call   f0100ba8 <check_va2pa>
f0101e66:	89 f2                	mov    %esi,%edx
f0101e68:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f0101e6e:	c1 fa 03             	sar    $0x3,%edx
f0101e71:	c1 e2 0c             	shl    $0xc,%edx
f0101e74:	39 d0                	cmp    %edx,%eax
f0101e76:	74 24                	je     f0101e9c <mem_init+0xa1f>
f0101e78:	c7 44 24 0c 70 77 10 	movl   $0xf0107770,0xc(%esp)
f0101e7f:	f0 
f0101e80:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101e87:	f0 
f0101e88:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f0101e8f:	00 
f0101e90:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101e97:	e8 a4 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101e9c:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101ea1:	74 24                	je     f0101ec7 <mem_init+0xa4a>
f0101ea3:	c7 44 24 0c 3a 80 10 	movl   $0xf010803a,0xc(%esp)
f0101eaa:	f0 
f0101eab:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101eb2:	f0 
f0101eb3:	c7 44 24 04 1f 04 00 	movl   $0x41f,0x4(%esp)
f0101eba:	00 
f0101ebb:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101ec2:	e8 79 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101ec7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ece:	e8 a3 f1 ff ff       	call   f0101076 <page_alloc>
f0101ed3:	85 c0                	test   %eax,%eax
f0101ed5:	74 24                	je     f0101efb <mem_init+0xa7e>
f0101ed7:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0101ede:	f0 
f0101edf:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101ee6:	f0 
f0101ee7:	c7 44 24 04 22 04 00 	movl   $0x422,0x4(%esp)
f0101eee:	00 
f0101eef:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101ef6:	e8 45 e1 ff ff       	call   f0100040 <_panic>
	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101efb:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f02:	00 
f0101f03:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f0a:	00 
f0101f0b:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f0f:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101f14:	89 04 24             	mov    %eax,(%esp)
f0101f17:	e8 76 f4 ff ff       	call   f0101392 <page_insert>
f0101f1c:	85 c0                	test   %eax,%eax
f0101f1e:	74 24                	je     f0101f44 <mem_init+0xac7>
f0101f20:	c7 44 24 0c 34 77 10 	movl   $0xf0107734,0xc(%esp)
f0101f27:	f0 
f0101f28:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101f2f:	f0 
f0101f30:	c7 44 24 04 24 04 00 	movl   $0x424,0x4(%esp)
f0101f37:	00 
f0101f38:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101f3f:	e8 fc e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f44:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f49:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0101f4e:	e8 55 ec ff ff       	call   f0100ba8 <check_va2pa>
f0101f53:	89 f2                	mov    %esi,%edx
f0101f55:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f0101f5b:	c1 fa 03             	sar    $0x3,%edx
f0101f5e:	c1 e2 0c             	shl    $0xc,%edx
f0101f61:	39 d0                	cmp    %edx,%eax
f0101f63:	74 24                	je     f0101f89 <mem_init+0xb0c>
f0101f65:	c7 44 24 0c 70 77 10 	movl   $0xf0107770,0xc(%esp)
f0101f6c:	f0 
f0101f6d:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101f74:	f0 
f0101f75:	c7 44 24 04 25 04 00 	movl   $0x425,0x4(%esp)
f0101f7c:	00 
f0101f7d:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101f84:	e8 b7 e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101f89:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101f8e:	74 24                	je     f0101fb4 <mem_init+0xb37>
f0101f90:	c7 44 24 0c 3a 80 10 	movl   $0xf010803a,0xc(%esp)
f0101f97:	f0 
f0101f98:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101f9f:	f0 
f0101fa0:	c7 44 24 04 26 04 00 	movl   $0x426,0x4(%esp)
f0101fa7:	00 
f0101fa8:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101faf:	e8 8c e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101fb4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101fbb:	e8 b6 f0 ff ff       	call   f0101076 <page_alloc>
f0101fc0:	85 c0                	test   %eax,%eax
f0101fc2:	74 24                	je     f0101fe8 <mem_init+0xb6b>
f0101fc4:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0101fcb:	f0 
f0101fcc:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0101fd3:	f0 
f0101fd4:	c7 44 24 04 2a 04 00 	movl   $0x42a,0x4(%esp)
f0101fdb:	00 
f0101fdc:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0101fe3:	e8 58 e0 ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101fe8:	8b 15 8c 1e 23 f0    	mov    0xf0231e8c,%edx
f0101fee:	8b 02                	mov    (%edx),%eax
f0101ff0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101ff5:	89 c1                	mov    %eax,%ecx
f0101ff7:	c1 e9 0c             	shr    $0xc,%ecx
f0101ffa:	3b 0d 88 1e 23 f0    	cmp    0xf0231e88,%ecx
f0102000:	72 20                	jb     f0102022 <mem_init+0xba5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102002:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102006:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f010200d:	f0 
f010200e:	c7 44 24 04 2d 04 00 	movl   $0x42d,0x4(%esp)
f0102015:	00 
f0102016:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010201d:	e8 1e e0 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102022:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102027:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f010202a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102031:	00 
f0102032:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102039:	00 
f010203a:	89 14 24             	mov    %edx,(%esp)
f010203d:	e8 3e f1 ff ff       	call   f0101180 <pgdir_walk>
f0102042:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0102045:	8d 51 04             	lea    0x4(%ecx),%edx
f0102048:	39 d0                	cmp    %edx,%eax
f010204a:	74 24                	je     f0102070 <mem_init+0xbf3>
f010204c:	c7 44 24 0c a0 77 10 	movl   $0xf01077a0,0xc(%esp)
f0102053:	f0 
f0102054:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010205b:	f0 
f010205c:	c7 44 24 04 2e 04 00 	movl   $0x42e,0x4(%esp)
f0102063:	00 
f0102064:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010206b:	e8 d0 df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0102070:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0102077:	00 
f0102078:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010207f:	00 
f0102080:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102084:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102089:	89 04 24             	mov    %eax,(%esp)
f010208c:	e8 01 f3 ff ff       	call   f0101392 <page_insert>
f0102091:	85 c0                	test   %eax,%eax
f0102093:	74 24                	je     f01020b9 <mem_init+0xc3c>
f0102095:	c7 44 24 0c e0 77 10 	movl   $0xf01077e0,0xc(%esp)
f010209c:	f0 
f010209d:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01020a4:	f0 
f01020a5:	c7 44 24 04 31 04 00 	movl   $0x431,0x4(%esp)
f01020ac:	00 
f01020ad:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01020b4:	e8 87 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f01020b9:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
f01020bf:	ba 00 10 00 00       	mov    $0x1000,%edx
f01020c4:	89 f8                	mov    %edi,%eax
f01020c6:	e8 dd ea ff ff       	call   f0100ba8 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f01020cb:	89 f2                	mov    %esi,%edx
f01020cd:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f01020d3:	c1 fa 03             	sar    $0x3,%edx
f01020d6:	c1 e2 0c             	shl    $0xc,%edx
f01020d9:	39 d0                	cmp    %edx,%eax
f01020db:	74 24                	je     f0102101 <mem_init+0xc84>
f01020dd:	c7 44 24 0c 70 77 10 	movl   $0xf0107770,0xc(%esp)
f01020e4:	f0 
f01020e5:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01020ec:	f0 
f01020ed:	c7 44 24 04 32 04 00 	movl   $0x432,0x4(%esp)
f01020f4:	00 
f01020f5:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01020fc:	e8 3f df ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102101:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102106:	74 24                	je     f010212c <mem_init+0xcaf>
f0102108:	c7 44 24 0c 3a 80 10 	movl   $0xf010803a,0xc(%esp)
f010210f:	f0 
f0102110:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102117:	f0 
f0102118:	c7 44 24 04 33 04 00 	movl   $0x433,0x4(%esp)
f010211f:	00 
f0102120:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102127:	e8 14 df ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f010212c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102133:	00 
f0102134:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010213b:	00 
f010213c:	89 3c 24             	mov    %edi,(%esp)
f010213f:	e8 3c f0 ff ff       	call   f0101180 <pgdir_walk>
f0102144:	f6 00 04             	testb  $0x4,(%eax)
f0102147:	75 24                	jne    f010216d <mem_init+0xcf0>
f0102149:	c7 44 24 0c 20 78 10 	movl   $0xf0107820,0xc(%esp)
f0102150:	f0 
f0102151:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102158:	f0 
f0102159:	c7 44 24 04 34 04 00 	movl   $0x434,0x4(%esp)
f0102160:	00 
f0102161:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102168:	e8 d3 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f010216d:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102172:	f6 00 04             	testb  $0x4,(%eax)
f0102175:	75 24                	jne    f010219b <mem_init+0xd1e>
f0102177:	c7 44 24 0c 4b 80 10 	movl   $0xf010804b,0xc(%esp)
f010217e:	f0 
f010217f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102186:	f0 
f0102187:	c7 44 24 04 35 04 00 	movl   $0x435,0x4(%esp)
f010218e:	00 
f010218f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102196:	e8 a5 de ff ff       	call   f0100040 <_panic>

	// should be able to remap with fewer permissions
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f010219b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021a2:	00 
f01021a3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01021aa:	00 
f01021ab:	89 74 24 04          	mov    %esi,0x4(%esp)
f01021af:	89 04 24             	mov    %eax,(%esp)
f01021b2:	e8 db f1 ff ff       	call   f0101392 <page_insert>
f01021b7:	85 c0                	test   %eax,%eax
f01021b9:	74 24                	je     f01021df <mem_init+0xd62>
f01021bb:	c7 44 24 0c 34 77 10 	movl   $0xf0107734,0xc(%esp)
f01021c2:	f0 
f01021c3:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01021ca:	f0 
f01021cb:	c7 44 24 04 38 04 00 	movl   $0x438,0x4(%esp)
f01021d2:	00 
f01021d3:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01021da:	e8 61 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_W);
f01021df:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01021e6:	00 
f01021e7:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021ee:	00 
f01021ef:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01021f4:	89 04 24             	mov    %eax,(%esp)
f01021f7:	e8 84 ef ff ff       	call   f0101180 <pgdir_walk>
f01021fc:	f6 00 02             	testb  $0x2,(%eax)
f01021ff:	75 24                	jne    f0102225 <mem_init+0xda8>
f0102201:	c7 44 24 0c 54 78 10 	movl   $0xf0107854,0xc(%esp)
f0102208:	f0 
f0102209:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102210:	f0 
f0102211:	c7 44 24 04 39 04 00 	movl   $0x439,0x4(%esp)
f0102218:	00 
f0102219:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102220:	e8 1b de ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0102225:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010222c:	00 
f010222d:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102234:	00 
f0102235:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f010223a:	89 04 24             	mov    %eax,(%esp)
f010223d:	e8 3e ef ff ff       	call   f0101180 <pgdir_walk>
f0102242:	f6 00 04             	testb  $0x4,(%eax)
f0102245:	74 24                	je     f010226b <mem_init+0xdee>
f0102247:	c7 44 24 0c 88 78 10 	movl   $0xf0107888,0xc(%esp)
f010224e:	f0 
f010224f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102256:	f0 
f0102257:	c7 44 24 04 3a 04 00 	movl   $0x43a,0x4(%esp)
f010225e:	00 
f010225f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102266:	e8 d5 dd ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f010226b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102272:	00 
f0102273:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f010227a:	00 
f010227b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010227e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102282:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102287:	89 04 24             	mov    %eax,(%esp)
f010228a:	e8 03 f1 ff ff       	call   f0101392 <page_insert>
f010228f:	85 c0                	test   %eax,%eax
f0102291:	78 24                	js     f01022b7 <mem_init+0xe3a>
f0102293:	c7 44 24 0c c0 78 10 	movl   $0xf01078c0,0xc(%esp)
f010229a:	f0 
f010229b:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01022a2:	f0 
f01022a3:	c7 44 24 04 3d 04 00 	movl   $0x43d,0x4(%esp)
f01022aa:	00 
f01022ab:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01022b2:	e8 89 dd ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f01022b7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01022be:	00 
f01022bf:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01022c6:	00 
f01022c7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01022cb:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01022d0:	89 04 24             	mov    %eax,(%esp)
f01022d3:	e8 ba f0 ff ff       	call   f0101392 <page_insert>
f01022d8:	85 c0                	test   %eax,%eax
f01022da:	74 24                	je     f0102300 <mem_init+0xe83>
f01022dc:	c7 44 24 0c f8 78 10 	movl   $0xf01078f8,0xc(%esp)
f01022e3:	f0 
f01022e4:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01022eb:	f0 
f01022ec:	c7 44 24 04 40 04 00 	movl   $0x440,0x4(%esp)
f01022f3:	00 
f01022f4:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01022fb:	e8 40 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0102300:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102307:	00 
f0102308:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010230f:	00 
f0102310:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102315:	89 04 24             	mov    %eax,(%esp)
f0102318:	e8 63 ee ff ff       	call   f0101180 <pgdir_walk>
f010231d:	f6 00 04             	testb  $0x4,(%eax)
f0102320:	74 24                	je     f0102346 <mem_init+0xec9>
f0102322:	c7 44 24 0c 88 78 10 	movl   $0xf0107888,0xc(%esp)
f0102329:	f0 
f010232a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102331:	f0 
f0102332:	c7 44 24 04 41 04 00 	movl   $0x441,0x4(%esp)
f0102339:	00 
f010233a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102341:	e8 fa dc ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0102346:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
f010234c:	ba 00 00 00 00       	mov    $0x0,%edx
f0102351:	89 f8                	mov    %edi,%eax
f0102353:	e8 50 e8 ff ff       	call   f0100ba8 <check_va2pa>
f0102358:	89 c1                	mov    %eax,%ecx
f010235a:	89 45 cc             	mov    %eax,-0x34(%ebp)
f010235d:	89 d8                	mov    %ebx,%eax
f010235f:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f0102365:	c1 f8 03             	sar    $0x3,%eax
f0102368:	c1 e0 0c             	shl    $0xc,%eax
f010236b:	39 c1                	cmp    %eax,%ecx
f010236d:	74 24                	je     f0102393 <mem_init+0xf16>
f010236f:	c7 44 24 0c 34 79 10 	movl   $0xf0107934,0xc(%esp)
f0102376:	f0 
f0102377:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010237e:	f0 
f010237f:	c7 44 24 04 44 04 00 	movl   $0x444,0x4(%esp)
f0102386:	00 
f0102387:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010238e:	e8 ad dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102393:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102398:	89 f8                	mov    %edi,%eax
f010239a:	e8 09 e8 ff ff       	call   f0100ba8 <check_va2pa>
f010239f:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f01023a2:	74 24                	je     f01023c8 <mem_init+0xf4b>
f01023a4:	c7 44 24 0c 60 79 10 	movl   $0xf0107960,0xc(%esp)
f01023ab:	f0 
f01023ac:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01023b3:	f0 
f01023b4:	c7 44 24 04 45 04 00 	movl   $0x445,0x4(%esp)
f01023bb:	00 
f01023bc:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01023c3:	e8 78 dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f01023c8:	66 83 7b 04 02       	cmpw   $0x2,0x4(%ebx)
f01023cd:	74 24                	je     f01023f3 <mem_init+0xf76>
f01023cf:	c7 44 24 0c 61 80 10 	movl   $0xf0108061,0xc(%esp)
f01023d6:	f0 
f01023d7:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01023de:	f0 
f01023df:	c7 44 24 04 47 04 00 	movl   $0x447,0x4(%esp)
f01023e6:	00 
f01023e7:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01023ee:	e8 4d dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01023f3:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01023f8:	74 24                	je     f010241e <mem_init+0xfa1>
f01023fa:	c7 44 24 0c 72 80 10 	movl   $0xf0108072,0xc(%esp)
f0102401:	f0 
f0102402:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102409:	f0 
f010240a:	c7 44 24 04 48 04 00 	movl   $0x448,0x4(%esp)
f0102411:	00 
f0102412:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102419:	e8 22 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f010241e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102425:	e8 4c ec ff ff       	call   f0101076 <page_alloc>
f010242a:	85 c0                	test   %eax,%eax
f010242c:	74 04                	je     f0102432 <mem_init+0xfb5>
f010242e:	39 c6                	cmp    %eax,%esi
f0102430:	74 24                	je     f0102456 <mem_init+0xfd9>
f0102432:	c7 44 24 0c 90 79 10 	movl   $0xf0107990,0xc(%esp)
f0102439:	f0 
f010243a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102441:	f0 
f0102442:	c7 44 24 04 4b 04 00 	movl   $0x44b,0x4(%esp)
f0102449:	00 
f010244a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102451:	e8 ea db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f0102456:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010245d:	00 
f010245e:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102463:	89 04 24             	mov    %eax,(%esp)
f0102466:	e8 b6 ee ff ff       	call   f0101321 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f010246b:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
f0102471:	ba 00 00 00 00       	mov    $0x0,%edx
f0102476:	89 f8                	mov    %edi,%eax
f0102478:	e8 2b e7 ff ff       	call   f0100ba8 <check_va2pa>
f010247d:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102480:	74 24                	je     f01024a6 <mem_init+0x1029>
f0102482:	c7 44 24 0c b4 79 10 	movl   $0xf01079b4,0xc(%esp)
f0102489:	f0 
f010248a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102491:	f0 
f0102492:	c7 44 24 04 4f 04 00 	movl   $0x44f,0x4(%esp)
f0102499:	00 
f010249a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01024a1:	e8 9a db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01024a6:	ba 00 10 00 00       	mov    $0x1000,%edx
f01024ab:	89 f8                	mov    %edi,%eax
f01024ad:	e8 f6 e6 ff ff       	call   f0100ba8 <check_va2pa>
f01024b2:	89 da                	mov    %ebx,%edx
f01024b4:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f01024ba:	c1 fa 03             	sar    $0x3,%edx
f01024bd:	c1 e2 0c             	shl    $0xc,%edx
f01024c0:	39 d0                	cmp    %edx,%eax
f01024c2:	74 24                	je     f01024e8 <mem_init+0x106b>
f01024c4:	c7 44 24 0c 60 79 10 	movl   $0xf0107960,0xc(%esp)
f01024cb:	f0 
f01024cc:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01024d3:	f0 
f01024d4:	c7 44 24 04 50 04 00 	movl   $0x450,0x4(%esp)
f01024db:	00 
f01024dc:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01024e3:	e8 58 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f01024e8:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f01024ed:	74 24                	je     f0102513 <mem_init+0x1096>
f01024ef:	c7 44 24 0c 18 80 10 	movl   $0xf0108018,0xc(%esp)
f01024f6:	f0 
f01024f7:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01024fe:	f0 
f01024ff:	c7 44 24 04 51 04 00 	movl   $0x451,0x4(%esp)
f0102506:	00 
f0102507:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010250e:	e8 2d db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102513:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102518:	74 24                	je     f010253e <mem_init+0x10c1>
f010251a:	c7 44 24 0c 72 80 10 	movl   $0xf0108072,0xc(%esp)
f0102521:	f0 
f0102522:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102529:	f0 
f010252a:	c7 44 24 04 52 04 00 	movl   $0x452,0x4(%esp)
f0102531:	00 
f0102532:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102539:	e8 02 db ff ff       	call   f0100040 <_panic>

	// test re-inserting pp1 at PGSIZE
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, 0) == 0);
f010253e:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102545:	00 
f0102546:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010254d:	00 
f010254e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102552:	89 3c 24             	mov    %edi,(%esp)
f0102555:	e8 38 ee ff ff       	call   f0101392 <page_insert>
f010255a:	85 c0                	test   %eax,%eax
f010255c:	74 24                	je     f0102582 <mem_init+0x1105>
f010255e:	c7 44 24 0c d8 79 10 	movl   $0xf01079d8,0xc(%esp)
f0102565:	f0 
f0102566:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010256d:	f0 
f010256e:	c7 44 24 04 55 04 00 	movl   $0x455,0x4(%esp)
f0102575:	00 
f0102576:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010257d:	e8 be da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref);
f0102582:	66 83 7b 04 00       	cmpw   $0x0,0x4(%ebx)
f0102587:	75 24                	jne    f01025ad <mem_init+0x1130>
f0102589:	c7 44 24 0c 83 80 10 	movl   $0xf0108083,0xc(%esp)
f0102590:	f0 
f0102591:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102598:	f0 
f0102599:	c7 44 24 04 56 04 00 	movl   $0x456,0x4(%esp)
f01025a0:	00 
f01025a1:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01025a8:	e8 93 da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_link == NULL);
f01025ad:	83 3b 00             	cmpl   $0x0,(%ebx)
f01025b0:	74 24                	je     f01025d6 <mem_init+0x1159>
f01025b2:	c7 44 24 0c 8f 80 10 	movl   $0xf010808f,0xc(%esp)
f01025b9:	f0 
f01025ba:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01025c1:	f0 
f01025c2:	c7 44 24 04 57 04 00 	movl   $0x457,0x4(%esp)
f01025c9:	00 
f01025ca:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01025d1:	e8 6a da ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01025d6:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01025dd:	00 
f01025de:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01025e3:	89 04 24             	mov    %eax,(%esp)
f01025e6:	e8 36 ed ff ff       	call   f0101321 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01025eb:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
f01025f1:	ba 00 00 00 00       	mov    $0x0,%edx
f01025f6:	89 f8                	mov    %edi,%eax
f01025f8:	e8 ab e5 ff ff       	call   f0100ba8 <check_va2pa>
f01025fd:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102600:	74 24                	je     f0102626 <mem_init+0x11a9>
f0102602:	c7 44 24 0c b4 79 10 	movl   $0xf01079b4,0xc(%esp)
f0102609:	f0 
f010260a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102611:	f0 
f0102612:	c7 44 24 04 5b 04 00 	movl   $0x45b,0x4(%esp)
f0102619:	00 
f010261a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102621:	e8 1a da ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102626:	ba 00 10 00 00       	mov    $0x1000,%edx
f010262b:	89 f8                	mov    %edi,%eax
f010262d:	e8 76 e5 ff ff       	call   f0100ba8 <check_va2pa>
f0102632:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102635:	74 24                	je     f010265b <mem_init+0x11de>
f0102637:	c7 44 24 0c 10 7a 10 	movl   $0xf0107a10,0xc(%esp)
f010263e:	f0 
f010263f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102646:	f0 
f0102647:	c7 44 24 04 5c 04 00 	movl   $0x45c,0x4(%esp)
f010264e:	00 
f010264f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102656:	e8 e5 d9 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010265b:	66 83 7b 04 00       	cmpw   $0x0,0x4(%ebx)
f0102660:	74 24                	je     f0102686 <mem_init+0x1209>
f0102662:	c7 44 24 0c a4 80 10 	movl   $0xf01080a4,0xc(%esp)
f0102669:	f0 
f010266a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102671:	f0 
f0102672:	c7 44 24 04 5d 04 00 	movl   $0x45d,0x4(%esp)
f0102679:	00 
f010267a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102681:	e8 ba d9 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102686:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010268b:	74 24                	je     f01026b1 <mem_init+0x1234>
f010268d:	c7 44 24 0c 72 80 10 	movl   $0xf0108072,0xc(%esp)
f0102694:	f0 
f0102695:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010269c:	f0 
f010269d:	c7 44 24 04 5e 04 00 	movl   $0x45e,0x4(%esp)
f01026a4:	00 
f01026a5:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01026ac:	e8 8f d9 ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01026b1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01026b8:	e8 b9 e9 ff ff       	call   f0101076 <page_alloc>
f01026bd:	85 c0                	test   %eax,%eax
f01026bf:	74 04                	je     f01026c5 <mem_init+0x1248>
f01026c1:	39 c3                	cmp    %eax,%ebx
f01026c3:	74 24                	je     f01026e9 <mem_init+0x126c>
f01026c5:	c7 44 24 0c 38 7a 10 	movl   $0xf0107a38,0xc(%esp)
f01026cc:	f0 
f01026cd:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01026d4:	f0 
f01026d5:	c7 44 24 04 61 04 00 	movl   $0x461,0x4(%esp)
f01026dc:	00 
f01026dd:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01026e4:	e8 57 d9 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01026e9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01026f0:	e8 81 e9 ff ff       	call   f0101076 <page_alloc>
f01026f5:	85 c0                	test   %eax,%eax
f01026f7:	74 24                	je     f010271d <mem_init+0x12a0>
f01026f9:	c7 44 24 0c c6 7f 10 	movl   $0xf0107fc6,0xc(%esp)
f0102700:	f0 
f0102701:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102708:	f0 
f0102709:	c7 44 24 04 64 04 00 	movl   $0x464,0x4(%esp)
f0102710:	00 
f0102711:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102718:	e8 23 d9 ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f010271d:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102722:	8b 08                	mov    (%eax),%ecx
f0102724:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f010272a:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f010272d:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f0102733:	c1 fa 03             	sar    $0x3,%edx
f0102736:	c1 e2 0c             	shl    $0xc,%edx
f0102739:	39 d1                	cmp    %edx,%ecx
f010273b:	74 24                	je     f0102761 <mem_init+0x12e4>
f010273d:	c7 44 24 0c dc 76 10 	movl   $0xf01076dc,0xc(%esp)
f0102744:	f0 
f0102745:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010274c:	f0 
f010274d:	c7 44 24 04 67 04 00 	movl   $0x467,0x4(%esp)
f0102754:	00 
f0102755:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010275c:	e8 df d8 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102761:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102767:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010276a:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010276f:	74 24                	je     f0102795 <mem_init+0x1318>
f0102771:	c7 44 24 0c 29 80 10 	movl   $0xf0108029,0xc(%esp)
f0102778:	f0 
f0102779:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102780:	f0 
f0102781:	c7 44 24 04 69 04 00 	movl   $0x469,0x4(%esp)
f0102788:	00 
f0102789:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102790:	e8 ab d8 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102795:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102798:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010279e:	89 04 24             	mov    %eax,(%esp)
f01027a1:	e8 5b e9 ff ff       	call   f0101101 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01027a6:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027ad:	00 
f01027ae:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01027b5:	00 
f01027b6:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01027bb:	89 04 24             	mov    %eax,(%esp)
f01027be:	e8 bd e9 ff ff       	call   f0101180 <pgdir_walk>
f01027c3:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01027c6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01027c9:	8b 15 8c 1e 23 f0    	mov    0xf0231e8c,%edx
f01027cf:	8b 7a 04             	mov    0x4(%edx),%edi
f01027d2:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027d8:	8b 0d 88 1e 23 f0    	mov    0xf0231e88,%ecx
f01027de:	89 f8                	mov    %edi,%eax
f01027e0:	c1 e8 0c             	shr    $0xc,%eax
f01027e3:	39 c8                	cmp    %ecx,%eax
f01027e5:	72 20                	jb     f0102807 <mem_init+0x138a>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027e7:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01027eb:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01027f2:	f0 
f01027f3:	c7 44 24 04 70 04 00 	movl   $0x470,0x4(%esp)
f01027fa:	00 
f01027fb:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102802:	e8 39 d8 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102807:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f010280d:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f0102810:	74 24                	je     f0102836 <mem_init+0x13b9>
f0102812:	c7 44 24 0c b5 80 10 	movl   $0xf01080b5,0xc(%esp)
f0102819:	f0 
f010281a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102821:	f0 
f0102822:	c7 44 24 04 71 04 00 	movl   $0x471,0x4(%esp)
f0102829:	00 
f010282a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102831:	e8 0a d8 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102836:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f010283d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102840:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f0102846:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f010284c:	c1 f8 03             	sar    $0x3,%eax
f010284f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102852:	89 c2                	mov    %eax,%edx
f0102854:	c1 ea 0c             	shr    $0xc,%edx
f0102857:	39 d1                	cmp    %edx,%ecx
f0102859:	77 20                	ja     f010287b <mem_init+0x13fe>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010285b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010285f:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0102866:	f0 
f0102867:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f010286e:	00 
f010286f:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0102876:	e8 c5 d7 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010287b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102882:	00 
f0102883:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f010288a:	00 
	return (void *)(pa + KERNBASE);
f010288b:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102890:	89 04 24             	mov    %eax,(%esp)
f0102893:	e8 8f 39 00 00       	call   f0106227 <memset>
	page_free(pp0);
f0102898:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010289b:	89 3c 24             	mov    %edi,(%esp)
f010289e:	e8 5e e8 ff ff       	call   f0101101 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01028a3:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01028aa:	00 
f01028ab:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01028b2:	00 
f01028b3:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01028b8:	89 04 24             	mov    %eax,(%esp)
f01028bb:	e8 c0 e8 ff ff       	call   f0101180 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f01028c0:	89 fa                	mov    %edi,%edx
f01028c2:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f01028c8:	c1 fa 03             	sar    $0x3,%edx
f01028cb:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028ce:	89 d0                	mov    %edx,%eax
f01028d0:	c1 e8 0c             	shr    $0xc,%eax
f01028d3:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f01028d9:	72 20                	jb     f01028fb <mem_init+0x147e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01028db:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01028df:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01028e6:	f0 
f01028e7:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f01028ee:	00 
f01028ef:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f01028f6:	e8 45 d7 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01028fb:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f0102901:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0102904:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f010290a:	f6 00 01             	testb  $0x1,(%eax)
f010290d:	74 24                	je     f0102933 <mem_init+0x14b6>
f010290f:	c7 44 24 0c cd 80 10 	movl   $0xf01080cd,0xc(%esp)
f0102916:	f0 
f0102917:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010291e:	f0 
f010291f:	c7 44 24 04 7b 04 00 	movl   $0x47b,0x4(%esp)
f0102926:	00 
f0102927:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010292e:	e8 0d d7 ff ff       	call   f0100040 <_panic>
f0102933:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102936:	39 d0                	cmp    %edx,%eax
f0102938:	75 d0                	jne    f010290a <mem_init+0x148d>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f010293a:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f010293f:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102945:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102948:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)

	// give free list back
	page_free_list = fl;
f010294e:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0102951:	89 0d 40 12 23 f0    	mov    %ecx,0xf0231240

	// free the pages we took
	page_free(pp0);
f0102957:	89 04 24             	mov    %eax,(%esp)
f010295a:	e8 a2 e7 ff ff       	call   f0101101 <page_free>
	page_free(pp1);
f010295f:	89 1c 24             	mov    %ebx,(%esp)
f0102962:	e8 9a e7 ff ff       	call   f0101101 <page_free>
	page_free(pp2);
f0102967:	89 34 24             	mov    %esi,(%esp)
f010296a:	e8 92 e7 ff ff       	call   f0101101 <page_free>

	// test mmio_map_region
	mm1 = (uintptr_t) mmio_map_region(0, 4097);
f010296f:	c7 44 24 04 01 10 00 	movl   $0x1001,0x4(%esp)
f0102976:	00 
f0102977:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010297e:	e8 91 ea ff ff       	call   f0101414 <mmio_map_region>
f0102983:	89 c3                	mov    %eax,%ebx
	mm2 = (uintptr_t) mmio_map_region(0, 4096);
f0102985:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010298c:	00 
f010298d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102994:	e8 7b ea ff ff       	call   f0101414 <mmio_map_region>
f0102999:	89 c6                	mov    %eax,%esi
	// check that they're in the right region
	assert(mm1 >= MMIOBASE && mm1 + 8096 < MMIOLIM);
f010299b:	8d 83 a0 1f 00 00    	lea    0x1fa0(%ebx),%eax
f01029a1:	3d ff ff bf ef       	cmp    $0xefbfffff,%eax
f01029a6:	77 08                	ja     f01029b0 <mem_init+0x1533>
f01029a8:	81 fb ff ff 7f ef    	cmp    $0xef7fffff,%ebx
f01029ae:	77 24                	ja     f01029d4 <mem_init+0x1557>
f01029b0:	c7 44 24 0c 5c 7a 10 	movl   $0xf0107a5c,0xc(%esp)
f01029b7:	f0 
f01029b8:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01029bf:	f0 
f01029c0:	c7 44 24 04 8b 04 00 	movl   $0x48b,0x4(%esp)
f01029c7:	00 
f01029c8:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01029cf:	e8 6c d6 ff ff       	call   f0100040 <_panic>
	assert(mm2 >= MMIOBASE && mm2 + 8096 < MMIOLIM);
f01029d4:	8d 96 a0 1f 00 00    	lea    0x1fa0(%esi),%edx
f01029da:	81 fa ff ff bf ef    	cmp    $0xefbfffff,%edx
f01029e0:	77 08                	ja     f01029ea <mem_init+0x156d>
f01029e2:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f01029e8:	77 24                	ja     f0102a0e <mem_init+0x1591>
f01029ea:	c7 44 24 0c 84 7a 10 	movl   $0xf0107a84,0xc(%esp)
f01029f1:	f0 
f01029f2:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01029f9:	f0 
f01029fa:	c7 44 24 04 8c 04 00 	movl   $0x48c,0x4(%esp)
f0102a01:	00 
f0102a02:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102a09:	e8 32 d6 ff ff       	call   f0100040 <_panic>
f0102a0e:	89 da                	mov    %ebx,%edx
f0102a10:	09 f2                	or     %esi,%edx
	// check that they're page-aligned
	assert(mm1 % PGSIZE == 0 && mm2 % PGSIZE == 0);
f0102a12:	f7 c2 ff 0f 00 00    	test   $0xfff,%edx
f0102a18:	74 24                	je     f0102a3e <mem_init+0x15c1>
f0102a1a:	c7 44 24 0c ac 7a 10 	movl   $0xf0107aac,0xc(%esp)
f0102a21:	f0 
f0102a22:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102a29:	f0 
f0102a2a:	c7 44 24 04 8e 04 00 	movl   $0x48e,0x4(%esp)
f0102a31:	00 
f0102a32:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102a39:	e8 02 d6 ff ff       	call   f0100040 <_panic>
	// check that they don't overlap
	assert(mm1 + 8096 <= mm2);
f0102a3e:	39 c6                	cmp    %eax,%esi
f0102a40:	73 24                	jae    f0102a66 <mem_init+0x15e9>
f0102a42:	c7 44 24 0c e4 80 10 	movl   $0xf01080e4,0xc(%esp)
f0102a49:	f0 
f0102a4a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102a51:	f0 
f0102a52:	c7 44 24 04 90 04 00 	movl   $0x490,0x4(%esp)
f0102a59:	00 
f0102a5a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102a61:	e8 da d5 ff ff       	call   f0100040 <_panic>
	// check page mappings
	assert(check_va2pa(kern_pgdir, mm1) == 0);
f0102a66:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi
f0102a6c:	89 da                	mov    %ebx,%edx
f0102a6e:	89 f8                	mov    %edi,%eax
f0102a70:	e8 33 e1 ff ff       	call   f0100ba8 <check_va2pa>
f0102a75:	85 c0                	test   %eax,%eax
f0102a77:	74 24                	je     f0102a9d <mem_init+0x1620>
f0102a79:	c7 44 24 0c d4 7a 10 	movl   $0xf0107ad4,0xc(%esp)
f0102a80:	f0 
f0102a81:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102a88:	f0 
f0102a89:	c7 44 24 04 92 04 00 	movl   $0x492,0x4(%esp)
f0102a90:	00 
f0102a91:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102a98:	e8 a3 d5 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, mm1+PGSIZE) == PGSIZE);
f0102a9d:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
f0102aa3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102aa6:	89 c2                	mov    %eax,%edx
f0102aa8:	89 f8                	mov    %edi,%eax
f0102aaa:	e8 f9 e0 ff ff       	call   f0100ba8 <check_va2pa>
f0102aaf:	3d 00 10 00 00       	cmp    $0x1000,%eax
f0102ab4:	74 24                	je     f0102ada <mem_init+0x165d>
f0102ab6:	c7 44 24 0c f8 7a 10 	movl   $0xf0107af8,0xc(%esp)
f0102abd:	f0 
f0102abe:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102ac5:	f0 
f0102ac6:	c7 44 24 04 93 04 00 	movl   $0x493,0x4(%esp)
f0102acd:	00 
f0102ace:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102ad5:	e8 66 d5 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, mm2) == 0);
f0102ada:	89 f2                	mov    %esi,%edx
f0102adc:	89 f8                	mov    %edi,%eax
f0102ade:	e8 c5 e0 ff ff       	call   f0100ba8 <check_va2pa>
f0102ae3:	85 c0                	test   %eax,%eax
f0102ae5:	74 24                	je     f0102b0b <mem_init+0x168e>
f0102ae7:	c7 44 24 0c 28 7b 10 	movl   $0xf0107b28,0xc(%esp)
f0102aee:	f0 
f0102aef:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102af6:	f0 
f0102af7:	c7 44 24 04 94 04 00 	movl   $0x494,0x4(%esp)
f0102afe:	00 
f0102aff:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102b06:	e8 35 d5 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, mm2+PGSIZE) == ~0);
f0102b0b:	8d 96 00 10 00 00    	lea    0x1000(%esi),%edx
f0102b11:	89 f8                	mov    %edi,%eax
f0102b13:	e8 90 e0 ff ff       	call   f0100ba8 <check_va2pa>
f0102b18:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102b1b:	74 24                	je     f0102b41 <mem_init+0x16c4>
f0102b1d:	c7 44 24 0c 4c 7b 10 	movl   $0xf0107b4c,0xc(%esp)
f0102b24:	f0 
f0102b25:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102b2c:	f0 
f0102b2d:	c7 44 24 04 95 04 00 	movl   $0x495,0x4(%esp)
f0102b34:	00 
f0102b35:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102b3c:	e8 ff d4 ff ff       	call   f0100040 <_panic>
	// check permissions
	assert(*pgdir_walk(kern_pgdir, (void*) mm1, 0) & (PTE_W|PTE_PWT|PTE_PCD));
f0102b41:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102b48:	00 
f0102b49:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102b4d:	89 3c 24             	mov    %edi,(%esp)
f0102b50:	e8 2b e6 ff ff       	call   f0101180 <pgdir_walk>
f0102b55:	f6 00 1a             	testb  $0x1a,(%eax)
f0102b58:	75 24                	jne    f0102b7e <mem_init+0x1701>
f0102b5a:	c7 44 24 0c 78 7b 10 	movl   $0xf0107b78,0xc(%esp)
f0102b61:	f0 
f0102b62:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102b69:	f0 
f0102b6a:	c7 44 24 04 97 04 00 	movl   $0x497,0x4(%esp)
f0102b71:	00 
f0102b72:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102b79:	e8 c2 d4 ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) mm1, 0) & PTE_U));
f0102b7e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102b85:	00 
f0102b86:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102b8a:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102b8f:	89 04 24             	mov    %eax,(%esp)
f0102b92:	e8 e9 e5 ff ff       	call   f0101180 <pgdir_walk>
f0102b97:	f6 00 04             	testb  $0x4,(%eax)
f0102b9a:	74 24                	je     f0102bc0 <mem_init+0x1743>
f0102b9c:	c7 44 24 0c bc 7b 10 	movl   $0xf0107bbc,0xc(%esp)
f0102ba3:	f0 
f0102ba4:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102bab:	f0 
f0102bac:	c7 44 24 04 98 04 00 	movl   $0x498,0x4(%esp)
f0102bb3:	00 
f0102bb4:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102bbb:	e8 80 d4 ff ff       	call   f0100040 <_panic>
	// clear the mappings
	*pgdir_walk(kern_pgdir, (void*) mm1, 0) = 0;
f0102bc0:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102bc7:	00 
f0102bc8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102bcc:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102bd1:	89 04 24             	mov    %eax,(%esp)
f0102bd4:	e8 a7 e5 ff ff       	call   f0101180 <pgdir_walk>
f0102bd9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	*pgdir_walk(kern_pgdir, (void*) mm1 + PGSIZE, 0) = 0;
f0102bdf:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102be6:	00 
f0102be7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102bea:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102bee:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102bf3:	89 04 24             	mov    %eax,(%esp)
f0102bf6:	e8 85 e5 ff ff       	call   f0101180 <pgdir_walk>
f0102bfb:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	*pgdir_walk(kern_pgdir, (void*) mm2, 0) = 0;
f0102c01:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102c08:	00 
f0102c09:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102c0d:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102c12:	89 04 24             	mov    %eax,(%esp)
f0102c15:	e8 66 e5 ff ff       	call   f0101180 <pgdir_walk>
f0102c1a:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

	cprintf("check_page() succeeded!\n");
f0102c20:	c7 04 24 f6 80 10 f0 	movl   $0xf01080f6,(%esp)
f0102c27:	e8 0b 13 00 00       	call   f0103f37 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:

	boot_map_region(kern_pgdir, (uintptr_t)UPAGES, ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE), PADDR(pages), PTE_U);
f0102c2c:	a1 90 1e 23 f0       	mov    0xf0231e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c31:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102c36:	77 20                	ja     f0102c58 <mem_init+0x17db>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c38:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c3c:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102c43:	f0 
f0102c44:	c7 44 24 04 c3 00 00 	movl   $0xc3,0x4(%esp)
f0102c4b:	00 
f0102c4c:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102c53:	e8 e8 d3 ff ff       	call   f0100040 <_panic>
f0102c58:	8b 15 88 1e 23 f0    	mov    0xf0231e88,%edx
f0102c5e:	8d 0c d5 ff 0f 00 00 	lea    0xfff(,%edx,8),%ecx
f0102c65:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102c6b:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
f0102c72:	00 
	return (physaddr_t)kva - KERNBASE;
f0102c73:	05 00 00 00 10       	add    $0x10000000,%eax
f0102c78:	89 04 24             	mov    %eax,(%esp)
f0102c7b:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102c80:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102c85:	e8 96 e5 ff ff       	call   f0101220 <boot_map_region>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.

	boot_map_region(kern_pgdir, (uintptr_t)UENVS, ROUNDUP(NENV*sizeof(struct Env), PGSIZE), PADDR(envs), PTE_U);
f0102c8a:	a1 48 12 23 f0       	mov    0xf0231248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c8f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102c94:	77 20                	ja     f0102cb6 <mem_init+0x1839>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c96:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c9a:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102ca1:	f0 
f0102ca2:	c7 44 24 04 ce 00 00 	movl   $0xce,0x4(%esp)
f0102ca9:	00 
f0102caa:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102cb1:	e8 8a d3 ff ff       	call   f0100040 <_panic>
f0102cb6:	c7 44 24 04 04 00 00 	movl   $0x4,0x4(%esp)
f0102cbd:	00 
	return (physaddr_t)kva - KERNBASE;
f0102cbe:	05 00 00 00 10       	add    $0x10000000,%eax
f0102cc3:	89 04 24             	mov    %eax,(%esp)
f0102cc6:	b9 00 f0 01 00       	mov    $0x1f000,%ecx
f0102ccb:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102cd0:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102cd5:	e8 46 e5 ff ff       	call   f0101220 <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102cda:	b8 00 70 11 f0       	mov    $0xf0117000,%eax
f0102cdf:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102ce4:	77 20                	ja     f0102d06 <mem_init+0x1889>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102ce6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102cea:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102cf1:	f0 
f0102cf2:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
f0102cf9:	00 
f0102cfa:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102d01:	e8 3a d3 ff ff       	call   f0100040 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:

	boot_map_region(kern_pgdir, (uintptr_t)(KSTACKTOP-KSTKSIZE), KSTKSIZE, PADDR(bootstack), PTE_W);
f0102d06:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102d0d:	00 
f0102d0e:	c7 04 24 00 70 11 00 	movl   $0x117000,(%esp)
f0102d15:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102d1a:	ba 00 80 ff ef       	mov    $0xefff8000,%edx
f0102d1f:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102d24:	e8 f7 e4 ff ff       	call   f0101220 <boot_map_region>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:

	boot_map_region(kern_pgdir, (uintptr_t)KERNBASE, ROUNDUP(~0 - KERNBASE + 1, PGSIZE), 0, PTE_W);
f0102d29:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102d30:	00 
f0102d31:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102d38:	b9 00 00 00 10       	mov    $0x10000000,%ecx
f0102d3d:	ba 00 00 00 f0       	mov    $0xf0000000,%edx
f0102d42:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102d47:	e8 d4 e4 ff ff       	call   f0101220 <boot_map_region>
f0102d4c:	bf 00 30 27 f0       	mov    $0xf0273000,%edi
f0102d51:	bb 00 30 23 f0       	mov    $0xf0233000,%ebx
f0102d56:	be 00 80 ff ef       	mov    $0xefff8000,%esi
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d5b:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102d61:	77 20                	ja     f0102d83 <mem_init+0x1906>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102d63:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102d67:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102d6e:	f0 
f0102d6f:	c7 44 24 04 1d 01 00 	movl   $0x11d,0x4(%esp)
f0102d76:	00 
f0102d77:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102d7e:	e8 bd d2 ff ff       	call   f0100040 <_panic>
	//
	// LAB 4: Your code here:

	int i;
	for(i=0;i<NCPU;i++){
		boot_map_region(kern_pgdir, (uintptr_t)(KSTACKTOP-KSTKSIZE - i*(KSTKSIZE+KSTKGAP)), KSTKSIZE, PADDR(percpu_kstacks[i]), PTE_W);
f0102d83:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102d8a:	00 
f0102d8b:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102d91:	89 04 24             	mov    %eax,(%esp)
f0102d94:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102d99:	89 f2                	mov    %esi,%edx
f0102d9b:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0102da0:	e8 7b e4 ff ff       	call   f0101220 <boot_map_region>
f0102da5:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102dab:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	//     Permissions: kernel RW, user NONE
	//
	// LAB 4: Your code here:

	int i;
	for(i=0;i<NCPU;i++){
f0102db1:	39 fb                	cmp    %edi,%ebx
f0102db3:	75 a6                	jne    f0102d5b <mem_init+0x18de>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102db5:	8b 3d 8c 1e 23 f0    	mov    0xf0231e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE);
f0102dbb:	a1 88 1e 23 f0       	mov    0xf0231e88,%eax
f0102dc0:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102dc3:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
f0102dca:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102dcf:	89 45 d0             	mov    %eax,-0x30(%ebp)
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102dd2:	8b 35 90 1e 23 f0    	mov    0xf0231e90,%esi
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102dd8:	89 75 cc             	mov    %esi,-0x34(%ebp)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102ddb:	8d 86 00 00 00 10    	lea    0x10000000(%esi),%eax
f0102de1:	89 45 c8             	mov    %eax,-0x38(%ebp)

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102de4:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102de9:	eb 6a                	jmp    f0102e55 <mem_init+0x19d8>
f0102deb:	8d 93 00 00 00 ef    	lea    -0x11000000(%ebx),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102df1:	89 f8                	mov    %edi,%eax
f0102df3:	e8 b0 dd ff ff       	call   f0100ba8 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102df8:	81 7d cc ff ff ff ef 	cmpl   $0xefffffff,-0x34(%ebp)
f0102dff:	77 20                	ja     f0102e21 <mem_init+0x19a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102e01:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0102e05:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102e0c:	f0 
f0102e0d:	c7 44 24 04 a9 03 00 	movl   $0x3a9,0x4(%esp)
f0102e14:	00 
f0102e15:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102e1c:	e8 1f d2 ff ff       	call   f0100040 <_panic>
f0102e21:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102e24:	8d 14 0b             	lea    (%ebx,%ecx,1),%edx
f0102e27:	39 d0                	cmp    %edx,%eax
f0102e29:	74 24                	je     f0102e4f <mem_init+0x19d2>
f0102e2b:	c7 44 24 0c f0 7b 10 	movl   $0xf0107bf0,0xc(%esp)
f0102e32:	f0 
f0102e33:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102e3a:	f0 
f0102e3b:	c7 44 24 04 a9 03 00 	movl   $0x3a9,0x4(%esp)
f0102e42:	00 
f0102e43:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102e4a:	e8 f1 d1 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102e4f:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102e55:	39 5d d0             	cmp    %ebx,-0x30(%ebp)
f0102e58:	77 91                	ja     f0102deb <mem_init+0x196e>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102e5a:	8b 1d 48 12 23 f0    	mov    0xf0231248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102e60:	89 de                	mov    %ebx,%esi
f0102e62:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102e67:	89 f8                	mov    %edi,%eax
f0102e69:	e8 3a dd ff ff       	call   f0100ba8 <check_va2pa>
f0102e6e:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102e74:	77 20                	ja     f0102e96 <mem_init+0x1a19>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102e76:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102e7a:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102e81:	f0 
f0102e82:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f0102e89:	00 
f0102e8a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102e91:	e8 aa d1 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102e96:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102e9b:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102ea1:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102ea4:	39 d0                	cmp    %edx,%eax
f0102ea6:	74 24                	je     f0102ecc <mem_init+0x1a4f>
f0102ea8:	c7 44 24 0c 24 7c 10 	movl   $0xf0107c24,0xc(%esp)
f0102eaf:	f0 
f0102eb0:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102eb7:	f0 
f0102eb8:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f0102ebf:	00 
f0102ec0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102ec7:	e8 74 d1 ff ff       	call   f0100040 <_panic>
f0102ecc:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102ed2:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102ed8:	0f 85 a8 05 00 00    	jne    f0103486 <mem_init+0x2009>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102ede:	8b 75 d4             	mov    -0x2c(%ebp),%esi
f0102ee1:	c1 e6 0c             	shl    $0xc,%esi
f0102ee4:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102ee9:	eb 3b                	jmp    f0102f26 <mem_init+0x1aa9>
f0102eeb:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102ef1:	89 f8                	mov    %edi,%eax
f0102ef3:	e8 b0 dc ff ff       	call   f0100ba8 <check_va2pa>
f0102ef8:	39 c3                	cmp    %eax,%ebx
f0102efa:	74 24                	je     f0102f20 <mem_init+0x1aa3>
f0102efc:	c7 44 24 0c 58 7c 10 	movl   $0xf0107c58,0xc(%esp)
f0102f03:	f0 
f0102f04:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102f0b:	f0 
f0102f0c:	c7 44 24 04 b2 03 00 	movl   $0x3b2,0x4(%esp)
f0102f13:	00 
f0102f14:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102f1b:	e8 20 d1 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102f20:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102f26:	39 f3                	cmp    %esi,%ebx
f0102f28:	72 c1                	jb     f0102eeb <mem_init+0x1a6e>
f0102f2a:	c7 45 d0 00 30 23 f0 	movl   $0xf0233000,-0x30(%ebp)
f0102f31:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
f0102f38:	be 00 80 ff ef       	mov    $0xefff8000,%esi
f0102f3d:	b8 00 30 23 f0       	mov    $0xf0233000,%eax
f0102f42:	05 00 80 00 20       	add    $0x20008000,%eax
f0102f47:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102f4a:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102f50:	89 45 cc             	mov    %eax,-0x34(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102f53:	89 f2                	mov    %esi,%edx
f0102f55:	89 f8                	mov    %edi,%eax
f0102f57:	e8 4c dc ff ff       	call   f0100ba8 <check_va2pa>
f0102f5c:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0102f5f:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102f65:	77 20                	ja     f0102f87 <mem_init+0x1b0a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f67:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102f6b:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0102f72:	f0 
f0102f73:	c7 44 24 04 ba 03 00 	movl   $0x3ba,0x4(%esp)
f0102f7a:	00 
f0102f7b:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102f82:	e8 b9 d0 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102f87:	89 f3                	mov    %esi,%ebx
f0102f89:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f0102f8c:	03 4d d4             	add    -0x2c(%ebp),%ecx
f0102f8f:	89 4d c8             	mov    %ecx,-0x38(%ebp)
f0102f92:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102f95:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
f0102f98:	39 c2                	cmp    %eax,%edx
f0102f9a:	74 24                	je     f0102fc0 <mem_init+0x1b43>
f0102f9c:	c7 44 24 0c 80 7c 10 	movl   $0xf0107c80,0xc(%esp)
f0102fa3:	f0 
f0102fa4:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102fab:	f0 
f0102fac:	c7 44 24 04 ba 03 00 	movl   $0x3ba,0x4(%esp)
f0102fb3:	00 
f0102fb4:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0102fbb:	e8 80 d0 ff ff       	call   f0100040 <_panic>
f0102fc0:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102fc6:	3b 5d cc             	cmp    -0x34(%ebp),%ebx
f0102fc9:	0f 85 a9 04 00 00    	jne    f0103478 <mem_init+0x1ffb>
f0102fcf:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);

		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102fd5:	89 da                	mov    %ebx,%edx
f0102fd7:	89 f8                	mov    %edi,%eax
f0102fd9:	e8 ca db ff ff       	call   f0100ba8 <check_va2pa>
f0102fde:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102fe1:	74 24                	je     f0103007 <mem_init+0x1b8a>
f0102fe3:	c7 44 24 0c c8 7c 10 	movl   $0xf0107cc8,0xc(%esp)
f0102fea:	f0 
f0102feb:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0102ff2:	f0 
f0102ff3:	c7 44 24 04 bd 03 00 	movl   $0x3bd,0x4(%esp)
f0102ffa:	00 
f0102ffb:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103002:	e8 39 d0 ff ff       	call   f0100040 <_panic>
f0103007:	81 c3 00 10 00 00    	add    $0x1000,%ebx
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);

		for (i = 0; i < KSTKGAP; i += PGSIZE)
f010300d:	39 de                	cmp    %ebx,%esi
f010300f:	75 c4                	jne    f0102fd5 <mem_init+0x1b58>
f0103011:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0103017:	81 45 d4 00 80 01 00 	addl   $0x18000,-0x2c(%ebp)
f010301e:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0103025:	81 fe 00 80 f7 ef    	cmp    $0xeff78000,%esi
f010302b:	0f 85 19 ff ff ff    	jne    f0102f4a <mem_init+0x1acd>
f0103031:	b8 00 00 00 00       	mov    $0x0,%eax
f0103036:	e9 c2 00 00 00       	jmp    f01030fd <mem_init+0x1c80>
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f010303b:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0103041:	83 fa 04             	cmp    $0x4,%edx
f0103044:	77 2e                	ja     f0103074 <mem_init+0x1bf7>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
		case PDX(MMIOBASE):
			assert(pgdir[i] & PTE_P);
f0103046:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f010304a:	0f 85 aa 00 00 00    	jne    f01030fa <mem_init+0x1c7d>
f0103050:	c7 44 24 0c 0f 81 10 	movl   $0xf010810f,0xc(%esp)
f0103057:	f0 
f0103058:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010305f:	f0 
f0103060:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
f0103067:	00 
f0103068:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010306f:	e8 cc cf ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0103074:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0103079:	76 55                	jbe    f01030d0 <mem_init+0x1c53>
				assert(pgdir[i] & PTE_P);
f010307b:	8b 14 87             	mov    (%edi,%eax,4),%edx
f010307e:	f6 c2 01             	test   $0x1,%dl
f0103081:	75 24                	jne    f01030a7 <mem_init+0x1c2a>
f0103083:	c7 44 24 0c 0f 81 10 	movl   $0xf010810f,0xc(%esp)
f010308a:	f0 
f010308b:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103092:	f0 
f0103093:	c7 44 24 04 cc 03 00 	movl   $0x3cc,0x4(%esp)
f010309a:	00 
f010309b:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01030a2:	e8 99 cf ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f01030a7:	f6 c2 02             	test   $0x2,%dl
f01030aa:	75 4e                	jne    f01030fa <mem_init+0x1c7d>
f01030ac:	c7 44 24 0c 20 81 10 	movl   $0xf0108120,0xc(%esp)
f01030b3:	f0 
f01030b4:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01030bb:	f0 
f01030bc:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f01030c3:	00 
f01030c4:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01030cb:	e8 70 cf ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f01030d0:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f01030d4:	74 24                	je     f01030fa <mem_init+0x1c7d>
f01030d6:	c7 44 24 0c 31 81 10 	movl   $0xf0108131,0xc(%esp)
f01030dd:	f0 
f01030de:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01030e5:	f0 
f01030e6:	c7 44 24 04 cf 03 00 	movl   $0x3cf,0x4(%esp)
f01030ed:	00 
f01030ee:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01030f5:	e8 46 cf ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f01030fa:	83 c0 01             	add    $0x1,%eax
f01030fd:	3d 00 04 00 00       	cmp    $0x400,%eax
f0103102:	0f 85 33 ff ff ff    	jne    f010303b <mem_init+0x1bbe>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0103108:	c7 04 24 ec 7c 10 f0 	movl   $0xf0107cec,(%esp)
f010310f:	e8 23 0e 00 00       	call   f0103f37 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0103114:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0103119:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010311e:	77 20                	ja     f0103140 <mem_init+0x1cc3>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103120:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103124:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f010312b:	f0 
f010312c:	c7 44 24 04 f5 00 00 	movl   $0xf5,0x4(%esp)
f0103133:	00 
f0103134:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010313b:	e8 00 cf ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103140:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103145:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0103148:	b8 00 00 00 00       	mov    $0x0,%eax
f010314d:	e8 c5 da ff ff       	call   f0100c17 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0103152:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0103155:	83 e0 f3             	and    $0xfffffff3,%eax
f0103158:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f010315d:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0103160:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103167:	e8 0a df ff ff       	call   f0101076 <page_alloc>
f010316c:	89 c3                	mov    %eax,%ebx
f010316e:	85 c0                	test   %eax,%eax
f0103170:	75 24                	jne    f0103196 <mem_init+0x1d19>
f0103172:	c7 44 24 0c 1b 7f 10 	movl   $0xf0107f1b,0xc(%esp)
f0103179:	f0 
f010317a:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103181:	f0 
f0103182:	c7 44 24 04 ad 04 00 	movl   $0x4ad,0x4(%esp)
f0103189:	00 
f010318a:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103191:	e8 aa ce ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0103196:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010319d:	e8 d4 de ff ff       	call   f0101076 <page_alloc>
f01031a2:	89 c7                	mov    %eax,%edi
f01031a4:	85 c0                	test   %eax,%eax
f01031a6:	75 24                	jne    f01031cc <mem_init+0x1d4f>
f01031a8:	c7 44 24 0c 31 7f 10 	movl   $0xf0107f31,0xc(%esp)
f01031af:	f0 
f01031b0:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01031b7:	f0 
f01031b8:	c7 44 24 04 ae 04 00 	movl   $0x4ae,0x4(%esp)
f01031bf:	00 
f01031c0:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01031c7:	e8 74 ce ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01031cc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01031d3:	e8 9e de ff ff       	call   f0101076 <page_alloc>
f01031d8:	89 c6                	mov    %eax,%esi
f01031da:	85 c0                	test   %eax,%eax
f01031dc:	75 24                	jne    f0103202 <mem_init+0x1d85>
f01031de:	c7 44 24 0c 47 7f 10 	movl   $0xf0107f47,0xc(%esp)
f01031e5:	f0 
f01031e6:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01031ed:	f0 
f01031ee:	c7 44 24 04 af 04 00 	movl   $0x4af,0x4(%esp)
f01031f5:	00 
f01031f6:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01031fd:	e8 3e ce ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103202:	89 1c 24             	mov    %ebx,(%esp)
f0103205:	e8 f7 de ff ff       	call   f0101101 <page_free>
	memset(page2kva(pp1), 1, PGSIZE);
f010320a:	89 f8                	mov    %edi,%eax
f010320c:	e8 52 d9 ff ff       	call   f0100b63 <page2kva>
f0103211:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103218:	00 
f0103219:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0103220:	00 
f0103221:	89 04 24             	mov    %eax,(%esp)
f0103224:	e8 fe 2f 00 00       	call   f0106227 <memset>
	memset(page2kva(pp2), 2, PGSIZE);
f0103229:	89 f0                	mov    %esi,%eax
f010322b:	e8 33 d9 ff ff       	call   f0100b63 <page2kva>
f0103230:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103237:	00 
f0103238:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f010323f:	00 
f0103240:	89 04 24             	mov    %eax,(%esp)
f0103243:	e8 df 2f 00 00       	call   f0106227 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0103248:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010324f:	00 
f0103250:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103257:	00 
f0103258:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010325c:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f0103261:	89 04 24             	mov    %eax,(%esp)
f0103264:	e8 29 e1 ff ff       	call   f0101392 <page_insert>
	assert(pp1->pp_ref == 1);
f0103269:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f010326e:	74 24                	je     f0103294 <mem_init+0x1e17>
f0103270:	c7 44 24 0c 18 80 10 	movl   $0xf0108018,0xc(%esp)
f0103277:	f0 
f0103278:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010327f:	f0 
f0103280:	c7 44 24 04 b4 04 00 	movl   $0x4b4,0x4(%esp)
f0103287:	00 
f0103288:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010328f:	e8 ac cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0103294:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f010329b:	01 01 01 
f010329e:	74 24                	je     f01032c4 <mem_init+0x1e47>
f01032a0:	c7 44 24 0c 0c 7d 10 	movl   $0xf0107d0c,0xc(%esp)
f01032a7:	f0 
f01032a8:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01032af:	f0 
f01032b0:	c7 44 24 04 b5 04 00 	movl   $0x4b5,0x4(%esp)
f01032b7:	00 
f01032b8:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01032bf:	e8 7c cd ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f01032c4:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01032cb:	00 
f01032cc:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01032d3:	00 
f01032d4:	89 74 24 04          	mov    %esi,0x4(%esp)
f01032d8:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01032dd:	89 04 24             	mov    %eax,(%esp)
f01032e0:	e8 ad e0 ff ff       	call   f0101392 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f01032e5:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f01032ec:	02 02 02 
f01032ef:	74 24                	je     f0103315 <mem_init+0x1e98>
f01032f1:	c7 44 24 0c 30 7d 10 	movl   $0xf0107d30,0xc(%esp)
f01032f8:	f0 
f01032f9:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103300:	f0 
f0103301:	c7 44 24 04 b7 04 00 	movl   $0x4b7,0x4(%esp)
f0103308:	00 
f0103309:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103310:	e8 2b cd ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0103315:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010331a:	74 24                	je     f0103340 <mem_init+0x1ec3>
f010331c:	c7 44 24 0c 3a 80 10 	movl   $0xf010803a,0xc(%esp)
f0103323:	f0 
f0103324:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f010332b:	f0 
f010332c:	c7 44 24 04 b8 04 00 	movl   $0x4b8,0x4(%esp)
f0103333:	00 
f0103334:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f010333b:	e8 00 cd ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103340:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0103345:	74 24                	je     f010336b <mem_init+0x1eee>
f0103347:	c7 44 24 0c a4 80 10 	movl   $0xf01080a4,0xc(%esp)
f010334e:	f0 
f010334f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103356:	f0 
f0103357:	c7 44 24 04 b9 04 00 	movl   $0x4b9,0x4(%esp)
f010335e:	00 
f010335f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103366:	e8 d5 cc ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f010336b:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0103372:	03 03 03 
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103375:	89 f0                	mov    %esi,%eax
f0103377:	e8 e7 d7 ff ff       	call   f0100b63 <page2kva>
f010337c:	81 38 03 03 03 03    	cmpl   $0x3030303,(%eax)
f0103382:	74 24                	je     f01033a8 <mem_init+0x1f2b>
f0103384:	c7 44 24 0c 54 7d 10 	movl   $0xf0107d54,0xc(%esp)
f010338b:	f0 
f010338c:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103393:	f0 
f0103394:	c7 44 24 04 bb 04 00 	movl   $0x4bb,0x4(%esp)
f010339b:	00 
f010339c:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01033a3:	e8 98 cc ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01033a8:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01033af:	00 
f01033b0:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01033b5:	89 04 24             	mov    %eax,(%esp)
f01033b8:	e8 64 df ff ff       	call   f0101321 <page_remove>
	assert(pp2->pp_ref == 0);
f01033bd:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01033c2:	74 24                	je     f01033e8 <mem_init+0x1f6b>
f01033c4:	c7 44 24 0c 72 80 10 	movl   $0xf0108072,0xc(%esp)
f01033cb:	f0 
f01033cc:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f01033d3:	f0 
f01033d4:	c7 44 24 04 bd 04 00 	movl   $0x4bd,0x4(%esp)
f01033db:	00 
f01033dc:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f01033e3:	e8 58 cc ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01033e8:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
f01033ed:	8b 08                	mov    (%eax),%ecx
f01033ef:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp)
{
	return (pp - pages) << PGSHIFT;
f01033f5:	89 da                	mov    %ebx,%edx
f01033f7:	2b 15 90 1e 23 f0    	sub    0xf0231e90,%edx
f01033fd:	c1 fa 03             	sar    $0x3,%edx
f0103400:	c1 e2 0c             	shl    $0xc,%edx
f0103403:	39 d1                	cmp    %edx,%ecx
f0103405:	74 24                	je     f010342b <mem_init+0x1fae>
f0103407:	c7 44 24 0c dc 76 10 	movl   $0xf01076dc,0xc(%esp)
f010340e:	f0 
f010340f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103416:	f0 
f0103417:	c7 44 24 04 c0 04 00 	movl   $0x4c0,0x4(%esp)
f010341e:	00 
f010341f:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103426:	e8 15 cc ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f010342b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103431:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0103436:	74 24                	je     f010345c <mem_init+0x1fdf>
f0103438:	c7 44 24 0c 29 80 10 	movl   $0xf0108029,0xc(%esp)
f010343f:	f0 
f0103440:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0103447:	f0 
f0103448:	c7 44 24 04 c2 04 00 	movl   $0x4c2,0x4(%esp)
f010344f:	00 
f0103450:	c7 04 24 ef 7d 10 f0 	movl   $0xf0107def,(%esp)
f0103457:	e8 e4 cb ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010345c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0103462:	89 1c 24             	mov    %ebx,(%esp)
f0103465:	e8 97 dc ff ff       	call   f0101101 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f010346a:	c7 04 24 80 7d 10 f0 	movl   $0xf0107d80,(%esp)
f0103471:	e8 c1 0a 00 00       	call   f0103f37 <cprintf>
f0103476:	eb 1d                	jmp    f0103495 <mem_init+0x2018>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103478:	89 da                	mov    %ebx,%edx
f010347a:	89 f8                	mov    %edi,%eax
f010347c:	e8 27 d7 ff ff       	call   f0100ba8 <check_va2pa>
f0103481:	e9 0c fb ff ff       	jmp    f0102f92 <mem_init+0x1b15>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103486:	89 da                	mov    %ebx,%edx
f0103488:	89 f8                	mov    %edi,%eax
f010348a:	e8 19 d7 ff ff       	call   f0100ba8 <check_va2pa>
f010348f:	90                   	nop
f0103490:	e9 0c fa ff ff       	jmp    f0102ea1 <mem_init+0x1a24>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103495:	83 c4 4c             	add    $0x4c,%esp
f0103498:	5b                   	pop    %ebx
f0103499:	5e                   	pop    %esi
f010349a:	5f                   	pop    %edi
f010349b:	5d                   	pop    %ebp
f010349c:	c3                   	ret    

f010349d <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f010349d:	55                   	push   %ebp
f010349e:	89 e5                	mov    %esp,%ebp
f01034a0:	57                   	push   %edi
f01034a1:	56                   	push   %esi
f01034a2:	53                   	push   %ebx
f01034a3:	83 ec 2c             	sub    $0x2c,%esp
f01034a6:	8b 75 08             	mov    0x8(%ebp),%esi
	// LAB 3: Your code here.

	pte_t* page_table_entry;

	const void* lower = ROUNDDOWN(va, PGSIZE);
f01034a9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01034ac:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
	const void* upper = ROUNDDOWN(va+len, PGSIZE);
f01034b2:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034b5:	03 45 10             	add    0x10(%ebp),%eax
f01034b8:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01034bb:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01034c0:	89 45 e4             	mov    %eax,-0x1c(%ebp)

	do{
		page_table_entry = pgdir_walk(env->env_pgdir, (void*)lower, 0);
		if(page_table_entry==NULL || !((perm|PTE_P) & *page_table_entry)){
f01034c3:	8b 7d 14             	mov    0x14(%ebp),%edi
f01034c6:	83 cf 01             	or     $0x1,%edi

	const void* lower = ROUNDDOWN(va, PGSIZE);
	const void* upper = ROUNDDOWN(va+len, PGSIZE);

	do{
		page_table_entry = pgdir_walk(env->env_pgdir, (void*)lower, 0);
f01034c9:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01034d0:	00 
f01034d1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01034d5:	8b 46 60             	mov    0x60(%esi),%eax
f01034d8:	89 04 24             	mov    %eax,(%esp)
f01034db:	e8 a0 dc ff ff       	call   f0101180 <pgdir_walk>
		if(page_table_entry==NULL || !((perm|PTE_P) & *page_table_entry)){
f01034e0:	85 c0                	test   %eax,%eax
f01034e2:	74 04                	je     f01034e8 <user_mem_check+0x4b>
f01034e4:	85 38                	test   %edi,(%eax)
f01034e6:	75 21                	jne    f0103509 <user_mem_check+0x6c>
			if(va<lower)
f01034e8:	39 5d 0c             	cmp    %ebx,0xc(%ebp)
f01034eb:	73 0d                	jae    f01034fa <user_mem_check+0x5d>
				user_mem_check_addr = (uintptr_t) lower;
f01034ed:	89 1d 3c 12 23 f0    	mov    %ebx,0xf023123c
			else
				user_mem_check_addr = (uintptr_t) va;
			return -E_FAULT;
f01034f3:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01034f8:	eb 4f                	jmp    f0103549 <user_mem_check+0xac>
		page_table_entry = pgdir_walk(env->env_pgdir, (void*)lower, 0);
		if(page_table_entry==NULL || !((perm|PTE_P) & *page_table_entry)){
			if(va<lower)
				user_mem_check_addr = (uintptr_t) lower;
			else
				user_mem_check_addr = (uintptr_t) va;
f01034fa:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034fd:	a3 3c 12 23 f0       	mov    %eax,0xf023123c
			return -E_FAULT;
f0103502:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103507:	eb 40                	jmp    f0103549 <user_mem_check+0xac>
		}
		lower += PGSIZE;
f0103509:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	}
	while(lower<upper);
f010350f:	39 5d e4             	cmp    %ebx,-0x1c(%ebp)
f0103512:	77 b5                	ja     f01034c9 <user_mem_check+0x2c>
		else
			user_mem_check_addr = (uintptr_t) va;
		return -E_FAULT;
	}

	return 0;
f0103514:	b8 00 00 00 00       	mov    $0x0,%eax
		}
		lower += PGSIZE;
	}
	while(lower<upper);

	if((uintptr_t)va+len>=ULIM)
f0103519:	81 7d e0 ff ff 7f ef 	cmpl   $0xef7fffff,-0x20(%ebp)
f0103520:	76 27                	jbe    f0103549 <user_mem_check+0xac>
	{
		if((uintptr_t)va<ULIM)
f0103522:	81 7d 0c ff ff 7f ef 	cmpl   $0xef7fffff,0xc(%ebp)
f0103529:	77 11                	ja     f010353c <user_mem_check+0x9f>
			user_mem_check_addr = ULIM;
f010352b:	c7 05 3c 12 23 f0 00 	movl   $0xef800000,0xf023123c
f0103532:	00 80 ef 
		else
			user_mem_check_addr = (uintptr_t) va;
		return -E_FAULT;
f0103535:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f010353a:	eb 0d                	jmp    f0103549 <user_mem_check+0xac>
	if((uintptr_t)va+len>=ULIM)
	{
		if((uintptr_t)va<ULIM)
			user_mem_check_addr = ULIM;
		else
			user_mem_check_addr = (uintptr_t) va;
f010353c:	8b 45 0c             	mov    0xc(%ebp),%eax
f010353f:	a3 3c 12 23 f0       	mov    %eax,0xf023123c
		return -E_FAULT;
f0103544:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
	}

	return 0;
}
f0103549:	83 c4 2c             	add    $0x2c,%esp
f010354c:	5b                   	pop    %ebx
f010354d:	5e                   	pop    %esi
f010354e:	5f                   	pop    %edi
f010354f:	5d                   	pop    %ebp
f0103550:	c3                   	ret    

f0103551 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0103551:	55                   	push   %ebp
f0103552:	89 e5                	mov    %esp,%ebp
f0103554:	53                   	push   %ebx
f0103555:	83 ec 14             	sub    $0x14,%esp
f0103558:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f010355b:	8b 45 14             	mov    0x14(%ebp),%eax
f010355e:	83 c8 04             	or     $0x4,%eax
f0103561:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103565:	8b 45 10             	mov    0x10(%ebp),%eax
f0103568:	89 44 24 08          	mov    %eax,0x8(%esp)
f010356c:	8b 45 0c             	mov    0xc(%ebp),%eax
f010356f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103573:	89 1c 24             	mov    %ebx,(%esp)
f0103576:	e8 22 ff ff ff       	call   f010349d <user_mem_check>
f010357b:	85 c0                	test   %eax,%eax
f010357d:	79 24                	jns    f01035a3 <user_mem_assert+0x52>
		cprintf("[%08x] user_mem_check assertion failure for "
f010357f:	a1 3c 12 23 f0       	mov    0xf023123c,%eax
f0103584:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103588:	8b 43 48             	mov    0x48(%ebx),%eax
f010358b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010358f:	c7 04 24 ac 7d 10 f0 	movl   $0xf0107dac,(%esp)
f0103596:	e8 9c 09 00 00       	call   f0103f37 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010359b:	89 1c 24             	mov    %ebx,(%esp)
f010359e:	e8 a5 06 00 00       	call   f0103c48 <env_destroy>
	}
}
f01035a3:	83 c4 14             	add    $0x14,%esp
f01035a6:	5b                   	pop    %ebx
f01035a7:	5d                   	pop    %ebp
f01035a8:	c3                   	ret    

f01035a9 <region_alloc>:
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
static void
region_alloc(struct Env *e, void *va, size_t len)
{
f01035a9:	55                   	push   %ebp
f01035aa:	89 e5                	mov    %esp,%ebp
f01035ac:	57                   	push   %edi
f01035ad:	56                   	push   %esi
f01035ae:	53                   	push   %ebx
f01035af:	83 ec 1c             	sub    $0x1c,%esp
f01035b2:	89 c7                	mov    %eax,%edi
	//
	// Hint: It is easier to use region_alloc if the caller can pass
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* lower = ROUNDDOWN(va, PGSIZE);
f01035b4:	89 d3                	mov    %edx,%ebx
f01035b6:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
	void* upper = ROUNDUP(va+len, PGSIZE);
f01035bc:	8d b4 0a ff 0f 00 00 	lea    0xfff(%edx,%ecx,1),%esi
f01035c3:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
	size_t size = (upper - lower)/PGSIZE;
	int i, status;
	struct PageInfo *pp;
	while(lower<upper)
f01035c9:	eb 6e                	jmp    f0103639 <region_alloc+0x90>
	{
		pp = page_alloc(0);
f01035cb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01035d2:	e8 9f da ff ff       	call   f0101076 <page_alloc>
		if(pp==NULL)
f01035d7:	85 c0                	test   %eax,%eax
f01035d9:	75 1c                	jne    f01035f7 <region_alloc+0x4e>
			panic("Ran out of memory");
f01035db:	c7 44 24 08 3f 81 10 	movl   $0xf010813f,0x8(%esp)
f01035e2:	f0 
f01035e3:	c7 44 24 04 37 01 00 	movl   $0x137,0x4(%esp)
f01035ea:	00 
f01035eb:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f01035f2:	e8 49 ca ff ff       	call   f0100040 <_panic>

		status = page_insert(e->env_pgdir, pp, lower, PTE_U|PTE_W);
f01035f7:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01035fe:	00 
f01035ff:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103603:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103607:	8b 47 60             	mov    0x60(%edi),%eax
f010360a:	89 04 24             	mov    %eax,(%esp)
f010360d:	e8 80 dd ff ff       	call   f0101392 <page_insert>

		if(status==-E_NO_MEM)
f0103612:	83 f8 fc             	cmp    $0xfffffffc,%eax
f0103615:	75 1c                	jne    f0103633 <region_alloc+0x8a>
			panic("Ran out of memory");	
f0103617:	c7 44 24 08 3f 81 10 	movl   $0xf010813f,0x8(%esp)
f010361e:	f0 
f010361f:	c7 44 24 04 3c 01 00 	movl   $0x13c,0x4(%esp)
f0103626:	00 
f0103627:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f010362e:	e8 0d ca ff ff       	call   f0100040 <_panic>

		lower += PGSIZE;
f0103633:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	void* lower = ROUNDDOWN(va, PGSIZE);
	void* upper = ROUNDUP(va+len, PGSIZE);
	size_t size = (upper - lower)/PGSIZE;
	int i, status;
	struct PageInfo *pp;
	while(lower<upper)
f0103639:	39 f3                	cmp    %esi,%ebx
f010363b:	72 8e                	jb     f01035cb <region_alloc+0x22>
		if(status==-E_NO_MEM)
			panic("Ran out of memory");	

		lower += PGSIZE;
	}
}
f010363d:	83 c4 1c             	add    $0x1c,%esp
f0103640:	5b                   	pop    %ebx
f0103641:	5e                   	pop    %esi
f0103642:	5f                   	pop    %edi
f0103643:	5d                   	pop    %ebp
f0103644:	c3                   	ret    

f0103645 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103645:	55                   	push   %ebp
f0103646:	89 e5                	mov    %esp,%ebp
f0103648:	56                   	push   %esi
f0103649:	53                   	push   %ebx
f010364a:	8b 45 08             	mov    0x8(%ebp),%eax
f010364d:	8b 55 10             	mov    0x10(%ebp),%edx
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103650:	85 c0                	test   %eax,%eax
f0103652:	75 1a                	jne    f010366e <envid2env+0x29>
		*env_store = curenv;
f0103654:	e8 20 32 00 00       	call   f0106879 <cpunum>
f0103659:	6b c0 74             	imul   $0x74,%eax,%eax
f010365c:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103662:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0103665:	89 01                	mov    %eax,(%ecx)
		return 0;
f0103667:	b8 00 00 00 00       	mov    $0x0,%eax
f010366c:	eb 70                	jmp    f01036de <envid2env+0x99>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010366e:	89 c3                	mov    %eax,%ebx
f0103670:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0103676:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103679:	03 1d 48 12 23 f0    	add    0xf0231248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010367f:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f0103683:	74 05                	je     f010368a <envid2env+0x45>
f0103685:	39 43 48             	cmp    %eax,0x48(%ebx)
f0103688:	74 10                	je     f010369a <envid2env+0x55>
		*env_store = 0;
f010368a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010368d:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103693:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103698:	eb 44                	jmp    f01036de <envid2env+0x99>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f010369a:	84 d2                	test   %dl,%dl
f010369c:	74 36                	je     f01036d4 <envid2env+0x8f>
f010369e:	e8 d6 31 00 00       	call   f0106879 <cpunum>
f01036a3:	6b c0 74             	imul   $0x74,%eax,%eax
f01036a6:	39 98 28 20 23 f0    	cmp    %ebx,-0xfdcdfd8(%eax)
f01036ac:	74 26                	je     f01036d4 <envid2env+0x8f>
f01036ae:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01036b1:	e8 c3 31 00 00       	call   f0106879 <cpunum>
f01036b6:	6b c0 74             	imul   $0x74,%eax,%eax
f01036b9:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01036bf:	3b 70 48             	cmp    0x48(%eax),%esi
f01036c2:	74 10                	je     f01036d4 <envid2env+0x8f>
		*env_store = 0;
f01036c4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01036c7:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01036cd:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01036d2:	eb 0a                	jmp    f01036de <envid2env+0x99>
	}

	*env_store = e;
f01036d4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01036d7:	89 18                	mov    %ebx,(%eax)
	return 0;
f01036d9:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01036de:	5b                   	pop    %ebx
f01036df:	5e                   	pop    %esi
f01036e0:	5d                   	pop    %ebp
f01036e1:	c3                   	ret    

f01036e2 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f01036e2:	55                   	push   %ebp
f01036e3:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f01036e5:	b8 20 13 12 f0       	mov    $0xf0121320,%eax
f01036ea:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01036ed:	b8 23 00 00 00       	mov    $0x23,%eax
f01036f2:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f01036f4:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f01036f6:	b0 10                	mov    $0x10,%al
f01036f8:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f01036fa:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f01036fc:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f01036fe:	ea 05 37 10 f0 08 00 	ljmp   $0x8,$0xf0103705
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103705:	b0 00                	mov    $0x0,%al
f0103707:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f010370a:	5d                   	pop    %ebp
f010370b:	c3                   	ret    

f010370c <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010370c:	55                   	push   %ebp
f010370d:	89 e5                	mov    %esp,%ebp
f010370f:	56                   	push   %esi
f0103710:	53                   	push   %ebx
	// LAB 3: Your code here.
	env_free_list = NULL;
	int i;

	for(i=NENV-1;i>=0;i--){
		envs[i].env_status = ENV_FREE;
f0103711:	8b 35 48 12 23 f0    	mov    0xf0231248,%esi
f0103717:	8d 86 84 ef 01 00    	lea    0x1ef84(%esi),%eax
f010371d:	ba 00 04 00 00       	mov    $0x400,%edx
f0103722:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103727:	89 c3                	mov    %eax,%ebx
f0103729:	c7 40 54 00 00 00 00 	movl   $0x0,0x54(%eax)
		envs[i].env_id = 0;
f0103730:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f0103737:	89 48 44             	mov    %ecx,0x44(%eax)
f010373a:	83 e8 7c             	sub    $0x7c,%eax
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	int i;

	for(i=NENV-1;i>=0;i--){
f010373d:	83 ea 01             	sub    $0x1,%edx
f0103740:	74 04                	je     f0103746 <env_init+0x3a>
		envs[i].env_status = ENV_FREE;
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f0103742:	89 d9                	mov    %ebx,%ecx
f0103744:	eb e1                	jmp    f0103727 <env_init+0x1b>
f0103746:	89 35 4c 12 23 f0    	mov    %esi,0xf023124c
	}
	// Per-CPU part of the initialization
	env_init_percpu();
f010374c:	e8 91 ff ff ff       	call   f01036e2 <env_init_percpu>
}
f0103751:	5b                   	pop    %ebx
f0103752:	5e                   	pop    %esi
f0103753:	5d                   	pop    %ebp
f0103754:	c3                   	ret    

f0103755 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103755:	55                   	push   %ebp
f0103756:	89 e5                	mov    %esp,%ebp
f0103758:	53                   	push   %ebx
f0103759:	83 ec 14             	sub    $0x14,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f010375c:	8b 1d 4c 12 23 f0    	mov    0xf023124c,%ebx
f0103762:	85 db                	test   %ebx,%ebx
f0103764:	0f 84 8e 01 00 00    	je     f01038f8 <env_alloc+0x1a3>
{
	int i;
	struct PageInfo *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f010376a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103771:	e8 00 d9 ff ff       	call   f0101076 <page_alloc>
f0103776:	85 c0                	test   %eax,%eax
f0103778:	0f 84 81 01 00 00    	je     f01038ff <env_alloc+0x1aa>
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.

	p->pp_ref++;
f010377e:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
f0103783:	2b 05 90 1e 23 f0    	sub    0xf0231e90,%eax
f0103789:	c1 f8 03             	sar    $0x3,%eax
f010378c:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010378f:	89 c2                	mov    %eax,%edx
f0103791:	c1 ea 0c             	shr    $0xc,%edx
f0103794:	3b 15 88 1e 23 f0    	cmp    0xf0231e88,%edx
f010379a:	72 20                	jb     f01037bc <env_alloc+0x67>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010379c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037a0:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01037a7:	f0 
f01037a8:	c7 44 24 04 c3 00 00 	movl   $0xc3,0x4(%esp)
f01037af:	00 
f01037b0:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f01037b7:	e8 84 c8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01037bc:	2d 00 00 00 10       	sub    $0x10000000,%eax
	e->env_pgdir = KADDR(page2pa(p));
f01037c1:	89 43 60             	mov    %eax,0x60(%ebx)
	// boot_map_region(e->env_pgdir, (uintptr_t)UENVS, ROUNDUP(NENV*sizeof(struct Env), PGSIZE), PADDR(envs), PTE_U);
	// boot_map_region(e->env_pgdir, (uintptr_t)UPAGES, ROUNDUP(npages*sizeof(struct PageInfo), PGSIZE), PADDR(pages), PTE_U);
	// boot_map_region(e->env_pgdir, (uintptr_t)(KSTACKTOP-KSTKSIZE), KSTKSIZE, PADDR(bootstack), PTE_W);
	// boot_map_region(e->env_pgdir, (uintptr_t)KERNBASE, ROUNDUP(~0 - KERNBASE + 1, PGSIZE), 0, PTE_W);

	memmove(e->env_pgdir, kern_pgdir, PGSIZE);
f01037c4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01037cb:	00 
f01037cc:	8b 15 8c 1e 23 f0    	mov    0xf0231e8c,%edx
f01037d2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01037d6:	89 04 24             	mov    %eax,(%esp)
f01037d9:	e8 96 2a 00 00       	call   f0106274 <memmove>

	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01037de:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01037e1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01037e6:	77 20                	ja     f0103808 <env_alloc+0xb3>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01037e8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037ec:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f01037f3:	f0 
f01037f4:	c7 44 24 04 ce 00 00 	movl   $0xce,0x4(%esp)
f01037fb:	00 
f01037fc:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103803:	e8 38 c8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103808:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010380e:	83 ca 05             	or     $0x5,%edx
f0103811:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0103817:	8b 43 48             	mov    0x48(%ebx),%eax
f010381a:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f010381f:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103824:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103829:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f010382c:	89 da                	mov    %ebx,%edx
f010382e:	2b 15 48 12 23 f0    	sub    0xf0231248,%edx
f0103834:	c1 fa 02             	sar    $0x2,%edx
f0103837:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f010383d:	09 d0                	or     %edx,%eax
f010383f:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0103842:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103845:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103848:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f010384f:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f0103856:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f010385d:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103864:	00 
f0103865:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010386c:	00 
f010386d:	89 1c 24             	mov    %ebx,(%esp)
f0103870:	e8 b2 29 00 00       	call   f0106227 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103875:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010387b:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103881:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0103887:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f010388e:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	e->env_tf.tf_eflags = FL_IF;
f0103894:	c7 43 38 00 02 00 00 	movl   $0x200,0x38(%ebx)

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f010389b:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f01038a2:	c6 43 68 00          	movb   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f01038a6:	8b 43 44             	mov    0x44(%ebx),%eax
f01038a9:	a3 4c 12 23 f0       	mov    %eax,0xf023124c
	*newenv_store = e;
f01038ae:	8b 45 08             	mov    0x8(%ebp),%eax
f01038b1:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01038b3:	8b 5b 48             	mov    0x48(%ebx),%ebx
f01038b6:	e8 be 2f 00 00       	call   f0106879 <cpunum>
f01038bb:	6b c0 74             	imul   $0x74,%eax,%eax
f01038be:	ba 00 00 00 00       	mov    $0x0,%edx
f01038c3:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f01038ca:	74 11                	je     f01038dd <env_alloc+0x188>
f01038cc:	e8 a8 2f 00 00       	call   f0106879 <cpunum>
f01038d1:	6b c0 74             	imul   $0x74,%eax,%eax
f01038d4:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01038da:	8b 50 48             	mov    0x48(%eax),%edx
f01038dd:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01038e1:	89 54 24 04          	mov    %edx,0x4(%esp)
f01038e5:	c7 04 24 5c 81 10 f0 	movl   $0xf010815c,(%esp)
f01038ec:	e8 46 06 00 00       	call   f0103f37 <cprintf>
	return 0;
f01038f1:	b8 00 00 00 00       	mov    $0x0,%eax
f01038f6:	eb 0c                	jmp    f0103904 <env_alloc+0x1af>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f01038f8:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01038fd:	eb 05                	jmp    f0103904 <env_alloc+0x1af>
	int i;
	struct PageInfo *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01038ff:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0103904:	83 c4 14             	add    $0x14,%esp
f0103907:	5b                   	pop    %ebx
f0103908:	5d                   	pop    %ebp
f0103909:	c3                   	ret    

f010390a <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, enum EnvType type)
{
f010390a:	55                   	push   %ebp
f010390b:	89 e5                	mov    %esp,%ebp
f010390d:	57                   	push   %edi
f010390e:	56                   	push   %esi
f010390f:	53                   	push   %ebx
f0103910:	83 ec 3c             	sub    $0x3c,%esp
f0103913:	8b 7d 08             	mov    0x8(%ebp),%edi
	// LAB 3: Your code here.
	struct Env *e;
	env_alloc(&e, 0);
f0103916:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010391d:	00 
f010391e:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103921:	89 04 24             	mov    %eax,(%esp)
f0103924:	e8 2c fe ff ff       	call   f0103755 <env_alloc>
	load_icode(e, binary);
f0103929:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010392c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.

	lcr3(PADDR(e->env_pgdir));
f010392f:	8b 40 60             	mov    0x60(%eax),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103932:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103937:	77 20                	ja     f0103959 <env_create+0x4f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103939:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010393d:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0103944:	f0 
f0103945:	c7 44 24 04 79 01 00 	movl   $0x179,0x4(%esp)
f010394c:	00 
f010394d:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103954:	e8 e7 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103959:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010395e:	0f 22 d8             	mov    %eax,%cr3

	struct Elf *header = (struct Elf*)binary;

	if(header->e_magic != ELF_MAGIC)
f0103961:	81 3f 7f 45 4c 46    	cmpl   $0x464c457f,(%edi)
f0103967:	74 1c                	je     f0103985 <env_create+0x7b>
		panic("Not a valid ELF file");
f0103969:	c7 44 24 08 71 81 10 	movl   $0xf0108171,0x8(%esp)
f0103970:	f0 
f0103971:	c7 44 24 04 7e 01 00 	movl   $0x17e,0x4(%esp)
f0103978:	00 
f0103979:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103980:	e8 bb c6 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph, *eph;

	ph = (struct Proghdr *) (binary + header->e_phoff);
f0103985:	89 fb                	mov    %edi,%ebx
f0103987:	03 5f 1c             	add    0x1c(%edi),%ebx
	eph = ph + header->e_phnum;
f010398a:	0f b7 77 2c          	movzwl 0x2c(%edi),%esi
f010398e:	c1 e6 05             	shl    $0x5,%esi
f0103991:	01 de                	add    %ebx,%esi
f0103993:	eb 4b                	jmp    f01039e0 <env_create+0xd6>

	for(;ph<eph; ph++){
		if(ph->p_type != ELF_PROG_LOAD)
f0103995:	83 3b 01             	cmpl   $0x1,(%ebx)
f0103998:	75 43                	jne    f01039dd <env_create+0xd3>
			continue;
		region_alloc(e, (void*)ph->p_va, ph->p_memsz);
f010399a:	8b 4b 14             	mov    0x14(%ebx),%ecx
f010399d:	8b 53 08             	mov    0x8(%ebx),%edx
f01039a0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01039a3:	e8 01 fc ff ff       	call   f01035a9 <region_alloc>
		memset((void*)ph->p_va, 0, ph->p_memsz);
f01039a8:	8b 43 14             	mov    0x14(%ebx),%eax
f01039ab:	89 44 24 08          	mov    %eax,0x8(%esp)
f01039af:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01039b6:	00 
f01039b7:	8b 43 08             	mov    0x8(%ebx),%eax
f01039ba:	89 04 24             	mov    %eax,(%esp)
f01039bd:	e8 65 28 00 00       	call   f0106227 <memset>
		memcpy((void*)ph->p_va, binary + ph->p_offset, ph->p_filesz);
f01039c2:	8b 43 10             	mov    0x10(%ebx),%eax
f01039c5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01039c9:	89 f8                	mov    %edi,%eax
f01039cb:	03 43 04             	add    0x4(%ebx),%eax
f01039ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01039d2:	8b 43 08             	mov    0x8(%ebx),%eax
f01039d5:	89 04 24             	mov    %eax,(%esp)
f01039d8:	e8 ff 28 00 00       	call   f01062dc <memcpy>
	struct Proghdr *ph, *eph;

	ph = (struct Proghdr *) (binary + header->e_phoff);
	eph = ph + header->e_phnum;

	for(;ph<eph; ph++){
f01039dd:	83 c3 20             	add    $0x20,%ebx
f01039e0:	39 de                	cmp    %ebx,%esi
f01039e2:	77 b1                	ja     f0103995 <env_create+0x8b>
	}

	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	region_alloc(e, (void*)(USTACKTOP-PGSIZE), PGSIZE);
f01039e4:	b9 00 10 00 00       	mov    $0x1000,%ecx
f01039e9:	ba 00 d0 bf ee       	mov    $0xeebfd000,%edx
f01039ee:	8b 75 d4             	mov    -0x2c(%ebp),%esi
f01039f1:	89 f0                	mov    %esi,%eax
f01039f3:	e8 b1 fb ff ff       	call   f01035a9 <region_alloc>

	// LAB 3: Your code here.

	e->env_tf.tf_eip = (uintptr_t) header->e_entry;
f01039f8:	8b 47 18             	mov    0x18(%edi),%eax
f01039fb:	89 46 30             	mov    %eax,0x30(%esi)

	lcr3(PADDR(kern_pgdir));
f01039fe:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a03:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a08:	77 20                	ja     f0103a2a <env_create+0x120>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a0a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a0e:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0103a15:	f0 
f0103a16:	c7 44 24 04 96 01 00 	movl   $0x196,0x4(%esp)
f0103a1d:	00 
f0103a1e:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103a25:	e8 16 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a2a:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a2f:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env *e;
	env_alloc(&e, 0);
	load_icode(e, binary);
	e->env_type = type;
f0103a32:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103a35:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103a38:	89 50 50             	mov    %edx,0x50(%eax)
}
f0103a3b:	83 c4 3c             	add    $0x3c,%esp
f0103a3e:	5b                   	pop    %ebx
f0103a3f:	5e                   	pop    %esi
f0103a40:	5f                   	pop    %edi
f0103a41:	5d                   	pop    %ebp
f0103a42:	c3                   	ret    

f0103a43 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a43:	55                   	push   %ebp
f0103a44:	89 e5                	mov    %esp,%ebp
f0103a46:	57                   	push   %edi
f0103a47:	56                   	push   %esi
f0103a48:	53                   	push   %ebx
f0103a49:	83 ec 2c             	sub    $0x2c,%esp
f0103a4c:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103a4f:	e8 25 2e 00 00       	call   f0106879 <cpunum>
f0103a54:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a57:	39 b8 28 20 23 f0    	cmp    %edi,-0xfdcdfd8(%eax)
f0103a5d:	75 34                	jne    f0103a93 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0103a5f:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a64:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a69:	77 20                	ja     f0103a8b <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a6b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a6f:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0103a76:	f0 
f0103a77:	c7 44 24 04 b8 01 00 	movl   $0x1b8,0x4(%esp)
f0103a7e:	00 
f0103a7f:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103a86:	e8 b5 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a8b:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a90:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a93:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103a96:	e8 de 2d 00 00       	call   f0106879 <cpunum>
f0103a9b:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a9e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103aa3:	83 ba 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%edx)
f0103aaa:	74 11                	je     f0103abd <env_free+0x7a>
f0103aac:	e8 c8 2d 00 00       	call   f0106879 <cpunum>
f0103ab1:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ab4:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103aba:	8b 40 48             	mov    0x48(%eax),%eax
f0103abd:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103ac1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ac5:	c7 04 24 86 81 10 f0 	movl   $0xf0108186,(%esp)
f0103acc:	e8 66 04 00 00       	call   f0103f37 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103ad1:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103ad8:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103adb:	89 c8                	mov    %ecx,%eax
f0103add:	c1 e0 02             	shl    $0x2,%eax
f0103ae0:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103ae3:	8b 47 60             	mov    0x60(%edi),%eax
f0103ae6:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103ae9:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103aef:	0f 84 b7 00 00 00    	je     f0103bac <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103af5:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103afb:	89 f0                	mov    %esi,%eax
f0103afd:	c1 e8 0c             	shr    $0xc,%eax
f0103b00:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103b03:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f0103b09:	72 20                	jb     f0103b2b <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103b0b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103b0f:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0103b16:	f0 
f0103b17:	c7 44 24 04 c7 01 00 	movl   $0x1c7,0x4(%esp)
f0103b1e:	00 
f0103b1f:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103b26:	e8 15 c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103b2b:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103b2e:	c1 e0 16             	shl    $0x16,%eax
f0103b31:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103b34:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103b39:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103b40:	01 
f0103b41:	74 17                	je     f0103b5a <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103b43:	89 d8                	mov    %ebx,%eax
f0103b45:	c1 e0 0c             	shl    $0xc,%eax
f0103b48:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103b4b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b4f:	8b 47 60             	mov    0x60(%edi),%eax
f0103b52:	89 04 24             	mov    %eax,(%esp)
f0103b55:	e8 c7 d7 ff ff       	call   f0101321 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103b5a:	83 c3 01             	add    $0x1,%ebx
f0103b5d:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103b63:	75 d4                	jne    f0103b39 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103b65:	8b 47 60             	mov    0x60(%edi),%eax
f0103b68:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103b6b:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct PageInfo*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b72:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103b75:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f0103b7b:	72 1c                	jb     f0103b99 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103b7d:	c7 44 24 08 a8 75 10 	movl   $0xf01075a8,0x8(%esp)
f0103b84:	f0 
f0103b85:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0103b8c:	00 
f0103b8d:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0103b94:	e8 a7 c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b99:	a1 90 1e 23 f0       	mov    0xf0231e90,%eax
f0103b9e:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103ba1:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103ba4:	89 04 24             	mov    %eax,(%esp)
f0103ba7:	e8 b1 d5 ff ff       	call   f010115d <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103bac:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103bb0:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103bb7:	0f 85 1b ff ff ff    	jne    f0103ad8 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103bbd:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103bc0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103bc5:	77 20                	ja     f0103be7 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103bc7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103bcb:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0103bd2:	f0 
f0103bd3:	c7 44 24 04 d5 01 00 	movl   $0x1d5,0x4(%esp)
f0103bda:	00 
f0103bdb:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103be2:	e8 59 c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103be7:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103bee:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct PageInfo*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103bf3:	c1 e8 0c             	shr    $0xc,%eax
f0103bf6:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f0103bfc:	72 1c                	jb     f0103c1a <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103bfe:	c7 44 24 08 a8 75 10 	movl   $0xf01075a8,0x8(%esp)
f0103c05:	f0 
f0103c06:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0103c0d:	00 
f0103c0e:	c7 04 24 e1 7d 10 f0 	movl   $0xf0107de1,(%esp)
f0103c15:	e8 26 c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103c1a:	8b 15 90 1e 23 f0    	mov    0xf0231e90,%edx
f0103c20:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103c23:	89 04 24             	mov    %eax,(%esp)
f0103c26:	e8 32 d5 ff ff       	call   f010115d <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103c2b:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103c32:	a1 4c 12 23 f0       	mov    0xf023124c,%eax
f0103c37:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103c3a:	89 3d 4c 12 23 f0    	mov    %edi,0xf023124c
}
f0103c40:	83 c4 2c             	add    $0x2c,%esp
f0103c43:	5b                   	pop    %ebx
f0103c44:	5e                   	pop    %esi
f0103c45:	5f                   	pop    %edi
f0103c46:	5d                   	pop    %ebp
f0103c47:	c3                   	ret    

f0103c48 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103c48:	55                   	push   %ebp
f0103c49:	89 e5                	mov    %esp,%ebp
f0103c4b:	53                   	push   %ebx
f0103c4c:	83 ec 14             	sub    $0x14,%esp
f0103c4f:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103c52:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103c56:	75 19                	jne    f0103c71 <env_destroy+0x29>
f0103c58:	e8 1c 2c 00 00       	call   f0106879 <cpunum>
f0103c5d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c60:	39 98 28 20 23 f0    	cmp    %ebx,-0xfdcdfd8(%eax)
f0103c66:	74 09                	je     f0103c71 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103c68:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103c6f:	eb 2f                	jmp    f0103ca0 <env_destroy+0x58>
	}

	env_free(e);
f0103c71:	89 1c 24             	mov    %ebx,(%esp)
f0103c74:	e8 ca fd ff ff       	call   f0103a43 <env_free>

	if (curenv == e) {
f0103c79:	e8 fb 2b 00 00       	call   f0106879 <cpunum>
f0103c7e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c81:	39 98 28 20 23 f0    	cmp    %ebx,-0xfdcdfd8(%eax)
f0103c87:	75 17                	jne    f0103ca0 <env_destroy+0x58>
		curenv = NULL;
f0103c89:	e8 eb 2b 00 00       	call   f0106879 <cpunum>
f0103c8e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c91:	c7 80 28 20 23 f0 00 	movl   $0x0,-0xfdcdfd8(%eax)
f0103c98:	00 00 00 
		sched_yield();
f0103c9b:	e8 d6 11 00 00       	call   f0104e76 <sched_yield>
	}
}
f0103ca0:	83 c4 14             	add    $0x14,%esp
f0103ca3:	5b                   	pop    %ebx
f0103ca4:	5d                   	pop    %ebp
f0103ca5:	c3                   	ret    

f0103ca6 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103ca6:	55                   	push   %ebp
f0103ca7:	89 e5                	mov    %esp,%ebp
f0103ca9:	53                   	push   %ebx
f0103caa:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103cad:	e8 c7 2b 00 00       	call   f0106879 <cpunum>
f0103cb2:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cb5:	8b 98 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%ebx
f0103cbb:	e8 b9 2b 00 00       	call   f0106879 <cpunum>
f0103cc0:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103cc3:	8b 65 08             	mov    0x8(%ebp),%esp
f0103cc6:	61                   	popa   
f0103cc7:	07                   	pop    %es
f0103cc8:	1f                   	pop    %ds
f0103cc9:	83 c4 08             	add    $0x8,%esp
f0103ccc:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103ccd:	c7 44 24 08 9c 81 10 	movl   $0xf010819c,0x8(%esp)
f0103cd4:	f0 
f0103cd5:	c7 44 24 04 0b 02 00 	movl   $0x20b,0x4(%esp)
f0103cdc:	00 
f0103cdd:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103ce4:	e8 57 c3 ff ff       	call   f0100040 <_panic>

f0103ce9 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103ce9:	55                   	push   %ebp
f0103cea:	89 e5                	mov    %esp,%ebp
f0103cec:	53                   	push   %ebx
f0103ced:	83 ec 14             	sub    $0x14,%esp
f0103cf0:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.

	if(e!=NULL)
f0103cf3:	85 db                	test   %ebx,%ebx
f0103cf5:	0f 84 b7 00 00 00    	je     f0103db2 <env_run+0xc9>
	{
		if(curenv){
f0103cfb:	e8 79 2b 00 00       	call   f0106879 <cpunum>
f0103d00:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d03:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f0103d0a:	74 29                	je     f0103d35 <env_run+0x4c>
			if(curenv->env_status == ENV_RUNNING)
f0103d0c:	e8 68 2b 00 00       	call   f0106879 <cpunum>
f0103d11:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d14:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103d1a:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103d1e:	75 15                	jne    f0103d35 <env_run+0x4c>
				curenv->env_status = ENV_RUNNABLE;
f0103d20:	e8 54 2b 00 00       	call   f0106879 <cpunum>
f0103d25:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d28:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103d2e:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
		}
		curenv = e;
f0103d35:	e8 3f 2b 00 00       	call   f0106879 <cpunum>
f0103d3a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d3d:	89 98 28 20 23 f0    	mov    %ebx,-0xfdcdfd8(%eax)
		curenv->env_status = ENV_RUNNING;
f0103d43:	e8 31 2b 00 00       	call   f0106879 <cpunum>
f0103d48:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d4b:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103d51:	c7 40 54 03 00 00 00 	movl   $0x3,0x54(%eax)
		curenv->env_runs++;
f0103d58:	e8 1c 2b 00 00       	call   f0106879 <cpunum>
f0103d5d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d60:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0103d66:	83 40 58 01          	addl   $0x1,0x58(%eax)
		lcr3(PADDR(e->env_pgdir));
f0103d6a:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103d6d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103d72:	77 20                	ja     f0103d94 <env_run+0xab>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103d74:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103d78:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0103d7f:	f0 
f0103d80:	c7 44 24 04 33 02 00 	movl   $0x233,0x4(%esp)
f0103d87:	00 
f0103d88:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103d8f:	e8 ac c2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103d94:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d99:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103d9c:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f0103da3:	e8 fb 2d 00 00       	call   f0106ba3 <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103da8:	f3 90                	pause  
		unlock_kernel();
		env_pop_tf(&(e->env_tf));
f0103daa:	89 1c 24             	mov    %ebx,(%esp)
f0103dad:	e8 f4 fe ff ff       	call   f0103ca6 <env_pop_tf>
	}	

	panic("placating the compiler");
f0103db2:	c7 44 24 08 a8 81 10 	movl   $0xf01081a8,0x8(%esp)
f0103db9:	f0 
f0103dba:	c7 44 24 04 38 02 00 	movl   $0x238,0x4(%esp)
f0103dc1:	00 
f0103dc2:	c7 04 24 51 81 10 f0 	movl   $0xf0108151,(%esp)
f0103dc9:	e8 72 c2 ff ff       	call   f0100040 <_panic>

f0103dce <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103dce:	55                   	push   %ebp
f0103dcf:	89 e5                	mov    %esp,%ebp
f0103dd1:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103dd5:	ba 70 00 00 00       	mov    $0x70,%edx
f0103dda:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103ddb:	b2 71                	mov    $0x71,%dl
f0103ddd:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103dde:	0f b6 c0             	movzbl %al,%eax
}
f0103de1:	5d                   	pop    %ebp
f0103de2:	c3                   	ret    

f0103de3 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103de3:	55                   	push   %ebp
f0103de4:	89 e5                	mov    %esp,%ebp
f0103de6:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103dea:	ba 70 00 00 00       	mov    $0x70,%edx
f0103def:	ee                   	out    %al,(%dx)
f0103df0:	b2 71                	mov    $0x71,%dl
f0103df2:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103df5:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103df6:	5d                   	pop    %ebp
f0103df7:	c3                   	ret    

f0103df8 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103df8:	55                   	push   %ebp
f0103df9:	89 e5                	mov    %esp,%ebp
f0103dfb:	56                   	push   %esi
f0103dfc:	53                   	push   %ebx
f0103dfd:	83 ec 10             	sub    $0x10,%esp
f0103e00:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103e03:	66 a3 a8 13 12 f0    	mov    %ax,0xf01213a8
	if (!didinit)
f0103e09:	80 3d 50 12 23 f0 00 	cmpb   $0x0,0xf0231250
f0103e10:	74 4e                	je     f0103e60 <irq_setmask_8259A+0x68>
f0103e12:	89 c6                	mov    %eax,%esi
f0103e14:	ba 21 00 00 00       	mov    $0x21,%edx
f0103e19:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103e1a:	66 c1 e8 08          	shr    $0x8,%ax
f0103e1e:	b2 a1                	mov    $0xa1,%dl
f0103e20:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103e21:	c7 04 24 bf 81 10 f0 	movl   $0xf01081bf,(%esp)
f0103e28:	e8 0a 01 00 00       	call   f0103f37 <cprintf>
	for (i = 0; i < 16; i++)
f0103e2d:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103e32:	0f b7 f6             	movzwl %si,%esi
f0103e35:	f7 d6                	not    %esi
f0103e37:	0f a3 de             	bt     %ebx,%esi
f0103e3a:	73 10                	jae    f0103e4c <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103e3c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103e40:	c7 04 24 5b 86 10 f0 	movl   $0xf010865b,(%esp)
f0103e47:	e8 eb 00 00 00       	call   f0103f37 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103e4c:	83 c3 01             	add    $0x1,%ebx
f0103e4f:	83 fb 10             	cmp    $0x10,%ebx
f0103e52:	75 e3                	jne    f0103e37 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103e54:	c7 04 24 0d 81 10 f0 	movl   $0xf010810d,(%esp)
f0103e5b:	e8 d7 00 00 00       	call   f0103f37 <cprintf>
}
f0103e60:	83 c4 10             	add    $0x10,%esp
f0103e63:	5b                   	pop    %ebx
f0103e64:	5e                   	pop    %esi
f0103e65:	5d                   	pop    %ebp
f0103e66:	c3                   	ret    

f0103e67 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103e67:	c6 05 50 12 23 f0 01 	movb   $0x1,0xf0231250
f0103e6e:	ba 21 00 00 00       	mov    $0x21,%edx
f0103e73:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103e78:	ee                   	out    %al,(%dx)
f0103e79:	b2 a1                	mov    $0xa1,%dl
f0103e7b:	ee                   	out    %al,(%dx)
f0103e7c:	b2 20                	mov    $0x20,%dl
f0103e7e:	b8 11 00 00 00       	mov    $0x11,%eax
f0103e83:	ee                   	out    %al,(%dx)
f0103e84:	b2 21                	mov    $0x21,%dl
f0103e86:	b8 20 00 00 00       	mov    $0x20,%eax
f0103e8b:	ee                   	out    %al,(%dx)
f0103e8c:	b8 04 00 00 00       	mov    $0x4,%eax
f0103e91:	ee                   	out    %al,(%dx)
f0103e92:	b8 03 00 00 00       	mov    $0x3,%eax
f0103e97:	ee                   	out    %al,(%dx)
f0103e98:	b2 a0                	mov    $0xa0,%dl
f0103e9a:	b8 11 00 00 00       	mov    $0x11,%eax
f0103e9f:	ee                   	out    %al,(%dx)
f0103ea0:	b2 a1                	mov    $0xa1,%dl
f0103ea2:	b8 28 00 00 00       	mov    $0x28,%eax
f0103ea7:	ee                   	out    %al,(%dx)
f0103ea8:	b8 02 00 00 00       	mov    $0x2,%eax
f0103ead:	ee                   	out    %al,(%dx)
f0103eae:	b8 01 00 00 00       	mov    $0x1,%eax
f0103eb3:	ee                   	out    %al,(%dx)
f0103eb4:	b2 20                	mov    $0x20,%dl
f0103eb6:	b8 68 00 00 00       	mov    $0x68,%eax
f0103ebb:	ee                   	out    %al,(%dx)
f0103ebc:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103ec1:	ee                   	out    %al,(%dx)
f0103ec2:	b2 a0                	mov    $0xa0,%dl
f0103ec4:	b8 68 00 00 00       	mov    $0x68,%eax
f0103ec9:	ee                   	out    %al,(%dx)
f0103eca:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103ecf:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103ed0:	0f b7 05 a8 13 12 f0 	movzwl 0xf01213a8,%eax
f0103ed7:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103edb:	74 12                	je     f0103eef <pic_init+0x88>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103edd:	55                   	push   %ebp
f0103ede:	89 e5                	mov    %esp,%ebp
f0103ee0:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103ee3:	0f b7 c0             	movzwl %ax,%eax
f0103ee6:	89 04 24             	mov    %eax,(%esp)
f0103ee9:	e8 0a ff ff ff       	call   f0103df8 <irq_setmask_8259A>
}
f0103eee:	c9                   	leave  
f0103eef:	f3 c3                	repz ret 

f0103ef1 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103ef1:	55                   	push   %ebp
f0103ef2:	89 e5                	mov    %esp,%ebp
f0103ef4:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103ef7:	8b 45 08             	mov    0x8(%ebp),%eax
f0103efa:	89 04 24             	mov    %eax,(%esp)
f0103efd:	e8 c8 c8 ff ff       	call   f01007ca <cputchar>
	*cnt++;
}
f0103f02:	c9                   	leave  
f0103f03:	c3                   	ret    

f0103f04 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103f04:	55                   	push   %ebp
f0103f05:	89 e5                	mov    %esp,%ebp
f0103f07:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103f0a:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103f11:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103f14:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103f18:	8b 45 08             	mov    0x8(%ebp),%eax
f0103f1b:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103f1f:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103f22:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f26:	c7 04 24 f1 3e 10 f0 	movl   $0xf0103ef1,(%esp)
f0103f2d:	e8 3c 1c 00 00       	call   f0105b6e <vprintfmt>
	return cnt;
}
f0103f32:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103f35:	c9                   	leave  
f0103f36:	c3                   	ret    

f0103f37 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103f37:	55                   	push   %ebp
f0103f38:	89 e5                	mov    %esp,%ebp
f0103f3a:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103f3d:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103f40:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f44:	8b 45 08             	mov    0x8(%ebp),%eax
f0103f47:	89 04 24             	mov    %eax,(%esp)
f0103f4a:	e8 b5 ff ff ff       	call   f0103f04 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103f4f:	c9                   	leave  
f0103f50:	c3                   	ret    
f0103f51:	66 90                	xchg   %ax,%ax
f0103f53:	66 90                	xchg   %ax,%ax
f0103f55:	66 90                	xchg   %ax,%ax
f0103f57:	66 90                	xchg   %ax,%ax
f0103f59:	66 90                	xchg   %ax,%ax
f0103f5b:	66 90                	xchg   %ax,%ax
f0103f5d:	66 90                	xchg   %ax,%ax
f0103f5f:	90                   	nop

f0103f60 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103f60:	55                   	push   %ebp
f0103f61:	89 e5                	mov    %esp,%ebp
f0103f63:	57                   	push   %edi
f0103f64:	56                   	push   %esi
f0103f65:	53                   	push   %ebx
f0103f66:	83 ec 0c             	sub    $0xc,%esp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	thiscpu->cpu_ts.ts_esp0 = KSTACKTOP - thiscpu->cpu_id*(KSTKSIZE+KSTKGAP);
f0103f69:	e8 0b 29 00 00       	call   f0106879 <cpunum>
f0103f6e:	89 c3                	mov    %eax,%ebx
f0103f70:	e8 04 29 00 00       	call   f0106879 <cpunum>
f0103f75:	6b db 74             	imul   $0x74,%ebx,%ebx
f0103f78:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f7b:	0f b6 80 20 20 23 f0 	movzbl -0xfdcdfe0(%eax),%eax
f0103f82:	f7 d8                	neg    %eax
f0103f84:	c1 e0 10             	shl    $0x10,%eax
f0103f87:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103f8c:	89 83 30 20 23 f0    	mov    %eax,-0xfdcdfd0(%ebx)
	thiscpu->cpu_ts.ts_ss0 = GD_KD;
f0103f92:	e8 e2 28 00 00       	call   f0106879 <cpunum>
f0103f97:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f9a:	66 c7 80 34 20 23 f0 	movw   $0x10,-0xfdcdfcc(%eax)
f0103fa1:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[(GD_TSS0 >> 3) + thiscpu->cpu_id] = SEG16(STS_T32A, (uint32_t) (&(thiscpu->cpu_ts)),
f0103fa3:	e8 d1 28 00 00       	call   f0106879 <cpunum>
f0103fa8:	6b c0 74             	imul   $0x74,%eax,%eax
f0103fab:	0f b6 98 20 20 23 f0 	movzbl -0xfdcdfe0(%eax),%ebx
f0103fb2:	83 c3 05             	add    $0x5,%ebx
f0103fb5:	e8 bf 28 00 00       	call   f0106879 <cpunum>
f0103fba:	89 c7                	mov    %eax,%edi
f0103fbc:	e8 b8 28 00 00       	call   f0106879 <cpunum>
f0103fc1:	89 c6                	mov    %eax,%esi
f0103fc3:	e8 b1 28 00 00       	call   f0106879 <cpunum>
f0103fc8:	66 c7 04 dd 40 13 12 	movw   $0x67,-0xfedecc0(,%ebx,8)
f0103fcf:	f0 67 00 
f0103fd2:	6b ff 74             	imul   $0x74,%edi,%edi
f0103fd5:	81 c7 2c 20 23 f0    	add    $0xf023202c,%edi
f0103fdb:	66 89 3c dd 42 13 12 	mov    %di,-0xfedecbe(,%ebx,8)
f0103fe2:	f0 
f0103fe3:	6b d6 74             	imul   $0x74,%esi,%edx
f0103fe6:	81 c2 2c 20 23 f0    	add    $0xf023202c,%edx
f0103fec:	c1 ea 10             	shr    $0x10,%edx
f0103fef:	88 14 dd 44 13 12 f0 	mov    %dl,-0xfedecbc(,%ebx,8)
f0103ff6:	c6 04 dd 45 13 12 f0 	movb   $0x99,-0xfedecbb(,%ebx,8)
f0103ffd:	99 
f0103ffe:	c6 04 dd 46 13 12 f0 	movb   $0x40,-0xfedecba(,%ebx,8)
f0104005:	40 
f0104006:	6b c0 74             	imul   $0x74,%eax,%eax
f0104009:	05 2c 20 23 f0       	add    $0xf023202c,%eax
f010400e:	c1 e8 18             	shr    $0x18,%eax
f0104011:	88 04 dd 47 13 12 f0 	mov    %al,-0xfedecb9(,%ebx,8)
					sizeof(struct Taskstate) - 1, 0);
	gdt[(GD_TSS0 >> 3) + thiscpu->cpu_id].sd_s = 0;
f0104018:	e8 5c 28 00 00       	call   f0106879 <cpunum>
f010401d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104020:	0f b6 80 20 20 23 f0 	movzbl -0xfdcdfe0(%eax),%eax
f0104027:	80 24 c5 6d 13 12 f0 	andb   $0xef,-0xfedec93(,%eax,8)
f010402e:	ef 

	// Load the TSS selector (like other segment selectors, the
	// bottom three bits are special; we leave them 0)
	ltr(((GD_TSS0 >> 3) + thiscpu->cpu_id)<<3);
f010402f:	e8 45 28 00 00       	call   f0106879 <cpunum>
f0104034:	6b c0 74             	imul   $0x74,%eax,%eax
f0104037:	0f b6 80 20 20 23 f0 	movzbl -0xfdcdfe0(%eax),%eax
f010403e:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0104045:	0f 00 d8             	ltr    %ax
}

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0104048:	b8 aa 13 12 f0       	mov    $0xf01213aa,%eax
f010404d:	0f 01 18             	lidtl  (%eax)

	// Load the IDT
	lidt(&idt_pd);
}
f0104050:	83 c4 0c             	add    $0xc,%esp
f0104053:	5b                   	pop    %ebx
f0104054:	5e                   	pop    %esi
f0104055:	5f                   	pop    %edi
f0104056:	5d                   	pop    %ebp
f0104057:	c3                   	ret    

f0104058 <trap_init>:
}


void
trap_init(void)
{
f0104058:	55                   	push   %ebp
f0104059:	89 e5                	mov    %esp,%ebp
f010405b:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];

	// LAB 3: Your code here.

	SETGATE(idt[0], 0, GD_KT, &t_divide, 0);
f010405e:	b8 60 4c 10 f0       	mov    $0xf0104c60,%eax
f0104063:	66 a3 60 12 23 f0    	mov    %ax,0xf0231260
f0104069:	66 c7 05 62 12 23 f0 	movw   $0x8,0xf0231262
f0104070:	08 00 
f0104072:	c6 05 64 12 23 f0 00 	movb   $0x0,0xf0231264
f0104079:	c6 05 65 12 23 f0 8e 	movb   $0x8e,0xf0231265
f0104080:	c1 e8 10             	shr    $0x10,%eax
f0104083:	66 a3 66 12 23 f0    	mov    %ax,0xf0231266
	SETGATE(idt[1], 0, GD_KT, &t_debug, 0);
f0104089:	b8 6a 4c 10 f0       	mov    $0xf0104c6a,%eax
f010408e:	66 a3 68 12 23 f0    	mov    %ax,0xf0231268
f0104094:	66 c7 05 6a 12 23 f0 	movw   $0x8,0xf023126a
f010409b:	08 00 
f010409d:	c6 05 6c 12 23 f0 00 	movb   $0x0,0xf023126c
f01040a4:	c6 05 6d 12 23 f0 8e 	movb   $0x8e,0xf023126d
f01040ab:	c1 e8 10             	shr    $0x10,%eax
f01040ae:	66 a3 6e 12 23 f0    	mov    %ax,0xf023126e
	SETGATE(idt[2], 0, GD_KT, &t_nmi, 0);
f01040b4:	b8 74 4c 10 f0       	mov    $0xf0104c74,%eax
f01040b9:	66 a3 70 12 23 f0    	mov    %ax,0xf0231270
f01040bf:	66 c7 05 72 12 23 f0 	movw   $0x8,0xf0231272
f01040c6:	08 00 
f01040c8:	c6 05 74 12 23 f0 00 	movb   $0x0,0xf0231274
f01040cf:	c6 05 75 12 23 f0 8e 	movb   $0x8e,0xf0231275
f01040d6:	c1 e8 10             	shr    $0x10,%eax
f01040d9:	66 a3 76 12 23 f0    	mov    %ax,0xf0231276
	SETGATE(idt[3], 0, GD_KT, &t_brkpt, 3);
f01040df:	b8 7e 4c 10 f0       	mov    $0xf0104c7e,%eax
f01040e4:	66 a3 78 12 23 f0    	mov    %ax,0xf0231278
f01040ea:	66 c7 05 7a 12 23 f0 	movw   $0x8,0xf023127a
f01040f1:	08 00 
f01040f3:	c6 05 7c 12 23 f0 00 	movb   $0x0,0xf023127c
f01040fa:	c6 05 7d 12 23 f0 ee 	movb   $0xee,0xf023127d
f0104101:	c1 e8 10             	shr    $0x10,%eax
f0104104:	66 a3 7e 12 23 f0    	mov    %ax,0xf023127e
	SETGATE(idt[4], 0, GD_KT, &t_oflow, 0);
f010410a:	b8 88 4c 10 f0       	mov    $0xf0104c88,%eax
f010410f:	66 a3 80 12 23 f0    	mov    %ax,0xf0231280
f0104115:	66 c7 05 82 12 23 f0 	movw   $0x8,0xf0231282
f010411c:	08 00 
f010411e:	c6 05 84 12 23 f0 00 	movb   $0x0,0xf0231284
f0104125:	c6 05 85 12 23 f0 8e 	movb   $0x8e,0xf0231285
f010412c:	c1 e8 10             	shr    $0x10,%eax
f010412f:	66 a3 86 12 23 f0    	mov    %ax,0xf0231286
	SETGATE(idt[5], 0, GD_KT, &t_bound, 0);
f0104135:	b8 92 4c 10 f0       	mov    $0xf0104c92,%eax
f010413a:	66 a3 88 12 23 f0    	mov    %ax,0xf0231288
f0104140:	66 c7 05 8a 12 23 f0 	movw   $0x8,0xf023128a
f0104147:	08 00 
f0104149:	c6 05 8c 12 23 f0 00 	movb   $0x0,0xf023128c
f0104150:	c6 05 8d 12 23 f0 8e 	movb   $0x8e,0xf023128d
f0104157:	c1 e8 10             	shr    $0x10,%eax
f010415a:	66 a3 8e 12 23 f0    	mov    %ax,0xf023128e
	SETGATE(idt[6], 0, GD_KT, &t_illop, 0);
f0104160:	b8 9c 4c 10 f0       	mov    $0xf0104c9c,%eax
f0104165:	66 a3 90 12 23 f0    	mov    %ax,0xf0231290
f010416b:	66 c7 05 92 12 23 f0 	movw   $0x8,0xf0231292
f0104172:	08 00 
f0104174:	c6 05 94 12 23 f0 00 	movb   $0x0,0xf0231294
f010417b:	c6 05 95 12 23 f0 8e 	movb   $0x8e,0xf0231295
f0104182:	c1 e8 10             	shr    $0x10,%eax
f0104185:	66 a3 96 12 23 f0    	mov    %ax,0xf0231296
	SETGATE(idt[7], 0, GD_KT, &t_device, 0);
f010418b:	b8 a6 4c 10 f0       	mov    $0xf0104ca6,%eax
f0104190:	66 a3 98 12 23 f0    	mov    %ax,0xf0231298
f0104196:	66 c7 05 9a 12 23 f0 	movw   $0x8,0xf023129a
f010419d:	08 00 
f010419f:	c6 05 9c 12 23 f0 00 	movb   $0x0,0xf023129c
f01041a6:	c6 05 9d 12 23 f0 8e 	movb   $0x8e,0xf023129d
f01041ad:	c1 e8 10             	shr    $0x10,%eax
f01041b0:	66 a3 9e 12 23 f0    	mov    %ax,0xf023129e
	SETGATE(idt[8], 0, GD_KT, &t_dblflt, 0);
f01041b6:	b8 b0 4c 10 f0       	mov    $0xf0104cb0,%eax
f01041bb:	66 a3 a0 12 23 f0    	mov    %ax,0xf02312a0
f01041c1:	66 c7 05 a2 12 23 f0 	movw   $0x8,0xf02312a2
f01041c8:	08 00 
f01041ca:	c6 05 a4 12 23 f0 00 	movb   $0x0,0xf02312a4
f01041d1:	c6 05 a5 12 23 f0 8e 	movb   $0x8e,0xf02312a5
f01041d8:	c1 e8 10             	shr    $0x10,%eax
f01041db:	66 a3 a6 12 23 f0    	mov    %ax,0xf02312a6
	SETGATE(idt[9], 0, GD_KT, &t_coproc, 0);
f01041e1:	b8 b8 4c 10 f0       	mov    $0xf0104cb8,%eax
f01041e6:	66 a3 a8 12 23 f0    	mov    %ax,0xf02312a8
f01041ec:	66 c7 05 aa 12 23 f0 	movw   $0x8,0xf02312aa
f01041f3:	08 00 
f01041f5:	c6 05 ac 12 23 f0 00 	movb   $0x0,0xf02312ac
f01041fc:	c6 05 ad 12 23 f0 8e 	movb   $0x8e,0xf02312ad
f0104203:	c1 e8 10             	shr    $0x10,%eax
f0104206:	66 a3 ae 12 23 f0    	mov    %ax,0xf02312ae
	SETGATE(idt[10], 0, GD_KT, &t_tss, 0);
f010420c:	b8 c2 4c 10 f0       	mov    $0xf0104cc2,%eax
f0104211:	66 a3 b0 12 23 f0    	mov    %ax,0xf02312b0
f0104217:	66 c7 05 b2 12 23 f0 	movw   $0x8,0xf02312b2
f010421e:	08 00 
f0104220:	c6 05 b4 12 23 f0 00 	movb   $0x0,0xf02312b4
f0104227:	c6 05 b5 12 23 f0 8e 	movb   $0x8e,0xf02312b5
f010422e:	c1 e8 10             	shr    $0x10,%eax
f0104231:	66 a3 b6 12 23 f0    	mov    %ax,0xf02312b6
	SETGATE(idt[11], 0, GD_KT, &t_segnp, 0);
f0104237:	b8 ca 4c 10 f0       	mov    $0xf0104cca,%eax
f010423c:	66 a3 b8 12 23 f0    	mov    %ax,0xf02312b8
f0104242:	66 c7 05 ba 12 23 f0 	movw   $0x8,0xf02312ba
f0104249:	08 00 
f010424b:	c6 05 bc 12 23 f0 00 	movb   $0x0,0xf02312bc
f0104252:	c6 05 bd 12 23 f0 8e 	movb   $0x8e,0xf02312bd
f0104259:	c1 e8 10             	shr    $0x10,%eax
f010425c:	66 a3 be 12 23 f0    	mov    %ax,0xf02312be
	SETGATE(idt[12], 0, GD_KT, &t_stack, 0);
f0104262:	b8 d2 4c 10 f0       	mov    $0xf0104cd2,%eax
f0104267:	66 a3 c0 12 23 f0    	mov    %ax,0xf02312c0
f010426d:	66 c7 05 c2 12 23 f0 	movw   $0x8,0xf02312c2
f0104274:	08 00 
f0104276:	c6 05 c4 12 23 f0 00 	movb   $0x0,0xf02312c4
f010427d:	c6 05 c5 12 23 f0 8e 	movb   $0x8e,0xf02312c5
f0104284:	c1 e8 10             	shr    $0x10,%eax
f0104287:	66 a3 c6 12 23 f0    	mov    %ax,0xf02312c6
	SETGATE(idt[13], 0, GD_KT, &t_gpflt, 0);
f010428d:	b8 da 4c 10 f0       	mov    $0xf0104cda,%eax
f0104292:	66 a3 c8 12 23 f0    	mov    %ax,0xf02312c8
f0104298:	66 c7 05 ca 12 23 f0 	movw   $0x8,0xf02312ca
f010429f:	08 00 
f01042a1:	c6 05 cc 12 23 f0 00 	movb   $0x0,0xf02312cc
f01042a8:	c6 05 cd 12 23 f0 8e 	movb   $0x8e,0xf02312cd
f01042af:	c1 e8 10             	shr    $0x10,%eax
f01042b2:	66 a3 ce 12 23 f0    	mov    %ax,0xf02312ce
	SETGATE(idt[14], 0, GD_KT, &t_pgflt, 0);
f01042b8:	b8 e2 4c 10 f0       	mov    $0xf0104ce2,%eax
f01042bd:	66 a3 d0 12 23 f0    	mov    %ax,0xf02312d0
f01042c3:	66 c7 05 d2 12 23 f0 	movw   $0x8,0xf02312d2
f01042ca:	08 00 
f01042cc:	c6 05 d4 12 23 f0 00 	movb   $0x0,0xf02312d4
f01042d3:	c6 05 d5 12 23 f0 8e 	movb   $0x8e,0xf02312d5
f01042da:	c1 e8 10             	shr    $0x10,%eax
f01042dd:	66 a3 d6 12 23 f0    	mov    %ax,0xf02312d6
	SETGATE(idt[15], 0, GD_KT, &t_res, 0);
f01042e3:	b8 ea 4c 10 f0       	mov    $0xf0104cea,%eax
f01042e8:	66 a3 d8 12 23 f0    	mov    %ax,0xf02312d8
f01042ee:	66 c7 05 da 12 23 f0 	movw   $0x8,0xf02312da
f01042f5:	08 00 
f01042f7:	c6 05 dc 12 23 f0 00 	movb   $0x0,0xf02312dc
f01042fe:	c6 05 dd 12 23 f0 8e 	movb   $0x8e,0xf02312dd
f0104305:	c1 e8 10             	shr    $0x10,%eax
f0104308:	66 a3 de 12 23 f0    	mov    %ax,0xf02312de
	SETGATE(idt[16], 0, GD_KT, &t_fperr, 0);
f010430e:	b8 f4 4c 10 f0       	mov    $0xf0104cf4,%eax
f0104313:	66 a3 e0 12 23 f0    	mov    %ax,0xf02312e0
f0104319:	66 c7 05 e2 12 23 f0 	movw   $0x8,0xf02312e2
f0104320:	08 00 
f0104322:	c6 05 e4 12 23 f0 00 	movb   $0x0,0xf02312e4
f0104329:	c6 05 e5 12 23 f0 8e 	movb   $0x8e,0xf02312e5
f0104330:	c1 e8 10             	shr    $0x10,%eax
f0104333:	66 a3 e6 12 23 f0    	mov    %ax,0xf02312e6
	SETGATE(idt[17], 0, GD_KT, &t_align, 0);
f0104339:	b8 fe 4c 10 f0       	mov    $0xf0104cfe,%eax
f010433e:	66 a3 e8 12 23 f0    	mov    %ax,0xf02312e8
f0104344:	66 c7 05 ea 12 23 f0 	movw   $0x8,0xf02312ea
f010434b:	08 00 
f010434d:	c6 05 ec 12 23 f0 00 	movb   $0x0,0xf02312ec
f0104354:	c6 05 ed 12 23 f0 8e 	movb   $0x8e,0xf02312ed
f010435b:	c1 e8 10             	shr    $0x10,%eax
f010435e:	66 a3 ee 12 23 f0    	mov    %ax,0xf02312ee
	SETGATE(idt[18], 0, GD_KT, &t_mchk, 0);
f0104364:	b8 02 4d 10 f0       	mov    $0xf0104d02,%eax
f0104369:	66 a3 f0 12 23 f0    	mov    %ax,0xf02312f0
f010436f:	66 c7 05 f2 12 23 f0 	movw   $0x8,0xf02312f2
f0104376:	08 00 
f0104378:	c6 05 f4 12 23 f0 00 	movb   $0x0,0xf02312f4
f010437f:	c6 05 f5 12 23 f0 8e 	movb   $0x8e,0xf02312f5
f0104386:	c1 e8 10             	shr    $0x10,%eax
f0104389:	66 a3 f6 12 23 f0    	mov    %ax,0xf02312f6
	SETGATE(idt[19], 0, GD_KT, &t_simderr, 0);
f010438f:	b8 08 4d 10 f0       	mov    $0xf0104d08,%eax
f0104394:	66 a3 f8 12 23 f0    	mov    %ax,0xf02312f8
f010439a:	66 c7 05 fa 12 23 f0 	movw   $0x8,0xf02312fa
f01043a1:	08 00 
f01043a3:	c6 05 fc 12 23 f0 00 	movb   $0x0,0xf02312fc
f01043aa:	c6 05 fd 12 23 f0 8e 	movb   $0x8e,0xf02312fd
f01043b1:	c1 e8 10             	shr    $0x10,%eax
f01043b4:	66 a3 fe 12 23 f0    	mov    %ax,0xf02312fe

	SETGATE(idt[48], 0, GD_KT, &t_syscall, 3);
f01043ba:	b8 0e 4d 10 f0       	mov    $0xf0104d0e,%eax
f01043bf:	66 a3 e0 13 23 f0    	mov    %ax,0xf02313e0
f01043c5:	66 c7 05 e2 13 23 f0 	movw   $0x8,0xf02313e2
f01043cc:	08 00 
f01043ce:	c6 05 e4 13 23 f0 00 	movb   $0x0,0xf02313e4
f01043d5:	c6 05 e5 13 23 f0 ee 	movb   $0xee,0xf02313e5
f01043dc:	c1 e8 10             	shr    $0x10,%eax
f01043df:	66 a3 e6 13 23 f0    	mov    %ax,0xf02313e6

	SETGATE(idt[IRQ_OFFSET+0], 0, GD_KT, &t_irq0, 0);
f01043e5:	b8 1e 4d 10 f0       	mov    $0xf0104d1e,%eax
f01043ea:	66 a3 60 13 23 f0    	mov    %ax,0xf0231360
f01043f0:	66 c7 05 62 13 23 f0 	movw   $0x8,0xf0231362
f01043f7:	08 00 
f01043f9:	c6 05 64 13 23 f0 00 	movb   $0x0,0xf0231364
f0104400:	c6 05 65 13 23 f0 8e 	movb   $0x8e,0xf0231365
f0104407:	c1 e8 10             	shr    $0x10,%eax
f010440a:	66 a3 66 13 23 f0    	mov    %ax,0xf0231366
	SETGATE(idt[IRQ_OFFSET+1], 0, GD_KT, &t_irq1, 0);
f0104410:	b8 24 4d 10 f0       	mov    $0xf0104d24,%eax
f0104415:	66 a3 68 13 23 f0    	mov    %ax,0xf0231368
f010441b:	66 c7 05 6a 13 23 f0 	movw   $0x8,0xf023136a
f0104422:	08 00 
f0104424:	c6 05 6c 13 23 f0 00 	movb   $0x0,0xf023136c
f010442b:	c6 05 6d 13 23 f0 8e 	movb   $0x8e,0xf023136d
f0104432:	c1 e8 10             	shr    $0x10,%eax
f0104435:	66 a3 6e 13 23 f0    	mov    %ax,0xf023136e
	SETGATE(idt[IRQ_OFFSET+2], 0, GD_KT, &t_irq2, 0);
f010443b:	b8 2a 4d 10 f0       	mov    $0xf0104d2a,%eax
f0104440:	66 a3 70 13 23 f0    	mov    %ax,0xf0231370
f0104446:	66 c7 05 72 13 23 f0 	movw   $0x8,0xf0231372
f010444d:	08 00 
f010444f:	c6 05 74 13 23 f0 00 	movb   $0x0,0xf0231374
f0104456:	c6 05 75 13 23 f0 8e 	movb   $0x8e,0xf0231375
f010445d:	c1 e8 10             	shr    $0x10,%eax
f0104460:	66 a3 76 13 23 f0    	mov    %ax,0xf0231376
	SETGATE(idt[IRQ_OFFSET+3], 0, GD_KT, &t_irq3, 0);
f0104466:	b8 30 4d 10 f0       	mov    $0xf0104d30,%eax
f010446b:	66 a3 78 13 23 f0    	mov    %ax,0xf0231378
f0104471:	66 c7 05 7a 13 23 f0 	movw   $0x8,0xf023137a
f0104478:	08 00 
f010447a:	c6 05 7c 13 23 f0 00 	movb   $0x0,0xf023137c
f0104481:	c6 05 7d 13 23 f0 8e 	movb   $0x8e,0xf023137d
f0104488:	c1 e8 10             	shr    $0x10,%eax
f010448b:	66 a3 7e 13 23 f0    	mov    %ax,0xf023137e
	SETGATE(idt[IRQ_OFFSET+4], 0, GD_KT, &t_irq4, 0);
f0104491:	b8 36 4d 10 f0       	mov    $0xf0104d36,%eax
f0104496:	66 a3 80 13 23 f0    	mov    %ax,0xf0231380
f010449c:	66 c7 05 82 13 23 f0 	movw   $0x8,0xf0231382
f01044a3:	08 00 
f01044a5:	c6 05 84 13 23 f0 00 	movb   $0x0,0xf0231384
f01044ac:	c6 05 85 13 23 f0 8e 	movb   $0x8e,0xf0231385
f01044b3:	c1 e8 10             	shr    $0x10,%eax
f01044b6:	66 a3 86 13 23 f0    	mov    %ax,0xf0231386
	SETGATE(idt[IRQ_OFFSET+5], 0, GD_KT, &t_irq5, 0);
f01044bc:	b8 3c 4d 10 f0       	mov    $0xf0104d3c,%eax
f01044c1:	66 a3 88 13 23 f0    	mov    %ax,0xf0231388
f01044c7:	66 c7 05 8a 13 23 f0 	movw   $0x8,0xf023138a
f01044ce:	08 00 
f01044d0:	c6 05 8c 13 23 f0 00 	movb   $0x0,0xf023138c
f01044d7:	c6 05 8d 13 23 f0 8e 	movb   $0x8e,0xf023138d
f01044de:	c1 e8 10             	shr    $0x10,%eax
f01044e1:	66 a3 8e 13 23 f0    	mov    %ax,0xf023138e
	SETGATE(idt[IRQ_OFFSET+6], 0, GD_KT, &t_irq6, 0);
f01044e7:	b8 42 4d 10 f0       	mov    $0xf0104d42,%eax
f01044ec:	66 a3 90 13 23 f0    	mov    %ax,0xf0231390
f01044f2:	66 c7 05 92 13 23 f0 	movw   $0x8,0xf0231392
f01044f9:	08 00 
f01044fb:	c6 05 94 13 23 f0 00 	movb   $0x0,0xf0231394
f0104502:	c6 05 95 13 23 f0 8e 	movb   $0x8e,0xf0231395
f0104509:	c1 e8 10             	shr    $0x10,%eax
f010450c:	66 a3 96 13 23 f0    	mov    %ax,0xf0231396
	SETGATE(idt[IRQ_OFFSET+7], 0, GD_KT, &t_irq7, 0);
f0104512:	b8 48 4d 10 f0       	mov    $0xf0104d48,%eax
f0104517:	66 a3 98 13 23 f0    	mov    %ax,0xf0231398
f010451d:	66 c7 05 9a 13 23 f0 	movw   $0x8,0xf023139a
f0104524:	08 00 
f0104526:	c6 05 9c 13 23 f0 00 	movb   $0x0,0xf023139c
f010452d:	c6 05 9d 13 23 f0 8e 	movb   $0x8e,0xf023139d
f0104534:	c1 e8 10             	shr    $0x10,%eax
f0104537:	66 a3 9e 13 23 f0    	mov    %ax,0xf023139e
	SETGATE(idt[IRQ_OFFSET+8], 0, GD_KT, &t_irq8, 0);
f010453d:	b8 4e 4d 10 f0       	mov    $0xf0104d4e,%eax
f0104542:	66 a3 a0 13 23 f0    	mov    %ax,0xf02313a0
f0104548:	66 c7 05 a2 13 23 f0 	movw   $0x8,0xf02313a2
f010454f:	08 00 
f0104551:	c6 05 a4 13 23 f0 00 	movb   $0x0,0xf02313a4
f0104558:	c6 05 a5 13 23 f0 8e 	movb   $0x8e,0xf02313a5
f010455f:	c1 e8 10             	shr    $0x10,%eax
f0104562:	66 a3 a6 13 23 f0    	mov    %ax,0xf02313a6
	SETGATE(idt[IRQ_OFFSET+9], 0, GD_KT, &t_irq9, 0);
f0104568:	b8 54 4d 10 f0       	mov    $0xf0104d54,%eax
f010456d:	66 a3 a8 13 23 f0    	mov    %ax,0xf02313a8
f0104573:	66 c7 05 aa 13 23 f0 	movw   $0x8,0xf02313aa
f010457a:	08 00 
f010457c:	c6 05 ac 13 23 f0 00 	movb   $0x0,0xf02313ac
f0104583:	c6 05 ad 13 23 f0 8e 	movb   $0x8e,0xf02313ad
f010458a:	c1 e8 10             	shr    $0x10,%eax
f010458d:	66 a3 ae 13 23 f0    	mov    %ax,0xf02313ae
	SETGATE(idt[IRQ_OFFSET+10], 0, GD_KT, &t_irq10, 0);
f0104593:	b8 5a 4d 10 f0       	mov    $0xf0104d5a,%eax
f0104598:	66 a3 b0 13 23 f0    	mov    %ax,0xf02313b0
f010459e:	66 c7 05 b2 13 23 f0 	movw   $0x8,0xf02313b2
f01045a5:	08 00 
f01045a7:	c6 05 b4 13 23 f0 00 	movb   $0x0,0xf02313b4
f01045ae:	c6 05 b5 13 23 f0 8e 	movb   $0x8e,0xf02313b5
f01045b5:	c1 e8 10             	shr    $0x10,%eax
f01045b8:	66 a3 b6 13 23 f0    	mov    %ax,0xf02313b6
	SETGATE(idt[IRQ_OFFSET+11], 0, GD_KT, &t_irq11, 0);
f01045be:	b8 60 4d 10 f0       	mov    $0xf0104d60,%eax
f01045c3:	66 a3 b8 13 23 f0    	mov    %ax,0xf02313b8
f01045c9:	66 c7 05 ba 13 23 f0 	movw   $0x8,0xf02313ba
f01045d0:	08 00 
f01045d2:	c6 05 bc 13 23 f0 00 	movb   $0x0,0xf02313bc
f01045d9:	c6 05 bd 13 23 f0 8e 	movb   $0x8e,0xf02313bd
f01045e0:	c1 e8 10             	shr    $0x10,%eax
f01045e3:	66 a3 be 13 23 f0    	mov    %ax,0xf02313be
	SETGATE(idt[IRQ_OFFSET+12], 0, GD_KT, &t_irq12, 0);
f01045e9:	b8 66 4d 10 f0       	mov    $0xf0104d66,%eax
f01045ee:	66 a3 c0 13 23 f0    	mov    %ax,0xf02313c0
f01045f4:	66 c7 05 c2 13 23 f0 	movw   $0x8,0xf02313c2
f01045fb:	08 00 
f01045fd:	c6 05 c4 13 23 f0 00 	movb   $0x0,0xf02313c4
f0104604:	c6 05 c5 13 23 f0 8e 	movb   $0x8e,0xf02313c5
f010460b:	c1 e8 10             	shr    $0x10,%eax
f010460e:	66 a3 c6 13 23 f0    	mov    %ax,0xf02313c6
	SETGATE(idt[IRQ_OFFSET+13], 0, GD_KT, &t_irq13, 0);
f0104614:	b8 6c 4d 10 f0       	mov    $0xf0104d6c,%eax
f0104619:	66 a3 c8 13 23 f0    	mov    %ax,0xf02313c8
f010461f:	66 c7 05 ca 13 23 f0 	movw   $0x8,0xf02313ca
f0104626:	08 00 
f0104628:	c6 05 cc 13 23 f0 00 	movb   $0x0,0xf02313cc
f010462f:	c6 05 cd 13 23 f0 8e 	movb   $0x8e,0xf02313cd
f0104636:	c1 e8 10             	shr    $0x10,%eax
f0104639:	66 a3 ce 13 23 f0    	mov    %ax,0xf02313ce
	SETGATE(idt[IRQ_OFFSET+14], 0, GD_KT, &t_irq14, 0);
f010463f:	b8 72 4d 10 f0       	mov    $0xf0104d72,%eax
f0104644:	66 a3 d0 13 23 f0    	mov    %ax,0xf02313d0
f010464a:	66 c7 05 d2 13 23 f0 	movw   $0x8,0xf02313d2
f0104651:	08 00 
f0104653:	c6 05 d4 13 23 f0 00 	movb   $0x0,0xf02313d4
f010465a:	c6 05 d5 13 23 f0 8e 	movb   $0x8e,0xf02313d5
f0104661:	c1 e8 10             	shr    $0x10,%eax
f0104664:	66 a3 d6 13 23 f0    	mov    %ax,0xf02313d6
	SETGATE(idt[IRQ_OFFSET+15], 0, GD_KT, &t_irq15, 0);
f010466a:	b8 78 4d 10 f0       	mov    $0xf0104d78,%eax
f010466f:	66 a3 d8 13 23 f0    	mov    %ax,0xf02313d8
f0104675:	66 c7 05 da 13 23 f0 	movw   $0x8,0xf02313da
f010467c:	08 00 
f010467e:	c6 05 dc 13 23 f0 00 	movb   $0x0,0xf02313dc
f0104685:	c6 05 dd 13 23 f0 8e 	movb   $0x8e,0xf02313dd
f010468c:	c1 e8 10             	shr    $0x10,%eax
f010468f:	66 a3 de 13 23 f0    	mov    %ax,0xf02313de

	// Per-CPU setup 
	trap_init_percpu();
f0104695:	e8 c6 f8 ff ff       	call   f0103f60 <trap_init_percpu>
}
f010469a:	c9                   	leave  
f010469b:	c3                   	ret    

f010469c <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010469c:	55                   	push   %ebp
f010469d:	89 e5                	mov    %esp,%ebp
f010469f:	53                   	push   %ebx
f01046a0:	83 ec 14             	sub    $0x14,%esp
f01046a3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01046a6:	8b 03                	mov    (%ebx),%eax
f01046a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046ac:	c7 04 24 d3 81 10 f0 	movl   $0xf01081d3,(%esp)
f01046b3:	e8 7f f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01046b8:	8b 43 04             	mov    0x4(%ebx),%eax
f01046bb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046bf:	c7 04 24 e2 81 10 f0 	movl   $0xf01081e2,(%esp)
f01046c6:	e8 6c f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f01046cb:	8b 43 08             	mov    0x8(%ebx),%eax
f01046ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046d2:	c7 04 24 f1 81 10 f0 	movl   $0xf01081f1,(%esp)
f01046d9:	e8 59 f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f01046de:	8b 43 0c             	mov    0xc(%ebx),%eax
f01046e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046e5:	c7 04 24 00 82 10 f0 	movl   $0xf0108200,(%esp)
f01046ec:	e8 46 f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f01046f1:	8b 43 10             	mov    0x10(%ebx),%eax
f01046f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046f8:	c7 04 24 0f 82 10 f0 	movl   $0xf010820f,(%esp)
f01046ff:	e8 33 f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104704:	8b 43 14             	mov    0x14(%ebx),%eax
f0104707:	89 44 24 04          	mov    %eax,0x4(%esp)
f010470b:	c7 04 24 1e 82 10 f0 	movl   $0xf010821e,(%esp)
f0104712:	e8 20 f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104717:	8b 43 18             	mov    0x18(%ebx),%eax
f010471a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010471e:	c7 04 24 2d 82 10 f0 	movl   $0xf010822d,(%esp)
f0104725:	e8 0d f8 ff ff       	call   f0103f37 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010472a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010472d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104731:	c7 04 24 3c 82 10 f0 	movl   $0xf010823c,(%esp)
f0104738:	e8 fa f7 ff ff       	call   f0103f37 <cprintf>
}
f010473d:	83 c4 14             	add    $0x14,%esp
f0104740:	5b                   	pop    %ebx
f0104741:	5d                   	pop    %ebp
f0104742:	c3                   	ret    

f0104743 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0104743:	55                   	push   %ebp
f0104744:	89 e5                	mov    %esp,%ebp
f0104746:	56                   	push   %esi
f0104747:	53                   	push   %ebx
f0104748:	83 ec 10             	sub    $0x10,%esp
f010474b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010474e:	e8 26 21 00 00       	call   f0106879 <cpunum>
f0104753:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104757:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010475b:	c7 04 24 a0 82 10 f0 	movl   $0xf01082a0,(%esp)
f0104762:	e8 d0 f7 ff ff       	call   f0103f37 <cprintf>
	print_regs(&tf->tf_regs);
f0104767:	89 1c 24             	mov    %ebx,(%esp)
f010476a:	e8 2d ff ff ff       	call   f010469c <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f010476f:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0104773:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104777:	c7 04 24 be 82 10 f0 	movl   $0xf01082be,(%esp)
f010477e:	e8 b4 f7 ff ff       	call   f0103f37 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0104783:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0104787:	89 44 24 04          	mov    %eax,0x4(%esp)
f010478b:	c7 04 24 d1 82 10 f0 	movl   $0xf01082d1,(%esp)
f0104792:	e8 a0 f7 ff ff       	call   f0103f37 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104797:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010479a:	83 f8 13             	cmp    $0x13,%eax
f010479d:	77 09                	ja     f01047a8 <print_trapframe+0x65>
		return excnames[trapno];
f010479f:	8b 14 85 40 85 10 f0 	mov    -0xfef7ac0(,%eax,4),%edx
f01047a6:	eb 1f                	jmp    f01047c7 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01047a8:	83 f8 30             	cmp    $0x30,%eax
f01047ab:	74 15                	je     f01047c2 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01047ad:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f01047b0:	83 fa 0f             	cmp    $0xf,%edx
f01047b3:	ba 57 82 10 f0       	mov    $0xf0108257,%edx
f01047b8:	b9 6a 82 10 f0       	mov    $0xf010826a,%ecx
f01047bd:	0f 47 d1             	cmova  %ecx,%edx
f01047c0:	eb 05                	jmp    f01047c7 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f01047c2:	ba 4b 82 10 f0       	mov    $0xf010824b,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01047c7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01047cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047cf:	c7 04 24 e4 82 10 f0 	movl   $0xf01082e4,(%esp)
f01047d6:	e8 5c f7 ff ff       	call   f0103f37 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f01047db:	3b 1d 60 1a 23 f0    	cmp    0xf0231a60,%ebx
f01047e1:	75 19                	jne    f01047fc <print_trapframe+0xb9>
f01047e3:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01047e7:	75 13                	jne    f01047fc <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f01047e9:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f01047ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047f0:	c7 04 24 f6 82 10 f0 	movl   $0xf01082f6,(%esp)
f01047f7:	e8 3b f7 ff ff       	call   f0103f37 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f01047fc:	8b 43 2c             	mov    0x2c(%ebx),%eax
f01047ff:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104803:	c7 04 24 05 83 10 f0 	movl   $0xf0108305,(%esp)
f010480a:	e8 28 f7 ff ff       	call   f0103f37 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010480f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104813:	75 51                	jne    f0104866 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104815:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104818:	89 c2                	mov    %eax,%edx
f010481a:	83 e2 01             	and    $0x1,%edx
f010481d:	ba 79 82 10 f0       	mov    $0xf0108279,%edx
f0104822:	b9 84 82 10 f0       	mov    $0xf0108284,%ecx
f0104827:	0f 45 ca             	cmovne %edx,%ecx
f010482a:	89 c2                	mov    %eax,%edx
f010482c:	83 e2 02             	and    $0x2,%edx
f010482f:	ba 90 82 10 f0       	mov    $0xf0108290,%edx
f0104834:	be 96 82 10 f0       	mov    $0xf0108296,%esi
f0104839:	0f 44 d6             	cmove  %esi,%edx
f010483c:	83 e0 04             	and    $0x4,%eax
f010483f:	b8 9b 82 10 f0       	mov    $0xf010829b,%eax
f0104844:	be d0 83 10 f0       	mov    $0xf01083d0,%esi
f0104849:	0f 44 c6             	cmove  %esi,%eax
f010484c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104850:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104854:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104858:	c7 04 24 13 83 10 f0 	movl   $0xf0108313,(%esp)
f010485f:	e8 d3 f6 ff ff       	call   f0103f37 <cprintf>
f0104864:	eb 0c                	jmp    f0104872 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0104866:	c7 04 24 0d 81 10 f0 	movl   $0xf010810d,(%esp)
f010486d:	e8 c5 f6 ff ff       	call   f0103f37 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0104872:	8b 43 30             	mov    0x30(%ebx),%eax
f0104875:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104879:	c7 04 24 22 83 10 f0 	movl   $0xf0108322,(%esp)
f0104880:	e8 b2 f6 ff ff       	call   f0103f37 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0104885:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104889:	89 44 24 04          	mov    %eax,0x4(%esp)
f010488d:	c7 04 24 31 83 10 f0 	movl   $0xf0108331,(%esp)
f0104894:	e8 9e f6 ff ff       	call   f0103f37 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0104899:	8b 43 38             	mov    0x38(%ebx),%eax
f010489c:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048a0:	c7 04 24 44 83 10 f0 	movl   $0xf0108344,(%esp)
f01048a7:	e8 8b f6 ff ff       	call   f0103f37 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01048ac:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01048b0:	74 27                	je     f01048d9 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01048b2:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01048b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048b9:	c7 04 24 53 83 10 f0 	movl   $0xf0108353,(%esp)
f01048c0:	e8 72 f6 ff ff       	call   f0103f37 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f01048c5:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f01048c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048cd:	c7 04 24 62 83 10 f0 	movl   $0xf0108362,(%esp)
f01048d4:	e8 5e f6 ff ff       	call   f0103f37 <cprintf>
	}
}
f01048d9:	83 c4 10             	add    $0x10,%esp
f01048dc:	5b                   	pop    %ebx
f01048dd:	5e                   	pop    %esi
f01048de:	5d                   	pop    %ebp
f01048df:	c3                   	ret    

f01048e0 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f01048e0:	55                   	push   %ebp
f01048e1:	89 e5                	mov    %esp,%ebp
f01048e3:	57                   	push   %edi
f01048e4:	56                   	push   %esi
f01048e5:	53                   	push   %ebx
f01048e6:	83 ec 2c             	sub    $0x2c,%esp
f01048e9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01048ec:	0f 20 d0             	mov    %cr2,%eax
f01048ef:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	if(!curenv->env_pgfault_upcall){
f01048f2:	e8 82 1f 00 00       	call   f0106879 <cpunum>
f01048f7:	6b c0 74             	imul   $0x74,%eax,%eax
f01048fa:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104900:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f0104904:	75 4d                	jne    f0104953 <page_fault_handler+0x73>
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104906:	8b 73 30             	mov    0x30(%ebx),%esi
			curenv->env_id, fault_va, tf->tf_eip);
f0104909:	e8 6b 1f 00 00       	call   f0106879 <cpunum>

	// LAB 4: Your code here.

	if(!curenv->env_pgfault_upcall){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f010490e:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104912:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0104915:	89 4c 24 08          	mov    %ecx,0x8(%esp)
			curenv->env_id, fault_va, tf->tf_eip);
f0104919:	6b c0 74             	imul   $0x74,%eax,%eax

	// LAB 4: Your code here.

	if(!curenv->env_pgfault_upcall){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f010491c:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104922:	8b 40 48             	mov    0x48(%eax),%eax
f0104925:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104929:	c7 04 24 1c 85 10 f0 	movl   $0xf010851c,(%esp)
f0104930:	e8 02 f6 ff ff       	call   f0103f37 <cprintf>
			curenv->env_id, fault_va, tf->tf_eip);
		print_trapframe(tf);
f0104935:	89 1c 24             	mov    %ebx,(%esp)
f0104938:	e8 06 fe ff ff       	call   f0104743 <print_trapframe>
		env_destroy(curenv);	
f010493d:	e8 37 1f 00 00       	call   f0106879 <cpunum>
f0104942:	6b c0 74             	imul   $0x74,%eax,%eax
f0104945:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f010494b:	89 04 24             	mov    %eax,(%esp)
f010494e:	e8 f5 f2 ff ff       	call   f0103c48 <env_destroy>
	}

	uintptr_t orig_esp = tf->tf_esp;
f0104953:	8b 73 3c             	mov    0x3c(%ebx),%esi

	struct UTrapframe *utf;
	if(tf->tf_esp < UXSTACKTOP && tf->tf_esp >= UXSTACKTOP - PGSIZE){
f0104956:	8d 86 00 10 40 11    	lea    0x11401000(%esi),%eax
f010495c:	3d ff 0f 00 00       	cmp    $0xfff,%eax
f0104961:	77 08                	ja     f010496b <page_fault_handler+0x8b>
		tf->tf_esp -= 4;
f0104963:	8d 46 fc             	lea    -0x4(%esi),%eax
f0104966:	89 43 3c             	mov    %eax,0x3c(%ebx)
f0104969:	eb 07                	jmp    f0104972 <page_fault_handler+0x92>
	}
	else
		tf->tf_esp = UXSTACKTOP;
f010496b:	c7 43 3c 00 00 c0 ee 	movl   $0xeec00000,0x3c(%ebx)

	tf->tf_esp -= sizeof(struct UTrapframe);
f0104972:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104975:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104978:	8d 78 cc             	lea    -0x34(%eax),%edi
f010497b:	89 7b 3c             	mov    %edi,0x3c(%ebx)

	user_mem_assert(curenv, (void *)tf->tf_esp, UXSTACKTOP - tf->tf_esp, PTE_W | PTE_U);
f010497e:	e8 f6 1e 00 00       	call   f0106879 <cpunum>
f0104983:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010498a:	00 
f010498b:	ba 34 00 c0 ee       	mov    $0xeec00034,%edx
f0104990:	2b 55 e0             	sub    -0x20(%ebp),%edx
f0104993:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104997:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010499b:	6b c0 74             	imul   $0x74,%eax,%eax
f010499e:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01049a4:	89 04 24             	mov    %eax,(%esp)
f01049a7:	e8 a5 eb ff ff       	call   f0103551 <user_mem_assert>

	utf = (struct UTrapframe*)(tf->tf_esp);
f01049ac:	8b 43 3c             	mov    0x3c(%ebx),%eax
	utf->utf_fault_va = fault_va;
f01049af:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01049b2:	89 08                	mov    %ecx,(%eax)
	utf->utf_err = tf->tf_err;
f01049b4:	8b 53 2c             	mov    0x2c(%ebx),%edx
f01049b7:	89 50 04             	mov    %edx,0x4(%eax)
	utf->utf_regs = tf->tf_regs;
f01049ba:	8b 13                	mov    (%ebx),%edx
f01049bc:	89 50 08             	mov    %edx,0x8(%eax)
f01049bf:	8b 53 04             	mov    0x4(%ebx),%edx
f01049c2:	89 50 0c             	mov    %edx,0xc(%eax)
f01049c5:	8b 53 08             	mov    0x8(%ebx),%edx
f01049c8:	89 50 10             	mov    %edx,0x10(%eax)
f01049cb:	8b 53 0c             	mov    0xc(%ebx),%edx
f01049ce:	89 50 14             	mov    %edx,0x14(%eax)
f01049d1:	8b 53 10             	mov    0x10(%ebx),%edx
f01049d4:	89 50 18             	mov    %edx,0x18(%eax)
f01049d7:	8b 53 14             	mov    0x14(%ebx),%edx
f01049da:	89 50 1c             	mov    %edx,0x1c(%eax)
f01049dd:	8b 53 18             	mov    0x18(%ebx),%edx
f01049e0:	89 50 20             	mov    %edx,0x20(%eax)
f01049e3:	8b 53 1c             	mov    0x1c(%ebx),%edx
f01049e6:	89 50 24             	mov    %edx,0x24(%eax)
	utf->utf_esp = orig_esp;
f01049e9:	89 70 30             	mov    %esi,0x30(%eax)
	utf->utf_eip = tf->tf_eip;
f01049ec:	8b 53 30             	mov    0x30(%ebx),%edx
f01049ef:	89 50 28             	mov    %edx,0x28(%eax)
	utf->utf_eflags = tf->tf_eflags;
f01049f2:	8b 53 38             	mov    0x38(%ebx),%edx
f01049f5:	89 50 2c             	mov    %edx,0x2c(%eax)
	tf->tf_eip = (uintptr_t)curenv->env_pgfault_upcall;
f01049f8:	e8 7c 1e 00 00       	call   f0106879 <cpunum>
f01049fd:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a00:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104a06:	8b 40 64             	mov    0x64(%eax),%eax
f0104a09:	89 43 30             	mov    %eax,0x30(%ebx)

	env_run(curenv);
f0104a0c:	e8 68 1e 00 00       	call   f0106879 <cpunum>
f0104a11:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a14:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104a1a:	89 04 24             	mov    %eax,(%esp)
f0104a1d:	e8 c7 f2 ff ff       	call   f0103ce9 <env_run>

f0104a22 <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f0104a22:	55                   	push   %ebp
f0104a23:	89 e5                	mov    %esp,%ebp
f0104a25:	57                   	push   %edi
f0104a26:	56                   	push   %esi
f0104a27:	83 ec 20             	sub    $0x20,%esp
f0104a2a:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f0104a2d:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f0104a2e:	83 3d 80 1e 23 f0 00 	cmpl   $0x0,0xf0231e80
f0104a35:	74 01                	je     f0104a38 <trap+0x16>
		asm volatile("hlt");
f0104a37:	f4                   	hlt    

	// Re-acqurie the big kernel lock if we were halted in
	// sched_yield()
	if (xchg(&thiscpu->cpu_status, CPU_STARTED) == CPU_HALTED)
f0104a38:	e8 3c 1e 00 00       	call   f0106879 <cpunum>
f0104a3d:	6b d0 74             	imul   $0x74,%eax,%edx
f0104a40:	81 c2 20 20 23 f0    	add    $0xf0232020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0104a46:	b8 01 00 00 00       	mov    $0x1,%eax
f0104a4b:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f0104a4f:	83 f8 02             	cmp    $0x2,%eax
f0104a52:	75 0c                	jne    f0104a60 <trap+0x3e>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f0104a54:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f0104a5b:	e8 97 20 00 00       	call   f0106af7 <spin_lock>

static __inline uint32_t
read_eflags(void)
{
	uint32_t eflags;
	__asm __volatile("pushfl; popl %0" : "=r" (eflags));
f0104a60:	9c                   	pushf  
f0104a61:	58                   	pop    %eax
		lock_kernel();
	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f0104a62:	f6 c4 02             	test   $0x2,%ah
f0104a65:	74 24                	je     f0104a8b <trap+0x69>
f0104a67:	c7 44 24 0c 75 83 10 	movl   $0xf0108375,0xc(%esp)
f0104a6e:	f0 
f0104a6f:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0104a76:	f0 
f0104a77:	c7 44 24 04 43 01 00 	movl   $0x143,0x4(%esp)
f0104a7e:	00 
f0104a7f:	c7 04 24 8e 83 10 f0 	movl   $0xf010838e,(%esp)
f0104a86:	e8 b5 b5 ff ff       	call   f0100040 <_panic>

	if ((tf->tf_cs & 3) == 3) {
f0104a8b:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f0104a8f:	83 e0 03             	and    $0x3,%eax
f0104a92:	66 83 f8 03          	cmp    $0x3,%ax
f0104a96:	0f 85 a7 00 00 00    	jne    f0104b43 <trap+0x121>
f0104a9c:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f0104aa3:	e8 4f 20 00 00       	call   f0106af7 <spin_lock>
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.

		lock_kernel();
		assert(curenv);
f0104aa8:	e8 cc 1d 00 00       	call   f0106879 <cpunum>
f0104aad:	6b c0 74             	imul   $0x74,%eax,%eax
f0104ab0:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f0104ab7:	75 24                	jne    f0104add <trap+0xbb>
f0104ab9:	c7 44 24 0c 9a 83 10 	movl   $0xf010839a,0xc(%esp)
f0104ac0:	f0 
f0104ac1:	c7 44 24 08 07 7e 10 	movl   $0xf0107e07,0x8(%esp)
f0104ac8:	f0 
f0104ac9:	c7 44 24 04 4c 01 00 	movl   $0x14c,0x4(%esp)
f0104ad0:	00 
f0104ad1:	c7 04 24 8e 83 10 f0 	movl   $0xf010838e,(%esp)
f0104ad8:	e8 63 b5 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0104add:	e8 97 1d 00 00       	call   f0106879 <cpunum>
f0104ae2:	6b c0 74             	imul   $0x74,%eax,%eax
f0104ae5:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104aeb:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104aef:	75 2d                	jne    f0104b1e <trap+0xfc>
			env_free(curenv);
f0104af1:	e8 83 1d 00 00       	call   f0106879 <cpunum>
f0104af6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104af9:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104aff:	89 04 24             	mov    %eax,(%esp)
f0104b02:	e8 3c ef ff ff       	call   f0103a43 <env_free>
			curenv = NULL;
f0104b07:	e8 6d 1d 00 00       	call   f0106879 <cpunum>
f0104b0c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b0f:	c7 80 28 20 23 f0 00 	movl   $0x0,-0xfdcdfd8(%eax)
f0104b16:	00 00 00 
			sched_yield();
f0104b19:	e8 58 03 00 00       	call   f0104e76 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f0104b1e:	e8 56 1d 00 00       	call   f0106879 <cpunum>
f0104b23:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b26:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104b2c:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104b31:	89 c7                	mov    %eax,%edi
f0104b33:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104b35:	e8 3f 1d 00 00       	call   f0106879 <cpunum>
f0104b3a:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b3d:	8b b0 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%esi
	// else
	// 	panic("Page fault in kernel!!");

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104b43:	89 35 60 1a 23 f0    	mov    %esi,0xf0231a60
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f0104b49:	8b 46 28             	mov    0x28(%esi),%eax
f0104b4c:	83 f8 27             	cmp    $0x27,%eax
f0104b4f:	75 19                	jne    f0104b6a <trap+0x148>
		cprintf("Spurious interrupt on irq 7\n");
f0104b51:	c7 04 24 a1 83 10 f0 	movl   $0xf01083a1,(%esp)
f0104b58:	e8 da f3 ff ff       	call   f0103f37 <cprintf>
		print_trapframe(tf);
f0104b5d:	89 34 24             	mov    %esi,(%esp)
f0104b60:	e8 de fb ff ff       	call   f0104743 <print_trapframe>
f0104b65:	e9 b5 00 00 00       	jmp    f0104c1f <trap+0x1fd>

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	switch(tf->tf_trapno)
f0104b6a:	83 f8 0e             	cmp    $0xe,%eax
f0104b6d:	74 2b                	je     f0104b9a <trap+0x178>
f0104b6f:	83 f8 0e             	cmp    $0xe,%eax
f0104b72:	77 07                	ja     f0104b7b <trap+0x159>
f0104b74:	83 f8 03             	cmp    $0x3,%eax
f0104b77:	74 10                	je     f0104b89 <trap+0x167>
f0104b79:	eb 63                	jmp    f0104bde <trap+0x1bc>
f0104b7b:	83 f8 20             	cmp    $0x20,%eax
f0104b7e:	66 90                	xchg   %ax,%ax
f0104b80:	74 52                	je     f0104bd4 <trap+0x1b2>
f0104b82:	83 f8 30             	cmp    $0x30,%eax
f0104b85:	74 1b                	je     f0104ba2 <trap+0x180>
f0104b87:	eb 55                	jmp    f0104bde <trap+0x1bc>
	{
		case 3:
		monitor(tf);
f0104b89:	89 34 24             	mov    %esi,(%esp)
f0104b8c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104b90:	e8 3d be ff ff       	call   f01009d2 <monitor>
f0104b95:	e9 85 00 00 00       	jmp    f0104c1f <trap+0x1fd>
		return;
		case 14:
		page_fault_handler(tf);
f0104b9a:	89 34 24             	mov    %esi,(%esp)
f0104b9d:	e8 3e fd ff ff       	call   f01048e0 <page_fault_handler>
		return;
		case 48:
		tf->tf_regs.reg_eax = syscall(tf->tf_regs.reg_eax, tf->tf_regs.reg_edx, tf->tf_regs.reg_ecx, tf->tf_regs.reg_ebx, tf->tf_regs.reg_edi, tf->tf_regs.reg_esi);
f0104ba2:	8b 46 04             	mov    0x4(%esi),%eax
f0104ba5:	89 44 24 14          	mov    %eax,0x14(%esp)
f0104ba9:	8b 06                	mov    (%esi),%eax
f0104bab:	89 44 24 10          	mov    %eax,0x10(%esp)
f0104baf:	8b 46 10             	mov    0x10(%esi),%eax
f0104bb2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104bb6:	8b 46 18             	mov    0x18(%esi),%eax
f0104bb9:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104bbd:	8b 46 14             	mov    0x14(%esi),%eax
f0104bc0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bc4:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104bc7:	89 04 24             	mov    %eax,(%esp)
f0104bca:	e8 a1 03 00 00       	call   f0104f70 <syscall>
f0104bcf:	89 46 1c             	mov    %eax,0x1c(%esi)
f0104bd2:	eb 4b                	jmp    f0104c1f <trap+0x1fd>
		return;
		case IRQ_OFFSET+IRQ_TIMER:
		lapic_eoi();
f0104bd4:	e8 ed 1d 00 00       	call   f01069c6 <lapic_eoi>
		sched_yield();
f0104bd9:	e8 98 02 00 00       	call   f0104e76 <sched_yield>
		return;
	}

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f0104bde:	89 34 24             	mov    %esi,(%esp)
f0104be1:	e8 5d fb ff ff       	call   f0104743 <print_trapframe>
	if (tf->tf_cs == GD_KT)
f0104be6:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104beb:	75 1c                	jne    f0104c09 <trap+0x1e7>
		panic("unhandled trap in kernel");
f0104bed:	c7 44 24 08 be 83 10 	movl   $0xf01083be,0x8(%esp)
f0104bf4:	f0 
f0104bf5:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
f0104bfc:	00 
f0104bfd:	c7 04 24 8e 83 10 f0 	movl   $0xf010838e,(%esp)
f0104c04:	e8 37 b4 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104c09:	e8 6b 1c 00 00       	call   f0106879 <cpunum>
f0104c0e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c11:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104c17:	89 04 24             	mov    %eax,(%esp)
f0104c1a:	e8 29 f0 ff ff       	call   f0103c48 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104c1f:	e8 55 1c 00 00       	call   f0106879 <cpunum>
f0104c24:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c27:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f0104c2e:	74 2a                	je     f0104c5a <trap+0x238>
f0104c30:	e8 44 1c 00 00       	call   f0106879 <cpunum>
f0104c35:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c38:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104c3e:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104c42:	75 16                	jne    f0104c5a <trap+0x238>
		env_run(curenv);
f0104c44:	e8 30 1c 00 00       	call   f0106879 <cpunum>
f0104c49:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c4c:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104c52:	89 04 24             	mov    %eax,(%esp)
f0104c55:	e8 8f f0 ff ff       	call   f0103ce9 <env_run>
	else
		sched_yield();
f0104c5a:	e8 17 02 00 00       	call   f0104e76 <sched_yield>
f0104c5f:	90                   	nop

f0104c60 <t_divide>:

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */

TRAPHANDLER_NOEC(t_divide, 0);
f0104c60:	6a 00                	push   $0x0
f0104c62:	6a 00                	push   $0x0
f0104c64:	e9 15 01 00 00       	jmp    f0104d7e <_alltraps>
f0104c69:	90                   	nop

f0104c6a <t_debug>:
TRAPHANDLER_NOEC(t_debug, 1);
f0104c6a:	6a 00                	push   $0x0
f0104c6c:	6a 01                	push   $0x1
f0104c6e:	e9 0b 01 00 00       	jmp    f0104d7e <_alltraps>
f0104c73:	90                   	nop

f0104c74 <t_nmi>:
TRAPHANDLER_NOEC(t_nmi, 2);
f0104c74:	6a 00                	push   $0x0
f0104c76:	6a 02                	push   $0x2
f0104c78:	e9 01 01 00 00       	jmp    f0104d7e <_alltraps>
f0104c7d:	90                   	nop

f0104c7e <t_brkpt>:
TRAPHANDLER_NOEC(t_brkpt, 3);
f0104c7e:	6a 00                	push   $0x0
f0104c80:	6a 03                	push   $0x3
f0104c82:	e9 f7 00 00 00       	jmp    f0104d7e <_alltraps>
f0104c87:	90                   	nop

f0104c88 <t_oflow>:
TRAPHANDLER_NOEC(t_oflow, 4);
f0104c88:	6a 00                	push   $0x0
f0104c8a:	6a 04                	push   $0x4
f0104c8c:	e9 ed 00 00 00       	jmp    f0104d7e <_alltraps>
f0104c91:	90                   	nop

f0104c92 <t_bound>:
TRAPHANDLER_NOEC(t_bound, 5);
f0104c92:	6a 00                	push   $0x0
f0104c94:	6a 05                	push   $0x5
f0104c96:	e9 e3 00 00 00       	jmp    f0104d7e <_alltraps>
f0104c9b:	90                   	nop

f0104c9c <t_illop>:
TRAPHANDLER_NOEC(t_illop, 6);
f0104c9c:	6a 00                	push   $0x0
f0104c9e:	6a 06                	push   $0x6
f0104ca0:	e9 d9 00 00 00       	jmp    f0104d7e <_alltraps>
f0104ca5:	90                   	nop

f0104ca6 <t_device>:
TRAPHANDLER_NOEC(t_device, 7);
f0104ca6:	6a 00                	push   $0x0
f0104ca8:	6a 07                	push   $0x7
f0104caa:	e9 cf 00 00 00       	jmp    f0104d7e <_alltraps>
f0104caf:	90                   	nop

f0104cb0 <t_dblflt>:

TRAPHANDLER(t_dblflt, 8);
f0104cb0:	6a 08                	push   $0x8
f0104cb2:	e9 c7 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cb7:	90                   	nop

f0104cb8 <t_coproc>:

TRAPHANDLER_NOEC(t_coproc, 9);  /*reserved*/
f0104cb8:	6a 00                	push   $0x0
f0104cba:	6a 09                	push   $0x9
f0104cbc:	e9 bd 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cc1:	90                   	nop

f0104cc2 <t_tss>:

TRAPHANDLER(t_tss, 10);
f0104cc2:	6a 0a                	push   $0xa
f0104cc4:	e9 b5 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cc9:	90                   	nop

f0104cca <t_segnp>:
TRAPHANDLER(t_segnp, 11);
f0104cca:	6a 0b                	push   $0xb
f0104ccc:	e9 ad 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cd1:	90                   	nop

f0104cd2 <t_stack>:
TRAPHANDLER(t_stack, 12);
f0104cd2:	6a 0c                	push   $0xc
f0104cd4:	e9 a5 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cd9:	90                   	nop

f0104cda <t_gpflt>:
TRAPHANDLER(t_gpflt, 13);
f0104cda:	6a 0d                	push   $0xd
f0104cdc:	e9 9d 00 00 00       	jmp    f0104d7e <_alltraps>
f0104ce1:	90                   	nop

f0104ce2 <t_pgflt>:
TRAPHANDLER(t_pgflt, 14);
f0104ce2:	6a 0e                	push   $0xe
f0104ce4:	e9 95 00 00 00       	jmp    f0104d7e <_alltraps>
f0104ce9:	90                   	nop

f0104cea <t_res>:

TRAPHANDLER_NOEC(t_res, 15);   /*reserved*/
f0104cea:	6a 00                	push   $0x0
f0104cec:	6a 0f                	push   $0xf
f0104cee:	e9 8b 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cf3:	90                   	nop

f0104cf4 <t_fperr>:

TRAPHANDLER_NOEC(t_fperr, 16);
f0104cf4:	6a 00                	push   $0x0
f0104cf6:	6a 10                	push   $0x10
f0104cf8:	e9 81 00 00 00       	jmp    f0104d7e <_alltraps>
f0104cfd:	90                   	nop

f0104cfe <t_align>:

TRAPHANDLER(t_align, 17);
f0104cfe:	6a 11                	push   $0x11
f0104d00:	eb 7c                	jmp    f0104d7e <_alltraps>

f0104d02 <t_mchk>:

TRAPHANDLER_NOEC(t_mchk, 18);
f0104d02:	6a 00                	push   $0x0
f0104d04:	6a 12                	push   $0x12
f0104d06:	eb 76                	jmp    f0104d7e <_alltraps>

f0104d08 <t_simderr>:
TRAPHANDLER_NOEC(t_simderr, 19);
f0104d08:	6a 00                	push   $0x0
f0104d0a:	6a 13                	push   $0x13
f0104d0c:	eb 70                	jmp    f0104d7e <_alltraps>

f0104d0e <t_syscall>:

TRAPHANDLER_NOEC(t_syscall, 48);
f0104d0e:	6a 00                	push   $0x0
f0104d10:	6a 30                	push   $0x30
f0104d12:	eb 6a                	jmp    f0104d7e <_alltraps>

f0104d14 <t_default>:
TRAPHANDLER_NOEC(t_default, 500);
f0104d14:	6a 00                	push   $0x0
f0104d16:	68 f4 01 00 00       	push   $0x1f4
f0104d1b:	eb 61                	jmp    f0104d7e <_alltraps>
f0104d1d:	90                   	nop

f0104d1e <t_irq0>:

TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
f0104d1e:	6a 00                	push   $0x0
f0104d20:	6a 20                	push   $0x20
f0104d22:	eb 5a                	jmp    f0104d7e <_alltraps>

f0104d24 <t_irq1>:
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
f0104d24:	6a 00                	push   $0x0
f0104d26:	6a 21                	push   $0x21
f0104d28:	eb 54                	jmp    f0104d7e <_alltraps>

f0104d2a <t_irq2>:
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
f0104d2a:	6a 00                	push   $0x0
f0104d2c:	6a 22                	push   $0x22
f0104d2e:	eb 4e                	jmp    f0104d7e <_alltraps>

f0104d30 <t_irq3>:
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
f0104d30:	6a 00                	push   $0x0
f0104d32:	6a 23                	push   $0x23
f0104d34:	eb 48                	jmp    f0104d7e <_alltraps>

f0104d36 <t_irq4>:
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
f0104d36:	6a 00                	push   $0x0
f0104d38:	6a 24                	push   $0x24
f0104d3a:	eb 42                	jmp    f0104d7e <_alltraps>

f0104d3c <t_irq5>:
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
f0104d3c:	6a 00                	push   $0x0
f0104d3e:	6a 25                	push   $0x25
f0104d40:	eb 3c                	jmp    f0104d7e <_alltraps>

f0104d42 <t_irq6>:
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
f0104d42:	6a 00                	push   $0x0
f0104d44:	6a 26                	push   $0x26
f0104d46:	eb 36                	jmp    f0104d7e <_alltraps>

f0104d48 <t_irq7>:
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
f0104d48:	6a 00                	push   $0x0
f0104d4a:	6a 27                	push   $0x27
f0104d4c:	eb 30                	jmp    f0104d7e <_alltraps>

f0104d4e <t_irq8>:
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
f0104d4e:	6a 00                	push   $0x0
f0104d50:	6a 28                	push   $0x28
f0104d52:	eb 2a                	jmp    f0104d7e <_alltraps>

f0104d54 <t_irq9>:
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
f0104d54:	6a 00                	push   $0x0
f0104d56:	6a 29                	push   $0x29
f0104d58:	eb 24                	jmp    f0104d7e <_alltraps>

f0104d5a <t_irq10>:
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
f0104d5a:	6a 00                	push   $0x0
f0104d5c:	6a 2a                	push   $0x2a
f0104d5e:	eb 1e                	jmp    f0104d7e <_alltraps>

f0104d60 <t_irq11>:
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
f0104d60:	6a 00                	push   $0x0
f0104d62:	6a 2b                	push   $0x2b
f0104d64:	eb 18                	jmp    f0104d7e <_alltraps>

f0104d66 <t_irq12>:
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
f0104d66:	6a 00                	push   $0x0
f0104d68:	6a 2c                	push   $0x2c
f0104d6a:	eb 12                	jmp    f0104d7e <_alltraps>

f0104d6c <t_irq13>:
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
f0104d6c:	6a 00                	push   $0x0
f0104d6e:	6a 2d                	push   $0x2d
f0104d70:	eb 0c                	jmp    f0104d7e <_alltraps>

f0104d72 <t_irq14>:
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
f0104d72:	6a 00                	push   $0x0
f0104d74:	6a 2e                	push   $0x2e
f0104d76:	eb 06                	jmp    f0104d7e <_alltraps>

f0104d78 <t_irq15>:
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
f0104d78:	6a 00                	push   $0x0
f0104d7a:	6a 2f                	push   $0x2f
f0104d7c:	eb 00                	jmp    f0104d7e <_alltraps>

f0104d7e <_alltraps>:
 * Lab 3: Your code here for _alltraps
 */

_alltraps:

 pushw $0x0;
f0104d7e:	66 6a 00             	pushw  $0x0
 pushw %ds;
f0104d81:	66 1e                	pushw  %ds
 pushw $0x0;
f0104d83:	66 6a 00             	pushw  $0x0
 pushw %es;
f0104d86:	66 06                	pushw  %es
 pushal;
f0104d88:	60                   	pusha  
 movl $GD_KD, %ax;
f0104d89:	b8 10 00 00 00       	mov    $0x10,%eax
 movl %ax, %ds ;
f0104d8e:	8e d8                	mov    %eax,%ds
 movl %ax, %es ;
f0104d90:	8e c0                	mov    %eax,%es
 pushl %esp;
f0104d92:	54                   	push   %esp
 call trap;
f0104d93:	e8 8a fc ff ff       	call   f0104a22 <trap>
f0104d98:	66 90                	xchg   %ax,%ax
f0104d9a:	66 90                	xchg   %ax,%ax
f0104d9c:	66 90                	xchg   %ax,%ax
f0104d9e:	66 90                	xchg   %ax,%ax

f0104da0 <sched_halt>:
// Halt this CPU when there is nothing to do. Wait until the
// timer interrupt wakes it up. This function never returns.
//
void
sched_halt(void)
{
f0104da0:	55                   	push   %ebp
f0104da1:	89 e5                	mov    %esp,%ebp
f0104da3:	83 ec 18             	sub    $0x18,%esp
f0104da6:	8b 15 48 12 23 f0    	mov    0xf0231248,%edx
	int i;

	// For debugging and testing purposes, if there are no runnable
	// environments in the system, then drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104dac:	b8 00 00 00 00       	mov    $0x0,%eax
		if ((envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING ||
f0104db1:	8b 4a 54             	mov    0x54(%edx),%ecx
f0104db4:	83 e9 01             	sub    $0x1,%ecx
	int i;

	// For debugging and testing purposes, if there are no runnable
	// environments in the system, then drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if ((envs[i].env_status == ENV_RUNNABLE ||
f0104db7:	83 f9 02             	cmp    $0x2,%ecx
f0104dba:	76 0f                	jbe    f0104dcb <sched_halt+0x2b>
{
	int i;

	// For debugging and testing purposes, if there are no runnable
	// environments in the system, then drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104dbc:	83 c0 01             	add    $0x1,%eax
f0104dbf:	83 c2 7c             	add    $0x7c,%edx
f0104dc2:	3d 00 04 00 00       	cmp    $0x400,%eax
f0104dc7:	75 e8                	jne    f0104db1 <sched_halt+0x11>
f0104dc9:	eb 07                	jmp    f0104dd2 <sched_halt+0x32>
		if ((envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING ||
		     envs[i].env_status == ENV_DYING))
			break;
	}
	if (i == NENV) {
f0104dcb:	3d 00 04 00 00       	cmp    $0x400,%eax
f0104dd0:	75 1a                	jne    f0104dec <sched_halt+0x4c>
		cprintf("No runnable environments in the system!\n");
f0104dd2:	c7 04 24 90 85 10 f0 	movl   $0xf0108590,(%esp)
f0104dd9:	e8 59 f1 ff ff       	call   f0103f37 <cprintf>
		while (1)
			monitor(NULL);
f0104dde:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104de5:	e8 e8 bb ff ff       	call   f01009d2 <monitor>
f0104dea:	eb f2                	jmp    f0104dde <sched_halt+0x3e>
	}

	// Mark that no environment is running on this CPU
	curenv = NULL;
f0104dec:	e8 88 1a 00 00       	call   f0106879 <cpunum>
f0104df1:	6b c0 74             	imul   $0x74,%eax,%eax
f0104df4:	c7 80 28 20 23 f0 00 	movl   $0x0,-0xfdcdfd8(%eax)
f0104dfb:	00 00 00 
	lcr3(PADDR(kern_pgdir));
f0104dfe:	a1 8c 1e 23 f0       	mov    0xf0231e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0104e03:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0104e08:	77 20                	ja     f0104e2a <sched_halt+0x8a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0104e0a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104e0e:	c7 44 24 08 a8 6f 10 	movl   $0xf0106fa8,0x8(%esp)
f0104e15:	f0 
f0104e16:	c7 44 24 04 50 00 00 	movl   $0x50,0x4(%esp)
f0104e1d:	00 
f0104e1e:	c7 04 24 b9 85 10 f0 	movl   $0xf01085b9,(%esp)
f0104e25:	e8 16 b2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0104e2a:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0104e2f:	0f 22 d8             	mov    %eax,%cr3

	// Mark that this CPU is in the HALT state, so that when
	// timer interupts come in, we know we should re-acquire the
	// big kernel lock
	xchg(&thiscpu->cpu_status, CPU_HALTED);
f0104e32:	e8 42 1a 00 00       	call   f0106879 <cpunum>
f0104e37:	6b d0 74             	imul   $0x74,%eax,%edx
f0104e3a:	81 c2 20 20 23 f0    	add    $0xf0232020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0104e40:	b8 02 00 00 00       	mov    $0x2,%eax
f0104e45:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0104e49:	c7 04 24 c0 13 12 f0 	movl   $0xf01213c0,(%esp)
f0104e50:	e8 4e 1d 00 00       	call   f0106ba3 <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0104e55:	f3 90                	pause  
		"pushl $0\n"
		"sti\n"
		"1:\n"
		"hlt\n"
		"jmp 1b\n"
	: : "a" (thiscpu->cpu_ts.ts_esp0));
f0104e57:	e8 1d 1a 00 00       	call   f0106879 <cpunum>
f0104e5c:	6b c0 74             	imul   $0x74,%eax,%eax

	// Release the big kernel lock as if we were "leaving" the kernel
	unlock_kernel();

	// Reset stack pointer, enable interrupts and then halt.
	asm volatile (
f0104e5f:	8b 80 30 20 23 f0    	mov    -0xfdcdfd0(%eax),%eax
f0104e65:	bd 00 00 00 00       	mov    $0x0,%ebp
f0104e6a:	89 c4                	mov    %eax,%esp
f0104e6c:	6a 00                	push   $0x0
f0104e6e:	6a 00                	push   $0x0
f0104e70:	fb                   	sti    
f0104e71:	f4                   	hlt    
f0104e72:	eb fd                	jmp    f0104e71 <sched_halt+0xd1>
		"sti\n"
		"1:\n"
		"hlt\n"
		"jmp 1b\n"
	: : "a" (thiscpu->cpu_ts.ts_esp0));
}
f0104e74:	c9                   	leave  
f0104e75:	c3                   	ret    

f0104e76 <sched_yield>:
void sched_halt(void);

// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104e76:	55                   	push   %ebp
f0104e77:	89 e5                	mov    %esp,%ebp
f0104e79:	57                   	push   %edi
f0104e7a:	56                   	push   %esi
f0104e7b:	53                   	push   %ebx
f0104e7c:	83 ec 1c             	sub    $0x1c,%esp
	// no runnable environments, simply drop through to the code
	// below to halt the cpu.

	// LAB 4: Your code here.
	int i = 0, ct = 0;
	if(thiscpu->cpu_env)
f0104e7f:	e8 f5 19 00 00       	call   f0106879 <cpunum>
f0104e84:	6b c0 74             	imul   $0x74,%eax,%eax
	// another CPU (env_status == ENV_RUNNING). If there are
	// no runnable environments, simply drop through to the code
	// below to halt the cpu.

	// LAB 4: Your code here.
	int i = 0, ct = 0;
f0104e87:	bb 00 00 00 00       	mov    $0x0,%ebx
	if(thiscpu->cpu_env)
f0104e8c:	83 b8 28 20 23 f0 00 	cmpl   $0x0,-0xfdcdfd8(%eax)
f0104e93:	0f 84 b9 00 00 00    	je     f0104f52 <sched_yield+0xdc>
		i = ((thiscpu->cpu_env - envs) + 1)%NENV;
f0104e99:	e8 db 19 00 00       	call   f0106879 <cpunum>
f0104e9e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104ea1:	8b 90 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%edx
f0104ea7:	2b 15 48 12 23 f0    	sub    0xf0231248,%edx
f0104ead:	c1 fa 02             	sar    $0x2,%edx
f0104eb0:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f0104eb6:	83 c2 01             	add    $0x1,%edx
f0104eb9:	89 d0                	mov    %edx,%eax
f0104ebb:	c1 f8 1f             	sar    $0x1f,%eax
f0104ebe:	c1 e8 16             	shr    $0x16,%eax
f0104ec1:	8d 1c 02             	lea    (%edx,%eax,1),%ebx
f0104ec4:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0104eca:	29 c3                	sub    %eax,%ebx
f0104ecc:	e9 81 00 00 00       	jmp    f0104f52 <sched_yield+0xdc>

	while(ct<NENV){
		if(i==thiscpu->cpu_env - envs){
f0104ed1:	e8 a3 19 00 00       	call   f0106879 <cpunum>
f0104ed6:	8b 15 48 12 23 f0    	mov    0xf0231248,%edx
f0104edc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104edf:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104ee5:	29 d0                	sub    %edx,%eax
f0104ee7:	c1 f8 02             	sar    $0x2,%eax
f0104eea:	69 c0 df 7b ef bd    	imul   $0xbdef7bdf,%eax,%eax
f0104ef0:	89 c7                	mov    %eax,%edi
f0104ef2:	39 d8                	cmp    %ebx,%eax
f0104ef4:	75 25                	jne    f0104f1b <sched_yield+0xa5>
			if(thiscpu->cpu_env->env_status == ENV_RUNNING)
f0104ef6:	e8 7e 19 00 00       	call   f0106879 <cpunum>
f0104efb:	6b c0 74             	imul   $0x74,%eax,%eax
f0104efe:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104f04:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104f08:	75 40                	jne    f0104f4a <sched_yield+0xd4>
				env_run(&envs[i]);
f0104f0a:	6b c7 7c             	imul   $0x7c,%edi,%eax
f0104f0d:	03 05 48 12 23 f0    	add    0xf0231248,%eax
f0104f13:	89 04 24             	mov    %eax,(%esp)
f0104f16:	e8 ce ed ff ff       	call   f0103ce9 <env_run>
			else
				break;
		}
		if(envs[i].env_status != ENV_RUNNABLE){
f0104f1b:	6b c3 7c             	imul   $0x7c,%ebx,%eax
f0104f1e:	01 c2                	add    %eax,%edx
f0104f20:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0104f24:	74 1c                	je     f0104f42 <sched_yield+0xcc>
			i = (i+1)%NENV;
f0104f26:	83 c3 01             	add    $0x1,%ebx
f0104f29:	89 d8                	mov    %ebx,%eax
f0104f2b:	c1 f8 1f             	sar    $0x1f,%eax
f0104f2e:	c1 e8 16             	shr    $0x16,%eax
f0104f31:	01 c3                	add    %eax,%ebx
f0104f33:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0104f39:	29 c3                	sub    %eax,%ebx
	// LAB 4: Your code here.
	int i = 0, ct = 0;
	if(thiscpu->cpu_env)
		i = ((thiscpu->cpu_env - envs) + 1)%NENV;

	while(ct<NENV){
f0104f3b:	83 ee 01             	sub    $0x1,%esi
f0104f3e:	75 91                	jne    f0104ed1 <sched_yield+0x5b>
f0104f40:	eb 08                	jmp    f0104f4a <sched_yield+0xd4>
			i = (i+1)%NENV;
			ct++;
			continue;
		}
		// cprintf("envs[i]: %d\n", envs[i].env_id);
		env_run(&envs[i]);
f0104f42:	89 14 24             	mov    %edx,(%esp)
f0104f45:	e8 9f ed ff ff       	call   f0103ce9 <env_run>
	}

	// sched_halt never returns
	sched_halt();
f0104f4a:	e8 51 fe ff ff       	call   f0104da0 <sched_halt>
f0104f4f:	90                   	nop
f0104f50:	eb 0a                	jmp    f0104f5c <sched_yield+0xe6>
void sched_halt(void);

// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104f52:	be 00 04 00 00       	mov    $0x400,%esi
f0104f57:	e9 75 ff ff ff       	jmp    f0104ed1 <sched_yield+0x5b>
		env_run(&envs[i]);
	}

	// sched_halt never returns
	sched_halt();
}
f0104f5c:	83 c4 1c             	add    $0x1c,%esp
f0104f5f:	5b                   	pop    %ebx
f0104f60:	5e                   	pop    %esi
f0104f61:	5f                   	pop    %edi
f0104f62:	5d                   	pop    %ebp
f0104f63:	c3                   	ret    
f0104f64:	66 90                	xchg   %ax,%ax
f0104f66:	66 90                	xchg   %ax,%ax
f0104f68:	66 90                	xchg   %ax,%ax
f0104f6a:	66 90                	xchg   %ax,%ax
f0104f6c:	66 90                	xchg   %ax,%ax
f0104f6e:	66 90                	xchg   %ax,%ax

f0104f70 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104f70:	55                   	push   %ebp
f0104f71:	89 e5                	mov    %esp,%ebp
f0104f73:	57                   	push   %edi
f0104f74:	56                   	push   %esi
f0104f75:	53                   	push   %ebx
f0104f76:	83 ec 2c             	sub    $0x2c,%esp
f0104f79:	8b 45 08             	mov    0x8(%ebp),%eax
f0104f7c:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Return any appropriate return value.
	// LAB 3: Your code here.

	// panic("syscall not implemented");

	switch (syscallno) {
f0104f7f:	83 f8 0c             	cmp    $0xc,%eax
f0104f82:	0f 87 68 06 00 00    	ja     f01055f0 <syscall+0x680>
f0104f88:	ff 24 85 00 86 10 f0 	jmp    *-0xfef7a00(,%eax,4)
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.

	// LAB 3: Your code here.

	user_mem_assert(curenv, s, len, PTE_U);
f0104f8f:	e8 e5 18 00 00       	call   f0106879 <cpunum>
f0104f94:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0104f9b:	00 
f0104f9c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104fa0:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0104fa3:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104fa7:	6b c0 74             	imul   $0x74,%eax,%eax
f0104faa:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104fb0:	89 04 24             	mov    %eax,(%esp)
f0104fb3:	e8 99 e5 ff ff       	call   f0103551 <user_mem_assert>
	
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104fb8:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104fbb:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104fbf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104fc3:	c7 04 24 c6 85 10 f0 	movl   $0xf01085c6,(%esp)
f0104fca:	e8 68 ef ff ff       	call   f0103f37 <cprintf>

	switch (syscallno) {
		
		case SYS_cputs:
		sys_cputs((char*)a1, a2);
		return syscallno;
f0104fcf:	b8 00 00 00 00       	mov    $0x0,%eax
f0104fd4:	e9 23 06 00 00       	jmp    f01055fc <syscall+0x68c>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104fd9:	e8 97 b6 ff ff       	call   f0100675 <cons_getc>
		sys_cputs((char*)a1, a2);
		return syscallno;
		break;

		case SYS_cgetc:
		return sys_cgetc();
f0104fde:	66 90                	xchg   %ax,%ax
f0104fe0:	e9 17 06 00 00       	jmp    f01055fc <syscall+0x68c>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104fe5:	e8 8f 18 00 00       	call   f0106879 <cpunum>
f0104fea:	6b c0 74             	imul   $0x74,%eax,%eax
f0104fed:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0104ff3:	8b 40 48             	mov    0x48(%eax),%eax
		case SYS_cgetc:
		return sys_cgetc();
		break;

		case SYS_getenvid:
		return sys_getenvid();
f0104ff6:	e9 01 06 00 00       	jmp    f01055fc <syscall+0x68c>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104ffb:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0105002:	00 
f0105003:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0105006:	89 44 24 04          	mov    %eax,0x4(%esp)
f010500a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010500d:	89 04 24             	mov    %eax,(%esp)
f0105010:	e8 30 e6 ff ff       	call   f0103645 <envid2env>
		return r;
f0105015:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0105017:	85 c0                	test   %eax,%eax
f0105019:	78 6e                	js     f0105089 <syscall+0x119>
		return r;
	if (e == curenv)
f010501b:	e8 59 18 00 00       	call   f0106879 <cpunum>
f0105020:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0105023:	6b c0 74             	imul   $0x74,%eax,%eax
f0105026:	39 90 28 20 23 f0    	cmp    %edx,-0xfdcdfd8(%eax)
f010502c:	75 23                	jne    f0105051 <syscall+0xe1>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f010502e:	e8 46 18 00 00       	call   f0106879 <cpunum>
f0105033:	6b c0 74             	imul   $0x74,%eax,%eax
f0105036:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f010503c:	8b 40 48             	mov    0x48(%eax),%eax
f010503f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105043:	c7 04 24 cb 85 10 f0 	movl   $0xf01085cb,(%esp)
f010504a:	e8 e8 ee ff ff       	call   f0103f37 <cprintf>
f010504f:	eb 28                	jmp    f0105079 <syscall+0x109>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0105051:	8b 5a 48             	mov    0x48(%edx),%ebx
f0105054:	e8 20 18 00 00       	call   f0106879 <cpunum>
f0105059:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010505d:	6b c0 74             	imul   $0x74,%eax,%eax
f0105060:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0105066:	8b 40 48             	mov    0x48(%eax),%eax
f0105069:	89 44 24 04          	mov    %eax,0x4(%esp)
f010506d:	c7 04 24 e6 85 10 f0 	movl   $0xf01085e6,(%esp)
f0105074:	e8 be ee ff ff       	call   f0103f37 <cprintf>
	env_destroy(e);
f0105079:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010507c:	89 04 24             	mov    %eax,(%esp)
f010507f:	e8 c4 eb ff ff       	call   f0103c48 <env_destroy>
	return 0;
f0105084:	ba 00 00 00 00       	mov    $0x0,%edx
		case SYS_getenvid:
		return sys_getenvid();
		break;

		case SYS_env_destroy:
		return sys_env_destroy(a1);
f0105089:	89 d0                	mov    %edx,%eax
f010508b:	e9 6c 05 00 00       	jmp    f01055fc <syscall+0x68c>

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0105090:	e8 e1 fd ff ff       	call   f0104e76 <sched_yield>
	// from the current environment -- but tweaked so sys_exofork
	// will appear to return 0.

	// LAB 4: Your code here.
	struct Env* child;
	int ret = env_alloc(&child, thiscpu->cpu_env->env_id);
f0105095:	e8 df 17 00 00       	call   f0106879 <cpunum>
f010509a:	6b c0 74             	imul   $0x74,%eax,%eax
f010509d:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01050a3:	8b 40 48             	mov    0x48(%eax),%eax
f01050a6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050aa:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01050ad:	89 04 24             	mov    %eax,(%esp)
f01050b0:	e8 a0 e6 ff ff       	call   f0103755 <env_alloc>
	if(ret<0)
		return ret;
f01050b5:	89 c2                	mov    %eax,%edx
	// will appear to return 0.

	// LAB 4: Your code here.
	struct Env* child;
	int ret = env_alloc(&child, thiscpu->cpu_env->env_id);
	if(ret<0)
f01050b7:	85 c0                	test   %eax,%eax
f01050b9:	78 2e                	js     f01050e9 <syscall+0x179>
		return ret;
	child->env_status = ENV_NOT_RUNNABLE;
f01050bb:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01050be:	c7 43 54 04 00 00 00 	movl   $0x4,0x54(%ebx)
	child->env_tf = thiscpu->cpu_env->env_tf;
f01050c5:	e8 af 17 00 00       	call   f0106879 <cpunum>
f01050ca:	6b c0 74             	imul   $0x74,%eax,%eax
f01050cd:	8b b0 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%esi
f01050d3:	b9 11 00 00 00       	mov    $0x11,%ecx
f01050d8:	89 df                	mov    %ebx,%edi
f01050da:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
	child->env_tf.tf_regs.reg_eax = 0;
f01050dc:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01050df:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	return child->env_id;
f01050e6:	8b 50 48             	mov    0x48(%eax),%edx
		sys_yield();
		return 0;
		break;

		case SYS_exofork:
		return sys_exofork();
f01050e9:	89 d0                	mov    %edx,%eax
f01050eb:	e9 0c 05 00 00       	jmp    f01055fc <syscall+0x68c>
	// check whether the current environment has permission to set
	// envid's status.

	// LAB 4: Your code here.

	if(status!=ENV_RUNNABLE && status!=ENV_NOT_RUNNABLE)
f01050f0:	83 fb 04             	cmp    $0x4,%ebx
f01050f3:	74 05                	je     f01050fa <syscall+0x18a>
f01050f5:	83 fb 02             	cmp    $0x2,%ebx
f01050f8:	75 32                	jne    f010512c <syscall+0x1bc>
		return -E_INVAL;

	struct Env* proc;
	int ret = envid2env(envid, &proc, 1);
f01050fa:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0105101:	00 
f0105102:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0105105:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105109:	8b 45 0c             	mov    0xc(%ebp),%eax
f010510c:	89 04 24             	mov    %eax,(%esp)
f010510f:	e8 31 e5 ff ff       	call   f0103645 <envid2env>
	if(ret<0)
f0105114:	85 c0                	test   %eax,%eax
f0105116:	0f 88 e0 04 00 00    	js     f01055fc <syscall+0x68c>
		return ret;
	proc->env_status = status;
f010511c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010511f:	89 58 54             	mov    %ebx,0x54(%eax)

	return 0;
f0105122:	b8 00 00 00 00       	mov    $0x0,%eax
f0105127:	e9 d0 04 00 00       	jmp    f01055fc <syscall+0x68c>
	// envid's status.

	// LAB 4: Your code here.

	if(status!=ENV_RUNNABLE && status!=ENV_NOT_RUNNABLE)
		return -E_INVAL;
f010512c:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105131:	e9 c6 04 00 00       	jmp    f01055fc <syscall+0x68c>
	//   If page_insert() fails, remember to free the page you
	//   allocated!

	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
f0105136:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010513d:	00 
f010513e:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0105141:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105145:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105148:	89 04 24             	mov    %eax,(%esp)
f010514b:	e8 f5 e4 ff ff       	call   f0103645 <envid2env>
f0105150:	85 c0                	test   %eax,%eax
f0105152:	78 6f                	js     f01051c3 <syscall+0x253>
		return -E_BAD_ENV;
	if((int)va>=UTOP || ((int)va)%PGSIZE>0)
f0105154:	81 fb ff ff bf ee    	cmp    $0xeebfffff,%ebx
f010515a:	77 71                	ja     f01051cd <syscall+0x25d>
f010515c:	89 d8                	mov    %ebx,%eax
f010515e:	c1 f8 1f             	sar    $0x1f,%eax
f0105161:	c1 e8 14             	shr    $0x14,%eax
f0105164:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0105167:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f010516d:	29 c2                	sub    %eax,%edx
f010516f:	85 d2                	test   %edx,%edx
f0105171:	7f 64                	jg     f01051d7 <syscall+0x267>
		return -E_INVAL;
	int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
	if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
f0105173:	8b 45 14             	mov    0x14(%ebp),%eax
f0105176:	83 e0 05             	and    $0x5,%eax
f0105179:	83 f8 05             	cmp    $0x5,%eax
f010517c:	75 63                	jne    f01051e1 <syscall+0x271>
		return -E_INVAL;
	struct PageInfo* pp;
	if(!(pp=page_alloc(0)))
f010517e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105185:	e8 ec be ff ff       	call   f0101076 <page_alloc>
f010518a:	89 c6                	mov    %eax,%esi
f010518c:	85 c0                	test   %eax,%eax
f010518e:	74 5b                	je     f01051eb <syscall+0x27b>
		return -E_NO_MEM;
	if(page_insert(proc->env_pgdir, pp, va, perm)<0){
f0105190:	8b 45 14             	mov    0x14(%ebp),%eax
f0105193:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105197:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010519b:	89 74 24 04          	mov    %esi,0x4(%esp)
f010519f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01051a2:	8b 40 60             	mov    0x60(%eax),%eax
f01051a5:	89 04 24             	mov    %eax,(%esp)
f01051a8:	e8 e5 c1 ff ff       	call   f0101392 <page_insert>
f01051ad:	85 c0                	test   %eax,%eax
f01051af:	79 44                	jns    f01051f5 <syscall+0x285>
		page_free(pp);
f01051b1:	89 34 24             	mov    %esi,(%esp)
f01051b4:	e8 48 bf ff ff       	call   f0101101 <page_free>
		return -E_NO_MEM;
f01051b9:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f01051be:	e9 39 04 00 00       	jmp    f01055fc <syscall+0x68c>
	//   allocated!

	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
		return -E_BAD_ENV;
f01051c3:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01051c8:	e9 2f 04 00 00       	jmp    f01055fc <syscall+0x68c>
	if((int)va>=UTOP || ((int)va)%PGSIZE>0)
		return -E_INVAL;
f01051cd:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01051d2:	e9 25 04 00 00       	jmp    f01055fc <syscall+0x68c>
f01051d7:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01051dc:	e9 1b 04 00 00       	jmp    f01055fc <syscall+0x68c>
	int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
	if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
		return -E_INVAL;
f01051e1:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01051e6:	e9 11 04 00 00       	jmp    f01055fc <syscall+0x68c>
	struct PageInfo* pp;
	if(!(pp=page_alloc(0)))
		return -E_NO_MEM;
f01051eb:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f01051f0:	e9 07 04 00 00       	jmp    f01055fc <syscall+0x68c>
	if(page_insert(proc->env_pgdir, pp, va, perm)<0){
		page_free(pp);
		return -E_NO_MEM;
	}
	return 0;
f01051f5:	b8 00 00 00 00       	mov    $0x0,%eax
		case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
		break;

		case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
f01051fa:	e9 fd 03 00 00       	jmp    f01055fc <syscall+0x68c>
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.

	// LAB 4: Your code here.
	struct Env *src, *dst;
	if(envid2env(srcenvid, &src, 1)<0)
f01051ff:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0105206:	00 
f0105207:	8d 45 dc             	lea    -0x24(%ebp),%eax
f010520a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010520e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105211:	89 04 24             	mov    %eax,(%esp)
f0105214:	e8 2c e4 ff ff       	call   f0103645 <envid2env>
f0105219:	85 c0                	test   %eax,%eax
f010521b:	0f 88 d9 00 00 00    	js     f01052fa <syscall+0x38a>
		return -E_BAD_ENV;
	if(envid2env(dstenvid, &dst, 1)<0)
f0105221:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0105228:	00 
f0105229:	8d 45 e0             	lea    -0x20(%ebp),%eax
f010522c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105230:	8b 45 14             	mov    0x14(%ebp),%eax
f0105233:	89 04 24             	mov    %eax,(%esp)
f0105236:	e8 0a e4 ff ff       	call   f0103645 <envid2env>
f010523b:	85 c0                	test   %eax,%eax
f010523d:	0f 88 c1 00 00 00    	js     f0105304 <syscall+0x394>
		return -E_BAD_ENV;
	if((int)srcva>=UTOP || ((int)srcva)%PGSIZE>0)
f0105243:	81 fb ff ff bf ee    	cmp    $0xeebfffff,%ebx
f0105249:	0f 87 bf 00 00 00    	ja     f010530e <syscall+0x39e>
f010524f:	89 d8                	mov    %ebx,%eax
f0105251:	c1 f8 1f             	sar    $0x1f,%eax
f0105254:	c1 e8 14             	shr    $0x14,%eax
f0105257:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f010525a:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f0105260:	29 c2                	sub    %eax,%edx
f0105262:	85 d2                	test   %edx,%edx
f0105264:	0f 8f ae 00 00 00    	jg     f0105318 <syscall+0x3a8>
		return -E_INVAL;
	if((int)dstva>=UTOP || ((int)dstva)%PGSIZE>0)
f010526a:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0105271:	0f 87 ab 00 00 00    	ja     f0105322 <syscall+0x3b2>
f0105277:	8b 45 18             	mov    0x18(%ebp),%eax
f010527a:	c1 f8 1f             	sar    $0x1f,%eax
f010527d:	c1 e8 14             	shr    $0x14,%eax
f0105280:	89 c2                	mov    %eax,%edx
f0105282:	03 55 18             	add    0x18(%ebp),%edx
f0105285:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f010528b:	29 c2                	sub    %eax,%edx
f010528d:	85 d2                	test   %edx,%edx
f010528f:	0f 8f 97 00 00 00    	jg     f010532c <syscall+0x3bc>
		return -E_INVAL;
	int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
	if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
f0105295:	8b 45 1c             	mov    0x1c(%ebp),%eax
f0105298:	83 e0 05             	and    $0x5,%eax
f010529b:	83 f8 05             	cmp    $0x5,%eax
f010529e:	0f 85 92 00 00 00    	jne    f0105336 <syscall+0x3c6>
		return -E_INVAL;

	struct PageInfo* pp;
	pte_t *page_table_entry;
	if(!(pp=page_lookup(src->env_pgdir, srcva, &page_table_entry)))
f01052a4:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01052a7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01052ab:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052af:	8b 45 dc             	mov    -0x24(%ebp),%eax
f01052b2:	8b 40 60             	mov    0x60(%eax),%eax
f01052b5:	89 04 24             	mov    %eax,(%esp)
f01052b8:	e8 b7 bf ff ff       	call   f0101274 <page_lookup>
f01052bd:	85 c0                	test   %eax,%eax
f01052bf:	74 7f                	je     f0105340 <syscall+0x3d0>
		return -E_INVAL;
	if(!((*page_table_entry)&PTE_W) && perm&PTE_W)
f01052c1:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f01052c4:	f6 02 02             	testb  $0x2,(%edx)
f01052c7:	75 06                	jne    f01052cf <syscall+0x35f>
f01052c9:	f6 45 1c 02          	testb  $0x2,0x1c(%ebp)
f01052cd:	75 7b                	jne    f010534a <syscall+0x3da>
		return -E_INVAL;

	if(page_insert(dst->env_pgdir, pp, dstva, perm)<0)
f01052cf:	8b 4d 1c             	mov    0x1c(%ebp),%ecx
f01052d2:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01052d6:	8b 4d 18             	mov    0x18(%ebp),%ecx
f01052d9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01052dd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01052e1:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01052e4:	8b 40 60             	mov    0x60(%eax),%eax
f01052e7:	89 04 24             	mov    %eax,(%esp)
f01052ea:	e8 a3 c0 ff ff       	call   f0101392 <page_insert>
		return -E_NO_MEM;
f01052ef:	c1 f8 1f             	sar    $0x1f,%eax
f01052f2:	83 e0 fc             	and    $0xfffffffc,%eax
f01052f5:	e9 02 03 00 00       	jmp    f01055fc <syscall+0x68c>
	//   check the current permissions on the page.

	// LAB 4: Your code here.
	struct Env *src, *dst;
	if(envid2env(srcenvid, &src, 1)<0)
		return -E_BAD_ENV;
f01052fa:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01052ff:	e9 f8 02 00 00       	jmp    f01055fc <syscall+0x68c>
	if(envid2env(dstenvid, &dst, 1)<0)
		return -E_BAD_ENV;
f0105304:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0105309:	e9 ee 02 00 00       	jmp    f01055fc <syscall+0x68c>
	if((int)srcva>=UTOP || ((int)srcva)%PGSIZE>0)
		return -E_INVAL;
f010530e:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105313:	e9 e4 02 00 00       	jmp    f01055fc <syscall+0x68c>
f0105318:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010531d:	e9 da 02 00 00       	jmp    f01055fc <syscall+0x68c>
	if((int)dstva>=UTOP || ((int)dstva)%PGSIZE>0)
		return -E_INVAL;
f0105322:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105327:	e9 d0 02 00 00       	jmp    f01055fc <syscall+0x68c>
f010532c:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105331:	e9 c6 02 00 00       	jmp    f01055fc <syscall+0x68c>
	int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
	if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
		return -E_INVAL;
f0105336:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010533b:	e9 bc 02 00 00       	jmp    f01055fc <syscall+0x68c>

	struct PageInfo* pp;
	pte_t *page_table_entry;
	if(!(pp=page_lookup(src->env_pgdir, srcva, &page_table_entry)))
		return -E_INVAL;
f0105340:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105345:	e9 b2 02 00 00       	jmp    f01055fc <syscall+0x68c>
	if(!((*page_table_entry)&PTE_W) && perm&PTE_W)
		return -E_INVAL;
f010534a:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
		break;

		case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f010534f:	e9 a8 02 00 00       	jmp    f01055fc <syscall+0x68c>
{
	// Hint: This function is a wrapper around page_remove().

	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
f0105354:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010535b:	00 
f010535c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010535f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105363:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105366:	89 04 24             	mov    %eax,(%esp)
f0105369:	e8 d7 e2 ff ff       	call   f0103645 <envid2env>
f010536e:	85 c0                	test   %eax,%eax
f0105370:	78 44                	js     f01053b6 <syscall+0x446>
		return -E_BAD_ENV;
	if((int)va>=UTOP || ((int)va)%PGSIZE>0)
f0105372:	81 fb ff ff bf ee    	cmp    $0xeebfffff,%ebx
f0105378:	77 46                	ja     f01053c0 <syscall+0x450>
f010537a:	89 d8                	mov    %ebx,%eax
f010537c:	c1 f8 1f             	sar    $0x1f,%eax
f010537f:	c1 e8 14             	shr    $0x14,%eax
f0105382:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0105385:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f010538b:	29 c2                	sub    %eax,%edx
		return -E_INVAL;
f010538d:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
		return -E_BAD_ENV;
	if((int)va>=UTOP || ((int)va)%PGSIZE>0)
f0105392:	85 d2                	test   %edx,%edx
f0105394:	0f 8f 62 02 00 00    	jg     f01055fc <syscall+0x68c>
		return -E_INVAL;
	page_remove(proc->env_pgdir, va);
f010539a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010539e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01053a1:	8b 40 60             	mov    0x60(%eax),%eax
f01053a4:	89 04 24             	mov    %eax,(%esp)
f01053a7:	e8 75 bf ff ff       	call   f0101321 <page_remove>
	return 0;
f01053ac:	b8 00 00 00 00       	mov    $0x0,%eax
f01053b1:	e9 46 02 00 00       	jmp    f01055fc <syscall+0x68c>
	// Hint: This function is a wrapper around page_remove().

	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
		return -E_BAD_ENV;
f01053b6:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01053bb:	e9 3c 02 00 00       	jmp    f01055fc <syscall+0x68c>
	if((int)va>=UTOP || ((int)va)%PGSIZE>0)
		return -E_INVAL;
f01053c0:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		break;

		case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
f01053c5:	e9 32 02 00 00       	jmp    f01055fc <syscall+0x68c>
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
f01053ca:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01053d1:	00 
f01053d2:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01053d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053d9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01053dc:	89 04 24             	mov    %eax,(%esp)
f01053df:	e8 61 e2 ff ff       	call   f0103645 <envid2env>
f01053e4:	85 c0                	test   %eax,%eax
f01053e6:	78 10                	js     f01053f8 <syscall+0x488>
		return -E_BAD_ENV;
	proc->env_pgfault_upcall = func;
f01053e8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01053eb:	89 58 64             	mov    %ebx,0x64(%eax)
	return 0;
f01053ee:	b8 00 00 00 00       	mov    $0x0,%eax
f01053f3:	e9 04 02 00 00       	jmp    f01055fc <syscall+0x68c>
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	// LAB 4: Your code here.
	struct Env* proc;
	if(envid2env(envid, &proc, 1)<0)
		return -E_BAD_ENV;
f01053f8:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
		case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
		break;

		case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
f01053fd:	e9 fa 01 00 00       	jmp    f01055fc <syscall+0x68c>
static int
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env * target;
	if(envid2env(envid, &target, 0)<0)
f0105402:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0105409:	00 
f010540a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f010540d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105411:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105414:	89 04 24             	mov    %eax,(%esp)
f0105417:	e8 29 e2 ff ff       	call   f0103645 <envid2env>
f010541c:	85 c0                	test   %eax,%eax
f010541e:	0f 88 4e 01 00 00    	js     f0105572 <syscall+0x602>
		return -E_BAD_ENV;
	if(!target->env_ipc_recving)
f0105424:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105427:	80 78 68 00          	cmpb   $0x0,0x68(%eax)
f010542b:	0f 84 4b 01 00 00    	je     f010557c <syscall+0x60c>
		return -E_IPC_NOT_RECV;

	if((int)srcva < UTOP && (int)target->env_ipc_dstva<UTOP)
f0105431:	81 7d 14 ff ff bf ee 	cmpl   $0xeebfffff,0x14(%ebp)
f0105438:	0f 87 f4 00 00 00    	ja     f0105532 <syscall+0x5c2>
f010543e:	81 78 6c ff ff bf ee 	cmpl   $0xeebfffff,0x6c(%eax)
f0105445:	0f 87 e7 00 00 00    	ja     f0105532 <syscall+0x5c2>
	{
		if(ROUNDDOWN(srcva, PGSIZE)!=srcva)
f010544b:	8b 55 14             	mov    0x14(%ebp),%edx
f010544e:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
			return -E_INVAL;
f0105454:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	if(!target->env_ipc_recving)
		return -E_IPC_NOT_RECV;

	if((int)srcva < UTOP && (int)target->env_ipc_dstva<UTOP)
	{
		if(ROUNDDOWN(srcva, PGSIZE)!=srcva)
f0105459:	39 55 14             	cmp    %edx,0x14(%ebp)
f010545c:	0f 85 9a 01 00 00    	jne    f01055fc <syscall+0x68c>
			return -E_INVAL;
		int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
		if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
f0105462:	8b 55 18             	mov    0x18(%ebp),%edx
f0105465:	83 e2 05             	and    $0x5,%edx
f0105468:	83 fa 05             	cmp    $0x5,%edx
f010546b:	0f 85 8b 01 00 00    	jne    f01055fc <syscall+0x68c>
			return -E_INVAL;
		if(user_mem_check(curenv, srcva, PGSIZE, perm)<0)
f0105471:	e8 03 14 00 00       	call   f0106879 <cpunum>
f0105476:	8b 7d 18             	mov    0x18(%ebp),%edi
f0105479:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010547d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0105484:	00 
f0105485:	8b 7d 14             	mov    0x14(%ebp),%edi
f0105488:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010548c:	6b c0 74             	imul   $0x74,%eax,%eax
f010548f:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f0105495:	89 04 24             	mov    %eax,(%esp)
f0105498:	e8 00 e0 ff ff       	call   f010349d <user_mem_check>
f010549d:	85 c0                	test   %eax,%eax
f010549f:	78 73                	js     f0105514 <syscall+0x5a4>
			return -E_INVAL;

		struct PageInfo* pp;
		pte_t *page_table_entry;
		if(!(pp=page_lookup(curenv->env_pgdir, srcva, &page_table_entry)))
f01054a1:	e8 d3 13 00 00       	call   f0106879 <cpunum>
f01054a6:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01054a9:	89 54 24 08          	mov    %edx,0x8(%esp)
f01054ad:	8b 7d 14             	mov    0x14(%ebp),%edi
f01054b0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054b4:	6b c0 74             	imul   $0x74,%eax,%eax
f01054b7:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01054bd:	8b 40 60             	mov    0x60(%eax),%eax
f01054c0:	89 04 24             	mov    %eax,(%esp)
f01054c3:	e8 ac bd ff ff       	call   f0101274 <page_lookup>
f01054c8:	89 c1                	mov    %eax,%ecx
f01054ca:	85 c0                	test   %eax,%eax
f01054cc:	74 50                	je     f010551e <syscall+0x5ae>
			return -E_INVAL;
		if(!((*page_table_entry)&PTE_W) && perm&PTE_W)
f01054ce:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01054d1:	f6 00 02             	testb  $0x2,(%eax)
f01054d4:	75 0f                	jne    f01054e5 <syscall+0x575>
			return -E_INVAL;
f01054d6:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

		struct PageInfo* pp;
		pte_t *page_table_entry;
		if(!(pp=page_lookup(curenv->env_pgdir, srcva, &page_table_entry)))
			return -E_INVAL;
		if(!((*page_table_entry)&PTE_W) && perm&PTE_W)
f01054db:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f01054df:	0f 85 17 01 00 00    	jne    f01055fc <syscall+0x68c>
			return -E_INVAL;

		if(page_insert(target->env_pgdir, pp, target->env_ipc_dstva, perm)<0)
f01054e5:	8b 55 e0             	mov    -0x20(%ebp),%edx
f01054e8:	8b 45 18             	mov    0x18(%ebp),%eax
f01054eb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01054ef:	8b 42 6c             	mov    0x6c(%edx),%eax
f01054f2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01054f6:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01054fa:	8b 42 60             	mov    0x60(%edx),%eax
f01054fd:	89 04 24             	mov    %eax,(%esp)
f0105500:	e8 8d be ff ff       	call   f0101392 <page_insert>
f0105505:	85 c0                	test   %eax,%eax
f0105507:	78 1f                	js     f0105528 <syscall+0x5b8>
			return -E_NO_MEM;

		target->env_ipc_perm = perm;
f0105509:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010550c:	8b 7d 18             	mov    0x18(%ebp),%edi
f010550f:	89 78 78             	mov    %edi,0x78(%eax)
f0105512:	eb 25                	jmp    f0105539 <syscall+0x5c9>
			return -E_INVAL;
		int none = !(PTE_U|PTE_P|PTE_AVAIL|PTE_W);
		if(!(perm&PTE_U && perm&PTE_P && !(perm&none)))
			return -E_INVAL;
		if(user_mem_check(curenv, srcva, PGSIZE, perm)<0)
			return -E_INVAL;
f0105514:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105519:	e9 de 00 00 00       	jmp    f01055fc <syscall+0x68c>

		struct PageInfo* pp;
		pte_t *page_table_entry;
		if(!(pp=page_lookup(curenv->env_pgdir, srcva, &page_table_entry)))
			return -E_INVAL;
f010551e:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105523:	e9 d4 00 00 00       	jmp    f01055fc <syscall+0x68c>
		if(!((*page_table_entry)&PTE_W) && perm&PTE_W)
			return -E_INVAL;

		if(page_insert(target->env_pgdir, pp, target->env_ipc_dstva, perm)<0)
			return -E_NO_MEM;
f0105528:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f010552d:	e9 ca 00 00 00       	jmp    f01055fc <syscall+0x68c>

		target->env_ipc_perm = perm;
	}
	else
		target->env_ipc_perm = 0;
f0105532:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)

	target->env_ipc_recving = false;
f0105539:	8b 75 e0             	mov    -0x20(%ebp),%esi
f010553c:	c6 46 68 00          	movb   $0x0,0x68(%esi)
	target->env_ipc_from = curenv->env_id;
f0105540:	e8 34 13 00 00       	call   f0106879 <cpunum>
f0105545:	6b c0 74             	imul   $0x74,%eax,%eax
f0105548:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f010554e:	8b 40 48             	mov    0x48(%eax),%eax
f0105551:	89 46 74             	mov    %eax,0x74(%esi)
	target->env_ipc_value = value;
f0105554:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105557:	89 58 70             	mov    %ebx,0x70(%eax)
	target->env_tf.tf_regs.reg_eax = 0;
f010555a:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	target->env_status = ENV_RUNNABLE;
f0105561:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	return 0;
f0105568:	b8 00 00 00 00       	mov    $0x0,%eax
f010556d:	e9 8a 00 00 00       	jmp    f01055fc <syscall+0x68c>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env * target;
	if(envid2env(envid, &target, 0)<0)
		return -E_BAD_ENV;
f0105572:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0105577:	e9 80 00 00 00       	jmp    f01055fc <syscall+0x68c>
	if(!target->env_ipc_recving)
		return -E_IPC_NOT_RECV;
f010557c:	b8 f8 ff ff ff       	mov    $0xfffffff8,%eax
		case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
		break;

		case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, (unsigned)a4);
f0105581:	eb 79                	jmp    f01055fc <syscall+0x68c>
static int
sys_ipc_recv(void *dstva)
{
	// LAB 4: Your code here.

	if((int)dstva<UTOP){
f0105583:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f010558a:	77 23                	ja     f01055af <syscall+0x63f>
		if(ROUNDDOWN(dstva, PGSIZE)!=dstva)
f010558c:	8b 45 0c             	mov    0xc(%ebp),%eax
f010558f:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0105594:	39 45 0c             	cmp    %eax,0xc(%ebp)
f0105597:	75 5e                	jne    f01055f7 <syscall+0x687>
			return -E_INVAL;
		curenv->env_ipc_dstva = dstva;
f0105599:	e8 db 12 00 00       	call   f0106879 <cpunum>
f010559e:	6b c0 74             	imul   $0x74,%eax,%eax
f01055a1:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01055a7:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01055aa:	89 78 6c             	mov    %edi,0x6c(%eax)
f01055ad:	eb 15                	jmp    f01055c4 <syscall+0x654>
	}
	else
		curenv->env_ipc_dstva = (void*)UTOP;	
f01055af:	e8 c5 12 00 00       	call   f0106879 <cpunum>
f01055b4:	6b c0 74             	imul   $0x74,%eax,%eax
f01055b7:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01055bd:	c7 40 6c 00 00 c0 ee 	movl   $0xeec00000,0x6c(%eax)

	curenv->env_ipc_recving = true;
f01055c4:	e8 b0 12 00 00       	call   f0106879 <cpunum>
f01055c9:	6b c0 74             	imul   $0x74,%eax,%eax
f01055cc:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01055d2:	c6 40 68 01          	movb   $0x1,0x68(%eax)

	curenv->env_status = ENV_NOT_RUNNABLE;
f01055d6:	e8 9e 12 00 00       	call   f0106879 <cpunum>
f01055db:	6b c0 74             	imul   $0x74,%eax,%eax
f01055de:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01055e4:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f01055eb:	e8 86 f8 ff ff       	call   f0104e76 <sched_yield>
		case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
		break;

		default:
			return -E_INVAL;
f01055f0:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01055f5:	eb 05                	jmp    f01055fc <syscall+0x68c>
		case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, (unsigned)a4);
		break;

		case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
f01055f7:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		break;

		default:
			return -E_INVAL;
	}
}
f01055fc:	83 c4 2c             	add    $0x2c,%esp
f01055ff:	5b                   	pop    %ebx
f0105600:	5e                   	pop    %esi
f0105601:	5f                   	pop    %edi
f0105602:	5d                   	pop    %ebp
f0105603:	c3                   	ret    

f0105604 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0105604:	55                   	push   %ebp
f0105605:	89 e5                	mov    %esp,%ebp
f0105607:	57                   	push   %edi
f0105608:	56                   	push   %esi
f0105609:	53                   	push   %ebx
f010560a:	83 ec 14             	sub    $0x14,%esp
f010560d:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105610:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0105613:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0105616:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0105619:	8b 1a                	mov    (%edx),%ebx
f010561b:	8b 01                	mov    (%ecx),%eax
f010561d:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0105620:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)

	while (l <= r) {
f0105627:	e9 88 00 00 00       	jmp    f01056b4 <stab_binsearch+0xb0>
		int true_m = (l + r) / 2, m = true_m;
f010562c:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010562f:	01 d8                	add    %ebx,%eax
f0105631:	89 c7                	mov    %eax,%edi
f0105633:	c1 ef 1f             	shr    $0x1f,%edi
f0105636:	01 c7                	add    %eax,%edi
f0105638:	d1 ff                	sar    %edi
f010563a:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f010563d:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105640:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0105643:	89 f8                	mov    %edi,%eax

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0105645:	eb 03                	jmp    f010564a <stab_binsearch+0x46>
			m--;
f0105647:	83 e8 01             	sub    $0x1,%eax

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010564a:	39 c3                	cmp    %eax,%ebx
f010564c:	7f 1f                	jg     f010566d <stab_binsearch+0x69>
f010564e:	0f b6 4a 04          	movzbl 0x4(%edx),%ecx
f0105652:	83 ea 0c             	sub    $0xc,%edx
f0105655:	39 f1                	cmp    %esi,%ecx
f0105657:	75 ee                	jne    f0105647 <stab_binsearch+0x43>
f0105659:	89 45 e8             	mov    %eax,-0x18(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010565c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010565f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105662:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0105666:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0105669:	76 18                	jbe    f0105683 <stab_binsearch+0x7f>
f010566b:	eb 05                	jmp    f0105672 <stab_binsearch+0x6e>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f010566d:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0105670:	eb 42                	jmp    f01056b4 <stab_binsearch+0xb0>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0105672:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0105675:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0105677:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010567a:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0105681:	eb 31                	jmp    f01056b4 <stab_binsearch+0xb0>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0105683:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0105686:	73 17                	jae    f010569f <stab_binsearch+0x9b>
			*region_right = m - 1;
f0105688:	8b 45 e8             	mov    -0x18(%ebp),%eax
f010568b:	83 e8 01             	sub    $0x1,%eax
f010568e:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0105691:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0105694:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0105696:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f010569d:	eb 15                	jmp    f01056b4 <stab_binsearch+0xb0>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f010569f:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01056a2:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f01056a5:	89 1f                	mov    %ebx,(%edi)
			l = m;
			addr++;
f01056a7:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01056ab:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01056ad:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;

	while (l <= r) {
f01056b4:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01056b7:	0f 8e 6f ff ff ff    	jle    f010562c <stab_binsearch+0x28>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01056bd:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01056c1:	75 0f                	jne    f01056d2 <stab_binsearch+0xce>
		*region_right = *region_left - 1;
f01056c3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01056c6:	8b 00                	mov    (%eax),%eax
f01056c8:	83 e8 01             	sub    $0x1,%eax
f01056cb:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01056ce:	89 07                	mov    %eax,(%edi)
f01056d0:	eb 2c                	jmp    f01056fe <stab_binsearch+0xfa>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01056d2:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01056d5:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f01056d7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01056da:	8b 0f                	mov    (%edi),%ecx
f01056dc:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01056df:	8b 7d ec             	mov    -0x14(%ebp),%edi
f01056e2:	8d 14 97             	lea    (%edi,%edx,4),%edx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01056e5:	eb 03                	jmp    f01056ea <stab_binsearch+0xe6>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f01056e7:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01056ea:	39 c8                	cmp    %ecx,%eax
f01056ec:	7e 0b                	jle    f01056f9 <stab_binsearch+0xf5>
		     l > *region_left && stabs[l].n_type != type;
f01056ee:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f01056f2:	83 ea 0c             	sub    $0xc,%edx
f01056f5:	39 f3                	cmp    %esi,%ebx
f01056f7:	75 ee                	jne    f01056e7 <stab_binsearch+0xe3>
		     l--)
			/* do nothing */;
		*region_left = l;
f01056f9:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01056fc:	89 07                	mov    %eax,(%edi)
	}
}
f01056fe:	83 c4 14             	add    $0x14,%esp
f0105701:	5b                   	pop    %ebx
f0105702:	5e                   	pop    %esi
f0105703:	5f                   	pop    %edi
f0105704:	5d                   	pop    %ebp
f0105705:	c3                   	ret    

f0105706 <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0105706:	55                   	push   %ebp
f0105707:	89 e5                	mov    %esp,%ebp
f0105709:	57                   	push   %edi
f010570a:	56                   	push   %esi
f010570b:	53                   	push   %ebx
f010570c:	83 ec 4c             	sub    $0x4c,%esp
f010570f:	8b 75 08             	mov    0x8(%ebp),%esi
f0105712:	8b 7d 0c             	mov    0xc(%ebp),%edi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0105715:	c7 07 34 86 10 f0    	movl   $0xf0108634,(%edi)
	info->eip_line = 0;
f010571b:	c7 47 04 00 00 00 00 	movl   $0x0,0x4(%edi)
	info->eip_fn_name = "<unknown>";
f0105722:	c7 47 08 34 86 10 f0 	movl   $0xf0108634,0x8(%edi)
	info->eip_fn_namelen = 9;
f0105729:	c7 47 0c 09 00 00 00 	movl   $0x9,0xc(%edi)
	info->eip_fn_addr = addr;
f0105730:	89 77 10             	mov    %esi,0x10(%edi)
	info->eip_fn_narg = 0;
f0105733:	c7 47 14 00 00 00 00 	movl   $0x0,0x14(%edi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f010573a:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0105740:	0f 87 c0 00 00 00    	ja     f0105806 <debuginfo_eip+0x100>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.

		int check = user_mem_check(curenv, usd, sizeof(struct UserStabData), PTE_U);
f0105746:	e8 2e 11 00 00       	call   f0106879 <cpunum>
f010574b:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0105752:	00 
f0105753:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f010575a:	00 
f010575b:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0105762:	00 
f0105763:	6b c0 74             	imul   $0x74,%eax,%eax
f0105766:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f010576c:	89 04 24             	mov    %eax,(%esp)
f010576f:	e8 29 dd ff ff       	call   f010349d <user_mem_check>
		if(check<0)
f0105774:	85 c0                	test   %eax,%eax
f0105776:	0f 88 50 02 00 00    	js     f01059cc <debuginfo_eip+0x2c6>
			return -1;

		stabs = usd->stabs;
f010577c:	a1 00 00 20 00       	mov    0x200000,%eax
		stab_end = usd->stab_end;
f0105781:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0105787:	8b 0d 08 00 20 00    	mov    0x200008,%ecx
f010578d:	89 4d c0             	mov    %ecx,-0x40(%ebp)
		stabstr_end = usd->stabstr_end;
f0105790:	8b 15 0c 00 20 00    	mov    0x20000c,%edx
f0105796:	89 55 bc             	mov    %edx,-0x44(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		user_mem_assert(curenv, stabs, (uintptr_t)stab_end - (uintptr_t)stabs, PTE_U);
f0105799:	89 da                	mov    %ebx,%edx
f010579b:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f010579e:	29 c2                	sub    %eax,%edx
f01057a0:	89 55 b8             	mov    %edx,-0x48(%ebp)
f01057a3:	e8 d1 10 00 00       	call   f0106879 <cpunum>
f01057a8:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01057af:	00 
f01057b0:	8b 55 b8             	mov    -0x48(%ebp),%edx
f01057b3:	89 54 24 08          	mov    %edx,0x8(%esp)
f01057b7:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f01057ba:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01057be:	6b c0 74             	imul   $0x74,%eax,%eax
f01057c1:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01057c7:	89 04 24             	mov    %eax,(%esp)
f01057ca:	e8 82 dd ff ff       	call   f0103551 <user_mem_assert>
		user_mem_assert(curenv, stabstr, (uintptr_t)stabstr_end - (uintptr_t)stabstr, PTE_U);
f01057cf:	8b 55 bc             	mov    -0x44(%ebp),%edx
f01057d2:	2b 55 c0             	sub    -0x40(%ebp),%edx
f01057d5:	89 55 b8             	mov    %edx,-0x48(%ebp)
f01057d8:	e8 9c 10 00 00       	call   f0106879 <cpunum>
f01057dd:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01057e4:	00 
f01057e5:	8b 55 b8             	mov    -0x48(%ebp),%edx
f01057e8:	89 54 24 08          	mov    %edx,0x8(%esp)
f01057ec:	8b 4d c0             	mov    -0x40(%ebp),%ecx
f01057ef:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01057f3:	6b c0 74             	imul   $0x74,%eax,%eax
f01057f6:	8b 80 28 20 23 f0    	mov    -0xfdcdfd8(%eax),%eax
f01057fc:	89 04 24             	mov    %eax,(%esp)
f01057ff:	e8 4d dd ff ff       	call   f0103551 <user_mem_assert>
f0105804:	eb 1a                	jmp    f0105820 <debuginfo_eip+0x11a>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0105806:	c7 45 bc 4d 68 11 f0 	movl   $0xf011684d,-0x44(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f010580d:	c7 45 c0 5d 31 11 f0 	movl   $0xf011315d,-0x40(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105814:	bb 5c 31 11 f0       	mov    $0xf011315c,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105819:	c7 45 c4 18 8b 10 f0 	movl   $0xf0108b18,-0x3c(%ebp)
		user_mem_assert(curenv, stabs, (uintptr_t)stab_end - (uintptr_t)stabs, PTE_U);
		user_mem_assert(curenv, stabstr, (uintptr_t)stabstr_end - (uintptr_t)stabstr, PTE_U);
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0105820:	8b 45 bc             	mov    -0x44(%ebp),%eax
f0105823:	39 45 c0             	cmp    %eax,-0x40(%ebp)
f0105826:	0f 83 a7 01 00 00    	jae    f01059d3 <debuginfo_eip+0x2cd>
f010582c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0105830:	0f 85 a4 01 00 00    	jne    f01059da <debuginfo_eip+0x2d4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0105836:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f010583d:	2b 5d c4             	sub    -0x3c(%ebp),%ebx
f0105840:	c1 fb 02             	sar    $0x2,%ebx
f0105843:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0105849:	83 e8 01             	sub    $0x1,%eax
f010584c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f010584f:	89 74 24 04          	mov    %esi,0x4(%esp)
f0105853:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010585a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f010585d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0105860:	8b 5d c4             	mov    -0x3c(%ebp),%ebx
f0105863:	89 d8                	mov    %ebx,%eax
f0105865:	e8 9a fd ff ff       	call   f0105604 <stab_binsearch>
	if (lfile == 0)
f010586a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010586d:	85 c0                	test   %eax,%eax
f010586f:	0f 84 6c 01 00 00    	je     f01059e1 <debuginfo_eip+0x2db>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0105875:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0105878:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010587b:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f010587e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0105882:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0105889:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f010588c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f010588f:	89 d8                	mov    %ebx,%eax
f0105891:	e8 6e fd ff ff       	call   f0105604 <stab_binsearch>

	if (lfun <= rfun) {
f0105896:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0105899:	8b 5d d8             	mov    -0x28(%ebp),%ebx
f010589c:	39 d8                	cmp    %ebx,%eax
f010589e:	7f 32                	jg     f01058d2 <debuginfo_eip+0x1cc>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f01058a0:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01058a3:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f01058a6:	8d 14 91             	lea    (%ecx,%edx,4),%edx
f01058a9:	8b 0a                	mov    (%edx),%ecx
f01058ab:	89 4d b8             	mov    %ecx,-0x48(%ebp)
f01058ae:	8b 4d bc             	mov    -0x44(%ebp),%ecx
f01058b1:	2b 4d c0             	sub    -0x40(%ebp),%ecx
f01058b4:	39 4d b8             	cmp    %ecx,-0x48(%ebp)
f01058b7:	73 09                	jae    f01058c2 <debuginfo_eip+0x1bc>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f01058b9:	8b 4d b8             	mov    -0x48(%ebp),%ecx
f01058bc:	03 4d c0             	add    -0x40(%ebp),%ecx
f01058bf:	89 4f 08             	mov    %ecx,0x8(%edi)
		info->eip_fn_addr = stabs[lfun].n_value;
f01058c2:	8b 52 08             	mov    0x8(%edx),%edx
f01058c5:	89 57 10             	mov    %edx,0x10(%edi)
		addr -= info->eip_fn_addr;
f01058c8:	29 d6                	sub    %edx,%esi
		// Search within the function definition for the line number.
		lline = lfun;
f01058ca:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfun;
f01058cd:	89 5d d0             	mov    %ebx,-0x30(%ebp)
f01058d0:	eb 0f                	jmp    f01058e1 <debuginfo_eip+0x1db>
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f01058d2:	89 77 10             	mov    %esi,0x10(%edi)
		lline = lfile;
f01058d5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01058d8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		rline = rfile;
f01058db:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01058de:	89 45 d0             	mov    %eax,-0x30(%ebp)
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f01058e1:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f01058e8:	00 
f01058e9:	8b 47 08             	mov    0x8(%edi),%eax
f01058ec:	89 04 24             	mov    %eax,(%esp)
f01058ef:	e8 17 09 00 00       	call   f010620b <strfind>
f01058f4:	2b 47 08             	sub    0x8(%edi),%eax
f01058f7:	89 47 0c             	mov    %eax,0xc(%edi)
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
	// Your code here.

	stab_binsearch(stabs, &lline, &rline, N_SLINE, addr);
f01058fa:	89 74 24 04          	mov    %esi,0x4(%esp)
f01058fe:	c7 04 24 44 00 00 00 	movl   $0x44,(%esp)
f0105905:	8d 4d d0             	lea    -0x30(%ebp),%ecx
f0105908:	8d 55 d4             	lea    -0x2c(%ebp),%edx
f010590b:	8b 75 c4             	mov    -0x3c(%ebp),%esi
f010590e:	89 f0                	mov    %esi,%eax
f0105910:	e8 ef fc ff ff       	call   f0105604 <stab_binsearch>
	if(lline == rline)
f0105915:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105918:	3b 45 d0             	cmp    -0x30(%ebp),%eax
f010591b:	0f 85 c7 00 00 00    	jne    f01059e8 <debuginfo_eip+0x2e2>
	{
		info->eip_line = stabs[lline].n_desc;
f0105921:	8d 04 40             	lea    (%eax,%eax,2),%eax
f0105924:	0f b7 44 86 06       	movzwl 0x6(%esi,%eax,4),%eax
f0105929:	89 47 04             	mov    %eax,0x4(%edi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010592c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010592f:	89 c3                	mov    %eax,%ebx
f0105931:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105934:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0105937:	8d 14 96             	lea    (%esi,%edx,4),%edx
f010593a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010593d:	89 df                	mov    %ebx,%edi
f010593f:	eb 06                	jmp    f0105947 <debuginfo_eip+0x241>
f0105941:	83 e8 01             	sub    $0x1,%eax
f0105944:	83 ea 0c             	sub    $0xc,%edx
f0105947:	89 c6                	mov    %eax,%esi
f0105949:	39 c7                	cmp    %eax,%edi
f010594b:	7f 3c                	jg     f0105989 <debuginfo_eip+0x283>
	       && stabs[lline].n_type != N_SOL
f010594d:	0f b6 4a 04          	movzbl 0x4(%edx),%ecx
f0105951:	80 f9 84             	cmp    $0x84,%cl
f0105954:	75 08                	jne    f010595e <debuginfo_eip+0x258>
f0105956:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105959:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010595c:	eb 11                	jmp    f010596f <debuginfo_eip+0x269>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010595e:	80 f9 64             	cmp    $0x64,%cl
f0105961:	75 de                	jne    f0105941 <debuginfo_eip+0x23b>
f0105963:	83 7a 08 00          	cmpl   $0x0,0x8(%edx)
f0105967:	74 d8                	je     f0105941 <debuginfo_eip+0x23b>
f0105969:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010596c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f010596f:	8d 04 76             	lea    (%esi,%esi,2),%eax
f0105972:	8b 75 c4             	mov    -0x3c(%ebp),%esi
f0105975:	8b 04 86             	mov    (%esi,%eax,4),%eax
f0105978:	8b 55 bc             	mov    -0x44(%ebp),%edx
f010597b:	2b 55 c0             	sub    -0x40(%ebp),%edx
f010597e:	39 d0                	cmp    %edx,%eax
f0105980:	73 0a                	jae    f010598c <debuginfo_eip+0x286>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0105982:	03 45 c0             	add    -0x40(%ebp),%eax
f0105985:	89 07                	mov    %eax,(%edi)
f0105987:	eb 03                	jmp    f010598c <debuginfo_eip+0x286>
f0105989:	8b 7d 0c             	mov    0xc(%ebp),%edi


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f010598c:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010598f:	8b 5d d8             	mov    -0x28(%ebp),%ebx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0105992:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0105997:	39 da                	cmp    %ebx,%edx
f0105999:	7d 59                	jge    f01059f4 <debuginfo_eip+0x2ee>
		for (lline = lfun + 1;
f010599b:	83 c2 01             	add    $0x1,%edx
f010599e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f01059a1:	89 d0                	mov    %edx,%eax
f01059a3:	8d 14 52             	lea    (%edx,%edx,2),%edx
f01059a6:	8b 75 c4             	mov    -0x3c(%ebp),%esi
f01059a9:	8d 14 96             	lea    (%esi,%edx,4),%edx
f01059ac:	eb 04                	jmp    f01059b2 <debuginfo_eip+0x2ac>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
f01059ae:	83 47 14 01          	addl   $0x1,0x14(%edi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01059b2:	39 c3                	cmp    %eax,%ebx
f01059b4:	7e 39                	jle    f01059ef <debuginfo_eip+0x2e9>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01059b6:	0f b6 4a 04          	movzbl 0x4(%edx),%ecx
f01059ba:	83 c0 01             	add    $0x1,%eax
f01059bd:	83 c2 0c             	add    $0xc,%edx
f01059c0:	80 f9 a0             	cmp    $0xa0,%cl
f01059c3:	74 e9                	je     f01059ae <debuginfo_eip+0x2a8>
		     lline++)
			info->eip_fn_narg++;

	return 0;
f01059c5:	b8 00 00 00 00       	mov    $0x0,%eax
f01059ca:	eb 28                	jmp    f01059f4 <debuginfo_eip+0x2ee>
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.

		int check = user_mem_check(curenv, usd, sizeof(struct UserStabData), PTE_U);
		if(check<0)
			return -1;
f01059cc:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01059d1:	eb 21                	jmp    f01059f4 <debuginfo_eip+0x2ee>
		user_mem_assert(curenv, stabstr, (uintptr_t)stabstr_end - (uintptr_t)stabstr, PTE_U);
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f01059d3:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01059d8:	eb 1a                	jmp    f01059f4 <debuginfo_eip+0x2ee>
f01059da:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01059df:	eb 13                	jmp    f01059f4 <debuginfo_eip+0x2ee>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f01059e1:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01059e6:	eb 0c                	jmp    f01059f4 <debuginfo_eip+0x2ee>
	if(lline == rline)
	{
		info->eip_line = stabs[lline].n_desc;
	}
	else
		return -1;
f01059e8:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01059ed:	eb 05                	jmp    f01059f4 <debuginfo_eip+0x2ee>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f01059ef:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01059f4:	83 c4 4c             	add    $0x4c,%esp
f01059f7:	5b                   	pop    %ebx
f01059f8:	5e                   	pop    %esi
f01059f9:	5f                   	pop    %edi
f01059fa:	5d                   	pop    %ebp
f01059fb:	c3                   	ret    
f01059fc:	66 90                	xchg   %ax,%ax
f01059fe:	66 90                	xchg   %ax,%ax

f0105a00 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105a00:	55                   	push   %ebp
f0105a01:	89 e5                	mov    %esp,%ebp
f0105a03:	57                   	push   %edi
f0105a04:	56                   	push   %esi
f0105a05:	53                   	push   %ebx
f0105a06:	83 ec 3c             	sub    $0x3c,%esp
f0105a09:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105a0c:	89 d7                	mov    %edx,%edi
f0105a0e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105a11:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105a14:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105a17:	89 c3                	mov    %eax,%ebx
f0105a19:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0105a1c:	8b 45 10             	mov    0x10(%ebp),%eax
f0105a1f:	8b 75 14             	mov    0x14(%ebp),%esi
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0105a22:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105a27:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105a2a:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105a2d:	39 d9                	cmp    %ebx,%ecx
f0105a2f:	72 05                	jb     f0105a36 <printnum+0x36>
f0105a31:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0105a34:	77 69                	ja     f0105a9f <printnum+0x9f>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105a36:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105a39:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105a3d:	83 ee 01             	sub    $0x1,%esi
f0105a40:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105a44:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105a48:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105a4c:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0105a50:	89 c3                	mov    %eax,%ebx
f0105a52:	89 d6                	mov    %edx,%esi
f0105a54:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105a57:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105a5a:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105a5e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0105a62:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105a65:	89 04 24             	mov    %eax,(%esp)
f0105a68:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105a6b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105a6f:	e8 4c 12 00 00       	call   f0106cc0 <__udivdi3>
f0105a74:	89 d9                	mov    %ebx,%ecx
f0105a76:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105a7a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105a7e:	89 04 24             	mov    %eax,(%esp)
f0105a81:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105a85:	89 fa                	mov    %edi,%edx
f0105a87:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105a8a:	e8 71 ff ff ff       	call   f0105a00 <printnum>
f0105a8f:	eb 1b                	jmp    f0105aac <printnum+0xac>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0105a91:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105a95:	8b 45 18             	mov    0x18(%ebp),%eax
f0105a98:	89 04 24             	mov    %eax,(%esp)
f0105a9b:	ff d3                	call   *%ebx
f0105a9d:	eb 03                	jmp    f0105aa2 <printnum+0xa2>
f0105a9f:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105aa2:	83 ee 01             	sub    $0x1,%esi
f0105aa5:	85 f6                	test   %esi,%esi
f0105aa7:	7f e8                	jg     f0105a91 <printnum+0x91>
f0105aa9:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0105aac:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ab0:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0105ab4:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105ab7:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105aba:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105abe:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105ac2:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105ac5:	89 04 24             	mov    %eax,(%esp)
f0105ac8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105acb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105acf:	e8 1c 13 00 00       	call   f0106df0 <__umoddi3>
f0105ad4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ad8:	0f be 80 3e 86 10 f0 	movsbl -0xfef79c2(%eax),%eax
f0105adf:	89 04 24             	mov    %eax,(%esp)
f0105ae2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105ae5:	ff d0                	call   *%eax
}
f0105ae7:	83 c4 3c             	add    $0x3c,%esp
f0105aea:	5b                   	pop    %ebx
f0105aeb:	5e                   	pop    %esi
f0105aec:	5f                   	pop    %edi
f0105aed:	5d                   	pop    %ebp
f0105aee:	c3                   	ret    

f0105aef <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0105aef:	55                   	push   %ebp
f0105af0:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0105af2:	83 fa 01             	cmp    $0x1,%edx
f0105af5:	7e 0e                	jle    f0105b05 <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0105af7:	8b 10                	mov    (%eax),%edx
f0105af9:	8d 4a 08             	lea    0x8(%edx),%ecx
f0105afc:	89 08                	mov    %ecx,(%eax)
f0105afe:	8b 02                	mov    (%edx),%eax
f0105b00:	8b 52 04             	mov    0x4(%edx),%edx
f0105b03:	eb 22                	jmp    f0105b27 <getuint+0x38>
	else if (lflag)
f0105b05:	85 d2                	test   %edx,%edx
f0105b07:	74 10                	je     f0105b19 <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0105b09:	8b 10                	mov    (%eax),%edx
f0105b0b:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105b0e:	89 08                	mov    %ecx,(%eax)
f0105b10:	8b 02                	mov    (%edx),%eax
f0105b12:	ba 00 00 00 00       	mov    $0x0,%edx
f0105b17:	eb 0e                	jmp    f0105b27 <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0105b19:	8b 10                	mov    (%eax),%edx
f0105b1b:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105b1e:	89 08                	mov    %ecx,(%eax)
f0105b20:	8b 02                	mov    (%edx),%eax
f0105b22:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0105b27:	5d                   	pop    %ebp
f0105b28:	c3                   	ret    

f0105b29 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0105b29:	55                   	push   %ebp
f0105b2a:	89 e5                	mov    %esp,%ebp
f0105b2c:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0105b2f:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0105b33:	8b 10                	mov    (%eax),%edx
f0105b35:	3b 50 04             	cmp    0x4(%eax),%edx
f0105b38:	73 0a                	jae    f0105b44 <sprintputch+0x1b>
		*b->buf++ = ch;
f0105b3a:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105b3d:	89 08                	mov    %ecx,(%eax)
f0105b3f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b42:	88 02                	mov    %al,(%edx)
}
f0105b44:	5d                   	pop    %ebp
f0105b45:	c3                   	ret    

f0105b46 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0105b46:	55                   	push   %ebp
f0105b47:	89 e5                	mov    %esp,%ebp
f0105b49:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105b4c:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0105b4f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105b53:	8b 45 10             	mov    0x10(%ebp),%eax
f0105b56:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105b5a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105b5d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b61:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b64:	89 04 24             	mov    %eax,(%esp)
f0105b67:	e8 02 00 00 00       	call   f0105b6e <vprintfmt>
	va_end(ap);
}
f0105b6c:	c9                   	leave  
f0105b6d:	c3                   	ret    

f0105b6e <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0105b6e:	55                   	push   %ebp
f0105b6f:	89 e5                	mov    %esp,%ebp
f0105b71:	57                   	push   %edi
f0105b72:	56                   	push   %esi
f0105b73:	53                   	push   %ebx
f0105b74:	83 ec 3c             	sub    $0x3c,%esp
f0105b77:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105b7a:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105b7d:	eb 14                	jmp    f0105b93 <vprintfmt+0x25>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0105b7f:	85 c0                	test   %eax,%eax
f0105b81:	0f 84 b3 03 00 00    	je     f0105f3a <vprintfmt+0x3cc>
				return;
			putch(ch, putdat);
f0105b87:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b8b:	89 04 24             	mov    %eax,(%esp)
f0105b8e:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0105b91:	89 f3                	mov    %esi,%ebx
f0105b93:	8d 73 01             	lea    0x1(%ebx),%esi
f0105b96:	0f b6 03             	movzbl (%ebx),%eax
f0105b99:	83 f8 25             	cmp    $0x25,%eax
f0105b9c:	75 e1                	jne    f0105b7f <vprintfmt+0x11>
f0105b9e:	c6 45 d8 20          	movb   $0x20,-0x28(%ebp)
f0105ba2:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0105ba9:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0105bb0:	c7 45 dc ff ff ff ff 	movl   $0xffffffff,-0x24(%ebp)
f0105bb7:	ba 00 00 00 00       	mov    $0x0,%edx
f0105bbc:	eb 1d                	jmp    f0105bdb <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105bbe:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0105bc0:	c6 45 d8 2d          	movb   $0x2d,-0x28(%ebp)
f0105bc4:	eb 15                	jmp    f0105bdb <vprintfmt+0x6d>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105bc6:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105bc8:	c6 45 d8 30          	movb   $0x30,-0x28(%ebp)
f0105bcc:	eb 0d                	jmp    f0105bdb <vprintfmt+0x6d>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0105bce:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105bd1:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105bd4:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105bdb:	8d 5e 01             	lea    0x1(%esi),%ebx
f0105bde:	0f b6 0e             	movzbl (%esi),%ecx
f0105be1:	0f b6 c1             	movzbl %cl,%eax
f0105be4:	83 e9 23             	sub    $0x23,%ecx
f0105be7:	80 f9 55             	cmp    $0x55,%cl
f0105bea:	0f 87 2a 03 00 00    	ja     f0105f1a <vprintfmt+0x3ac>
f0105bf0:	0f b6 c9             	movzbl %cl,%ecx
f0105bf3:	ff 24 8d 00 87 10 f0 	jmp    *-0xfef7900(,%ecx,4)
f0105bfa:	89 de                	mov    %ebx,%esi
f0105bfc:	b9 00 00 00 00       	mov    $0x0,%ecx
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0105c01:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0105c04:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0105c08:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105c0b:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0105c0e:	83 fb 09             	cmp    $0x9,%ebx
f0105c11:	77 36                	ja     f0105c49 <vprintfmt+0xdb>
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0105c13:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
				ch = *fmt;
				if (ch < '0' || ch > '9')
					break;
			}
f0105c16:	eb e9                	jmp    f0105c01 <vprintfmt+0x93>
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105c18:	8b 45 14             	mov    0x14(%ebp),%eax
f0105c1b:	8d 48 04             	lea    0x4(%eax),%ecx
f0105c1e:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0105c21:	8b 00                	mov    (%eax),%eax
f0105c23:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105c26:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105c28:	eb 22                	jmp    f0105c4c <vprintfmt+0xde>
f0105c2a:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105c2d:	85 c9                	test   %ecx,%ecx
f0105c2f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c34:	0f 49 c1             	cmovns %ecx,%eax
f0105c37:	89 45 dc             	mov    %eax,-0x24(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105c3a:	89 de                	mov    %ebx,%esi
f0105c3c:	eb 9d                	jmp    f0105bdb <vprintfmt+0x6d>
f0105c3e:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0105c40:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
			goto reswitch;
f0105c47:	eb 92                	jmp    f0105bdb <vprintfmt+0x6d>
f0105c49:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		process_precision:
			if (width < 0)
f0105c4c:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105c50:	79 89                	jns    f0105bdb <vprintfmt+0x6d>
f0105c52:	e9 77 ff ff ff       	jmp    f0105bce <vprintfmt+0x60>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105c57:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105c5a:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0105c5c:	e9 7a ff ff ff       	jmp    f0105bdb <vprintfmt+0x6d>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0105c61:	8b 45 14             	mov    0x14(%ebp),%eax
f0105c64:	8d 50 04             	lea    0x4(%eax),%edx
f0105c67:	89 55 14             	mov    %edx,0x14(%ebp)
f0105c6a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105c6e:	8b 00                	mov    (%eax),%eax
f0105c70:	89 04 24             	mov    %eax,(%esp)
f0105c73:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105c76:	e9 18 ff ff ff       	jmp    f0105b93 <vprintfmt+0x25>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0105c7b:	8b 45 14             	mov    0x14(%ebp),%eax
f0105c7e:	8d 50 04             	lea    0x4(%eax),%edx
f0105c81:	89 55 14             	mov    %edx,0x14(%ebp)
f0105c84:	8b 00                	mov    (%eax),%eax
f0105c86:	99                   	cltd   
f0105c87:	31 d0                	xor    %edx,%eax
f0105c89:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0105c8b:	83 f8 09             	cmp    $0x9,%eax
f0105c8e:	7f 0b                	jg     f0105c9b <vprintfmt+0x12d>
f0105c90:	8b 14 85 60 88 10 f0 	mov    -0xfef77a0(,%eax,4),%edx
f0105c97:	85 d2                	test   %edx,%edx
f0105c99:	75 20                	jne    f0105cbb <vprintfmt+0x14d>
				printfmt(putch, putdat, "error %d", err);
f0105c9b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c9f:	c7 44 24 08 56 86 10 	movl   $0xf0108656,0x8(%esp)
f0105ca6:	f0 
f0105ca7:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105cab:	8b 45 08             	mov    0x8(%ebp),%eax
f0105cae:	89 04 24             	mov    %eax,(%esp)
f0105cb1:	e8 90 fe ff ff       	call   f0105b46 <printfmt>
f0105cb6:	e9 d8 fe ff ff       	jmp    f0105b93 <vprintfmt+0x25>
			else
				printfmt(putch, putdat, "%s", p);
f0105cbb:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105cbf:	c7 44 24 08 19 7e 10 	movl   $0xf0107e19,0x8(%esp)
f0105cc6:	f0 
f0105cc7:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ccb:	8b 45 08             	mov    0x8(%ebp),%eax
f0105cce:	89 04 24             	mov    %eax,(%esp)
f0105cd1:	e8 70 fe ff ff       	call   f0105b46 <printfmt>
f0105cd6:	e9 b8 fe ff ff       	jmp    f0105b93 <vprintfmt+0x25>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105cdb:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105cde:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0105ce1:	89 45 d0             	mov    %eax,-0x30(%ebp)
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0105ce4:	8b 45 14             	mov    0x14(%ebp),%eax
f0105ce7:	8d 50 04             	lea    0x4(%eax),%edx
f0105cea:	89 55 14             	mov    %edx,0x14(%ebp)
f0105ced:	8b 30                	mov    (%eax),%esi
				p = "(null)";
f0105cef:	85 f6                	test   %esi,%esi
f0105cf1:	b8 4f 86 10 f0       	mov    $0xf010864f,%eax
f0105cf6:	0f 44 f0             	cmove  %eax,%esi
			if (width > 0 && padc != '-')
f0105cf9:	80 7d d8 2d          	cmpb   $0x2d,-0x28(%ebp)
f0105cfd:	0f 84 97 00 00 00    	je     f0105d9a <vprintfmt+0x22c>
f0105d03:	83 7d d0 00          	cmpl   $0x0,-0x30(%ebp)
f0105d07:	0f 8e 9b 00 00 00    	jle    f0105da8 <vprintfmt+0x23a>
				for (width -= strnlen(p, precision); width > 0; width--)
f0105d0d:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105d11:	89 34 24             	mov    %esi,(%esp)
f0105d14:	e8 9f 03 00 00       	call   f01060b8 <strnlen>
f0105d19:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0105d1c:	29 c2                	sub    %eax,%edx
f0105d1e:	89 55 d0             	mov    %edx,-0x30(%ebp)
					putch(padc, putdat);
f0105d21:	0f be 45 d8          	movsbl -0x28(%ebp),%eax
f0105d25:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105d28:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105d2b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105d2e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105d31:	89 d3                	mov    %edx,%ebx
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105d33:	eb 0f                	jmp    f0105d44 <vprintfmt+0x1d6>
					putch(padc, putdat);
f0105d35:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105d39:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0105d3c:	89 04 24             	mov    %eax,(%esp)
f0105d3f:	ff d6                	call   *%esi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105d41:	83 eb 01             	sub    $0x1,%ebx
f0105d44:	85 db                	test   %ebx,%ebx
f0105d46:	7f ed                	jg     f0105d35 <vprintfmt+0x1c7>
f0105d48:	8b 75 d8             	mov    -0x28(%ebp),%esi
f0105d4b:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0105d4e:	85 d2                	test   %edx,%edx
f0105d50:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d55:	0f 49 c2             	cmovns %edx,%eax
f0105d58:	29 c2                	sub    %eax,%edx
f0105d5a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0105d5d:	89 d7                	mov    %edx,%edi
f0105d5f:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0105d62:	eb 50                	jmp    f0105db4 <vprintfmt+0x246>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0105d64:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f0105d68:	74 1e                	je     f0105d88 <vprintfmt+0x21a>
f0105d6a:	0f be d2             	movsbl %dl,%edx
f0105d6d:	83 ea 20             	sub    $0x20,%edx
f0105d70:	83 fa 5e             	cmp    $0x5e,%edx
f0105d73:	76 13                	jbe    f0105d88 <vprintfmt+0x21a>
					putch('?', putdat);
f0105d75:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105d78:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105d7c:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0105d83:	ff 55 08             	call   *0x8(%ebp)
f0105d86:	eb 0d                	jmp    f0105d95 <vprintfmt+0x227>
				else
					putch(ch, putdat);
f0105d88:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d8b:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105d8f:	89 04 24             	mov    %eax,(%esp)
f0105d92:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105d95:	83 ef 01             	sub    $0x1,%edi
f0105d98:	eb 1a                	jmp    f0105db4 <vprintfmt+0x246>
f0105d9a:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0105d9d:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0105da0:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105da3:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0105da6:	eb 0c                	jmp    f0105db4 <vprintfmt+0x246>
f0105da8:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0105dab:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0105dae:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105db1:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0105db4:	83 c6 01             	add    $0x1,%esi
f0105db7:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105dbb:	0f be c2             	movsbl %dl,%eax
f0105dbe:	85 c0                	test   %eax,%eax
f0105dc0:	74 27                	je     f0105de9 <vprintfmt+0x27b>
f0105dc2:	85 db                	test   %ebx,%ebx
f0105dc4:	78 9e                	js     f0105d64 <vprintfmt+0x1f6>
f0105dc6:	83 eb 01             	sub    $0x1,%ebx
f0105dc9:	79 99                	jns    f0105d64 <vprintfmt+0x1f6>
f0105dcb:	89 f8                	mov    %edi,%eax
f0105dcd:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105dd0:	8b 75 08             	mov    0x8(%ebp),%esi
f0105dd3:	89 c3                	mov    %eax,%ebx
f0105dd5:	eb 1a                	jmp    f0105df1 <vprintfmt+0x283>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105dd7:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ddb:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105de2:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105de4:	83 eb 01             	sub    $0x1,%ebx
f0105de7:	eb 08                	jmp    f0105df1 <vprintfmt+0x283>
f0105de9:	89 fb                	mov    %edi,%ebx
f0105deb:	8b 75 08             	mov    0x8(%ebp),%esi
f0105dee:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105df1:	85 db                	test   %ebx,%ebx
f0105df3:	7f e2                	jg     f0105dd7 <vprintfmt+0x269>
f0105df5:	89 75 08             	mov    %esi,0x8(%ebp)
f0105df8:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105dfb:	e9 93 fd ff ff       	jmp    f0105b93 <vprintfmt+0x25>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0105e00:	83 fa 01             	cmp    $0x1,%edx
f0105e03:	7e 16                	jle    f0105e1b <vprintfmt+0x2ad>
		return va_arg(*ap, long long);
f0105e05:	8b 45 14             	mov    0x14(%ebp),%eax
f0105e08:	8d 50 08             	lea    0x8(%eax),%edx
f0105e0b:	89 55 14             	mov    %edx,0x14(%ebp)
f0105e0e:	8b 50 04             	mov    0x4(%eax),%edx
f0105e11:	8b 00                	mov    (%eax),%eax
f0105e13:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105e16:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0105e19:	eb 32                	jmp    f0105e4d <vprintfmt+0x2df>
	else if (lflag)
f0105e1b:	85 d2                	test   %edx,%edx
f0105e1d:	74 18                	je     f0105e37 <vprintfmt+0x2c9>
		return va_arg(*ap, long);
f0105e1f:	8b 45 14             	mov    0x14(%ebp),%eax
f0105e22:	8d 50 04             	lea    0x4(%eax),%edx
f0105e25:	89 55 14             	mov    %edx,0x14(%ebp)
f0105e28:	8b 30                	mov    (%eax),%esi
f0105e2a:	89 75 e0             	mov    %esi,-0x20(%ebp)
f0105e2d:	89 f0                	mov    %esi,%eax
f0105e2f:	c1 f8 1f             	sar    $0x1f,%eax
f0105e32:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105e35:	eb 16                	jmp    f0105e4d <vprintfmt+0x2df>
	else
		return va_arg(*ap, int);
f0105e37:	8b 45 14             	mov    0x14(%ebp),%eax
f0105e3a:	8d 50 04             	lea    0x4(%eax),%edx
f0105e3d:	89 55 14             	mov    %edx,0x14(%ebp)
f0105e40:	8b 30                	mov    (%eax),%esi
f0105e42:	89 75 e0             	mov    %esi,-0x20(%ebp)
f0105e45:	89 f0                	mov    %esi,%eax
f0105e47:	c1 f8 1f             	sar    $0x1f,%eax
f0105e4a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105e4d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105e50:	8b 55 e4             	mov    -0x1c(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105e53:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105e58:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105e5c:	0f 89 80 00 00 00    	jns    f0105ee2 <vprintfmt+0x374>
				putch('-', putdat);
f0105e62:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105e66:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105e6d:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0105e70:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105e73:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0105e76:	f7 d8                	neg    %eax
f0105e78:	83 d2 00             	adc    $0x0,%edx
f0105e7b:	f7 da                	neg    %edx
			}
			base = 10;
f0105e7d:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0105e82:	eb 5e                	jmp    f0105ee2 <vprintfmt+0x374>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0105e84:	8d 45 14             	lea    0x14(%ebp),%eax
f0105e87:	e8 63 fc ff ff       	call   f0105aef <getuint>
			base = 10;
f0105e8c:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0105e91:	eb 4f                	jmp    f0105ee2 <vprintfmt+0x374>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			num = getuint(&ap, lflag);
f0105e93:	8d 45 14             	lea    0x14(%ebp),%eax
f0105e96:	e8 54 fc ff ff       	call   f0105aef <getuint>
			base = 8;
f0105e9b:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0105ea0:	eb 40                	jmp    f0105ee2 <vprintfmt+0x374>

		// pointer
		case 'p':
			putch('0', putdat);
f0105ea2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ea6:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105ead:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0105eb0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105eb4:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105ebb:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f0105ebe:	8b 45 14             	mov    0x14(%ebp),%eax
f0105ec1:	8d 50 04             	lea    0x4(%eax),%edx
f0105ec4:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0105ec7:	8b 00                	mov    (%eax),%eax
f0105ec9:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f0105ece:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0105ed3:	eb 0d                	jmp    f0105ee2 <vprintfmt+0x374>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0105ed5:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ed8:	e8 12 fc ff ff       	call   f0105aef <getuint>
			base = 16;
f0105edd:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105ee2:	0f be 75 d8          	movsbl -0x28(%ebp),%esi
f0105ee6:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105eea:	8b 75 dc             	mov    -0x24(%ebp),%esi
f0105eed:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105ef1:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105ef5:	89 04 24             	mov    %eax,(%esp)
f0105ef8:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105efc:	89 fa                	mov    %edi,%edx
f0105efe:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f01:	e8 fa fa ff ff       	call   f0105a00 <printnum>
			break;
f0105f06:	e9 88 fc ff ff       	jmp    f0105b93 <vprintfmt+0x25>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105f0b:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105f0f:	89 04 24             	mov    %eax,(%esp)
f0105f12:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105f15:	e9 79 fc ff ff       	jmp    f0105b93 <vprintfmt+0x25>

		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105f1a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105f1e:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105f25:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105f28:	89 f3                	mov    %esi,%ebx
f0105f2a:	eb 03                	jmp    f0105f2f <vprintfmt+0x3c1>
f0105f2c:	83 eb 01             	sub    $0x1,%ebx
f0105f2f:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105f33:	75 f7                	jne    f0105f2c <vprintfmt+0x3be>
f0105f35:	e9 59 fc ff ff       	jmp    f0105b93 <vprintfmt+0x25>
				/* do nothing */;
			break;
		}
	}
}
f0105f3a:	83 c4 3c             	add    $0x3c,%esp
f0105f3d:	5b                   	pop    %ebx
f0105f3e:	5e                   	pop    %esi
f0105f3f:	5f                   	pop    %edi
f0105f40:	5d                   	pop    %ebp
f0105f41:	c3                   	ret    

f0105f42 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105f42:	55                   	push   %ebp
f0105f43:	89 e5                	mov    %esp,%ebp
f0105f45:	83 ec 28             	sub    $0x28,%esp
f0105f48:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f4b:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105f4e:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105f51:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0105f55:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105f58:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105f5f:	85 c0                	test   %eax,%eax
f0105f61:	74 30                	je     f0105f93 <vsnprintf+0x51>
f0105f63:	85 d2                	test   %edx,%edx
f0105f65:	7e 2c                	jle    f0105f93 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0105f67:	8b 45 14             	mov    0x14(%ebp),%eax
f0105f6a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105f6e:	8b 45 10             	mov    0x10(%ebp),%eax
f0105f71:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105f75:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105f78:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f7c:	c7 04 24 29 5b 10 f0 	movl   $0xf0105b29,(%esp)
f0105f83:	e8 e6 fb ff ff       	call   f0105b6e <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105f88:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105f8b:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105f8e:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105f91:	eb 05                	jmp    f0105f98 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105f93:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105f98:	c9                   	leave  
f0105f99:	c3                   	ret    

f0105f9a <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105f9a:	55                   	push   %ebp
f0105f9b:	89 e5                	mov    %esp,%ebp
f0105f9d:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105fa0:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105fa3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105fa7:	8b 45 10             	mov    0x10(%ebp),%eax
f0105faa:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105fae:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105fb1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fb5:	8b 45 08             	mov    0x8(%ebp),%eax
f0105fb8:	89 04 24             	mov    %eax,(%esp)
f0105fbb:	e8 82 ff ff ff       	call   f0105f42 <vsnprintf>
	va_end(ap);

	return rc;
}
f0105fc0:	c9                   	leave  
f0105fc1:	c3                   	ret    
f0105fc2:	66 90                	xchg   %ax,%ax
f0105fc4:	66 90                	xchg   %ax,%ax
f0105fc6:	66 90                	xchg   %ax,%ax
f0105fc8:	66 90                	xchg   %ax,%ax
f0105fca:	66 90                	xchg   %ax,%ax
f0105fcc:	66 90                	xchg   %ax,%ax
f0105fce:	66 90                	xchg   %ax,%ax

f0105fd0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105fd0:	55                   	push   %ebp
f0105fd1:	89 e5                	mov    %esp,%ebp
f0105fd3:	57                   	push   %edi
f0105fd4:	56                   	push   %esi
f0105fd5:	53                   	push   %ebx
f0105fd6:	83 ec 1c             	sub    $0x1c,%esp
f0105fd9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0105fdc:	85 c0                	test   %eax,%eax
f0105fde:	74 10                	je     f0105ff0 <readline+0x20>
		cprintf("%s", prompt);
f0105fe0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fe4:	c7 04 24 19 7e 10 f0 	movl   $0xf0107e19,(%esp)
f0105feb:	e8 47 df ff ff       	call   f0103f37 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105ff0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105ff7:	e8 ef a7 ff ff       	call   f01007eb <iscons>
f0105ffc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0105ffe:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0106003:	e8 d2 a7 ff ff       	call   f01007da <getchar>
f0106008:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010600a:	85 c0                	test   %eax,%eax
f010600c:	79 17                	jns    f0106025 <readline+0x55>
			cprintf("read error: %e\n", c);
f010600e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106012:	c7 04 24 88 88 10 f0 	movl   $0xf0108888,(%esp)
f0106019:	e8 19 df ff ff       	call   f0103f37 <cprintf>
			return NULL;
f010601e:	b8 00 00 00 00       	mov    $0x0,%eax
f0106023:	eb 6d                	jmp    f0106092 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0106025:	83 f8 7f             	cmp    $0x7f,%eax
f0106028:	74 05                	je     f010602f <readline+0x5f>
f010602a:	83 f8 08             	cmp    $0x8,%eax
f010602d:	75 19                	jne    f0106048 <readline+0x78>
f010602f:	85 f6                	test   %esi,%esi
f0106031:	7e 15                	jle    f0106048 <readline+0x78>
			if (echoing)
f0106033:	85 ff                	test   %edi,%edi
f0106035:	74 0c                	je     f0106043 <readline+0x73>
				cputchar('\b');
f0106037:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010603e:	e8 87 a7 ff ff       	call   f01007ca <cputchar>
			i--;
f0106043:	83 ee 01             	sub    $0x1,%esi
f0106046:	eb bb                	jmp    f0106003 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0106048:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010604e:	7f 1c                	jg     f010606c <readline+0x9c>
f0106050:	83 fb 1f             	cmp    $0x1f,%ebx
f0106053:	7e 17                	jle    f010606c <readline+0x9c>
			if (echoing)
f0106055:	85 ff                	test   %edi,%edi
f0106057:	74 08                	je     f0106061 <readline+0x91>
				cputchar(c);
f0106059:	89 1c 24             	mov    %ebx,(%esp)
f010605c:	e8 69 a7 ff ff       	call   f01007ca <cputchar>
			buf[i++] = c;
f0106061:	88 9e 80 1a 23 f0    	mov    %bl,-0xfdce580(%esi)
f0106067:	8d 76 01             	lea    0x1(%esi),%esi
f010606a:	eb 97                	jmp    f0106003 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010606c:	83 fb 0d             	cmp    $0xd,%ebx
f010606f:	74 05                	je     f0106076 <readline+0xa6>
f0106071:	83 fb 0a             	cmp    $0xa,%ebx
f0106074:	75 8d                	jne    f0106003 <readline+0x33>
			if (echoing)
f0106076:	85 ff                	test   %edi,%edi
f0106078:	74 0c                	je     f0106086 <readline+0xb6>
				cputchar('\n');
f010607a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0106081:	e8 44 a7 ff ff       	call   f01007ca <cputchar>
			buf[i] = 0;
f0106086:	c6 86 80 1a 23 f0 00 	movb   $0x0,-0xfdce580(%esi)
			return buf;
f010608d:	b8 80 1a 23 f0       	mov    $0xf0231a80,%eax
		}
	}
}
f0106092:	83 c4 1c             	add    $0x1c,%esp
f0106095:	5b                   	pop    %ebx
f0106096:	5e                   	pop    %esi
f0106097:	5f                   	pop    %edi
f0106098:	5d                   	pop    %ebp
f0106099:	c3                   	ret    
f010609a:	66 90                	xchg   %ax,%ax
f010609c:	66 90                	xchg   %ax,%ax
f010609e:	66 90                	xchg   %ax,%ax

f01060a0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01060a0:	55                   	push   %ebp
f01060a1:	89 e5                	mov    %esp,%ebp
f01060a3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01060a6:	b8 00 00 00 00       	mov    $0x0,%eax
f01060ab:	eb 03                	jmp    f01060b0 <strlen+0x10>
		n++;
f01060ad:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01060b0:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01060b4:	75 f7                	jne    f01060ad <strlen+0xd>
		n++;
	return n;
}
f01060b6:	5d                   	pop    %ebp
f01060b7:	c3                   	ret    

f01060b8 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01060b8:	55                   	push   %ebp
f01060b9:	89 e5                	mov    %esp,%ebp
f01060bb:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01060be:	8b 55 0c             	mov    0xc(%ebp),%edx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01060c1:	b8 00 00 00 00       	mov    $0x0,%eax
f01060c6:	eb 03                	jmp    f01060cb <strnlen+0x13>
		n++;
f01060c8:	83 c0 01             	add    $0x1,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01060cb:	39 d0                	cmp    %edx,%eax
f01060cd:	74 06                	je     f01060d5 <strnlen+0x1d>
f01060cf:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f01060d3:	75 f3                	jne    f01060c8 <strnlen+0x10>
		n++;
	return n;
}
f01060d5:	5d                   	pop    %ebp
f01060d6:	c3                   	ret    

f01060d7 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01060d7:	55                   	push   %ebp
f01060d8:	89 e5                	mov    %esp,%ebp
f01060da:	53                   	push   %ebx
f01060db:	8b 45 08             	mov    0x8(%ebp),%eax
f01060de:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01060e1:	89 c2                	mov    %eax,%edx
f01060e3:	83 c2 01             	add    $0x1,%edx
f01060e6:	83 c1 01             	add    $0x1,%ecx
f01060e9:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01060ed:	88 5a ff             	mov    %bl,-0x1(%edx)
f01060f0:	84 db                	test   %bl,%bl
f01060f2:	75 ef                	jne    f01060e3 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01060f4:	5b                   	pop    %ebx
f01060f5:	5d                   	pop    %ebp
f01060f6:	c3                   	ret    

f01060f7 <strcat>:

char *
strcat(char *dst, const char *src)
{
f01060f7:	55                   	push   %ebp
f01060f8:	89 e5                	mov    %esp,%ebp
f01060fa:	53                   	push   %ebx
f01060fb:	83 ec 08             	sub    $0x8,%esp
f01060fe:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0106101:	89 1c 24             	mov    %ebx,(%esp)
f0106104:	e8 97 ff ff ff       	call   f01060a0 <strlen>
	strcpy(dst + len, src);
f0106109:	8b 55 0c             	mov    0xc(%ebp),%edx
f010610c:	89 54 24 04          	mov    %edx,0x4(%esp)
f0106110:	01 d8                	add    %ebx,%eax
f0106112:	89 04 24             	mov    %eax,(%esp)
f0106115:	e8 bd ff ff ff       	call   f01060d7 <strcpy>
	return dst;
}
f010611a:	89 d8                	mov    %ebx,%eax
f010611c:	83 c4 08             	add    $0x8,%esp
f010611f:	5b                   	pop    %ebx
f0106120:	5d                   	pop    %ebp
f0106121:	c3                   	ret    

f0106122 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0106122:	55                   	push   %ebp
f0106123:	89 e5                	mov    %esp,%ebp
f0106125:	56                   	push   %esi
f0106126:	53                   	push   %ebx
f0106127:	8b 75 08             	mov    0x8(%ebp),%esi
f010612a:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f010612d:	89 f3                	mov    %esi,%ebx
f010612f:	03 5d 10             	add    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0106132:	89 f2                	mov    %esi,%edx
f0106134:	eb 0f                	jmp    f0106145 <strncpy+0x23>
		*dst++ = *src;
f0106136:	83 c2 01             	add    $0x1,%edx
f0106139:	0f b6 01             	movzbl (%ecx),%eax
f010613c:	88 42 ff             	mov    %al,-0x1(%edx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f010613f:	80 39 01             	cmpb   $0x1,(%ecx)
f0106142:	83 d9 ff             	sbb    $0xffffffff,%ecx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0106145:	39 da                	cmp    %ebx,%edx
f0106147:	75 ed                	jne    f0106136 <strncpy+0x14>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0106149:	89 f0                	mov    %esi,%eax
f010614b:	5b                   	pop    %ebx
f010614c:	5e                   	pop    %esi
f010614d:	5d                   	pop    %ebp
f010614e:	c3                   	ret    

f010614f <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010614f:	55                   	push   %ebp
f0106150:	89 e5                	mov    %esp,%ebp
f0106152:	56                   	push   %esi
f0106153:	53                   	push   %ebx
f0106154:	8b 75 08             	mov    0x8(%ebp),%esi
f0106157:	8b 55 0c             	mov    0xc(%ebp),%edx
f010615a:	8b 4d 10             	mov    0x10(%ebp),%ecx
f010615d:	89 f0                	mov    %esi,%eax
f010615f:	8d 5c 0e ff          	lea    -0x1(%esi,%ecx,1),%ebx
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0106163:	85 c9                	test   %ecx,%ecx
f0106165:	75 0b                	jne    f0106172 <strlcpy+0x23>
f0106167:	eb 1d                	jmp    f0106186 <strlcpy+0x37>
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f0106169:	83 c0 01             	add    $0x1,%eax
f010616c:	83 c2 01             	add    $0x1,%edx
f010616f:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0106172:	39 d8                	cmp    %ebx,%eax
f0106174:	74 0b                	je     f0106181 <strlcpy+0x32>
f0106176:	0f b6 0a             	movzbl (%edx),%ecx
f0106179:	84 c9                	test   %cl,%cl
f010617b:	75 ec                	jne    f0106169 <strlcpy+0x1a>
f010617d:	89 c2                	mov    %eax,%edx
f010617f:	eb 02                	jmp    f0106183 <strlcpy+0x34>
f0106181:	89 c2                	mov    %eax,%edx
			*dst++ = *src++;
		*dst = '\0';
f0106183:	c6 02 00             	movb   $0x0,(%edx)
	}
	return dst - dst_in;
f0106186:	29 f0                	sub    %esi,%eax
}
f0106188:	5b                   	pop    %ebx
f0106189:	5e                   	pop    %esi
f010618a:	5d                   	pop    %ebp
f010618b:	c3                   	ret    

f010618c <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010618c:	55                   	push   %ebp
f010618d:	89 e5                	mov    %esp,%ebp
f010618f:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0106192:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0106195:	eb 06                	jmp    f010619d <strcmp+0x11>
		p++, q++;
f0106197:	83 c1 01             	add    $0x1,%ecx
f010619a:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010619d:	0f b6 01             	movzbl (%ecx),%eax
f01061a0:	84 c0                	test   %al,%al
f01061a2:	74 04                	je     f01061a8 <strcmp+0x1c>
f01061a4:	3a 02                	cmp    (%edx),%al
f01061a6:	74 ef                	je     f0106197 <strcmp+0xb>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01061a8:	0f b6 c0             	movzbl %al,%eax
f01061ab:	0f b6 12             	movzbl (%edx),%edx
f01061ae:	29 d0                	sub    %edx,%eax
}
f01061b0:	5d                   	pop    %ebp
f01061b1:	c3                   	ret    

f01061b2 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01061b2:	55                   	push   %ebp
f01061b3:	89 e5                	mov    %esp,%ebp
f01061b5:	53                   	push   %ebx
f01061b6:	8b 45 08             	mov    0x8(%ebp),%eax
f01061b9:	8b 55 0c             	mov    0xc(%ebp),%edx
f01061bc:	89 c3                	mov    %eax,%ebx
f01061be:	03 5d 10             	add    0x10(%ebp),%ebx
	while (n > 0 && *p && *p == *q)
f01061c1:	eb 06                	jmp    f01061c9 <strncmp+0x17>
		n--, p++, q++;
f01061c3:	83 c0 01             	add    $0x1,%eax
f01061c6:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01061c9:	39 d8                	cmp    %ebx,%eax
f01061cb:	74 15                	je     f01061e2 <strncmp+0x30>
f01061cd:	0f b6 08             	movzbl (%eax),%ecx
f01061d0:	84 c9                	test   %cl,%cl
f01061d2:	74 04                	je     f01061d8 <strncmp+0x26>
f01061d4:	3a 0a                	cmp    (%edx),%cl
f01061d6:	74 eb                	je     f01061c3 <strncmp+0x11>
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01061d8:	0f b6 00             	movzbl (%eax),%eax
f01061db:	0f b6 12             	movzbl (%edx),%edx
f01061de:	29 d0                	sub    %edx,%eax
f01061e0:	eb 05                	jmp    f01061e7 <strncmp+0x35>
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
f01061e2:	b8 00 00 00 00       	mov    $0x0,%eax
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
}
f01061e7:	5b                   	pop    %ebx
f01061e8:	5d                   	pop    %ebp
f01061e9:	c3                   	ret    

f01061ea <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01061ea:	55                   	push   %ebp
f01061eb:	89 e5                	mov    %esp,%ebp
f01061ed:	8b 45 08             	mov    0x8(%ebp),%eax
f01061f0:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f01061f4:	eb 07                	jmp    f01061fd <strchr+0x13>
		if (*s == c)
f01061f6:	38 ca                	cmp    %cl,%dl
f01061f8:	74 0f                	je     f0106209 <strchr+0x1f>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01061fa:	83 c0 01             	add    $0x1,%eax
f01061fd:	0f b6 10             	movzbl (%eax),%edx
f0106200:	84 d2                	test   %dl,%dl
f0106202:	75 f2                	jne    f01061f6 <strchr+0xc>
		if (*s == c)
			return (char *) s;
	return 0;
f0106204:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106209:	5d                   	pop    %ebp
f010620a:	c3                   	ret    

f010620b <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010620b:	55                   	push   %ebp
f010620c:	89 e5                	mov    %esp,%ebp
f010620e:	8b 45 08             	mov    0x8(%ebp),%eax
f0106211:	0f b6 4d 0c          	movzbl 0xc(%ebp),%ecx
	for (; *s; s++)
f0106215:	eb 07                	jmp    f010621e <strfind+0x13>
		if (*s == c)
f0106217:	38 ca                	cmp    %cl,%dl
f0106219:	74 0a                	je     f0106225 <strfind+0x1a>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010621b:	83 c0 01             	add    $0x1,%eax
f010621e:	0f b6 10             	movzbl (%eax),%edx
f0106221:	84 d2                	test   %dl,%dl
f0106223:	75 f2                	jne    f0106217 <strfind+0xc>
		if (*s == c)
			break;
	return (char *) s;
}
f0106225:	5d                   	pop    %ebp
f0106226:	c3                   	ret    

f0106227 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0106227:	55                   	push   %ebp
f0106228:	89 e5                	mov    %esp,%ebp
f010622a:	57                   	push   %edi
f010622b:	56                   	push   %esi
f010622c:	53                   	push   %ebx
f010622d:	8b 7d 08             	mov    0x8(%ebp),%edi
f0106230:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0106233:	85 c9                	test   %ecx,%ecx
f0106235:	74 36                	je     f010626d <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0106237:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010623d:	75 28                	jne    f0106267 <memset+0x40>
f010623f:	f6 c1 03             	test   $0x3,%cl
f0106242:	75 23                	jne    f0106267 <memset+0x40>
		c &= 0xFF;
f0106244:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0106248:	89 d3                	mov    %edx,%ebx
f010624a:	c1 e3 08             	shl    $0x8,%ebx
f010624d:	89 d6                	mov    %edx,%esi
f010624f:	c1 e6 18             	shl    $0x18,%esi
f0106252:	89 d0                	mov    %edx,%eax
f0106254:	c1 e0 10             	shl    $0x10,%eax
f0106257:	09 f0                	or     %esi,%eax
f0106259:	09 c2                	or     %eax,%edx
f010625b:	89 d0                	mov    %edx,%eax
f010625d:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f010625f:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0106262:	fc                   	cld    
f0106263:	f3 ab                	rep stos %eax,%es:(%edi)
f0106265:	eb 06                	jmp    f010626d <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0106267:	8b 45 0c             	mov    0xc(%ebp),%eax
f010626a:	fc                   	cld    
f010626b:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010626d:	89 f8                	mov    %edi,%eax
f010626f:	5b                   	pop    %ebx
f0106270:	5e                   	pop    %esi
f0106271:	5f                   	pop    %edi
f0106272:	5d                   	pop    %ebp
f0106273:	c3                   	ret    

f0106274 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0106274:	55                   	push   %ebp
f0106275:	89 e5                	mov    %esp,%ebp
f0106277:	57                   	push   %edi
f0106278:	56                   	push   %esi
f0106279:	8b 45 08             	mov    0x8(%ebp),%eax
f010627c:	8b 75 0c             	mov    0xc(%ebp),%esi
f010627f:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0106282:	39 c6                	cmp    %eax,%esi
f0106284:	73 35                	jae    f01062bb <memmove+0x47>
f0106286:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0106289:	39 d0                	cmp    %edx,%eax
f010628b:	73 2e                	jae    f01062bb <memmove+0x47>
		s += n;
		d += n;
f010628d:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0106290:	89 d6                	mov    %edx,%esi
f0106292:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0106294:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010629a:	75 13                	jne    f01062af <memmove+0x3b>
f010629c:	f6 c1 03             	test   $0x3,%cl
f010629f:	75 0e                	jne    f01062af <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f01062a1:	83 ef 04             	sub    $0x4,%edi
f01062a4:	8d 72 fc             	lea    -0x4(%edx),%esi
f01062a7:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f01062aa:	fd                   	std    
f01062ab:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01062ad:	eb 09                	jmp    f01062b8 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f01062af:	83 ef 01             	sub    $0x1,%edi
f01062b2:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f01062b5:	fd                   	std    
f01062b6:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f01062b8:	fc                   	cld    
f01062b9:	eb 1d                	jmp    f01062d8 <memmove+0x64>
f01062bb:	89 f2                	mov    %esi,%edx
f01062bd:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01062bf:	f6 c2 03             	test   $0x3,%dl
f01062c2:	75 0f                	jne    f01062d3 <memmove+0x5f>
f01062c4:	f6 c1 03             	test   $0x3,%cl
f01062c7:	75 0a                	jne    f01062d3 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f01062c9:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f01062cc:	89 c7                	mov    %eax,%edi
f01062ce:	fc                   	cld    
f01062cf:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01062d1:	eb 05                	jmp    f01062d8 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f01062d3:	89 c7                	mov    %eax,%edi
f01062d5:	fc                   	cld    
f01062d6:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01062d8:	5e                   	pop    %esi
f01062d9:	5f                   	pop    %edi
f01062da:	5d                   	pop    %ebp
f01062db:	c3                   	ret    

f01062dc <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f01062dc:	55                   	push   %ebp
f01062dd:	89 e5                	mov    %esp,%ebp
f01062df:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01062e2:	8b 45 10             	mov    0x10(%ebp),%eax
f01062e5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01062e9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01062ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01062f0:	8b 45 08             	mov    0x8(%ebp),%eax
f01062f3:	89 04 24             	mov    %eax,(%esp)
f01062f6:	e8 79 ff ff ff       	call   f0106274 <memmove>
}
f01062fb:	c9                   	leave  
f01062fc:	c3                   	ret    

f01062fd <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01062fd:	55                   	push   %ebp
f01062fe:	89 e5                	mov    %esp,%ebp
f0106300:	56                   	push   %esi
f0106301:	53                   	push   %ebx
f0106302:	8b 55 08             	mov    0x8(%ebp),%edx
f0106305:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0106308:	89 d6                	mov    %edx,%esi
f010630a:	03 75 10             	add    0x10(%ebp),%esi
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010630d:	eb 1a                	jmp    f0106329 <memcmp+0x2c>
		if (*s1 != *s2)
f010630f:	0f b6 02             	movzbl (%edx),%eax
f0106312:	0f b6 19             	movzbl (%ecx),%ebx
f0106315:	38 d8                	cmp    %bl,%al
f0106317:	74 0a                	je     f0106323 <memcmp+0x26>
			return (int) *s1 - (int) *s2;
f0106319:	0f b6 c0             	movzbl %al,%eax
f010631c:	0f b6 db             	movzbl %bl,%ebx
f010631f:	29 d8                	sub    %ebx,%eax
f0106321:	eb 0f                	jmp    f0106332 <memcmp+0x35>
		s1++, s2++;
f0106323:	83 c2 01             	add    $0x1,%edx
f0106326:	83 c1 01             	add    $0x1,%ecx
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0106329:	39 f2                	cmp    %esi,%edx
f010632b:	75 e2                	jne    f010630f <memcmp+0x12>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f010632d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106332:	5b                   	pop    %ebx
f0106333:	5e                   	pop    %esi
f0106334:	5d                   	pop    %ebp
f0106335:	c3                   	ret    

f0106336 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0106336:	55                   	push   %ebp
f0106337:	89 e5                	mov    %esp,%ebp
f0106339:	8b 45 08             	mov    0x8(%ebp),%eax
f010633c:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f010633f:	89 c2                	mov    %eax,%edx
f0106341:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0106344:	eb 07                	jmp    f010634d <memfind+0x17>
		if (*(const unsigned char *) s == (unsigned char) c)
f0106346:	38 08                	cmp    %cl,(%eax)
f0106348:	74 07                	je     f0106351 <memfind+0x1b>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f010634a:	83 c0 01             	add    $0x1,%eax
f010634d:	39 d0                	cmp    %edx,%eax
f010634f:	72 f5                	jb     f0106346 <memfind+0x10>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0106351:	5d                   	pop    %ebp
f0106352:	c3                   	ret    

f0106353 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0106353:	55                   	push   %ebp
f0106354:	89 e5                	mov    %esp,%ebp
f0106356:	57                   	push   %edi
f0106357:	56                   	push   %esi
f0106358:	53                   	push   %ebx
f0106359:	8b 55 08             	mov    0x8(%ebp),%edx
f010635c:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010635f:	eb 03                	jmp    f0106364 <strtol+0x11>
		s++;
f0106361:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0106364:	0f b6 0a             	movzbl (%edx),%ecx
f0106367:	80 f9 09             	cmp    $0x9,%cl
f010636a:	74 f5                	je     f0106361 <strtol+0xe>
f010636c:	80 f9 20             	cmp    $0x20,%cl
f010636f:	74 f0                	je     f0106361 <strtol+0xe>
		s++;

	// plus/minus sign
	if (*s == '+')
f0106371:	80 f9 2b             	cmp    $0x2b,%cl
f0106374:	75 0a                	jne    f0106380 <strtol+0x2d>
		s++;
f0106376:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0106379:	bf 00 00 00 00       	mov    $0x0,%edi
f010637e:	eb 11                	jmp    f0106391 <strtol+0x3e>
f0106380:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0106385:	80 f9 2d             	cmp    $0x2d,%cl
f0106388:	75 07                	jne    f0106391 <strtol+0x3e>
		s++, neg = 1;
f010638a:	8d 52 01             	lea    0x1(%edx),%edx
f010638d:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0106391:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0106396:	75 15                	jne    f01063ad <strtol+0x5a>
f0106398:	80 3a 30             	cmpb   $0x30,(%edx)
f010639b:	75 10                	jne    f01063ad <strtol+0x5a>
f010639d:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f01063a1:	75 0a                	jne    f01063ad <strtol+0x5a>
		s += 2, base = 16;
f01063a3:	83 c2 02             	add    $0x2,%edx
f01063a6:	b8 10 00 00 00       	mov    $0x10,%eax
f01063ab:	eb 10                	jmp    f01063bd <strtol+0x6a>
	else if (base == 0 && s[0] == '0')
f01063ad:	85 c0                	test   %eax,%eax
f01063af:	75 0c                	jne    f01063bd <strtol+0x6a>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f01063b1:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f01063b3:	80 3a 30             	cmpb   $0x30,(%edx)
f01063b6:	75 05                	jne    f01063bd <strtol+0x6a>
		s++, base = 8;
f01063b8:	83 c2 01             	add    $0x1,%edx
f01063bb:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01063bd:	bb 00 00 00 00       	mov    $0x0,%ebx
f01063c2:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01063c5:	0f b6 0a             	movzbl (%edx),%ecx
f01063c8:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01063cb:	89 f0                	mov    %esi,%eax
f01063cd:	3c 09                	cmp    $0x9,%al
f01063cf:	77 08                	ja     f01063d9 <strtol+0x86>
			dig = *s - '0';
f01063d1:	0f be c9             	movsbl %cl,%ecx
f01063d4:	83 e9 30             	sub    $0x30,%ecx
f01063d7:	eb 20                	jmp    f01063f9 <strtol+0xa6>
		else if (*s >= 'a' && *s <= 'z')
f01063d9:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01063dc:	89 f0                	mov    %esi,%eax
f01063de:	3c 19                	cmp    $0x19,%al
f01063e0:	77 08                	ja     f01063ea <strtol+0x97>
			dig = *s - 'a' + 10;
f01063e2:	0f be c9             	movsbl %cl,%ecx
f01063e5:	83 e9 57             	sub    $0x57,%ecx
f01063e8:	eb 0f                	jmp    f01063f9 <strtol+0xa6>
		else if (*s >= 'A' && *s <= 'Z')
f01063ea:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01063ed:	89 f0                	mov    %esi,%eax
f01063ef:	3c 19                	cmp    $0x19,%al
f01063f1:	77 16                	ja     f0106409 <strtol+0xb6>
			dig = *s - 'A' + 10;
f01063f3:	0f be c9             	movsbl %cl,%ecx
f01063f6:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01063f9:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01063fc:	7d 0f                	jge    f010640d <strtol+0xba>
			break;
		s++, val = (val * base) + dig;
f01063fe:	83 c2 01             	add    $0x1,%edx
f0106401:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0106405:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0106407:	eb bc                	jmp    f01063c5 <strtol+0x72>
f0106409:	89 d8                	mov    %ebx,%eax
f010640b:	eb 02                	jmp    f010640f <strtol+0xbc>
f010640d:	89 d8                	mov    %ebx,%eax

	if (endptr)
f010640f:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0106413:	74 05                	je     f010641a <strtol+0xc7>
		*endptr = (char *) s;
f0106415:	8b 75 0c             	mov    0xc(%ebp),%esi
f0106418:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f010641a:	f7 d8                	neg    %eax
f010641c:	85 ff                	test   %edi,%edi
f010641e:	0f 44 c3             	cmove  %ebx,%eax
}
f0106421:	5b                   	pop    %ebx
f0106422:	5e                   	pop    %esi
f0106423:	5f                   	pop    %edi
f0106424:	5d                   	pop    %ebp
f0106425:	c3                   	ret    
f0106426:	66 90                	xchg   %ax,%ax

f0106428 <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f0106428:	fa                   	cli    

	xorw    %ax, %ax
f0106429:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010642b:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f010642d:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f010642f:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0106431:	0f 01 16             	lgdtl  (%esi)
f0106434:	74 70                	je     f01064a6 <mpentry_end+0x4>
	movl    %cr0, %eax
f0106436:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f0106439:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f010643d:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0106440:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0106446:	08 00                	or     %al,(%eax)

f0106448 <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0106448:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f010644c:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f010644e:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106450:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0106452:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0106456:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0106458:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010645a:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl    %eax, %cr3
f010645f:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0106462:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0106465:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010646a:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in boot_aps()
	movl    mpentry_kstack, %esp
f010646d:	8b 25 84 1e 23 f0    	mov    0xf0231e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0106473:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0106478:	b8 2f 02 10 f0       	mov    $0xf010022f,%eax
	call    *%eax
f010647d:	ff d0                	call   *%eax

f010647f <spin>:

	# If mp_main returns (it should not), loop.
spin:
	jmp     spin
f010647f:	eb fe                	jmp    f010647f <spin>
f0106481:	8d 76 00             	lea    0x0(%esi),%esi

f0106484 <gdt>:
	...
f010648c:	ff                   	(bad)  
f010648d:	ff 00                	incl   (%eax)
f010648f:	00 00                	add    %al,(%eax)
f0106491:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0106498:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f010649c <gdtdesc>:
f010649c:	17                   	pop    %ss
f010649d:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f01064a2 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f01064a2:	90                   	nop
f01064a3:	66 90                	xchg   %ax,%ax
f01064a5:	66 90                	xchg   %ax,%ax
f01064a7:	66 90                	xchg   %ax,%ax
f01064a9:	66 90                	xchg   %ax,%ax
f01064ab:	66 90                	xchg   %ax,%ax
f01064ad:	66 90                	xchg   %ax,%ax
f01064af:	90                   	nop

f01064b0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f01064b0:	55                   	push   %ebp
f01064b1:	89 e5                	mov    %esp,%ebp
f01064b3:	56                   	push   %esi
f01064b4:	53                   	push   %ebx
f01064b5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01064b8:	8b 0d 88 1e 23 f0    	mov    0xf0231e88,%ecx
f01064be:	89 c3                	mov    %eax,%ebx
f01064c0:	c1 eb 0c             	shr    $0xc,%ebx
f01064c3:	39 cb                	cmp    %ecx,%ebx
f01064c5:	72 20                	jb     f01064e7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01064c7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01064cb:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f01064d2:	f0 
f01064d3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01064da:	00 
f01064db:	c7 04 24 25 8a 10 f0 	movl   $0xf0108a25,(%esp)
f01064e2:	e8 59 9b ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01064e7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01064ed:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01064ef:	89 c2                	mov    %eax,%edx
f01064f1:	c1 ea 0c             	shr    $0xc,%edx
f01064f4:	39 d1                	cmp    %edx,%ecx
f01064f6:	77 20                	ja     f0106518 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01064f8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01064fc:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0106503:	f0 
f0106504:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010650b:	00 
f010650c:	c7 04 24 25 8a 10 f0 	movl   $0xf0108a25,(%esp)
f0106513:	e8 28 9b ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106518:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f010651e:	eb 36                	jmp    f0106556 <mpsearch1+0xa6>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106520:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106527:	00 
f0106528:	c7 44 24 04 35 8a 10 	movl   $0xf0108a35,0x4(%esp)
f010652f:	f0 
f0106530:	89 1c 24             	mov    %ebx,(%esp)
f0106533:	e8 c5 fd ff ff       	call   f01062fd <memcmp>
f0106538:	85 c0                	test   %eax,%eax
f010653a:	75 17                	jne    f0106553 <mpsearch1+0xa3>
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f010653c:	ba 00 00 00 00       	mov    $0x0,%edx
		sum += ((uint8_t *)addr)[i];
f0106541:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0106545:	01 c8                	add    %ecx,%eax
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106547:	83 c2 01             	add    $0x1,%edx
f010654a:	83 fa 10             	cmp    $0x10,%edx
f010654d:	75 f2                	jne    f0106541 <mpsearch1+0x91>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f010654f:	84 c0                	test   %al,%al
f0106551:	74 0e                	je     f0106561 <mpsearch1+0xb1>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0106553:	83 c3 10             	add    $0x10,%ebx
f0106556:	39 f3                	cmp    %esi,%ebx
f0106558:	72 c6                	jb     f0106520 <mpsearch1+0x70>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f010655a:	b8 00 00 00 00       	mov    $0x0,%eax
f010655f:	eb 02                	jmp    f0106563 <mpsearch1+0xb3>
f0106561:	89 d8                	mov    %ebx,%eax
}
f0106563:	83 c4 10             	add    $0x10,%esp
f0106566:	5b                   	pop    %ebx
f0106567:	5e                   	pop    %esi
f0106568:	5d                   	pop    %ebp
f0106569:	c3                   	ret    

f010656a <mp_init>:
	return conf;
}

void
mp_init(void)
{
f010656a:	55                   	push   %ebp
f010656b:	89 e5                	mov    %esp,%ebp
f010656d:	57                   	push   %edi
f010656e:	56                   	push   %esi
f010656f:	53                   	push   %ebx
f0106570:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0106573:	c7 05 c0 23 23 f0 20 	movl   $0xf0232020,0xf02323c0
f010657a:	20 23 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010657d:	83 3d 88 1e 23 f0 00 	cmpl   $0x0,0xf0231e88
f0106584:	75 24                	jne    f01065aa <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106586:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f010658d:	00 
f010658e:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0106595:	f0 
f0106596:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f010659d:	00 
f010659e:	c7 04 24 25 8a 10 f0 	movl   $0xf0108a25,(%esp)
f01065a5:	e8 96 9a ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f01065aa:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01065b1:	85 c0                	test   %eax,%eax
f01065b3:	74 16                	je     f01065cb <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01065b5:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01065b8:	ba 00 04 00 00       	mov    $0x400,%edx
f01065bd:	e8 ee fe ff ff       	call   f01064b0 <mpsearch1>
f01065c2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01065c5:	85 c0                	test   %eax,%eax
f01065c7:	75 3c                	jne    f0106605 <mp_init+0x9b>
f01065c9:	eb 20                	jmp    f01065eb <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01065cb:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01065d2:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01065d5:	2d 00 04 00 00       	sub    $0x400,%eax
f01065da:	ba 00 04 00 00       	mov    $0x400,%edx
f01065df:	e8 cc fe ff ff       	call   f01064b0 <mpsearch1>
f01065e4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01065e7:	85 c0                	test   %eax,%eax
f01065e9:	75 1a                	jne    f0106605 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f01065eb:	ba 00 00 01 00       	mov    $0x10000,%edx
f01065f0:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f01065f5:	e8 b6 fe ff ff       	call   f01064b0 <mpsearch1>
f01065fa:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f01065fd:	85 c0                	test   %eax,%eax
f01065ff:	0f 84 54 02 00 00    	je     f0106859 <mp_init+0x2ef>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0106605:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106608:	8b 70 04             	mov    0x4(%eax),%esi
f010660b:	85 f6                	test   %esi,%esi
f010660d:	74 06                	je     f0106615 <mp_init+0xab>
f010660f:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0106613:	74 11                	je     f0106626 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0106615:	c7 04 24 98 88 10 f0 	movl   $0xf0108898,(%esp)
f010661c:	e8 16 d9 ff ff       	call   f0103f37 <cprintf>
f0106621:	e9 33 02 00 00       	jmp    f0106859 <mp_init+0x2ef>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106626:	89 f0                	mov    %esi,%eax
f0106628:	c1 e8 0c             	shr    $0xc,%eax
f010662b:	3b 05 88 1e 23 f0    	cmp    0xf0231e88,%eax
f0106631:	72 20                	jb     f0106653 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106633:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106637:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f010663e:	f0 
f010663f:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0106646:	00 
f0106647:	c7 04 24 25 8a 10 f0 	movl   $0xf0108a25,(%esp)
f010664e:	e8 ed 99 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106653:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0106659:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106660:	00 
f0106661:	c7 44 24 04 3a 8a 10 	movl   $0xf0108a3a,0x4(%esp)
f0106668:	f0 
f0106669:	89 1c 24             	mov    %ebx,(%esp)
f010666c:	e8 8c fc ff ff       	call   f01062fd <memcmp>
f0106671:	85 c0                	test   %eax,%eax
f0106673:	74 11                	je     f0106686 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0106675:	c7 04 24 c8 88 10 f0 	movl   $0xf01088c8,(%esp)
f010667c:	e8 b6 d8 ff ff       	call   f0103f37 <cprintf>
f0106681:	e9 d3 01 00 00       	jmp    f0106859 <mp_init+0x2ef>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0106686:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f010668a:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f010668e:	0f b7 f8             	movzwl %ax,%edi
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106691:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0106696:	b8 00 00 00 00       	mov    $0x0,%eax
f010669b:	eb 0d                	jmp    f01066aa <mp_init+0x140>
		sum += ((uint8_t *)addr)[i];
f010669d:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f01066a4:	f0 
f01066a5:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01066a7:	83 c0 01             	add    $0x1,%eax
f01066aa:	39 c7                	cmp    %eax,%edi
f01066ac:	7f ef                	jg     f010669d <mp_init+0x133>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01066ae:	84 d2                	test   %dl,%dl
f01066b0:	74 11                	je     f01066c3 <mp_init+0x159>
		cprintf("SMP: Bad MP configuration checksum\n");
f01066b2:	c7 04 24 fc 88 10 f0 	movl   $0xf01088fc,(%esp)
f01066b9:	e8 79 d8 ff ff       	call   f0103f37 <cprintf>
f01066be:	e9 96 01 00 00       	jmp    f0106859 <mp_init+0x2ef>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f01066c3:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f01066c7:	3c 04                	cmp    $0x4,%al
f01066c9:	74 1f                	je     f01066ea <mp_init+0x180>
f01066cb:	3c 01                	cmp    $0x1,%al
f01066cd:	8d 76 00             	lea    0x0(%esi),%esi
f01066d0:	74 18                	je     f01066ea <mp_init+0x180>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f01066d2:	0f b6 c0             	movzbl %al,%eax
f01066d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01066d9:	c7 04 24 20 89 10 f0 	movl   $0xf0108920,(%esp)
f01066e0:	e8 52 d8 ff ff       	call   f0103f37 <cprintf>
f01066e5:	e9 6f 01 00 00       	jmp    f0106859 <mp_init+0x2ef>
		return NULL;
	}
	if ((sum((uint8_t *)conf + conf->length, conf->xlength) + conf->xchecksum) & 0xff) {
f01066ea:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f01066ee:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f01066f2:	01 df                	add    %ebx,%edi
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f01066f4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f01066f9:	b8 00 00 00 00       	mov    $0x0,%eax
f01066fe:	eb 09                	jmp    f0106709 <mp_init+0x19f>
		sum += ((uint8_t *)addr)[i];
f0106700:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106704:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106706:	83 c0 01             	add    $0x1,%eax
f0106709:	39 c6                	cmp    %eax,%esi
f010670b:	7f f3                	jg     f0106700 <mp_init+0x196>
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if ((sum((uint8_t *)conf + conf->length, conf->xlength) + conf->xchecksum) & 0xff) {
f010670d:	02 53 2a             	add    0x2a(%ebx),%dl
f0106710:	84 d2                	test   %dl,%dl
f0106712:	74 11                	je     f0106725 <mp_init+0x1bb>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0106714:	c7 04 24 40 89 10 f0 	movl   $0xf0108940,(%esp)
f010671b:	e8 17 d8 ff ff       	call   f0103f37 <cprintf>
f0106720:	e9 34 01 00 00       	jmp    f0106859 <mp_init+0x2ef>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0106725:	85 db                	test   %ebx,%ebx
f0106727:	0f 84 2c 01 00 00    	je     f0106859 <mp_init+0x2ef>
		return;
	ismp = 1;
f010672d:	c7 05 00 20 23 f0 01 	movl   $0x1,0xf0232000
f0106734:	00 00 00 
	lapicaddr = conf->lapicaddr;
f0106737:	8b 43 24             	mov    0x24(%ebx),%eax
f010673a:	a3 00 30 27 f0       	mov    %eax,0xf0273000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f010673f:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106742:	be 00 00 00 00       	mov    $0x0,%esi
f0106747:	e9 86 00 00 00       	jmp    f01067d2 <mp_init+0x268>
		switch (*p) {
f010674c:	0f b6 07             	movzbl (%edi),%eax
f010674f:	84 c0                	test   %al,%al
f0106751:	74 06                	je     f0106759 <mp_init+0x1ef>
f0106753:	3c 04                	cmp    $0x4,%al
f0106755:	77 57                	ja     f01067ae <mp_init+0x244>
f0106757:	eb 50                	jmp    f01067a9 <mp_init+0x23f>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0106759:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f010675d:	8d 76 00             	lea    0x0(%esi),%esi
f0106760:	74 11                	je     f0106773 <mp_init+0x209>
				bootcpu = &cpus[ncpu];
f0106762:	6b 05 c4 23 23 f0 74 	imul   $0x74,0xf02323c4,%eax
f0106769:	05 20 20 23 f0       	add    $0xf0232020,%eax
f010676e:	a3 c0 23 23 f0       	mov    %eax,0xf02323c0
			if (ncpu < NCPU) {
f0106773:	a1 c4 23 23 f0       	mov    0xf02323c4,%eax
f0106778:	83 f8 07             	cmp    $0x7,%eax
f010677b:	7f 13                	jg     f0106790 <mp_init+0x226>
				cpus[ncpu].cpu_id = ncpu;
f010677d:	6b d0 74             	imul   $0x74,%eax,%edx
f0106780:	88 82 20 20 23 f0    	mov    %al,-0xfdcdfe0(%edx)
				ncpu++;
f0106786:	83 c0 01             	add    $0x1,%eax
f0106789:	a3 c4 23 23 f0       	mov    %eax,0xf02323c4
f010678e:	eb 14                	jmp    f01067a4 <mp_init+0x23a>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0106790:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0106794:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106798:	c7 04 24 70 89 10 f0 	movl   $0xf0108970,(%esp)
f010679f:	e8 93 d7 ff ff       	call   f0103f37 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01067a4:	83 c7 14             	add    $0x14,%edi
			continue;
f01067a7:	eb 26                	jmp    f01067cf <mp_init+0x265>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f01067a9:	83 c7 08             	add    $0x8,%edi
			continue;
f01067ac:	eb 21                	jmp    f01067cf <mp_init+0x265>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f01067ae:	0f b6 c0             	movzbl %al,%eax
f01067b1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01067b5:	c7 04 24 98 89 10 f0 	movl   $0xf0108998,(%esp)
f01067bc:	e8 76 d7 ff ff       	call   f0103f37 <cprintf>
			ismp = 0;
f01067c1:	c7 05 00 20 23 f0 00 	movl   $0x0,0xf0232000
f01067c8:	00 00 00 
			i = conf->entry;
f01067cb:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapicaddr = conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f01067cf:	83 c6 01             	add    $0x1,%esi
f01067d2:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f01067d6:	39 c6                	cmp    %eax,%esi
f01067d8:	0f 82 6e ff ff ff    	jb     f010674c <mp_init+0x1e2>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f01067de:	a1 c0 23 23 f0       	mov    0xf02323c0,%eax
f01067e3:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f01067ea:	83 3d 00 20 23 f0 00 	cmpl   $0x0,0xf0232000
f01067f1:	75 22                	jne    f0106815 <mp_init+0x2ab>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f01067f3:	c7 05 c4 23 23 f0 01 	movl   $0x1,0xf02323c4
f01067fa:	00 00 00 
		lapicaddr = 0;
f01067fd:	c7 05 00 30 27 f0 00 	movl   $0x0,0xf0273000
f0106804:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106807:	c7 04 24 b8 89 10 f0 	movl   $0xf01089b8,(%esp)
f010680e:	e8 24 d7 ff ff       	call   f0103f37 <cprintf>
		return;
f0106813:	eb 44                	jmp    f0106859 <mp_init+0x2ef>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0106815:	8b 15 c4 23 23 f0    	mov    0xf02323c4,%edx
f010681b:	89 54 24 08          	mov    %edx,0x8(%esp)
f010681f:	0f b6 00             	movzbl (%eax),%eax
f0106822:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106826:	c7 04 24 3f 8a 10 f0 	movl   $0xf0108a3f,(%esp)
f010682d:	e8 05 d7 ff ff       	call   f0103f37 <cprintf>

	if (mp->imcrp) {
f0106832:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106835:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106839:	74 1e                	je     f0106859 <mp_init+0x2ef>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f010683b:	c7 04 24 e4 89 10 f0 	movl   $0xf01089e4,(%esp)
f0106842:	e8 f0 d6 ff ff       	call   f0103f37 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106847:	ba 22 00 00 00       	mov    $0x22,%edx
f010684c:	b8 70 00 00 00       	mov    $0x70,%eax
f0106851:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0106852:	b2 23                	mov    $0x23,%dl
f0106854:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0106855:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106858:	ee                   	out    %al,(%dx)
	}
}
f0106859:	83 c4 2c             	add    $0x2c,%esp
f010685c:	5b                   	pop    %ebx
f010685d:	5e                   	pop    %esi
f010685e:	5f                   	pop    %edi
f010685f:	5d                   	pop    %ebp
f0106860:	c3                   	ret    

f0106861 <lapicw>:
physaddr_t lapicaddr;        // Initialized in mpconfig.c
volatile uint32_t *lapic;

static void
lapicw(int index, int value)
{
f0106861:	55                   	push   %ebp
f0106862:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0106864:	8b 0d 04 30 27 f0    	mov    0xf0273004,%ecx
f010686a:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f010686d:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f010686f:	a1 04 30 27 f0       	mov    0xf0273004,%eax
f0106874:	8b 40 20             	mov    0x20(%eax),%eax
}
f0106877:	5d                   	pop    %ebp
f0106878:	c3                   	ret    

f0106879 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0106879:	55                   	push   %ebp
f010687a:	89 e5                	mov    %esp,%ebp
	if (lapic)
f010687c:	a1 04 30 27 f0       	mov    0xf0273004,%eax
f0106881:	85 c0                	test   %eax,%eax
f0106883:	74 08                	je     f010688d <cpunum+0x14>
		return lapic[ID] >> 24;
f0106885:	8b 40 20             	mov    0x20(%eax),%eax
f0106888:	c1 e8 18             	shr    $0x18,%eax
f010688b:	eb 05                	jmp    f0106892 <cpunum+0x19>
	return 0;
f010688d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106892:	5d                   	pop    %ebp
f0106893:	c3                   	ret    

f0106894 <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapicaddr)
f0106894:	a1 00 30 27 f0       	mov    0xf0273000,%eax
f0106899:	85 c0                	test   %eax,%eax
f010689b:	0f 84 23 01 00 00    	je     f01069c4 <lapic_init+0x130>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01068a1:	55                   	push   %ebp
f01068a2:	89 e5                	mov    %esp,%ebp
f01068a4:	83 ec 18             	sub    $0x18,%esp
	if (!lapicaddr)
		return;

	// lapicaddr is the physical address of the LAPIC's 4K MMIO
	// region.  Map it in to virtual memory so we can access it.
	lapic = mmio_map_region(lapicaddr, 4096);
f01068a7:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01068ae:	00 
f01068af:	89 04 24             	mov    %eax,(%esp)
f01068b2:	e8 5d ab ff ff       	call   f0101414 <mmio_map_region>
f01068b7:	a3 04 30 27 f0       	mov    %eax,0xf0273004

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01068bc:	ba 27 01 00 00       	mov    $0x127,%edx
f01068c1:	b8 3c 00 00 00       	mov    $0x3c,%eax
f01068c6:	e8 96 ff ff ff       	call   f0106861 <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f01068cb:	ba 0b 00 00 00       	mov    $0xb,%edx
f01068d0:	b8 f8 00 00 00       	mov    $0xf8,%eax
f01068d5:	e8 87 ff ff ff       	call   f0106861 <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f01068da:	ba 20 00 02 00       	mov    $0x20020,%edx
f01068df:	b8 c8 00 00 00       	mov    $0xc8,%eax
f01068e4:	e8 78 ff ff ff       	call   f0106861 <lapicw>
	lapicw(TICR, 10000000); 
f01068e9:	ba 80 96 98 00       	mov    $0x989680,%edx
f01068ee:	b8 e0 00 00 00       	mov    $0xe0,%eax
f01068f3:	e8 69 ff ff ff       	call   f0106861 <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f01068f8:	e8 7c ff ff ff       	call   f0106879 <cpunum>
f01068fd:	6b c0 74             	imul   $0x74,%eax,%eax
f0106900:	05 20 20 23 f0       	add    $0xf0232020,%eax
f0106905:	39 05 c0 23 23 f0    	cmp    %eax,0xf02323c0
f010690b:	74 0f                	je     f010691c <lapic_init+0x88>
		lapicw(LINT0, MASKED);
f010690d:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106912:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106917:	e8 45 ff ff ff       	call   f0106861 <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010691c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106921:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106926:	e8 36 ff ff ff       	call   f0106861 <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010692b:	a1 04 30 27 f0       	mov    0xf0273004,%eax
f0106930:	8b 40 30             	mov    0x30(%eax),%eax
f0106933:	c1 e8 10             	shr    $0x10,%eax
f0106936:	3c 03                	cmp    $0x3,%al
f0106938:	76 0f                	jbe    f0106949 <lapic_init+0xb5>
		lapicw(PCINT, MASKED);
f010693a:	ba 00 00 01 00       	mov    $0x10000,%edx
f010693f:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106944:	e8 18 ff ff ff       	call   f0106861 <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f0106949:	ba 33 00 00 00       	mov    $0x33,%edx
f010694e:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106953:	e8 09 ff ff ff       	call   f0106861 <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f0106958:	ba 00 00 00 00       	mov    $0x0,%edx
f010695d:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106962:	e8 fa fe ff ff       	call   f0106861 <lapicw>
	lapicw(ESR, 0);
f0106967:	ba 00 00 00 00       	mov    $0x0,%edx
f010696c:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106971:	e8 eb fe ff ff       	call   f0106861 <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106976:	ba 00 00 00 00       	mov    $0x0,%edx
f010697b:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106980:	e8 dc fe ff ff       	call   f0106861 <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106985:	ba 00 00 00 00       	mov    $0x0,%edx
f010698a:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010698f:	e8 cd fe ff ff       	call   f0106861 <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0106994:	ba 00 85 08 00       	mov    $0x88500,%edx
f0106999:	b8 c0 00 00 00       	mov    $0xc0,%eax
f010699e:	e8 be fe ff ff       	call   f0106861 <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01069a3:	8b 15 04 30 27 f0    	mov    0xf0273004,%edx
f01069a9:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01069af:	f6 c4 10             	test   $0x10,%ah
f01069b2:	75 f5                	jne    f01069a9 <lapic_init+0x115>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01069b4:	ba 00 00 00 00       	mov    $0x0,%edx
f01069b9:	b8 20 00 00 00       	mov    $0x20,%eax
f01069be:	e8 9e fe ff ff       	call   f0106861 <lapicw>
}
f01069c3:	c9                   	leave  
f01069c4:	f3 c3                	repz ret 

f01069c6 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01069c6:	83 3d 04 30 27 f0 00 	cmpl   $0x0,0xf0273004
f01069cd:	74 13                	je     f01069e2 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01069cf:	55                   	push   %ebp
f01069d0:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01069d2:	ba 00 00 00 00       	mov    $0x0,%edx
f01069d7:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01069dc:	e8 80 fe ff ff       	call   f0106861 <lapicw>
}
f01069e1:	5d                   	pop    %ebp
f01069e2:	f3 c3                	repz ret 

f01069e4 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f01069e4:	55                   	push   %ebp
f01069e5:	89 e5                	mov    %esp,%ebp
f01069e7:	56                   	push   %esi
f01069e8:	53                   	push   %ebx
f01069e9:	83 ec 10             	sub    $0x10,%esp
f01069ec:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01069ef:	8b 75 0c             	mov    0xc(%ebp),%esi
f01069f2:	ba 70 00 00 00       	mov    $0x70,%edx
f01069f7:	b8 0f 00 00 00       	mov    $0xf,%eax
f01069fc:	ee                   	out    %al,(%dx)
f01069fd:	b2 71                	mov    $0x71,%dl
f01069ff:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106a04:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106a05:	83 3d 88 1e 23 f0 00 	cmpl   $0x0,0xf0231e88
f0106a0c:	75 24                	jne    f0106a32 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106a0e:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106a15:	00 
f0106a16:	c7 44 24 08 84 6f 10 	movl   $0xf0106f84,0x8(%esp)
f0106a1d:	f0 
f0106a1e:	c7 44 24 04 98 00 00 	movl   $0x98,0x4(%esp)
f0106a25:	00 
f0106a26:	c7 04 24 5c 8a 10 f0 	movl   $0xf0108a5c,(%esp)
f0106a2d:	e8 0e 96 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106a32:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f0106a39:	00 00 
	wrv[1] = addr >> 4;
f0106a3b:	89 f0                	mov    %esi,%eax
f0106a3d:	c1 e8 04             	shr    $0x4,%eax
f0106a40:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106a46:	c1 e3 18             	shl    $0x18,%ebx
f0106a49:	89 da                	mov    %ebx,%edx
f0106a4b:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106a50:	e8 0c fe ff ff       	call   f0106861 <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106a55:	ba 00 c5 00 00       	mov    $0xc500,%edx
f0106a5a:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106a5f:	e8 fd fd ff ff       	call   f0106861 <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106a64:	ba 00 85 00 00       	mov    $0x8500,%edx
f0106a69:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106a6e:	e8 ee fd ff ff       	call   f0106861 <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106a73:	c1 ee 0c             	shr    $0xc,%esi
f0106a76:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106a7c:	89 da                	mov    %ebx,%edx
f0106a7e:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106a83:	e8 d9 fd ff ff       	call   f0106861 <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106a88:	89 f2                	mov    %esi,%edx
f0106a8a:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106a8f:	e8 cd fd ff ff       	call   f0106861 <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106a94:	89 da                	mov    %ebx,%edx
f0106a96:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106a9b:	e8 c1 fd ff ff       	call   f0106861 <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106aa0:	89 f2                	mov    %esi,%edx
f0106aa2:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106aa7:	e8 b5 fd ff ff       	call   f0106861 <lapicw>
		microdelay(200);
	}
}
f0106aac:	83 c4 10             	add    $0x10,%esp
f0106aaf:	5b                   	pop    %ebx
f0106ab0:	5e                   	pop    %esi
f0106ab1:	5d                   	pop    %ebp
f0106ab2:	c3                   	ret    

f0106ab3 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0106ab3:	55                   	push   %ebp
f0106ab4:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0106ab6:	8b 55 08             	mov    0x8(%ebp),%edx
f0106ab9:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0106abf:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106ac4:	e8 98 fd ff ff       	call   f0106861 <lapicw>
	while (lapic[ICRLO] & DELIVS)
f0106ac9:	8b 15 04 30 27 f0    	mov    0xf0273004,%edx
f0106acf:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106ad5:	f6 c4 10             	test   $0x10,%ah
f0106ad8:	75 f5                	jne    f0106acf <lapic_ipi+0x1c>
		;
}
f0106ada:	5d                   	pop    %ebp
f0106adb:	c3                   	ret    

f0106adc <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f0106adc:	55                   	push   %ebp
f0106add:	89 e5                	mov    %esp,%ebp
f0106adf:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0106ae2:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f0106ae8:	8b 55 0c             	mov    0xc(%ebp),%edx
f0106aeb:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0106aee:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0106af5:	5d                   	pop    %ebp
f0106af6:	c3                   	ret    

f0106af7 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0106af7:	55                   	push   %ebp
f0106af8:	89 e5                	mov    %esp,%ebp
f0106afa:	56                   	push   %esi
f0106afb:	53                   	push   %ebx
f0106afc:	83 ec 20             	sub    $0x20,%esp
f0106aff:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106b02:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106b05:	75 07                	jne    f0106b0e <spin_lock+0x17>
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106b07:	ba 01 00 00 00       	mov    $0x1,%edx
f0106b0c:	eb 42                	jmp    f0106b50 <spin_lock+0x59>
f0106b0e:	8b 73 08             	mov    0x8(%ebx),%esi
f0106b11:	e8 63 fd ff ff       	call   f0106879 <cpunum>
f0106b16:	6b c0 74             	imul   $0x74,%eax,%eax
f0106b19:	05 20 20 23 f0       	add    $0xf0232020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106b1e:	39 c6                	cmp    %eax,%esi
f0106b20:	75 e5                	jne    f0106b07 <spin_lock+0x10>
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106b22:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106b25:	e8 4f fd ff ff       	call   f0106879 <cpunum>
f0106b2a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f0106b2e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106b32:	c7 44 24 08 6c 8a 10 	movl   $0xf0108a6c,0x8(%esp)
f0106b39:	f0 
f0106b3a:	c7 44 24 04 41 00 00 	movl   $0x41,0x4(%esp)
f0106b41:	00 
f0106b42:	c7 04 24 d0 8a 10 f0 	movl   $0xf0108ad0,(%esp)
f0106b49:	e8 f2 94 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f0106b4e:	f3 90                	pause  
f0106b50:	89 d0                	mov    %edx,%eax
f0106b52:	f0 87 03             	lock xchg %eax,(%ebx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106b55:	85 c0                	test   %eax,%eax
f0106b57:	75 f5                	jne    f0106b4e <spin_lock+0x57>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106b59:	e8 1b fd ff ff       	call   f0106879 <cpunum>
f0106b5e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106b61:	05 20 20 23 f0       	add    $0xf0232020,%eax
f0106b66:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106b69:	83 c3 0c             	add    $0xc,%ebx
get_caller_pcs(uint32_t pcs[])
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
f0106b6c:	89 ea                	mov    %ebp,%edx
	for (i = 0; i < 10; i++){
f0106b6e:	b8 00 00 00 00       	mov    $0x0,%eax
		if (ebp == 0 || ebp < (uint32_t *)ULIM)
f0106b73:	81 fa ff ff 7f ef    	cmp    $0xef7fffff,%edx
f0106b79:	76 12                	jbe    f0106b8d <spin_lock+0x96>
			break;
		pcs[i] = ebp[1];          // saved %eip
f0106b7b:	8b 4a 04             	mov    0x4(%edx),%ecx
f0106b7e:	89 0c 83             	mov    %ecx,(%ebx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0106b81:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0106b83:	83 c0 01             	add    $0x1,%eax
f0106b86:	83 f8 0a             	cmp    $0xa,%eax
f0106b89:	75 e8                	jne    f0106b73 <spin_lock+0x7c>
f0106b8b:	eb 0f                	jmp    f0106b9c <spin_lock+0xa5>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f0106b8d:	c7 04 83 00 00 00 00 	movl   $0x0,(%ebx,%eax,4)
		if (ebp == 0 || ebp < (uint32_t *)ULIM)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0106b94:	83 c0 01             	add    $0x1,%eax
f0106b97:	83 f8 09             	cmp    $0x9,%eax
f0106b9a:	7e f1                	jle    f0106b8d <spin_lock+0x96>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0106b9c:	83 c4 20             	add    $0x20,%esp
f0106b9f:	5b                   	pop    %ebx
f0106ba0:	5e                   	pop    %esi
f0106ba1:	5d                   	pop    %ebp
f0106ba2:	c3                   	ret    

f0106ba3 <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f0106ba3:	55                   	push   %ebp
f0106ba4:	89 e5                	mov    %esp,%ebp
f0106ba6:	57                   	push   %edi
f0106ba7:	56                   	push   %esi
f0106ba8:	53                   	push   %ebx
f0106ba9:	83 ec 6c             	sub    $0x6c,%esp
f0106bac:	8b 75 08             	mov    0x8(%ebp),%esi

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106baf:	83 3e 00             	cmpl   $0x0,(%esi)
f0106bb2:	74 18                	je     f0106bcc <spin_unlock+0x29>
f0106bb4:	8b 5e 08             	mov    0x8(%esi),%ebx
f0106bb7:	e8 bd fc ff ff       	call   f0106879 <cpunum>
f0106bbc:	6b c0 74             	imul   $0x74,%eax,%eax
f0106bbf:	05 20 20 23 f0       	add    $0xf0232020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f0106bc4:	39 c3                	cmp    %eax,%ebx
f0106bc6:	0f 84 ce 00 00 00    	je     f0106c9a <spin_unlock+0xf7>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106bcc:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f0106bd3:	00 
f0106bd4:	8d 46 0c             	lea    0xc(%esi),%eax
f0106bd7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106bdb:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f0106bde:	89 1c 24             	mov    %ebx,(%esp)
f0106be1:	e8 8e f6 ff ff       	call   f0106274 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f0106be6:	8b 46 08             	mov    0x8(%esi),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106be9:	0f b6 38             	movzbl (%eax),%edi
f0106bec:	8b 76 04             	mov    0x4(%esi),%esi
f0106bef:	e8 85 fc ff ff       	call   f0106879 <cpunum>
f0106bf4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106bf8:	89 74 24 08          	mov    %esi,0x8(%esp)
f0106bfc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106c00:	c7 04 24 98 8a 10 f0 	movl   $0xf0108a98,(%esp)
f0106c07:	e8 2b d3 ff ff       	call   f0103f37 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106c0c:	8d 7d a8             	lea    -0x58(%ebp),%edi
f0106c0f:	eb 65                	jmp    f0106c76 <spin_unlock+0xd3>
f0106c11:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0106c15:	89 04 24             	mov    %eax,(%esp)
f0106c18:	e8 e9 ea ff ff       	call   f0105706 <debuginfo_eip>
f0106c1d:	85 c0                	test   %eax,%eax
f0106c1f:	78 39                	js     f0106c5a <spin_unlock+0xb7>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106c21:	8b 06                	mov    (%esi),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106c23:	89 c2                	mov    %eax,%edx
f0106c25:	2b 55 b8             	sub    -0x48(%ebp),%edx
f0106c28:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106c2c:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106c2f:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106c33:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f0106c36:	89 54 24 10          	mov    %edx,0x10(%esp)
f0106c3a:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106c3d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106c41:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106c44:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106c48:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106c4c:	c7 04 24 e0 8a 10 f0 	movl   $0xf0108ae0,(%esp)
f0106c53:	e8 df d2 ff ff       	call   f0103f37 <cprintf>
f0106c58:	eb 12                	jmp    f0106c6c <spin_unlock+0xc9>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f0106c5a:	8b 06                	mov    (%esi),%eax
f0106c5c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106c60:	c7 04 24 f7 8a 10 f0 	movl   $0xf0108af7,(%esp)
f0106c67:	e8 cb d2 ff ff       	call   f0103f37 <cprintf>
f0106c6c:	83 c3 04             	add    $0x4,%ebx
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106c6f:	8d 45 e8             	lea    -0x18(%ebp),%eax
f0106c72:	39 c3                	cmp    %eax,%ebx
f0106c74:	74 08                	je     f0106c7e <spin_unlock+0xdb>
f0106c76:	89 de                	mov    %ebx,%esi
f0106c78:	8b 03                	mov    (%ebx),%eax
f0106c7a:	85 c0                	test   %eax,%eax
f0106c7c:	75 93                	jne    f0106c11 <spin_unlock+0x6e>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f0106c7e:	c7 44 24 08 ff 8a 10 	movl   $0xf0108aff,0x8(%esp)
f0106c85:	f0 
f0106c86:	c7 44 24 04 67 00 00 	movl   $0x67,0x4(%esp)
f0106c8d:	00 
f0106c8e:	c7 04 24 d0 8a 10 f0 	movl   $0xf0108ad0,(%esp)
f0106c95:	e8 a6 93 ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0106c9a:	c7 46 0c 00 00 00 00 	movl   $0x0,0xc(%esi)
	lk->cpu = 0;
f0106ca1:	c7 46 08 00 00 00 00 	movl   $0x0,0x8(%esi)
f0106ca8:	b8 00 00 00 00       	mov    $0x0,%eax
f0106cad:	f0 87 06             	lock xchg %eax,(%esi)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f0106cb0:	83 c4 6c             	add    $0x6c,%esp
f0106cb3:	5b                   	pop    %ebx
f0106cb4:	5e                   	pop    %esi
f0106cb5:	5f                   	pop    %edi
f0106cb6:	5d                   	pop    %ebp
f0106cb7:	c3                   	ret    
f0106cb8:	66 90                	xchg   %ax,%ax
f0106cba:	66 90                	xchg   %ax,%ax
f0106cbc:	66 90                	xchg   %ax,%ax
f0106cbe:	66 90                	xchg   %ax,%ax

f0106cc0 <__udivdi3>:
f0106cc0:	55                   	push   %ebp
f0106cc1:	57                   	push   %edi
f0106cc2:	56                   	push   %esi
f0106cc3:	83 ec 0c             	sub    $0xc,%esp
f0106cc6:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106cca:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0106cce:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106cd2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106cd6:	85 c0                	test   %eax,%eax
f0106cd8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0106cdc:	89 ea                	mov    %ebp,%edx
f0106cde:	89 0c 24             	mov    %ecx,(%esp)
f0106ce1:	75 2d                	jne    f0106d10 <__udivdi3+0x50>
f0106ce3:	39 e9                	cmp    %ebp,%ecx
f0106ce5:	77 61                	ja     f0106d48 <__udivdi3+0x88>
f0106ce7:	85 c9                	test   %ecx,%ecx
f0106ce9:	89 ce                	mov    %ecx,%esi
f0106ceb:	75 0b                	jne    f0106cf8 <__udivdi3+0x38>
f0106ced:	b8 01 00 00 00       	mov    $0x1,%eax
f0106cf2:	31 d2                	xor    %edx,%edx
f0106cf4:	f7 f1                	div    %ecx
f0106cf6:	89 c6                	mov    %eax,%esi
f0106cf8:	31 d2                	xor    %edx,%edx
f0106cfa:	89 e8                	mov    %ebp,%eax
f0106cfc:	f7 f6                	div    %esi
f0106cfe:	89 c5                	mov    %eax,%ebp
f0106d00:	89 f8                	mov    %edi,%eax
f0106d02:	f7 f6                	div    %esi
f0106d04:	89 ea                	mov    %ebp,%edx
f0106d06:	83 c4 0c             	add    $0xc,%esp
f0106d09:	5e                   	pop    %esi
f0106d0a:	5f                   	pop    %edi
f0106d0b:	5d                   	pop    %ebp
f0106d0c:	c3                   	ret    
f0106d0d:	8d 76 00             	lea    0x0(%esi),%esi
f0106d10:	39 e8                	cmp    %ebp,%eax
f0106d12:	77 24                	ja     f0106d38 <__udivdi3+0x78>
f0106d14:	0f bd e8             	bsr    %eax,%ebp
f0106d17:	83 f5 1f             	xor    $0x1f,%ebp
f0106d1a:	75 3c                	jne    f0106d58 <__udivdi3+0x98>
f0106d1c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106d20:	39 34 24             	cmp    %esi,(%esp)
f0106d23:	0f 86 9f 00 00 00    	jbe    f0106dc8 <__udivdi3+0x108>
f0106d29:	39 d0                	cmp    %edx,%eax
f0106d2b:	0f 82 97 00 00 00    	jb     f0106dc8 <__udivdi3+0x108>
f0106d31:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106d38:	31 d2                	xor    %edx,%edx
f0106d3a:	31 c0                	xor    %eax,%eax
f0106d3c:	83 c4 0c             	add    $0xc,%esp
f0106d3f:	5e                   	pop    %esi
f0106d40:	5f                   	pop    %edi
f0106d41:	5d                   	pop    %ebp
f0106d42:	c3                   	ret    
f0106d43:	90                   	nop
f0106d44:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106d48:	89 f8                	mov    %edi,%eax
f0106d4a:	f7 f1                	div    %ecx
f0106d4c:	31 d2                	xor    %edx,%edx
f0106d4e:	83 c4 0c             	add    $0xc,%esp
f0106d51:	5e                   	pop    %esi
f0106d52:	5f                   	pop    %edi
f0106d53:	5d                   	pop    %ebp
f0106d54:	c3                   	ret    
f0106d55:	8d 76 00             	lea    0x0(%esi),%esi
f0106d58:	89 e9                	mov    %ebp,%ecx
f0106d5a:	8b 3c 24             	mov    (%esp),%edi
f0106d5d:	d3 e0                	shl    %cl,%eax
f0106d5f:	89 c6                	mov    %eax,%esi
f0106d61:	b8 20 00 00 00       	mov    $0x20,%eax
f0106d66:	29 e8                	sub    %ebp,%eax
f0106d68:	89 c1                	mov    %eax,%ecx
f0106d6a:	d3 ef                	shr    %cl,%edi
f0106d6c:	89 e9                	mov    %ebp,%ecx
f0106d6e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106d72:	8b 3c 24             	mov    (%esp),%edi
f0106d75:	09 74 24 08          	or     %esi,0x8(%esp)
f0106d79:	89 d6                	mov    %edx,%esi
f0106d7b:	d3 e7                	shl    %cl,%edi
f0106d7d:	89 c1                	mov    %eax,%ecx
f0106d7f:	89 3c 24             	mov    %edi,(%esp)
f0106d82:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106d86:	d3 ee                	shr    %cl,%esi
f0106d88:	89 e9                	mov    %ebp,%ecx
f0106d8a:	d3 e2                	shl    %cl,%edx
f0106d8c:	89 c1                	mov    %eax,%ecx
f0106d8e:	d3 ef                	shr    %cl,%edi
f0106d90:	09 d7                	or     %edx,%edi
f0106d92:	89 f2                	mov    %esi,%edx
f0106d94:	89 f8                	mov    %edi,%eax
f0106d96:	f7 74 24 08          	divl   0x8(%esp)
f0106d9a:	89 d6                	mov    %edx,%esi
f0106d9c:	89 c7                	mov    %eax,%edi
f0106d9e:	f7 24 24             	mull   (%esp)
f0106da1:	39 d6                	cmp    %edx,%esi
f0106da3:	89 14 24             	mov    %edx,(%esp)
f0106da6:	72 30                	jb     f0106dd8 <__udivdi3+0x118>
f0106da8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0106dac:	89 e9                	mov    %ebp,%ecx
f0106dae:	d3 e2                	shl    %cl,%edx
f0106db0:	39 c2                	cmp    %eax,%edx
f0106db2:	73 05                	jae    f0106db9 <__udivdi3+0xf9>
f0106db4:	3b 34 24             	cmp    (%esp),%esi
f0106db7:	74 1f                	je     f0106dd8 <__udivdi3+0x118>
f0106db9:	89 f8                	mov    %edi,%eax
f0106dbb:	31 d2                	xor    %edx,%edx
f0106dbd:	e9 7a ff ff ff       	jmp    f0106d3c <__udivdi3+0x7c>
f0106dc2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106dc8:	31 d2                	xor    %edx,%edx
f0106dca:	b8 01 00 00 00       	mov    $0x1,%eax
f0106dcf:	e9 68 ff ff ff       	jmp    f0106d3c <__udivdi3+0x7c>
f0106dd4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106dd8:	8d 47 ff             	lea    -0x1(%edi),%eax
f0106ddb:	31 d2                	xor    %edx,%edx
f0106ddd:	83 c4 0c             	add    $0xc,%esp
f0106de0:	5e                   	pop    %esi
f0106de1:	5f                   	pop    %edi
f0106de2:	5d                   	pop    %ebp
f0106de3:	c3                   	ret    
f0106de4:	66 90                	xchg   %ax,%ax
f0106de6:	66 90                	xchg   %ax,%ax
f0106de8:	66 90                	xchg   %ax,%ax
f0106dea:	66 90                	xchg   %ax,%ax
f0106dec:	66 90                	xchg   %ax,%ax
f0106dee:	66 90                	xchg   %ax,%ax

f0106df0 <__umoddi3>:
f0106df0:	55                   	push   %ebp
f0106df1:	57                   	push   %edi
f0106df2:	56                   	push   %esi
f0106df3:	83 ec 14             	sub    $0x14,%esp
f0106df6:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106dfa:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106dfe:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106e02:	89 c7                	mov    %eax,%edi
f0106e04:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106e08:	8b 44 24 30          	mov    0x30(%esp),%eax
f0106e0c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106e10:	89 34 24             	mov    %esi,(%esp)
f0106e13:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106e17:	85 c0                	test   %eax,%eax
f0106e19:	89 c2                	mov    %eax,%edx
f0106e1b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106e1f:	75 17                	jne    f0106e38 <__umoddi3+0x48>
f0106e21:	39 fe                	cmp    %edi,%esi
f0106e23:	76 4b                	jbe    f0106e70 <__umoddi3+0x80>
f0106e25:	89 c8                	mov    %ecx,%eax
f0106e27:	89 fa                	mov    %edi,%edx
f0106e29:	f7 f6                	div    %esi
f0106e2b:	89 d0                	mov    %edx,%eax
f0106e2d:	31 d2                	xor    %edx,%edx
f0106e2f:	83 c4 14             	add    $0x14,%esp
f0106e32:	5e                   	pop    %esi
f0106e33:	5f                   	pop    %edi
f0106e34:	5d                   	pop    %ebp
f0106e35:	c3                   	ret    
f0106e36:	66 90                	xchg   %ax,%ax
f0106e38:	39 f8                	cmp    %edi,%eax
f0106e3a:	77 54                	ja     f0106e90 <__umoddi3+0xa0>
f0106e3c:	0f bd e8             	bsr    %eax,%ebp
f0106e3f:	83 f5 1f             	xor    $0x1f,%ebp
f0106e42:	75 5c                	jne    f0106ea0 <__umoddi3+0xb0>
f0106e44:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106e48:	39 3c 24             	cmp    %edi,(%esp)
f0106e4b:	0f 87 e7 00 00 00    	ja     f0106f38 <__umoddi3+0x148>
f0106e51:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106e55:	29 f1                	sub    %esi,%ecx
f0106e57:	19 c7                	sbb    %eax,%edi
f0106e59:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106e5d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106e61:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106e65:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106e69:	83 c4 14             	add    $0x14,%esp
f0106e6c:	5e                   	pop    %esi
f0106e6d:	5f                   	pop    %edi
f0106e6e:	5d                   	pop    %ebp
f0106e6f:	c3                   	ret    
f0106e70:	85 f6                	test   %esi,%esi
f0106e72:	89 f5                	mov    %esi,%ebp
f0106e74:	75 0b                	jne    f0106e81 <__umoddi3+0x91>
f0106e76:	b8 01 00 00 00       	mov    $0x1,%eax
f0106e7b:	31 d2                	xor    %edx,%edx
f0106e7d:	f7 f6                	div    %esi
f0106e7f:	89 c5                	mov    %eax,%ebp
f0106e81:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106e85:	31 d2                	xor    %edx,%edx
f0106e87:	f7 f5                	div    %ebp
f0106e89:	89 c8                	mov    %ecx,%eax
f0106e8b:	f7 f5                	div    %ebp
f0106e8d:	eb 9c                	jmp    f0106e2b <__umoddi3+0x3b>
f0106e8f:	90                   	nop
f0106e90:	89 c8                	mov    %ecx,%eax
f0106e92:	89 fa                	mov    %edi,%edx
f0106e94:	83 c4 14             	add    $0x14,%esp
f0106e97:	5e                   	pop    %esi
f0106e98:	5f                   	pop    %edi
f0106e99:	5d                   	pop    %ebp
f0106e9a:	c3                   	ret    
f0106e9b:	90                   	nop
f0106e9c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106ea0:	8b 04 24             	mov    (%esp),%eax
f0106ea3:	be 20 00 00 00       	mov    $0x20,%esi
f0106ea8:	89 e9                	mov    %ebp,%ecx
f0106eaa:	29 ee                	sub    %ebp,%esi
f0106eac:	d3 e2                	shl    %cl,%edx
f0106eae:	89 f1                	mov    %esi,%ecx
f0106eb0:	d3 e8                	shr    %cl,%eax
f0106eb2:	89 e9                	mov    %ebp,%ecx
f0106eb4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106eb8:	8b 04 24             	mov    (%esp),%eax
f0106ebb:	09 54 24 04          	or     %edx,0x4(%esp)
f0106ebf:	89 fa                	mov    %edi,%edx
f0106ec1:	d3 e0                	shl    %cl,%eax
f0106ec3:	89 f1                	mov    %esi,%ecx
f0106ec5:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106ec9:	8b 44 24 10          	mov    0x10(%esp),%eax
f0106ecd:	d3 ea                	shr    %cl,%edx
f0106ecf:	89 e9                	mov    %ebp,%ecx
f0106ed1:	d3 e7                	shl    %cl,%edi
f0106ed3:	89 f1                	mov    %esi,%ecx
f0106ed5:	d3 e8                	shr    %cl,%eax
f0106ed7:	89 e9                	mov    %ebp,%ecx
f0106ed9:	09 f8                	or     %edi,%eax
f0106edb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0106edf:	f7 74 24 04          	divl   0x4(%esp)
f0106ee3:	d3 e7                	shl    %cl,%edi
f0106ee5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106ee9:	89 d7                	mov    %edx,%edi
f0106eeb:	f7 64 24 08          	mull   0x8(%esp)
f0106eef:	39 d7                	cmp    %edx,%edi
f0106ef1:	89 c1                	mov    %eax,%ecx
f0106ef3:	89 14 24             	mov    %edx,(%esp)
f0106ef6:	72 2c                	jb     f0106f24 <__umoddi3+0x134>
f0106ef8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0106efc:	72 22                	jb     f0106f20 <__umoddi3+0x130>
f0106efe:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106f02:	29 c8                	sub    %ecx,%eax
f0106f04:	19 d7                	sbb    %edx,%edi
f0106f06:	89 e9                	mov    %ebp,%ecx
f0106f08:	89 fa                	mov    %edi,%edx
f0106f0a:	d3 e8                	shr    %cl,%eax
f0106f0c:	89 f1                	mov    %esi,%ecx
f0106f0e:	d3 e2                	shl    %cl,%edx
f0106f10:	89 e9                	mov    %ebp,%ecx
f0106f12:	d3 ef                	shr    %cl,%edi
f0106f14:	09 d0                	or     %edx,%eax
f0106f16:	89 fa                	mov    %edi,%edx
f0106f18:	83 c4 14             	add    $0x14,%esp
f0106f1b:	5e                   	pop    %esi
f0106f1c:	5f                   	pop    %edi
f0106f1d:	5d                   	pop    %ebp
f0106f1e:	c3                   	ret    
f0106f1f:	90                   	nop
f0106f20:	39 d7                	cmp    %edx,%edi
f0106f22:	75 da                	jne    f0106efe <__umoddi3+0x10e>
f0106f24:	8b 14 24             	mov    (%esp),%edx
f0106f27:	89 c1                	mov    %eax,%ecx
f0106f29:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0106f2d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106f31:	eb cb                	jmp    f0106efe <__umoddi3+0x10e>
f0106f33:	90                   	nop
f0106f34:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106f38:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0106f3c:	0f 82 0f ff ff ff    	jb     f0106e51 <__umoddi3+0x61>
f0106f42:	e9 1a ff ff ff       	jmp    f0106e61 <__umoddi3+0x71>
