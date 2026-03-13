`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals for Neural Network test
localparam string NN_INPUT_NAME     = "neural_net/x_test.txt";
localparam string NN_EXPECTED_NAME  = "neural_net/y_test.txt";
localparam string NN_OUTPUT_NAME    = "nn_output.txt";

// Neural Network parameters
localparam int NN_INPUT_SIZE = 784;
localparam int NN_OUTPUT_SIZE = 1;  // Argmax outputs single class index
localparam int DATA_WIDTH = 32;
localparam int FIFO_DEPTH = 16;
localparam int CLOCK_FREQ_MHZ = 100;
localparam int CLOCK_PERIOD = 10;

`endif
