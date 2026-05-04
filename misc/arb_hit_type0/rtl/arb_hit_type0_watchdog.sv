// arb_hit_type0_watchdog.sv
// Frame-alignment watchdog eligibility for stranded source packets.
//
// Version : 26.2.0
// Date    : 20260504
// Change  : Split frame-alignment watchdog decision logic out of the top.

module arb_hit_type0_watchdog (
    input  logic [15:0] watchdog_cycles,
    input  logic        grant_enable,
    input  logic        real_open,
    input  logic        emu_open,
    input  logic        eor_seen_real,
    input  logic        eor_seen_emu,
    input  logic        merged_locked,
    input  logic [15:0] idle_cycles_real,
    input  logic [15:0] idle_cycles_emu,
    output logic        fire_real,
    output logic        fire_emu
);

    logic watchdog_enabled;
    logic real_eligible;
    logic emu_eligible;

    assign watchdog_enabled = (watchdog_cycles != 16'd0);

    assign real_eligible    = watchdog_enabled & real_open &
                              (idle_cycles_real > watchdog_cycles) &
                              (eor_seen_emu |
                               (~emu_open & (idle_cycles_emu > watchdog_cycles)));

    assign emu_eligible     = watchdog_enabled & emu_open &
                              (idle_cycles_emu > watchdog_cycles) &
                              (eor_seen_real |
                               (~real_open & (idle_cycles_real > watchdog_cycles)));

    assign fire_real        = real_eligible &
                              (~emu_eligible | (idle_cycles_real >= idle_cycles_emu)) &
                              grant_enable & ~merged_locked;

    assign fire_emu         = emu_eligible & ~fire_real & grant_enable & ~merged_locked;

endmodule
