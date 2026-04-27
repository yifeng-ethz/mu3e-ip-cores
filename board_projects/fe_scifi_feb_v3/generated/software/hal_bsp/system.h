/*
 * system.h - SOPC Builder system and BSP software package information
 *
 * Machine generated for CPU 'cpu' in SOPC Builder design 'feb_bringup_system'
 * SOPC Builder design path: ../../nios.sopcinfo
 *
 * Generated: Wed Mar 18 18:24:54 CET 2026
 */

/*
 * DO NOT MODIFY THIS FILE
 *
 * Changing this file will have subtle consequences
 * which will almost certainly lead to a nonfunctioning
 * system. If you do modify this file, be aware that your
 * changes will be overwritten and lost when this file
 * is generated again.
 *
 * DO NOT MODIFY THIS FILE
 */

/*
 * License Agreement
 *
 * Copyright (c) 2008
 * Altera Corporation, San Jose, California, USA.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * This agreement shall be governed in all respects by the laws of the State
 * of California and by the laws of the United States of America.
 */

#ifndef __SYSTEM_H_
#define __SYSTEM_H_

/* Include definitions from linker script generator */
#include "linker.h"


/*
 * CPU configuration
 *
 */

#define ALT_CPU_ARCHITECTURE "altera_nios2_gen2"
#define ALT_CPU_BIG_ENDIAN 0
#define ALT_CPU_BREAK_ADDR 0x70000020
#define ALT_CPU_CPU_ARCH_NIOS2_R1
#define ALT_CPU_CPU_FREQ 50000000u
#define ALT_CPU_CPU_ID_SIZE 1
#define ALT_CPU_CPU_ID_VALUE 0x00000000
#define ALT_CPU_CPU_IMPLEMENTATION "tiny"
#define ALT_CPU_DATA_ADDR_WIDTH 0x1f
#define ALT_CPU_DCACHE_LINE_SIZE 0
#define ALT_CPU_DCACHE_LINE_SIZE_LOG2 0
#define ALT_CPU_DCACHE_SIZE 0
#define ALT_CPU_EXCEPTION_ADDR 0x10000020
#define ALT_CPU_FLASH_ACCELERATOR_LINES 0
#define ALT_CPU_FLASH_ACCELERATOR_LINE_SIZE 0
#define ALT_CPU_FLUSHDA_SUPPORTED
#define ALT_CPU_FREQ 50000000
#define ALT_CPU_HARDWARE_DIVIDE_PRESENT 0
#define ALT_CPU_HARDWARE_MULTIPLY_PRESENT 0
#define ALT_CPU_HARDWARE_MULX_PRESENT 0
#define ALT_CPU_HAS_DEBUG_CORE 1
#define ALT_CPU_HAS_DEBUG_STUB
#define ALT_CPU_HAS_ILLEGAL_INSTRUCTION_EXCEPTION
#define ALT_CPU_HAS_JMPI_INSTRUCTION
#define ALT_CPU_ICACHE_LINE_SIZE 0
#define ALT_CPU_ICACHE_LINE_SIZE_LOG2 0
#define ALT_CPU_ICACHE_SIZE 0
#define ALT_CPU_INST_ADDR_WIDTH 0x1f
#define ALT_CPU_NAME "cpu"
#define ALT_CPU_OCI_VERSION 1
#define ALT_CPU_RESET_ADDR 0x10000000


/*
 * CPU configuration (with legacy prefix - don't use these anymore)
 *
 */

#define NIOS2_BIG_ENDIAN 0
#define NIOS2_BREAK_ADDR 0x70000020
#define NIOS2_CPU_ARCH_NIOS2_R1
#define NIOS2_CPU_FREQ 50000000u
#define NIOS2_CPU_ID_SIZE 1
#define NIOS2_CPU_ID_VALUE 0x00000000
#define NIOS2_CPU_IMPLEMENTATION "tiny"
#define NIOS2_DATA_ADDR_WIDTH 0x1f
#define NIOS2_DCACHE_LINE_SIZE 0
#define NIOS2_DCACHE_LINE_SIZE_LOG2 0
#define NIOS2_DCACHE_SIZE 0
#define NIOS2_EXCEPTION_ADDR 0x10000020
#define NIOS2_FLASH_ACCELERATOR_LINES 0
#define NIOS2_FLASH_ACCELERATOR_LINE_SIZE 0
#define NIOS2_FLUSHDA_SUPPORTED
#define NIOS2_HARDWARE_DIVIDE_PRESENT 0
#define NIOS2_HARDWARE_MULTIPLY_PRESENT 0
#define NIOS2_HARDWARE_MULX_PRESENT 0
#define NIOS2_HAS_DEBUG_CORE 1
#define NIOS2_HAS_DEBUG_STUB
#define NIOS2_HAS_ILLEGAL_INSTRUCTION_EXCEPTION
#define NIOS2_HAS_JMPI_INSTRUCTION
#define NIOS2_ICACHE_LINE_SIZE 0
#define NIOS2_ICACHE_LINE_SIZE_LOG2 0
#define NIOS2_ICACHE_SIZE 0
#define NIOS2_INST_ADDR_WIDTH 0x1f
#define NIOS2_OCI_VERSION 1
#define NIOS2_RESET_ADDR 0x10000000


/*
 * Define for each module class mastered by the CPU
 *
 */

#define __ALTERA_AVALON_I2C
#define __ALTERA_AVALON_JTAG_UART
#define __ALTERA_AVALON_ONCHIP_MEMORY2
#define __ALTERA_AVALON_PIO
#define __ALTERA_AVALON_SPI
#define __ALTERA_AVALON_SYSID_QSYS
#define __ALTERA_AVALON_TIMER
#define __ALTERA_NIOS2_GEN2
#define __AVALON_PROXY


/*
 * System configuration
 *
 */

#define ALT_DEVICE_FAMILY "Arria V"
#define ALT_ENHANCED_INTERRUPT_API_PRESENT
#define ALT_IRQ_BASE NULL
#define ALT_LOG_PORT "/dev/null"
#define ALT_LOG_PORT_BASE 0x0
#define ALT_LOG_PORT_DEV null
#define ALT_LOG_PORT_TYPE ""
#define ALT_NUM_EXTERNAL_INTERRUPT_CONTROLLERS 0
#define ALT_NUM_INTERNAL_INTERRUPT_CONTROLLERS 1
#define ALT_NUM_INTERRUPT_CONTROLLERS 1
#define ALT_STDERR "/dev/jtag_uart"
#define ALT_STDERR_BASE 0x700f0010
#define ALT_STDERR_DEV jtag_uart
#define ALT_STDERR_IS_JTAG_UART
#define ALT_STDERR_PRESENT
#define ALT_STDERR_TYPE "altera_avalon_jtag_uart"
#define ALT_STDIN "/dev/jtag_uart"
#define ALT_STDIN_BASE 0x700f0010
#define ALT_STDIN_DEV jtag_uart
#define ALT_STDIN_IS_JTAG_UART
#define ALT_STDIN_PRESENT
#define ALT_STDIN_TYPE "altera_avalon_jtag_uart"
#define ALT_STDOUT "/dev/jtag_uart"
#define ALT_STDOUT_BASE 0x700f0010
#define ALT_STDOUT_DEV jtag_uart
#define ALT_STDOUT_IS_JTAG_UART
#define ALT_STDOUT_PRESENT
#define ALT_STDOUT_TYPE "altera_avalon_jtag_uart"
#define ALT_SYSTEM_NAME "feb_bringup_system"


/*
 * avm_mscb configuration
 *
 */

#define ALT_MODULE_CLASS_avm_mscb avalon_proxy
#define AVM_MSCB_BASE 0x70030000
#define AVM_MSCB_IRQ -1
#define AVM_MSCB_IRQ_INTERRUPT_CONTROLLER_ID -1
#define AVM_MSCB_NAME "/dev/avm_mscb"
#define AVM_MSCB_SPAN 64
#define AVM_MSCB_TYPE "avalon_proxy"


/*
 * avm_pod configuration
 *
 */

#define ALT_MODULE_CLASS_avm_pod avalon_proxy
#define AVM_POD_BASE 0x70020000
#define AVM_POD_IRQ -1
#define AVM_POD_IRQ_INTERRUPT_CONTROLLER_ID -1
#define AVM_POD_NAME "/dev/avm_pod"
#define AVM_POD_SPAN 65536
#define AVM_POD_TYPE "avalon_proxy"


/*
 * avm_qsfp configuration
 *
 */

#define ALT_MODULE_CLASS_avm_qsfp avalon_proxy
#define AVM_QSFP_BASE 0x70010000
#define AVM_QSFP_IRQ -1
#define AVM_QSFP_IRQ_INTERRUPT_CONTROLLER_ID -1
#define AVM_QSFP_NAME "/dev/avm_qsfp"
#define AVM_QSFP_SPAN 65536
#define AVM_QSFP_TYPE "avalon_proxy"


/*
 * avm_sc configuration
 *
 */

#define ALT_MODULE_CLASS_avm_sc avalon_proxy
#define AVM_SC_BASE 0x70080000
#define AVM_SC_IRQ -1
#define AVM_SC_IRQ_INTERRUPT_CONTROLLER_ID -1
#define AVM_SC_NAME "/dev/avm_sc"
#define AVM_SC_SPAN 262144
#define AVM_SC_TYPE "avalon_proxy"


/*
 * hal configuration
 *
 */

#define ALT_INCLUDE_INSTRUCTION_RELATED_EXCEPTION_API
#define ALT_MAX_FD 32
#define ALT_SYS_CLK TIMER
#define ALT_TIMESTAMP_CLK TIMER_TS


/*
 * i2c configuration
 *
 */

#define ALT_MODULE_CLASS_i2c altera_avalon_i2c
#define I2C_BASE 0x700f0200
#define I2C_FIFO_DEPTH 4
#define I2C_FREQ 50000000
#define I2C_IRQ 4
#define I2C_IRQ_INTERRUPT_CONTROLLER_ID 0
#define I2C_NAME "/dev/i2c"
#define I2C_SPAN 64
#define I2C_TYPE "altera_avalon_i2c"
#define I2C_USE_AV_ST 0


/*
 * i2c_mask configuration
 *
 */

#define ALT_MODULE_CLASS_i2c_mask altera_avalon_pio
#define I2C_MASK_BASE 0x700f02a0
#define I2C_MASK_BIT_CLEARING_EDGE_REGISTER 0
#define I2C_MASK_BIT_MODIFYING_OUTPUT_REGISTER 1
#define I2C_MASK_CAPTURE 0
#define I2C_MASK_DATA_WIDTH 32
#define I2C_MASK_DO_TEST_BENCH_WIRING 0
#define I2C_MASK_DRIVEN_SIM_VALUE 0
#define I2C_MASK_EDGE_TYPE "NONE"
#define I2C_MASK_FREQ 50000000
#define I2C_MASK_HAS_IN 0
#define I2C_MASK_HAS_OUT 1
#define I2C_MASK_HAS_TRI 0
#define I2C_MASK_IRQ -1
#define I2C_MASK_IRQ_INTERRUPT_CONTROLLER_ID -1
#define I2C_MASK_IRQ_TYPE "NONE"
#define I2C_MASK_NAME "/dev/i2c_mask"
#define I2C_MASK_RESET_VALUE 0
#define I2C_MASK_SPAN 32
#define I2C_MASK_TYPE "altera_avalon_pio"


/*
 * jtag_uart configuration
 *
 */

#define ALT_MODULE_CLASS_jtag_uart altera_avalon_jtag_uart
#define JTAG_UART_BASE 0x700f0010
#define JTAG_UART_IRQ 2
#define JTAG_UART_IRQ_INTERRUPT_CONTROLLER_ID 0
#define JTAG_UART_NAME "/dev/jtag_uart"
#define JTAG_UART_READ_DEPTH 64
#define JTAG_UART_READ_THRESHOLD 8
#define JTAG_UART_SPAN 8
#define JTAG_UART_TYPE "altera_avalon_jtag_uart"
#define JTAG_UART_WRITE_DEPTH 64
#define JTAG_UART_WRITE_THRESHOLD 8


/*
 * pio configuration
 *
 */

#define ALT_MODULE_CLASS_pio altera_avalon_pio
#define PIO_BASE 0x700f0200
#define PIO_BIT_CLEARING_EDGE_REGISTER 0
#define PIO_BIT_MODIFYING_OUTPUT_REGISTER 1
#define PIO_CAPTURE 0
#define PIO_DATA_WIDTH 32
#define PIO_DO_TEST_BENCH_WIRING 0
#define PIO_DRIVEN_SIM_VALUE 0
#define PIO_EDGE_TYPE "NONE"
#define PIO_FREQ 50000000
#define PIO_HAS_IN 0
#define PIO_HAS_OUT 1
#define PIO_HAS_TRI 0
#define PIO_IRQ -1
#define PIO_IRQ_INTERRUPT_CONTROLLER_ID -1
#define PIO_IRQ_TYPE "NONE"
#define PIO_NAME "/dev/pio"
#define PIO_RESET_VALUE 0
#define PIO_SPAN 32
#define PIO_TYPE "altera_avalon_pio"


/*
 * si_out configuration
 *
 */

#define ALT_MODULE_CLASS_si_out altera_avalon_pio
#define SI_OUT_BASE 0x700f0220
#define SI_OUT_BIT_CLEARING_EDGE_REGISTER 0
#define SI_OUT_BIT_MODIFYING_OUTPUT_REGISTER 1
#define SI_OUT_CAPTURE 0
#define SI_OUT_DATA_WIDTH 16
#define SI_OUT_DO_TEST_BENCH_WIRING 0
#define SI_OUT_DRIVEN_SIM_VALUE 0
#define SI_OUT_EDGE_TYPE "NONE"
#define SI_OUT_FREQ 50000000
#define SI_OUT_HAS_IN 0
#define SI_OUT_HAS_OUT 1
#define SI_OUT_HAS_TRI 0
#define SI_OUT_IRQ -1
#define SI_OUT_IRQ_INTERRUPT_CONTROLLER_ID -1
#define SI_OUT_IRQ_TYPE "NONE"
#define SI_OUT_NAME "/dev/si_out"
#define SI_OUT_RESET_VALUE 60
#define SI_OUT_SPAN 32
#define SI_OUT_TYPE "altera_avalon_pio"


/*
 * si_in configuration
 *
 */

#define ALT_MODULE_CLASS_si_in altera_avalon_pio
#define SI_IN_BASE 0x700f0240
#define SI_IN_BIT_CLEARING_EDGE_REGISTER 0
#define SI_IN_BIT_MODIFYING_OUTPUT_REGISTER 0
#define SI_IN_CAPTURE 0
#define SI_IN_DATA_WIDTH 8
#define SI_IN_DO_TEST_BENCH_WIRING 0
#define SI_IN_DRIVEN_SIM_VALUE 0
#define SI_IN_EDGE_TYPE "NONE"
#define SI_IN_FREQ 50000000
#define SI_IN_HAS_IN 1
#define SI_IN_HAS_OUT 0
#define SI_IN_HAS_TRI 0
#define SI_IN_IRQ -1
#define SI_IN_IRQ_INTERRUPT_CONTROLLER_ID -1
#define SI_IN_IRQ_TYPE "NONE"
#define SI_IN_NAME "/dev/si_in"
#define SI_IN_RESET_VALUE 0
#define SI_IN_SPAN 16
#define SI_IN_TYPE "altera_avalon_pio"


/*
 * dbg0 configuration
 *
 */

#define ALT_MODULE_CLASS_dbg0 altera_avalon_pio
#define DBG0_BASE 0x700f0260
#define DBG0_BIT_CLEARING_EDGE_REGISTER 0
#define DBG0_BIT_MODIFYING_OUTPUT_REGISTER 1
#define DBG0_CAPTURE 0
#define DBG0_DATA_WIDTH 32
#define DBG0_DO_TEST_BENCH_WIRING 0
#define DBG0_DRIVEN_SIM_VALUE 0
#define DBG0_EDGE_TYPE "NONE"
#define DBG0_FREQ 50000000
#define DBG0_HAS_IN 0
#define DBG0_HAS_OUT 1
#define DBG0_HAS_TRI 0
#define DBG0_IRQ -1
#define DBG0_IRQ_INTERRUPT_CONTROLLER_ID -1
#define DBG0_IRQ_TYPE "NONE"
#define DBG0_NAME "/dev/dbg0"
#define DBG0_RESET_VALUE 0
#define DBG0_SPAN 32
#define DBG0_TYPE "altera_avalon_pio"


/*
 * dbg1 configuration
 *
 */

#define ALT_MODULE_CLASS_dbg1 altera_avalon_pio
#define DBG1_BASE 0x700f0280
#define DBG1_BIT_CLEARING_EDGE_REGISTER 0
#define DBG1_BIT_MODIFYING_OUTPUT_REGISTER 1
#define DBG1_CAPTURE 0
#define DBG1_DATA_WIDTH 32
#define DBG1_DO_TEST_BENCH_WIRING 0
#define DBG1_DRIVEN_SIM_VALUE 0
#define DBG1_EDGE_TYPE "NONE"
#define DBG1_FREQ 50000000
#define DBG1_HAS_IN 0
#define DBG1_HAS_OUT 1
#define DBG1_HAS_TRI 0
#define DBG1_IRQ -1
#define DBG1_IRQ_INTERRUPT_CONTROLLER_ID -1
#define DBG1_IRQ_TYPE "NONE"
#define DBG1_NAME "/dev/dbg1"
#define DBG1_RESET_VALUE 0
#define DBG1_SPAN 32
#define DBG1_TYPE "altera_avalon_pio"


/*
 * ram configuration
 *
 */

#define ALT_MODULE_CLASS_ram altera_avalon_onchip_memory2
#define RAM_ALLOW_IN_SYSTEM_MEMORY_CONTENT_EDITOR 0
#define RAM_ALLOW_MRAM_SIM_CONTENTS_ONLY_FILE 0
#define RAM_BASE 0x10000000
#define RAM_CONTENTS_INFO ""
#define RAM_DUAL_PORT 0
#define RAM_GUI_RAM_BLOCK_TYPE "AUTO"
#define RAM_INIT_CONTENTS_FILE "nios_ram"
#define RAM_INIT_MEM_CONTENT 1
#define RAM_INSTANCE_ID "NONE"
#define RAM_IRQ -1
#define RAM_IRQ_INTERRUPT_CONTROLLER_ID -1
#define RAM_NAME "/dev/ram"
#define RAM_NON_DEFAULT_INIT_FILE_ENABLED 1
#define RAM_RAM_BLOCK_TYPE "AUTO"
#define RAM_READ_DURING_WRITE_MODE "DONT_CARE"
#define RAM_SINGLE_CLOCK_OP 0
#define RAM_SIZE_MULTIPLE 1
#define RAM_SIZE_VALUE 131072
#define RAM_SPAN 131072
#define RAM_TYPE "altera_avalon_onchip_memory2"
#define RAM_WRITABLE 1


/*
 * spi configuration
 *
 */

#define ALT_MODULE_CLASS_spi altera_avalon_spi
#define SPI_BASE 0x700f0240
#define SPI_CLOCKMULT 1
#define SPI_CLOCKPHASE 0
#define SPI_CLOCKPOLARITY 0
#define SPI_CLOCKUNITS "Hz"
#define SPI_DATABITS 8
#define SPI_DATAWIDTH 16
#define SPI_DELAYMULT "1.0E-9"
#define SPI_DELAYUNITS "ns"
#define SPI_EXTRADELAY 0
#define SPI_INSERT_SYNC 0
#define SPI_IRQ 5
#define SPI_IRQ_INTERRUPT_CONTROLLER_ID 0
#define SPI_ISMASTER 1
#define SPI_LSBFIRST 0
#define SPI_NAME "/dev/spi"
#define SPI_NUMSLAVES 16
#define SPI_PREFIX "spi_"
#define SPI_SPAN 32
#define SPI_SYNC_REG_DEPTH 2
#define SPI_TARGETCLOCK 128000u
#define SPI_TARGETSSDELAY "0.0"
#define SPI_TYPE "altera_avalon_spi"


/*
 * spi_si configuration
 *
 */

#define ALT_MODULE_CLASS_spi_si altera_avalon_spi
#define SPI_SI_BASE 0x700f0260
#define SPI_SI_CLOCKMULT 1
#define SPI_SI_CLOCKPHASE 0
#define SPI_SI_CLOCKPOLARITY 0
#define SPI_SI_CLOCKUNITS "Hz"
#define SPI_SI_DATABITS 8
#define SPI_SI_DATAWIDTH 16
#define SPI_SI_DELAYMULT "1.0E-9"
#define SPI_SI_DELAYUNITS "ns"
#define SPI_SI_EXTRADELAY 0
#define SPI_SI_INSERT_SYNC 0
#define SPI_SI_IRQ 8
#define SPI_SI_IRQ_INTERRUPT_CONTROLLER_ID 0
#define SPI_SI_ISMASTER 1
#define SPI_SI_LSBFIRST 0
#define SPI_SI_NAME "/dev/spi_si"
#define SPI_SI_NUMSLAVES 2
#define SPI_SI_PREFIX "spi_"
#define SPI_SI_SPAN 32
#define SPI_SI_SYNC_REG_DEPTH 2
#define SPI_SI_TARGETCLOCK 128000u
#define SPI_SI_TARGETSSDELAY "0.0"
#define SPI_SI_TYPE "altera_avalon_spi"


/*
 * sysid configuration
 *
 */

#define ALT_MODULE_CLASS_sysid altera_avalon_sysid_qsys
#define SYSID_BASE 0x700f0000
#define SYSID_ID 0x46454233
#define SYSID_IRQ -1
#define SYSID_IRQ_INTERRUPT_CONTROLLER_ID -1
#define SYSID_NAME "/dev/sysid"
#define SYSID_SPAN 8
#define SYSID_TIMESTAMP 1773676555
#define SYSID_TYPE "altera_avalon_sysid_qsys"


/*
 * timer configuration
 *
 */

#define ALT_MODULE_CLASS_timer altera_avalon_timer
#define TIMER_ALWAYS_RUN 1
#define TIMER_BASE 0x700f0100
#define TIMER_COUNTER_SIZE 32
#define TIMER_FIXED_PERIOD 1
#define TIMER_FREQ 50000000
#define TIMER_IRQ 0
#define TIMER_IRQ_INTERRUPT_CONTROLLER_ID 0
#define TIMER_LOAD_VALUE 49999
#define TIMER_MULT 0.001
#define TIMER_NAME "/dev/timer"
#define TIMER_PERIOD 1
#define TIMER_PERIOD_UNITS "ms"
#define TIMER_RESET_OUTPUT 0
#define TIMER_SNAPSHOT 0
#define TIMER_SPAN 32
#define TIMER_TICKS_PER_SEC 1000
#define TIMER_TIMEOUT_PULSE_OUTPUT 0
#define TIMER_TYPE "altera_avalon_timer"


/*
 * timer_ts configuration
 *
 */

#define ALT_MODULE_CLASS_timer_ts altera_avalon_timer
#define TIMER_TS_ALWAYS_RUN 0
#define TIMER_TS_BASE 0x700f0140
#define TIMER_TS_COUNTER_SIZE 32
#define TIMER_TS_FIXED_PERIOD 0
#define TIMER_TS_FREQ 50000000
#define TIMER_TS_IRQ -1
#define TIMER_TS_IRQ_INTERRUPT_CONTROLLER_ID -1
#define TIMER_TS_LOAD_VALUE 49999
#define TIMER_TS_MULT 0.001
#define TIMER_TS_NAME "/dev/timer_ts"
#define TIMER_TS_PERIOD 1
#define TIMER_TS_PERIOD_UNITS "ms"
#define TIMER_TS_RESET_OUTPUT 0
#define TIMER_TS_SNAPSHOT 1
#define TIMER_TS_SPAN 32
#define TIMER_TS_TICKS_PER_SEC 1000
#define TIMER_TS_TIMEOUT_PULSE_OUTPUT 0
#define TIMER_TS_TYPE "altera_avalon_timer"

#endif /* __SYSTEM_H_ */
