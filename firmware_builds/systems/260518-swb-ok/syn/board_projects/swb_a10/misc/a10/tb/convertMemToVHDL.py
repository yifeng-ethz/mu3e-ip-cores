import pandas as pd
import matplotlib.pyplot as plt
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("-f", "--file", help="get path to memory file", type=str)
parser.add_argument("-o", "--output", help="path for vhd file", type=str)
parser.add_argument("-n", "--nrows", help="num rows", type=int)

args = parser.parse_args()

if args.nrows == -1:
    data = pd.read_csv(args.file, sep='\t', header=None)[1].values
else:
    data = pd.read_csv(args.file, sep='\t', header=None, nrows=args.nrows)[1].values
print(data)

outData = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[]}
febDict = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[]}
febCnt = {0:0,1:0,2:0,3:0,4:0,5:0,6:0,7:0,8:0,9:0}
febCntHits = {0:0,1:0,2:0,3:0,4:0,5:0,6:0,7:0,8:0,9:0}
febTS = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[]}
febTrailerCnt = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[]}
febHeaderCnt = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[]}
headerList=["E80000BC","E80001BC","E80002BC","E80003BC","E80004BC","E81005BC","E81006BC","E81007BC","E81008BC","E81009BC","E81000BC"]

last_d = 0
curFEB = -999
for idx, d in enumerate(data):
    if d == "FFFFFFFF" and data[idx+1] == "FFFFFFFF": break
    if curFEB != -999:
        curEvent.append(hex(int(d, 16)))
    if d == "FC00019C" or d == "FC00009C":
        febTrailerCnt[curFEB].append(hex(((int(data[idx+1], 16) >> 8) & 0xFFFF)-1))
        febDict[curFEB].append(curEvent)
        curFEB = -999

    if last_d == '00000000' and d in headerList:
        curFEB = int(d.split('E8')[1].split('BC')[0].split('0')[-1])
        curEvent = [hex(int(d, 16))]
        febHeaderCnt[curFEB].append(int(data[idx+2], 16) & 0xFFFF)
        febTS[curFEB].append((int(data[idx+1], 16) << 5) | (int(data[idx+2], 16) >> 27))
    last_d = d

for feb in febDict:
    if len(febDict[feb]) > 0:
        startEventCnt = int(febDict[feb][0][2], 16) & 0xFFFF
        trailerEventCnt = 0

    for idx_e, event in enumerate(febDict[feb]):
#print("Trailer Ecnt", febTrailerCnt[feb][idx_e], "Start Cnt", hex(startEventCnt))
        febCnt[feb] += 1
        if not (event[0] == hex(int("E8100" + str(feb) + "BC", 16)) or event[0] == hex(int("E8000" + str(feb) + "BC", 16))):
            print(event[0])
            print(f"FebCnt: {febCnt[feb]} of FEB: {feb} had no header")
        curData = [event[0], event[1], event[2]]
        haveWrongSub = False
        if str(event[3]) != hex(0xfe00000):
            print(f"FebCnt: {febCnt[feb]} of FEB: {feb} did not start with subheader")
        startSubheader = 0
        for idx, hit in enumerate(event[3:]):
            curData.append(hit)
            if hex((int(hit, 16) >> 21) & 0x7F) == hex(0x7F):
                curSubheader = ((int(hit, 16) >> 28) << 5) | ((int(hit, 16) >> 16) & 0x1F)
                if curSubheader != startSubheader and not haveWrongSub:
                    print(f"FebCnt: {febCnt[feb]} of FEB: {feb} Skip Subheader subheader {curSubheader} {startSubheader}")
                    for i in range(-50, 20):
                        if 3+i+idx >= len(event):
                            continue
                        print(event[3+i+idx], "chipID: ", (int(event[3+i+idx], 16) >> 21) & 0x7F, 3+i+idx)
                        haveWrongSub = True
                startSubheader += 1
            else:
                if hit != hex(0xFC00019C) or hit != hex(0xFC00009C): febCntHits[feb] += 1
        if haveWrongSub and feb == 5: outData[feb] = curData
        if feb != 5: outData[feb] = curData
        if startSubheader != 128:
            print(f"FebCnt: {febCnt[feb]} of FEB: {feb} wrong subheader ending {startSubheader}")
#if (int(event[2], 16) & 0xFFFF) != startEventCnt: print("We miss an event")

        startEventCnt += 1

for i in range(10):
    print("Events: " + str(len(febTS[i])) + " " + str(len(febDict[i])), "Hits: " + str(febCntHits[i]))

outData[6][1] = outData[5][1]
outData[6][2] = outData[5][2]
print(outData)

outTxt = """\
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.mudaq.all;

entity a10_real_data_gen is
port (
    o_data0             : out work.mu3e.link32_t;
    o_data1             : out work.mu3e.link32_t;

    i_enable            : in  std_logic;
    i_slow_down         : in  std_logic_vector(31 downto 0);

    i_reset_n           : in  std_logic;
    i_clk               : in  std_logic--;
);
end entity;

architecture rtl of a10_real_data_gen is

    signal waiting : std_logic;
    signal wait_counter, state_counter : std_logic_vector(31 downto 0);

begin

    -- slow down process
    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        waiting         <= '0';
        wait_counter    <= (others => '0');
    elsif rising_edge(i_clk) then
        if ( wait_counter >= i_slow_down ) then
            wait_counter    <= (others => '0');
            waiting         <= '0';
        else
            wait_counter    <= wait_counter + '1';
            waiting         <= '1';
        end if;
    end if;
    end process;

    process(i_clk, i_reset_n)
    begin
    if ( i_reset_n = '0' ) then
        o_data0              <= work.mu3e.LINK32_ZERO;
        o_data1              <= work.mu3e.LINK32_ZERO;
        state_counter        <= (others => '0');
        --
    elsif rising_edge(i_clk) then
        o_data0  <= work.mu3e.LINK32_IDLE;
        o_data1  <= work.mu3e.LINK32_IDLE;
        if ( i_enable = '1' and waiting = '0' ) then
            state_counter <= state_counter + '1';
"""

for idx, v in enumerate(outData[5]):
    state_counter = idx + 2
    if idx < len(outData[6]):
        data0 = str(v).split("x")[-1]
        data1 = str(outData[6][idx]).split("x")[-1]
        if ((int(v,16) >> 21) & 0x7F) == 0x7F:
            data0 = str(hex((0x3f << 26) | (((((int(v,16) >> 28) & 0x3) << 5) | (((int(v,16) >> 16) & 0x1F))) << 16))).split("x")[-1]
        if ((int(outData[6][idx],16) >> 21) & 0x7F) == 0x7F:
            data1 = str(hex((0x3f << 26) | (((((int(outData[6][idx],16) >> 28) & 0x3) << 5) | (((int(outData[6][idx],16) >> 16) & 0x1F))) << 16))).split("x")[-1]

        if idx == 0:
            isHeader = 1

            datak0 = "0001"
            datak1 = "0001"
        else:
            isHeader = 0
            datak0 = "0000"
            datak1 = "0000"
        if idx == len(outData[6])-1:
            isTrailerOne = 1
            data1 = "0000009C"
            datak1 = "0001"
        else:
            isTrailerOne = 0
        data0 = '{:08X}'.format(int(data0, 16) & ((1 << 32) - 1))
        data1 = '{:08X}'.format(int(data1, 16) & ((1 << 32) - 1))
        outTxt += f"""\
            if ( to_integer(unsigned(state_counter)) = {state_counter} ) then
                o_data0.data <= x"{data0}";
                o_data1.data <= x"{data1}";
                o_data0.datak <= "{datak0}";
                o_data1.datak <= "{datak1}";
                o_data0.sop <= '{isHeader}';
                o_data1.sop <= '{isHeader}';
                o_data1.eop <= '{isTrailerOne}';
            end if;
"""
    else:
        data0 = str(v).split("x")[-1]
        if ((int(v,16) >> 21) & 0x7F) == 0x7F:
            data0 = str(hex((0x3f << 26) | (((((int(v,16) >> 28) & 0x3) << 5) | (((int(v,16) >> 16) & 0x1F))) << 16))).split("x")[-1]
        if idx == len(outData[5])-1:
            isTrailerZero = 1
            datak0 = "0001"
            data0 = "0000009C"
        else:
            isTrailerZero = 0
            datak0 = "0000"
        data0 = '{:08X}'.format(int(data0, 16) & ((1 << 32) - 1))
        outTxt += f"""\
            if ( to_integer(unsigned(state_counter)) = {state_counter} ) then
                o_data0.data <= x"{data0}";
                o_data0.datak <= "{datak0}";
                o_data0.eop <= '{isTrailerZero}';
            end if;
"""
lenData5 = len(outData[5])+5
outTxt += f"""\
    if ( to_integer(unsigned(state_counter)) = {lenData5} ) then
            state_counter <= (others => '0');
    end if;
    end if;
    end if;
    end process;

end architecture;
"""
with open(f'{args.output}/a10_real_data_gen.vhd', 'w') as file:
    file.write(outTxt)
print(outTxt)

plt.plot(febTS[5], label="FEB5")
plt.plot(febTS[6], label="FEB6")
plt.plot(febTS[7], label="FEB7")
plt.plot(febTS[8], label="FEB8")
plt.plot(febTS[9], label="FEB9")
plt.xlabel("Events")
plt.ylabel("HeadTS")
plt.legend()
plt.savefig("headerTS.pdf")
plt.close()

plt.plot(febHeaderCnt[5], label="H_FEB5")
plt.plot(febHeaderCnt[6], label="H_FEB6")
plt.plot(febHeaderCnt[7], label="H_FEB7")
plt.plot(febHeaderCnt[8], label="H_FEB8")
plt.plot(febHeaderCnt[9], label="H_FEB9")
plt.xlabel("Events")
plt.ylabel("HeadCnt")
plt.legend()
plt.savefig("headerCnt.pdf")
plt.close()

lastj = 0
feb5 = []
feb6 = []
for idx, v in enumerate(febHeaderCnt[5]):
    for jdx, u in enumerate(febHeaderCnt[6][lastj:]):
        if v==u:
            #print(idx, jdx, v, u, febTS[5][idx], febTS[6][lastj])
            lastj = idx + jdx
            feb5.append(v)
            feb6.append(v)
            break
plt.plot(feb5, label="FEB5")
plt.plot(feb6, label="FEB6", alpha=0.3)
plt.xlabel("Events")
plt.ylabel("HeadTS")
plt.legend()
plt.savefig("headerTS2.pdf")
