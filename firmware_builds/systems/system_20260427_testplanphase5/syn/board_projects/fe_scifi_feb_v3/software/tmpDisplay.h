/*
 * author : Martin Mueller
 * date : 2020
 */

#include "stdlib.h"
#include "../../fe/generated/feb_sc_registers.h"

void menu_tmpDisplay(volatile alt_u32* xcvr, char ID = 'A') {

    while (1) {
        char cmd;
        if(read(uart, &cmd, 1) > 0) switch(cmd) {
        case '?':
            wait_key();
            break;
        case 'q':
            return;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
        xcvr[0x00] = ('0' - '0') & 0xFF;
        printf("Firefly 1 [°C] :  %i\n", xcvr[0x26]);
        xcvr[0x00] = ('1' - '0') & 0xFF;
        printf("Firefly 2 [°C] :  %i\n", xcvr[0x26]);
        printf("\n");
        sc.ram->data[ARRIA_TEMP_REGISTER_RW] = 0x00000003;
        sc.ram->data[ARRIA_TEMP_REGISTER_RW] = 0x00000002;
        usleep(2000000);
        printf("ArriaV    [°C] :  %i\n", sc.ram->data[ARRIA_TEMP_REGISTER_RW] - 0x80);

        usleep(200000);
    }
}
