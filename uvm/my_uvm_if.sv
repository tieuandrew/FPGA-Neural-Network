import uvm_pkg::*;

// Virtual interface matching top_nn ports
interface my_uvm_if;
    logic        clock;
    logic        reset;

    // In FIFO write interface
    logic [31:0] in_din;
    logic        in_wr_en;
    logic        in_full;

    // Output from argmax (direct, no handshake)
    logic [31:0] out_dout;
    logic        out_done;

    // internal pipeline
    logic        l0_out_valid;
    logic        l1_out_valid;
    logic        result_valid;
endinterface
