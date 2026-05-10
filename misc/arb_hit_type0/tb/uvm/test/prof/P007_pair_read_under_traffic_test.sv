class P007_pair_read_under_traffic_test extends prof_test_base;
  `uvm_component_utils(P007_pair_read_under_traffic_test)

  function new(string name = "P007_pair_read_under_traffic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    P007_pair_read_under_traffic_seq seq;

    seq = P007_pair_read_under_traffic_seq::type_id::create("seq");
    run_prof_sequence(seq, phase);
  endtask
endclass
