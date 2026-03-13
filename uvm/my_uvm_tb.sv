
import uvm_pkg::*;
import my_uvm_package::*;
import weights_pkg::*;

`include "my_uvm_if.sv"

`timescale 1 ns / 1 ns

module my_uvm_tb;

    my_uvm_if vif();

    // NN DUT
    top_nn #(
        .DATA_WIDTH(32),
        .QUANT_BITS(14),
        .NUM_LAYERS(2),
        .FIFO_BUFFER_SIZE(16),
        .INPUT_SIZE(784),
        .LAYER_SIZE(10),
        .N_CLASSES(10),
        .L1_WEIGHTS(PKG_L1_WEIGHTS),
        .L1_BIASES(PKG_L1_BIASES),
        .HIDDEN_WEIGHTS('{PKG_HIDDEN_WEIGHTS}),
        .HIDDEN_BIASES('{PKG_HIDDEN_BIASES})
    ) top_nn_inst (
        .clock(vif.clock),
        .reset(vif.reset),
        .in_din(vif.in_din),
        .in_wr_en(vif.in_wr_en),
        .in_full(vif.in_full),
        .out_dout(vif.out_dout),
        .out_done(vif.out_done)
    );

    // Probe internal pipeline valid strobes for coverage/performance tracking.
    assign vif.l0_out_valid = top_nn_inst.hidden_wr_en;
    assign vif.l1_out_valid = top_nn_inst.final_wr_en;
    assign vif.result_valid = top_nn_inst.result_wr_en;

    initial begin
        // store the vif so it can be retrieved by the driver & monitors
        uvm_resource_db#(virtual my_uvm_if)::set
            (.scope("ifs"), .name("vif"), .val(vif));

        // run the test
        run_test("my_uvm_test");
    end

    // reset
    initial begin
        vif.clock <= 1'b1;
        vif.reset <= 1'b0;
        @(posedge vif.clock);
        vif.reset <= 1'b1;
        @(posedge vif.clock);
        vif.reset <= 1'b0;
    end

    // 10ns clock
    always
        #(CLOCK_PERIOD/2) vif.clock = ~vif.clock;
endmodule
