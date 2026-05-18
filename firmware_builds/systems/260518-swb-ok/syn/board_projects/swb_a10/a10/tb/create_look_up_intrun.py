
output = ""
for i in range(10):
    for j in range(12):
        lookup = str(bin(i*12 + j)).split("b")[1]
        while len(lookup) < 7:
            lookup = "0" + lookup
        output += "\"" + lookup + "\" when i_fpgaID = x\"" + str(hex(i)).split("x")[1] + "\" and i_chipID = x\"" + str(hex(j)).split("x")[1] + "\" else \n"

print(output)
