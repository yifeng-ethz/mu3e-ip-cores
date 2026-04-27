/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#ifndef __UTIL_A10_FAN_H__
#define __UTIL_A10_FAN_H__

#include "../i2c.h"

/**
 * Arria 10 board (DE5a_NET) FAN controller.
 */
struct fan_t {
    i2c_t i2c;
    uint32_t i2c_mask;
    alt_u8 i2c_slave;

    // clock frequency
    const alt_u32 clk_hz = 254000;

//    uint8_t mode = 0x2; // closed loop
    alt_u8 scale = 4;
    alt_u8 rps = 50;

    fan_t(uint32_t i2c_mask = 0xFFFFFFFF, alt_u8 i2c_slave = 0x48)
        : i2c_mask(i2c_mask)
        , i2c_slave(i2c_slave)
    {
    }

    alt_u8 get(alt_u8 addr) {
        i2c.set_mask(i2c_mask);
        return i2c.get(i2c_slave, addr);
    }

    void set(alt_u8 addr, alt_u8 data) {
        i2c.set_mask(i2c_mask);
        i2c.set(i2c_slave, addr, data);
    }

    alt_u8 get_rps() {
        return scale * clk_hz / ( 128 * 2 * (get(0x00) + 1));
    }

    void set_rps(alt_u8 rps) {
        set(0x00, scale * clk_hz / (128 * 2 * rps) - 1);
    }

    void init() {
        set(0x16, 0x02); // tachometer count time
        set(0x08, 0x07); // alarm enable
        set(0x04, 0xF5); // gpio definition
        set(0x02, 0x2A); // configuration
//        set(0x00, 0x4E); // fan speed
        set_rps(rps);
    }

    void menu() {
        while (1) {
            printf("\n");
            printf("[fan] -------- menu --------\n");

            printf("\n");
            printf(
                "  conf = 0x%02X, gpio = 0x%02X, tach = 0x%02X\n"
                "  alarm = 0x%02X => 0x%02X\n"
                "  rps = 0x%02X (%u) => %u\n",
                get(0x02), get(0x04), get(0x16),
                get(0x08), get(0x0A),
                get(0x00), rps, get(0x0C) / 2
            );

            printf("\n");
            printf("  [i] => init\n");
            printf("  [[] => rps++\n");
            printf("  []] => rps--\n");
            printf("  [q] => exit\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 'i': // fan i2c
                init();
                break;
            case ']':
                set_rps(++rps);
                break;
            case '[':
                set_rps(--rps);
                break;
            case '?':
                wait_key();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }
};

#endif // __UTIL_A10_FAN_H__
