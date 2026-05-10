import uvm_pkg::*;
import arb_hit_type0_pkg::*;
`include "uvm_macros.svh"

module X999_cross_factory_anchor;
  initial begin
    void'(X001_bucket_frame_basic_test::type_id::get());
    void'(X002_bucket_frame_edge_test::type_id::get());
    void'(X003_bucket_frame_prof_test::type_id::get());
    void'(X004_bucket_frame_error_test::type_id::get());
    void'(X005_all_buckets_frame_test::type_id::get());
  end
endmodule

bind tb_top X999_cross_factory_anchor cross_factory_anchor();
