--

library ieee;
use ieee.std_logic_1164.all;

package mupix is

    -----------------------------------------------------------
    -- mupix hit constants
    -----------------------------------------------------------

    constant MUPIX_HITSIZE          :  integer := 32;
    constant MUPIX_TIMESTAMPSIZE    :  integer := 11;
    subtype  COLRANGE               is integer range 23 downto 16;
    subtype  ROWRANGE               is integer range 15 downto 8;
    constant CHARGESIZE_MP10        :  integer := 5;

    -----------------------------------------------------------
    -- mupix ctrl constants
    -----------------------------------------------------------

    type mp_config_regs_length_t    is array (5 downto 0) of integer;
    constant MP_CONFIG_REGS_LENGTH  : mp_config_regs_length_t := (512, 896, 896, 80, 90, 210);

    type tdac_conversion_index_t    is array (511 downto 0) of integer;

    constant tdac_conversion_index       : tdac_conversion_index_t := (6,7,8,9,10,11,385, 383, 381, 379, 377, 375, 373, 371, 369, 367, 365, 363, 361, 359, 357, 355, 353, 351, 349, 347, 345, 343, 341, 339, 337, 335, 333, 331, 329, 327, 325, 323, 321, 319, 317, 315, 313, 311, 309, 307, 305, 303, 301, 299, 297, 295, 293, 291, 289, 287, 285, 283, 281, 279, 277, 275, 273, 271, 269, 267, 265, 263, 261, 259, 257, 386, 384, 382, 380, 378, 376, 374, 372, 370, 368, 366, 364, 362, 360, 358, 356, 354, 352, 350, 348, 346, 344, 342, 340, 338, 336, 334, 332, 330, 328, 326, 324, 322, 320, 318, 316, 314, 312, 310, 308, 306, 304, 302, 300, 298, 296, 294, 292, 290, 288, 286, 284, 282, 280, 278, 276, 274, 272, 270, 268, 266, 264, 262, 260, 258, 256, 129, 127, 125, 123, 121, 119, 117, 115, 113, 111, 109, 107, 105, 103, 101, 99, 97, 95, 93, 91, 89, 87, 85, 83, 81, 79, 77, 75, 73, 71, 69, 67, 65, 63, 61, 59, 57, 55, 53, 51, 49, 47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25, 23, 21, 19, 17, 15, 13, 130, 128, 126, 124, 122, 120, 118, 116, 114, 112, 110, 108, 106, 104, 102, 100, 98, 96, 94, 92, 90, 88, 86, 84, 82, 80, 78, 76, 74, 72, 70, 68, 66, 64, 62, 60, 58, 56, 54, 52, 50, 48, 46, 44, 42, 40, 38, 36, 34, 32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 0,1,2,3,4,5, 511, 509, 507, 505, 503, 501, 499, 497, 495, 493, 491, 489, 487, 485, 483, 481, 479, 477, 475, 473, 471, 469, 467, 465, 463, 461, 459, 457, 455, 453, 451, 449, 447, 445, 443, 441, 439, 437, 435, 433, 431, 429, 427, 425, 423, 421, 419, 417, 415, 413, 411, 409, 407, 405, 403, 401, 399, 397, 395, 393, 391, 389, 387, 510, 508, 506, 504, 502, 500, 498, 496, 494, 492, 490, 488, 486, 484, 482, 480, 478, 476, 474, 472, 470, 468, 466, 464, 462, 460, 458, 456, 454, 452, 450, 448, 446, 444, 442, 440, 438, 436, 434, 432, 430, 428, 426, 424, 422, 420, 418, 416, 414, 412, 410, 408, 406, 404, 402, 400, 398, 396, 394, 392, 390, 388, 255, 253, 251, 249, 247, 245, 243, 241, 239, 237, 235, 233, 231, 229, 227, 225, 223, 221, 219, 217, 215, 213, 211, 209, 207, 205, 203, 201, 199, 197, 195, 193, 191, 189, 187, 185, 183, 181, 179, 177, 175, 173, 171, 169, 167, 165, 163, 161, 159, 157, 155, 153, 151, 149, 147, 145, 143, 141, 139, 137, 135, 133, 131, 254, 252, 250, 248, 246, 244, 242, 240, 238, 236, 234, 232, 230, 228, 226, 224, 222, 220, 218, 216, 214, 212, 210, 208, 206, 204, 202, 200, 198, 196, 194, 192, 190, 188, 186, 184, 182, 180, 178, 176, 174, 172, 170, 168, 166, 164, 162, 160, 158, 156, 154, 152, 150, 148, 146, 144, 142, 140, 138, 136, 134, 132);
    constant tdac_conversion_index_mp11  : tdac_conversion_index_t := (6,7,8,9,10,11,12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 0,1,2,3,4,5, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399, 400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415, 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427, 428, 429, 430, 431, 432, 433, 434, 435, 436, 437, 438, 439, 440, 441, 442, 443, 444, 445, 446, 447, 448, 449, 450, 451, 452, 453, 454, 455, 456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 466, 467, 468, 469, 470, 471, 472, 473, 474, 475, 476, 477, 478, 479, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 495, 496, 497, 498, 499, 500, 501, 502, 503, 504, 505, 506, 507, 508, 509, 510, 511);
    --(251,252,253,254,255,506,507,508,509,510,511, 315, 256, 316, 257, 317, 258, 318, 259, 319, 260, 320, 261, 321, 262, 322, 263, 323, 264, 324, 265, 325, 266, 326, 267, 327, 268, 328, 269, 329, 270, 330, 271, 331, 272, 332, 273, 333, 274, 334, 275, 335, 276, 336, 277, 337, 278, 338, 279, 339, 280, 340, 281, 341, 282, 342, 283, 343, 284, 344, 285, 345, 286, 346, 287, 347, 288, 348, 289, 349, 290, 350, 291, 351, 292, 352, 293, 353, 294, 354, 295, 355, 296, 356, 297, 357, 298, 358, 299, 359, 300, 360, 301, 361, 302, 362, 303, 363, 304, 364, 305, 365, 306, 366, 307, 367, 308, 368, 309, 369, 310, 370, 311, 371, 312, 372, 313, 373, 314, 374, 315, 62, 0, 63, 1, 64, 2, 65, 3, 66, 4, 67, 5, 68, 6, 69, 7, 70, 8, 71, 9, 72, 10, 73, 11, 74, 12, 75, 13, 76, 14, 77, 15, 78, 16, 79, 17, 80, 18, 81, 19, 82, 20, 83, 21, 84, 22, 85, 23, 86, 24, 87, 25, 88, 26, 89, 27, 90, 28, 91, 29, 92, 30, 93, 31, 94, 32, 95, 33, 96, 34, 97, 35, 98, 36, 99, 37, 100, 38, 101, 39, 102, 40, 103, 41, 104, 42, 105, 43, 106, 44, 107, 45, 108, 46, 109, 47, 110, 48, 111, 49, 112, 50, 113, 51, 114, 52, 115, 53, 116, 54, 117, 55, 118, 56, 119, 57, 120, 58, 121, 59, 122, 60, 123, 61, 124, 375, 441, 376, 442, 377, 443, 378, 444, 379, 445, 380, 446, 381, 447, 382, 448, 383, 449, 384, 450, 385, 451, 386, 452, 387, 453, 388, 454, 389, 455, 390, 456, 391, 457, 392, 458, 393, 459, 394, 460, 395, 461, 396, 462, 397, 463, 398, 464, 399, 465, 400, 466, 401, 467, 402, 468, 403, 469, 404, 470, 405, 471, 406, 472, 407, 473, 408, 474, 409, 475, 410, 476, 411, 477, 412, 478, 413, 479, 414, 480, 415, 481, 416, 482, 417, 483, 418, 484, 419, 485, 420, 486, 421, 487, 422, 488, 423, 489, 424, 490, 425, 491, 426, 492, 427, 493, 428, 494, 429, 495, 430, 496, 431, 497, 432, 498, 433, 499, 434, 500, 435, 501, 436, 502, 437, 503, 438, 504, 439, 505, 440, 187, 125, 188, 126, 189, 127, 190, 128, 191, 129, 192, 130, 193, 131, 194, 132, 195, 133, 196, 134, 197, 135, 198, 136, 199, 137, 200, 138, 201, 139, 202, 140, 203, 141, 204, 142, 205, 143, 206, 144, 207, 145, 208, 146, 209, 147, 210, 148, 211, 149, 212, 150, 213, 151, 214, 152, 215, 153, 216, 154, 217, 155, 218, 156, 219, 157, 220, 158, 221, 159, 222, 160, 223, 161, 224, 162, 225, 163, 226, 164, 227, 165, 228, 166, 229, 167, 230, 168, 231, 169, 232, 170, 233, 171, 234, 172, 235, 173, 236, 174, 237, 175, 238, 176, 239, 177, 240, 178, 241, 179, 242, 180, 243, 181, 244, 182, 245, 183, 246, 184, 247, 185, 248, 186, 249);

    type mp_conf_storage_interface_in is record
        spi_read        :   std_logic_vector(3 downto 0);
        mu3e_read       :   std_logic_vector(3 downto 0);
    end record;

    type mp_conf_storage_interface_out is record
        rdy             :   std_logic_vector(3 downto 0);
        spi_data        :   std_logic_vector(3 downto 0);
        conf            :   std_logic_vector(53 downto 0);
        vdac            :   std_logic_vector(53 downto 0);
        bias            :   std_logic_vector(53 downto 0);
        tdac            :   std_logic_vector(53 downto 0);
    end record;

    type mp_ctrl_external_command_t is record
        command         :   std_logic_vector(63 downto 0);
        trigger         :   std_logic; -- any change will trigger sending of the command
    end record;

    type mp_ctrl_external_command_array_t is array( natural range <> ) of mp_ctrl_external_command_t;
    constant MP_CTRL_EXT_CMD_DEFAULT : mp_ctrl_external_command_t := ( -- i need a default for the simulation
        command => X"0000000000000000",
        trigger => '0'
    );

    type mp_conf_array_in  is array( natural range <> ) of mp_conf_storage_interface_in;
    type mp_conf_array_out is array( natural range <> ) of mp_conf_storage_interface_out;


    type mp_link_order_t    is array (35 downto 0) of integer;
                                               -- 35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
    constant MP_LINK_ORDER  : mp_link_order_t := (33,31,29,35,32,28,34,30,27,26,25,20,24,23,21,22,19,18,15,11,9,17,13,10,16,14,12,5,3,2,6,4,1,8,7,0);
    constant MP_LINK_ORDER_TELESCOPE : mp_link_order_t := (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,35,26,30,34,21,25,23,24,22,33,32,31,29,28,27,20,19,18);
    constant MP_LINK_ORDER_PROBE_CARD : mp_link_order_t := (10,13,14,17,4,5,6,7,8,9,0,11,12,1,2,15,16,3,35,26,30,34,21,25,23,24,22,33,32,31,29,28,27,20,19,18);
    -- Quad Module with two trigger S1 and S2:
    -- Chip 1 A|B|C | Chip 2 A|B|C
    --        0 1 2          3 4 5
    -- ---------------------------
    -- Chip 3 A|B|C | Chip 4 A|B|C
    --        6 7 8         9 10 11
    -- Signals Firmware                                         D9 D8 D7 D6 D5 D4 D3 D2 D1 C9 C8 C7 C6 C5 C4 C3 C2 C1 B9 B8 B7 B6 B5 B4 B3 B2 B1 A9 A8 A7 A6 A5 A4 A3 A2 A1
    -- Links Firmware when 1-to-1 mapping                       35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
    -- Link / Chip (start at 1) numbering on QUAD               C6 XX A5 A6 B5 S2 C5 B6 XX B7 A7 A8 C8 XX B8 C7 XX XX A2 S1 B1 XX C2 XX C1 B2 A1 XX XX A4 B3 C4 A3 C3 B4 XX
    -- Links / Chips when 1-to-1 mapping                        XX XX XX XX XX XX XX XX XX XX XX XX C8 B8 A8 C7 B7 A7 C6 B6 A6 C5 B5 A5 C4 B4 A4 C3 B3 A3 C2 B2 A2 C1 B1 A1
    -- Reordering to fit QUAD mapping                           XX XX XX XX XX XX XX XX XX XX XX XX C6 C4 C7 C3 C9 C8 D9 D2 D6 D3 D5 D7 A5 A2 A7 A3 A6 A4 B5 B2 B9 B3 B7 B1 
    --constant MP_LINK_ORDER_QUAD_MODULE : mp_link_order_t := (    0,10,11,12,14,16,18,19,22,27,30,34,23,21,24,20,26,25,35,28,32,29,31,33, 4, 1, 6, 2, 5, 3,13, 7,17, 8,15, 9);
    constant MP_LINK_ORDER_QUAD_MODULE : mp_link_order_t := (    0, 7, 8,12,14,16,18,19,22,27,30,34,23,21,24,20,26,25,35,28,32,29,31,33, 4, 1, 6, 2, 5, 3,13,10,17,11,15, 9);
    constant NO_REORDER  : mp_link_order_t := (35,34,33,32,31,30,29,28,27,26,25,24,23,22,21,20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0);

    -- following mp links are inverted on DAB integration run version:
        -- 0,19,30,35
    -- more links are inverted on the FEB:
        -- 12,14,16,27,34,35
    -- additional inverts: (we dont know from where, list is incomplete):
        -- 11,15,32,28,  2,3,5,24,23,21,20,25,26,28,32,29,31,10,13,17
    -- additional inverts found in the integration run cage before craning:(with this the list is hopefully complete)
        -- 0,7,8,18,19,22,9,30,33,1,4,6

    --                                                                         data_d   data_c   data_b   data_a
    --                                                                      987654321987654321987654321987654321
    -- constant MP_LINK_INVERT             : std_logic_vector(35 downto 0) := "011110111111111101111111111111111110";
    constant MP_LINK_INVERT             : std_logic_vector(35 downto 0) := "011110110110100100111111111101111110"; --Trial 3  INVERTED LINKS: 1 (7), 20 (22), 21 (21), 27(27)
    constant MP_LINK_INVERT_QUAD        : std_logic_vector(35 downto 0) := "100001000000000010000000000000000001";
    constant MP_LINK_INVERT_TELESCOPE   : std_logic_vector(35 downto 0) := "001110011111111111111111111111111110";
    constant MP_LINK_INVERT_PROBE_CARD  : std_logic_vector(35 downto 0) := "111110100111111101111111111111111110";

    -- there is a maximum of 15 different chips that could be connected to the same mupix slowcontrol line
    -- (because we have 4 bits as hardwired address and 0xF is reserved for broadcast)
    -- we need to talk to these addresses accordingly depending on how the solder connections are done on the mupix
    -- these constants list now the addresses in the order that we want them.
    -- The address on the right will be the lowest chip number on each ladder, address on the left is the highest
    -- if your hardware does only have N mupixes connected to one slowcontrol line then only the N entries on the right are relevant.
    -- you can fill the other entries (above g_CHIPS_PER_LANE-1) with random garbage ... they are just there because we need the same length for all constants
    type mp_ladder_addr_array_t is array (14 downto 0) of std_logic_vector(3 downto 0);
    -- TODO: insert the correct numbers for all of them (TODO: agree on numbers for all of them first)

    constant MP_LADDER_ADDR_ARRAY_US_INNER  : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","1001","0011","0010","0001");
    constant MP_LADDER_ADDR_ARRAY_US_OUTER  : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","1001","1000","0111","0110","0101","0100","0011","0010","0001");
    constant MP_LADDER_ADDR_ARRAY_DS_INNER  : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","1001","0110","0101","0100");
    constant MP_LADDER_ADDR_ARRAY_DS_OUTER  : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","1001","1000","0111","0110","0101","0100","0011","0010","0001");
    constant MP_LADDER_ADDR_ARRAY_TELESCOPE : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","1001","1000","0100","1111"); -- "1111" at the end because i do not care right now and just want this to work and we will never seriously use this again for a measurement
    constant MP_LADDER_ADDR_ARRAY_QUAD      : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","1001","0110","0001","0000");
    constant MP_LADDER_ADDR_ARRAY_PROBECARD : mp_ladder_addr_array_t := ("0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","0001","1001","0011","0010","0001");

    type ts_array_t                 is array (natural range <>) of std_logic_vector(10 downto 0);
    type row_array_t                is array (natural range <>) of std_logic_vector(7 downto 0);
    type col_array_t                is array (natural range <>) of std_logic_vector(7 downto 0);
    type ch_ID_array_t              is array (natural range <>) of std_logic_vector(5 downto 0);
    type tot_array_t                is array (natural range <>) of std_logic_vector(5 downto 0);

    -- Action Flags for the mupix mu3e slowcontrol (taken from slowControlStatemachine.v in mupix source code)
    constant COMMAND_WRITE_BIAS     : std_logic_vector(5 downto 0) := "111000";
    constant COMMAND_WRITE_CONF     : std_logic_vector(5 downto 0) := "110100";
    constant COMMAND_WRITE_VDAC     : std_logic_vector(5 downto 0) := "110010";
    constant COMMAND_WRITE_TDAC     : std_logic_vector(5 downto 0) := "101010";
    constant COMMAND_WRITE_COL      : std_logic_vector(5 downto 0) := "110001";
    constant COMMAND_SHIFT1         : std_logic_vector(5 downto 0) := "111101";
    constant COMMAND_LOAD_BIAS      : std_logic_vector(5 downto 0) := "000111";
    constant COMMAND_LOAD_CONF      : std_logic_vector(5 downto 0) := "001011";
    constant COMMAND_LOAD_VDAC      : std_logic_vector(5 downto 0) := "010011";
    constant COMMAND_LOAD_TDAC      : std_logic_vector(5 downto 0) := "010101";
    constant COMMAND_LOAD_COL       : std_logic_vector(5 downto 0) := "100011";

end package;

