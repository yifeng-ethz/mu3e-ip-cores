// frontend_ticket_bus_pkg.sv
// Packed front-end ticket bus type for detector back-end dispatch
// Author: Yifeng Wang
// Version : 26.2.0
// Date    : 20260502
// Change  : Add the shared per-lane ticket payload contract.

package frontend_ticket_bus_pkg;

    parameter int unsigned TS_WIDTH = 15;

    typedef struct packed {
        logic [4:0]          ch_low;
        logic [4:0]          ch_high;
        logic [TS_WIDTH-1:0] ts_a;
        logic [TS_WIDTH-1:0] ts_b;
    } frontend_ticket_t;

endpackage
