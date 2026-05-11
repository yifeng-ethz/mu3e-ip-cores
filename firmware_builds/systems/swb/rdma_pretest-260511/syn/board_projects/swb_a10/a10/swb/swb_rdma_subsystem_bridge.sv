// File name: swb_rdma_subsystem_bridge.sv
// Purpose  : SWB-local wrapper that connects OPQ egress to rdma_subsystem_top.

`default_nettype none

module swb_rdma_subsystem_bridge (
    input  wire logic        clk,
    input  wire logic        reset_n,
    input  wire logic        enable,

    input  wire logic [31:0] opq_data,
    input  wire logic [3:0]  opq_datak,
    input  wire logic        opq_valid,
    input  wire logic        opq_sop,
    input  wire logic        opq_eop,

    input  wire logic [7:0]  csr_addr,
    input  wire logic [31:0] csr_wdata,
    input  wire logic        csr_write,
    output logic [31:0]      csr_rdata,
    output logic [31:0]      csr_uid,
    output logic [31:0]      csr_status,
    output logic [31:0]      cnt_rqe_consumed,
    output logic [31:0]      cnt_cqe_posted,
    output logic [31:0]      cnt_bytes_written,
    output logic [31:0]      cnt_opq_input_w,
    output logic [31:0]      cnt_halt,
    output logic [31:0]      cnt_eoe_observed,
    output logic [31:0]      host_stub_status,

    // AXI4-W -> legacy DMA-FIFO bridge outputs.
    // The rdma_subsystem emits 256-bit AXI4 writes through m_axi_w; each
    // accepted beat becomes one DMA word write (o_dma_data + o_dma_wren).
    // m_axi_wlast asserts o_endofevent on the same beat so the host PCIe
    // DMA0 engine closes the buffer at the end of every RDMA burst.
    output logic [255:0]     o_dma_data,
    output logic             o_dma_wren,
    output logic             o_endofevent
);

    localparam logic [7:0] CSR_UID_ADDR               = 8'h00;
    localparam logic [7:0] CSR_STATUS_ADDR            = 8'h0c;
    localparam logic [7:0] CSR_CNT_RQE_CONSUMED_ADDR  = 8'h34;
    localparam logic [7:0] CSR_CNT_CQE_POSTED_ADDR    = 8'h38;
    localparam logic [7:0] CSR_CNT_BYTES_WRITTEN_ADDR = 8'h3c;
    localparam logic [7:0] CSR_CNT_OPQ_INPUT_W_ADDR   = 8'h40;
    localparam logic [7:0] CSR_CNT_HALT_ADDR          = 8'h44;
    localparam logic [7:0] CSR_CNT_EOE_OBSERVED_ADDR  = 8'h48;

    typedef enum logic [2:0] {
        AXIL_RESET,
        AXIL_IDLE,
        AXIL_WRITE,
        AXIL_WRITE_RESP,
        AXIL_READ,
        AXIL_READ_RESP
    } axil_state_t;

    axil_state_t axil_state;

    logic [7:0]  pending_write_addr;
    logic [31:0] pending_write_data;
    logic        pending_write_valid;
    logic [3:0]  scan_index;
    logic [3:0]  read_index_latched;
    logic [7:0]  read_addr_latched;

    logic [7:0]  s_axil_awaddr;
    logic        s_axil_awvalid;
    logic        s_axil_awready;
    logic [31:0] s_axil_wdata;
    logic [3:0]  s_axil_wstrb;
    logic        s_axil_wvalid;
    logic        s_axil_wready;
    logic [1:0]  s_axil_bresp;
    logic        s_axil_bvalid;
    logic        s_axil_bready;
    logic [7:0]  s_axil_araddr;
    logic        s_axil_arvalid;
    logic        s_axil_arready;
    logic [31:0] s_axil_rdata;
    logic [1:0]  s_axil_rresp;
    logic        s_axil_rvalid;
    logic        s_axil_rready;

    logic [3:0]   m_axi_awid;
    logic [63:0]  m_axi_awaddr;
    logic [7:0]   m_axi_awlen;
    logic [2:0]   m_axi_awsize;
    logic [1:0]   m_axi_awburst;
    logic         m_axi_awvalid;
    logic         m_axi_awready;
    logic [255:0] m_axi_wdata;
    logic [31:0]  m_axi_wstrb;
    logic         m_axi_wlast;
    logic         m_axi_wvalid;
    logic         m_axi_wready;
    logic [3:0]   m_axi_bid;
    logic [1:0]   m_axi_bresp;
    logic         m_axi_bvalid;
    logic         m_axi_bready;
    logic [3:0]   m_axi_arid;
    logic [63:0]  m_axi_araddr;
    logic [7:0]   m_axi_arlen;
    logic [2:0]   m_axi_arsize;
    logic [1:0]   m_axi_arburst;
    logic         m_axi_arvalid;
    logic         m_axi_arready;
    logic [3:0]   m_axi_rid;
    logic [255:0] m_axi_rdata;
    logic [1:0]   m_axi_rresp;
    logic         m_axi_rlast;
    logic         m_axi_rvalid;
    logic         m_axi_rready;

    logic         msix_req;
    logic [4:0]   msix_vector;
    logic         msix_ack;
    logic         rdma_opq_ready;

    logic         write_aw_seen;
    logic [3:0]   write_bid_latched;
    logic [7:0]   host_write_count;
    logic [7:0]   host_read_count;
    logic [7:0]   host_resp_error_count;
    logic         read_active;
    logic [7:0]   read_beats_left;
    logic [3:0]   read_id_latched;

    function automatic logic [7:0] scan_addr_for_index(
        input logic [3:0] index,
        input logic [7:0] selected_addr
    );
        case (index)
            4'd0: scan_addr_for_index = selected_addr;
            4'd1: scan_addr_for_index = CSR_UID_ADDR;
            4'd2: scan_addr_for_index = CSR_STATUS_ADDR;
            4'd3: scan_addr_for_index = CSR_CNT_RQE_CONSUMED_ADDR;
            4'd4: scan_addr_for_index = CSR_CNT_CQE_POSTED_ADDR;
            4'd5: scan_addr_for_index = CSR_CNT_BYTES_WRITTEN_ADDR;
            4'd6: scan_addr_for_index = CSR_CNT_OPQ_INPUT_W_ADDR;
            4'd7: scan_addr_for_index = CSR_CNT_HALT_ADDR;
            4'd8: scan_addr_for_index = CSR_CNT_EOE_OBSERVED_ADDR;
            default: scan_addr_for_index = CSR_UID_ADDR;
        endcase
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            axil_state          <= AXIL_RESET;
            pending_write_addr  <= 8'h00;
            pending_write_data  <= 32'h0000_0000;
            pending_write_valid <= 1'b0;
            scan_index          <= 4'd0;
            read_index_latched  <= 4'd0;
            read_addr_latched   <= 8'h00;
            s_axil_awaddr       <= 8'h00;
            s_axil_awvalid      <= 1'b0;
            s_axil_wdata        <= 32'h0000_0000;
            s_axil_wstrb        <= 4'h0;
            s_axil_wvalid       <= 1'b0;
            s_axil_bready       <= 1'b0;
            s_axil_araddr       <= 8'h00;
            s_axil_arvalid      <= 1'b0;
            s_axil_rready       <= 1'b0;
            csr_rdata           <= 32'h0000_0000;
            csr_uid             <= 32'h0000_0000;
            csr_status          <= 32'h0000_0000;
            cnt_rqe_consumed    <= 32'h0000_0000;
            cnt_cqe_posted      <= 32'h0000_0000;
            cnt_bytes_written   <= 32'h0000_0000;
            cnt_opq_input_w     <= 32'h0000_0000;
            cnt_halt            <= 32'h0000_0000;
            cnt_eoe_observed    <= 32'h0000_0000;
            host_resp_error_count <= 8'h00;
        end else begin
            if (csr_write) begin
                pending_write_addr  <= csr_addr;
                pending_write_data  <= csr_wdata;
                pending_write_valid <= 1'b1;
            end

            case (axil_state)
                AXIL_RESET: begin
                    s_axil_awvalid <= 1'b0;
                    s_axil_wvalid  <= 1'b0;
                    s_axil_bready  <= 1'b0;
                    s_axil_arvalid <= 1'b0;
                    s_axil_rready  <= 1'b0;
                    axil_state     <= AXIL_IDLE;
                end

                AXIL_IDLE: begin
                    s_axil_bready <= 1'b0;
                    s_axil_rready <= 1'b0;
                    if (pending_write_valid) begin
                        s_axil_awaddr       <= pending_write_addr;
                        s_axil_wdata        <= pending_write_data;
                        s_axil_wstrb        <= 4'hf;
                        s_axil_awvalid      <= 1'b1;
                        s_axil_wvalid       <= 1'b1;
                        pending_write_valid <= 1'b0;
                        axil_state          <= AXIL_WRITE;
                    end else begin
                        read_index_latched <= scan_index;
                        read_addr_latched  <= scan_addr_for_index(scan_index, csr_addr);
                        s_axil_araddr      <= scan_addr_for_index(scan_index, csr_addr);
                        s_axil_arvalid     <= 1'b1;
                        axil_state         <= AXIL_READ;
                    end
                end

                AXIL_WRITE: begin
                    if (s_axil_awvalid && s_axil_awready) begin
                        s_axil_awvalid <= 1'b0;
                    end
                    if (s_axil_wvalid && s_axil_wready) begin
                        s_axil_wvalid <= 1'b0;
                    end
                    if ((!s_axil_awvalid || s_axil_awready) &&
                        (!s_axil_wvalid || s_axil_wready)) begin
                        s_axil_bready <= 1'b1;
                        axil_state    <= AXIL_WRITE_RESP;
                    end
                end

                AXIL_WRITE_RESP: begin
                    if (s_axil_bvalid && s_axil_bready) begin
                        if (s_axil_bresp != 2'b00) begin
                            host_resp_error_count <= host_resp_error_count + 8'd1;
                        end
                        s_axil_bready <= 1'b0;
                        axil_state    <= AXIL_IDLE;
                    end
                end

                AXIL_READ: begin
                    if (s_axil_arvalid && s_axil_arready) begin
                        s_axil_arvalid <= 1'b0;
                        s_axil_rready  <= 1'b1;
                        axil_state     <= AXIL_READ_RESP;
                    end
                end

                AXIL_READ_RESP: begin
                    if (s_axil_rvalid && s_axil_rready) begin
                        if (s_axil_rresp != 2'b00) begin
                            host_resp_error_count <= host_resp_error_count + 8'd1;
                        end
                        if (read_index_latched == 4'd0) begin
                            csr_rdata <= s_axil_rdata;
                        end
                        case (read_addr_latched)
                            CSR_UID_ADDR:               csr_uid           <= s_axil_rdata;
                            CSR_STATUS_ADDR:            csr_status        <= s_axil_rdata;
                            CSR_CNT_RQE_CONSUMED_ADDR:  cnt_rqe_consumed  <= s_axil_rdata;
                            CSR_CNT_CQE_POSTED_ADDR:    cnt_cqe_posted    <= s_axil_rdata;
                            CSR_CNT_BYTES_WRITTEN_ADDR: cnt_bytes_written <= s_axil_rdata;
                            CSR_CNT_OPQ_INPUT_W_ADDR:   cnt_opq_input_w   <= s_axil_rdata;
                            CSR_CNT_HALT_ADDR:          cnt_halt          <= s_axil_rdata;
                            CSR_CNT_EOE_OBSERVED_ADDR:  cnt_eoe_observed  <= s_axil_rdata;
                            default: begin
                            end
                        endcase
                        scan_index    <= (scan_index == 4'd8) ? 4'd0 : scan_index + 4'd1;
                        s_axil_rready <= 1'b0;
                        axil_state    <= AXIL_IDLE;
                    end
                end

                default: begin
                    axil_state <= AXIL_RESET;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            m_axi_awready       <= 1'b0;
            m_axi_wready        <= 1'b0;
            m_axi_bid           <= 4'h0;
            m_axi_bresp         <= 2'b00;
            m_axi_bvalid        <= 1'b0;
            write_aw_seen       <= 1'b0;
            write_bid_latched   <= 4'h0;
            host_write_count    <= 8'h00;
            m_axi_arready       <= 1'b0;
            m_axi_rid           <= 4'h0;
            m_axi_rdata         <= 256'h0;
            m_axi_rresp         <= 2'b00;
            m_axi_rlast         <= 1'b0;
            m_axi_rvalid        <= 1'b0;
            read_active         <= 1'b0;
            read_beats_left     <= 8'h00;
            read_id_latched     <= 4'h0;
            host_read_count     <= 8'h00;
        end else begin
            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end

            m_axi_awready <= !m_axi_bvalid && !write_aw_seen;
            m_axi_wready  <= !m_axi_bvalid;

            if (m_axi_awready && m_axi_awvalid) begin
                write_aw_seen     <= 1'b1;
                write_bid_latched <= m_axi_awid;
                host_write_count  <= host_write_count + 8'd1;
            end

            if (m_axi_wready && m_axi_wvalid && m_axi_wlast) begin
                m_axi_bid     <= write_aw_seen ? write_bid_latched : m_axi_awid;
                m_axi_bresp   <= 2'b00;
                m_axi_bvalid  <= 1'b1;
                write_aw_seen <= 1'b0;
            end

            if (!read_active) begin
                m_axi_arready <= 1'b1;
                if (m_axi_arvalid) begin
                    read_active     <= 1'b1;
                    m_axi_arready   <= 1'b0;
                    read_id_latched <= m_axi_arid;
                    read_beats_left <= m_axi_arlen;
                    m_axi_rid       <= m_axi_arid;
                    m_axi_rdata     <= 256'h0;
                    m_axi_rresp     <= 2'b00;
                    m_axi_rlast     <= (m_axi_arlen == 8'h00);
                    m_axi_rvalid    <= 1'b1;
                    host_read_count <= host_read_count + 8'd1;
                end
            end else if (m_axi_rvalid && m_axi_rready) begin
                if (m_axi_rlast) begin
                    m_axi_rvalid    <= 1'b0;
                    m_axi_rlast     <= 1'b0;
                    read_active     <= 1'b0;
                    m_axi_arready   <= 1'b1;
                end else begin
                    read_beats_left <= read_beats_left - 8'd1;
                    m_axi_rid       <= read_id_latched;
                    m_axi_rdata     <= 256'h0;
                    m_axi_rresp     <= 2'b00;
                    m_axi_rlast     <= (read_beats_left == 8'd1);
                end
            end
        end
    end

    // AXI4-W -> legacy DMA-FIFO bridge.
    // The OKAY-responder above closes the AXI4 protocol (returns BRESP=OK on
    // every burst). In parallel we tap each accepted m_axi_w beat into the
    // legacy DMA writeback interface so that data lands in host DRAM via the
    // existing a10_block i_pcie0_dma0_* path (i_pcie0_dma0_wdata/we/eoe).
    // The 256-bit width of m_axi_wdata matches o_dma_data exactly; no
    // re-packing is required.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            o_dma_data   <= 256'h0;
            o_dma_wren   <= 1'b0;
            o_endofevent <= 1'b0;
        end else begin
            if (m_axi_wvalid && m_axi_wready) begin
                o_dma_data   <= m_axi_wdata;
                o_dma_wren   <= 1'b1;
                o_endofevent <= m_axi_wlast;
            end else begin
                o_dma_wren   <= 1'b0;
                o_endofevent <= 1'b0;
            end
        end
    end

    assign host_stub_status = {
        msix_req,
        rdma_opq_ready,
        m_axi_awvalid,
        m_axi_wvalid,
        m_axi_arvalid,
        read_active,
        write_aw_seen,
        pending_write_valid,
        host_resp_error_count,
        host_read_count,
        host_write_count
    };

    assign msix_ack = 1'b1;

    rdma_subsystem_top rdma_subsystem_i (
        .clk               (clk),
        .reset_n           (reset_n),
        .s_axis_opq_tdata  ({opq_datak, opq_data}),
        .s_axis_opq_tvalid (enable && opq_valid),
        .s_axis_opq_tready (rdma_opq_ready),
        .s_axis_opq_tlast  (opq_eop),
        .s_axis_opq_tuser  ({1'b0, opq_sop}),
        .s_axil_awaddr     (s_axil_awaddr),
        .s_axil_awvalid    (s_axil_awvalid),
        .s_axil_awready    (s_axil_awready),
        .s_axil_wdata      (s_axil_wdata),
        .s_axil_wstrb      (s_axil_wstrb),
        .s_axil_wvalid     (s_axil_wvalid),
        .s_axil_wready     (s_axil_wready),
        .s_axil_bresp      (s_axil_bresp),
        .s_axil_bvalid     (s_axil_bvalid),
        .s_axil_bready     (s_axil_bready),
        .s_axil_araddr     (s_axil_araddr),
        .s_axil_arvalid    (s_axil_arvalid),
        .s_axil_arready    (s_axil_arready),
        .s_axil_rdata      (s_axil_rdata),
        .s_axil_rresp      (s_axil_rresp),
        .s_axil_rvalid     (s_axil_rvalid),
        .s_axil_rready     (s_axil_rready),
        .m_axi_awid        (m_axi_awid),
        .m_axi_awaddr      (m_axi_awaddr),
        .m_axi_awlen       (m_axi_awlen),
        .m_axi_awsize      (m_axi_awsize),
        .m_axi_awburst     (m_axi_awburst),
        .m_axi_awvalid     (m_axi_awvalid),
        .m_axi_awready     (m_axi_awready),
        .m_axi_wdata       (m_axi_wdata),
        .m_axi_wstrb       (m_axi_wstrb),
        .m_axi_wlast       (m_axi_wlast),
        .m_axi_wvalid      (m_axi_wvalid),
        .m_axi_wready      (m_axi_wready),
        .m_axi_bid         (m_axi_bid),
        .m_axi_bresp       (m_axi_bresp),
        .m_axi_bvalid      (m_axi_bvalid),
        .m_axi_bready      (m_axi_bready),
        .m_axi_arid        (m_axi_arid),
        .m_axi_araddr      (m_axi_araddr),
        .m_axi_arlen       (m_axi_arlen),
        .m_axi_arsize      (m_axi_arsize),
        .m_axi_arburst     (m_axi_arburst),
        .m_axi_arvalid     (m_axi_arvalid),
        .m_axi_arready     (m_axi_arready),
        .m_axi_rid         (m_axi_rid),
        .m_axi_rdata       (m_axi_rdata),
        .m_axi_rresp       (m_axi_rresp),
        .m_axi_rlast       (m_axi_rlast),
        .m_axi_rvalid      (m_axi_rvalid),
        .m_axi_rready      (m_axi_rready),
        .msix_req          (msix_req),
        .msix_vector       (msix_vector),
        .msix_ack          (msix_ack)
    );

endmodule

`default_nettype wire
