/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#ifndef __UTIL_SI_H__
#define __UTIL_SI_H__

#include <altera_avalon_i2c.h>
#include <altera_avalon_spi.h>

/**
 * SI (Silicon Labs) clock chip controller.
 */
struct si_t {
    /**
     * SI register type.
     */
    struct register_t {
        uint16_t address;
        uint16_t value;
    };

    int log_level = 0;

    ALT_AVALON_I2C_DEV_t* i2c_dev = nullptr;
    const alt_u32 i2c_slave = -1;

    const alt_u32 spi_base = -1;
    const alt_u32 spi_slave = -1;

    si_t(ALT_AVALON_I2C_DEV_t* i2c_dev, alt_u32 i2c_slave)
        : i2c_dev(i2c_dev)
        , i2c_slave(i2c_slave)
    {
    }

    si_t(alt_u32 spi_base, alt_u32 spi_slave)
        : spi_base(spi_base)
        , spi_slave(spi_slave)
    {
        printf("[si] PN_BASE = %02X%02X, GRADE = %d, DEVICE_REV = %d\n", read(0x0003), read(0x0002), read(0x0004), read(0x0005));
    }

    alt_u8 read_byte(alt_u8 address) {
        alt_u8 r[] = { 0x00 };
        if(i2c_dev != nullptr) {
            alt_avalon_i2c_master_target_set(i2c_dev, i2c_slave);
            alt_u8 w[] = { address };
            int write_err = alt_avalon_i2c_master_tx(i2c_dev, w, 1, ALT_AVALON_I2C_NO_INTERRUPTS);
            if(write_err != ALT_AVALON_I2C_SUCCESS) {
                printf("[si.read_byte] ERROR: alt_avalon_i2c_master_tx => %d\n", write_err);
            }
            int read_err = alt_avalon_i2c_master_rx(i2c_dev, r, 1, ALT_AVALON_I2C_NO_INTERRUPTS);
            if(read_err != ALT_AVALON_I2C_SUCCESS) {
                printf("[si.read_byte] ERROR: alt_avalon_i2c_master_rx => %d\n", read_err);
            }
        }
        else if(spi_slave != alt_u32(-1)) {
            alt_u8 w[] = { 0x00, address, 0x80 };
            alt_avalon_spi_command(spi_base, spi_slave, 3, w, 1, r, 0);
        }
        else {
            printf("[si.read_byte] ERROR: no spi/i2c interface\n");
        }
        return r[0];
    }

    void write_byte(alt_u8 address, alt_u8 value) {
        if(i2c_dev != nullptr) {
            alt_avalon_i2c_master_target_set(i2c_dev, i2c_slave);
            alt_u8 w[] = { address, value };
            int write_err = alt_avalon_i2c_master_tx(i2c_dev, w, 2, ALT_AVALON_I2C_NO_INTERRUPTS);
            if(write_err != ALT_AVALON_I2C_SUCCESS) {
                printf("[si.read_byte] ERROR: alt_avalon_i2c_master_tx => %d\n", write_err);
            }
        }
        else if(spi_slave != alt_u32(-1)) {
            alt_u8 w[4] = { 0x00, address, 0x40, value };
            alt_avalon_spi_command(spi_base, spi_slave, 4, w, 0, 0, 0);
        }
        else {
            printf("[si.write_byte] ERROR: no spi/i2c interface\n");
        }
    }

    int wait_ready(int timeout = 8) {
        for(int i = 0; i < timeout; i++) {
            if(read_byte(0xFE) == 0x0F) return 0;
            usleep(1000);
        }
        printf("[si.wait_ready] WARN: DEVICE_READY != 0x0F\n");
        return -1;
    }

    alt_u8 set_page(alt_u8 page) {
        wait_ready();
        if(page != read_byte(0x01)) {
            if(log_level > 0) printf("[si.set_page] page <= 0x%02X\n", page);
            write_byte(0x01, page);
            wait_ready();
        }
        return read_byte(0x01);
    }

    alt_u8 read(alt_u16 address) {
        set_page(address >> 8);
        alt_u8 value = read_byte(address & 0xFF);
        if(log_level > 0) printf("[si.read] si[0x%04X] = 0x%02X\n", address, value);
        return value;
    }

    void write(alt_u16 address, alt_u8 value) {
        if(log_level > 0) printf("[si.write] si[0x%04X] <= 0x%02X\n", address, value);
        set_page(address >> 8);
        write_byte(address & 0xFF, value);
        wait_ready();
    }

    void read_n(alt_u16 address, alt_u8* value, alt_u8 n) {
        for(alt_u8 i = 0; i < n; i++) {
            value[i] = read(address + i);
        }
    }

    void write_n(alt_u16 address, const alt_u8* value, alt_u8 n) {
        for(alt_u8 i = 0; i < n; i++) {
            write(address + i, value[i]);
        }
    }

    alt_u64 read_n(alt_u16 address, alt_u8 n) {
        alt_u64 value = 0;

        if(n > 8) {
            // TODO
        }

        while(n-- > 0) {
            value = (value << 8) | read(address++);
        }

        return value;
    }

    void write_n(alt_u16 address, alt_u64 value, alt_u8 n) {
        if(n > 8) {
            // TODO
        }

        while(n-- > 0) {
            write(address++, value & 0xFF);
            value >>= 8;
        }

        if(value != 0) {
            // TODO
        }
    }

    template < typename T >
    void init(const T* regs, int n) {
        for(int i = 0; i < n; i++) {
            alt_u16 address = regs[i].address;
            alt_u16 value = regs[i].value;
            if(address == 0xFFFF) {
                usleep(1000 * value);
                continue;
            }
            write(address, value);
        }

        printf("[si.init] done\n");
    }

};

#endif // __UTIL_SI_H__
