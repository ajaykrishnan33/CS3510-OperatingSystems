// implement fork from user space

#include <inc/string.h>
#include <inc/lib.h>

// PTE_COW marks copy-on-write page table entries.
// It is one of the bits explicitly allocated to user processes (PTE_AVAIL).
#define PTE_COW		0x800

//
// Custom page fault handler - if faulting page is copy-on-write,
// map in our own private writable copy.
//
static void
pgfault(struct UTrapframe *utf)
{
	void *addr = (void *) utf->utf_fault_va;
	uint32_t err = utf->utf_err;
	int r;

	// Check that the faulting access was (1) a write, and (2) to a
	// copy-on-write page.  If not, panic.
	// Hint:
	//   Use the read-only page table mappings at uvpt
	//   (see <inc/memlayout.h>).

	// LAB 4: Your code here.

	if((!(err&FEC_WR)) || (!(uvpt[PGNUM(addr)]&PTE_COW))){
		cprintf("%x, %d, %lld\n", addr, err&FEC_U, PGNUM(addr));
		panic("Either not COW page or error not during write.");
	}

	// Allocate a new page, map it at a temporary location (PFTEMP),
	// copy the data from the old page to the new page, then move the new
	// page to the old page's address.
	// Hint:
	//   You should make three system calls.

	// LAB 4: Your code here.

	void *pg_addr = (void*)(PGNUM(addr)*PGSIZE);

	sys_page_alloc(0, (void*)PFTEMP, PTE_P|PTE_U|PTE_W);
	memmove((void*)PFTEMP, pg_addr, PGSIZE);
	sys_page_map(0, (void*)PFTEMP, 0, pg_addr, PTE_U|PTE_P|PTE_W);
	sys_page_unmap(0, (void*)PFTEMP);

}

//
// Map our virtual page pn (address pn*PGSIZE) into the target envid
// at the same virtual address.  If the page is writable or copy-on-write,
// the new mapping must be created copy-on-write, and then our mapping must be
// marked copy-on-write as well.  (Exercise: Why do we need to mark ours
// copy-on-write again if it was already copy-on-write at the beginning of
// this function?)
//
// Returns: 0 on success, < 0 on error.
// It is also OK to panic on error.
//
static int
duppage(envid_t envid, unsigned pn)
{
	int r;

	// LAB 4: Your code here.lld
	// uvpt+pn==(0xef401000){
	// 	cprintf("\n\nHERE\n\n");
	// 	// cprintf("HERE : %x", uvpt[i]);
	// }
	
	if(pn==979969)
		cprintf("\n\nHAHA\n\n");

	pte_t pg_entry = (pte_t)uvpt[pn];

	int perm = PTE_P|PTE_U;

	if(pg_entry&PTE_W || pg_entry&PTE_COW)
		perm = perm | PTE_COW;

	if(sys_page_map(0, (void*)(pn*PGSIZE), envid, (void*)(pn*PGSIZE), perm)<0)
		panic("ERROR in page map system call.");

	if(sys_page_map(envid, (void*)(pn*PGSIZE), 0, (void*)(pn*PGSIZE), perm))
		panic("ERROR in page map system call.");

	return 0;
}

//
// User-level fork with copy-on-write.
// Set up our page fault handler appropriately.
// Create a child.
// Copy our address space and page fault handler setup to the child.
// Then mark the child as runnable and return.
//
// Returns: child's envid to the parent, 0 to the child, < 0 on error.
// It is also OK to panic on error.
//
// Hint:
//   Use uvpd, uvpt, and duppage.
//   Remember to fix "thisenv" in the child process.
//   Neither user exception stack should ever be marked copy-on-write,
//   so you must allocate a new page for the child's user exception stack.
//
envid_t
fork(void)
{
	// LAB 4: Your code here.
		
	set_pgfault_handler(pgfault);

	envid_t pid = sys_exofork();

	if(pid>0)		//parent
	{
		int i,j;
	    for (i=0;i<PDX(UTOP);i++) 
	    {
	        // No page table yet.
	        if (!(uvpd[i] & PTE_P))
	            continue;

	        for (j=0;j<NPTENTRIES;j++) 
	        {
	            unsigned pn = (i << 10) | j;
	            if (pn == PGNUM(UXSTACKTOP - PGSIZE)) {
	                continue;
	            }

	            if (uvpt[pn] & PTE_P)
	                duppage(pid, pn);
	        }
	    }

	    if (sys_page_alloc(pid, (void *)(UXSTACKTOP - PGSIZE), PTE_W | PTE_U | PTE_P)<0)
	    	panic("fork: no phys mem for xstk");

	    // Step 4: set user page fault entry for child.
	    if (sys_env_set_pgfault_upcall(pid, thisenv->env_pgfault_upcall))
	        panic("fork: cannot set pgfault upcall");

	    // Step 5: set child status to ENV_RUNNABLE.
	    if (sys_env_set_status(pid, ENV_RUNNABLE))
	        panic("fork: cannot set env status");

	    return pid;

	}
	else			//child
	{
		int self_id = sys_getenvid();
		thisenv = &envs[ENVX(self_id)];		
		return 0;
	}

	return 0;

}

// Challenge!
int
sfork(void)
{
	panic("sfork not implemented");
	return -E_INVAL;
}
