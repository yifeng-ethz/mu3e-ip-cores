#ifndef __UTIL_SI_H__
#define __UTIL_SI_H__

#include "base.h"

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

    static constexpr alt_u32 SI_MOSI_BIT = 0;
    static constexpr alt_u32 SI_SCLK_BIT = 1;
    static constexpr alt_u32 SI_SS0_BIT = 2;
    static constexpr alt_u32 SI_SS1_BIT = 3;
    static constexpr alt_u32 SI_RST0_BIT = 4;
    static constexpr alt_u32 SI_RST1_BIT = 5;
    static constexpr alt_u32 SI_DEFAULT_STATE =
        (1u << SI_SS0_BIT) |
        (1u << SI_SS1_BIT) |
        (1u << SI_RST0_BIT) |
        (1u << SI_RST1_BIT);

    const alt_u32 gpio_base;
    const alt_u32 status_base;
    const alt_u32 chip;

    si_t(alt_u32 gpio_base, alt_u32 status_base, alt_u32 chip)
        : gpio_base(gpio_base)
        , status_base(status_base)
        , chip(chip)
    {
    }

    static alt_u32& shared_gpio_state() {
        static alt_u32 state = SI_DEFAULT_STATE;
        return state;
    }

    static void bit_delay() {
        for(volatile int i = 0; i < 8; ++i) {
            __asm__ volatile("nop");
        }
    }

    alt_u32 chip_select_mask() const {
        return 1u << (SI_SS0_BIT + chip);
    }

    alt_u32 reset_mask() const {
        return 1u << (SI_RST0_BIT + chip);
    }

    void apply_gpio() const {
        IOWR_ALTERA_AVALON_PIO_DATA(gpio_base, shared_gpio_state());
    }

    alt_u8 raw_status() const {
        return static_cast<alt_u8>(IORD_ALTERA_AVALON_PIO_DATA(status_base));
    }

    alt_u8 miso() const {
        return (raw_status() >> (4u + chip)) & 0x1u;
    }

    alt_u8 intr_n() const {
        return (raw_status() >> chip) & 0x1u;
    }

    alt_u8 lol_n() const {
        return (raw_status() >> (2u + chip)) & 0x1u;
    }

    void sync_defaults() const {
        shared_gpio_state() = SI_DEFAULT_STATE;
        apply_gpio();
        bit_delay();
    }

    void set_reset(bool release_reset_n) const {
        if(release_reset_n) {
            shared_gpio_state() |= reset_mask();
        }
        else {
            shared_gpio_state() &= ~reset_mask();
        }
        apply_gpio();
        bit_delay();
    }

    void deselect_all() const {
        shared_gpio_state() |= (1u << SI_SS0_BIT) | (1u << SI_SS1_BIT);
        shared_gpio_state() &= ~(1u << SI_SCLK_BIT);
        apply_gpio();
        bit_delay();
    }

    void select() const {
        deselect_all();
        shared_gpio_state() &= ~chip_select_mask();
        apply_gpio();
        bit_delay();
    }

    alt_u8 transfer_byte(alt_u8 value) const {
        alt_u8 readback = 0;

        for(int bit = 7; bit >= 0; --bit) {
            if(((value >> bit) & 0x1u) != 0) {
                shared_gpio_state() |= (1u << SI_MOSI_BIT);
            }
            else {
                shared_gpio_state() &= ~(1u << SI_MOSI_BIT);
            }

            shared_gpio_state() &= ~(1u << SI_SCLK_BIT);
            apply_gpio();
            bit_delay();

            shared_gpio_state() |= (1u << SI_SCLK_BIT);
            apply_gpio();
            bit_delay();
            readback = static_cast<alt_u8>((readback << 1) | miso());

            shared_gpio_state() &= ~(1u << SI_SCLK_BIT);
            apply_gpio();
            bit_delay();
        }

        return readback;
    }

    alt_u8 read_byte(alt_u8 address) {
        select();
        transfer_byte(0x00);
        transfer_byte(address);
        transfer_byte(0x80);
        alt_u8 value = transfer_byte(0x00);
        deselect_all();
        return value;
    }

    void write_byte(alt_u8 address, alt_u8 value) {
        select();
        transfer_byte(0x00);
        transfer_byte(address);
        transfer_byte(0x40);
        transfer_byte(value);
        deselect_all();
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
