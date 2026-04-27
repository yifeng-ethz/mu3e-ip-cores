#ifndef SMB_MODULE_H_
#define SMB_MODULE_H_

#include <sys/alt_alarm.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>

#include "include/i2c.h"

//forward declarations
struct sc_t;

#include "smb_constants.h"

struct SMB_t {
    sc_t& sc;
    //TODO: add spi in parameters
    SMB_t(sc_t& _sc):sc(_sc){};
    int n_MODULES=2; // TODO: Should this be a variable?

    //=========================
    //ASIC configuration
    //write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1. Does not include CSn line switching.
    int spi_write_pattern(alt_u32 spi_slave, const alt_u8* bitpattern, bool print);
    //write and verify pattern twice, toggle i2c lines via i2c
    alt_u16     configure_asic(alt_u32 asic, const alt_u8* bitpattern, int dbglevel);
    //print out a given pattern for debugging
    void        print_config(const alt_u8* bitpattern);
 
    void        read_CEC(int asic){asic++;};//TODO

    //=========================
    //Menu functions for command line use
    void menu_SMB_monitors();
    void menu_SMB_main();
    //Slow control callback
    alt_u16 sc_callback(alt_u16 cmd, volatile alt_u32* data, alt_u16 n, int dbglevel=0);

};
#endif
