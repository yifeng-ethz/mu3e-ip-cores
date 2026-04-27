#ifndef __UTIL_A10_SENSORS_H__
#define __UTIL_A10_SENSORS_H__

struct temp_t {
    void print() {
        printf("TEMP: local = %u, remote = %u\n",
            i2c.get(0x18, 0x00),
            i2c.get(0x18, 0x01)
        );
    }
};

// power monitor
struct pwr_t {
    void menu() {
        i2c.w8(0x40, 0x02);
        printf("pwr_bus: %u mV\n", 40959 * i2c.r16(0x40) / 0x7FFF); // 0x7FFF = 40.95875 V
        i2c.w8(0x40, 0x01);
        printf("pwr_shunt: %u uV\n", 81918 * i2c.r16(0x40) / 0x7FFF); // 0x7FFFF = 81.9175 mV
    }
};

#endif // __UTIL_A10_SENSORS_H__
