#ifndef __FE_SI5345_H__
#define __FE_SI5345_H__

#include "include/si534x.h"

struct si5345_t : si534x_t {

    const char* DESIGN_ID = "si45.v1";

    const register_t* regs; int regs_n;

    si5345_t(alt_u32 spi_base, alt_u32 spi_slave, const register_t* regs, int regs_n)
        : si534x_t(spi_base, spi_slave)
        , regs(regs), regs_n(regs_n)
    {
    }

    void init(int force = 0) {
        char id[9];
        id[8] = '\0';
        for(int i = 0; i < 8; i++) id[i] = (char)read(0x026B + i);
        if(force == 0 && strcmp(id, DESIGN_ID) == 0) return;

        si_t::init(regs, regs_n);
//        for(int i = 0; i < 8; i++) write(0x026B + i, DESIGN_ID[i]);

        wait_sysincal();
    }

    void preamble() {
        write(0x0B24, 0xC0);
        write(0x0B25, 0x00);
        write(0x0540, 0x01);
    }

    void postamble() {
        write(0x0540, 0x00);
        write(0x0B24, 0xC3);
        write(0x0B25, 0x02);
    }

    static const int N_OUT = 10;
    const int16_t REG_OUT[N_OUT] = { 0x0108, 0x010D, 0x0112, 0x0117, 0x0121, 0x0126, 0x012B, 0x0130, 0x013A };

    /**
     * divide value = (R + 1) * 2
     */
    int set_R(int i, int r) {
        if(!(0 <= i && i <= 9)) return -1;
        if(!(0 <= r && r < (1 << 24))) return -1;

        uint16_t O_reg = REG_OUT[i];
        uint16_t R_reg = 0x024A + 3 * i;

        const uint8_t RDIV_FORCE2 = (1 << 2);

        if(r == 0) {
            write(O_reg, read(O_reg) | RDIV_FORCE2);
            write_n(R_reg, r, 3);
        }
        else {
            write_n(R_reg, r, 3);
            write(O_reg, read(O_reg) & ~RDIV_FORCE2);
        }

        return 0;
    }

    void menu() {
        alt_u32 pn_base = (read(0x0003) << 8) | read(0x0002);
        if(pn_base != 0x5345) {
            printf("Invalid base part number: 0x%04X\n", pn_base);
            return;
        }

        while (1) {
            status();
            printf("\n");

            printf("si5345:\n");
            printf("  [I] => init\n");
            printf("  [R] => reset\n");
            printf("  [r] => read regs\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 'I':
                init(1); // force init
                break;
            case 'R':
                soft_reset();
                break;
            case 'r': {
                printf("select page (0): ");
                char page = wait_key();
                if('0' <= page && page <= '9') page = page - '0';
                else if('a' <= page && page <= 'f') page = 10 + page - 'a';
                else if('A' <= page && page <= 'F') page = 10 + page - 'A';
                else page = 0;
                printf("si5345.read:\n");
                for(alt_u16 address = 0x0000; address < 0x0100; address++) {
                    printf("  [0x%04X] = 0x%02X\n", (page << 8) + address, read((page << 8) + address));
                }
                break;
            }
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

};

#endif // __FE_SI5345_H__
