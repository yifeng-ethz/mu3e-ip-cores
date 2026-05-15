/*
 * Si5342 Rev B Configuration Register Export Header File
 *
 * This file represents a series of Silicon Labs Si5342 Rev B
 * register writes that can be performed to load a single configuration
 * on a device. It was created by a Silicon Labs ClockBuilder Pro
 * export tool.
 *
 * Part:                                               Si5342 Rev B
 * Design ID:
 * Includes Pre/Post Download Control Register Writes: Yes
 * Created By:
 * Timestamp:
 *
 * A complete design report corresponding to this export is included at the end
 * of this header file.
 *
 */

#ifndef __SI5342_REGS_V1_H__
#define __SI5342_REGS_V1_H__

si_t::register_t const si5342_regs_v1[] =
{

	/* Start configuration preamble */
	{ 0x0B24, 0xD8 },
	{ 0x0B25, 0x00 },
	{ 0x0540, 0x01 },
	/* End configuration preamble */

	/* Delay 300 msec */
	/*    Delay is worst case time for device to complete any calibration */
	/*    that is running due to device state change previous to this script */
	/*    being processed. */
	{ 0xFFFF, 300 },

	/* Start configuration registers */
	{ 0x000B, 0x68 },
	{ 0x0016, 0x02 },
	{ 0x0017, 0x1C },
	{ 0x0018, 0xFE },
	{ 0x0019, 0xDD },
	{ 0x001A, 0xDF },
	{ 0x002B, 0x02 },
	{ 0x002C, 0x01 },
	{ 0x002D, 0x01 },
	{ 0x002E, 0x39 },
	{ 0x002F, 0x00 },
	{ 0x0030, 0x00 },
	{ 0x0031, 0x00 },
	{ 0x0032, 0x00 },
	{ 0x0033, 0x00 },
	{ 0x0034, 0x00 },
	{ 0x0035, 0x00 },
	{ 0x0036, 0x39 },
	{ 0x0037, 0x00 },
	{ 0x0038, 0x00 },
	{ 0x0039, 0x00 },
	{ 0x003A, 0x00 },
	{ 0x003B, 0x00 },
	{ 0x003C, 0x00 },
	{ 0x003D, 0x00 },
	{ 0x003F, 0x00 },
	{ 0x0040, 0x04 },
	{ 0x0041, 0x0D },
	{ 0x0042, 0x00 },
	{ 0x0043, 0x00 },
	{ 0x0044, 0x00 },
	{ 0x0045, 0x0C },
	{ 0x0046, 0x32 },
	{ 0x0047, 0x00 },
	{ 0x0048, 0x00 },
	{ 0x0049, 0x00 },
	{ 0x004A, 0x32 },
	{ 0x004B, 0x00 },
	{ 0x004C, 0x00 },
	{ 0x004D, 0x00 },
	{ 0x004E, 0x05 },
	{ 0x004F, 0x00 },
	{ 0x0050, 0x0E },
	{ 0x0051, 0x03 },
	{ 0x0052, 0x00 },
	{ 0x0053, 0x00 },
	{ 0x0054, 0x00 },
	{ 0x0055, 0x03 },
	{ 0x0056, 0x00 },
	{ 0x0057, 0x00 },
	{ 0x0058, 0x00 },
	{ 0x0059, 0x03 },
	{ 0x005A, 0x00 },
	{ 0x005B, 0x00 },
	{ 0x005C, 0x40 },
	{ 0x005D, 0x01 },
	{ 0x005E, 0x00 },
	{ 0x005F, 0x00 },
	{ 0x0060, 0x00 },
	{ 0x0061, 0x00 },
	{ 0x0062, 0x00 },
	{ 0x0063, 0x00 },
	{ 0x0064, 0x00 },
	{ 0x0065, 0x00 },
	{ 0x0066, 0x00 },
	{ 0x0067, 0x00 },
	{ 0x0068, 0x00 },
	{ 0x0069, 0x00 },
	{ 0x0092, 0x00 },
	{ 0x0093, 0x00 },
	{ 0x0095, 0x00 },
	{ 0x0096, 0x00 },
	{ 0x0098, 0x00 },
	{ 0x009A, 0x02 },
	{ 0x009B, 0x30 },
	{ 0x009D, 0x00 },
	{ 0x009E, 0x20 },
	{ 0x00A0, 0x00 },
	{ 0x00A2, 0x02 },
	{ 0x00A8, 0x41 },
	{ 0x00A9, 0xCA },
	{ 0x00AA, 0x07 },
	{ 0x00AB, 0x00 },
	{ 0x00AC, 0x00 },
	{ 0x0102, 0x01 },
	{ 0x0112, 0x02 },
	{ 0x0113, 0x09 },
	{ 0x0114, 0x3B },
	{ 0x0115, 0x00 },
	{ 0x0117, 0x02 },
	{ 0x0118, 0x09 },
	{ 0x0119, 0x3B },
	{ 0x011A, 0x00 },
	{ 0x013F, 0x00 },
	{ 0x0140, 0x00 },
	{ 0x0141, 0x40 },
	{ 0x0142, 0xFF },
	{ 0x0202, 0x00 },
	{ 0x0203, 0x00 },
	{ 0x0204, 0x00 },
	{ 0x0205, 0x00 },
	{ 0x0206, 0x00 },
	{ 0x0208, 0x41 },
	{ 0x0209, 0x00 },
	{ 0x020A, 0x00 },
	{ 0x020B, 0x00 },
	{ 0x020C, 0x00 },
	{ 0x020D, 0x00 },
	{ 0x020E, 0x01 },
	{ 0x020F, 0x00 },
	{ 0x0210, 0x00 },
	{ 0x0211, 0x00 },
	{ 0x0212, 0x00 },
	{ 0x0213, 0x00 },
	{ 0x0214, 0x00 },
	{ 0x0215, 0x00 },
	{ 0x0216, 0x00 },
	{ 0x0217, 0x00 },
	{ 0x0218, 0x00 },
	{ 0x0219, 0x00 },
	{ 0x021A, 0x00 },
	{ 0x021B, 0x00 },
	{ 0x021C, 0x00 },
	{ 0x021D, 0x00 },
	{ 0x021E, 0x00 },
	{ 0x021F, 0x00 },
	{ 0x0220, 0x00 },
	{ 0x0221, 0x00 },
	{ 0x0222, 0x00 },
	{ 0x0223, 0x00 },
	{ 0x0224, 0x00 },
	{ 0x0225, 0x00 },
	{ 0x0226, 0x00 },
	{ 0x0227, 0x00 },
	{ 0x0228, 0x00 },
	{ 0x0229, 0x00 },
	{ 0x022A, 0x00 },
	{ 0x022B, 0x00 },
	{ 0x022C, 0x00 },
	{ 0x022D, 0x00 },
	{ 0x022E, 0x00 },
	{ 0x022F, 0x00 },
	{ 0x0231, 0x01 },
	{ 0x0232, 0x01 },
	{ 0x0233, 0x01 },
	{ 0x0234, 0x01 },
	{ 0x0235, 0x00 },
	{ 0x0236, 0x00 },
	{ 0x0237, 0x00 },
	{ 0x0238, 0x00 },
	{ 0x0239, 0x87 },
	{ 0x023A, 0x00 },
	{ 0x023B, 0x00 },
	{ 0x023C, 0x00 },
	{ 0x023D, 0x00 },
	{ 0x023E, 0x80 },
	{ 0x0250, 0x01 },
	{ 0x0251, 0x00 },
	{ 0x0252, 0x00 },
	{ 0x0253, 0x04 },
	{ 0x0254, 0x00 },
	{ 0x0255, 0x00 },
	{ 0x026B, 's' },
	{ 0x026C, 'i' },
	{ 0x026D, '4' },
	{ 0x026E, '2' },
	{ 0x026F, '.' },
	{ 0x0270, 'v' },
	{ 0x0271, '1' },
	{ 0x0272, 0x00 },
	{ 0x0302, 0x00 },
	{ 0x0303, 0x00 },
	{ 0x0304, 0x00 },
	{ 0x0305, 0x80 },
	{ 0x0306, 0x0D },
	{ 0x0307, 0x00 },
	{ 0x0308, 0x00 },
	{ 0x0309, 0x00 },
	{ 0x030A, 0x00 },
	{ 0x030B, 0x80 },
	{ 0x030C, 0x00 },
	{ 0x030D, 0x00 },
	{ 0x030E, 0x00 },
	{ 0x030F, 0x00 },
	{ 0x0310, 0x00 },
	{ 0x0311, 0x00 },
	{ 0x0312, 0x00 },
	{ 0x0313, 0x00 },
	{ 0x0314, 0x00 },
	{ 0x0315, 0x00 },
	{ 0x0316, 0x00 },
	{ 0x0317, 0x00 },
	{ 0x0338, 0x00 },
	{ 0x0339, 0x1F },
	{ 0x033B, 0x00 },
	{ 0x033C, 0x00 },
	{ 0x033D, 0x00 },
	{ 0x033E, 0x00 },
	{ 0x033F, 0x00 },
	{ 0x0340, 0x00 },
	{ 0x0341, 0x00 },
	{ 0x0342, 0x00 },
	{ 0x0343, 0x00 },
	{ 0x0344, 0x00 },
	{ 0x0345, 0x00 },
	{ 0x0346, 0x00 },
	{ 0x0359, 0x00 },
	{ 0x035A, 0x00 },
	{ 0x035B, 0x00 },
	{ 0x035C, 0x00 },
	{ 0x0487, 0x00 },
	{ 0x0508, 0x13 },
	{ 0x0509, 0x22 },
	{ 0x050A, 0x0C },
	{ 0x050B, 0x0B },
	{ 0x050C, 0x07 },
	{ 0x050D, 0x3F },
	{ 0x050E, 0x16 },
	{ 0x050F, 0x2A },
	{ 0x0510, 0x09 },
	{ 0x0511, 0x08 },
	{ 0x0512, 0x07 },
	{ 0x0513, 0x3F },
	{ 0x0515, 0x00 },
	{ 0x0516, 0x00 },
	{ 0x0517, 0x00 },
	{ 0x0518, 0x00 },
	{ 0x0519, 0xBE },
	{ 0x051A, 0x02 },
	{ 0x051B, 0x00 },
	{ 0x051C, 0x00 },
	{ 0x051D, 0x00 },
	{ 0x051E, 0x00 },
	{ 0x051F, 0x80 },
	{ 0x0521, 0x21 },
	{ 0x052A, 0x01 },
	{ 0x052B, 0x01 },
	{ 0x052C, 0x0F },
	{ 0x052D, 0x03 },
	{ 0x052E, 0x19 },
	{ 0x052F, 0x19 },
	{ 0x0531, 0x00 },
	{ 0x0532, 0x63 },
	{ 0x0533, 0x03 },
	{ 0x0534, 0x00 },
	{ 0x0535, 0x00 },
	{ 0x0536, 0x0C },
	{ 0x0537, 0x00 },
	{ 0x0538, 0x00 },
	{ 0x0539, 0x00 },
	{ 0x0802, 0x35 },
	{ 0x0803, 0x05 },
	{ 0x0804, 0x00 },
	{ 0x090E, 0x02 },
	{ 0x0943, 0x00 },
	{ 0x0949, 0x01 },
	{ 0x094A, 0x01 },
	{ 0x0A02, 0x00 },
	{ 0x0A03, 0x01 },
	{ 0x0A04, 0x01 },
	{ 0x0A05, 0x01 },
	{ 0x0B44, 0x2F },
	{ 0x0B46, 0x00 },
	{ 0x0B47, 0x0E },
	{ 0x0B48, 0x0E },
	{ 0x0B4A, 0x02 },
	/* End configuration registers */

	/* Start configuration postamble */
	{ 0x0514, 0x01 },
	{ 0x001C, 0x01 },
	{ 0x0540, 0x00 },
	{ 0x0B24, 0xDB },
	{ 0x0B25, 0x02 },
	/* End configuration postamble */

};

/*
 * Design Report
 *
 * Overview
 * ========
 * Part:               Si5342ABCD Rev B
 * Project File:
 * Design ID:
 * Created By:
 * Timestamp:
 *
 * Design Rule Check
 * =================
 * Errors:
 * - No errors
 *
 * Warnings:
 * - Revision B is not recommended for new designs
 *
 * Device Grade
 * ============
 * Maximum Output Frequency: 125 MHz
 * Frequency Synthesis Mode: Integer
 * Frequency Plan Grade:     D
 * Minimum Base OPN:         Si5342D*
 *
 * Base       Output Clock         Supported Frequency Synthesis Modes
 * OPN Grade  Frequency Range      (Typical Jitter)
 * ---------  -------------------  --------------------------------------------
 * Si5342A    100 Hz to 712.5 MHz  Integer (< 100 fs) and fractional (< 150 fs)
 * Si5342B    100 Hz to 350 MHz    "
 * Si5342C    100 Hz to 712.5 MHz  Integer only (< 100 fs)
 * Si5342D*   100 Hz to 350 MHz    "
 *
 * * Based on your calculated frequency plan, a Si5342D grade device is
 * sufficient for your design. For more in-system configuration flexibility
 * (higher frequencies and/or to enable fractional synthesis), consider
 * selecting device grade Si5342A when specifying an ordering part number (OPN)
 * for your application. See the datasheet Ordering Guide for more information.
 *
 * Design
 * ======
 * Host Interface:
 *    I/O Power Supply: VDD (Core)
 *    SPI Mode: 4-Wire
 *    I2C Address Range: 104d to 107d / 0x68 to 0x6B (selected via A0/A1 pins)
 *
 * XA/XB:
 *    50 MHz (XTAL - Crystal)
 *
 * Inputs:
 *     IN0: 125 MHz
 *          Standard
 *     IN1: Unused
 *     IN2: Unused
 *     IN3: Unused
 *
 * Outputs:
 *    OUT0: 125 MHz
 *          Enabled, LVDS 2.5 V
 *    OUT1: 50 MHz
 *          Enabled, LVDS 2.5 V
 *
 * Frequency Plan
 * ==============
 * Priority: maximize the number of low jitter outputs
 *
 * Fvco = 13.5 GHz
 * Fpfd = 1.9230769230769230... MHz [ 1 + 12/13 MHz ]
 * Fms0 = 500 MHz
 *
 * P dividers:
 *    P0  = 65
 *    P1  = Unused
 *    P2  = Unused
 *    P3  = Unused
 *    Pxaxb = 1
 *
 * MXAXB = 270
 * M = 1404
 * N dividers:
 *    N0:
 *       Value: 27
 *       OUT0: 125 MHz
 *       OUT1: 50 MHz
 *    N1:
 *       Unused
 *
 * R dividers:
 *    R0 = 4
 *    R1 = 10
 *
 * Nominal Bandwidth:
 *   Desired: 100.000 Hz
 *   Actual:  89.238 Hz
 *   Coefficients:
 *      BW0:  19
 *      BW1:  34
 *      BW2:  12
 *      BW3:  11
 *      BW4:  7
 *      BW5:  63
 * Fastlock Bandwidth:
 *   Desired: 1.000 kHz
 *   Actual:  714.652 Hz
 *   Coefficients:
 *      BW0:  22
 *      BW1:  42
 *      BW2:  9
 *      BW3:  8
 *      BW4:  7
 *      BW5:  63
 *
 * Dividers listed above show effective values. These values are translated to register settings by ClockBuilder Pro. For the actual register values, see below. Refer to the Family Reference Manual for information on registers related to frequency plan.
 *
 * Digitally Controlled Oscillator (DCO)
 * =====================================
 * Mode: FINC/FDEC
 *
 * N0: DCO Disabled
 *
 * N1: DCO Disabled
 *
 * Revision B Frequency Offset Errata Report
 * =========================================
 *
 * Output  Frequency  Offset(Max,ppt)
 * ------  ---------  ---------------
 * OUT0    125 MHz    0.000000
 * OUT1    50 MHz     0.000000
 *
 * Offset is reported in parts-per-trillion (1e12).
 *
 * Estimated Power & Junction Temperature
 * ======================================
 * Assumptions:
 *
 * Revision: B
 * VDD:      1.8 V
 * Ta:       25 C
 * Theta-JA: 18.4 C/W
 * Airflow:  2 m/s
 *
 * Total Power: 638 mW, On Chip Power: 626 mW, Tj: 37 C
 *
 *         Frequency  Format   Voltage   Current     Power
 *         ---------  ------  --------  --------  --------
 * VDD                           1.8 V  101.2 mA    182 mW
 * VDDA                          3.3 V  114.8 mA    379 mW
 * VDDO0     125 MHz  LVDS       2.5 V   15.6 mA     39 mW
 * VDDO1      50 MHz  LVDS       2.5 V   15.2 mA     38 mW
 *                                      --------  --------
 *                               Total  246.8 mA    638 mW
 *
 * Note:
 *
 * -Tj is junction temperature. Tj must be less than 125 C (on Si5342 Revision B) for device to comply with datasheet specifications. Tj = Ta + Theta_JA*On_Chip_Power.
 * -Overall power includes on-chip power dissipation and adds differential load power dissipation to estimate total power requirements.
 * -Above are estimates only: power and temperature should be measured on your PCB.
 * -Selection of appropriate Theta-JA is required for most accurate estimate. Ideally, select 'User Specified Theta-JA' and enter a Theta-JA value based on the thermal properties of your PCB.
 *
 * Settings
 * ========
 *
 * Location      Setting Name          Decimal Value      Hex Value
 * ------------  --------------------  -----------------  -----------------
 * 0x000B[6:0]   I2C_ADDR              104                0x68
 * 0x0016[1]     LOL_ON_HOLD           1                  0x1
 * 0x0017[0]     SYSINCAL_INTR_MSK     0                  0x0
 * 0x0017[1]     LOSXAXB_INTR_MSK      0                  0x0
 * 0x0017[5]     SMB_TMOUT_INTR_MSK    0                  0x0
 * 0x0018[3:0]   LOS_INTR_MSK          14                 0xE
 * 0x0018[7:4]   OOF_INTR_MSK          15                 0xF
 * 0x0019[1]     LOL_INTR_MSK          0                  0x0
 * 0x0019[5]     HOLD_INTR_MSK         0                  0x0
 * 0x001A[5]     CAL_PLL_INTR_MSK      0                  0x0
 * 0x002B[3]     SPI_3WIRE             0                  0x0
 * 0x002B[5]     AUTO_NDIV_UPDATE      0                  0x0
 * 0x002C[3:0]   LOS_EN                1                  0x1
 * 0x002C[4]     LOSXAXB_DIS           0                  0x0
 * 0x002D[1:0]   LOS0_VAL_TIME         1                  0x1
 * 0x002D[3:2]   LOS1_VAL_TIME         0                  0x0
 * 0x002D[5:4]   LOS2_VAL_TIME         0                  0x0
 * 0x002D[7:6]   LOS3_VAL_TIME         0                  0x0
 * 0x002E[15:0]  LOS0_TRG_THR          57                 0x0039
 * 0x0030[15:0]  LOS1_TRG_THR          0                  0x0000
 * 0x0032[15:0]  LOS2_TRG_THR          0                  0x0000
 * 0x0034[15:0]  LOS3_TRG_THR          0                  0x0000
 * 0x0036[15:0]  LOS0_CLR_THR          57                 0x0039
 * 0x0038[15:0]  LOS1_CLR_THR          0                  0x0000
 * 0x003A[15:0]  LOS2_CLR_THR          0                  0x0000
 * 0x003C[15:0]  LOS3_CLR_THR          0                  0x0000
 * 0x003F[3:0]   OOF_EN                0                  0x0
 * 0x003F[7:4]   FAST_OOF_EN           0                  0x0
 * 0x0040[2:0]   OOF_REF_SEL           4                  0x4
 * 0x0041[4:0]   OOF0_DIV_SEL          13                 0x0D
 * 0x0042[4:0]   OOF1_DIV_SEL          0                  0x00
 * 0x0043[4:0]   OOF2_DIV_SEL          0                  0x00
 * 0x0044[4:0]   OOF3_DIV_SEL          0                  0x00
 * 0x0045[4:0]   OOFXO_DIV_SEL         12                 0x0C
 * 0x0046[7:0]   OOF0_SET_THR          50                 0x32
 * 0x0047[7:0]   OOF1_SET_THR          0                  0x00
 * 0x0048[7:0]   OOF2_SET_THR          0                  0x00
 * 0x0049[7:0]   OOF3_SET_THR          0                  0x00
 * 0x004A[7:0]   OOF0_CLR_THR          50                 0x32
 * 0x004B[7:0]   OOF1_CLR_THR          0                  0x00
 * 0x004C[7:0]   OOF2_CLR_THR          0                  0x00
 * 0x004D[7:0]   OOF3_CLR_THR          0                  0x00
 * 0x004E[2:0]   OOF0_DETWIN_SEL       5                  0x5
 * 0x004E[6:4]   OOF1_DETWIN_SEL       0                  0x0
 * 0x004F[2:0]   OOF2_DETWIN_SEL       0                  0x0
 * 0x004F[6:4]   OOF3_DETWIN_SEL       0                  0x0
 * 0x0050[3:0]   OOF_ON_LOS            14                 0xE
 * 0x0051[3:0]   FAST_OOF0_SET_THR     3                  0x3
 * 0x0052[3:0]   FAST_OOF1_SET_THR     0                  0x0
 * 0x0053[3:0]   FAST_OOF2_SET_THR     0                  0x0
 * 0x0054[3:0]   FAST_OOF3_SET_THR     0                  0x0
 * 0x0055[3:0]   FAST_OOF0_CLR_THR     3                  0x3
 * 0x0056[3:0]   FAST_OOF1_CLR_THR     0                  0x0
 * 0x0057[3:0]   FAST_OOF2_CLR_THR     0                  0x0
 * 0x0058[3:0]   FAST_OOF3_CLR_THR     0                  0x0
 * 0x0059[1:0]   FAST_OOF0_DETWIN_SEL  3                  0x3
 * 0x0059[3:2]   FAST_OOF1_DETWIN_SEL  0                  0x0
 * 0x0059[5:4]   FAST_OOF2_DETWIN_SEL  0                  0x0
 * 0x0059[7:6]   FAST_OOF3_DETWIN_SEL  0                  0x0
 * 0x005A[25:0]  OOF0_RATIO_REF        20971520           0x1400000
 * 0x005E[25:0]  OOF1_RATIO_REF        0                  0x0000000
 * 0x0062[25:0]  OOF2_RATIO_REF        0                  0x0000000
 * 0x0066[25:0]  OOF3_RATIO_REF        0                  0x0000000
 * 0x0092[1]     LOL_FST_EN            0                  0x0
 * 0x0093[7:4]   LOL_FST_DETWIN_SEL    0                  0x0
 * 0x0095[3:2]   LOL_FST_VALWIN_SEL    0                  0x0
 * 0x0096[7:4]   LOL_FST_SET_THR_SEL   0                  0x0
 * 0x0098[7:4]   LOL_FST_CLR_THR_SEL   0                  0x0
 * 0x009A[1]     LOL_SLOW_EN_PLL       1                  0x1
 * 0x009B[7:4]   LOL_SLW_DETWIN_SEL    3                  0x3
 * 0x009D[3:2]   LOL_SLW_VALWIN_SEL    0                  0x0
 * 0x009E[7:4]   LOL_SLW_SET_THR       2                  0x2
 * 0x00A0[7:4]   LOL_SLW_CLR_THR       0                  0x0
 * 0x00A2[1]     LOL_TIMER_EN          1                  0x1
 * 0x00A8[34:0]  LOL_CLR_DELAY         510529             0x00007CA41
 * 0x0102[0]     OUTALL_DISABLE_LOW    1                  0x1
 * 0x0112[0]     OUT0_PDN              0                  0x0
 * 0x0112[1]     OUT0_OE               1                  0x1
 * 0x0112[2]     OUT0_RDIV_FORCE2      0                  0x0
 * 0x0113[2:0]   OUT0_FORMAT           1                  0x1
 * 0x0113[3]     OUT0_SYNC_EN          1                  0x1
 * 0x0113[5:4]   OUT0_DIS_STATE        0                  0x0
 * 0x0113[7:6]   OUT0_CMOS_DRV         0                  0x0
 * 0x0114[3:0]   OUT0_CM               11                 0xB
 * 0x0114[6:4]   OUT0_AMPL             3                  0x3
 * 0x0115[2:0]   OUT0_MUX_SEL          0                  0x0
 * 0x0115[7:6]   OUT0_INV              0                  0x0
 * 0x0117[0]     OUT1_PDN              0                  0x0
 * 0x0117[1]     OUT1_OE               1                  0x1
 * 0x0117[2]     OUT1_RDIV_FORCE2      0                  0x0
 * 0x0118[2:0]   OUT1_FORMAT           1                  0x1
 * 0x0118[3]     OUT1_SYNC_EN          1                  0x1
 * 0x0118[5:4]   OUT1_DIS_STATE        0                  0x0
 * 0x0118[7:6]   OUT1_CMOS_DRV         0                  0x0
 * 0x0119[3:0]   OUT1_CM               11                 0xB
 * 0x0119[6:4]   OUT1_AMPL             3                  0x3
 * 0x011A[2:0]   OUT1_MUX_SEL          0                  0x0
 * 0x011A[7:6]   OUT1_INV              0                  0x0
 * 0x013F[11:0]  OUTX_ALWAYS_ON        0                  0x000
 * 0x0141[1]     OUT_DIS_MSK           0                  0x0
 * 0x0141[5]     OUT_DIS_LOL_MSK       0                  0x0
 * 0x0141[6]     OUT_DIS_LOSXAXB_MSK   1                  0x1
 * 0x0141[7]     OUT_DIS_MSK_LOS_PFD   0                  0x0
 * 0x0142[1]     OUT_DIS_MSK_LOL       1                  0x1
 * 0x0142[5]     OUT_DIS_MSK_HOLD      1                  0x1
 * 0x0202[31:0]  XAXB_FREQ_OFFSET      0                  0x00000000
 * 0x0206[1:0]   PXAXB                 0                  0x0
 * 0x0208[47:0]  P0_NUM                65                 0x000000000041
 * 0x020E[31:0]  P0_DEN                1                  0x00000001
 * 0x0212[47:0]  P1_NUM                0                  0x000000000000
 * 0x0218[31:0]  P1_DEN                0                  0x00000000
 * 0x021C[47:0]  P2_NUM                0                  0x000000000000
 * 0x0222[31:0]  P2_DEN                0                  0x00000000
 * 0x0226[47:0]  P3_NUM                0                  0x000000000000
 * 0x022C[31:0]  P3_DEN                0                  0x00000000
 * 0x0231[3:0]   P0_FRACN_MODE         1                  0x1
 * 0x0231[4]     P0_FRACN_EN           0                  0x0
 * 0x0232[3:0]   P1_FRACN_MODE         1                  0x1
 * 0x0232[4]     P1_FRACN_EN           0                  0x0
 * 0x0233[3:0]   P2_FRACN_MODE         1                  0x1
 * 0x0233[4]     P2_FRACN_EN           0                  0x0
 * 0x0234[3:0]   P3_FRACN_MODE         1                  0x1
 * 0x0234[4]     P3_FRACN_EN           0                  0x0
 * 0x0235[43:0]  MXAXB_NUM             579820584960       0x08700000000
 * 0x023B[31:0]  MXAXB_DEN             2147483648         0x80000000
 * 0x0250[23:0]  R0_REG                1                  0x000001
 * 0x0253[23:0]  R1_REG                4                  0x000004
 * 0x026B[7:0]   DESIGN_ID0            's'                0x..
 * 0x026C[7:0]   DESIGN_ID1            'i'                0x..
 * 0x026D[7:0]   DESIGN_ID2            '4'                0x..
 * 0x026E[7:0]   DESIGN_ID3            '2'                0x..
 * 0x026F[7:0]   DESIGN_ID4            '.'                0x..
 * 0x0270[7:0]   DESIGN_ID5            'v'                0x..
 * 0x0271[7:0]   DESIGN_ID6            '1'                0x..
 * 0x0272[7:0]   DESIGN_ID7            0                  0x00
 * 0x0302[43:0]  N0_NUM                57982058496        0x00D80000000
 * 0x0308[31:0]  N0_DEN                2147483648         0x80000000
 * 0x030C[0]     N0_UPDATE             0                  0x0
 * 0x030D[43:0]  N1_NUM                0                  0x00000000000
 * 0x0313[31:0]  N1_DEN                0                  0x00000000
 * 0x0317[0]     N1_UPDATE             0                  0x0
 * 0x0338[1]     N_UPDATE              0                  0x0
 * 0x0339[4:0]   N_FSTEP_MSK           31                 0x1F
 * 0x033B[43:0]  N0_FSTEPW             0                  0x00000000000
 * 0x0341[43:0]  N1_FSTEPW             0                  0x00000000000
 * 0x0359[15:0]  N0_DELAY              0                  0x0000
 * 0x035B[15:0]  N1_DELAY              0                  0x0000
 * 0x0487[0]     ZDM_EN                0                  0x0
 * 0x0487[2:1]   ZDM_IN_SEL            0                  0x0
 * 0x0508[5:0]   BW0_PLL               19                 0x13
 * 0x0509[5:0]   BW1_PLL               34                 0x22
 * 0x050A[5:0]   BW2_PLL               12                 0x0C
 * 0x050B[5:0]   BW3_PLL               11                 0x0B
 * 0x050C[5:0]   BW4_PLL               7                  0x07
 * 0x050D[5:0]   BW5_PLL               63                 0x3F
 * 0x050E[5:0]   FAST_BW0_PLL          22                 0x16
 * 0x050F[5:0]   FAST_BW1_PLL          42                 0x2A
 * 0x0510[5:0]   FAST_BW2_PLL          9                  0x09
 * 0x0511[5:0]   FAST_BW3_PLL          8                  0x08
 * 0x0512[5:0]   FAST_BW4_PLL          7                  0x07
 * 0x0513[5:0]   FAST_BW5_PLL          63                 0x3F
 * 0x0515[55:0]  M_NUM                 3015067041792      0x0002BE00000000
 * 0x051C[31:0]  M_DEN                 2147483648         0x80000000
 * 0x0521[3:0]   M_FRAC_MODE           1                  0x1
 * 0x0521[4]     M_FRAC_EN             0                  0x0
 * 0x0521[5]     PLL_OUT_RATE_SEL      1                  0x1
 * 0x052A[0]     IN_SEL_REGCTRL        1                  0x1
 * 0x052A[3:1]   IN_SEL                0                  0x0
 * 0x052B[0]     FASTLOCK_AUTO_EN      1                  0x1
 * 0x052B[1]     FASTLOCK_MAN          0                  0x0
 * 0x052C[0]     HOLD_EN               1                  0x1
 * 0x052C[3]     HOLD_RAMP_BYP         1                  0x1
 * 0x052C[7:5]   HOLD_RAMP_RATE        0                  0x0
 * 0x052D[1]     HOLD_RAMPBYP_NOHIST   1                  0x1
 * 0x052E[4:0]   HOLD_HIST_LEN         25                 0x19
 * 0x052F[4:0]   HOLD_HIST_DELAY       25                 0x19
 * 0x0531[4:0]   HOLD_REF_COUNT_FRC    0                  0x00
 * 0x0532[23:0]  HOLD_15M_CYC_COUNT    867                0x000363
 * 0x0535[0]     FORCE_HOLD            0                  0x0
 * 0x0536[1:0]   CLK_SWITCH_MODE       0                  0x0
 * 0x0536[2]     HSW_EN                1                  0x1
 * 0x0536[3]     HSW_RAMP_BYP          1                  0x1
 * 0x0537[3:0]   IN_LOS_MSK            0                  0x0
 * 0x0537[7:4]   IN_OOF_MSK            0                  0x0
 * 0x0538[2:0]   IN0_PRIORITY          0                  0x0
 * 0x0538[6:4]   IN1_PRIORITY          0                  0x0
 * 0x0539[2:0]   IN2_PRIORITY          0                  0x0
 * 0x0539[6:4]   IN3_PRIORITY          0                  0x0
 * 0x0802[15:0]  FIXREGSA0             1333               0x0535
 * 0x0804[7:0]   FIXREGSD0             0                  0x00
 * 0x090E[0]     XAXB_EXTCLK_EN        0                  0x0
 * 0x0943[0]     IO_VDD_SEL            0                  0x0
 * 0x0949[3:0]   IN_EN                 1                  0x1
 * 0x0949[7:4]   IN_PULSED_CMOS_EN     0                  0x0
 * 0x094A[3:0]   INX_TO_PFD_EN         1                  0x1
 * 0x0A02[4:0]   N_ADD_0P5             0                  0x00
 * 0x0A03[4:0]   N_CLK_TO_OUTX_EN      1                  0x01
 * 0x0A04[4:0]   N_PIBYP               1                  0x01
 * 0x0A05[4:0]   N_PDNB                1                  0x01
 * 0x0B44[3:0]   PDIV_FRACN_CLK_DIS    15                 0xF
 * 0x0B44[5]     FRACN_CLK_DIS_PLL     1                  0x1
 * 0x0B46[3:0]   LOS_CLK_DIS           0                  0x0
 * 0x0B47[4:0]   OOF_CLK_DIS           14                 0x0E
 * 0x0B48[4:0]   OOF_DIV_CLK_DIS       14                 0x0E
 * 0x0B4A[4:0]   N_CLK_DIS             2                  0x02
 *
 *
 */

#endif __SI5342_REGS_V1_H__
