#! /bin/sh
#
# A script to attempt a software unplug & plug of a USB blaster. Can be used
# remotely to try and reset when jtagconfig hangs. You may need to do this more
# than once, although this works for me every time:
#
#    bash$ ./resetBlaster.sh && jtagconfig
#    <output from this script>
#    No JTAG hardware available
#    bash$ jtagconfig
#    <successful output>
#
# I.e. the `&& jtagconfig` fails, but something about the immediate query prompts
# jtagconfig into working properly after that.
#
# mark.grimes@bristol.ac.uk
# 2025-01-07
#

SEARCH_STRING="USB-Blaster" # How we think the USB blaster will be called in lsusb.py

# If the user specified a port number on the command line, use that.
if [ $# -gt 0 ]; then
    PORT_NUMBER=$1
    echo "Using port \"$PORT_NUMBER\" specified on the command line"
fi

# If the user didn't specify a port, try and figure it out.
if [ -z "$PORT_NUMBER" ]; then
    PORT_NUMBER=`lsusb.py | grep "$SEARCH_STRING" | awk '{print $1}'`
    NUMBER_OF_BLASTERS=`echo "$PORT_NUMBER" | wc -l`

    if [ -z "$PORT_NUMBER" ]; then
        echo "Couldn't find any \"$SEARCH_STRING\" devices. Find the port of your blaster with "lsusb.py" and specify on the command line directly." >&2
        exit
    elif [ $NUMBER_OF_BLASTERS -ne 1 ]; then
        echo "Found $NUMBER_OF_BLASTERS devices called \"$SEARCH_STRING\". We can't choose between them so you will need to specify the port directly." >&2
        exit
    fi

    echo "Using port \"$PORT_NUMBER\" from the entries in lsusb.py"
fi

PARENT_PORT_NUMBER=`echo $PORT_NUMBER | awk -F "." '{print $1}'`
echo "Attempting to remove the USB device at port "$PORT_NUMBER", and then rebind all devices on parent port "$PARENT_PORT_NUMBER". You will need to enter your sudo password."

if [ -d "/sys/bus/usb/devices/$PORT_NUMBER" ]; then
    # We need the `tee` so that the writes are done with sudo privileges
    echo "1" | sudo tee "/sys/bus/usb/devices/$PORT_NUMBER/remove" > /dev/null
    sleep 1
    echo "$PARENT_PORT_NUMBER" | sudo tee "/sys/bus/usb/drivers/usb/unbind" > /dev/null
    sleep 1
    echo "$PARENT_PORT_NUMBER" | sudo tee "/sys/bus/usb/drivers/usb/bind" > /dev/null
else
    echo "Port \"$PORT_NUMBER\"' does not appear to be a valid port" >&2
fi
