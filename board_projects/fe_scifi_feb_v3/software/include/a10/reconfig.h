/*
 * author : Alexandr Kozlinskiy
 * date : 2019
 */

#ifndef __UTIL_A10_RECONFIG_H__
#define __UTIL_A10_RECONFIG_H__

struct reconfig_t {
    static const alt_u32 ONE = 1;

    volatile alt_u32* base;

    /**
     * Set bit 'i'.
     */
    void set(alt_u32 r, alt_u32 i, alt_u32 b) {
        base[r] ^= (-b ^ base[r]) & (ONE << i);
        printf("DEBUG [0x%03X](%u) <= %u => [0x%03X] is 0x%02X\n", r, i, b, r, base[r]);
    }

    /**
     * Get bit i;
     */
    alt_u32 get(alt_u32 r, alt_u32 i) {
        alt_u32 b = (base[r] >> i) & ONE;
        printf("[0x%03X](%u) is '%u'\n", r, i, b);
        return b;
    }

    void wait(alt_u32 r, alt_u32 i, alt_u32 b) {
        printf("DEBUG wait [0x%03X](%u) ...", r, i);
        while(get(r, i) != b) {
            usleep(100);
        }
        printf(" '%u'\n", b);
    }

    void pll(alt_u32 QSFP_BASE) {
        printf("reconfig.pll 0x%08X\n", QSFP_BASE);
        base = (alt_u32*)(QSFP_BASE) + 0x2000;

//        if(get(0x280, 0) == 1) return; // pll_locked

        if(base[0x000] == 0xCCCCCCCC) {
            printf("E [reconfig.pll] invalid address\n");
            return;
        }

        // 1. Request user access to the internal configuration bus by writing 0x2 to offset address 0x0[7:0].
        base[0x000] = 0x2;
        // 2. Wait for reconfig_waitrequest to be deasserted (logic low)
        //    or wait until capability register of PreSICE Avalon-MM interface control = 0x0.
        while(get(0x280, 2) != 0) usleep(100);
        // 3. To calibrate the fPLL, Read-Modify-Write 0x1 to bit[1] of address 0x100 of the fPLL.
        set(0x100, 1, 1);
        // 4. Release the internal configuration bus to PreSICE to perform recalibration by writing 0x1 to offset address 0x0[7:0].
        base[0x000] = 0x1;
        // 5. Periodically check the *cal_busy output signals
        //    or read the capability registers 0x280[1] to check *cal_busy status until calibration is complete.
        wait(0x280, 1, 0); // fPLL calibration is running

        wait(0x280, 0, 1); // wait pll_locked
    }

    void phy(alt_u32 ch, alt_u32 QSFP_BASE) {
        printf("INFO reconfig.phy(0x%04X.0x%02X)\n", QSFP_BASE, ch);
        base = (alt_u32*)(QSFP_BASE) + 0x1000;

        // channel id
        if(ch != base[0x211]) {
            printf("ERROR reconfig.phy(0x%02X) - invalid channel 0x%02X\n", ch, base[0x211]);
            return;
        }

        // 1. Request access to the internal configuration bus by writing 0x2 to offset address 0x0[7:0].
        base[0x000] = 0x2;
        // 2. Wait for reconfig_waitrequest to be deasserted (logic low),
        // or wait until capability register of PreSICE Avalon-MM interface control = 0x0.
        wait(0x281, 2, 0);

        // -. Set Serial Loopback Mode
//        set(0x2E1, 0, 0);

        // 3. Set the proper value to offset address 0x100 to enable PMA calibration.
        //    You must set 0x100[6] to 0x0 when you enable any calibration.
        set(0x100, 1, 1); // PMA RX calibration enable
        set(0x100, 5, 1); // PMA TX calibration enable
        set(0x100, 6, 0);
        // 4. Set the rate switch flag register for PMA RX calibration after the rate change.
        //    - Read-Modify-Write 0x1 to offset address 0x166[7] if no rate switch.
        //    - Read-Modify-Write 0x0 to offset address 0x166[7] if switched rate with different CDR bandwidth setting.
        set(0x166, 7, 1);
        // 5. Do Read-Modify-Write the proper value to capability register 0x281[5:4] for PMA calibration to enable/disable tx_cal_busy or rx_cal_busy output.
        //    - To enable rx_cal_busy, Read-Modify-Write 0x1 to 0x281[5].
        //    - To disable rx_cal_busy, Read-Modify-Write 0x0 to 0x281[5].
        //    - To enable tx_cal_busy, Read-Modify-Write 0x1 to 0x281[4].
        //    - To disable tx_cal_busy, Read-Modify-Write 0x0 to 0x281[4].
        set(0x281, 4, 1); // enable PMA channel tx_cal_busy output
        set(0x281, 5, 1); // enable PMA channel rx_cal_busy output
        // 6. Release the internal configuration bus to PreSICE to perform recalibration by writing 0x1 to offset address 0x0[7:0].
        base[0x000] = 0x1;
        // 7. Periodically check the *cal_busy output signals
        //    or read the capability registers 0x281[1:0] to check *cal_busy status until calibration is complete.
        wait(0x281, 0, 0); // PMA TX calibration is running
        wait(0x281, 1, 0); // PMA RX calibration is running
    }
};

#endif // __UTIL_A10_RECONFIG_H__
