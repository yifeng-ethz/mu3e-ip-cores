# new signals for DAB2.2
# 6 control signals for the DS25BR440 LVDS buffer (0-5:upperbank;6-11:lowerbank)
set_location_assignment PIN_AB9  -to scifi_ds_ctrl[0]
set_location_assignment PIN_AB10 -to scifi_ds_ctrl[1]
set_location_assignment PIN_AB11 -to scifi_ds_ctrl[2]
set_location_assignment PIN_AA12 -to scifi_ds_ctrl[3]
set_location_assignment PIN_AG11 -to scifi_ds_ctrl[4]
set_location_assignment	PIN_AH11 -to scifi_ds_ctrl[5]
set_location_assignment PIN_A13  -to scifi_ds_ctrl[6]
set_location_assignment PIN_A14  -to scifi_ds_ctrl[7]
set_location_assignment PIN_B13  -to scifi_ds_ctrl[8]
set_location_assignment PIN_B12  -to scifi_ds_ctrl[9]
set_location_assignment PIN_J11  -to scifi_ds_ctrl[10]
set_location_assignment PIN_K11  -to scifi_ds_ctrl[11]
# 7 monitor of DS25B440 LVDS buffer Loss of Signal (low-active) (0-6:upperbank;7-13:lowerbank)
set_location_assignment PIN_AF12 -to scifi_ds_losn[0]
set_location_assignment PIN_AF13 -to scifi_ds_losn[1]
set_location_assignment PIN_AG12 -to scifi_ds_losn[2]
set_location_assignment PIN_AH12 -to scifi_ds_losn[3]
set_location_assignment PIN_AJ10 -to scifi_ds_losn[4]
set_location_assignment PIN_AK11 -to scifi_ds_losn[5]
set_location_assignment PIN_AK10 -to scifi_ds_losn[6]
set_location_assignment PIN_B15  -to scifi_ds_losn[7]
set_location_assignment PIN_A15  -to scifi_ds_losn[8]
set_location_assignment PIN_D14  -to scifi_ds_losn[9]
set_location_assignment PIN_C14  -to scifi_ds_losn[10]
set_location_assignment PIN_C13  -to scifi_ds_losn[11]
set_location_assignment PIN_K14  -to scifi_ds_losn[12]
set_location_assignment PIN_J14  -to scifi_ds_losn[13]
# analog charge injection single-end signal (0:upperbank;1:lowerbank)
set_location_assignment PIN_AH19 -to scifi_ainj[0]
set_location_assignment PIN_AG7  -to scifi_ainj[1]




#set_location_assignment PIN_AB9	 -to fdin_pre_en[0]
#set_location_assignment PIN_A13	 -to fdin_pre_en[1]
#set_location_assignment	PIN_AB10 -to fdin_eq_en[0]
#set_location_assignment	PIN_A14	 -to fdin_eq_en[1]
#set_location_assignment	PIN_AB11 -to fclk_pre_en[0]
#set_location_assignment	PIN_B13	 -to fclk_pre_en[1]
#set_location_assignment	PIN_AA12 -to frst_tdc_injdf_pre_en[0]
#set_location_assignment	PIN_B12	 -to frst_tdc_injdf_pre_en[1]
#set_location_assignment PIN_AH9	 -to fclk_los_n[0]
#set_location_assignment	PIN_D13	 -to fclk_los_n[1]
#
#set_location_assignment	PIN_AH18 -to inject_cal_p[0] 
#set_location_assignment	PIN_AH19 -to inject_cal_n[0]  
#set_location_assignment	PIN_AH7	-to inject_cal_p[1]
#set_location_assignment	PIN_AG7	-to inject_cal_n[1]
#set_location_assignment	PIN_AG20	-to inject_cal_s[0]
#set_location_assignment	PIN_AH4	-to inject_cal_s[1]
set_location_assignment PIN_AH20 -to scifi_temp_mutrig[0]
set_location_assignment	PIN_AJ4	 -to scifi_temp_mutrig[1]
set_location_assignment	PIN_AK20 -to scifi_temp_sipm[0]
set_location_assignment	PIN_AJ3	 -to scifi_temp_sipm[1]
set_location_assignment PIN_AK21 -to scifi_temp_dab[0]
set_location_assignment	PIN_AK3	 -to scifi_temp_dab[1]
set_location_assignment PIN_AJ21 -to scifi_temp_mutrig_old[0]
set_location_assignment PIN_AK22 -to scifi_temp_sipm_old[0]
set_location_assignment PIN_AH2	 -to scifi_temp_mutrig_old[1]
set_location_assignment	PIN_AH1	 -to scifi_temp_sipm_old[1]


#set_instance_assignment -name IO_STANDARD LVDS -to inject_cal_lvds[0]
#set_instance_assignment -name IO_STANDARD LVDS -to inject_cal_lvds[1]

#set_location_assignment PIN_J11 -to ds_preemp_en[1]
#set_location_assignment PIN_B13 -to ds_eq_en[0]
#set_location_assignment PIN_K11 -to ds_eq_en[1]
# CON2
#set_location_assignment PIN_AH12 -to scifi_lvds_los_n[0]
#set_location_assignment PIN_AG12 -to scifi_lvds_los_n[1]
#set_location_assignment PIN_AF13 -to scifi_lvds_los_n[2]
#set_location_assignment PIN_AF12 -to scifi_lvds_los_n[3]

set_location_assignment PIN_AG16 -to scifi_csn[0]
set_location_assignment PIN_AG6  -to scifi_csn[1]
set_location_assignment PIN_AE11 -to scifi_csn[2]
set_location_assignment PIN_AA10 -to scifi_csn[3]
set_location_assignment PIN_A5   -to scifi_cec_csn[0]
set_location_assignment PIN_AC12 -to scifi_cec_csn[1]
set_location_assignment PIN_AC15 -to scifi_cec_csn[2]
set_location_assignment PIN_AD15 -to scifi_cec_csn[3]
set_location_assignment PIN_AB12 -to scifi_cec_miso
set_location_assignment PIN_A4   -to scifi_fifo_ext
set_location_assignment PIN_AB18 -to scifi_inject
set_location_assignment PIN_AD22 -to scifi_syncres
set_location_assignment PIN_AC21 -to scifi_spi_sclk
set_location_assignment PIN_AB17 -to scifi_spi_miso
set_location_assignment PIN_AK19 -to scifi_spi_mosi
set_location_assignment PIN_AB22 -to scifi_din[0]
set_location_assignment PIN_AH23 -to scifi_din[1]
set_location_assignment PIN_AG22 -to scifi_din[2]
set_location_assignment PIN_AG21 -to scifi_din[3]
#set_location_assignment PIN_AJ21 -to scifi_temp_mutrig
#set_location_assignment PIN_AK22 -to scifi_temp_sipm

set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[0]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[1]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[2]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[3]

set_instance_assignment -name IO_STANDARD LVDS -to scifi_inject
set_instance_assignment -name IO_STANDARD LVDS -to scifi_syncres
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_sclk
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_miso
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_mosi
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[0]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[1]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[2]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[3]



set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_spi_miso
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[0]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[1]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[2]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[3]


# CON3

#set_location_assignment PIN_C14 -to scifi_lvds_los_n[4]
#set_location_assignment PIN_D14 -to scifi_lvds_los_n[5]
#set_location_assignment PIN_A15 -to scifi_lvds_los_n[6]
#set_location_assignment PIN_B15 -to scifi_lvds_los_n[7]

set_location_assignment PIN_B10  -to scifi_csn[4]
set_location_assignment PIN_B7   -to scifi_csn[5]
set_location_assignment PIN_D12  -to scifi_csn[6]
set_location_assignment PIN_D15  -to scifi_csn[7]
set_location_assignment PIN_C8   -to scifi_cec_csn[4]
set_location_assignment PIN_F15  -to scifi_cec_csn[5]
set_location_assignment PIN_G17  -to scifi_cec_csn[6]
set_location_assignment PIN_F17  -to scifi_cec_csn[7]
set_location_assignment PIN_G15  -to scifi_cec_miso2
set_location_assignment PIN_D8   -to scifi_fifo_ext2
set_location_assignment PIN_D19  -to scifi_inject2
set_location_assignment PIN_AH8  -to scifi_syncres2
set_location_assignment PIN_AD9  -to scifi_spi_sclk2
set_location_assignment PIN_AF6  -to scifi_spi_miso2
set_location_assignment PIN_AD16 -to scifi_spi_mosi2
set_location_assignment PIN_AB15 -to scifi_din[4]
set_location_assignment PIN_AB6  -to scifi_din[5]
set_location_assignment PIN_AK16 -to scifi_din[6]
set_location_assignment PIN_AK2  -to scifi_din[7]
#set_location_assignment PIN_AH2  -to scifi_temp_mutrig2
#set_location_assignment PIN_AH1  -to scifi_temp_sipm2

set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[4]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[5]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[6]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_csn[7]

set_instance_assignment -name IO_STANDARD LVDS -to scifi_inject2
set_instance_assignment -name IO_STANDARD LVDS -to scifi_syncres2
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_sclk2
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_miso2
set_instance_assignment -name IO_STANDARD LVDS -to scifi_spi_mosi2
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[4]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[5]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[6]
set_instance_assignment -name IO_STANDARD LVDS -to scifi_din[7]

set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_spi_miso2
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[4]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[5]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[6]
set_instance_assignment -name INPUT_TERMINATION DIFFERENTIAL -to scifi_din[7]
