/*
 * cfi1616.h
 *
 * author : Alexandr Kozlinskiy
 * date : 2017-10-30
 */

#ifndef __UTIL_A10_CFI1616_H__
#define __UTIL_A10_CFI1616_H__

#include <io.h>

#include <sys/alt_stdio.h>

#include <errno.h>

/**
 *
 */
struct cfi1616_t {
    // Device WSM Status
    static const alt_u32 SR_DWS         = 0x00800080;

    static const alt_u32 CMD_READ_ARRAY = 0x00FF00FF;
    static const alt_u32 CMD_PGM_BUF    = 0x00E800E8;
    static const alt_u32 CMD_CONFIRM    = 0x00D000D0;
    static const alt_u32 CMD_CFI_READ   = 0x00980098;
    static const alt_u32 CMD_ID_READ    = 0x00900090;
    static const alt_u32 CMD_SR_READ    = 0x00700070;
    static const alt_u32 CMD_LOCK_SETUP = 0x00600060;
    static const alt_u32 CMD_SR_CLEAR   = 0x00500050;
    static const alt_u32 CMD_PGM_WORD   = 0x00400040;
    static const alt_u32 CMD_ERASE      = 0x00200020;

    volatile alt_u8* base;

    alt_u32 deviceSize;

    alt_u32 numRegions;
    struct {
        volatile alt_u8* base;
        alt_u32 size;
        alt_u32 numBlocks;
        alt_u32 blockSize;
    } regions[8];

    alt_u32 bufferSize;

    alt_u32 wordProgramTimeout;
    alt_u32 bufferProgramTimeout;
    alt_u32 blockEraseTimeout;

    int init(volatile alt_u8* base_) {
        base = base_;

        IOWR(base, 0x55, CMD_CFI_READ);

        {
            alt_u32 q = IORD(base, 0x10);
//            printf("[0x10] = 0x%08X\n", q);
            if(q != 0x00510051) return -1;
            alt_u32 r = IORD(base, 0x11);
//            printf("[0x11] = 0x%08X\n", r);
            if(r != 0x00520052) return -1;
            alt_u32 y = IORD(base, 0x12);
//            printf("[0x12] = 0x%08X\n", y);
            if(y != 0x00590059) return -1;
        }

        printf("CFI table in 32 bit x16||x16 mode\n");

        alt_u8 cfi[0x40], ext[0x40];

        for(alt_u32 i = 0x10; i <= 0x38; i++) {
            alt_u32 j = IORD(base, i);
            if((j & 0xFFFF) != (j >> 16)) return -1;
            if((j & 0xFF00) != 0) return -1;
            cfi[i] = j & 0xFF;
        }
        for(alt_u32 i = 0x00; i < 0x20; i++) {
            alt_u32 j = IORD(base, (cfi[0x15] | (cfi[0x16] << 8)) + i);
            if((j & 0xFFFF) != (j >> 16)) return -1;
            if((j & 0xFF00) != 0) return -1;
            ext[i] = j & 0xFF;
        }

        printf("CFI query table:");
        for(alt_u32 i = 0x10; i <= 0x38; i++) {
            if((i & 0xF) == 0) printf("\n  %02X:", i);
            printf(" %02X", cfi[i]);
        }
        printf("\n");

        printf("CFI extended table:");
        for(alt_u32 i = 0x00; i < 0x20; i++) {
            if((i & 0xF) == 0) printf("\n  %02X:", i);
            printf(" %02X", ext[i]);
        }
        printf("\n");

//        IOWR(base, 0, CMD_ID_READ);
//        alt_u32 id = IORD(base, 1);
//        if((id & 0xFFFF) != (id >> 16)) return -1;
//        id = id & 0xFFFF;
//        printf("Device ID is %04X\n", id);

        deviceSize = 2 * (1 << cfi[0x27]);
        printf("Device size is %uMB\n", deviceSize >> 20);

        // Number of erase block regions
        numRegions = cfi[0x2C];
        if(numRegions > 8) numRegions = 8; // FIXME
        printf("Erase block regions:\n");
        for(alt_u32 i = 0; i < numRegions; i++) {
            auto& r = regions[i];
            if(i == 0) r.base = base;
            else {
                r.base = r.base + regions[i-1].size;
            }
            r.numBlocks = (cfi[0x2D + 4*i] | (cfi[0x2E + 4*i] << 8)) + 1;
            r.blockSize = 2 * (cfi[0x2F + 4*i] | (cfi[0x30 + 4*i] << 8)) * 256;
            r.size = r.numBlocks * r.blockSize;
            printf("  0x%08X: %u x %uK\n", r.base, r.numBlocks, r.blockSize >> 10);
        }

        bufferSize = 2 * (1 << cfi[0x2A]);
        printf("Write buffer size is %uB\n", bufferSize);

        wordProgramTimeout = (1 << cfi[0x1F] << cfi[0x23]) / 1000; // ms
        printf("Word program timeout is %u ms\n", wordProgramTimeout);
        bufferProgramTimeout = (1 << cfi[0x20] << cfi[0x24]) / 1000; // ms
        printf("Buffer program timeout is %u ms\n", bufferProgramTimeout);
        blockEraseTimeout = (1 << cfi[0x21] << cfi[0x25]); // ms
        printf("Block erase timeout is %u s\n", blockEraseTimeout / 1000);

        read_array();
        return 0;
    }

    int addr_valid(volatile alt_u8* addr) {
        if(numRegions < 2) return -EINVAL;
        auto& r = regions[1];
        if(!(r.base <= addr && addr < r.base + r.size)) return -EINVAL;
        if((addr - r.base) & (bufferSize - 1)) return -EINVAL;
        return 0;
    }

    /**
     * Switch to read array mode.
     */
    void read_array() {
        IOWR(base, 0x55, CMD_READ_ARRAY);
    }

    /**
     * Check WSM status bits.
     *
     * @return -EBUSY, 0 or WSM error bits
     */
    int check_wsm(volatile alt_u8* addr) {
        alt_u32 sr = IORD(addr, 0);
        if((sr & SR_DWS) != SR_DWS) return -EBUSY;

        int err = 0;
        if(sr != SR_DWS) {
            IOWR(base, 0x55, CMD_SR_READ);
            sr = IORD(addr, 0);
            err = (sr | (sr >> 16)) & 0x7F;
            // TODO: use errno codes
//            if(err & 0x18) err = -EIO;
//            else if(err & 0x2) err = -EPERM;
            IOWR(base, 0x55, CMD_SR_CLEAR);
        }
        return err;
    }

    /**
     * Wait for WSM ready state, switch to read array mode.
     *
     * @return 0 or WSM error bits
     */
    int sync(volatile alt_u8* addr, useconds_t us = 1000, alt_u32* k = nullptr) {
        // TODO: k -> timeout
        int err;
        while(true) {
            err = check_wsm(addr);
            if(err != -EBUSY) break;
            usleep(us);
            if(k) (*k)++;
        }

        read_array();
        return err;
    }

    static
    int cmp(volatile alt_u8* addr, volatile alt_u8* data, alt_u32 n) {
        alt_u32 nw = n / 4;

        for(alt_u32 i = 0; i < nw; i++) {
            alt_u32 l = IORD(addr, i);
            alt_u32 r = IORD(data, i);
            if(l < r) return -1;
            if(l > r) return 1;
        }
        if(n & 3) {
            alt_u32 mask = 0xFFFFFFFF << ((n & 3) * 8);
            alt_u32 l = IORD(addr, nw) | mask;
            alt_u32 r = IORD(data, nw) | mask;
            if(l < r) return -1;
            if(l > r) return 1;
        }

        return 0;
    }

    /**
     * Lock block and switch to read array mode.
     */
    int lock(volatile alt_u8* addr) {
        if(addr_valid(addr) != 0) return -EINVAL;

        IOWR(addr, 2, CMD_ID_READ);
        alt_u32 lock = IORD(addr, 2);
        if(lock == 0x00010001) return 0;
        if(lock & 0x00020002) return -EPERM;

        IOWR(addr, 0, CMD_LOCK_SETUP);
        IOWR(addr, 0, 0x00010001); // lock

        IOWR(addr, 2, CMD_ID_READ);
        int err = 0;
        if(IORD(addr, 2) != 0x00010001) err = -EAGAIN;

        read_array();
        return err;
    }

    /**
     * Unlock block and switch to read array mode.
     */
    int unlock(volatile alt_u8* addr) {
        if(addr_valid(addr) != 0) return -EINVAL;

        IOWR(addr, 2, CMD_ID_READ);
        alt_u32 lock = IORD(addr, 2);
        if(lock == 0x00000000) return 0;
        if(lock & 0x00020002) return -EPERM;

        IOWR(addr, 0, CMD_LOCK_SETUP);
        IOWR(addr, 0, CMD_CONFIRM); // unlock

        IOWR(addr, 2, CMD_ID_READ);
        int err = 0;
        if(IORD(addr, 2) != 0x00000000) err = -EAGAIN;

        read_array();
        return err;
    }

    int erase(volatile alt_u8* addr) {
        if(addr_valid(addr) != 0) return -EINVAL;

        IOWR(addr, 0, CMD_ERASE);
        IOWR(addr, 0, CMD_CONFIRM);

        return 0;
    }

    int program(volatile alt_u8* addr, volatile alt_u8* data, alt_u32 n) {
        if(addr_valid(addr) != 0) return -EINVAL;

        if(data == nullptr || !(0 < n && n <= bufferSize)) {
            return -EINVAL;
        }

        IOWR(addr, 0, CMD_PGM_BUF);
        if((IORD(addr, 0) & SR_DWS) != SR_DWS) return -EAGAIN;
        // TODO: use check_wsm

        alt_u32 nw = (n + 3) / 4;
        nw -= 1;
        IOWR(addr, 0, (nw << 16) | nw);
        for(alt_u32 i = 0; i <= nw; i++) {
            alt_u32 d = IORD(data, i);
            IOWR(addr, i, d);
        }
        IOWR(addr, 0, CMD_CONFIRM);

        return 0;
    }

    static
    int print(volatile alt_u8* addr, alt_u32 n) {
        alt_u32 nw = n / 4;
        for(alt_u32 i = 0; i < nw; i++) {
            printf("%08X", IORD(addr, i));
            if((i & 0x7) == 0x7) printf("\n");
            else printf(" ");
        }
        if(n & 3) {
            // TODO:
        }
        return 0;
    }

    alt_u32 state = 0;
    alt_u32 timeout = 1;

    int callback(volatile alt_u8* addr, volatile alt_u8* data, alt_u32 n) {
        if(!(addr && data && n)) return -EINVAL;

        int err = 0;
        alt_u32 state_ = state >> 24;
        alt_u32 i = state & 0xFFFFFF;

        if(timeout == 0) {
            err = check_wsm(addr);
            alt_printf("%x : timeout => %x\n", addr, err);
            goto exit;
        }
        if(timeout > 0) timeout -= 1;

        // wait
        if(state_ == 0x80) {
            err = check_wsm(addr);
            if(err == -EBUSY) {
                return -EAGAIN;
            }
            if(err) {
                alt_printf("%x : wait => %x\n", addr, err);
                goto exit; // exit
            }

            if(i < n) {
                state_ = 0xE8; // program
                timeout = 1;
            }
            else {
                state_ = 0x61; // lock
                timeout = 1;
            }
        }

        // program
        if(state_ == 0xE8) {
            err = program(addr + i, data + i, (n - i) < bufferSize ? (n - i) : bufferSize);
            if(err == -EAGAIN) {
                return -EAGAIN;
            }
            if(err) {
                alt_printf("%x : program => %x\n", addr, err);
                goto exit; // exit
            }
            i += bufferSize;

            state = (0x80 << 24) | i; // wait
            timeout = bufferProgramTimeout; // 4ms
            return -EAGAIN;
        }

        // init
        if(state_ == 0) {
            if(n & 3) {
                alt_u32 d = IORD(data, n / 4);
                alt_u32 mask = 0xFFFFFFFF << ((n & 3) * 8);
                IOWR(data, n / 4, d | mask);
            }

            state_ = 0x01; // verify
        }

        // verify
        if(state_ == 0x01) {
            int eq = cmp(addr + i, data + i, (n - i) < bufferSize ? (n - i) : bufferSize);
            if(eq == 0) {
                i += bufferSize;
                if(i >= n) goto exit;
                state = (0x01 << 24) | i; // verify
                timeout = 1;
                return -EAGAIN;
            }

            state_ = 0x60; // unlock
            timeout = 1;
        }

        // unlock
        if(state_ == 0x60) {
            err = unlock(addr);
            if(err == -EAGAIN) {
                state = 0x60 << 24;
                return -EAGAIN;
            }
            if(err) {
                alt_printf("%x : unlock => %x\n", addr, err);
                goto exit;
            }
            state_ = 0x20; // erase
        }

        // erase
        if(state_ == 0x20) {
            err = erase(addr);
            if(err) {
                alt_printf("%x : erase => %x\n", addr, err);
                goto exit; // exit
            }

            state = 0x80 << 24; // wait
            timeout = blockEraseTimeout; // 4s
            return -EAGAIN;
        }

        // lock
        if(state_ == 0x61) {
            err = lock(addr);
            if(err == -EAGAIN) {
                state = 0x61 << 24;
                return -EAGAIN;
            }
            if(err) {
                alt_printf("%x : lock => %x\n", addr, err);
            }
        }

        // exit
        exit: {
            read_array();
            state = 0;
            timeout = 1;
        }

        return 0;
    }
};

#endif // __UTIL_A10_CFI1616_H__
