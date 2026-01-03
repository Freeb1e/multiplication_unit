.PHONY: build run RUN clean
VERILOG = $(wildcard vsrc/*.sv)
VERILOG += $(wildcard vsrc/*.v)
CSOURCE=$(shell find csrc -name "*.cpp" -not -path "*/tools/capstone/repo/*")
CSOURCE+=$(shell find csrc -name "*.c" -not -path "*/tools/capstone/repo/*")
CSOURCE+=$(shell find csrc -name "*.cc" -not -path "*/tools/capstone/repo/*")

TOP_NAME ?= platform_top

build:
# 	clear
	verilator --trace -cc $(VERILOG) --exe $(CSOURCE) --top-module $(TOP_NAME) -Mdir obj_dir -Ivsrc
	$(MAKE) -C obj_dir -f V$(TOP_NAME).mk V$(TOP_NAME) 

run: build
	./obj_dir/V$(TOP_NAME)
test: buildtest
	./obj_dir/V$(TOP_NAME)
RUN: run

see:
	gtkwave waveform.vcd

clean:
	rm -rf obj_dir waveform.vcd

diff1:
	if diff ./testdata/output/Bout.bin ./testdata/output/BGOLDENAS.bin; then echo -e "\033[32mPASS\033[0m"; else echo -e "\033[31mFAIL\033[0m"; fi
diff2:
	if diff ./testdata/output/Bout.bin ./testdata/output/BGOLDENSA.bin; then echo -e "\033[32mPASS\033[0m"; else echo -e "\033[31mFAIL\033[0m"; fi
