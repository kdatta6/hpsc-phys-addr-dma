Problem Summary
---------------

There are two versions of the code: dmatest_page.c and dmatest_single.c.  They both have a “dmatest_with_virt_addr()” function that is meant to replace the existing “dmatest_alloc_test_data()” function.  Both the old and new functions are called to (separately) initialize the “src” and “dst” data structures, both of which are pointers to “dmatest_data” structs.  In dmatest_alloc_test_data(), kmalloc() is used to allocate the “d->raw” and “d->aligned” arrays that are used for DMA operations (this is a DMA_MEMCPY operation, so d->cnt is 1).  In contrast, when using dmatest_with_virt_addr(), first a call to memremap() is needed in order to convert the source and destination physical addresses to virtual addresses, as well as to bring those memory ranges into kernel space so that we can directly read and write to them.  After the translation, these virtual addresses are passed to dmatest_with_virt_addr() so that src->raw[0] points to the virtual address mapped to 0x83600000.  Similarly, dst->raw[0] points to the virtual address mapped to 0x83601000.  There is no additional malloc’ing performed at these memory locations.

Here is additional information about dmatest_page.c and dmatest_single.c.  The original dmatest.c code used dma_map_page() to perform DMAs, but Alexei recommended using dma_map_single() to avoid referencing pages directly (I believe).  Thus, the dma_map_single() function is used in dmatest_single.c, but there is a minor issue that should be fixed- the call to “dmaengine_unmap_put(um)” generates a CPU unmap warning followed by an exception stack (but the code still runs).  This does not happen with the dmatest_page.c code since it is the original version of the code.

As for functionality, both codes work successfully when using dmatest_alloc_test_data(), although dmatest_single.c will generate the unmap warnings discussed above.  However, neither code performs a correct DMA when using dmatest_with_virt_addr().  When running dmatest_page.c, the code hangs sometime during the DMA operation.  If it prints the destination buffer after the DMA, it shows that it wasn’t updated at all, even though dma_async_is_tx_complete() returns 0 (success).  Similarly, when running dmatest_single.c, the code again hangs and the DMA operation doesn’t occur.  David and I have also seen that the virtual address associated with the destination buffer was out of range when using “dmatest_with_virt_addr()” (“kfree_debugcheck: out of range ptr ffffff8008c6d000h”).  This may be related to the “dmaengine_unmap_put(um)” warnings discussed above, so dmatest_single.c should be debugged.

Finally, the choice of physical addresses was based on the hpsc.dts file, where the following is listed:

reserved-memory {
		#address-cells = <0x2>;
 		#size-cells = <0x2>;
 		ranges;

 		ramoops@0x83200000 {
		compatible = "ramoops";
 		reg = <0x0 0x83200000 0x0 0x400000>;
		ftrace-size = <0x400000>;
 		};

 		shm@0x83600000 {
 		reg = <0x0 0x83600000 0x0 0x10000>;
 		linux,phandle = <0x2>;
		phandle = <0x2>;
		};

The memory range at 0x83600000 is a shared memory space.

Notes
-----

Both dmatest_page.c and dmatest_single.c should be copied into: linux-hpsc/drivers/dma/dmatest.c.
dma-standalone-tester.sh should be copied into HPSC QEMU and then executed in order to trigger the code in dmatest.c.

Things to try
-------------

1.  The best approach to understand why the DMA isn’t occuring using physical addresses is to turn off the IOMMU.  Alexei suggested that the best way to do go through menuconfig before building the linux kernel, but I haven’t tried this yet.
2.  Print out the full source and destination buffers to make sure that the DMA isn’t updating any of the destination buffer.
3.  Fix any lingering bugs in the dmatest_single.c code.

Other debugging tips
--------------------

1.  The QEMU monitor can be used in conjunction with gdb to print out the contents at a specific physical address by using something like: 'x/x 0x83600000'
2.  David suggested that to monitor exceptions, the “int” option can be added to the QEMU -d flag.  In addition, to print every instruction, the “in_asm” option can be added as well (so something like “…-d “fdt, … , int, in_asm” “).
