MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 0x00100000
    SRAM (rwx) : ORIGIN = 0x20000000, LENGTH = 0x00040000
}

SECTIONS
{

    .text :
    {
        . = ALIGN(4);
        _text = .;
        KEEP(*(.vector_table))
        *(.text .text* .gnu.linkonce.t.*)
        *(.glue_7t) *(.glue_7)
        *(.rodata .rodata* .gnu.linkonce.r.*)
        *(.ARM.extab* .gnu.linkonce.armextab.*)
        
        . = ALIGN(4);
        KEEP(*(.init))

        . = ALIGN(4);
        __PREINIT_ARRAY_START__ = .;
        KEEP(*(SORT(.preinit_array*)))
        KEEP(*(.preinit_array))
        __PREINIT_ARRAY_END__ = .;
        
        . = ALIGN(4);
        __INIT_ARRAY_START__ = .;
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        __INIT_ARRAY_END__ = .;
        
        . = ALIGN(4);
        KEEP(*(.fini))

        . = ALIGN(4);
        __FINI_ARRAY_START__ = .;
        KEEP(*(.fini_array))
        KEEP(*(SORT(.fini_array.*)))
        __FINI_ARRAY_END__ = .;

        . = ALIGN(4);
        __TEXT_END__ = .;
    } > FLASH

    .data : AT(ADDR(.text) + SIZEOF(.text))
    {
        . = ALIGN(4);
        __DATA_START__ = .;
        *(vtable)
        *(.data .data* .gnu.linkonce.d.*)
        __DATA_END__ = .;
    } > SRAM
    
    PROVIDE_HIDDEN(__exidx_start = .);
    .ARM.exidx :
    {
      *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    } > SRAM
    PROVIDE_HIDDEN(__exidx_end = .);
    
    .bss (NOLOAD):
    {
        . = ALIGN(4);
        __BSS_START__ = .;
        ___BSS_START___start__ = __BSS_START__;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4); 
        __BSS_END__ = .;
        ___BSS_START___end__ = __BSS_END__;
        . = ALIGN(8);
    } > SRAM
    
    . = ALIGN(4);
    _end = . ;
}

/* end of allocated ram is start of heap, heap grows up towards stack*/
PROVIDE(end = _end);

/* top of stack starts at end of ram, stack grows down towards heap */
PROVIDE(__STACK_BASE__ = ORIGIN(SRAM) + LENGTH(SRAM));