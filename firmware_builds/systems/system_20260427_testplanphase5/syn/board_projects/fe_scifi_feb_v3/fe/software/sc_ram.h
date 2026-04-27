#ifndef __FE_SC_RAM_H__
#define __FE_SC_RAM_H__

struct sc_ram_t {
    alt_u32 data[AVM_SC_SPAN/4 - 256];

    struct regs_t {
        union {
            alt_u32 block0[16];

            struct {
                alt_u32 status;
                alt_u32 git_hash;

                alt_u32 fpga_type;
                alt_u32 fpga_id;

                alt_u32 cmdlen;
                alt_u32 offset;

                alt_u32 reset_bypass; //11 downto 0: requested bypass (R/W) ; 9+16 downto 16: actual runstate (R)
                alt_u32 reset_bypass_payload;
                alt_u32 reset_optical_links;
                alt_u32 reset_phase;
                alt_u32 merger_rate_count;
            } fe;
        };

        union {
            alt_u32 block1[16];
        };

        union {
            alt_u32 block2[16];
        };

        union {
            alt_u32 block3[16];
        };

        union {
            alt_u32 block4[16];

            struct {
                struct {
                    alt_u32 data;
                    alt_u16 tag;
                    alt_u16 status;
                    alt_u32 reserved[2];
                } fifo;

                struct {
                    alt_u32 status;
                    alt_u32 rx_dpa_lock;
                    alt_u32 rx_ready;
                    alt_u32 reserved[1];
                } mon;

                struct {
                    alt_u32 dummy;
                    alt_u32 dp;
                    alt_u32 reset;
                    alt_u32 reserved[1];
                } ctrl;
            } TMB;
        };

        union {
            alt_u32 block5[16];
        };

        union {
            alt_u32 block6[16];

            struct {
                struct {
                    alt_u32 ctrl;
                    alt_u32 nom;
                    alt_u64 denom;
                } counters;
                struct {
                    alt_u32 status;
                    alt_u32 rx_dpa_lock;
                    alt_u32 rx_ready;
                    alt_u32 reserved[1];
                } mon;
                struct {
                    alt_u32 dummy;
                    alt_u32 dp;
                    alt_u32 reset;
                    alt_u32 resetdelay;
                } ctrl;
            } SMB;
        };

        union {
            alt_u32 block7[16];
        };

        union {
            alt_u32 block8[16];

            struct {
                alt_u32 test;
            } mupix;
        };

        union {
            alt_u32 block9[16];
        };

        union {
            alt_u32 block10[16];
        };

        union {
            alt_u32 block11[16];
        };

        union {
            alt_u32 block12[16];
        };

        union {
            alt_u32 block13[16];
        };

        union {
            alt_u32 block14[16];
        };

        union {
            alt_u32 block15[16];
        };

    } regs;
};

static_assert(sizeof(sc_ram_t) == 65536 * 4, "");
static_assert(sizeof(sc_ram_t::regs) == 256 * 4, "");

static_assert(offsetof(sc_ram_t, regs) % 1024 == 0, "");
static_assert(offsetof(sc_ram_t::regs_t, fe) % 64 == 0, "");
static_assert(offsetof(sc_ram_t::regs_t, TMB) % 64 == 0, "");
static_assert(offsetof(sc_ram_t::regs_t, SMB) % 64 == 0, "");
static_assert(offsetof(sc_ram_t::regs_t, mupix) % 64 == 0, "");

#endif // __FE_SC_RAM_H__
