
//Standard configuration patterns and length definition
//for *mutrig2* ASIC
const uint32_t MUTRIG_CONFIG_LEN_BYTES=333;
const uint32_t MUTRIG_CONFIG_LEN_BITS =2262;

#include "mutrig3/FF.h"
#include "mutrig2/ALL_OFF.h"
#include "mutrig2/PRBS_single.h"
#include "mutrig2/No_TDC_Power.h"
#include "mutrig2/PLL_TEST.h"
#include "mutrig2/MuTRiG2_PLL_maskall_but23.h"
#include "mutrig2/mutrig2_DCR.h"
#include "mutrig2/mutrig2_HighTTh.h"
