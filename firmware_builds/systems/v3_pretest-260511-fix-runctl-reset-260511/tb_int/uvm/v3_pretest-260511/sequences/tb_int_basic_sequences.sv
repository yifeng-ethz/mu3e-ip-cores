// tb_int_basic_sequences.sv
// Directed BASIC-bucket smoke stimulus helpers for v3_pretest tb_int.

package tb_int_basic_sequences_pkg;

    import uvm_pkg::*;
    import tb_int_hit_key_pkg::*;
    import tb_int_run_window_pkg::*;
    import tb_int_runctl_phy_agent_pkg::*;
    import tb_int_sc_phy_agent_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned RUNCTL_CPP_GAP_CYCLES = 125000;
    localparam int unsigned B065_RUNNING_WINDOW_CYCLES = 12500;
    localparam int unsigned B065_HIT_GAP_CYCLES = 625;

    class runctl_seq_firefly extends uvm_sequence#(runctl_phy_item);
        `uvm_object_utils(runctl_seq_firefly)

        function new(string name = "runctl_seq_firefly");
            super.new(name);
        endfunction

        task automatic send_state(runctl_state_e state);
            runctl_phy_item item;

            item = runctl_phy_item::type_id::create("runctl_firefly_item");
            item.state = state;
            item.hold_cycles = RUNCTL_CPP_GAP_CYCLES;
            start_item(item);
            finish_item(item);
        endtask

        virtual task body();
            send_state(RUNCTL_IDLE);
            send_state(RUNCTL_RUN_PREP);
            send_state(RUNCTL_SYNC);
            send_state(RUNCTL_RUNNING);
            send_state(RUNCTL_TERMINATING);
            send_state(RUNCTL_IDLE);
        endtask
    endclass

    class runctl_seq_csr extends uvm_sequence#(sc_phy_item);
        `uvm_object_utils(runctl_seq_csr)

        localparam bit [31:0] RUNCTL_CSR_STATE_ADDR = 32'h0000_D000;

        function new(string name = "runctl_seq_csr");
            super.new(name);
        endfunction

        task automatic write_state(runctl_state_e state);
            sc_phy_item item;

            item = sc_phy_item::type_id::create("runctl_csr_item");
            item.op = SC_WRITE;
            item.address = RUNCTL_CSR_STATE_ADDR;
            item.writedata = state;
            item.byteenable = 4'hf;
            item.idle_cycles = RUNCTL_CPP_GAP_CYCLES;
            start_item(item);
            finish_item(item);
        endtask

        virtual task body();
            write_state(RUNCTL_IDLE);
            write_state(RUNCTL_RUN_PREP);
            write_state(RUNCTL_SYNC);
            write_state(RUNCTL_RUNNING);
            write_state(RUNCTL_TERMINATING);
            write_state(RUNCTL_IDLE);
        endtask
    endclass

    class sc_seq_firefly extends uvm_sequence#(sc_phy_item);
        `uvm_object_utils(sc_seq_firefly)

        function new(string name = "sc_seq_firefly");
            super.new(name);
        endfunction

        task automatic read32(bit [31:0] address);
            sc_phy_item item;

            item = sc_phy_item::type_id::create("sc_firefly_read");
            item.op = SC_READ;
            item.address = address;
            item.byteenable = 4'hf;
            item.idle_cycles = 0;
            start_item(item);
            finish_item(item);
        endtask
    endclass

    class sc_seq_jtag extends sc_seq_firefly;
        `uvm_object_utils(sc_seq_jtag)

        function new(string name = "sc_seq_jtag");
            super.new(name);
        endfunction
    endclass

    class tb_int_basic_sequence extends uvm_object;
        `uvm_object_utils(tb_int_basic_sequence)

        function new(string name = "tb_int_basic_sequence");
            super.new(name);
        endfunction

        function automatic bit [44:0] payload_for_hit(int unsigned hit_idx);
            bit [4:0] channel;
            bit [4:0] t_fine;
            bit [14:0] t_coarse;
            bit [14:0] e_coarse;

            channel = hit_idx % 2;
            t_fine = hit_idx;
            t_coarse = 15'd100 + hit_idx;
            e_coarse = 15'd200 + hit_idx;
            return build_hit0_payload(4'd0,
                                      channel,
                                      t_coarse,
                                      t_fine,
                                      e_coarse,
                                      1'b1);
        endfunction

        task automatic open_run_window(virtual mutrig_l2_commit_if stage_a_vif);
            repeat (8) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::reset();
            tb_int_run_window_db::note_run_start($time);
            tb_int_run_window_db::note_stable_start($time);
        endtask

        task automatic close_run_window(virtual mutrig_l2_commit_if stage_a_vif);
            repeat (4) @(posedge stage_a_vif.clk);
            tb_int_run_window_db::note_stable_end($time);
            tb_int_run_window_db::note_run_end($time);
            repeat (8) @(posedge stage_a_vif.clk);
        endtask

        task automatic drive_case(
            string case_id,
            int unsigned hit_count,
            virtual mutrig_l2_commit_if stage_a_vif,
            virtual mutrig_l2_commit_if debug_l2_vif,
            virtual hit_tap_if pre_rbcam_vif,
            virtual hit_tap_if post_rbcam_vif,
            virtual hit_tap_if debug_pre_rbcam_vif,
            virtual hit_tap_if debug_post_rbcam_vif,
            virtual hit_tap_if debug_feb_egress_vif,
            virtual hit_tap_if feb_egress_vif
        );
            bit [44:0] payload;
            bit [63:0] hit_id;
            bit [15:0] hit_count16;
            bit [15:0] hit_idx16;

            `uvm_info("TB_INT_SEQ",
                      $sformatf("starting %s hit_count=%0d", case_id, hit_count),
                      UVM_LOW)
            open_run_window(stage_a_vif);
            for (int unsigned hit_idx = 0; hit_idx < hit_count; hit_idx++) begin
                payload = payload_for_hit(hit_idx);
                hit_count16 = hit_count;
                hit_idx16 = hit_idx;
                hit_id = {32'hB000_0000, hit_count16, hit_idx16};

                stage_a_vif.drive_commit(4'd0, payload);
                debug_l2_vif.drive_commit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 2'd2);

                pre_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1, 2'd0);
                debug_pre_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 1'b1, 2'd2);

                post_rbcam_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0, 1'b1, 2'd0);
                debug_post_rbcam_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1, 1'b1, 2'd2);

                feb_egress_vif.drive_hit(4'd0, payload, 64'd0, 1'b0, 64'd0, 1'b0,
                                         1'b1, 2'd0);
                debug_feb_egress_vif.drive_hit(4'd0, payload, hit_id, 1'b1, hit_id, 1'b1,
                                               1'b1, 2'd2);
                if (case_id == "B065")
                    repeat (B065_HIT_GAP_CYCLES) @(posedge stage_a_vif.clk);
            end
            if (case_id == "B065")
                repeat (B065_RUNNING_WINDOW_CYCLES) @(posedge stage_a_vif.clk);
            close_run_window(stage_a_vif);
            `uvm_info("TB_INT_SEQ", $sformatf("completed %s", case_id), UVM_LOW)
        endtask
    endclass

    class tb_int_b065_sequence extends tb_int_basic_sequence;
        `uvm_object_utils(tb_int_b065_sequence)
        function new(string name = "tb_int_b065_sequence");
            super.new(name);
        endfunction
    endclass

    class tb_int_b066_sequence extends tb_int_basic_sequence;
        `uvm_object_utils(tb_int_b066_sequence)
        function new(string name = "tb_int_b066_sequence");
            super.new(name);
        endfunction
    endclass

    class tb_int_b067_sequence extends tb_int_basic_sequence;
        `uvm_object_utils(tb_int_b067_sequence)
        function new(string name = "tb_int_b067_sequence");
            super.new(name);
        endfunction
    endclass

    class tb_int_b068_sequence extends tb_int_basic_sequence;
        `uvm_object_utils(tb_int_b068_sequence)
        function new(string name = "tb_int_b068_sequence");
            super.new(name);
        endfunction
    endclass

    class tb_int_b069_sequence extends tb_int_basic_sequence;
        `uvm_object_utils(tb_int_b069_sequence)
        function new(string name = "tb_int_b069_sequence");
            super.new(name);
        endfunction
    endclass

endpackage
