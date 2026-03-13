import uvm_pkg::*;

class my_uvm_driver extends uvm_driver#(my_uvm_transaction);

    `uvm_component_utils(my_uvm_driver)

    virtual my_uvm_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
            (.scope("ifs"), .name("vif"), .val(vif)));
    endfunction: build_phase

    virtual task run_phase(uvm_phase phase);
        drive();
    endtask: run_phase

    virtual task drive();
        my_uvm_transaction tx;

        // wait for reset
        @(posedge vif.reset);
        @(negedge vif.reset);

        vif.in_din    = '0;
        vif.in_wr_en  = 1'b0;

        forever begin
            @(negedge vif.clock);
            vif.in_wr_en = 1'b0;
            if (!vif.in_full) begin
                tx = null;
                seq_item_port.try_next_item(tx);
                if (tx != null) begin
                    vif.in_din   = tx.data_value;
                    vif.in_wr_en = 1'b1;
                    seq_item_port.item_done();
                end
            end
        end
    endtask: drive

endclass
