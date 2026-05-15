//-------------------------------------------------------------------------------------
//  Paul Scherrer Institute
//-------------------------------------------------------------------------------------
//
//  Project :  MSCB on MIOSII
//
//  Author  :  rs32/FW
//  Created :  01.04.2016
//
//  Description :  prototype to get MSCB protocol on FPGA
//                 copy from mscb.h for the Wavedream project
//
//-------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------

#ifndef __MSCB_H__
#define __MSCB_H__

/******************************************************************************/
/* constant definitions                                                       */
/******************************************************************************/

#define MSCB_UDP_LISTEN_PORT  1177

#define MSCB_SEND_DST_PORT    1177
#define MSCB_SEND_SRC_PORT    1177

#define TIME_FREQUENCY 50000000 //in MHz

/*---- MSCB commands -----------------------------------------------*/

#define PROTOCOL_VERSION 5
#define INTERCHAR_DELAY 20      // 20us between characters

/* Version history:

1.0 Initial
1.1 Add unit prefix, implement upgrade command
1.2 Add CMD_ECHO, CMD_READ with multiple channels
1.3 Add "set node name"
1.4 Remove CMD_xxxs_CONF
1.5 Return 0x0A for protected pages on upload
1.6 Upload subpages of 60 bytes with ACK
1.7 Upload with simplified CRC code
1.8 Add 20us delay betwee characters for repeater
*/

/*---- MSCB commands -----------------------------------------------*/

#define MCMD_ADDR_NODE8  0x09
#define MCMD_ADDR_NODE16 0x0A
#define MCMD_ADDR_BC     0x10
#define MCMD_ADDR_GRP8   0x11
#define MCMD_ADDR_GRP16  0x12
#define MCMD_PING8       0x19
#define MCMD_PING16      0x1A

#define MCMD_INIT        0x20
#define MCMD_GET_INFO    0x28
#define MCMD_SET_ADDR    0x33
#define MCMD_SET_NAME    0x37
#define MCMD_SET_BAUD    0x39

#define MCMD_FREEZE      0x41
#define MCMD_SYNC        0x49
#define MCMD_SET_TIME    0x4E
#define MCMD_UPGRADE     0x50
#define MCMD_USER        0x58

#define MCMD_ECHO        0x61
#define MCMD_TOKEN       0x68
#define MCMD_GET_UPTIME  0x70

#define MCMD_ACK         0x78

#define MCMD_WRITE_NA    0x80
#define MCMD_WRITE_ACK   0x88

#define MCMD_FLASH       0x98

#define MCMD_READ        0xA0
#define MCMD_WRITE_RANGE 0xA8

#define MCMD_WRITE_MEM   0xB7
#define MCMD_READ_MEM    0xBF

#define GET_INFO_GENERAL   0
#define GET_INFO_VARIABLE  1

#define RS485_FLAG_BIT9      (1<<0)
#define RS485_FLAG_NO_ACK    (1<<1)
#define RS485_FLAG_SHORT_TO  (1<<2)
#define RS485_FLAG_LONG_TO   (1<<3)
#define RS485_FLAG_CMD       (1<<4)
#define RS485_FLAG_ADR_CYCLE (1<<5)

#define ADDR_SET_NODE      1
#define ADDR_SET_HIGH      2
#define ADDR_SET_GROUP     3

/*---- MSCB upgrade commands ---------------------------------------*/

#define UCMD_ECHO          1
#define UCMD_ERASE         2
#define UCMD_PROGRAM       3
#define UCMD_VERIFY        4
#define UCMD_READ          5
#define UCMD_REBOOT        6
#define UCMD_RETURN        7

/*---- flags from the configuration and status register (CSR) ------*/

#define CSR_DEBUG       (1<<0)
#define CSR_LCD_PRESENT (1<<1)
#define CSR_SYNC_MODE   (1<<2)
#define CSR_FREEZE_MODE (1<<3)
#define CSR_WD_RESET    (1<<2)

/*---- baud rates used ---------------------------------------------*/

#define BD_2400            1
#define BD_4800            2
#define BD_9600            3
#define BD_19200           4
#define BD_28800           5
#define BD_38400           6
#define BD_57600           7
#define BD_115200          8
#define BD_172800          9
#define BD_345600         10

/*---- memroy base addresses for CMD_WRITE_MEM/CMD_READ_MEM --------*/

#define MSCB_BASE_RAM     0x00000000
#define MSCB_BASE_NVRAM   0x10000000
#define MSCB_BASE_FLASH   0x20000000
#define MSCB_BASE_CODE    0x30000000

/*---- info structures ---------------------------------------------*/

typedef struct {
    unsigned char protocol_version;
    unsigned char node_status;
    unsigned char n_variables;
    unsigned short node_address;
    unsigned short group_address;
    unsigned short watchdog_resets;
    char node_name[16];
    unsigned char rtc[6];
    unsigned short buf_size;
} MSCB_INFO;

typedef struct {
    unsigned char width;         // width in bytes
    unsigned char unit;          // physical units UNIT_xxxx
    unsigned char prefix;        // unit prefix PRFX_xxx
    unsigned char status;        // status (not yet used)
    unsigned char flags;         // flags MSCBF_xxx
    char name[8];                // name
    void *ud;                    // point to user data buffer

#ifdef CFG_EXTENDED_VARIABLES
    unsigned char  digits;       // number of digits to display after period
    float min, max, delta;       // limits for button control
    unsigned short node_address; // address for remote node on subbus
    unsigned char  channel;      // address for remote channel subbus
#endif
} MSCB_INFO_VAR;

#define MSCBF_FLOAT    (1<<0)   // channel in floating point format
#define MSCBF_SIGNED   (1<<1)   // channel is signed integer
#define MSCBF_DATALESS (1<<2)   // channel doesn't contain data
#define MSCBF_HIDDEN   (1<<3)   // used for internal config parameters
#define MSCBF_REMIN    (1<<4)   // get variable from remote node on subbus
#define MSCBF_REMOUT   (1<<5)   // send variable to remote node on subbus
#define MSCBF_INVALID  (1<<6)   // cannot read remote variable

/* physical units */

#define PRFX_PICO       -12
#define PRFX_NANO        -9
#define PRFX_MICRO       -6
#define PRFX_MILLI       -3
#define PRFX_NONE         0
#define PRFX_KILO         3
#define PRFX_MEGA         6
#define PRFX_GIGA         9
#define PRFX_TERA        12

#define UNIT_UNDEFINED    0

// SI base units
#define UNIT_METER        1
#define UNIT_GRAM         2
#define UNIT_SECOND       3
#define UNIT_MINUTE       4
#define UNIT_HOUR         5
#define UNIT_AMPERE       6
#define UNIT_KELVIN       7
#define UNIT_CELSIUS      8
#define UNIT_FARENHEIT    9

// SI derived units

#define UNIT_HERTZ       20
#define UNIT_PASCAL      21
#define UNIT_BAR         22
#define UNIT_WATT        23
#define UNIT_VOLT        24
#define UNIT_OHM         25
#define UNIT_TESLA       26
#define UNIT_LITERPERSEC 27
#define UNIT_RPM         28
#define UNIT_FARAD       29
#define UNIT_JOULE       30

// computer units

#define UNIT_BOOLEAN     50
#define UNIT_BYTE        52
#define UNIT_WORD        53
#define UNIT_DWORD       54
#define UNIT_ASCII       55
#define UNIT_STRING      56
#define UNIT_BAUD        57

// others

#define UNIT_PERCENT     90
#define UNIT_PPM         91
#define UNIT_COUNT       92
#define UNIT_FACTOR      93

/*------------------------------------------------------------------*/

typedef struct {                // system info stored in EEPROM
    unsigned int node_addr;
    unsigned int group_addr;
    unsigned int revision;
    char node_name[16];
} SYS_INFO;

#endif /* MSCB_H_ */
