//

#include "stdlib.h"

void menu_print_rate() {
    auto& rate = sc.ram->data[MERGER_RATE_REGISTER_R];
    while (1) {
            char cmd;
            if(read(uart, &cmd, 1) > 0) switch(cmd) {
            case 'q':
                return;
            default:
                printf("invalid command: '%c'\n", cmd);
            }

            printf("merger rate:  0x%08x\n", rate);

            usleep(200000);
        }
}

void menu_reset() {
    auto& reset_bypass = sc.ram->data[RUN_STATE_RESET_BYPASS_REGISTER_RW];
    auto  reset_bypass_buffer = 0;
    auto& reset_bypass_payload = sc.ram->data[RESET_PAYLOAD_REGISTER_RW];
    auto& reset_phase = sc.ram->data[RESET_PHASE_REGISTER_R];

    alt_u32 payload = 0x0;
    char str[2] = {0};

    while(1) {
        printf("\n");
        printf("[reset] -------- menu --------\n");

        printf("\n");
        printf("fe.reset_bypass = 0x%04X\n", reset_bypass);

        auto& rate = sc.ram->data[MERGER_RATE_REGISTER_R];

        printf("merger rate: 0x%08x\n", rate);

        printf("fe.reset_bypass: run state=");
        switch((reset_bypass >> 16) & 0x3ff) {
		case 1<<0: printf("RUN_STATE_IDLE\n"); break;
		case 1<<1: printf("RUN_STATE_PREP\n"); break;
		case 1<<2: printf("RUN_STATE_SYNC\n"); break;
		case 1<<3: printf("RUN_STATE_RUNNING\n"); break;
		case 1<<4: printf("RUN_STATE_TERMINATING\n"); break;
		case 1<<5: printf("RUN_STATE_LINK_TEST\n"); break;
		case 1<<6: printf("RUN_STATE_SYNC_TEST\n"); break;
		case 1<<7: printf("RUN_STATE_RESET\n"); break;
		case 1<<8: printf("RUN_STATE_OUT_OF_DAQ\n"); break;
		default:   printf("UNKNOWN\n"); break;
	}
/*
	printf("fe.reset_bypass: transition_command=");
        switch((reset_bypass) & 0xffff) {
		case 0x0000 : printf("USE GENESIS\n"); break;
		case 0x0110 : printf("RUN_PREP\n"); break;
		case 0x0111 : printf("SYNC\n"); break;
		case 0x0112 : printf("START_RUN\n"); break;
		case 0x0113 : printf("END_RUN\n"); break;
		case 0x0114 : printf("ABORT_RUN\n"); break;
		case 0x0130 : printf("START_RESET\n"); break;
		case 0x0131 : printf("STOP_RESET\n"); break;
		case 0x0120 : printf("START_LINKTEST\n"); break;
		case 0x0121 : printf("STOP_LINKTEST\n"); break;
		default:   printf("UNKNOWN\n"); break;
	}
*/
	printf("fe.reset_bypass: command payload=0x%8.8x (%d)\n",sc.ram->regs.fe.reset_bypass_payload,sc.ram->regs.fe.reset_bypass_payload);


        printf("\n");
        printf("  value: 0x%08x\n", 0xFFFF&reset_bypass);
        printf("  value: 0x%08x\n", reset_bypass);
        if((0x0000FFFF&reset_bypass)==0x00000200)
            printf("  [0] => use genesis\n");
        else
            printf("  [0] => use bypass\n");
        printf("  [1] => run_prep\n");
        printf("  [2] => sync\n");
        printf("  [3] => start run\n");
        printf("  [4] => end run\n");
        printf("  [5] => abort run\n");
        printf("  [6] => start reset\n");
        printf("  [7] => stop reset\n");
        printf("  [8] => start link test\n");
        printf("  [9] => stop link test\n");
        printf("  [r] => print rate\n");
        printf("  [a] => readout reset phase\n");
        printf("  [b] => reset pod\n");
        printf("  [c] => reset TX data\n");
        printf("  [p] => set payload   payload: 0x%08x\n", payload);
        printf("Select entry ...\n");
        reset_bypass_buffer = reset_bypass;
        char cmd = wait_key();
        switch(cmd) {
        case '0':
            if((0x0000FFFF&reset_bypass)==0x00000200){
                reset_bypass = 0x00000000;
                reset_bypass_buffer = 0x00000000;
            }else{
                reset_bypass=0x00000200;
                reset_bypass_buffer=0x00000200;
            }
            break;
        case '1':
            reset_bypass = 0x0310;
            break;
        case '2':
            reset_bypass = 0x0311;
            break;
        case '3':
            reset_bypass = 0x0312;
            break;
        case '4':
            reset_bypass = 0x0313;
            break;
        case '5':
            reset_bypass = 0x0314;
            break;
        case '6':
            reset_bypass = 0x0330;
            break;
        case '7':
            reset_bypass = 0x0331;
            break;
        case '8':
            reset_bypass = 0x0320;
            break;
        case '9':
            reset_bypass = 0x0321;
            break;
        case 'a':
            printf("Reset phase: 0x%08x\n", reset_phase);
            printf("TODO: Reset TX/Pod: 0x%08x\n",0);
            break;
        case 'b':
            printf("TODO: Reset reset pod\n");
            //sc.ram->data[0xFFF8] = 0x00000001; -- connect to something
            break;
        case 'c':
            printf("TODO: Reset TX data\n");
            //sc.ram->data[0xFFF8] = 0x00000002;
            break;
        case 'r':
            menu_print_rate();
            break;
        case 'p':
            payload = 0x0;
            printf("Enter payload in hex: ");

            for(int i = 0; i<8; i++){
                printf("payload: 0x%08x\n", payload);
                str[0] = wait_key();
                payload = payload*16+strtol(str,NULL,16);
            }

            printf("setting payload to 0x%08x\n", payload);
            reset_bypass_payload = payload;
            break;
        case 'q':
            return;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
        reset_bypass = reset_bypass_buffer;
    }
}
