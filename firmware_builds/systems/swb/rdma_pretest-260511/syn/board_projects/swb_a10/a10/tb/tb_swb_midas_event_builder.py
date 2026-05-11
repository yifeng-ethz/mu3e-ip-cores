import pandas as pd
import numpy as np
import sys

print(f"Arguments count: {len(sys.argv)}")

if len(sys.argv) == 1:
    path = ".cache/memory_content.txt"
    idx = 0
    header = None
else:
    path = sys.argv[1]
    idx = "data"
    header = 0

df = pd.read_csv(path, sep="\t", header=header)
# print(df[:63].values)
data = np.array([hex(int(v, 16)) for v in df[idx].values])

class midas_event:

    def __init__(self, data, start):

        self.eventid = data[start:][0]
        self.serial_number = data[start:][1]
        self.time = data[start:][2]
        self.event_size = data[start:][3]
        self.all_bank_size = data[start:][4]
        self.flags = data[start:][5]

        self.start = start
        self.end = int(start + 4 + int(self.event_size, 16)/4)
        self.bank_data = data[start+4:self.end]

start = 0
cnt = 0
list_e = []
while start < len(data):
    cnt+=1
    e = midas_event(data, start)
    event_data = data[e.start:e.end]
    if e.eventid != '0x1':

        event_data_last = data[list_e[-1].start:list_e[-1].end]

        print("data[start-1]: {}".format(data[start-1]))
        print("list_e[-1].event_size: {}".format(int(list_e[-1].event_size, 16)/4))
        print(event_data_last, len(event_data_last), list_e[-1].end, list_e[-1].start, cnt)
        print(event_data, len(event_data), e.end, e.start, cnt)
        break
    # print(event_data, len(event_data), e.end, e.start, cnt)
    # print("e.event_size: {}".format(int(e.event_size, 16)/4))
    list_e.append(e)
    start=e.end

print("Num Events: {}".format(cnt))
