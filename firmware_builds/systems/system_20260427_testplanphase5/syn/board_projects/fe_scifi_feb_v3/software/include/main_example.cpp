/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#include "base.h"

int main() {
    base_init();

    while (1) {
        printf("\n");
        printf("[example] -------- menu --------\n");

        printf("\n");
        printf("  [1] => menu 1\n");
        printf("  [2] => menu 2\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case '1':
            menu_1();
            break;
        case '2':
            menu_2();
            break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }

    return 0;
}
