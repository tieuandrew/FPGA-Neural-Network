import uvm_pkg::*;

`uvm_analysis_imp_decl(_output)
`uvm_analysis_imp_decl(_compare)

class my_uvm_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(my_uvm_scoreboard)

    uvm_analysis_export #(my_uvm_transaction) sb_export_output;
    uvm_analysis_export #(my_uvm_transaction) sb_export_compare;

    uvm_tlm_analysis_fifo #(my_uvm_transaction) output_fifo;
    uvm_tlm_analysis_fifo #(my_uvm_transaction) compare_fifo;

    my_uvm_transaction tx_out;
    my_uvm_transaction tx_cmp;
    virtual my_uvm_if vif;

    longint unsigned cycle_count;
    longint unsigned input_start_cycle;
    longint unsigned output_cycle;
    int input_accept_count;
    bit inference_started;
    bit inference_done;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_out    = new("tx_out");
        tx_cmp = new("tx_cmp");
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sb_export_output    = new("sb_export_output", this);
        sb_export_compare   = new("sb_export_compare", this);

        output_fifo        = new("output_fifo", this);
        compare_fifo    = new("compare_fifo", this);

        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
        if (vif == null) begin
            `uvm_fatal("SB_BUILD", "Virtual interface not found")
        end

        cycle_count = 0;
        input_start_cycle = 0;
        output_cycle = 0;
        input_accept_count = 0;
        inference_started = 0;
        inference_done = 0;
    endfunction: build_phase

    virtual function void connect_phase(uvm_phase phase);
        sb_export_output.connect(output_fifo.analysis_export);
        sb_export_compare.connect(compare_fifo.analysis_export);
    endfunction: connect_phase

    virtual task run_phase(uvm_phase phase);
        forever begin
            @(negedge vif.clock);
            cycle_count++;

            if (!inference_started && vif.in_wr_en && !vif.in_full) begin
                inference_started = 1;
                input_start_cycle = cycle_count;
            end

            if (vif.in_wr_en && !vif.in_full && input_accept_count < NN_INPUT_SIZE) begin
                input_accept_count++;
            end

            if (output_fifo.try_get(tx_out)) begin
                compare_fifo.get(tx_cmp);
                output_cycle = cycle_count;
                inference_done = 1;
                comparison();
            end
        end
    endtask: run_phase

    virtual function void comparison();
        if (tx_out.data_value !== tx_cmp.expected_class) begin
            `uvm_info("SB_CMP", tx_out.sprint(), UVM_LOW);
            `uvm_info("SB_CMP", tx_cmp.sprint(), UVM_LOW);
            `uvm_error("SB_CMP",
                $sformatf("NN Classification mismatch: expected class=%0d, got=%0d",
                          tx_cmp.expected_class, tx_out.data_value))
        end else begin
            `uvm_info("SB_CMP",
                $sformatf("NN Classification PASS: class=%0d", tx_out.data_value), UVM_MEDIUM)
        end
    endfunction: comparison

    virtual function void report_phase(uvm_phase phase);
        longint unsigned latency_cycles;
        real latency_ns;
        real throughput_inf_per_cycle;
        real throughput_inf_per_us;

        super.report_phase(phase);

        if (inference_started && inference_done && output_cycle >= input_start_cycle) begin
            latency_cycles = output_cycle - input_start_cycle + 1;
            latency_ns = real'(latency_cycles * CLOCK_PERIOD);
            throughput_inf_per_cycle = 1.0 / real'(latency_cycles);
            throughput_inf_per_us = 1000.0 / latency_ns;

            `uvm_info("SB_PERF",
                $sformatf("Inference latency = %0d cycles (%0.2f ns), accepted_inputs=%0d/%0d, throughput=%0.6f inf/cycle (%0.6f inf/us)",
                          latency_cycles, latency_ns, input_accept_count, NN_INPUT_SIZE,
                          throughput_inf_per_cycle, throughput_inf_per_us), UVM_LOW)
        end
    endfunction: report_phase
endclass: my_uvm_scoreboard
