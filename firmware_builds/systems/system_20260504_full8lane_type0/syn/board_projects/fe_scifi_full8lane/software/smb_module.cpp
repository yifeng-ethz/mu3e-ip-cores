//

#include "smb_module.h"
#include "smb_constants.h"
#include "builtin_config/mutrig3_config.h"
#include <ctype.h>

//from base.h
char wait_key(useconds_t us = 100000);


#include "../../fe/software/sc.h"
#include "../../../common/include/feb.h"
#include <altera_avalon_spi.h>
#include "altera_avalon_spi_regs.h"
#include "altera_avalon_spi.h"
#include "include/generated/mutrig_registers.h"


void pcharb(uint8_t c){
  for(int i=0;i<8;i++) printf("%u",(c>>i)&1);
}


/* TMB2 variant from tiles */
//write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1.
int SMB_t::spi_write_pattern(alt_u32 spi_slave, const alt_u8* bitpattern, bool print) {
    //const bool print=true;
    int status=0;
    uint16_t rx_pre=0xff00;
    //if (print) printf("tx | rx\n");
    uint16_t nb=MUTRIG_CONFIG_LEN_BYTES;
    unsigned char rx_check;
    alt_u8 rx;
    do{
        nb--;
        //do spi transaction, one byte at a time
        rx = 0xCC;
        alt_u8 tx = bitpattern[nb];

        alt_avalon_spi_command(SPI_BASE, spi_slave, 1, &tx, 0, &rx, nb==0?0:ALT_AVALON_SPI_COMMAND_MERGE);
        rx = IORD_8DIRECT(SPI_BASE, 0);

        //pattern is not in full units of bytes, so shift back while receiving to check the correct configuration state
        rx_check= (rx_pre | rx ) >> (8-MUTRIG_CONFIG_LEN_BITS%8);
        //if(print) { printf("%03u %02X %02x (%02x)    ",nb, tx,rx, rx_check); }
        //if(print) { pcharb(tx); printf(" "); }
        //if(print) { pcharb(rx); printf(" "); }
        //if(print) { pcharb(rx_check); printf(" "); }
        //if(print) { printf(" \n"); }
        if(nb==MUTRIG_CONFIG_LEN_BYTES-1){
            rx_check &= 0xff>>(8-MUTRIG_CONFIG_LEN_BITS%8);
        };

        if(rx_check!=bitpattern[nb]){
        //printf("Error in byte %d: received %2.2x expected %2.2x\n",nb,rx_check,bitpattern[nb]);
            status=-1;
        }
        rx_pre=rx<<8;
    }while(nb>0);

    return status;
}





void SMB_t::print_config(const alt_u8* bitpattern) {
    uint16_t nb=MUTRIG_CONFIG_LEN_BYTES;
    do{
        nb--;
        printf("%02X ",bitpattern[nb]);
    }while(nb>0);
    printf("\n");
}


//configure ASIC
alt_u16 SMB_t::configure_asic(alt_u32 asic, const alt_u8* bitpattern, int dbglevel) {
    if(dbglevel>0) printf("[SMB] chip_configure(%u)\n", asic); //cmp

    int ret;
    ret = spi_write_pattern(asic, bitpattern, dbglevel>1);

    if(ret != 0) {
        if(dbglevel>0) printf("[scifi] Configuration error (1st try)\n");
    }

    //     usleep(1e5);
    ret = spi_write_pattern(asic, bitpattern, dbglevel>1);

    if(ret != 0) {
        if(dbglevel>0) printf("[scifi] Configuration error (2nd try)\n");
        return FEB_REPLY_ERROR;
    }

    return FEB_REPLY_SUCCESS;
}



//#include "../../../../common/include/feb.h"
using namespace mu3e::daq::feb;
//TODO: add list&document in specbook
alt_u16 SMB_t::sc_callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n, int dbglevel) {
    alt_u16 status=FEB_REPLY_SUCCESS;
    alt_u16 asic = cmd & 0x000F;
    switch (cmd & 0xFFF0){
        case CMD_MUTRIG_ASIC_CFG:
            return configure_asic(asic, (alt_u8*)data, dbglevel+1);
            break;

        case CMD_MUTRIG_ASIC_OFF:
            //TODO make configure all off builtin pattern .h file for M3 
            for(alt_u8 asic = 0; asic < 8; asic++) {
               if(sc_callback(CMD_MUTRIG_ASIC_CFG | asic, (alt_u32*) config_ALL_OFF, 0, dbglevel) == FEB_REPLY_ERROR)
                   status=FEB_REPLY_ERROR;
            }
            return status;
            break;

        default:
            //printf("[sc_callback] unknown command: 0x%X\n", cmd);
            //Commented out for headless
            status=FEB_REPLY_ERROR;
            break;
    }
    return status;
}

extern int uart;
void SMB_t::menu_SMB_main() {
    volatile sc_ram_t* ram = (sc_ram_t*) AVM_SC_BASE;
    uint32_t value = 0x0;
    char str[2] = {0};


    while(1) {
        printf("CTRL DP = 0x%08X\n", ram->data[MUTRIG_CTRL_DP_REGISTER_W]);
        printf("CNT CTRL = 0x%08X\n", ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
        //        TODO: Define menu
        printf("  [s] => sorter counters\n");
        printf("  [m] => monitor menu (temperature, etc.)\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        printf("%c\n", cmd);
        switch(cmd) {
            case 's':
                printf("sorter counters:\n");
                printf("MT_SORTER_NINTIME_REGISTER_R\n");
                for(int i=0; i<2; i++){
                    printf("%i: 0x%08x\n", i, sc.ram->data[MT_SORTER_NINTIME_REGISTER_R+i]);
                }
                printf("MT_SORTER_NOUTOFTIME_REGISTER_R\n");
                for(int i=0; i<2; i++){
                    printf("%i: 0x%08x\n", i, sc.ram->data[MT_SORTER_NOUTOFTIME_REGISTER_R+i]);
                }
                printf("MT_SORTER_NOVERFLOW_REGISTER_R\n");
                for(int i=0; i<2; i++){
                    printf("%i: 0x%08x\n", i, sc.ram->data[MT_SORTER_NOVERFLOW_REGISTER_R+i]);
                }
                printf("MT_SORTER_NOUT_REGISTER_R: 0x%08x\n", sc.ram->data[MT_SORTER_NOUT_REGISTER_R]);
                printf("MT_SORTER_CREDIT_REGISTER_R: 0x%08x\n", sc.ram->data[MT_SORTER_CREDIT_REGISTER_R]);
                printf("MT_SORTER_DELAY_REGISTER_W: 0x%08x\n", sc.ram->data[MT_SORTER_DELAY_REGISTER_W]);
                break;
	        case 'm':
		        menu_SMB_monitors();
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void SMB_t::menu_SMB_monitors() {

    while(1) {
        printf("  [0] => read temperature\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
	switch(cmd) {
            case '0':
		if(((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 11) & 1)==0) printf("Temperature: +");
		else printf(" Temperature: -");
		printf("%dC\n",	((1<<6) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 10) & 1)) +
				((1<<5) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 9)  & 1)) +
				((1<<4) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 8)  & 1)) +
				((1<<3) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 7)  & 1)) +
				((1<<2) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 6)  & 1)) +
				((1<<1) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 5)  & 1)) +
				((1<<0) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 4)  & 1)) +
				((1>>1) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 3)  & 1)) +
				((1>>2) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 2)  & 1)) +
				((1>>3) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W] >> 1)  & 1)) +
				((1>>4) * ((sc.ram->data[MUTRIG_MON_TEMPERATURE_REGISTER_W]) & 1)));
		printf("   [NOTE: +85C is the power-on value, not the physical one]\n");
		break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}
