#ifndef __UTIL_A10_FLAHS_H__
#define __UTIL_A10_FLAHS_H__

#include "cfi1616.h"

struct flash_t {
    cfi1616_t cfi;

    alt_alarm alarm;

    void init() {
        printf("[flash] init\n");

        if(cfi.init((alt_u8*)(FLASH_BASE)) != 0) {
            printf("[flash] ERROR: flash init failed\n");
        }

        int err = alt_alarm_start(&alarm, 0, callback, this);
        if(err) {
            printf("[flash] ERROR: alt_alarm_start => %d\n", err);
        }
    }

    alt_u32 hibit(alt_u32 n) {
        if(n == 0) return 0;
        alt_u32 r = 0;
        if(n & 0xFFFF0000) { r += 16; n >>= 16; };
        if(n & 0xFF00) { r += 8; n >>= 8; };
        if(n & 0xF0) { r += 4; n >>= 4; };
        if(n & 8) return r + 3;
        if(n & 4) return r + 2;
        if(n & 2) return r + 1;
        return 0;
    }

    volatile alt_u32* ctrl = (alt_u32*)(CTRL_REGION_BASE);
    volatile alt_u8* data = (alt_u8*)(DATA_REGION_BASE);

    alt_u32 hist_ts[16];

    alt_u32 callback() {
        alt_timestamp_start();
        int state = cfi.callback((alt_u8*)IORD(ctrl, 0), data, (alt_u32)IORD(ctrl, 1));
        alt_u32 ts_bin = hibit(alt_timestamp() / 125);

        if(ts_bin < 16) hist_ts[ts_bin]++;
        if(state == -EAGAIN) return 1;
        if(state == 0) {
            //asm volatile ("" : : : "memory");
            IOWR(ctrl, 0, 0);
            IOWR(ctrl, 1, 0);
        }

        return 10;
    }

    static
    alt_u32 callback(void* flash) {
        return ((flash_t*)flash)->callback();
    }

    void menu() {
        volatile alt_u8* addr_test = cfi.base + 0x05E80000;

        while (1) {
            printf("\n");
            printf("[flash] -------- menu --------\n");

            printf("\n");
            for(int i = 0; i <= 10; i++) {
                printf("%8u", 1 << i);
            } printf("\n");
            for(int i = 0; i <= 10; i++) {
                printf("%8u", hist_ts[i]);
            } printf("\n");

            printf("\n");
            printf("  [i] => init\n");
            printf("  [o] => print option bits\n");
            printf("  [e] => erase test\n");
            printf("  [w] => write test\n");
            printf("  [q] => exit\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 'i':
                cfi.init((alt_u8*)(FLASH_BASE));
                break;
            case 'o':
                for(int i = 0; i < 0x80; i++) {
                    printf("%02X", cfi.base[0x00030000+i]);
                    if(i%0x20 == 0x1F) printf("\n");
                }
                break;
            case 'e': {
                int err;
                err = cfi.unlock(addr_test);
                printf("%08X : unlock => %d\n", addr_test, err);
                err = cfi.erase(addr_test);
                err = cfi.sync(addr_test);
                printf("%08X : erase => %d\n", addr_test, err);
                break;
            }
            case 'w': {
                int err;
                for(int i = 0; i < 512; i++) data[i] = i;
                for(alt_u32 i = 0; i < cfi.regions[1].blockSize; i += cfi.bufferSize) {
                    err = cfi.program(addr_test + i, data, cfi.bufferSize);
                    err = cfi.sync(addr_test + i);
                    printf("%08X : program => %d\n", addr_test + i, err);
                }
                err = cfi.lock(addr_test);
                printf("%08X : lock => %d\n", addr_test, err);
                break;
            }
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

#endif // __UTIL_A10_FLAHS_H__
