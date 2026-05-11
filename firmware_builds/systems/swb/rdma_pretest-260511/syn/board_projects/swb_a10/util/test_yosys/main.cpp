//

#include "cxxrtl/model.cpp"

#include <cstdio>

int main() {
    cxxrtl_design::p_template top;

    top.step();

    for(int cycle = 0; cycle < 100; cycle++) {

        top.p_i__reset__n.set<bool>(1);
        top.p_i__clk.set<bool>(false);
        top.step();
        top.p_i__clk.set<bool>(true);
        top.step();

        top.p_i__data.set<uint8_t>(0x0F);
        uint8_t data = top.p_o__data.get<uint8_t>();
        printf("cycle = %d, data = 0x%02X\n", cycle, data);
    }
}
