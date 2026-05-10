//

void menu_lapse();
void menu_reg_dummyctrl();
void menu_subdet_reset();
void menu_mutrig_counters();
void menu_ch_rate();
void mutrig_reset_counters();
void menu_reg_resetskew();
//Copied from FEB1 including comment
//Reset skew configuration
//shadow storage of reset skew configuration,
//we do not have this in a register
uint8_t resetskew_count[4];
void RSTSKWctrl_Clear();
void RSTSKWctrl_Set(uint8_t channel, uint8_t value);


void menu_mutrig_common() {
    volatile sc_ram_t* ram = (sc_ram_t*) AVM_SC_BASE;
    uint32_t value = 0x0;
    char str[2] = {0};

    while(1) {
        printf("CTRL DP = 0x%08X\n", ram->data[MUTRIG_CTRL_DP_REGISTER_W]);
        printf("CNT CTRL = 0x%08X\n", ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
        printf("DUM CTRL = 0x%08X\n", ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]);
        printf("  [8] => data\n");
        printf("  [a] => counters\n");
        printf("  [b] => lapse correction menu\n");
        printf("  [c] => ch rate\n");
        printf("  [l] => link data menu\n");
        printf("  [m] => set ASIC mask\n");
        printf("  [s] => get slow control registers\n");
        printf("  [d] => get datapath status\n");
        printf("  [f] => dummy generator settings\n");
        printf("  [r] => reset things\n");
        printf("  [w] => enable length replace\n");
        printf("  [u] => disable length replace\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        printf("%c\n", cmd);
        switch(cmd) {
            case '8':
                printf("buffer_full / frame_desync / rx_pll_lock : 0x%03X\n", sc.ram->data[MUTRIG_MON_STATUS_REGISTER_R]);
                printf("rx_dpa_lock / rx_ready : 0x%04X / 0x%04X\n", sc.ram->data[MUTRIG_RX_STATUS_REGISTER_R] & 0x1FFC0, sc.ram->data[MUTRIG_RX_STATUS_REGISTER_R] & 0xFFF80000);
                break;
            case 'a':
                menu_mutrig_counters();
                break;
            case 'b':
                menu_lapse();
                break;
            case 'c':
                menu_ch_rate();
                break;
            case 's': //get slowcontrol registers
                //printf("dummyctrl_reg:    0x%08X\n", regs.ctrl.dummy);
                printf("dummyctrl_reg:    0x%08X\n", sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]);
                //sc.ram->data[addr];
                printf("    :cfgdummy_en  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>0)&1);
                printf("    :datagen_en   0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>1)&1);
                printf("    :datagen_fast 0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>2)&1);
                printf("    :datagen_cnt  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W]>>3)&0x3ff);

                printf("dpctrl_reg:       0x%08X\n", sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]);
                printf("    :mask         0b");
                for(int i=15;i>=0;i--)
                    printf("%d", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>i)&1);
                printf("\n");

                printf("    :dec_disable  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>31)&1);
                printf("    :rx_wait_all  0x%X\n", (sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W]>>30)&1);
                printf("subdet_reset_reg: 0x%08X\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W]);
                break;
            case 'd': //get datapath status
                printf("Datapath status registers: press 'q' to end\n");
                while(1){
                    printf("buffer_full / frame_desync / rx_pll_lock : 0x%03X ", sc.ram->data[MUTRIG_MON_STATUS_REGISTER_R]);
                    printf("rx_dpa_lock / rx_ready : 0x%04X / 0x%04X\r",
                            sc.ram->data[MUTRIG_RX_STATUS_REGISTER_R] & 0x1FFC0, sc.ram->data[MUTRIG_RX_STATUS_REGISTER_R] & 0xFFF80000);
                    if (read(uart,&cmd, 1) > 0){
                        printf("--\n");
                        if(cmd=='q') break;
                    }
                    usleep(200000);
                };
                break;
            case 'f':
                menu_reg_dummyctrl();
                break;
            case 'r':
                menu_subdet_reset();
                break;
            case 'm':
                value = 0x0;
                printf("Enter Chip Mask in hex: ");
                for ( int i = 0; i < 2; i++ ) {
                    printf("mask: 0x%08x\n", value);
                    str[0] = wait_key();
                    value = value*16+strtol(str,NULL,16);
                }
                printf("setting mask to 0x%08x\n", value);
                sc.ram->data[MUTRIG_CTRL_DP_REGISTER_W] = value;
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_lapse() {
    while(1) {
        printf("CTRL_LAPSE = 0x%08X\n", sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W]);
        printf("  [1] => enable injection\n");
        printf("  [2] => disable injection\n");


        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '1':
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] | (1<<31);
                break;
            case '2':
                sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_LAPSE_COUNTER_REGISTER_W] & ~(1<<31);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_pll_injection() {
    while(1) {
        printf("CNT CTRL = 0x%08X\n", sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W]);
        printf("  [1] => enable injection 100kHz pulse\n");
        printf("  [2] => disable injection 100kHz pulse\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '1':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] | (1<<0);
                break;
            case '2':
                sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] & ~(1<<0);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_reg_dummyctrl(){
    while(1) {
        auto reg = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W];
        //printf("Dummy reg now: %16.16x / %16.16x\n",sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W], reg);
        printf("  [0] => %s config dummy\n",(reg&1) == 0?"enable":"disable");
        printf("  [1] => %s data dummy\n",(reg&2) == 0?"enable":"disable");
        printf("  [2] => %s fast hit mode\n",(reg&4) == 0?"enable":"disable");
        printf("  [+] => increase count (currently %u)\n",(reg>>3&0x3fff));
        printf("  [-] => decrease count\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        uint32_t val;
        char cmd = wait_key();
        switch(cmd) {
            case '0':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<0);
                break;
            case '1':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<1);
                break;
            case '2':
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] ^ (1<<2);
                break;
            case '+':
                val=(reg>>3&0x3fff)+1;
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] & 0x07) | (0x3fff&(val <<3));
                break;
            case '-':
                val=(reg>>3&0x3fff)-1;
                sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] = (sc.ram->data[MUTRIG_CTRL_DUMMY_REGISTER_W] & 0x07) | (0x3fff&(val <<3));
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}


void menu_subdet_reset() {
    while(1) {
        printf("  [1] => reset asic\n");
        printf("  [2] => reset datapath\n");
        printf("  [3] => reset lvds_rx\n");
        printf("  [4] => reset skew settings\n");
        printf("  [5] => read reset reg\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '1':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 1;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '2':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 2;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '3':
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 4;
                printf("%x, %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W], MUTRIG_CTRL_RESET_REGISTER_W);
                usleep(50000);
                sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W] = 0;
                break;
            case '4':
                menu_reg_resetskew();
                break;
            case '5':
                printf("Reset red %x\n", sc.ram->data[MUTRIG_CTRL_RESET_REGISTER_W]);
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void RSTSKWctrl_Clear(){
    auto& reg = sc.ram->regs.SMB.ctrl.resetdelay;
    //reset pll to zero phase counters
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = 0x8000;
    for(int i=0; i<4;i++)
        resetskew_count[i]=0;
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = 0x0000;
}

void RSTSKWctrl_Set(uint8_t channel, uint8_t value){
    if(channel>7) return;
    if(value>7) return;
    uint32_t val = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] & 0xffc0;
    //printf("PLL_phaseadjust #%u: ",channel);
    while(value!=resetskew_count[channel]){
        val |= (channel+2)<<2;
        if(value>resetskew_count[channel]){ //increment counter
            val |= 2;
            //printf("+");
            resetskew_count[channel]++;
        }else{
            val |= 1;
            //printf("-");
            resetskew_count[channel]--;
        }
        sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = val;
    }
    //printf("\n");
    sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]= val & 0xffc0;
}
void menu_reg_resetskew(){
    int selected=0;
    while(1) {
        auto reg = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W];
        printf("Reset delay reg now: %16.16x\n",reg);
        printf("  [0..3] => Select line N (currently %d)\n",selected);

        printf("  [p] => swap phase bit (currently %d)\n",(reg>>(6 +selected)&0x1));
        printf("  [d] => swap delay bit (currently %d)\n",(reg>>(10+selected)&0x1));
        printf("  [+] => increase count (currently %d)\n",resetskew_count[selected]);
        printf("  [-] => increase count (currently %d)\n",resetskew_count[selected]);
        printf("  [r] => reset phase configuration\n");

        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
            case '0':
                break;
            case '1':
                selected=1;
                break;
            case '2':
                selected=2;
                break;
            case '3':
                selected=3;
                break;
            case 'r':
                RSTSKWctrl_Clear();
                break;
            case '+':
                RSTSKWctrl_Set(selected, resetskew_count[selected]+1);
                break;
            case '-':
                RSTSKWctrl_Set(selected, resetskew_count[selected]-1);
                break;
            case 'd':
                sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]^(1<<(10+selected));
                break;
            case 'p':
                sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W] = sc.ram->data[MUTRIG_CTRL_RESETDELAY_REGISTER_W]^(1<<( 6+selected));
                break;
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
        }
    }
}

void menu_mutrig_counters(){
    // Scifi Counters per ASIC N_ASICS_TOTAL
    // mutrig store:
    //  0: s_eventcounter
    //  1: s_timecounter low
    //  2: s_timecounter high
    //  3: s_crcerrorcounter
    //  4: s_framecounter
    //  5: s_prbs_wrd_cnt
    //  6: s_prbs_err_cnt
    // rx
    //  7: s_receivers_runcounter
    //  8: s_receivers_errorcounter
    //  9: s_receivers_synclosscounter
    char cmd;

    //this is for scifi
    uint32_t numModule = 2;
    uint32_t numASICsPerMod = 4;

    uint32_t lastTS = 0;
    uint32_t curNom = 0;
    uint32_t curDeNom = 0;
    uint32_t lastFrame[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    uint32_t lastWords[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    uint32_t lastCRC[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    uint32_t lastPRBS[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    uint32_t lastLVDS[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    uint32_t lastEvents[8] = {0, 0, 0, 0, 0, 0, 0, 0};    
    uint32_t counter_map[5] = {0, 3, 6, 8, 9};
    printf("Counters: press 'q' to end / 'r' to reset\n");
    while(1){
    printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
        for ( uint32_t mod = 0; mod < numModule; mod++ ) {
            printf("ASIC %i to %i\n", mod * numASICsPerMod, numASICsPerMod-1 + mod * numASICsPerMod);
            for ( uint32_t selected = 0; selected < 6; selected++ ) {
                switch ( selected ) {
                    case 0: printf("Events / 8ns        "); break;
                    case 1: printf("CRC-Errors / Frame  "); break;
                    case 2: printf("PRBS-Errors / Words "); break;
                    case 3: printf("LVDS-Errors / Words "); break;
                    case 4: printf("# SYNCLOSS  / -     "); break;
                    case 5: printf("Frame / 8ns         "); break;
                }
                // loop over asics
                for ( uint32_t asic = 0; asic < numASICsPerMod ; asic++ ) {
                    if ( asic % 6 == 0 ) printf("\n");
                    // print event rate
                    if ( selected == 0 ) {
                        // get time
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 1;
                        curDeNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        // get events of chip
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, curDeNom);
                        lastEvents[mod * asic] = curNom;
                        lastTS = curDeNom;
                    } else if ( selected == 1 ) {
                        // get frame
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 4 + asic * 10 + mod * numASICsPerMod * 10;
                        curDeNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        // get crc errors
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, curDeNom);
                        lastCRC[mod * asic] = curNom;
                        lastFrame[mod * asic] = curDeNom;
                    } else if ( selected == 2 ) {
                        // get words
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 5 + asic * 10 + mod * numASICsPerMod * 10;
                        curDeNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        // get prbs errors
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, curDeNom);
                        lastPRBS[mod * asic] = curNom;
                        lastWords[mod * asic] = curDeNom;
                    } else if ( selected == 3 ) {
                        // get words
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 5 + asic * 10 + mod * numASICsPerMod * 10;
                        curDeNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        // get lvds errors
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, curDeNom);
                        lastLVDS[mod * asic] = curNom;
                        lastWords[mod * asic] = curDeNom;
                    } else if ( selected == 4 ) {
                        // get sync loss
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, counter_map[selected] + asic * 10 + mod * numASICsPerMod * 10);
                    } else if ( selected == 5 ) {
                        // get time
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 1;
                        curDeNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        // get frame
                        sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = 4 + asic * 10 + mod * numASICsPerMod * 10;
                        curNom = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
                        printf("| %10u / %10u |", curNom, curDeNom);
                    }
                }
                printf("\n");
            }
        }
        printf("\n");

        if (read(uart,&cmd, 1) > 0){
            printf("--\n");
            if(cmd=='q') return;
            if(cmd=='r'){
                mutrig_reset_counters();
                printf("-- reset\n");
            };
        }
        usleep(200000);
    };

}


void menu_ch_rate() {

    uint32_t curRate = 0;
    for ( int asic = 0; asic < 4; asic++ ) {
        printf("\n");
        printf("ASIC %i: ", asic);
        for ( int ch = 0; ch < 32; ch++ ) {
            sc.ram->data[MUTRIG_CH_CTRL_REGISTER_R] = (ch << 4) | (asic & 0xF);
            if ( ch % 16 == 0 ) printf("\n");
            curRate = sc.ram->data[MUTRIG_CH_RATE_REGISTER_R + ch];
            printf("%i|", curRate);
        }
    printf("\n");
    }

}

//write counter values of all channels to memory address *data and following. Return number of asic channels written.
alt_u16 mutrig_store_counters(volatile alt_u32* data, int asics_total){
    for ( uint32_t asic = 0; asic < asics_total; asic++ ) {
        for ( uint32_t cnt = 0; cnt < 10; cnt++ ) {
            sc.ram->data[MUTRIG_CNT_ADDR_REGISTER_W] = asic * 10 + cnt;
            *data = sc.ram->data[MUTRIG_CNT_VALUE_REGISTER_R];
            data++;
        }
    }
    return asics_total; //return number of asic channels written so we can parse correctly later
}

void mutrig_reset_counters(){
    sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] | 1<<15;
    sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] = sc.ram->data[MUTRIG_CNT_CTRL_REGISTER_W] ^ 1<<15;
}
