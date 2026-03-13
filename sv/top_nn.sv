module top_nn #(
    parameter int DATA_WIDTH = 32,
    parameter int QUANT_BITS = 14,
    parameter int NUM_LAYERS = 2,
    parameter int FIFO_BUFFER_SIZE = 16,

    // Network shape params
    parameter int INPUT_SIZE = 784,
    parameter int LAYER_SIZE = 10,
    parameter int N_CLASSES = 10,

    // Parameters for weights and biases
    parameter logic [0:LAYER_SIZE-1][0:INPUT_SIZE-1][DATA_WIDTH-1:0] L1_WEIGHTS = '0,
    parameter logic [0:LAYER_SIZE-1][DATA_WIDTH-1:0] L1_BIASES = '0,
    parameter logic [0:NUM_LAYERS-2][0:N_CLASSES-1][0:LAYER_SIZE-1][DATA_WIDTH-1:0] HIDDEN_WEIGHTS = '0,
    parameter logic [0:NUM_LAYERS-2][0:N_CLASSES-1][DATA_WIDTH-1:0] HIDDEN_BIASES = '0
) (
    input logic clock,
    input logic reset,

    // Input interface
    input  logic [DATA_WIDTH-1:0] in_din,
    input  logic in_wr_en,
    output logic in_full,

    // Output interface (direct from argmax)
    output logic [DATA_WIDTH-1:0] out_dout,
    output logic                  out_done
);

logic input_rd_en, input_empty;
logic [DATA_WIDTH-1:0] input_dout;

logic hidden_rd_en, hidden_empty, hidden_full;
logic [DATA_WIDTH-1:0] hidden_dout;
logic [DATA_WIDTH-1:0] hidden_din;
logic hidden_wr_en;

logic [DATA_WIDTH-1:0] final_din;
logic final_wr_en;
logic final_full;

logic final_to_argmax_rd_en;
logic final_to_argmax_empty;
logic [DATA_WIDTH-1:0] final_to_argmax_dout;

logic result_wr_en;

fifo #(
    .FIFO_DATA_WIDTH(DATA_WIDTH),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) u_input_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(in_din),
    .full(in_full),
    .rd_clk(clock),
    .rd_en(input_rd_en),
    .dout(input_dout),
    .empty(input_empty)
);

layer #(
    .DATA_WIDTH(DATA_WIDTH),
    .QUANT_BITS(QUANT_BITS),
    .N_INPUTS(INPUT_SIZE),
    .N_NEURONS(LAYER_SIZE),
    .WEIGHTS(L1_WEIGHTS),
    .BIASES(L1_BIASES)
) u_layer0 (
    .clock(clock),
    .reset(reset),
    .x_dout(input_dout),
    .x_empty(input_empty),
    .x_rd_en(input_rd_en),
    .y_din(hidden_din),
    .y_full(hidden_full),
    .y_wr_en(hidden_wr_en)
);

fifo #(
    .FIFO_DATA_WIDTH(DATA_WIDTH),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) u_hidden_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(hidden_wr_en),
    .din(hidden_din),
    .full(hidden_full),
    .rd_clk(clock),
    .rd_en(hidden_rd_en),
    .dout(hidden_dout),
    .empty(hidden_empty)
);

layer #(
    .DATA_WIDTH(DATA_WIDTH),
    .QUANT_BITS(QUANT_BITS),
    .N_INPUTS(LAYER_SIZE),
    .N_NEURONS(N_CLASSES),
    .WEIGHTS(HIDDEN_WEIGHTS[0]),
    .BIASES(HIDDEN_BIASES[0])
) u_layer1 (
    .clock(clock),
    .reset(reset),
    .x_dout(hidden_dout),
    .x_empty(hidden_empty),
    .x_rd_en(hidden_rd_en),
    .y_din(final_din),
    .y_full(final_full),
    .y_wr_en(final_wr_en)
);

fifo #(
    .FIFO_DATA_WIDTH(DATA_WIDTH),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) u_final_fifo (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(final_wr_en),
    .din(final_din),
    .full(final_full),
    .rd_clk(clock),
    .rd_en(final_to_argmax_rd_en),
    .dout(final_to_argmax_dout),
    .empty(final_to_argmax_empty)
);

argmax #(
    .DATA_WIDTH(DATA_WIDTH),
    .N_CLASSES(N_CLASSES)
) u_argmax (
    .clock(clock),
    .reset(reset),
    .x_dout(final_to_argmax_dout),
    .x_empty(final_to_argmax_empty),
    .x_rd_en(final_to_argmax_rd_en),
    .out_dout(out_dout),
    .y_wr_en(result_wr_en)
);

assign out_done = result_wr_en;

endmodule