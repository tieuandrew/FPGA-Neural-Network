setenv LMC_TIMEUNIT -9
setenv MTI_VCO_MODE 64

vlib work
vmap work work

# neural network architecture
vlog -work work "../sv/weights_pkg.sv"
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/neuron.sv"
vlog -work work "../sv/layer.sv"
vlog -work work "../sv/argmax.sv"
vlog -work work "../sv/top_nn.sv"

# uvm library
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# uvm package
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_pkg.sv"
vlog -work work +incdir+$env(UVM_HOME)/src "../uvm/my_uvm_tb.sv"

# start uvm simulation
vsim -coverage -classdebug -voptargs=+acc +notimingchecks -L work work.my_uvm_tb \
      -wlf my_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc \
      +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/ \
      +UVM_TESTNAME=my_uvm_test

coverage save -onexit coverage.ucdb

add wave -r /*

run -all

coverage report -details -output coverage_report.txt

#quit;

