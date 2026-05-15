#include "include/base.h"
#include <altera_avalon_pio_regs.h>
#include <altera_avalon_sysid_qsys_regs.h>

#include "si5345.h"
#include "si5345_regs1_mutrig.h"
#include "si5345_regs2.h"

namespace {

si5345_t si5345_1 { SI_OUT_BASE, SI_IN_BASE, 0, si5345_regs1_mutrig, sizeof(si5345_regs1_mutrig) / sizeof(si5345_regs1_mutrig[0]) };
si5345_t si5345_2 { SI_OUT_BASE, SI_IN_BASE, 1, si5345_regs2, sizeof(si5345_regs2) / sizeof(si5345_regs2[0]) };

enum : alt_u32 {
    DBG_STAGE_BOOT        = 0x42525430u, // "BRT0"
    DBG_STAGE_INIT_SI2    = 0x42525432u, // "BRT2"
    DBG_STAGE_WAIT_SI1    = 0x42525731u, // "BRW1"
    DBG_STAGE_INIT_SI1    = 0x42525431u, // "BRT1"
    DBG_STAGE_READY       = 0x4f4b4159u, // "OKAY"
    DBG_STAGE_RESET_HOLD  = 0x52535430u, // "RST0"
    DBG_STAGE_RESET_REL   = 0x52535431u  // "RST1"
};

void write_dbg0(alt_u32 value) {
    IOWR_ALTERA_AVALON_PIO_DATA(DBG0_BASE, value);
}

void write_dbg1(alt_u32 value) {
    IOWR_ALTERA_AVALON_PIO_DATA(DBG1_BASE, value);
}

alt_u8 read_si_status() {
    return static_cast<alt_u8>(IORD_ALTERA_AVALON_PIO_DATA(SI_IN_BASE));
}

void update_dbg_status() {
    write_dbg1(read_si_status());
}

void print_identity(const char* name, si5345_t& chip) {
    alt_u32 pn_base = (chip.read(0x0003) << 8) | chip.read(0x0002);
    alt_u8 grade = chip.read(0x0004);
    alt_u8 rev = chip.read(0x0005);
    printf("[%s] PN_BASE=0x%04X GRADE=%u REV=%u INTR_N=%u LOL_N=%u\n",
        name,
        static_cast<unsigned int>(pn_base),
        static_cast<unsigned int>(grade),
        static_cast<unsigned int>(rev),
        static_cast<unsigned int>(chip.intr_n()),
        static_cast<unsigned int>(chip.lol_n())
    );
}

void print_status() {
    const alt_u8 status = read_si_status();
    printf("si_status = 0x%02X\n", status);
    printf("  si1: INTR_N=%u LOL_N=%u MISO=%u\n",
        (status >> 0) & 0x1u,
        (status >> 2) & 0x1u,
        (status >> 4) & 0x1u
    );
    printf("  si2: INTR_N=%u LOL_N=%u MISO=%u\n",
        (status >> 1) & 0x1u,
        (status >> 3) & 0x1u,
        (status >> 5) & 0x1u
    );
    update_dbg_status();
}

void hold_resets() {
    write_dbg0(DBG_STAGE_RESET_HOLD);
    si5345_1.sync_defaults();
    si5345_1.set_reset(false);
    si5345_2.set_reset(false);
    update_dbg_status();
}

void release_resets() {
    write_dbg0(DBG_STAGE_RESET_REL);
    si5345_1.sync_defaults();
    si5345_1.set_reset(true);
    si5345_2.set_reset(true);
    update_dbg_status();
}

void bringup_si() {
    write_dbg0(DBG_STAGE_BOOT);
    hold_resets();
    usleep(10000);
    release_resets();
    usleep(100000);

    write_dbg0(DBG_STAGE_INIT_SI2);
    si5345_2.init();
    update_dbg_status();

    write_dbg0(DBG_STAGE_WAIT_SI1);
    usleep(5000000);

    write_dbg0(DBG_STAGE_INIT_SI1);
    si5345_1.init();
    update_dbg_status();

    write_dbg0(DBG_STAGE_READY);
}

void print_banner() {
    printf("FEB bring-up Nios\n");
    printf("  SYSID          : 0x%08X\n", static_cast<unsigned int>(IORD_ALTERA_AVALON_SYSID_QSYS_ID(SYSID_BASE)));
    printf("  SI_OUT_BASE    : 0x%08X\n", static_cast<unsigned int>(SI_OUT_BASE));
    printf("  SI_IN_BASE     : 0x%08X\n", static_cast<unsigned int>(SI_IN_BASE));
    printf("  DBG0/DBG1      : 0x%08X / 0x%08X\n", static_cast<unsigned int>(DBG0_BASE), static_cast<unsigned int>(DBG1_BASE));
}

void print_menu() {
    printf("\n");
    printf("[bringup] -------- menu --------\n");
    printf("  [b] => init both Si chips\n");
    printf("  [1] => force init SI5345 #1\n");
    printf("  [2] => force init SI5345 #2\n");
    printf("  [r] => pulse both reset pins\n");
    printf("  [s] => dump raw status\n");
    printf("  [5] => SI5345 #1 menu\n");
    printf("  [6] => SI5345 #2 menu\n");
    printf("Select entry ...\n");
}

} // namespace


int main() {
    base_init();
    print_banner();
    bringup_si();
    print_status();
    print_identity("si1", si5345_1);
    print_identity("si2", si5345_2);

    while (1) {
        print_menu();
        char cmd = wait_key();
        switch(cmd) {
        case 'b':
            bringup_si();
            break;
        case '1':
            si5345_1.init(1);
            print_identity("si1", si5345_1);
            update_dbg_status();
            break;
        case '2':
            si5345_2.init(1);
            print_identity("si2", si5345_2);
            update_dbg_status();
            break;
        case 'r':
            hold_resets();
            usleep(10000);
            release_resets();
            print_status();
            break;
        case '5':
            si5345_1.menu();
            update_dbg_status();
            break;
        case '6':
            si5345_2.menu();
            update_dbg_status();
            break;
        case 's':
            print_status();
            break;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }

    return 0;
}
