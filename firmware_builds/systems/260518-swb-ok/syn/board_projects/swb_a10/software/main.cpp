
//

#include "include/base.h"

#include "include/a10/flash.h"
flash_t flash;

#include "include/a10/fan.h"
fan_t fan(0x01);

#include "include/xcvr.h"
#include "include/a10/reconfig.h"
reconfig_t reconfig;

int main() {
    base_init();

    fan.init();

    flash.init();

    while (1) {
        printf("  [1] => flash\n");
        printf("  [2] => xcvr\n");
        printf("  [8] => fan\n");
        printf("  [r] => reconfig pll\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            flash.menu();
            break;
        case '2':
            menu_xcvr(AVM_XCVR0_BASE, AVM_XCVR0_SPAN);
            break;
        case '8':
            fan.menu();
            break;
        case 'r':
            reconfig.pll(AVM_XCVR0_BASE + 0x00000);
            reconfig.pll(AVM_XCVR0_BASE + 0x10000);
            reconfig.pll(AVM_XCVR0_BASE + 0x20000);
            reconfig.pll(AVM_XCVR0_BASE + 0x30000);
            break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }

    return 0;
}
