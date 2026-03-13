module argmax #(
    parameter int DATA_WIDTH = 32,
    parameter int N_CLASSES = 10
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic [DATA_WIDTH-1:0] x_dout,
    input  logic                  x_empty,
    output logic                  x_rd_en,
    output logic [DATA_WIDTH-1:0] out_dout,
    output logic                  y_wr_en
);

localparam int ARGMAX_COUNT_WIDTH = $clog2(N_CLASSES + 1);
localparam int ARGMAX_INDEX_WIDTH = (N_CLASSES > 1) ? $clog2(N_CLASSES) : 1;

typedef enum logic [1:0] {IDLE, COLLECT, HOLD_OUTPUT} state_t;
state_t state, state_c;

logic [ARGMAX_COUNT_WIDTH-1:0] class_count, class_count_c;
logic [ARGMAX_INDEX_WIDTH-1:0] best_class, best_class_c;
logic signed [DATA_WIDTH-1:0] best_value, best_value_c;

logic [DATA_WIDTH-1:0] out_dout_c;
logic x_rd_en_c;
logic y_wr_en_c;

assign x_rd_en = x_rd_en_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        class_count <= '0;
        best_class <= '0;
        best_value <= '0;
        out_dout <= '0;
        y_wr_en <= 1'b0;
    end else begin
        state <= state_c;
        class_count <= class_count_c;
        best_class <= best_class_c;
        best_value <= best_value_c;
        out_dout <= out_dout_c;
        y_wr_en <= y_wr_en_c;
    end
end

always_comb begin
    state_c = state;
    class_count_c = class_count;
    best_class_c = best_class;
    best_value_c = best_value;

    out_dout_c = out_dout;
    x_rd_en_c = 1'b0;
    y_wr_en_c = 1'b0;

    case (state)
        IDLE: begin
            class_count_c = '0;
            best_class_c = '0;
            best_value_c = '0;

            // Start collecting a fresh vector when FIFO has data.
            if (x_empty == 1'b0) begin
                x_rd_en_c = 1'b1;
                best_value_c = $signed(x_dout);
                class_count_c = ARGMAX_COUNT_WIDTH'(1);

                if (N_CLASSES == 1) begin
                    out_dout_c = '0;
                    out_dout_c[ARGMAX_INDEX_WIDTH-1:0] = '0;
                    y_wr_en_c = 1'b1;
                    state_c = HOLD_OUTPUT;
                end else begin
                    state_c = COLLECT;
                end
            end
        end

        COLLECT: begin
            if (x_empty == 1'b0) begin
                x_rd_en_c = 1'b1;

                if ($signed(x_dout) > best_value) begin
                    best_value_c = $signed(x_dout);
                    best_class_c = ARGMAX_INDEX_WIDTH'(class_count);
                end

                if (class_count == ARGMAX_COUNT_WIDTH'(N_CLASSES - 1)) begin
                    out_dout_c = '0;
                    out_dout_c[ARGMAX_INDEX_WIDTH-1:0] = best_class_c;
                    y_wr_en_c = 1'b1;
                    state_c = HOLD_OUTPUT;
                end else begin
                    class_count_c = class_count + ARGMAX_COUNT_WIDTH'(1);
                end
            end
        end

        HOLD_OUTPUT: begin
            state_c = IDLE;
        end

        default: state_c = IDLE;
    endcase
end

endmodule
