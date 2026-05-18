import midas.file_reader

mfile = midas.file_reader.MidasFile('/home/mu3e/online/online/run00086.mid')

list_feb0 = []
list_feb2 = []

# [AK] TODO: use f''' string
def get_start(i):
    start_str = "library ieee;\n"
    start_str += "use ieee.numeric_std.all;\n"
    start_str += "use ieee.std_logic_1164.all;\n"
    start_str += "entity f" + str(i) + "_sim is\n"
    start_str += "port(\n"
    start_str += "data_feb" + str(i) + " : out std_logic_vector(31 downto 0);\n"
    start_str += "datak_feb" + str(i) + " : out std_logic_vector(3 downto 0);\n"
    start_str += "clk : in std_logic;\n"
    start_str += "reset_n : in std_logic--;\n"
    start_str += ");\n"
    start_str += "end entity;\n"
    start_str += "architecture behav of f" + str(i) + "_sim is\n"
    start_str += "begin\n"
    start_str += "process\n"
    start_str += "begin\n"
    start_str += "if (reset_n = '0') then\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "else\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "wait until rising_edge(clk);\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "wait until rising_edge(clk);\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "wait until rising_edge(clk);\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "wait until rising_edge(clk);\n"
    start_str += "data_feb" + str(i) + " <= x\"000000bc\";\n"
    start_str += "datak_feb" + str(i) + " <= \"0001\";\n"
    start_str += "wait until rising_edge(clk);\n"
    return start_str

end_str = "end if;\n"
end_str += "end process;\n"
end_str += "end architecture;\n"

def to_vhdl(d, i):

    value_str = str(hex(d)).split('x')[1]

    while len(list(value_str)) != 8:
        value_str = "0" + value_str

    outfile = 'data_feb' + i + ' <= x\"' + value_str + '\";\n'
    if d == 0xe8feb0bc or d == 0xe8feb2bc or d == 0xFC00009C:
        outfile += 'datak_feb' + i + ' <= "0001";\n'
    else:
        outfile += 'datak_feb' + i + ' <= "0000";\n'
    outfile += 'wait until rising_edge(clk);\n'
    return outfile

counter = 0

for event in mfile:
    bank_names = ", ".join(b.name for b in event.banks.values())
    if counter == 100: break
    for bank_name, bank in event.banks.items():
        if 'PCD1' == bank_name:
            counter += 1
            for d in bank.data:
                if d == 0xAFFEAFFE: continue
                if bank.data[0] == 0xe8feb0bc:
                    list_feb0.append(to_vhdl(d, "0"))
                else:
                    list_feb2.append(to_vhdl(d, "1"))
            if counter == 100: break

file=open('f0_sim.vhd','w')
file.writelines([get_start(0)])
for items in list_feb0:
    file.writelines([items])
file.writelines([end_str])
file.close()

file=open('f1_sim.vhd','w')
file.writelines([get_start(1)])
for items in list_feb2:
    file.writelines([items])
file.writelines([end_str])
file.close()
