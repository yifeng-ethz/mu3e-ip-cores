// debug_fill_monitor.sv
// Passive DEBUG_LEVEL=1 fill/status conduit monitor for v3 tb_int.

package tb_int_debug_fill_monitor_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class debug_fill_sample extends uvm_sequence_item;
        `uvm_object_utils(debug_fill_sample)

        string       ip_name;
        string       conduit_name;
        bit [63:0]   value;
        time         sample_time;

        function new(string name = "debug_fill_sample");
            super.new(name);
        endfunction

        function string describe();
            return $sformatf("{ip=%s conduit=%s value=0x%016h t=%0t}",
                             ip_name, conduit_name, value, sample_time);
        endfunction
    endclass

    class debug_fill_monitor extends uvm_component;
        `uvm_component_utils(debug_fill_monitor)

        virtual debug_fill_if vif;
        uvm_analysis_port#(debug_fill_sample) ap;
        string ip_name;
        string conduit_name;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ip_name = "";
            conduit_name = "";
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            ap = new("ap", this);
            void'(uvm_config_db#(string)::get(this, "", "ip_name", ip_name));
            void'(uvm_config_db#(string)::get(this, "", "conduit_name", conduit_name));
            if (!uvm_config_db#(virtual debug_fill_if)::get(this, "", "vif", vif))
                `uvm_info("DBG_FILL", "debug_fill_if not configured; monitor disabled", UVM_LOW)
        endfunction

        virtual task run_phase(uvm_phase phase);
            if (vif == null)
                return;
            forever begin
                @(posedge vif.clk);
                #1ps;
                if (vif.rst === 1'b1)
                    continue;
                if (vif.valid === 1'b1) begin
                    debug_fill_sample sample;

                    sample = debug_fill_sample::type_id::create("fill_sample");
                    sample.ip_name = ip_name;
                    sample.conduit_name = conduit_name;
                    sample.value = vif.data;
                    sample.sample_time = $time;
                    ap.write(sample);
                    `uvm_info("DBG_FILL", sample.describe(), UVM_HIGH)
                end
            end
        endtask
    endclass

endpackage
