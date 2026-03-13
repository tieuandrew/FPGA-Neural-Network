import uvm_pkg::*;

// Transaction carrying one neural network input/output value
class my_uvm_transaction extends uvm_sequence_item;
    logic [31:0] data_value;
    logic [31:0] expected_class;

    function new(string name = "");
        super.new(name);
    endfunction: new

    `uvm_object_utils_begin(my_uvm_transaction)
        `uvm_field_int(data_value, UVM_ALL_ON)
        `uvm_field_int(expected_class, UVM_ALL_ON)
    `uvm_object_utils_end
endclass: my_uvm_transaction


class my_uvm_sequence extends uvm_sequence#(my_uvm_transaction);
    `uvm_object_utils(my_uvm_sequence)

    function new(string name = "");
        super.new(name);
    endfunction: new

    // Read NN input file (hex) and send all input values
    task body();
        my_uvm_transaction tx;
        int input_file, r;

        `uvm_info("SEQ_RUN", $sformatf("Loading input file %s...", NN_INPUT_NAME), UVM_LOW);

        input_file = $fopen(NN_INPUT_NAME, "r");
        if (!input_file) begin
            `uvm_fatal("SEQ_RUN", $sformatf("Failed to open file %s...", NN_INPUT_NAME));
        end

        // Send all 784 input values
        for (int i = 0; i < NN_INPUT_SIZE; i++) begin
            tx = my_uvm_transaction::type_id::create(.name("tx"), .contxt(get_full_name()));
            start_item(tx);
            r = $fscanf(input_file, "%h", tx.data_value);
            if (r != 1) begin
                `uvm_fatal("SEQ_RUN", $sformatf("Failed to read input sample %0d from %s", i, NN_INPUT_NAME));
            end
            tx.expected_class = 0; // Not used in sequence
            finish_item(tx);
        end

        `uvm_info("SEQ_RUN", $sformatf("Sent %0d input values. Closing file %s...",
              NN_INPUT_SIZE, NN_INPUT_NAME), UVM_LOW);
        $fclose(input_file);
    endtask: body
endclass: my_uvm_sequence

typedef uvm_sequencer#(my_uvm_transaction) my_uvm_sequencer;
