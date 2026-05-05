// histogram_csr_monitor.sv
// Passive histogram CSR polling shell for scoreboard cross-checks.
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260504
// Change  : Add reusable histogram CSR monitor scaffold.

package tb_int_histogram_csr_monitor_pkg;

    import uvm_pkg::*;
    import tb_int_record_pkg::*;
    `include "uvm_macros.svh"

    class histogram_csr_monitor extends uvm_component;
        `uvm_component_utils(histogram_csr_monitor)

        virtual sc_avmm_if vif;
        uvm_analysis_port#(hit_record) ap;
        int unsigned poll_interval_cycles;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            poll_interval_cycles = 1024;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            void'(uvm_config_db#(virtual sc_avmm_if)::get(this, "", "vif", vif));
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null) begin
                `uvm_info("HIST_CSR", "histogram CSR monitor disabled; sc_avmm_if not configured", UVM_LOW)
                return;
            end
            forever begin
                repeat (poll_interval_cycles) @(posedge vif.clk);
                if (vif.rst === 1'b1)
                    continue;
                `uvm_info("HIST_CSR", "poll slot reserved for histogram_statistics_0 bin cross-check", UVM_HIGH)
            end
        endtask
    endclass

endpackage
