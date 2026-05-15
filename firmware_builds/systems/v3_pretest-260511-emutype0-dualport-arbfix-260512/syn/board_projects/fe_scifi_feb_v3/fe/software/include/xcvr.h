/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#ifndef __UTIL_XCVR_H__
#define __UTIL_XCVR_H__

struct xcvr_block_t {
    static const alt_u32 XCVR_SPAN = 0x10000;

    volatile alt_u32* base;
    alt_u32 span;

    alt_u32 ch = 0;
    alt_u32 n = 0;
    alt_u32* rx_p = nullptr;

    explicit
    xcvr_block_t(volatile alt_u32* base, alt_u32 span = 0) : base(base), span(span) {
    }

    volatile alt_u32* xcvr_ch(alt_u32 i) {
        if(n != 0 && i >= n) return nullptr;

        if(rx_p != nullptr && i < n) i = rx_p[i];

        volatile alt_u32* xcvr = base;
        while(1) {
            if(span != 0 && xcvr >= base + span / 4) return nullptr;
            alt_u32 n = xcvr[0x01];
            if(n > 0xFF || n == 0) return nullptr;
            if(i < n) {
                xcvr[0x00] = i;
                if(xcvr[0x00] != i) return nullptr;
                return xcvr;
            }
            i -= n;
            xcvr += XCVR_SPAN / 4;
        }
    }

    void menu() {
        while (1) {
            if(menu_cmd() != 0) return;
            status();
            usleep(200000);
        }
    }

    int menu_cmd() {
        printf("\n");
        printf("XCVR 0x%08X:\n", base);
        printf("  [[,]] => select channel\n");
        printf("  [r,R] => reset\n");
        printf("  [l,L] => loopback\n");
        printf("\n");

        volatile alt_u32* xcvr = xcvr_ch(ch);
        if(xcvr == nullptr) return -1;

        char cmd;
        if(read(uart, &cmd, 1) > 0) switch(cmd) {
        case '[':
            if(ch > 0) ch -= 1;
            break;
        case ']':
            if(xcvr_ch(ch + 1) != nullptr) ch += 1;
            break;
        case 'r': // reset
            xcvr[0x10] = 0x01; // tx
            xcvr[0x20] = 0x01; // rx
            break;
        case 'R': { // reset (all channels)
            for(alt_u32 i = 0;; i++) {
                volatile alt_u32* xcvr = xcvr_ch(i);
                if(xcvr == nullptr) break;
                xcvr[0x10] = 0x01; // tx
                xcvr[0x20] = 0x01; // rx
            }
            break;
        }
        case 'l': // toggle loopback
            xcvr[0x2F] ^= 0x01;
            break;
        case 'L': { // toggle loopback (all channels)
            for(alt_u32 i = 0;; i++) {
                volatile alt_u32* xcvr = xcvr_ch(i);
                if(xcvr == nullptr) break;
                xcvr[0x2F] ^= 0x01;
            }
            break;
        }
        case '?':
            wait_key();
            break;
        case 'q':
            return -1;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
        return 0;
    }

    void status() {
        for(alt_u32 i = 0;; i += 8) {
            volatile alt_u32* xcvr = xcvr_ch(i);
            if(xcvr == nullptr) break;

            printf("  ch");
            for(alt_u32 j = i; j < i + 8; j++) {
                xcvr = xcvr_ch(j);
                if(xcvr == nullptr) break;

                // loopback
                alt_u32 l = xcvr[0x2F];
                // error counters
                alt_u32 e = xcvr[0x23] > 0 || xcvr[0x24] > 0;
                alt_u32 E = xcvr[0x23] == 0xFF && xcvr[0x24] == 0xFFFF;
                // ready or LtoR or LtoD or locked
                alt_u32 _ = xcvr[0x21] != 0;
                // locked (sync)
                alt_u32 S = xcvr[0x20] == 0 && (xcvr[0x21] & 0x1005) == 0x1005 && xcvr[0x22] == 0;
                printf(" | %s0x%02X%s %s%s..%s",
                    j == ch ? "[" : " ", j, j == ch ? "]" : " ",
                    S ? "S" : _ ? "_" : ".", l ? "l" : ".", E ? "E" : e ? "e" : "."
                );
            }
            printf(" |\n");

            printf("data");
            for(alt_u32 j = i; j < i + 8; j++) {
                xcvr = xcvr_ch(j);
                if(xcvr == nullptr) break;

                printf(" | 0x%08X/%01X", xcvr[0x2A], xcvr[0x2B]);
            }
            printf(" |\n");
        }
        printf("\n");

        volatile alt_u32* xcvr = xcvr_ch(ch);
        if(xcvr == nullptr) return;

        char id = 'A' + (xcvr - base) / (XCVR_SPAN / 4);
        printf("xcvr[%c].ch[0x%02X], lpbk = %d\n", id, xcvr[0x00], xcvr[0x2F]);
        printf("                R_DA S_LS_R E__FDE\n");
        printf("  tx    :   %s  0x%02X 0x%04X 0x%04X\n",
            xcvr[0x10] == 0x00 && xcvr[0x11] == 0x0001 && xcvr[0x12] == 0x0000 ? "OK" : "  ",
            xcvr[0x10], xcvr[0x11], xcvr[0x12]
        );
        printf("  rx    :   %s  0x%02X 0x%04X 0x%04X\n",
            xcvr[0x20] == 0x00 && (xcvr[0x21] & 0x1005) == 0x1005 && xcvr[0x22] == 0x0000 ? "OK" : "  ",
            xcvr[0x20], xcvr[0x21], xcvr[0x22]
        );
        printf("        :   LoL_cnt = %d, err_cnt = %d\n", xcvr[0x23], xcvr[0x24]);
        printf("  data  :   0x%08X / 0x%01X\n", xcvr[0x2A], xcvr[0x2B]);

        if(xcvr[0x25] != 0xCCCCCCCC && xcvr[0x26] != 0xCCCCCCCC) {
            printf("  mW/C  :   %i / %i\n", xcvr[0x25], xcvr[0x26] / 10000);
        }
    }
};

void menu_xcvr(volatile alt_u32* base, alt_u32 span = 0) {
    xcvr_block_t xcvr_block(base, span);
    xcvr_block.menu();
}

void menu_xcvr(alt_u32 base, alt_u32 span = 0) {
    menu_xcvr((alt_u32*)(base | ALT_CPU_DCACHE_BYPASS_MASK), span);
}

#endif // __UTIL_XCVR_H__
