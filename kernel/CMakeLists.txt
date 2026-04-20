# SPDX-License-Identifier: Apache-2.0

# kernel is a normal CMake library and not a zephyr_library because it
# should usually not be --whole-archive'd

zephyr_syscall_header(
  ${ZEPHYR_BASE}/include/zephyr/device.h
  ${ZEPHYR_BASE}/include/zephyr/kernel.h
  ${ZEPHYR_BASE}/include/zephyr/sys/kobject.h
  ${ZEPHYR_BASE}/include/zephyr/sys/time_units.h
)

# Helper macro to append files to the kernel_files list
macro(kernel_sources_ifdef feature_toggle)
  if(${${feature_toggle}})
    list(APPEND kernel_files ${ARGN})
  endif()
endmacro()

macro(kernel_sources)
    list(APPEND kernel_files ${ARGN})
endmacro()

if(NOT CONFIG_ERRNO_IN_TLS AND NOT CONFIG_LIBC_ERRNO)
  zephyr_syscall_header(${ZEPHYR_BASE}/include/zephyr/sys/errno_private.h)
endif()

zephyr_syscall_header_ifdef(
  CONFIG_ATOMIC_OPERATIONS_C
  ${ZEPHYR_BASE}/include/zephyr/sys/atomic_c.h
)

zephyr_syscall_header_ifdef(
  CONFIG_MMU
  ${ZEPHYR_BASE}/include/zephyr/kernel/mm.h
  ${ZEPHYR_BASE}/include/zephyr/sys/mem_manage.h
)

zephyr_syscall_header_ifdef(
  CONFIG_DEMAND_PAGING
  ${ZEPHYR_BASE}/include/zephyr/kernel/mm/demand_paging.h
)

# If a pre-built static library containing kernel code exists in
# this directory, libkernel.a, link it with the application code
# instead of building from source.
zephyr_library_get_current_dir_lib_name(${ZEPHYR_BASE} libkernel_stem)
set(libkernel ${CMAKE_CURRENT_SOURCE_DIR}/lib${libkernel_stem}${CMAKE_STATIC_LIBRARY_SUFFIX})
unset(libkernel_stem)

if(EXISTS ${libkernel})

add_library(kernel INTERFACE)
target_link_libraries(kernel INTERFACE ${libkernel})

else()

# FIXME: SHADOW_VARS: Remove this once we have enabled -Wshadow globally.
add_compile_options($<TARGET_PROPERTY:compiler,warning_shadow_variables>)

kernel_sources(
  main_weak.c
  banner.c
  busy_wait.c
  device.c
  errno.c
  init.c
  float.c
  version.c
  )

# Toolchain workaround: on ARM Thumb, gcc will normally enable
# -fomit-frame-pointer at all optimization levels except -O0.  When
# frame pointers ARE enabled, gcc will also infuriatingly disallow a
# clobber of the r7 frame pointer register in inline assembly
# (vs. just spilling filling as needed).  Our optimized arch_switch
# requires the ability to clobber this (callee-saved) register.  Turn
# the flag back on for the two files that need it.  (The error
# behavior only gets modified at the level of a whole file, I tried
# #pragmas and attributes to change the code generation for the
# specific functions without success).
if(CONFIG_CPU_CORTEX_M)
  if(CONFIG_NO_OPTIMIZATIONS)
    if(${COMPILER} STREQUAL "gcc")
      set_source_files_properties(init.c PROPERTIES COMPILE_OPTIONS -fomit-frame-pointer)
      set_source_files_properties(sched.c PROPERTIES COMPILE_OPTIONS -fomit-frame-pointer)
    endif()
  endif()
endif()

# fatal.c is replaced by the Gale module when CONFIG_GALE_KERNEL_FATAL=y
if(NOT CONFIG_GALE_KERNEL_FATAL)
  kernel_sources(fatal.c)
endif()

# kheap.c is replaced by the Gale module when CONFIG_GALE_KERNEL_KHEAP=y
if(NOT CONFIG_GALE_KERNEL_KHEAP)
  kernel_sources(kheap.c)
endif()

if(CONFIG_SCHED_CPU_MASK AND NOT CONFIG_GALE_KERNEL_CPU_MASK)
  kernel_sources(cpu_mask.c)
endif()

kernel_sources_ifdef(CONFIG_MULTITHREADING
  idle.c
  system_work_q.c
  )

# work.c: Gale provides decision helpers only (2 of 25+ functions).
# Keep work.c always compiled to avoid missing k_work_* link errors.
kernel_sources_ifdef(CONFIG_MULTITHREADING work.c)

# condvar.c: Gale verifies condvar by composition (no C shim replacement).
# Keep the original always compiled.
kernel_sources_ifdef(CONFIG_MULTITHREADING condvar.c)

# thread.c is replaced by the Gale module when CONFIG_GALE_KERNEL_THREAD_LIFECYCLE=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_THREAD_LIFECYCLE)
  kernel_sources(thread.c)
endif()

# sched.c is replaced by the Gale module when CONFIG_GALE_KERNEL_SCHED=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_SCHED)
  kernel_sources(sched.c)
endif()

# mailbox.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MBOX=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_MBOX)
  kernel_sources(mailbox.c)
endif()

# queue.c is replaced by the Gale module when CONFIG_GALE_KERNEL_QUEUE=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_QUEUE)
  kernel_sources(queue.c)
endif()


# pipe.c is replaced by the Gale module when CONFIG_GALE_KERNEL_PIPE=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_PIPE)
  kernel_sources(pipe.c)
endif()

# stack.c is replaced by the Gale module when CONFIG_GALE_KERNEL_STACK=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_STACK)
  kernel_sources(stack.c)
endif()

# msg_q.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MSGQ=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_MSGQ)
  kernel_sources(msg_q.c)
endif()

# mutex.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MUTEX=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_MUTEX)
  kernel_sources(mutex.c)
endif()

# sem.c is replaced by the Gale module when CONFIG_GALE_KERNEL_SEM=y
if(CONFIG_MULTITHREADING AND NOT CONFIG_GALE_KERNEL_SEM)
  kernel_sources(sem.c)
endif()

# mem_slab.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MEM_SLAB=y
if(NOT CONFIG_GALE_KERNEL_MEM_SLAB)
  kernel_sources(mem_slab.c)
endif()


if(CONFIG_MULTITHREADING)
if(CONFIG_SCHED_SCALABLE OR CONFIG_WAITQ_SCALABLE)
kernel_sources(priority_queues.c)
endif()

# smp.c: gale_smp_state adds verified CPU-count decision helpers alongside
# the original.  It does NOT replace the full smp.c API (z_smp_global_lock,
# z_smp_init, z_smp_current_get, etc.), so smp.c must always be compiled
# when CONFIG_SMP is active.
if(CONFIG_SMP)
  kernel_sources(smp.c)
endif()
# ipi.c: gale_ipi adds a verified ipi_mask_create helper (gale_ipi_mask_create)
# alongside the original.  It does NOT replace flag_ipi, signal_pending_ipi,
# ipi_mask_create, or z_sched_ipi, so ipi.c must always be compiled when
# CONFIG_SMP is active.
if(CONFIG_SMP)
  kernel_sources(ipi.c)
endif()
else() # CONFIG_MULTITHREADING
kernel_sources(nothread.c)
endif() # CONFIG_MULTITHREADING

# timeslicing.c is replaced by the Gale module when CONFIG_GALE_KERNEL_TIMESLICE=y
if(CONFIG_TIMESLICING AND NOT CONFIG_GALE_KERNEL_TIMESLICE)
  kernel_sources(timeslicing.c)
endif()
if(CONFIG_SPIN_VALIDATE AND NOT CONFIG_GALE_KERNEL_SPINLOCK_VALIDATE)
  kernel_sources(spinlock_validate.c)
endif()
kernel_sources_ifdef(CONFIG_IRQ_OFFLOAD irq_offload.c)
kernel_sources_ifdef(CONFIG_BOOTARGS boot_args.c)
kernel_sources_ifdef(CONFIG_THREAD_MONITOR thread_monitor.c)
kernel_sources_ifdef(CONFIG_DEMAND_PAGING_STATS paging/statistics.c)

add_library(kernel ${kernel_files})

# Kernel files has the macro __ZEPHYR_SUPERVISOR__ set so that it
# optimizes the code when userspace is enabled.

set_target_properties(
  kernel
  PROPERTIES
  COMPILE_DEFINITIONS
  __ZEPHYR_SUPERVISOR__
  )

target_sources_ifdef(CONFIG_REQUIRES_STACK_CANARIES   kernel PRIVATE compiler_stack_protect.c)
# timeout.c and timer.c: Gale provides decision helpers but does NOT
# replace these files — they define sys_clock_announce, z_abort_timeout,
# and other functions that the kernel depends on.
target_sources_ifdef(CONFIG_SYS_CLOCK_EXISTS kernel PRIVATE timeout.c timer.c)
if(CONFIG_TIMER_READS_ITS_FREQUENCY_AT_RUNTIME OR CONFIG_SYSTEM_CLOCK_HW_CYCLES_PER_SEC_RUNTIME_UPDATE)
  target_sources(kernel PRIVATE sys_clock_hw_cycles.c)
endif()
target_sources_ifdef(CONFIG_ATOMIC_OPERATIONS_C   kernel PRIVATE atomic_c.c)
target_sources_ifdef(CONFIG_MMU                   kernel PRIVATE mmu.c)
# poll.c is replaced by the Gale module when CONFIG_GALE_KERNEL_POLL=y
if(CONFIG_POLL AND NOT CONFIG_GALE_KERNEL_POLL)
  target_sources(kernel PRIVATE poll.c)
endif()
# events.c is replaced by the Gale module when CONFIG_GALE_KERNEL_EVENT=y
if(CONFIG_EVENTS AND NOT CONFIG_GALE_KERNEL_EVENT)
  target_sources(kernel PRIVATE events.c)
endif()
target_sources_ifdef(CONFIG_SCHED_THREAD_USAGE    kernel PRIVATE usage.c)
target_sources_ifdef(CONFIG_OBJ_CORE              kernel PRIVATE obj_core.c)

# mempool.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MEMPOOL=y
if(CONFIG_KERNEL_MEM_POOL AND NOT CONFIG_GALE_KERNEL_MEMPOOL)
  target_sources(kernel PRIVATE mempool.c)

  if(CONFIG_HEAP_MEM_POOL_IGNORE_MIN)
    set(final_heap_size ${CONFIG_HEAP_MEM_POOL_SIZE})
  else()
    # Import all custom HEAP_MEM_POOL size requirements
    import_kconfig(CONFIG_HEAP_MEM_POOL_ADD_SIZE_ ${DOTCONFIG} add_size_keys)

    # Calculate the sum of all "ADD_SIZE" requirements
    set(add_size_sum 0)
    foreach(add_size ${add_size_keys})
      math(EXPR add_size_sum "${add_size_sum} + ${${add_size}}")
    endforeach()

    if(CONFIG_HEAP_MEM_POOL_SIZE LESS "${add_size_sum}")
      # Only warn if default value 0 has been modified
      if(NOT CONFIG_HEAP_MEM_POOL_SIZE EQUAL 0)
        message(WARNING "
        CONFIG_HEAP_MEM_POOL_SIZE is less than requested minimum:
          ${CONFIG_HEAP_MEM_POOL_SIZE} < ${add_size_sum}
        Setting the system heap size to ${add_size_sum}")
      endif()

      set(final_heap_size ${add_size_sum})
    else()
      # CONFIG_HEAP_MEM_POOL_SIZE was greater than the sum of the requirements
      set(final_heap_size ${CONFIG_HEAP_MEM_POOL_SIZE})
    endif()

  endif()

  zephyr_compile_definitions(K_HEAP_MEM_POOL_SIZE=${final_heap_size})
endif()

# The last 2 files inside the target_sources_ifdef should be
# userspace_handler.c and userspace.c. If not the linker would complain.
# This order has to be maintained. Any new file should be placed
# above these 2 files.
# futex.c is replaced by the Gale module when CONFIG_GALE_KERNEL_FUTEX=y
if(CONFIG_USERSPACE AND NOT CONFIG_GALE_KERNEL_FUTEX)
  target_sources(kernel PRIVATE futex.c)
endif()
# mem_domain.c is replaced by the Gale module when CONFIG_GALE_KERNEL_MEM_DOMAIN=y
if(CONFIG_USERSPACE AND NOT CONFIG_GALE_KERNEL_MEM_DOMAIN)
  target_sources(kernel PRIVATE mem_domain.c)
endif()
# userspace_handler.c is always needed (syscall marshaling)
target_sources_ifdef(CONFIG_USERSPACE kernel PRIVATE userspace_handler.c)
# userspace.c is replaced by the Gale module when CONFIG_GALE_KERNEL_USERSPACE=y
if(CONFIG_USERSPACE AND NOT CONFIG_GALE_KERNEL_USERSPACE)
  target_sources(kernel PRIVATE userspace.c)
endif()

# dynamic.c is replaced by the Gale module when CONFIG_GALE_KERNEL_DYNAMIC=y
if(CONFIG_DYNAMIC_THREAD AND NOT CONFIG_GALE_KERNEL_DYNAMIC)
  target_sources(kernel PRIVATE dynamic.c)
elseif(NOT CONFIG_DYNAMIC_THREAD)
  target_sources(kernel PRIVATE dynamic_disabled.c)
endif()

target_include_directories(kernel PRIVATE
  ${ZEPHYR_BASE}/kernel/include
  ${ARCH_DIR}/${ARCH}/include
  )

target_link_libraries(kernel zephyr_interface)

endif()

# Optionally build kernel sources without LTO
if(CONFIG_KERNEL_NO_LTO)
  set_target_properties(kernel PROPERTIES LTO 0)
endif()

add_dependencies(kernel zephyr_generated_headers)

unset(libkernel)
