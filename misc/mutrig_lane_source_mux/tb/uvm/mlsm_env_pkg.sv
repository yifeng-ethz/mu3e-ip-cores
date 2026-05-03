`timescale 1ns/1ps

package mlsm_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned MLSM_FIRST_VALIDLESS_CASE = 32;

    typedef struct packed {
        bit [8:0] data;
        bit [3:0] channel;
        bit [2:0] error;
    } mlsm_beat_t;

    class mlsm_coverage extends uvm_component;
        `uvm_component_utils(mlsm_coverage)

        int unsigned case_id;
        int unsigned mode;
        int unsigned real_always_valid;
        int unsigned real_valid_seen;
        int unsigned emu_valid_seen;
        int unsigned drop_seen;

        covergroup mlsm_cg;
            option.per_instance = 1;
            cp_case: coverpoint case_id {
                bins directed[] = {[0:63]};
            }
            cp_mode: coverpoint mode {
                bins real_mode = {0};
                bins emu_mode  = {1};
                bins rr_mode   = {2};
            }
            cp_rav: coverpoint real_always_valid {
                bins valid_qualified = {0};
                bins validless       = {1};
            }
            cp_real_valid: coverpoint real_valid_seen {
                bins no  = {0};
                bins yes = {1};
            }
            cp_emu_valid: coverpoint emu_valid_seen {
                bins no  = {0};
                bins yes = {1};
            }
            cp_drop_seen: coverpoint drop_seen {
                bins no  = {0};
                bins yes = {1};
            }
            cx_mode_rav: cross cp_mode, cp_rav;
            cx_case_rav: cross cp_case, cp_rav;
        endgroup

        function new(string name = "mlsm_coverage", uvm_component parent = null);
            super.new(name, parent);
            mlsm_cg = new();
        endfunction

        function void sample(
            int unsigned sample_case_id,
            int unsigned sample_mode,
            int unsigned sample_real_always_valid,
            bit          sample_real_valid_seen,
            bit          sample_emu_valid_seen,
            bit          sample_drop_seen
        );
            case_id           = sample_case_id;
            mode              = sample_mode;
            real_always_valid = sample_real_always_valid;
            real_valid_seen   = sample_real_valid_seen;
            emu_valid_seen    = sample_emu_valid_seen;
            drop_seen         = sample_drop_seen;
            mlsm_cg.sample();
        endfunction
    endclass

    class mlsm_env extends uvm_env;
        `uvm_component_utils(mlsm_env)

        mlsm_coverage cov;

        function new(string name = "mlsm_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            cov = mlsm_coverage::type_id::create("cov", this);
        endfunction
    endclass

    class mlsm_base_test extends uvm_test;
        `uvm_component_utils(mlsm_base_test)

        virtual mlsm_if vif;
        mlsm_env        env;

        int unsigned real_always_valid;
        int unsigned fifo_depth;
        int unsigned meta_select;
        bit          select_emulator;
        bit          mixed_rr_enable;
        bit          rr_next_emulator;

        mlsm_beat_t real_fifo[$];
        mlsm_beat_t emu_fifo[$];

        longint unsigned real_beat_count;
        longint unsigned emu_beat_count;
        longint unsigned selected_beat_count;
        longint unsigned source_switch_count;
        longint unsigned real_drop_count;
        longint unsigned emu_drop_count;
        longint unsigned real_selected_count;
        longint unsigned emu_selected_count;
        bit              last_selected_source;
        mlsm_beat_t      last_selected;

        function new(string name = "mlsm_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = mlsm_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual mlsm_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "mlsm_if was not configured")
            end
            if (!uvm_config_db#(int)::get(this, "", "real_always_valid", real_always_valid)) begin
                real_always_valid = 1;
            end
            if (!uvm_config_db#(int)::get(this, "", "fifo_depth", fifo_depth)) begin
                fifo_depth = 16;
            end
        endfunction

        function bit real_effective_valid(bit raw_valid);
            return (real_always_valid != 0) ? 1'b1 : raw_valid;
        endfunction

        function int unsigned current_mode;
            if (mixed_rr_enable) begin
                return 2;
            end
            return select_emulator ? 1 : 0;
        endfunction

        function mlsm_beat_t make_beat(int unsigned case_id, int unsigned idx, bit emu_source);
            mlsm_beat_t beat;
            beat.data    = {emu_source, case_id[3:0], idx[3:0]};
            beat.channel = (emu_source ? 4'h8 : 4'h1) ^ idx[3:0];
            beat.error   = emu_source ? {1'b0, idx[1:0]} : {idx[0], 1'b0, idx[1]};
            return beat;
        endfunction

        function bit mixed_visible(output mlsm_beat_t beat, output bit source_emulator);
            beat            = '0;
            source_emulator = 1'b0;

            if (!mixed_rr_enable) begin
                return 1'b0;
            end

            if ((real_fifo.size() != 0) && (emu_fifo.size() != 0)) begin
                source_emulator = rr_next_emulator;
                beat            = rr_next_emulator ? emu_fifo[0] : real_fifo[0];
                return 1'b1;
            end
            if (real_fifo.size() != 0) begin
                source_emulator = 1'b0;
                beat            = real_fifo[0];
                return 1'b1;
            end
            if (emu_fifo.size() != 0) begin
                source_emulator = 1'b1;
                beat            = emu_fifo[0];
                return 1'b1;
            end
            return 1'b0;
        endfunction

        function void reset_model;
            real_fifo.delete();
            emu_fifo.delete();
            meta_select          = 0;
            select_emulator      = 1'b0;
            mixed_rr_enable      = 1'b0;
            rr_next_emulator     = 1'b0;
            real_beat_count      = 0;
            emu_beat_count       = 0;
            selected_beat_count  = 0;
            source_switch_count  = 0;
            real_drop_count      = 0;
            emu_drop_count       = 0;
            real_selected_count  = 0;
            emu_selected_count   = 0;
            last_selected_source = 1'b0;
            last_selected        = '0;
        endfunction

        function void model_saturating_inc(ref longint unsigned value);
            if (value < 32'hFFFF_FFFF) begin
                value++;
            end
        endfunction

        function void model_selected(bit source_emulator, mlsm_beat_t beat);
            model_saturating_inc(selected_beat_count);
            last_selected_source = source_emulator;
            last_selected        = beat;
            if (source_emulator) begin
                model_saturating_inc(emu_selected_count);
            end else begin
                model_saturating_inc(real_selected_count);
            end
        endfunction

        task automatic reset_dut;
            vif.drive_quiet();
            vif.probe_clear = 1'b0;
            vif.rst = 1'b1;
            reset_model();
            repeat (5) @(posedge vif.clk);
            vif.rst = 1'b0;
            repeat (2) @(posedge vif.clk);
            #1;
        endtask

        task automatic clear_probe_window;
            vif.probe_clear = 1'b1;
            #1;
            vif.probe_clear = 1'b0;
            #1;
        endtask

        task automatic check_output(
            string       where,
            bit          expected_valid,
            mlsm_beat_t  expected_beat
        );
            if (vif.aso_valid !== expected_valid) begin
                `uvm_error("ASO_VALID", $sformatf("%s expected valid=%0b got %0b", where, expected_valid, vif.aso_valid))
            end
            if (expected_valid) begin
                if ((vif.aso_data !== expected_beat.data) ||
                    (vif.aso_channel !== expected_beat.channel) ||
                    (vif.aso_error !== expected_beat.error)) begin
                    `uvm_error("ASO_DATA",
                        $sformatf("%s expected data=%03h ch=%0h err=%0h got data=%03h ch=%0h err=%0h",
                                  where,
                                  expected_beat.data,
                                  expected_beat.channel,
                                  expected_beat.error,
                                  vif.aso_data,
                                  vif.aso_channel,
                                  vif.aso_error))
                end
            end
        endtask

        task automatic advance_cycle(
            int unsigned case_id,
            bit          real_valid,
            mlsm_beat_t  real_beat,
            bit          emu_valid,
            mlsm_beat_t  emu_beat,
            bit          csr_write,
            bit [3:0]    csr_address,
            bit [31:0]   csr_writedata,
            bit          skip_output_check = 1'b0
        );
            bit         pre_visible;
            bit         pre_source_emulator;
            mlsm_beat_t pre_beat;
            bit         pop_real;
            bit         pop_emu;
            bit         old_real_full;
            bit         old_emu_full;
            bit         accept_real;
            bit         accept_emu;
            bit         drop_real;
            bit         drop_emu;
            bit [1:0]   old_mode;
            bit [1:0]   requested_mode;
            bit         post_visible;
            bit         post_source_emulator;
            mlsm_beat_t post_beat;
            bit         post_expected_valid;
            mlsm_beat_t post_expected_beat;

            vif.asi_real_data     = real_beat.data;
            vif.asi_real_valid    = real_valid;
            vif.asi_real_error    = real_beat.error;
            vif.asi_real_channel  = real_beat.channel;
            vif.asi_emu_data      = emu_beat.data;
            vif.asi_emu_valid     = emu_valid;
            vif.asi_emu_error     = emu_beat.error;
            vif.asi_emu_channel   = emu_beat.channel;
            vif.avs_csr_address   = csr_address;
            vif.avs_csr_writedata = csr_writedata;
            vif.avs_csr_write     = csr_write;
            vif.avs_csr_read      = 1'b0;

            pre_visible = mixed_visible(pre_beat, pre_source_emulator);
            old_mode    = current_mode()[1:0];

            @(posedge vif.clk);
            #1;

            if (real_effective_valid(real_valid)) begin
                model_saturating_inc(real_beat_count);
            end
            if (emu_valid) begin
                model_saturating_inc(emu_beat_count);
            end

            if (mixed_rr_enable) begin
                if (pre_visible) begin
                    model_selected(pre_source_emulator, pre_beat);
                end

                old_real_full = (real_fifo.size() >= fifo_depth);
                old_emu_full  = (emu_fifo.size() >= fifo_depth);
                pop_real      = 1'b0;
                pop_emu       = 1'b0;

                if ((real_fifo.size() != 0) && (emu_fifo.size() != 0)) begin
                    pop_emu  = rr_next_emulator;
                    pop_real = !rr_next_emulator;
                end else if (real_fifo.size() != 0) begin
                    pop_real = 1'b1;
                end else if (emu_fifo.size() != 0) begin
                    pop_emu = 1'b1;
                end

                accept_real = real_effective_valid(real_valid) && (!old_real_full || pop_real);
                accept_emu  = emu_valid && (!old_emu_full || pop_emu);
                drop_real   = real_effective_valid(real_valid) && !accept_real;
                drop_emu    = emu_valid && !accept_emu;

                if (drop_real) begin
                    model_saturating_inc(real_drop_count);
                end
                if (drop_emu) begin
                    model_saturating_inc(emu_drop_count);
                end

                if (pop_real) begin
                    void'(real_fifo.pop_front());
                    rr_next_emulator = 1'b1;
                end
                if (pop_emu) begin
                    void'(emu_fifo.pop_front());
                    rr_next_emulator = 1'b0;
                end
                if (accept_real) begin
                    real_fifo.push_back(real_beat);
                end
                if (accept_emu) begin
                    emu_fifo.push_back(emu_beat);
                end
            end else if (select_emulator) begin
                if (emu_valid) begin
                    model_selected(1'b1, emu_beat);
                end
            end else begin
                if (real_effective_valid(real_valid)) begin
                    model_selected(1'b0, real_beat);
                end
            end

            if (csr_write) begin
                if (csr_address == 4'h1) begin
                    meta_select = csr_writedata[1:0];
                end else if (csr_address == 4'h2) begin
                    requested_mode = csr_writedata[2] ? 2'd2 : (csr_writedata[0] ? 2'd1 : 2'd0);
                    if (old_mode != requested_mode) begin
                        model_saturating_inc(source_switch_count);
                        real_fifo.delete();
                        emu_fifo.delete();
                        rr_next_emulator = 1'b0;
                    end
                    select_emulator = csr_writedata[0];
                    mixed_rr_enable = csr_writedata[2];
                    if (csr_writedata[1]) begin
                        real_fifo.delete();
                        emu_fifo.delete();
                        rr_next_emulator     = 1'b0;
                        real_beat_count      = 0;
                        emu_beat_count       = 0;
                        selected_beat_count  = 0;
                        source_switch_count  = 0;
                        real_drop_count      = 0;
                        emu_drop_count       = 0;
                        real_selected_count  = 0;
                        emu_selected_count   = 0;
                        last_selected_source = csr_writedata[0];
                        last_selected        = '0;
                    end
                end
            end

            if (!skip_output_check) begin
                if (mixed_rr_enable) begin
                    post_visible = mixed_visible(post_beat, post_source_emulator);
                    check_output($sformatf("case%0d mixed post-cycle", case_id), post_visible, post_beat);
                end else begin
                    if (select_emulator) begin
                        post_expected_valid = emu_valid;
                        post_expected_beat  = emu_beat;
                    end else begin
                        post_expected_valid = real_effective_valid(real_valid);
                        post_expected_beat  = real_beat;
                    end
                    check_output($sformatf("case%0d direct post-cycle", case_id), post_expected_valid, post_expected_beat);
                end
            end

            env.cov.sample(case_id, current_mode(), real_always_valid, real_effective_valid(real_valid), emu_valid, drop_real || drop_emu);

            vif.avs_csr_write     = 1'b0;
            vif.avs_csr_writedata = 32'd0;
            vif.avs_csr_address   = 4'd0;
        endtask

        task automatic idle_cycle(int unsigned case_id, bit skip_output_check = 1'b0);
            mlsm_beat_t real_idle;
            mlsm_beat_t emu_idle;
            real_idle = '0;
            emu_idle  = '0;
            advance_cycle(case_id, 1'b0, real_idle, 1'b0, emu_idle, 1'b0, 4'd0, 32'd0, skip_output_check);
        endtask

        task automatic csr_write32(bit [3:0] address, bit [31:0] data, int unsigned case_id);
            mlsm_beat_t real_idle;
            mlsm_beat_t emu_idle;
            real_idle = '0;
            emu_idle  = '0;
            advance_cycle(case_id, 1'b0, real_idle, 1'b0, emu_idle, 1'b1, address, data, 1'b1);
        endtask

        task automatic csr_read32(bit [3:0] address, output bit [31:0] data);
            vif.avs_csr_address = address;
            vif.avs_csr_read    = 1'b1;
            #1;
            data                = vif.avs_csr_readdata;
            vif.avs_csr_read    = 1'b0;
            vif.avs_csr_address = 4'd0;
            #1;
        endtask

        task automatic set_mode(bit select_emu, bit mixed_rr, int unsigned case_id);
            csr_write32(4'h2, {29'd0, mixed_rr, 1'b0, select_emu}, case_id);
        endtask

        task automatic clear_counters(int unsigned case_id);
            csr_write32(4'h2, {29'd0, mixed_rr_enable, 1'b1, select_emulator}, case_id);
            clear_probe_window();
        endtask

        task automatic expect_csr(string name, bit [3:0] address, bit [31:0] expected);
            bit [31:0] data;
            csr_read32(address, data);
            if (data !== expected) begin
                `uvm_error("CSR",
                    $sformatf("%s addr=%0h expected=%08h got=%08h", name, address, expected, data))
            end
        endtask

        task automatic expect_downstream_probe_snapshot(string name);
            if (vif.probe_valid_count !== selected_beat_count[31:0]) begin
                `uvm_error("DOWNSTREAM_PROBE",
                    $sformatf("%s expected probe_count=%08h got=%08h",
                              name, selected_beat_count[31:0], vif.probe_valid_count))
            end
            if (selected_beat_count != 0) begin
                if ((vif.probe_last_data !== last_selected.data) ||
                    (vif.probe_last_channel !== last_selected.channel) ||
                    (vif.probe_last_error !== last_selected.error)) begin
                    `uvm_error("DOWNSTREAM_PROBE",
                        $sformatf("%s expected last data=%03h ch=%0h err=%0h got data=%03h ch=%0h err=%0h",
                                  name,
                                  last_selected.data,
                                  last_selected.channel,
                                  last_selected.error,
                                  vif.probe_last_data,
                                  vif.probe_last_channel,
                                  vif.probe_last_error))
                end
            end
        endtask

        task automatic expect_counter_snapshot(string name);
            expect_csr({name, " real"}, 4'h4, real_beat_count[31:0]);
            expect_csr({name, " emu"}, 4'h5, emu_beat_count[31:0]);
            expect_csr({name, " selected"}, 4'h6, selected_beat_count[31:0]);
            expect_csr({name, " switch"}, 4'h7, source_switch_count[31:0]);
            expect_csr({name, " real_drop"}, 4'ha, real_drop_count[31:0]);
            expect_csr({name, " emu_drop"}, 4'hb, emu_drop_count[31:0]);
            expect_csr({name, " real_selected"}, 4'hc, real_selected_count[31:0]);
            expect_csr({name, " emu_selected"}, 4'hd, emu_selected_count[31:0]);
            expect_downstream_probe_snapshot({name, " downstream"});
        endtask

        task automatic expect_mixed_pressure_snapshot(string name, bit require_drop);
            bit [31:0] data_real;
            bit [31:0] data_emu;
            bit [31:0] data_selected;
            bit [31:0] data_real_drop;
            bit [31:0] data_emu_drop;
            bit [31:0] data_real_selected;
            bit [31:0] data_emu_selected;

            csr_read32(4'h4, data_real);
            csr_read32(4'h5, data_emu);
            csr_read32(4'h6, data_selected);
            csr_read32(4'ha, data_real_drop);
            csr_read32(4'hb, data_emu_drop);
            csr_read32(4'hc, data_real_selected);
            csr_read32(4'hd, data_emu_selected);

            if (data_real !== real_beat_count[31:0]) begin
                `uvm_error("CSR", $sformatf("%s real expected=%08h got=%08h", name, real_beat_count[31:0], data_real))
            end
            if (data_emu !== emu_beat_count[31:0]) begin
                `uvm_error("CSR", $sformatf("%s emu expected=%08h got=%08h", name, emu_beat_count[31:0], data_emu))
            end
            if ((data_real_selected + data_emu_selected) !== data_selected) begin
                `uvm_error("CSR", $sformatf("%s selected source sum mismatch selected=%08h real_sel=%08h emu_sel=%08h",
                                            name, data_selected, data_real_selected, data_emu_selected))
            end
            if (require_drop && ((data_real_drop + data_emu_drop) == 0)) begin
                `uvm_error("CSR", $sformatf("%s expected at least one mixed FIFO drop", name))
            end
            expect_downstream_probe_snapshot({name, " downstream"});
        endtask

        task automatic expect_validless_direct_snapshot(string name, bit emulator_mode);
            bit [31:0] data_real;
            bit [31:0] data_selected;
            bit [31:0] data_real_drop;
            bit [31:0] data_emu_drop;
            bit [31:0] data_real_selected;
            bit [31:0] data_emu_selected;

            csr_read32(4'h4, data_real);
            csr_read32(4'h6, data_selected);
            csr_read32(4'ha, data_real_drop);
            csr_read32(4'hb, data_emu_drop);
            csr_read32(4'hc, data_real_selected);
            csr_read32(4'hd, data_emu_selected);

            if (data_real == 0) begin
                `uvm_error("CSR", $sformatf("%s expected nonzero validless real input count", name))
            end
            if ((data_real_drop != 0) || (data_emu_drop != 0)) begin
                `uvm_error("CSR", $sformatf("%s non-mixed drops must stay zero real_drop=%08h emu_drop=%08h",
                                            name, data_real_drop, data_emu_drop))
            end
            if ((data_real_selected + data_emu_selected) !== data_selected) begin
                `uvm_error("CSR", $sformatf("%s selected source sum mismatch selected=%08h real_sel=%08h emu_sel=%08h",
                                            name, data_selected, data_real_selected, data_emu_selected))
            end
            if (emulator_mode) begin
                if ((data_real_selected != 0) || (data_emu_selected != data_selected)) begin
                    `uvm_error("CSR", $sformatf("%s emulator mode selected source mismatch selected=%08h real_sel=%08h emu_sel=%08h",
                                                name, data_selected, data_real_selected, data_emu_selected))
                end
            end else begin
                if ((data_emu_selected != 0) || (data_real_selected != data_selected)) begin
                    `uvm_error("CSR", $sformatf("%s real mode selected source mismatch selected=%08h real_sel=%08h emu_sel=%08h",
                                                name, data_selected, data_real_selected, data_emu_selected))
                end
            end
            expect_downstream_probe_snapshot({name, " downstream"});
        endtask

        task automatic expect_validless_switch_snapshot(string name);
            bit [31:0] data_real;
            bit [31:0] data_selected;
            bit [31:0] data_real_selected;
            bit [31:0] data_emu_selected;

            csr_read32(4'h4, data_real);
            csr_read32(4'h6, data_selected);
            csr_read32(4'hc, data_real_selected);
            csr_read32(4'hd, data_emu_selected);

            if (data_real == 0) begin
                `uvm_error("CSR", $sformatf("%s expected nonzero validless real input count", name))
            end
            if ((data_real_selected + data_emu_selected) !== data_selected) begin
                `uvm_error("CSR", $sformatf("%s selected source sum mismatch selected=%08h real_sel=%08h emu_sel=%08h",
                                            name, data_selected, data_real_selected, data_emu_selected))
            end
            if ((data_real_selected == 0) || (data_emu_selected == 0)) begin
                `uvm_error("CSR", $sformatf("%s expected both sources selected during switching real_sel=%08h emu_sel=%08h",
                                            name, data_real_selected, data_emu_selected))
            end
            expect_downstream_probe_snapshot({name, " downstream"});
        endtask

        task automatic expect_identity(int unsigned case_id);
            bit [31:0] data;
            csr_read32(4'h0, data);
            if (data !== 32'h4D4C534D) begin
                `uvm_error("UID", $sformatf("case%0d UID expected MLSM got %08h", case_id, data))
            end
            csr_write32(4'h1, 32'd0, case_id);
            csr_read32(4'h1, data);
            if (data[31:16] !== 16'h1A02) begin
                `uvm_error("META", $sformatf("case%0d version major/minor expected 26.2 got %08h", case_id, data))
            end
            csr_write32(4'h1, 32'd1, case_id);
            expect_csr("date meta", 4'h1, 32'd20260503);
            csr_write32(4'h1, 32'd3, case_id);
            expect_csr("instance meta", 4'h1, 32'h000051A0);
        endtask

        task automatic drive_direct_burst(
            int unsigned case_id,
            bit          emulator_mode,
            int unsigned beats,
            int unsigned gap_mod
        );
            mlsm_beat_t real_beat;
            mlsm_beat_t emu_beat;
            set_mode(emulator_mode, 1'b0, case_id);
            clear_counters(case_id);
            for (int unsigned idx = 0; idx < beats; idx++) begin
                real_beat = make_beat(case_id, idx, 1'b0);
                emu_beat  = make_beat(case_id, idx, 1'b1);
                if (gap_mod != 0 && ((idx % gap_mod) == 0)) begin
                    idle_cycle(case_id);
                end
                advance_cycle(case_id,
                              !emulator_mode,
                              real_beat,
                              emulator_mode,
                              emu_beat,
                              1'b0,
                              4'd0,
                              32'd0);
            end
            idle_cycle(case_id);
            if (real_always_valid == 0) begin
                expect_counter_snapshot($sformatf("direct case%0d", case_id));
            end else begin
                if (!emulator_mode) begin
                    set_mode(1'b1, 1'b0, case_id);
                end
                expect_validless_direct_snapshot($sformatf("direct case%0d", case_id), emulator_mode);
            end
        endtask

        task automatic drive_mixed_burst(
            int unsigned case_id,
            int unsigned beats,
            int unsigned emu_period,
            bit          force_overflow
        );
            mlsm_beat_t real_beat;
            mlsm_beat_t emu_beat;
            bit         emu_valid;

            set_mode(1'b0, 1'b1, case_id);
            clear_counters(case_id);
            for (int unsigned idx = 0; idx < beats; idx++) begin
                real_beat = make_beat(case_id, idx, 1'b0);
                emu_beat  = make_beat(case_id, idx, 1'b1);
                emu_valid = (emu_period == 0) ? 1'b1 : ((idx % emu_period) == 0);
                advance_cycle(case_id,
                              (real_always_valid == 0) ? 1'b1 : 1'b0,
                              real_beat,
                              emu_valid,
                              emu_beat,
                              1'b0,
                              4'd0,
                              32'd0);
            end
            if (real_always_valid == 0) begin
                int unsigned drain_guard;
                drain_guard = 0;
                while (((real_fifo.size() != 0) || (emu_fifo.size() != 0)) &&
                       (drain_guard < (beats + (4 * fifo_depth) + 16))) begin
                    idle_cycle(case_id);
                    drain_guard++;
                end
                idle_cycle(case_id);
                if ((real_fifo.size() != 0) || (emu_fifo.size() != 0)) begin
                    `uvm_error("DRAIN", $sformatf("case%0d mixed drain guard expired real_q=%0d emu_q=%0d",
                                                  case_id, real_fifo.size(), emu_fifo.size()))
                end
            end else begin
                repeat (fifo_depth + 5) begin
                    idle_cycle(case_id);
                end
            end
            if (force_overflow && (real_drop_count + emu_drop_count == 0)) begin
                `uvm_error("DROP", $sformatf("case%0d expected at least one mixed FIFO drop", case_id))
            end
            if (real_always_valid == 0) begin
                expect_counter_snapshot($sformatf("mixed case%0d", case_id));
            end else begin
                set_mode(1'b1, 1'b0, case_id);
                expect_mixed_pressure_snapshot($sformatf("mixed case%0d", case_id), force_overflow);
            end
        endtask

        task automatic drive_switching_case(int unsigned case_id);
            mlsm_beat_t real_beat;
            mlsm_beat_t emu_beat;
            expect_identity(case_id);
            set_mode(1'b0, 1'b0, case_id);
            clear_counters(case_id);
            for (int unsigned idx = 0; idx < 4; idx++) begin
                real_beat = make_beat(case_id, idx, 1'b0);
                emu_beat  = make_beat(case_id, idx, 1'b1);
                advance_cycle(case_id, (real_always_valid == 0), real_beat, 1'b0, emu_beat, 1'b0, 4'd0, 32'd0);
            end
            set_mode(1'b1, 1'b0, case_id);
            for (int unsigned idx = 4; idx < 8; idx++) begin
                real_beat = make_beat(case_id, idx, 1'b0);
                emu_beat  = make_beat(case_id, idx, 1'b1);
                advance_cycle(case_id, 1'b0, real_beat, 1'b1, emu_beat, 1'b0, 4'd0, 32'd0);
            end
            set_mode(1'b0, 1'b1, case_id);
            for (int unsigned idx = 8; idx < 16; idx++) begin
                real_beat = make_beat(case_id, idx, 1'b0);
                emu_beat  = make_beat(case_id, idx, 1'b1);
                advance_cycle(case_id, (real_always_valid == 0), real_beat, (idx[0] == 1'b0), emu_beat, 1'b0, 4'd0, 32'd0);
            end
            repeat (fifo_depth + 4) begin
                idle_cycle(case_id);
            end
            if (real_always_valid == 0) begin
                expect_counter_snapshot($sformatf("switch case%0d", case_id));
            end else begin
                set_mode(1'b1, 1'b0, case_id);
                expect_validless_switch_snapshot($sformatf("switch case%0d", case_id));
            end
        endtask

        task automatic run_case_body(int unsigned case_id, bit reset_first);
            int unsigned local_id;
            if (reset_first) begin
                reset_dut();
            end
            local_id = case_id % MLSM_FIRST_VALIDLESS_CASE;

            if ((case_id < MLSM_FIRST_VALIDLESS_CASE) && (real_always_valid != 0)) begin
                `uvm_fatal("RAVCFG", $sformatf("case%0d requires REAL_ALWAYS_VALID=0", case_id))
            end
            if ((case_id >= MLSM_FIRST_VALIDLESS_CASE) && (real_always_valid == 0)) begin
                `uvm_fatal("RAVCFG", $sformatf("case%0d requires REAL_ALWAYS_VALID=1", case_id))
            end

            if (local_id < 8) begin
                drive_direct_burst(case_id, 1'b0, 1 + local_id, (local_id % 3) + 1);
            end else if (local_id < 16) begin
                drive_direct_burst(case_id, 1'b1, 1 + (local_id - 8), ((local_id - 8) % 3) + 1);
            end else if (local_id < 24) begin
                drive_mixed_burst(case_id,
                                  fifo_depth + 4 + (local_id - 16),
                                  ((local_id - 16) % 4),
                                  (case_id >= MLSM_FIRST_VALIDLESS_CASE) && (((local_id - 16) % 4) <= 1));
            end else begin
                drive_switching_case(case_id);
            end
        endtask

        task automatic print_pass_banner(string test_name);
            if (uvm_report_enabled(UVM_LOW, UVM_INFO, "PASS")) begin
                `uvm_info("PASS", $sformatf("*** TEST PASSED *** %s", test_name), UVM_LOW)
            end
        endtask
    endclass

    class mlsm_directed_test extends mlsm_base_test;
        `uvm_component_utils(mlsm_directed_test)

        function new(string name = "mlsm_directed_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            int unsigned case_id;
            phase.raise_objection(this);
            case_id = 0;
            void'($value$plusargs("MLSM_CASE_ID=%d", case_id));
            run_case_body(case_id, 1'b1);
            print_pass_banner($sformatf("directed case%0d", case_id));
            phase.drop_objection(this);
        endtask
    endclass

    class mlsm_bucket_frame_test extends mlsm_base_test;
        `uvm_component_utils(mlsm_bucket_frame_test)

        function new(string name = "mlsm_bucket_frame_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            int unsigned first_case;
            int unsigned last_case;
            phase.raise_objection(this);
            first_case = (real_always_valid == 0) ? 0 : MLSM_FIRST_VALIDLESS_CASE;
            last_case  = first_case + MLSM_FIRST_VALIDLESS_CASE - 1;
            reset_dut();
            for (int unsigned case_id = first_case; case_id <= last_case; case_id++) begin
                run_case_body(case_id, 1'b0);
            end
            print_pass_banner($sformatf("bucket frame rav%0d", real_always_valid));
            phase.drop_objection(this);
        endtask
    endclass

    class mlsm_soak_test extends mlsm_base_test;
        `uvm_component_utils(mlsm_soak_test)

        function new(string name = "mlsm_soak_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            int unsigned soak_id;
            int unsigned soak_iters;
            int unsigned first_case;
            int unsigned selected_case;
            phase.raise_objection(this);
            soak_id    = 0;
            soak_iters = 4096;
            void'($value$plusargs("MLSM_SOAK_ID=%d", soak_id));
            void'($value$plusargs("MLSM_SOAK_ITERS=%d", soak_iters));
            first_case = (real_always_valid == 0) ? 0 : MLSM_FIRST_VALIDLESS_CASE;

            reset_dut();
            void'($urandom(32'h51A00000 ^ soak_id));
            for (int unsigned iter = 0; iter < soak_iters; iter++) begin
                selected_case = first_case + $urandom_range(0, MLSM_FIRST_VALIDLESS_CASE - 1);
                run_case_body(selected_case, 1'b0);
            end
            print_pass_banner($sformatf("soak%0d rav%0d iters%0d", soak_id, real_always_valid, soak_iters));
            phase.drop_objection(this);
        endtask
    endclass
endpackage
