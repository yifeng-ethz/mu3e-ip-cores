/*
 * Run-control command tool for SWB -> FEB reset-link injection.
 *
 * Writes RESET_LINK_CTL_REGISTER_W with (feb << 29 | cmd) and then clears it,
 * pulsing a10_reset_link so the command byte transmits on the FEB transceiver
 * run-control stream. RUN_PREPARE additionally needs RESET_LINK_RUN_NUMBER
 * set first: the FSM in a10_reset_link emits the 32-bit run number on the
 * wire right after the RUN_PREPARE byte (a10_reset_link.vhd:92-111).
 *
 * Style goal:
 *   Mirror sc_tool.cpp -- flat, explicit, small helpers, visible state and
 *   diagnostics. The tool never retries silently; one press, one report.
 *
 * Reset-link opcodes are defined in common/firmware/registers/mudaq.vhd as
 * RESET_LINK_* constants (0x10..0x40). This mirrors the SWB side of the Mu3e
 * run-control protocol (Mu3eSpecBook section 4.6).
 */

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include "mudaq_device.h"

using std::string;
using std::vector;

namespace {

// SWB register layout: the SWB is programmed from online_sc (see CLAUDE.md
// "Switching PC Firmware Source of Truth"), not online_dpv2. The two repos
// have divergent a10_pcie_registers.vhd. libmudaq is generated from
// online_dpv2 and therefore has the wrong addresses for the reset-link
// block, so we pin the register indices explicitly to match the SWB
// bitstream currently loaded on the A10 DE5 board.
//
// Source: online_sc/online/common/firmware/registers/a10_pcie_registers.vhd
//   RESET_LINK_CTL_REGISTER_W         = 0x29
//   RESET_LINK_RUN_NUMBER_REGISTER_W  = 0x2A
//   RESET_LINK_STATUS_REGISTER_R      = 0x35
//
// Writing to libmudaq's RESET_LINK_CTL_REGISTER_W (0x28) lands on
// FARM_CTL_REGISTER_W in online_sc and the reset-link never sees the pulse.
constexpr uint32_t swb_reset_link_ctl_reg = 0x29;
constexpr uint32_t swb_reset_link_run_nr_reg = 0x2A;
constexpr uint32_t swb_reset_link_status_reg = 0x35;

constexpr uint32_t rc_feb_broadcast = 0x7;
constexpr uint32_t rc_feb_mask = 0x7;
constexpr uint32_t rc_cmd_mask = 0xffu;
constexpr unsigned rc_default_settle_us = 5000;

enum class rc_mode {
	invalid = 0,
	send,
	status,
	list,
};

struct rc_op {
	string name;
	uint8_t code;
	bool has_run_number;
	const char *help;
};

// Mirrors RESET_LINK_* in common/firmware/registers/mudaq.vhd. Keep in the
// same order as the spec (run-control block first, then link tests, then
// reset/enable/address) so list output is scannable.
static const rc_op rc_op_table[] = {
	{"run-prepare",     0x10, true,  "start-of-run handshake; FSM also emits 32-bit run number"},
	{"sync",            0x11, false, "synchronize after run-prepare"},
	{"start-run",       0x12, false, "start run"},
	{"end-run",         0x13, false, "end run"},
	{"abort-run",       0x14, false, "abort run"},
	{"start-link-test", 0x20, false, "start link test"},
	{"stop-link-test",  0x21, false, "stop link test"},
	{"start-sync-test", 0x24, false, "start sync test"},
	{"stop-sync-test",  0x25, false, "stop sync test"},
	{"test-sync",       0x26, false, "test sync pulse"},
	{"reset",           0x30, false, "assert FEB soft reset"},
	{"stop-reset",      0x31, false, "release FEB soft reset"},
	{"enable",          0x32, false, "enable FEB run state"},
	{"disable",         0x33, false, "disable FEB run state"},
	{"address",         0x40, false, "address assignment"},
};

struct rc_opts {
	string device = "/dev/mudaq0";
	rc_mode mode = rc_mode::invalid;
	uint32_t cmd = 0;
	uint32_t feb = rc_feb_broadcast;
	uint32_t run_number = 0;
	bool run_number_set = false;
	unsigned settle_us = rc_default_settle_us;
	bool quiet = false;
};

static string hex_u32(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(8)
	   << std::setfill('0') << value;
	return os.str();
}

static string hex_u8(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(2)
	   << std::setfill('0') << (value & 0xffu);
	return os.str();
}

static void pr_info(const string& msg)
{
	std::cout << "info: " << msg << '\n';
}

static void pr_warn(const string& msg)
{
	std::cout << "warn: " << msg << '\n';
}

static void pr_err(const string& msg)
{
	std::cerr << "err: " << msg << '\n';
}

static void print_usage()
{
	std::cout
		<< "Usage:\n"
		<< "  rc_tool send <cmd> [options]           send a run-control byte\n"
		<< "  rc_tool status [options]               read RESET_LINK_STATUS_REGISTER_R\n"
		<< "  rc_tool list                           list known command names\n"
		<< "\n"
		<< "<cmd> is a name from `rc_tool list` (e.g. start-run) or a raw 8-bit\n"
		<< "value (0xNN / decimal).\n"
		<< "\n"
		<< "Options:\n"
		<< "  --device <path>        MuDAQ device node (default /dev/mudaq0)\n"
		<< "  --feb <N>              destination FEB 0..7 (default 7 = broadcast)\n"
		<< "  --run <N>              32-bit run number (required for run-prepare)\n"
		<< "  --settle-us <us>       hold pulse width / poll delay (default 5000)\n"
		<< "  --quiet                suppress informational prints\n"
		<< "  -h, --help             show this help\n"
		<< "\n"
		<< "Examples:\n"
		<< "  rc_tool send reset                    # broadcast CMD_RESET\n"
		<< "  rc_tool send stop-reset --feb 2       # release reset on FEB 2\n"
		<< "  rc_tool send run-prepare --run 42     # begin run 42\n"
		<< "  rc_tool send 0x30                     # raw opcode\n"
		<< "  rc_tool status\n";
}

static bool parse_u32(const string& text, uint32_t *out)
{
	char *end = nullptr;
	unsigned long value;

	if (!out || text.empty())
		return false;

	errno = 0;
	value = std::strtoul(text.c_str(), &end, 0);
	if (errno || end == text.c_str() || *end != '\0')
		return false;
	if (value > std::numeric_limits<uint32_t>::max())
		return false;

	*out = static_cast<uint32_t>(value);
	return true;
}

static const rc_op *lookup_op_by_name(const string& name)
{
	for (const auto& op : rc_op_table) {
		if (name == op.name)
			return &op;
	}
	return nullptr;
}

static const rc_op *lookup_op_by_code(uint8_t code)
{
	for (const auto& op : rc_op_table) {
		if (op.code == code)
			return &op;
	}
	return nullptr;
}

static bool parse_cmd(const string& text, uint32_t *cmd,
                      const rc_op **op_out)
{
	const rc_op *op = lookup_op_by_name(text);
	if (op) {
		*cmd = op->code;
		if (op_out)
			*op_out = op;
		return true;
	}
	uint32_t value = 0;
	if (!parse_u32(text, &value)) {
		pr_err("unknown command and not a numeric byte: " + text);
		return false;
	}
	if (value > rc_cmd_mask) {
		pr_err("command byte must fit in 8 bits: " + text);
		return false;
	}
	*cmd = value;
	if (op_out)
		*op_out = lookup_op_by_code(static_cast<uint8_t>(value));
	return true;
}

static bool parse_opts(int argc, char **argv, rc_opts *opts,
                       const rc_op **matched_op)
{
	vector<string> pos;

	if (!opts)
		return false;
	if (argc < 2) {
		print_usage();
		return false;
	}

	for (int i = 1; i < argc; ++i) {
		string arg(argv[i]);

		if (arg == "-h" || arg == "--help") {
			print_usage();
			std::exit(0);
		}
		if (arg == "--device") {
			if (i + 1 >= argc) {
				pr_err("missing argument for --device");
				return false;
			}
			opts->device = argv[++i];
			continue;
		}
		if (arg == "--feb") {
			uint32_t feb;
			if (i + 1 >= argc || !parse_u32(argv[++i], &feb)) {
				pr_err("invalid value for --feb");
				return false;
			}
			if (feb > rc_feb_mask) {
				pr_err("feb address must be in 0..7");
				return false;
			}
			opts->feb = feb;
			continue;
		}
		if (arg == "--run") {
			uint32_t run;
			if (i + 1 >= argc || !parse_u32(argv[++i], &run)) {
				pr_err("invalid value for --run");
				return false;
			}
			opts->run_number = run;
			opts->run_number_set = true;
			continue;
		}
		if (arg == "--settle-us") {
			uint32_t us;
			if (i + 1 >= argc || !parse_u32(argv[++i], &us)) {
				pr_err("invalid value for --settle-us");
				return false;
			}
			opts->settle_us = us;
			continue;
		}
		if (arg == "--quiet") {
			opts->quiet = true;
			continue;
		}

		pos.push_back(arg);
	}

	if (pos.empty()) {
		print_usage();
		return false;
	}

	if (pos[0] == "send") {
		if (pos.size() != 2) {
			pr_err("send requires exactly one <cmd> argument");
			return false;
		}
		opts->mode = rc_mode::send;
		if (!parse_cmd(pos[1], &opts->cmd, matched_op))
			return false;
		return true;
	}

	if (pos[0] == "status") {
		if (pos.size() != 1) {
			pr_err("status takes no positional arguments");
			return false;
		}
		opts->mode = rc_mode::status;
		return true;
	}

	if (pos[0] == "list") {
		if (pos.size() != 1) {
			pr_err("list takes no positional arguments");
			return false;
		}
		opts->mode = rc_mode::list;
		return true;
	}

	pr_err("unknown subcommand: " + pos[0]);
	return false;
}

static void print_list()
{
	std::cout << "  code  payload  name              description\n";
	std::cout << "  ----  -------  ----------------  -----------\n";
	for (const auto& op : rc_op_table) {
		std::cout << "  " << hex_u8(op.code) << "  "
		          << (op.has_run_number ? "run_nr " : "none   ") << "  "
		          << std::left << std::setw(16) << op.name << "  "
		          << op.help << '\n';
	}
}

static int do_send(mudaq::DmaMudaqDevice& mu, const rc_opts& opts,
                   const rc_op *op)
{
	uint32_t ctl = (opts.feb & rc_feb_mask) << 29 | (opts.cmd & rc_cmd_mask);
	bool needs_run_number = op && op->has_run_number;

	if (needs_run_number && !opts.run_number_set) {
		pr_err(string(op->name) + " requires --run <N>");
		return 2;
	}

	uint32_t ctl_before = mu.read_register_rw(swb_reset_link_ctl_reg);
	uint32_t status_before = mu.read_register_ro(swb_reset_link_status_reg);

	if (!opts.quiet) {
		std::ostringstream os;
		os << "cmd=" << hex_u8(opts.cmd);
		if (op)
			os << " (" << op->name << ")";
		os << " feb=" << opts.feb
		   << " -> RESET_LINK_CTL_REGISTER_W=" << hex_u32(ctl);
		pr_info(os.str());
		pr_info("before: CTL=" + hex_u32(ctl_before)
		        + " STATUS=" + hex_u32(status_before));
	}

	if (needs_run_number) {
		if (!opts.quiet)
			pr_info("writing RESET_LINK_RUN_NUMBER_REGISTER_W = " + hex_u32(opts.run_number));
		mu.write_register(swb_reset_link_run_nr_reg, opts.run_number);
	}

	mu.write_register(swb_reset_link_ctl_reg, ctl);
	std::this_thread::sleep_for(std::chrono::microseconds(opts.settle_us));
	mu.write_register(swb_reset_link_ctl_reg, 0x0);
	std::this_thread::sleep_for(std::chrono::microseconds(opts.settle_us));

	uint32_t ctl_after = mu.read_register_rw(swb_reset_link_ctl_reg);
	uint32_t status_after = mu.read_register_ro(swb_reset_link_status_reg);
	uint32_t last_state_byte = (status_after >> 24) & 0xffu;

	if (!opts.quiet) {
		pr_info("after : CTL=" + hex_u32(ctl_after)
		        + " STATUS=" + hex_u32(status_after));
	}

	// a10_reset_link.o_state_out encodes the last transmitted byte in the top
	// byte for simple ops (line 78), or a FSM marker for RUN_PREPARE/SYNC/
	// START_RUN/END_RUN (lines 89,111,119,128). Match on the top byte when
	// possible; otherwise report without asserting.
	if (last_state_byte == (opts.cmd & rc_cmd_mask)) {
		if (!opts.quiet)
			pr_info("ok: o_state_out echoes " + hex_u8(last_state_byte));
		return 0;
	}

	if (needs_run_number && last_state_byte == 0) {
		// run-prepare completes into rNB0..rNB3/sync; the top byte becomes
		// the run number's MSB, not the command byte. Do not flag.
		if (!opts.quiet)
			pr_info("ok: run-prepare FSM advanced (state encodes run number)");
		return 0;
	}

	pr_warn("o_state_out top byte = " + hex_u8(last_state_byte)
	        + " (expected " + hex_u8(opts.cmd)
	        + "); see a10_reset_link.vhd if the FSM is mid-sequence");
	return 0;
}

static int do_status(mudaq::DmaMudaqDevice& mu, const rc_opts& opts)
{
	uint32_t ctl = mu.read_register_rw(swb_reset_link_ctl_reg);
	uint32_t status = mu.read_register_ro(swb_reset_link_status_reg);
	uint32_t run = mu.read_register_rw(swb_reset_link_run_nr_reg);
	uint32_t last_state_byte = (status >> 24) & 0xffu;
	const rc_op *op = lookup_op_by_code(static_cast<uint8_t>(last_state_byte));

	std::cout << "RESET_LINK_CTL_REGISTER_W        = " << hex_u32(ctl) << '\n';
	std::cout << "RESET_LINK_STATUS_REGISTER_R     = " << hex_u32(status) << '\n';
	std::cout << "RESET_LINK_RUN_NUMBER_REGISTER_W = " << hex_u32(run) << '\n';
	std::cout << "last state byte              = " << hex_u8(last_state_byte);
	if (op)
		std::cout << " (" << op->name << ")";
	std::cout << '\n';
	(void)opts;
	return 0;
}

} // namespace

int main(int argc, char **argv)
{
	rc_opts opts;
	const rc_op *op = nullptr;

	if (!parse_opts(argc, argv, &opts, &op))
		return 2;

	if (opts.mode == rc_mode::list) {
		print_list();
		return 0;
	}

	mudaq::DmaMudaqDevice mu(opts.device);
	if (!mu.open()) {
		pr_err("failed to open " + opts.device);
		return 1;
	}
	if (!mu.is_ok()) {
		pr_err("mudaq device reports not-ok");
		return 1;
	}

	switch (opts.mode) {
	case rc_mode::send:
		return do_send(mu, opts, op);
	case rc_mode::status:
		return do_status(mu, opts);
	default:
		print_usage();
		return 2;
	}
}
