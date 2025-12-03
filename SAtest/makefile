.PHONY: build run RUN clean
VERILOG=$(wildcard vsrc/*.sv)
CSOURCE=$(wildcard *.cpp)

build:
# 	clear
	verilator --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module mul_top -Mdir obj_dir
	$(MAKE) -C obj_dir -f Vmul_top.mk Vmul_top

buildtest:
	verilator -CFLAGS "-DAS_TEST" --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module mul_top -Mdir obj_dir   
	$(MAKE) -C obj_dir -f Vmul_top.mk Vmul_top

run: build
	./obj_dir/Vmul_top
test: buildtest
	./obj_dir/Vmul_top
RUN: run

see:
	gtkwave waveform.vcd

diff:
	diff -u left_B.bin ../goldendata_left/debug/debugfile.bin

diff1:
	diff -u left_B.bin ../goldendata_left/debug/adderB.bin

clean:
	rm -rf obj_dir waveform.vcd