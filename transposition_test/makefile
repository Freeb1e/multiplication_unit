.PHONY: build run RUN clean
VERILOG=$(wildcard *.sv)
CSOURCE=$(wildcard *.cpp)

build:
	clear
	verilator --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module transposition_top_default -Mdir obj_dir
	$(MAKE) -C obj_dir -f Vtransposition_top_default.mk Vtransposition_top_default

run: build
	./obj_dir/Vtransposition_top_default

RUN: run

see:
	gtkwave waveform.vcd


clean:
	rm -rf obj_dir waveform.vcd