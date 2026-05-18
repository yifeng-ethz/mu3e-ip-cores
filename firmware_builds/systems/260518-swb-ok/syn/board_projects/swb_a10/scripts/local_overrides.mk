#
# Local override include for a10_board.
# Keep this file included after util/quartus/makefile.mk so helper scripts in
# this directory win $(call find_file,...) lookups.
#

# Default to the Link02 SWB<->FEB slow-control capture profile for flash/SC
# bring-up. Override at invocation time if needed.
SIGNALTAP_FILE ?= top_sc_link2_rx_only.stp
