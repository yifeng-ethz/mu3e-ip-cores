#ifndef __FE_SI5342_H__
#define __FE_SI5342_H__

#include "include/si534x.h"

#include "si5342_revb_registers.h"

struct si5342_t : si534x_t {

    const char* DESIGN_ID = "si42.v1";

    si5342_t(alt_u32 spi_base, alt_u32 spi_slave)
        : si534x_t(spi_base, spi_slave)
    {
    }

    void init(int force = 0) {
        char id[9];
        id[8] = '\0';
        for(int i = 0; i < 8; i++) id[i] = (char)read(0x026B + i);
        if(force == 0 && strcmp(id, DESIGN_ID) == 0) return;

        wait_sysincal();
    }

    void menu() {
        alt_u32 pn_base = (read(0x0003) << 8) | read(0x0002);
        if(pn_base != 0x5342) {
            printf("Invalid base part number: 0x%04X\n", pn_base);
            return;
        }

        while (1) {
            status();
            printf("\n");

            printf("si5342:\n");
            printf("  [I] => init\n");
            printf("  [W] => write to NVM\n");

            printf("Select entry ...\n");
            char cmd = wait_key();
            switch(cmd) {
            case 'I':
                init(1);
                break;
            case 'W':
                nvm_write();
                return;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }
        }
    }

};

#endif // __FE_SI5342_H__
