#

# flags
set_setting hal.make.bsp_cflags_debug -g
set_setting hal.make.bsp_cflags_optimization -Os
set_setting hal.make.bsp_cflags_warnings "-Wall -Wextra"

# logging
#set_setting hal.log_port jtag_uart
#set_setting hal.log_flags 1

# exit
set_setting hal.enable_exit true
set_setting hal.enable_clean_exit true

# timers
set_setting hal.sys_clk_timer timer
set_setting hal.timestamp_timer timer_ts

# drivers
set_setting hal.enable_small_c_library true
set_setting hal.enable_reduced_device_drivers false
set_setting hal.enable_lightweight_device_driver_api false
