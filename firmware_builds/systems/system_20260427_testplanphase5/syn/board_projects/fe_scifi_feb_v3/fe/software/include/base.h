/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */
#ifndef __UTIL_BASE_H__
#define __UTIL_BASE_H__

#include <system.h>

#ifndef ALT_CPU_DCACHE_BYPASS_MASK
    #define ALT_CPU_DCACHE_BYPASS_MASK 0
#endif

#include <sys/alt_alarm.h>

#include <altera_avalon_i2c.h>
#include <altera_avalon_spi.h>
#include <altera_avalon_pio_regs.h>

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

// watchdog
struct wd_t {
    alt_alarm alarm;

    void init() {
        printf("[wd] init\n");
        int err = alt_alarm_start(&alarm, 10, callback, this);
        if(err) {
            printf("[wd] ERROR: alt_alarm_start => %d\n", err);
        }
    }

    alt_u32 callback() {
        IOWR_ALTERA_AVALON_PIO_CLEAR_BITS(PIO_BASE, 0xFF);
        IOWR_ALTERA_AVALON_PIO_SET_BITS(PIO_BASE, alt_nticks() & 0xFF);

        return 10;
    }

    static
    alt_u32 callback(void* wd) {
        return ((wd_t*)wd)->callback();
    }
} wd;

int uart = -1;

void uart_init() {
    uart = open(JTAG_UART_NAME, O_NONBLOCK);
    if(uart < 0) {
        printf("ERROR: can't open %s\n", JTAG_UART_NAME);
    }
}

void base_init() {
    printf("ALT_DEVICE_FAMILY = '%s'\n", ALT_DEVICE_FAMILY);
    printf("\n");

    uart_init();

    wd.init();
}

char wait_key(useconds_t us = 100000) {
    while(true) {
        char cmd = 0;
        if(uart < 0) return cmd;
        if(read(uart, &cmd, 1) > 0) return cmd;
        usleep(us);
    }
}

#include <sys/alt_timestamp.h>

#include <altera_avalon_spi.h>

#endif // __UTIL_BASE_H__
