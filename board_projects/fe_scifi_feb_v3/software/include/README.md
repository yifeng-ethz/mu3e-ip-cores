# NIOS software

 - `i2c.h` - I2C controller
 - `si.h` - SI chip controller
 - `xcvr.h`

## `si`



## `xcvr`

Registers:

- `0x00` - channel
- `0x01` - number of channels

- `0x10` - tx resets (4 - digital reset, 0 - analog reset)
- `0x11` - tx status (0 - tx ready)
- `0x12` - tx errors (8 - fifo error)

- `0x20` - rx resets (4 - digital reset, 0 - analog reset)
- `0x21` - rx status (12 - locked, 11-8 - syncstatus, 2 - locked to ref, 1 - locked to data, 0 - rx ready)
- `0x22` - rx errors (8 - fifo error, 7-4 - disparity error, 3-0 - error detect)

- `0x2A` - rx data
- `0x2B` - rx datak

Menu:

```
#    +--------------------- device
#    |        +------------ channel
#    |        |          +- loopback
#    |        |          |
xcvr[A].ch[0x00], lpbk = 1
#                 +-- digital reset
#                 |+- analog reset
#                 ||
#                 ||   +---- lock status
#                 ||   |+--- sync status
#                 ||   || +- ref.lock status
#                 ||   || |
#                 ||   || |    +--- fifo overflow
#                 ||   || |    |+-- 8b10 disparity error
#                 ||   || |    ||+- 8b10 error
#                 ||   || |    |||
                R_DA S_LS_R E__FDE
  tx    :   OK  0x00 0x0001 0x0000
  rx    :   OK  0x00 0x1F07 0x0000
#                     +- loss of lock counter
#                     |
#                     |            +- 8b10b error counter
#                     |            |
        :   LoL_cnt = 1, err_cnt = 65535
#                    +- data
#                    |     +- control symbols
#                    |     |
  data  :   0x000000BC / 0x1
```

Commands:

- `0-3` - channel
- `r` - reset
- `l` - loopback
- `q` - exit
