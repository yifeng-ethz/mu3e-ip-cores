class emu_st_driver extends uvm_driver #(hit_type0_seq_item);
  `uvm_component_utils(emu_st_driver)

  virtual arb_hit_type0_hit_if vif;

  function new(string name = "emu_st_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual arb_hit_type0_hit_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Missing emulator hit interface")
    end
  endfunction

  task run_phase(uvm_phase phase);
    hit_type0_seq_item req;

    reset_outputs();
    forever begin
      wait_for_reset_release();
      seq_item_port.get_next_item(req);
      if (req == null) begin
        `uvm_error(get_type_name(), "Received null hit_type0_seq_item")
        seq_item_port.item_done();
        continue;
      end
      drive_item(req);
      seq_item_port.item_done();
    end
  endtask

  task automatic wait_for_reset_release();
    while (vif.rst === 1'b1) begin
      reset_outputs();
      @(posedge vif.clk);
    end
  endtask

  task automatic reset_outputs();
    vif.valid      <= 1'b0;
    vif.data       <= '0;
    vif.error      <= '0;
    vif.channel    <= '0;
    vif.sop        <= 1'b0;
    vif.eop        <= 1'b0;
    vif.eor        <= 1'b0;
  endtask

  task automatic drive_item(hit_type0_seq_item item);
    repeat (item.idle_cycles) begin
      @(posedge vif.clk);
      reset_outputs();
    end

    @(posedge vif.clk);
    vif.valid      <= item.valid;
    vif.data       <= item.data;
    vif.error      <= item.error;
    vif.channel    <= item.channel;
    vif.sop        <= item.sop;
    vif.eop        <= item.eop;
    vif.eor        <= item.eor;

    @(posedge vif.clk);
    reset_outputs();
  endtask
endclass
