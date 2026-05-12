`timescale 1ns/1ps

package cosim_scoreboard_pkg;
    import uvm_pkg::*;
    import feb_egress_meta_pkg::*;
    import feb_egress_monitor_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        COSIM_CP_PRE_RBCAM = 0,
        COSIM_CP_POST_RBCAM = 1,
        COSIM_CP_FEB_EGRESS = 2,
        COSIM_CP_SWB_INGRESS = 3,
        COSIM_CP_OPQ_EGRESS = 4,
        COSIM_CP_RDMA_EGRESS = 5
    } cosim_checkpoint_e;

    class cosim_checkpoint_record extends uvm_sequence_item;
        `uvm_object_utils(cosim_checkpoint_record)

        longint unsigned hit_id;
        time             ts_birth;
        time             ts_checkpoint;
        cosim_checkpoint_e checkpoint;
        int unsigned     lane;
        int unsigned     channel;

        function new(string name = "cosim_checkpoint_record");
            super.new(name);
        endfunction

        function time delta();
            return (ts_checkpoint >= ts_birth) ? (ts_checkpoint - ts_birth) : 0;
        endfunction
    endclass

    `uvm_analysis_imp_decl(_wave)
    `uvm_analysis_imp_decl(_meta)
    `uvm_analysis_imp_decl(_checkpoint)

    class cosim_scoreboard extends uvm_component;
        `uvm_component_utils(cosim_scoreboard)

        uvm_analysis_imp_wave#(feb_egress_waveform_cycle,
                               cosim_scoreboard) wave_imp;
        uvm_analysis_imp_meta#(feb_egress_meta_record,
                               cosim_scoreboard) meta_imp;
        uvm_analysis_imp_checkpoint#(cosim_checkpoint_record,
                                     cosim_scoreboard) checkpoint_imp;

        longint unsigned wave_cycles;
        longint unsigned wave_valid_cycles;
        longint unsigned meta_count;
        longint unsigned checkpoint_count[int unsigned];
        time ts_birth_by_hit[longint unsigned];

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            wave_imp = new("wave_imp", this);
            meta_imp = new("meta_imp", this);
            checkpoint_imp = new("checkpoint_imp", this);
        endfunction

        function void write_wave(feb_egress_waveform_cycle item);
            if (item == null)
                return;
            wave_cycles++;
            if (item.valid && item.ready)
                wave_valid_cycles++;
        endfunction

        function void write_meta(feb_egress_meta_record item);
            if (item == null)
                return;
            ts_birth_by_hit[item.hit_id] = item.ts_birth;
            meta_count++;
        endfunction

        function void write_checkpoint(cosim_checkpoint_record item);
            if (item == null)
                return;
            checkpoint_count[item.checkpoint]++;
            if (ts_birth_by_hit.exists(item.hit_id))
                item.ts_birth = ts_birth_by_hit[item.hit_id];
        endfunction
    endclass
endpackage
