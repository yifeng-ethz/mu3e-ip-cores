// run_window_db.sv
// Shared stable-RUNNING window database for integration UVM.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Mirror packet_scheduler/tb_int stable run-window singleton.

package tb_int_run_window_pkg;

    // -----------------------------------------------------------------------
    // Shared stable-RUNNING window database.
    //
    // Stable-run loss accounting should follow hits born well inside RUNNING,
    // not those created right on the START/END edges. The run-control driver
    // arms this window in absolute simulation time and stage A tags each hit
    // at its true origin.
    // -----------------------------------------------------------------------
    class tb_int_run_window_db;
        static int unsigned start_guard_cycles = 128;
        static int unsigned end_guard_cycles   = 128;
        static time         run_start_ts       = 0;
        static time         run_end_ts         = 0;
        static time         stable_start_ts    = 0;
        static time         stable_end_ts      = 0;
        static bit          stable_window_open = 1'b0;
        static bit          stable_window_seen = 1'b0;

        static function void configure_guards(int unsigned start_cycles,
                                              int unsigned end_cycles);
            start_guard_cycles = start_cycles;
            end_guard_cycles   = end_cycles;
        endfunction

        static function void reset();
            run_start_ts       = 0;
            run_end_ts         = 0;
            stable_start_ts    = 0;
            stable_end_ts      = 0;
            stable_window_open = 1'b0;
            stable_window_seen = 1'b0;
        endfunction

        static function void note_run_start(time t);
            run_start_ts = t;
            run_end_ts   = 0;
        endfunction

        static function void note_run_end(time t);
            run_end_ts = t;
        endfunction

        static function time get_run_end_ts();
            return run_end_ts;
        endfunction

        static function bit run_end_seen();
            return (run_end_ts != 0);
        endfunction

        static function void note_stable_start(time t);
            stable_start_ts    = t;
            stable_end_ts      = 0;
            stable_window_open = 1'b1;
            stable_window_seen = 1'b1;
        endfunction

        static function void note_stable_end(time t);
            stable_end_ts      = t;
            stable_window_open = 1'b0;
            stable_window_seen = 1'b1;
        endfunction

        static function bit is_stable_origin(time t);
            if (!stable_window_seen)
                return 1'b0;
            if (stable_window_open)
                return (t >= stable_start_ts);
            return (t >= stable_start_ts) && (t < stable_end_ts);
        endfunction

        static function string describe();
            if (!stable_window_seen) begin
                return $sformatf("stable window not armed (guards start=%0d end=%0d cycles)",
                                 start_guard_cycles, end_guard_cycles);
            end
            if (stable_window_open) begin
                return $sformatf("stable_start=%0t stable_end=open (guards start=%0d end=%0d cycles)",
                                 stable_start_ts, start_guard_cycles, end_guard_cycles);
            end
            return $sformatf("stable_start=%0t stable_end=%0t (guards start=%0d end=%0d cycles)",
                             stable_start_ts, stable_end_ts,
                             start_guard_cycles, end_guard_cycles);
        endfunction
    endclass

endpackage
