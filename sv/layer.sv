module layer #(
    parameter int                                                 DATA_WIDTH = 32,
    parameter int                                                 QUANT_BITS = 14,
    parameter int                                                 N_INPUTS = 1,
    parameter int                                                 N_NEURONS = 1,
    parameter logic [0:N_NEURONS-1][0:N_INPUTS-1][DATA_WIDTH-1:0] WEIGHTS = '{N_NEURONS{'{N_INPUTS{'b0}}}},
    parameter logic [0:N_NEURONS-1][DATA_WIDTH-1:0]               BIASES = '{N_NEURONS{'b0}}
) (
    input  logic clock,
    input  logic reset,
    input  logic [DATA_WIDTH-1:0] x_dout,
    input  logic x_empty,
    output logic x_rd_en,
    output logic [DATA_WIDTH-1:0] y_din,
    input  logic y_full,
    output logic y_wr_en   
);

typedef enum logic [1:0] {IDLE, STREAM_INPUTS, WAIT_OUTPUTS, WRITE_OUTPUTS} layer_state_t;
layer_state_t state, state_c;

// Neuron input signals
logic [DATA_WIDTH-1:0] neuron_input, neuron_input_c;
logic neuron_valid_in, neuron_valid_in_c;

// Neuron output signals from array of neurons
logic [0:N_NEURONS-1][DATA_WIDTH-1:0] neuron_y; // wires
logic [0:N_NEURONS-1] neuron_valid_out;

// temp out neuron_y storage
logic [0:N_NEURONS-1][DATA_WIDTH-1:0] output_buffer, output_buffer_c;
logic [0:N_NEURONS-1] output_valid, output_valid_c;

// input counter
localparam INPUT_COUNT_WIDTH = $clog2(N_INPUTS + 1);
logic [INPUT_COUNT_WIDTH-1:0] input_counter, input_counter_c;

// Output neuron selection
logic [$clog2(N_NEURONS)-1:0] output_idx, output_idx_c;

generate
    for (genvar i = 0; i < N_NEURONS; i++) begin : neuron_array
        neuron #(
            .DATA_WIDTH(DATA_WIDTH),
            .N_INPUTS(N_INPUTS),
            .QUANT_BITS(QUANT_BITS),
            .WEIGHTS(WEIGHTS[i]),
            .BIAS(BIASES[i])
        ) neuron_inst (
            .clock(clock),
            .reset(reset),
            .x(neuron_input), // same input to all neurons
            .valid_in(neuron_valid_in),
            .y(neuron_y[i]),
            .valid_out(neuron_valid_out[i])
        );
    end : neuron_array
endgenerate

always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        neuron_input <= '0;
        neuron_valid_in <= 1'b0;
        input_counter <= '0;
        output_buffer <= '{N_NEURONS{'b0}};
        output_valid <= '{N_NEURONS{'b0}};
        output_idx <= '0;
    end else begin
        state <= state_c;
        neuron_input <= neuron_input_c;
        neuron_valid_in <= neuron_valid_in_c;
        input_counter <= input_counter_c;
        output_buffer <= output_buffer_c;
        output_valid <= output_valid_c;
        output_idx <= output_idx_c;
    end
end

always_comb begin
    // Default assignments
    state_c = state;
    neuron_input_c = neuron_input;
    neuron_valid_in_c = 1'b0;
    input_counter_c = input_counter;
    output_buffer_c = output_buffer;
    output_valid_c = output_valid;
    output_idx_c = output_idx;
    x_rd_en = 1'b0;
    y_din = '0;
    y_wr_en = 1'b0;

    case (state)
        // Wait for input FIFO to have data
        // read in first value
        IDLE: begin
            input_counter_c = '0;
            if (~x_empty) begin
                x_rd_en = 1'b1;
                neuron_input_c = x_dout;
                neuron_valid_in_c = 1'b1;
                input_counter_c = 1;
                state_c = STREAM_INPUTS;
            end
        end

        // read N_INPUTS-1 from FIFO
        // Send to all neurons at the same time
        STREAM_INPUTS: begin
            if (input_counter == INPUT_COUNT_WIDTH'(N_INPUTS)) begin
                // all inputs have been streamed in
                state_c = WAIT_OUTPUTS;
            end else if (x_empty == 1'b0) begin
                x_rd_en = 1'b1;
                neuron_input_c = x_dout;
                neuron_valid_in_c = 1'b1;
                input_counter_c = input_counter + 1;
            end
        end

        // Collect outputs into buffer and wait until valid
        WAIT_OUTPUTS: begin
            // Check if all neurons have valid outputs
            if (&neuron_valid_out) begin
                output_buffer_c = neuron_y;
                output_valid_c = neuron_valid_out;
                output_idx_c = '0;
                state_c = WRITE_OUTPUTS;
            end
        end

        // Write neuron outputs to output FIFO one at a time
        WRITE_OUTPUTS: begin
            if (~y_full) begin
                y_din = output_buffer[output_idx];
                y_wr_en = 1'b1;
                
                if (output_idx == ($clog2(N_NEURONS))'(N_NEURONS - 1)) begin
                    // All neuron outputs have been written
                    state_c = IDLE;
                end else begin
                    output_idx_c = output_idx + 1;
                end
            end
        end

        default: state_c = IDLE;
    endcase
end

endmodule // layer.sv