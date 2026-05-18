#

all : main
	./main

main : main.cpp cxxrtl/model.cpp
	clang++ $(shell yosys-config --cxxflags) $< -o $@

cxxrtl/model.cpp : ../template.vhd
	ghdl analyse $<
	yosys -m ghdl -p "ghdl $(basename $(notdir $<)); write_cxxrtl $@"

clean :
	rm -vf *.o *.cf
