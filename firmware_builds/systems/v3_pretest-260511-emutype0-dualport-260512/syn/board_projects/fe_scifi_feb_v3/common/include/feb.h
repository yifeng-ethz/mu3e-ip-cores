#ifndef __MU3E_HARDWARE_SC_H__
#define __MU3E_HARDWARE_SC_H__

#include <cstdint>

namespace mu3e { namespace daq { namespace feb {

/* Mupix specific commands */
const uint16_t CMD_MUPIX_CHIP_CFG            = 0x0110;
const uint16_t CMD_MUPIX_BOARD_CFG           = 0x0120;


/*Timing detector common commands (mutrig)*/
const uint16_t CMD_MUTRIG_ASIC_CFG           = 0x0110; // configure ASIC # with pattern in payload. ASIC number is cmd&0x000F
/*commands 0x0110 ... 0x011f reserved*/
const uint16_t CMD_MUTRIG_ASIC_OFF           = 0x0130; // configure all off builtin pattern
const uint16_t CMD_MUTRIG_CNT_READ           = 0x0150;
const uint16_t CMD_MUTRIG_CNT_RESET          = 0x0160;

/* Tiles specific commands */
const uint16_t CMD_TILE_TMB_INIT             = 0x0200; // set necescary initial values on the TMB
const uint16_t CMD_TILE_ASIC_ON              = 0x0210; // Power and configure  ASIC #. ASIC number is cmd&0x000F if number F then all
const uint16_t CMD_TILE_ASIC_OFF             = 0x0220; // Power down ASIC #. ASIC number is cmd&0x000F if number F then all
const uint16_t CMD_TILE_TEMPERATURES_READ    = 0x0230; // read out the Temperature of all sensors on the TMB
const uint16_t CMD_TILE_POWERMONITORS_READ   = 0x0240; // read out all powermonitors on the TMB
const uint16_t CMD_TILE_TMB_STATUS           = 0x0250; // read out the status of the Powermonitor
const uint16_t CMD_TILE_INJECTION_SETTING    = 0x0260; // change test pulse setting base on last bit: 0 -> off, 1 -> on
const uint16_t CMD_TILE_ENABLE_VDDA          = 0x0270; // turn on analog power for ASIC #. ASIC number is cmd&0x000F
const uint16_t CMD_TILE_DISABLE_VDDA         = 0x0280; // turn off analog pwoer for ASIC #. ASIC number is cmd&0x000F
const uint16_t CMD_TILE_ENABLE_VDDD          = 0x0290; // turn on digital power for ASIC #. ASIC number is cmd&0x000F
const uint16_t CMD_TILE_DISABLE_VDDD         = 0x02a0; // turn off digital power for ASIC #. ASIC number is cmd&0x000F
const uint16_t CMD_TILE_ASIC_STATUS          = 0x02b0; // read out the power status of all ASICs

//const uint16_t CMD_TILE_I2C_WRITE            = 0x0105;

/* SciFi specific commands */
//Fill me

/* FEB common commands */
const uint16_t CMD_PING                      = 0xFFFE;
const uint16_t CMD_FFFF                      = 0xFFFF;

inline
uint32_t make_cmd(uint16_t cmd, uint16_t n = 0) {
    return ((uint32_t)cmd << 16) | ((uint32_t)n & 0xFFFF);
}

} } } // namespace mu3e::daq::feb

#endif // __MU3E_HARDWARE_SC_H__
