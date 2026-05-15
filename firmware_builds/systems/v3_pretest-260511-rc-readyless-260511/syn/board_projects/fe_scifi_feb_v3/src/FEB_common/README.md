# FEB common Firmware:

This directory should be used for all frontend board firmware which is not specific for pixel-feb, tile-feb or fibre-feb

Contents:

state_controller:

    - decodes the "reset" input from GENESIS and uses it to provide the following outputs ...
        - the run state (idle, run_prep, sync, running, terminating, reset, link_test, sync_test, out_of_DAQ)
        - the run number
        - 16 reset lines

    - possible transitions:
        - idle  -> run_prep    -> sync -> running -> terminating -> idle
        - all   -> reset       -> idle
        - idle  -> X_test      -> idle
        - all   -> out_of_DAQ  -> idle

    - inputs:
        - reset from transceiver connected to GENESIS (clock and reset control board)
        - terminated signal from data_merger (permission to do the terminating -> idle transition)

data_merger:

    - we only have 1 optical connection per frontend board. With this connection we need to transmitt:
        - data from detectors
        - control data (temperatures, pixel dacs, ...)
        - run control signals (run_prep_acknowledge, run end, ...)
        - comma words for alignment of the

    - the data merger ...
        - decides what is send next (detector data or control data)
        - in general: sends packets as specified in the spec book
        - adds the preamble and trail to each packet as specified in the spec book
        - adds all comma words, fpga_ID, packet_type as specified in the spec book
        - adds run control signals (run_prep_acknowledge, run end, ...)
        - fills gaps with k285
        - gives permisson to the state controller to do the terminating -> idle transition when the end of a data packet is reached
        - provides a override (on request) directly to the optical link for BERTs & Co (only in state *_test from state controller)

    - inputs:
        - run state from state controller (everything in here is heavily based on run state)
        - FPGA id that should be added to all packets as specified in the spec book (set by 16 jumpers on the board)
        - type of Frontendboard (pixel, tiles, fibres)
        - connection to a data fifo and control fifo
        - data_priority input 0: slowcontrol packets have priority, 1: data packets have priority in run state "running"
        - override inputs (ToDo connected to something that does BERTs etc)

mergerfifo: This is the point where we leave FEB_common - land !!!!!

    - the data merger reads from 2 of these fifos

    - HOW TO WRITE TO THIS FIFO:

    - width: 36 bit

        - 31 downto 0: whatever you want (for data merger this is payload, see spec book for specifications for pixel, control, tiles, fibres)
        - 35 downto 32: ( 0010: this is the begin of something  0011: this is the end of something, 0000: else) !!!!!!!!!!!
            - This tells the data merger what should be used to build a spec book packet
            - do not start to write something into this fifo without 0010.
            - gaps are fine. It is not necessary to write in a single block, the data merger will fill gaps with word alignment
            - DO NOT STOP your packet without 35 dowto 32 = 0011 !!!!! you will block the link !!
        - example write:
            - 0010 + 31 downto 0            -> 31 downto 0 will be transmitted after the preamble
            - 0000 + 31 downto 0            -> 31 downto 0 will be transmitted
            - ...
            - 0011 + 31 downto 0            -> 31 downto 0 will NOT be transmitted (to be specified) !!!! and replaced by the spec book trailer
            - the next write to this fifo should start with 0010 again
