import uvm_pkg::*;

// Reads NN output from output FIFO to scoreboard
class my_uvm_monitor_output extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_output)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_output;

    virtual my_uvm_if vif;
    int out_file;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_output = new(.name("mon_ap_output"), .parent(this));

        out_file = $fopen(NN_OUTPUT_NAME, "w");
        if ( !out_file ) begin
            `uvm_fatal("MON_OUT_BUILD", $sformatf("Failed to open output file %s...", NN_OUTPUT_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        my_uvm_transaction tx_out;

        // wait for reset
        @(posedge vif.reset);
        @(negedge vif.reset);

        forever begin
            @(negedge vif.clock);
            if (vif.out_done) begin
                tx_out = my_uvm_transaction::type_id::create(.name("tx_out"), .contxt(get_full_name()));

                // Write output class to file
                $fwrite(out_file, "%08x\n", vif.out_dout);

                tx_out.data_value = vif.out_dout;
                tx_out.expected_class = '0;
                mon_ap_output.write(tx_out);
            end
        end
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_OUT_FINAL", $sformatf("Closing file %s...", NN_OUTPUT_NAME), UVM_LOW);
        $fclose(out_file);
    endfunction: final_phase

endclass: my_uvm_monitor_output


// Reads expected NN output (class) from file to scoreboard
class my_uvm_monitor_compare extends uvm_monitor;
    `uvm_component_utils(my_uvm_monitor_compare)

    uvm_analysis_port#(my_uvm_transaction) mon_ap_compare;
    virtual my_uvm_if vif;
    int expected_file, n_bytes;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        mon_ap_compare = new(.name("mon_ap_compare"), .parent(this));

        expected_file = $fopen(NN_EXPECTED_NAME, "r");
        if ( !expected_file ) begin
            `uvm_fatal("MON_CMP_BUILD", $sformatf("Failed to open file %s...", NN_EXPECTED_NAME));
        end
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        int i=0;
        my_uvm_transaction tx_cmp;

        // notify that run_phase has started
        phase.raise_objection(.obj(this));

        // wait for reset
        @(posedge vif.reset);
        @(negedge vif.reset);

        tx_cmp = my_uvm_transaction::type_id::create(.name("tx_cmp"), .contxt(get_full_name()));

        // Wait for NN output (1 classification result)
        while (i < NN_OUTPUT_SIZE) begin
            @(negedge vif.clock);
            if (vif.out_done) begin
                n_bytes = $fscanf(expected_file, "%d", tx_cmp.expected_class);
                if (n_bytes != 1) begin
                    `uvm_fatal("MON_CMP_RUN", $sformatf("Failed to read expected class from %s", NN_EXPECTED_NAME));
                end
                tx_cmp.data_value = '0;
                mon_ap_compare.write(tx_cmp);
                i++;
            end
        end

        // notify that run_phase has completed
        phase.drop_objection(.obj(this));
    endtask: run_phase

    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info("MON_CMP_FINAL", $sformatf("Closing file %s...", NN_EXPECTED_NAME), UVM_LOW);
        $fclose(expected_file);
    endfunction: final_phase

endclass: my_uvm_monitor_compare
