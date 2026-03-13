import uvm_pkg::*;

class my_uvm_cov_subscriber extends uvm_subscriber #(my_uvm_transaction);
  `uvm_component_utils(my_uvm_cov_subscriber)

  virtual my_uvm_if vif;
  logic [31:0] class_val;
  logic        l0_valid_s;
  logic        l1_valid_s;
  logic        result_valid_s;

  covergroup cg_class;
    option.per_instance = 1;

    // Argmax class coverage
    cp_class : coverpoint class_val {
      bins cls0 = {0};
      bins cls1 = {1};
      bins cls2 = {2};
      bins cls3 = {3};
      bins cls4 = {4};
      bins cls5 = {5};
      bins cls6 = {6};
      bins cls7 = {7};
      bins cls8 = {8};
      bins cls9 = {9};
      bins out_of_range = default;
    }

  endgroup

  covergroup cg_layers;
    option.per_instance = 1;

    // Layer activity coverage (sampled continuously each cycle)
    cp_l0_valid : coverpoint l0_valid_s {
      bins idle = {0};
      bins fire = {1};
    }

    cp_l1_valid : coverpoint l1_valid_s {
      bins idle = {0};
      bins fire = {1};
    }

    cp_result_valid : coverpoint result_valid_s {
      bins idle = {0};
      bins fire = {1};
    }

    cx_pipeline_activity : cross cp_l0_valid, cp_l1_valid, cp_result_valid;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_class = new();
    cg_layers = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_resource_db#(virtual my_uvm_if)::read_by_name
        (.scope("ifs"), .name("vif"), .val(vif)));
    if (vif == null) begin
      `uvm_fatal("COV_BUILD", "Virtual interface not found")
    end
  endfunction

  virtual function void write(my_uvm_transaction t);
    class_val = t.data_value;
    cg_class.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.clock);
      if (!vif.reset) begin
        l0_valid_s = vif.l0_out_valid;
        l1_valid_s = vif.l1_out_valid;
        result_valid_s = vif.result_valid;
        cg_layers.sample();
      end
    end
  endtask

endclass