/*
 * Robust slow-control debug tool for SWB -> FEB transactions.
 *
 * Style goal:
 *   Keep the code flat and explicit like kernel driver debug paths:
 *   small helpers, visible state transitions, no hidden parser state,
 *   and diagnostics that preserve raw evidence.
 */

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "a10_pcie_registers.h"
#include "feb_sc_registers.h"
#include "mudaq_device.h"
#include "mudaq_device_constants.h"

using std::string;
using std::vector;

namespace {

constexpr uint32_t sc_preamble_mask = 0x1c0000bc;
constexpr uint32_t sc_preamble_word = 0x1c0000bc;
constexpr uint32_t sc_trailer_word = 0x0000009c;
constexpr uint32_t sc_secondary_ready_mask = 0x20000000;
// SC hub v2 host transactions use 18-bit word addresses (0x00000..0x3FFFF).
// The user-facing CLI therefore accepts the exact word values documented in the
// board-test plan and SVD-derived slave map; do not enforce byte alignment.
constexpr uint32_t sc_addr_mask = 0x0003ffffu;
constexpr uint32_t sc_diag_err_addr = 0xfe84;
constexpr uint32_t sc_diag_main_addr = 0xfe8f;
constexpr uint32_t sc_diag_err_words = 2;
constexpr uint32_t sc_diag_main_words = 9;

enum class sc_cmd {
	invalid = 0,
	read,
	write,
	diag,
};

struct sc_opts {
	string device = "/dev/mudaq0";
	sc_cmd cmd = sc_cmd::invalid;
	uint32_t link = 0;
	uint32_t addr = 0;
	uint32_t read_len = 1;
	vector<uint32_t> write_data;
	bool nonincrementing = false;
	bool no_reset = false;
	bool dump_ring = false;
	bool quiet = false;
	uint32_t enable_mask = 0xffffffffu;
	unsigned main_timeout_ms = 1000;
	unsigned reply_timeout_ms = 1000;
	unsigned poll_us = 1000;
};

struct sc_request {
	bool is_read = false;
	uint32_t link = 0;
	uint32_t addr = 0;
	uint32_t pkt_type = 0;
	uint32_t req_len = 0;
	vector<uint32_t> payload;
	vector<uint32_t> words;
	size_t main_length_words = 0;
	size_t expected_reply_payload_words = 0;
	size_t expected_reply_ring_words = 0;
	size_t expected_reply_declared_words = 0;
};

struct sc_packet {
	bool valid = false;
	bool trailer_ok = false;
	bool matches_request = false;
	bool ack = false;
	uint32_t start_ptr = 0;
	uint32_t end_ptr = 0;
	uint32_t header = 0;
	uint32_t addr_word = 0;
	uint32_t len_word = 0;
	uint32_t trailer = 0;
	uint32_t pkt_type = 0;
	uint32_t link = 0;
	uint32_t addr = 0;
	uint32_t rsp = 0;
	uint32_t echoed_length = 0;
	uint32_t declared_payload_words = 0;
	uint32_t actual_payload_words = 0;
	size_t declared_ring_words = 0;
	size_t actual_ring_words = 0;
	vector<uint32_t> payload;
	vector<string> warnings;
};

struct sc_scan_result {
	vector<sc_packet> packets;
	vector<std::pair<uint32_t, uint32_t>> skipped_words;
	bool incomplete = false;
	uint32_t top = 0;
};

struct sc_xfer_result {
	bool ok = false;
	bool main_ready = false;
	bool matched = false;
	bool main_timeout = false;
	bool reply_timeout = false;
	uint64_t main_ready_us = 0;
	uint64_t match_us = 0;
	uint64_t total_us = 0;
	uint32_t secondary_before = 0;
	uint32_t secondary_after = 0;
	uint32_t secondary_delta_words = 0;
	sc_scan_result scan;
	sc_packet packet;
};

static string hex_u32(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(8)
	   << std::setfill('0') << value;
	return os.str();
}

static string hex_u16(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(4)
	   << std::setfill('0') << (value & 0xffffu);
	return os.str();
}

// SC hub address field is 18 bits; print as 5-nibble hex.
static string hex_addr(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(5)
	   << std::setfill('0') << (value & sc_addr_mask);
	return os.str();
}

static string hex_ptr(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << std::setw(4)
	   << std::setfill('0') << (value & (MUDAQ_MEM_RO_LEN - 1));
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
		<< "  sc_tool <link> read <addr> [len] [options]\n"
		<< "  sc_tool <link> write <addr> <word> [word ...] [options]\n"
		<< "  sc_tool <link> diag [options]\n"
		<< "\n"
		<< "Options:\n"
		<< "  --device <path>            MuDAQ device node (default /dev/mudaq0)\n"
		<< "  --enable-mask <mask>       FEB_ENABLE_REGISTER_W value (default 0xffffffff)\n"
		<< "  --noninc                   Use non-incrementing packet type\n"
		<< "  --no-reset                 Do not reset SC main/secondary before use\n"
		<< "  --main-timeout-ms <ms>     Wait time for SC main done (default 1000)\n"
		<< "  --reply-timeout-ms <ms>    Wait time for matching reply (default 1000)\n"
		<< "  --poll-us <us>             Poll interval in microseconds (default 1000)\n"
		<< "  --dump-ring                Dump raw ring words between before/after pointers\n"
		<< "  --quiet                    Suppress board banner\n"
		<< "  -h, --help                 Show this help\n"
		<< "\n"
		<< "Examples:\n"
		<< "  sc_tool 2 write 0x0000 0x12345678\n"
		<< "  sc_tool 2 read 0xFE8F 9\n"
		<< "  sc_tool 2 diag\n";
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

static bool parse_opts(int argc, char **argv, sc_opts *opts)
{
	vector<string> pos;

	if (!opts)
		return false;
	if (argc < 3) {
		print_usage();
		return false;
	}
	if (!parse_u32(argv[1], &opts->link)) {
		pr_err("invalid link index: " + string(argv[1]));
		return false;
	}
	if (opts->link > 0xff) {
		pr_err("link index must fit in 8 bits");
		return false;
	}

	for (int i = 2; i < argc; ++i) {
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
		if (arg == "--main-timeout-ms") {
			if (i + 1 >= argc || !parse_u32(argv[++i], &opts->main_timeout_ms)) {
				pr_err("invalid value for --main-timeout-ms");
				return false;
			}
			continue;
		}
		if (arg == "--enable-mask") {
			if (i + 1 >= argc || !parse_u32(argv[++i], &opts->enable_mask)) {
				pr_err("invalid value for --enable-mask");
				return false;
			}
			continue;
		}
		if (arg == "--reply-timeout-ms") {
			if (i + 1 >= argc || !parse_u32(argv[++i], &opts->reply_timeout_ms)) {
				pr_err("invalid value for --reply-timeout-ms");
				return false;
			}
			continue;
		}
		if (arg == "--poll-us") {
			if (i + 1 >= argc || !parse_u32(argv[++i], &opts->poll_us)) {
				pr_err("invalid value for --poll-us");
				return false;
			}
			continue;
		}
		if (arg == "--noninc") {
			opts->nonincrementing = true;
			continue;
		}
		if (arg == "--no-reset") {
			opts->no_reset = true;
			continue;
		}
		if (arg == "--dump-ring") {
			opts->dump_ring = true;
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

	if (pos[0] == "read") {
		uint32_t addr;
		uint32_t len = 1;

		opts->cmd = sc_cmd::read;
		if (pos.size() < 2 || !parse_u32(pos[1], &addr)) {
			pr_err("read requires <addr>");
			return false;
		}
		if (pos.size() >= 3 && !parse_u32(pos[2], &len)) {
			pr_err("invalid read length");
			return false;
		}
		if (pos.size() > 3) {
			pr_err("read takes at most <addr> [len]");
			return false;
		}
		if (addr > sc_addr_mask) {
			pr_err("read address must fit in 18 bits (word address 0x00000..0x3FFFF)");
			return false;
		}
		if (len == 0 || len > 0xffffu) {
			pr_err("read length must be in 1..65535");
			return false;
		}
		opts->addr = addr;
		opts->read_len = len;
		return true;
	}

	if (pos[0] == "write") {
		uint32_t addr;

		opts->cmd = sc_cmd::write;
		if (pos.size() < 3 || !parse_u32(pos[1], &addr)) {
			pr_err("write requires <addr> <word> [word ...]");
			return false;
		}
		if (addr > sc_addr_mask) {
			pr_err("write address must fit in 18 bits (word address 0x00000..0x3FFFF)");
			return false;
		}
		opts->addr = addr;

		for (size_t i = 2; i < pos.size(); ++i) {
			uint32_t word;
			if (!parse_u32(pos[i], &word)) {
				pr_err("invalid write data word: " + pos[i]);
				return false;
			}
			opts->write_data.push_back(word);
		}
		if (opts->write_data.empty()) {
			pr_err("write requires at least one data word");
			return false;
		}
		return true;
	}

	if (pos[0] == "diag") {
		if (pos.size() != 1) {
			pr_err("diag takes no positional arguments");
			return false;
		}
		opts->cmd = sc_cmd::diag;
		return true;
	}

	pr_err("unknown command: " + pos[0]);
	return false;
}

static uint32_t sc_ring_next(uint32_t ptr)
{
	return (ptr + 1u) & (MUDAQ_MEM_RO_LEN - 1u);
}

static uint32_t sc_ring_advance(uint32_t ptr, uint32_t words)
{
	return (ptr + words) & (MUDAQ_MEM_RO_LEN - 1u);
}

static uint32_t sc_ring_distance(uint32_t from, uint32_t to)
{
	if (to >= from)
		return to - from;
	return (MUDAQ_MEM_RO_LEN - from) + to;
}

static const char *sc_pkt_type_name(uint32_t pkt_type)
{
	switch (pkt_type) {
	case PACKET_TYPE_SC_READ:
		return "RD";
	case PACKET_TYPE_SC_WRITE:
		return "WR";
	case PACKET_TYPE_SC_READ_NONINCREMENTING:
		return "RD_NI";
	case PACKET_TYPE_SC_WRITE_NONINCREMENTING:
		return "WR_NI";
	default:
		return "??";
	}
}

static const char *sc_rsp_name(uint32_t rsp)
{
	switch (rsp & 0x3u) {
	case 0:
		return "OK";
	case 1:
		return "SLVERR";
	case 2:
		return "DECERR";
	default:
		return "RSP3";
	}
}

static uint32_t sc_secondary_top(mudaq::MudaqDevice& dev)
{
	return (dev.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) + 1u) & (MUDAQ_MEM_RO_LEN - 1u);
}

static bool sc_prepare(mudaq::MudaqDevice& dev, const sc_opts& opts)
{
	dev.write_register(FEB_ENABLE_REGISTER_W, opts.enable_mask);
	if (opts.no_reset)
		return true;

	{
		uint32_t reset = dev.read_register_rw(RESET_REGISTER_W);
		dev.write_register_wait(RESET_REGISTER_W, SET_RESET_BIT_SC_MAIN(reset), 1000);
		dev.write_register(RESET_REGISTER_W, UNSET_RESET_BIT_SC_MAIN(reset));
	}

	dev.toggle_register(RESET_REGISTER_W, SET_RESET_BIT_SC_SECONDARY(0), 1000);

	for (unsigned i = 0; i < 2000; ++i) {
		if ((dev.read_register_ro(SC_STATE_REGISTER_R) & sc_secondary_ready_mask) != 0)
			return true;
		std::this_thread::sleep_for(std::chrono::microseconds(1000));
	}

	pr_err("SC secondary did not report ready after reset");
	return false;
}

static sc_request sc_build_request(const sc_opts& opts)
{
	sc_request req;
	uint32_t header;

	req.is_read = (opts.cmd == sc_cmd::read);
	req.link = opts.link;
	req.addr = opts.addr & sc_addr_mask;
	req.pkt_type = req.is_read ?
		(opts.nonincrementing ? PACKET_TYPE_SC_READ_NONINCREMENTING : PACKET_TYPE_SC_READ) :
		(opts.nonincrementing ? PACKET_TYPE_SC_WRITE_NONINCREMENTING : PACKET_TYPE_SC_WRITE);
	req.req_len = req.is_read ? opts.read_len : static_cast<uint32_t>(opts.write_data.size());
	req.payload = opts.write_data;

	header = (PACKET_TYPE_SC << 26)
	       | (req.pkt_type << 24)
	       | ((req.link & 0xffu) << 8)
	       | 0xbcu;

	req.words.push_back(header);
	req.words.push_back(req.addr);
	req.words.push_back(req.req_len);
	if (req.is_read) {
		req.words.push_back(sc_trailer_word);
	} else {
		req.words.insert(req.words.end(), req.payload.begin(), req.payload.end());
		req.words.push_back(sc_trailer_word);
	}

	req.main_length_words = req.is_read ? 2u : (2u + req.payload.size());
	req.expected_reply_payload_words = req.is_read ? req.req_len : 0u;
	req.expected_reply_ring_words = 4u + req.expected_reply_payload_words;
	req.expected_reply_declared_words = req.expected_reply_ring_words;
	return req;
}

static void sc_dump_request(const sc_request& req)
{
	pr_info("request summary:");
	std::cout
		<< "  type               : " << sc_pkt_type_name(req.pkt_type) << '\n'
		<< "  link               : " << req.link << '\n'
		<< "  addr               : " << hex_addr(req.addr) << '\n'
		<< "  request length     : " << req.req_len << " word(s)\n"
		<< "  main length reg    : " << req.main_length_words << '\n'
		<< "  expected reply words (actual)   : " << req.expected_reply_ring_words << '\n'
		<< "  expected reply words (declared) : " << req.expected_reply_declared_words << '\n';

	pr_info("request words written to SC main:");
	for (size_t i = 0; i < req.words.size(); ++i)
		std::cout << "  wmem[" << i << "] = " << hex_u32(req.words[i]) << '\n';
}

static void sc_submit(mudaq::MudaqDevice& dev, const sc_request& req)
{
	for (size_t i = 0; i < req.words.size(); ++i)
		dev.write_memory_rw(static_cast<unsigned>(i), req.words[i]);

	(void)dev.read_memory_rw(static_cast<unsigned>(req.words.size() - 1u));

	dev.write_register(SC_MAIN_LENGTH_REGISTER_W, static_cast<uint32_t>(req.main_length_words));
	dev.write_register(SC_MAIN_ENABLE_REGISTER_W, 0);
	dev.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);
}

static bool sc_wait_main_ready(mudaq::MudaqDevice& dev, const sc_opts& opts)
{
	auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(opts.main_timeout_ms);

	while (std::chrono::steady_clock::now() < deadline) {
		if ((dev.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1u) != 0)
			return true;
		std::this_thread::sleep_for(std::chrono::microseconds(opts.poll_us));
	}

	return false;
}

static bool sc_packet_matches(const sc_packet& pkt, const sc_request& req)
{
	if (!pkt.valid)
		return false;
	if (pkt.link != req.link)
		return false;
	if (pkt.addr != req.addr)
		return false;
	if (pkt.pkt_type != req.pkt_type)
		return false;
	if (req.is_read)
		return pkt.actual_payload_words == req.expected_reply_payload_words;
	return pkt.actual_payload_words == 0;
}

static sc_scan_result sc_scan_packets(mudaq::MudaqDevice& dev, uint32_t from, uint32_t top)
{
	sc_scan_result res;
	uint32_t ptr = from;

	res.top = top;

	while (ptr != top) {
		uint32_t avail = sc_ring_distance(ptr, top);
		uint32_t header = dev.read_memory_ro(ptr);

		if ((header & sc_preamble_mask) != sc_preamble_word) {
			if (res.skipped_words.size() < 8)
				res.skipped_words.emplace_back(ptr, header);
			ptr = sc_ring_next(ptr);
			continue;
		}

		if (avail < 4u) {
			res.incomplete = true;
			break;
		}

			sc_packet pkt;
			uint32_t addr_ptr = sc_ring_next(ptr);
			uint32_t len_ptr = sc_ring_next(addr_ptr);
			uint32_t protocol_payload_words;
			uint32_t declared_total_words;
			uint32_t declared_trailer_ptr;
			uint32_t declared_trailer = 0;
			bool declared_complete;

			pkt.start_ptr = ptr;
			pkt.header = header;
			pkt.addr_word = dev.read_memory_ro(addr_ptr);
			pkt.len_word = dev.read_memory_ro(len_ptr);
			pkt.pkt_type = (header >> 24) & 0x3u;
			pkt.link = (header >> 8) & 0xffu;
			pkt.addr = pkt.addr_word & sc_addr_mask;
			pkt.rsp = (pkt.len_word >> 18) & 0x3u;
			pkt.ack = ((pkt.len_word >> 16) & 0x1u) != 0;
			pkt.echoed_length = pkt.len_word & 0xffffu;
			protocol_payload_words = pkt.echoed_length;
			if ((pkt.pkt_type == PACKET_TYPE_SC_WRITE ||
			     pkt.pkt_type == PACKET_TYPE_SC_WRITE_NONINCREMENTING) &&
			    pkt.ack) {
				protocol_payload_words = 0;
			}
			pkt.declared_payload_words = protocol_payload_words;
			pkt.declared_ring_words = 4u + protocol_payload_words;

			declared_total_words = 4u + protocol_payload_words;
			declared_complete = (avail >= declared_total_words);
			declared_trailer_ptr = sc_ring_advance(ptr, 3u + protocol_payload_words);
			if (declared_complete)
				declared_trailer = dev.read_memory_ro(declared_trailer_ptr);

			if (declared_complete && declared_trailer == sc_trailer_word) {
				pkt.valid = true;
				pkt.trailer_ok = true;
				pkt.actual_payload_words = pkt.declared_payload_words;
				pkt.actual_ring_words = pkt.declared_ring_words;
				pkt.trailer = declared_trailer;
				for (uint32_t i = 0; i < pkt.actual_payload_words; ++i) {
					uint32_t word_ptr = sc_ring_advance(ptr, 3u + i);
					pkt.payload.push_back(dev.read_memory_ro(word_ptr));
				}
				pkt.end_ptr = sc_ring_advance(ptr, static_cast<uint32_t>(pkt.actual_ring_words));
				ptr = pkt.end_ptr;
			} else {
				if (!declared_complete)
					res.incomplete = true;
				else
					pkt.trailer = declared_trailer;
				pkt.warnings.push_back(
					"candidate packet has valid preamble but no valid trailer at declared boundary");
				res.packets.push_back(pkt);
				ptr = sc_ring_next(ptr);
				continue;
			}

			res.packets.push_back(pkt);
	}

	return res;
}

static void sc_dump_ring(mudaq::MudaqDevice& dev, uint32_t from, uint32_t to)
{
	uint32_t ptr = from;
	uint32_t words = sc_ring_distance(from, to);

	pr_info("raw secondary ring window:");
	std::cout << "  start=" << hex_ptr(from)
		  << " end=" << hex_ptr(to)
		  << " words=" << words << '\n';

	for (uint32_t i = 0; i < words; ++i) {
		uint32_t word = dev.read_memory_ro(ptr);
		std::cout << "  ring[" << hex_ptr(ptr) << "] = " << hex_u32(word) << '\n';
		ptr = sc_ring_next(ptr);
	}
}

static void sc_dump_packet(const sc_packet& pkt)
{
	pr_info("observed packet:");
	std::cout
		<< "  ring start          : " << hex_ptr(pkt.start_ptr) << '\n'
		<< "  ring end            : " << hex_ptr(pkt.end_ptr) << '\n'
		<< "  type                : " << sc_pkt_type_name(pkt.pkt_type) << '\n'
		<< "  link                : " << pkt.link << '\n'
		<< "  addr                : " << hex_addr(pkt.addr) << '\n'
		<< "  rsp                 : " << sc_rsp_name(pkt.rsp) << " (" << pkt.rsp << ")\n"
		<< "  ack                 : " << (pkt.ack ? 1 : 0) << '\n'
		<< "  echoed length       : " << pkt.echoed_length << '\n'
		<< "  declared payload    : " << pkt.declared_payload_words << '\n'
		<< "  actual payload      : " << pkt.actual_payload_words << '\n'
		<< "  declared ring words : " << pkt.declared_ring_words << '\n'
		<< "  actual ring words   : " << pkt.actual_ring_words << '\n'
		<< "  raw header          : " << hex_u32(pkt.header) << '\n'
		<< "  raw addr word       : " << hex_u32(pkt.addr_word) << '\n'
		<< "  raw len word        : " << hex_u32(pkt.len_word) << '\n'
		<< "  raw trailer         : " << hex_u32(pkt.trailer) << '\n';

	if (!pkt.payload.empty()) {
		pr_info("packet payload:");
		for (size_t i = 0; i < pkt.payload.size(); ++i)
			std::cout << "  payload[" << i << "] = " << hex_u32(pkt.payload[i]) << '\n';
	}

	for (const auto& warning : pkt.warnings)
		pr_warn(warning);
}

static void sc_dump_scan_summary(const sc_scan_result& scan)
{
	if (!scan.skipped_words.empty()) {
		pr_warn("skipped non-preamble words while scanning secondary ring");
		for (const auto& entry : scan.skipped_words)
			std::cout << "  skipped ring[" << hex_ptr(entry.first)
				  << "] = " << hex_u32(entry.second) << '\n';
	}

	if (scan.packets.empty())
		return;

	pr_info("packets observed on secondary ring:");
	for (size_t i = 0; i < scan.packets.size(); ++i) {
		const auto& pkt = scan.packets[i];
		std::cout
			<< "  [" << i << "] "
			<< (pkt.valid ? "valid " : "invalid ")
			<< sc_pkt_type_name(pkt.pkt_type)
			<< " link=" << pkt.link
			<< " addr=" << hex_addr(pkt.addr)
			<< " rsp=" << sc_rsp_name(pkt.rsp)
				<< " ack=" << (pkt.ack ? 1 : 0)
			<< " declared=" << pkt.declared_payload_words
			<< " actual=" << pkt.actual_payload_words
			<< " start=" << hex_ptr(pkt.start_ptr)
			<< '\n';
	}

	if (scan.incomplete)
		pr_warn("scan ended with an incomplete candidate packet");
}

static sc_xfer_result sc_run_xfer(mudaq::MudaqDevice& dev, const sc_opts& opts,
				      const sc_request& req)
{
	sc_xfer_result res;
	auto start = std::chrono::steady_clock::now();
	auto deadline = start + std::chrono::milliseconds(opts.reply_timeout_ms);

	res.secondary_before = sc_secondary_top(dev);
	sc_submit(dev, req);

	res.main_ready = sc_wait_main_ready(dev, opts);
	res.main_ready_us = static_cast<uint64_t>(
		std::chrono::duration_cast<std::chrono::microseconds>(
			std::chrono::steady_clock::now() - start).count());
	if (!res.main_ready) {
		res.main_timeout = true;
		res.total_us = res.main_ready_us;
		res.secondary_after = sc_secondary_top(dev);
		res.secondary_delta_words = sc_ring_distance(res.secondary_before, res.secondary_after);
		return res;
	}

	while (std::chrono::steady_clock::now() < deadline) {
		res.secondary_after = sc_secondary_top(dev);
		res.secondary_delta_words = sc_ring_distance(res.secondary_before, res.secondary_after);
		res.scan = sc_scan_packets(dev, res.secondary_before, res.secondary_after);

		for (auto& pkt : res.scan.packets) {
			if (!sc_packet_matches(pkt, req))
				continue;
			pkt.matches_request = true;
			res.packet = pkt;
			res.matched = true;
			res.ok = true;
			res.match_us = static_cast<uint64_t>(
				std::chrono::duration_cast<std::chrono::microseconds>(
					std::chrono::steady_clock::now() - start).count());
			res.total_us = res.match_us;
			return res;
		}

		std::this_thread::sleep_for(std::chrono::microseconds(opts.poll_us));
	}

	res.reply_timeout = true;
	res.total_us = static_cast<uint64_t>(
		std::chrono::duration_cast<std::chrono::microseconds>(
			std::chrono::steady_clock::now() - start).count());
	res.secondary_after = sc_secondary_top(dev);
	res.secondary_delta_words = sc_ring_distance(res.secondary_before, res.secondary_after);
	res.scan = sc_scan_packets(dev, res.secondary_before, res.secondary_after);
	return res;
}

static int sc_run_request(mudaq::MudaqDevice& dev, const sc_opts& opts,
			  const sc_request& req, vector<uint32_t> *payload_out)
{
	sc_xfer_result res;

	sc_dump_request(req);
	res = sc_run_xfer(dev, opts, req);

	std::cout
		<< "  timing main ready   : " << res.main_ready_us << " us\n"
		<< "  timing matched      : " << res.match_us << " us\n"
		<< "  timing total        : " << res.total_us << " us\n"
		<< "  secondary before    : " << hex_ptr(res.secondary_before) << '\n'
		<< "  secondary after     : " << hex_ptr(res.secondary_after) << '\n'
		<< "  secondary delta     : " << res.secondary_delta_words << " word(s)\n"
		<< "  SC main status      : " << hex_u32(dev.read_register_ro(SC_MAIN_STATUS_REGISTER_R)) << '\n'
		<< "  SC state            : " << hex_u32(dev.read_register_ro(SC_STATE_REGISTER_R)) << '\n';

	if (opts.dump_ring)
		sc_dump_ring(dev, res.secondary_before, res.secondary_after);

	if (res.main_timeout) {
		pr_err("timed out waiting for SC main ready");
		return 3;
	}

	if (!res.matched) {
		pr_err("timed out waiting for matching secondary reply");
		sc_dump_scan_summary(res.scan);
		return 4;
	}

	sc_dump_packet(res.packet);
	if (res.secondary_delta_words != res.packet.actual_ring_words) {
		pr_warn("secondary pointer delta does not match matched packet size; extra traffic may be present");
	}
	if (res.packet.actual_ring_words != req.expected_reply_ring_words) {
		pr_warn("actual reply ring size differs from operation-level expectation");
	}
	if (res.packet.declared_ring_words != res.packet.actual_ring_words) {
		pr_warn("declared reply ring size differs from actual observed ring size");
	}

	if (payload_out)
		*payload_out = res.packet.payload;

	return 0;
}

static int sc_run_diag(mudaq::MudaqDevice& dev, const sc_opts& opts)
{
	sc_opts read_opts = opts;
	sc_request err_req;
	sc_request main_req;
	vector<uint32_t> err_payload;
	vector<uint32_t> main_payload;
	int rc;

	read_opts.cmd = sc_cmd::read;
	read_opts.addr = sc_diag_err_addr;
	read_opts.read_len = sc_diag_err_words;
	err_req = sc_build_request(read_opts);
	rc = sc_run_request(dev, read_opts, err_req, &err_payload);
	if (rc)
		return rc;

	read_opts.addr = sc_diag_main_addr;
	read_opts.read_len = sc_diag_main_words;
	main_req = sc_build_request(read_opts);
	rc = sc_run_request(dev, read_opts, main_req, &main_payload);
	if (rc)
		return rc;

	if (err_payload.size() != sc_diag_err_words || main_payload.size() != sc_diag_main_words) {
		pr_err("unexpected diagnostic payload length");
		return 5;
	}

	pr_info("decoded SC hub diagnostic counters:");
	std::cout
		<< "  ERR_FLAGS     = " << hex_u32(err_payload[0]) << '\n'
		<< "  ERR_COUNT     = " << hex_u32(err_payload[1]) << '\n'
		<< "  EXT_PKT_RD    = " << hex_u32(main_payload[0]) << '\n'
		<< "  EXT_PKT_WR    = " << hex_u32(main_payload[1]) << '\n'
		<< "  EXT_WORD_RD   = " << hex_u32(main_payload[2]) << '\n'
		<< "  EXT_WORD_WR   = " << hex_u32(main_payload[3]) << '\n'
		<< "  LAST_RD_ADDR  = " << hex_u32(main_payload[4]) << '\n'
		<< "  LAST_RD_DATA  = " << hex_u32(main_payload[5]) << '\n'
		<< "  LAST_WR_ADDR  = " << hex_u32(main_payload[6]) << '\n'
		<< "  LAST_WR_DATA  = " << hex_u32(main_payload[7]) << '\n'
		<< "  PKT_DROP_CNT  = " << hex_u32(main_payload[8]) << '\n';

	return 0;
}

static void sc_print_board_status(mudaq::MudaqDevice& dev)
{
	std::cout
		<< "board:\n"
		<< "  PLL_LOCKED_REGISTER_R      = " << hex_u32(dev.read_register_ro(PLL_LOCKED_REGISTER_R)) << '\n'
		<< "  LINK_LOCKED_LOW_REGISTER_R = " << hex_u32(dev.read_register_ro(LINK_LOCKED_LOW_REGISTER_R)) << '\n'
		<< "  LINK_LOCKED_HIGH_REGISTER_R= " << hex_u32(dev.read_register_ro(LINK_LOCKED_HIGH_REGISTER_R)) << '\n'
		<< "  RESET_LINK_STATUS_REGISTER_R = " << hex_u32(dev.read_register_ro(RESET_LINK_STATUS_REGISTER_R)) << '\n';
}

} /* namespace */

int main(int argc, char **argv)
{
	sc_opts opts;
	sc_request req;
	int rc = 0;

	if (!parse_opts(argc, argv, &opts))
		return 1;

	mudaq::DmaMudaqDevice dev(opts.device);
	if (!dev.open()) {
		pr_err("failed to open device " + opts.device);
		return 2;
	}
	if (!dev.is_ok()) {
		pr_err("device is not ready after open");
		return 2;
	}

	if (!opts.quiet)
		sc_print_board_status(dev);

	if (!sc_prepare(dev, opts))
		return 2;

	switch (opts.cmd) {
	case sc_cmd::read:
	case sc_cmd::write:
		req = sc_build_request(opts);
		rc = sc_run_request(dev, opts, req, nullptr);
		break;
	case sc_cmd::diag:
		rc = sc_run_diag(dev, opts);
		break;
	default:
		pr_err("invalid command");
		rc = 1;
		break;
	}

	return rc;
}
