/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#ifndef __UTIL_A10_SI5340_H__
#define __UTIL_A10_SI5340_H__

#include "si5340_regs.h"

struct si5340_t {

    const alt_u8 dev = 0x77;

    alt_u8 set_page(alt_u8 page = -1) {
        if(page != -1) i2c.set(dev, 0x01, page);
        page = i2c.get(dev, 0x01);
        printf("  page 0x%02X :\n", page);
        return page;
    }

    void set_N0(alt_u64 n) {
        set_page(0x03);

        //
        i2c.set(dev, 0x02, (n >> 0) & 0xFF);
        i2c.set(dev, 0x03, (n >> 8) & 0xFF);
        i2c.set(dev, 0x04, (n >> 16) & 0xFF);
        i2c.set(dev, 0x05, (n >> 24) & 0xFF);
        i2c.set(dev, 0x06, (n >> 32) & 0xFF);
        i2c.set(dev, 0x07, (n >> 40) & 0xFF);

        // update N0
        i2c.set(dev, 0x0c, 1);
    }

    void set_f0(alt_u32 f) {
        alt_u32 f_in = 48000000;
        while(f_in % 2 == 0 && f % 2 == 0) { f_in /= 2; f /= 2; }
        alt_u64 n = 0x93b4800000;
        while(n % 2 == 0 && f % 2 == 0) { n /= 2; f /= 2; }
        set_N0(n * f_in / f / 2);
    }

    void read_regs() {
        i2c.set(dev, 0x01, 0); // set page 0
        printf("  DIE_REV       = 0x%02X\n", i2c.get(dev, 0x00));
        printf("  PN_BASE       = 0x%02X%02X\n", i2c.get(dev, 0x03), i2c.get(dev, 0x02));
        printf("  GRADE         = 0x%02X\n", i2c.get(dev, 0x04));
        printf("  DEVICE_REV    = 0x%02X\n", i2c.get(dev, 0x05));
        printf("  TOOL_VERSION  = 0x%02X%02X%02X\n", i2c.get(dev, 0x08), i2c.get(dev, 0x07), i2c.get(dev, 0x06));
        printf("  TEMP_GRADE    = 0x%02X\n", i2c.get(dev, 0x09));
        printf("  PKG_ID        = 0x%02X\n", i2c.get(dev, 0x0A));

        auto& regs = si5340_regs;
        alt_u8 page = -1;
        for(unsigned i = 0; i < sizeof(regs)/sizeof(regs[0]); i++) {
            auto& reg = regs[i];
            if(page != reg[0]) {
                i2c.set(dev, 0x01, reg[0]);
                page = i2c.get(dev, 0x01);
                printf("  page 0x%02X :\n", page);
            }
            alt_u8 a = reg[1];
            alt_u8 r = i2c.get(dev, a), m = reg[2];
            printf("    [0x%02X] = 0x%02X | 0x%02X\n", a, r, (r & ~m) | (reg[3] & m));
        }
    }

    void menu() {
        while (1) {
            printf("\n");
            printf("[si5340] -------- menu --------\n");

            printf("\n");
            printf("  [1] => 100 MHz\n");
            printf("  [2] => 125 MHz\n");
            printf("  [3] => 156.25 MHz\n");
            printf("  [r] => read regs\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case '1':
                si5340.set_f0(100000000); // 100 MHz
                break;
            case '2':
                si5340.set_f0(125000000); // 125 MHz
                break;
            case '3':
                si5340.set_f0(156250000); // 156.25 MHz
                break;
            case 'r':
                si5340.read_regs();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

};

#endif // __UTIL_A10_SI5340_H__
