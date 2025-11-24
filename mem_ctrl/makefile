.PHONY: build run RUN clean
VERILOG=$(wildcard *.sv)
CSOURCE=$(wildcard *.cpp)

build:
	clear
	verilator --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module mem_ctrl -Mdir obj_dir
	$(MAKE) -C obj_dir -f Vmem_ctrl.mk Vmem_ctrl

run: build
	./obj_dir/Vmem_ctrl

RUN: run

see:
	gtkwave waveform.vcd


clean:
	rm -rf obj_dir waveform.vcd