module neuron #(
    parameter int                                  DATA_WIDTH = 32,
    parameter int                                  N_INPUTS = 1,
    parameter int                                  QUANT_BITS = 14,
    parameter logic [0:N_INPUTS-1][DATA_WIDTH-1:0] WEIGHTS = '{N_INPUTS{'b0}},
    parameter logic [DATA_WIDTH-1:0]               BIAS = 'h0
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic [DATA_WIDTH-1:0] x,
    input  logic                  valid_in,
    output logic [DATA_WIDTH-1:0] y,
    output logic                  valid_out 
);

function logic [DATA_WIDTH-1:0] DEQUANTIZE(logic [DATA_WIDTH-1:0] v);
    return (($signed(v) + $signed(1 << (QUANT_BITS-1))) / $signed(1 << QUANT_BITS));
endfunction

localparam COUNT_WIDTH = $clog2(N_INPUTS);

typedef enum logic [1:0] {s0, s1, s2, s3} state_t;
state_t state, state_c;

// internal signals
logic signed [DATA_WIDTH-1:0] acc, acc_c;
logic [COUNT_WIDTH-1:0] count, count_c;
logic [DATA_WIDTH-1:0] y_c;
logic valid_out_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        state     <= s0;
        acc       <= '0;
        count     <= '0;
        y         <= '0;
        valid_out <= 1'b0;
    end else begin
        // updates
        state     <= state_c;
        acc       <= acc_c;
        count     <= count_c;
        y         <= y_c;
        valid_out <= valid_out_c;
    end
end

always_comb begin
    // defaults
    state_c     = state;
    acc_c       = acc;
    count_c     = count;
    y_c         = y;
    valid_out_c = 1'b0;

    case (state)
        // Idle state
        // init accum with bias and process first input when valid
        s0: begin
            acc_c = $signed(BIAS); // initial offset default
            count_c = '0;
            if (valid_in) begin
                acc_c = $signed(BIAS) + $signed(DEQUANTIZE($signed(x) * $signed(WEIGHTS[0]))); // first MAC
                count_c = 1;
                if (N_INPUTS == 1)
                    state_c = s2;
                else
                    state_c = s1;
            end
        end

        // MAC stage
        // accum x*weight for all inputs
        s1: begin
            if (valid_in) begin
                acc_c = $signed(acc) + $signed(DEQUANTIZE($signed(x) * $signed(WEIGHTS[count])));
                if (count == COUNT_WIDTH'(N_INPUTS - 1))
                    state_c = s2;
                else
                    count_c = count + 1;
            end
        end

        // Dequantize final output by right shifting by QUANT_BITS
        s2: begin
            acc_c = $signed(acc) >>> QUANT_BITS;
            state_c = s3;
        end

        // ReLu Activation
        s3: begin
            y_c = ($signed(acc) > 0) ? acc : '0;
            valid_out_c = 1'b1;
            state_c = s0;
        end
    endcase
end

endmodule // neuron.sv