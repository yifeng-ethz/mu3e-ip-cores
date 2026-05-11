// tb_int_base_test.sv
// Base UVM test for SWB rdma_pretest-260511 selected-case tb_int.

package tb_int_swb_base_test_pkg;

    import uvm_pkg::*;
    import tb_int_swb_dual_env_pkg::*;
    import tb_int_swb_case_sequences_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int unsigned {
        TB_INT_EXEC_ISOLATED,
        TB_INT_EXEC_BUCKET_FRAME,
        TB_INT_EXEC_ALL_BUCKETS_FRAME
    } tb_int_exec_mode_e;

    class tb_int_base_test extends uvm_test;
        `uvm_component_utils(tb_int_base_test)

        tb_int_swb_dual_env env;
        tb_int_exec_mode_e exec_mode;

        virtual rdma_rqe_ingress_if rdma_rqe_vif;
        virtual rdma_cqe_egress_if  rdma_cqe_vif;
        virtual opq_lane_if         opq_lane0_vif;
        virtual opq_lane_if         opq_lane1_vif;
        virtual opq_lane_if         opq_lane2_vif;
        virtual opq_lane_if         opq_lane3_vif;
        virtual pcie_dma_egress_if  pcie_dma_vif;

        function new(string name = "tb_int_base_test", uvm_component parent = null);
            super.new(name, parent);
            exec_mode = TB_INT_EXEC_ISOLATED;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            string mode_name;

            super.build_phase(phase);
            if ($value$plusargs("TB_INT_EXEC_MODE=%s", mode_name)) begin
                if (mode_name == "bucket_frame")
                    exec_mode = TB_INT_EXEC_BUCKET_FRAME;
                else if (mode_name == "all_buckets_frame")
                    exec_mode = TB_INT_EXEC_ALL_BUCKETS_FRAME;
                else
                    exec_mode = TB_INT_EXEC_ISOLATED;
            end
            env = tb_int_swb_dual_env::type_id::create("env", this);
            get_required_vifs();
        endfunction

        virtual function void get_required_vifs();
            if (!uvm_config_db#(virtual rdma_rqe_ingress_if)::get(this, "", "rdma_rqe_vif", rdma_rqe_vif))
                `uvm_fatal("SWB_BASE", "rdma_rqe_vif not configured")
            if (!uvm_config_db#(virtual rdma_cqe_egress_if)::get(this, "", "rdma_cqe_vif", rdma_cqe_vif))
                `uvm_fatal("SWB_BASE", "rdma_cqe_vif not configured")
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "opq_lane0_vif", opq_lane0_vif))
                `uvm_fatal("SWB_BASE", "opq_lane0_vif not configured")
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "opq_lane1_vif", opq_lane1_vif))
                `uvm_fatal("SWB_BASE", "opq_lane1_vif not configured")
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "opq_lane2_vif", opq_lane2_vif))
                `uvm_fatal("SWB_BASE", "opq_lane2_vif not configured")
            if (!uvm_config_db#(virtual opq_lane_if)::get(this, "", "opq_lane3_vif", opq_lane3_vif))
                `uvm_fatal("SWB_BASE", "opq_lane3_vif not configured")
            if (!uvm_config_db#(virtual pcie_dma_egress_if)::get(this, "", "pcie_dma_vif", pcie_dma_vif))
                `uvm_fatal("SWB_BASE", "pcie_dma_vif not configured")
        endfunction

        virtual task run_configured_sequence(string case_id, swb_case_sequence seq);
            wait (rdma_rqe_vif.reset_n === 1'b1);
            repeat (4) @(posedge rdma_rqe_vif.clk);
            env.scoreboard.start_case(case_id);
            if (seq == null)
                seq = swb_case_sequence::type_id::create($sformatf("%s_seq", case_id));
            seq.configure(rdma_rqe_vif,
                          rdma_cqe_vif,
                          opq_lane0_vif,
                          opq_lane1_vif,
                          opq_lane2_vif,
                          opq_lane3_vif,
                          pcie_dma_vif);
            seq.drive_case(case_id);
            repeat (4) @(posedge rdma_rqe_vif.clk);
            env.scoreboard.check_case(case_id);
        endtask

        virtual task run_selected_case(string case_id);
            swb_case_sequence seq;

            seq = null;
            run_configured_sequence(case_id, seq);
        endtask
    endclass

endpackage
