// tb_int_dual_env.sv
// Dual nominal/debug UVM environment for SWB rdma_pretest-260511.

package tb_int_swb_dual_env_pkg;

    import uvm_pkg::*;
    import tb_int_runctl_phy_agent_pkg::*;
    import tb_int_sc_phy_agent_pkg::*;
    import tb_int_rdma_rqe_ingress_monitor_pkg::*;
    import tb_int_rdma_cqe_egress_monitor_pkg::*;
    import tb_int_opq_lane_fill_monitor_pkg::*;
    import tb_int_pcie_dma_egress_monitor_pkg::*;
    import tb_int_host_memory_model_pkg::*;
    import tb_int_host_polling_core_pkg::*;
    import tb_int_swb_scoreboard_pkg::*;
    `include "uvm_macros.svh"

    class tb_int_swb_nominal_env extends uvm_env;
        `uvm_component_utils(tb_int_swb_nominal_env)

        runctl_phy_agent          runctl_phy;
        sc_phy_agent              sc_phy;
        rdma_rqe_ingress_monitor  rdma_rqe_mon;
        opq_lane_fill_monitor     opq_lane_mon[4];
        pcie_dma_egress_monitor   pcie_dma_mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            runctl_phy = runctl_phy_agent::type_id::create("runctl_phy", this);
            sc_phy = sc_phy_agent::type_id::create("sc_phy", this);
            rdma_rqe_mon = rdma_rqe_ingress_monitor::type_id::create("rdma_rqe_mon", this);
            foreach (opq_lane_mon[i]) begin
                opq_lane_mon[i] = opq_lane_fill_monitor::type_id::create($sformatf("opq_lane_mon%0d", i), this);
                uvm_config_db#(int unsigned)::set(this, $sformatf("opq_lane_mon%0d", i), "lane_id", i);
            end
            pcie_dma_mon = pcie_dma_egress_monitor::type_id::create("pcie_dma_mon", this);
        endfunction
    endclass

    class tb_int_swb_debug_env extends uvm_env;
        `uvm_component_utils(tb_int_swb_debug_env)

        rdma_cqe_egress_monitor rdma_cqe_mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            rdma_cqe_mon = rdma_cqe_egress_monitor::type_id::create("rdma_cqe_mon", this);
        endfunction
    endclass

    class tb_int_swb_dual_env extends uvm_env;
        `uvm_component_utils(tb_int_swb_dual_env)

        tb_int_swb_nominal_env       nominal;
        tb_int_swb_debug_env         debug;
        host_memory_model            host_mem;
        host_polling_core            host_core;
        tb_int_swb_ledger_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            nominal = tb_int_swb_nominal_env::type_id::create("nominal", this);
            debug = tb_int_swb_debug_env::type_id::create("debug", this);
            host_mem = host_memory_model::type_id::create("host_mem", this);
            host_core = host_polling_core::type_id::create("host_core", this);
            scoreboard = tb_int_swb_ledger_scoreboard::type_id::create("scoreboard", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            nominal.rdma_rqe_mon.ap.connect(scoreboard.stage_imp);
            foreach (nominal.opq_lane_mon[i])
                nominal.opq_lane_mon[i].ap.connect(scoreboard.stage_imp);
            nominal.pcie_dma_mon.ap.connect(scoreboard.stage_imp);
            debug.rdma_cqe_mon.ap.connect(scoreboard.stage_imp);
            host_mem.stage_ap.connect(scoreboard.stage_imp);
            host_core.set_host_model(host_mem);
        endfunction
    endclass

endpackage
