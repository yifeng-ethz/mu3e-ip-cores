#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <random>
#include <string>
#include <vector>

#include "../../switching_pc/slowcontrol/FEBSlowcontrolInterface.h"
#include "a10_pcie_registers.h"
#include "mudaq_device.h"

using namespace std::chrono;

namespace {

constexpr uint32_t kScratchBaseWord = 0x0000u;
constexpr uint32_t kDefaultScratchWords = 256u;
constexpr uint32_t kDefaultOps = 512u;
constexpr uint32_t kDefaultBurstMax = 16u;
constexpr uint32_t kMaxScWordsPerTransaction = 255u;

struct Options {
        uint8_t sb_port = 0;
        uint32_t scratch_words = kDefaultScratchWords;
        uint32_t ops = kDefaultOps;
        uint32_t burst_max = kDefaultBurstMax;
        uint64_t seed = 0;
        bool seed_explicit = false;
        bool recover_all_reset = false;
        std::string device_path = "/dev/mudaq0";
};

bool parse_u32(const char *text, uint32_t &value)
{
        if (!text || !*text) {
                return false;
        }

        char *end = nullptr;
        errno = 0;
        const unsigned long parsed = std::strtoul(text, &end, 0);
        if (errno != 0 || end == text || *end != '\0') {
                return false;
        }

        value = static_cast<uint32_t>(parsed);
        return true;
}

bool parse_u64(const char *text, uint64_t &value)
{
        if (!text || !*text) {
                return false;
        }

        char *end = nullptr;
        errno = 0;
        const unsigned long long parsed = std::strtoull(text, &end, 0);
        if (errno != 0 || end == text || *end != '\0') {
                return false;
        }

        value = static_cast<uint64_t>(parsed);
        return true;
}

std::string hex32(uint32_t value)
{
        char buf[16];
        std::snprintf(buf, sizeof(buf), "0x%08X", value);
        return std::string(buf);
}

void print_usage()
{
        std::cout << "Usage:\n";
        std::cout << "        test_scifi_scratchpad_random <sb_port> [--words N] [--ops N] [--burst-max N]\n";
        std::cout << "                                        [--seed N] [--recover-all-reset] [--device PATH]\n";
        std::cout << '\n';
        std::cout << "Notes:\n";
        std::cout << "        - Only scratchpad space at sc_hub word address 0x0000 is touched.\n";
        std::cout << "        - The test snapshots the original contents and restores them before exit.\n";
        std::cout << "        - Transactions use the raw SC packet path, matching test_slowcontrol.\n";
}

bool parse_args(int argc, char *argv[], Options &opt)
{
        if (argc < 2) {
                return false;
        }

        uint32_t sb_port_u32 = 0;
        if (!parse_u32(argv[1], sb_port_u32) || sb_port_u32 > 31u) {
                std::cerr << "Invalid sb_port: " << argv[1] << '\n';
                return false;
        }
        opt.sb_port = static_cast<uint8_t>(sb_port_u32);

        for (int i = 2; i < argc; ++i) {
                const std::string arg(argv[i]);
                if (arg == "--words") {
                        uint32_t value = 0;
                        if (i + 1 >= argc || !parse_u32(argv[++i], value) || value == 0) {
                                std::cerr << "Invalid --words value\n";
                                return false;
                        }
                        opt.scratch_words = value;
                        continue;
                }
                if (arg == "--ops") {
                        uint32_t value = 0;
                        if (i + 1 >= argc || !parse_u32(argv[++i], value) || value == 0) {
                                std::cerr << "Invalid --ops value\n";
                                return false;
                        }
                        opt.ops = value;
                        continue;
                }
                if (arg == "--burst-max") {
                        uint32_t value = 0;
                        if (i + 1 >= argc || !parse_u32(argv[++i], value) || value == 0 || value > kMaxScWordsPerTransaction) {
                                std::cerr << "Invalid --burst-max value\n";
                                return false;
                        }
                        opt.burst_max = value;
                        continue;
                }
                if (arg == "--seed") {
                        uint64_t value = 0;
                        if (i + 1 >= argc || !parse_u64(argv[++i], value)) {
                                std::cerr << "Invalid --seed value\n";
                                return false;
                        }
                        opt.seed = value;
                        opt.seed_explicit = true;
                        continue;
                }
                if (arg == "--recover-all-reset") {
                        opt.recover_all_reset = true;
                        continue;
                }
                if (arg == "--device") {
                        if (i + 1 >= argc) {
                                std::cerr << "Missing value for --device\n";
                                return false;
                        }
                        opt.device_path = argv[++i];
                        continue;
                }
                if (arg == "-h" || arg == "--help") {
                        print_usage();
                        std::exit(0);
                }
                std::cerr << "Unknown argument: " << arg << '\n';
                return false;
        }

        return true;
}

void maybe_sleep_us(uint32_t usec)
{
        if (usec != 0) {
                usleep(usec);
        }
}

uint32_t read_sc_top(mudaq::DmaMudaqDevice &mu)
{
        return (mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) + 1u) & 0xffffu;
}

void rmem_incr(uint32_t &addr)
{
        addr = ((addr + 1u) == MUDAQ_MEM_RO_LEN) ? 0u : (addr + 1u);
}

uint32_t rmem_distance(uint32_t from, uint32_t to)
{
        if (to >= from) {
                return to - from;
        }
        return (MUDAQ_MEM_RO_LEN - from) + to;
}

uint32_t decode_pkt_type(uint32_t header)
{
        return (header >> 24) & 0x3u;
}

uint32_t decode_link_index(uint32_t header)
{
        return (header >> 8) & 0xFFu;
}

bool sc_read_raw(
        mudaq::DmaMudaqDevice &mu,
        uint32_t link_index,
        uint32_t startaddr,
        uint32_t len_words,
        std::vector<uint32_t> &out)
{
        uint32_t sc_rmem_ptr = read_sc_top(mu);

        mu.write_memory_rw(0, PACKET_TYPE_SC << 26 | PACKET_TYPE_SC_READ << 24 | ((link_index & 0xFFu) << 8) | 0xBCu);
        mu.write_memory_rw(1, startaddr);
        mu.write_memory_rw(2, len_words);
        mu.write_memory_rw(3, 0x0000009cu);
        (void)mu.read_memory_rw(3);

        mu.write_register(SC_MAIN_LENGTH_REGISTER_W, 2);
        mu.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
        mu.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);

        uint32_t count = 0;
        while (count < 10000u) {
                if (mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1u) {
                        break;
                }
                count++;
        }
        if (count >= 10000u) {
                std::cerr << "SC read timeout waiting for SC_MAIN_STATUS\n";
                return false;
        }

        const uint32_t min_words = 4u;
        const auto deadline = steady_clock::now() + milliseconds(5000);
        while (steady_clock::now() < deadline) {
                const uint32_t fpga_rmem_addr = read_sc_top(mu);

                if (sc_rmem_ptr == fpga_rmem_addr) {
                        continue;
                }

                if (rmem_distance(sc_rmem_ptr, fpga_rmem_addr) < min_words) {
                        continue;
                }

                const uint32_t hdr_addr = sc_rmem_ptr;
                const uint32_t header = mu.read_memory_ro(sc_rmem_ptr);
                if ((header & 0x1c0000bcu) != 0x1c0000bcu) {
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                rmem_incr(sc_rmem_ptr);
                const uint32_t start_addr_word = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);
                const uint32_t len_word = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);

                const bool is_response = (len_word & 0x10000u) != 0u;
                uint32_t payload_len = (len_word & 0xFFFFu);
                const uint32_t pkt_type = decode_pkt_type(header);
                const bool is_read_pkt = (pkt_type == PACKET_TYPE_SC_READ) || (pkt_type == PACKET_TYPE_SC_READ_NONINCREMENTING);
                const bool is_write_pkt = (pkt_type == PACKET_TYPE_SC_WRITE) || (pkt_type == PACKET_TYPE_SC_WRITE_NONINCREMENTING);
                if (is_write_pkt && is_response) {
                        payload_len = 0u;
                }

                if (payload_len > kMaxScWordsPerTransaction) {
                        sc_rmem_ptr = hdr_addr;
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                const uint32_t total_words = 4u + payload_len;
                if (rmem_distance(hdr_addr, fpga_rmem_addr) < total_words) {
                        sc_rmem_ptr = hdr_addr;
                        continue;
                }

                std::vector<uint32_t> payload;
                payload.reserve(payload_len);
                for (uint32_t i = 0; i < payload_len; ++i) {
                        payload.push_back(mu.read_memory_ro(sc_rmem_ptr));
                        rmem_incr(sc_rmem_ptr);
                }

                const uint32_t trailer = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);
                if (trailer != 0x9cu) {
                        sc_rmem_ptr = hdr_addr;
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                const uint32_t pkt_link = decode_link_index(header);
                const uint32_t pkt_addr = start_addr_word & 0xFFFFu;
                if (is_response && is_read_pkt && pkt_link == link_index && pkt_addr == startaddr && payload_len == len_words) {
                        out = std::move(payload);
                        return true;
                }
        }

        std::cerr << "SC read: no matching response for addr=" << hex32(startaddr)
                  << " len=" << std::dec << len_words << '\n';
        return false;
}

bool sc_write_raw(
        mudaq::DmaMudaqDevice &mu,
        uint32_t link_index,
        uint32_t startaddr,
        const std::vector<uint32_t> &words)
{
        uint32_t sc_rmem_ptr = read_sc_top(mu);

        mu.write_memory_rw(0, PACKET_TYPE_SC << 26 | PACKET_TYPE_SC_WRITE << 24 | ((link_index & 0xFFu) << 8) | 0xBCu);
        mu.write_memory_rw(1, startaddr);
        mu.write_memory_rw(2, static_cast<uint32_t>(words.size()));
        for (size_t i = 0; i < words.size(); ++i) {
                mu.write_memory_rw(3 + i, words[i]);
        }
        mu.write_memory_rw(3 + words.size(), 0x0000009cu);
        (void)mu.read_memory_rw(3 + words.size());

        mu.write_register(SC_MAIN_LENGTH_REGISTER_W, 2 + static_cast<uint32_t>(words.size()));
        mu.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
        mu.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);

        uint32_t count = 0;
        while (count < 10000u) {
                if (mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1u) {
                        break;
                }
                count++;
        }
        if (count >= 10000u) {
                std::cerr << "SC write timeout waiting for SC_MAIN_STATUS\n";
                return false;
        }

        const uint32_t min_words = 4u;
        const auto deadline = steady_clock::now() + milliseconds(5000);
        while (steady_clock::now() < deadline) {
                const uint32_t fpga_rmem_addr = read_sc_top(mu);

                if (sc_rmem_ptr == fpga_rmem_addr) {
                        continue;
                }

                if (rmem_distance(sc_rmem_ptr, fpga_rmem_addr) < min_words) {
                        continue;
                }

                const uint32_t hdr_addr = sc_rmem_ptr;
                const uint32_t header = mu.read_memory_ro(sc_rmem_ptr);
                if ((header & 0x1c0000bcu) != 0x1c0000bcu) {
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                rmem_incr(sc_rmem_ptr);
                const uint32_t start_addr_word = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);
                const uint32_t len_word = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);

                const bool is_response = (len_word & 0x10000u) != 0u;
                uint32_t payload_len = (len_word & 0xFFFFu);
                const uint32_t pkt_type = decode_pkt_type(header);
                const bool is_write_pkt = (pkt_type == PACKET_TYPE_SC_WRITE) || (pkt_type == PACKET_TYPE_SC_WRITE_NONINCREMENTING);
                if (is_write_pkt && is_response) {
                        payload_len = 0u;
                }

                if (payload_len > kMaxScWordsPerTransaction) {
                        sc_rmem_ptr = hdr_addr;
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                const uint32_t total_words = 4u + payload_len;
                if (rmem_distance(hdr_addr, fpga_rmem_addr) < total_words) {
                        sc_rmem_ptr = hdr_addr;
                        continue;
                }

                for (uint32_t i = 0; i < payload_len; ++i) {
                        (void)mu.read_memory_ro(sc_rmem_ptr);
                        rmem_incr(sc_rmem_ptr);
                }

                const uint32_t trailer = mu.read_memory_ro(sc_rmem_ptr);
                rmem_incr(sc_rmem_ptr);
                if (trailer != 0x9cu) {
                        sc_rmem_ptr = hdr_addr;
                        rmem_incr(sc_rmem_ptr);
                        continue;
                }

                const uint32_t pkt_link = decode_link_index(header);
                const uint32_t pkt_addr = start_addr_word & 0xFFFFu;
                if (is_response && is_write_pkt && pkt_link == link_index && pkt_addr == startaddr) {
                        return true;
                }
        }

        std::cerr << "SC write: no matching response for addr=" << hex32(startaddr)
                  << " len=" << std::dec << words.size() << '\n';
        return false;
}

bool read_window(
        mudaq::DmaMudaqDevice &mu,
        uint32_t link_index,
        uint32_t start_word,
        std::vector<uint32_t> &words,
        uint32_t chunk_limit_words)
{
        const uint32_t effective_chunk_limit = std::max<uint32_t>(1u, std::min<uint32_t>(kMaxScWordsPerTransaction, chunk_limit_words));
        for (uint32_t offset = 0; offset < words.size(); offset += effective_chunk_limit) {
                const uint32_t chunk_words = std::min<uint32_t>(effective_chunk_limit, words.size() - offset);
                std::vector<uint32_t> chunk;
                if (!sc_read_raw(mu, link_index, start_word + offset, chunk_words, chunk)) {
                        return false;
                }
                std::copy(chunk.begin(), chunk.end(), words.begin() + offset);
        }
        return true;
}

bool write_window(
        mudaq::DmaMudaqDevice &mu,
        uint32_t link_index,
        uint32_t start_word,
        const std::vector<uint32_t> &words,
        uint32_t chunk_limit_words)
{
        const uint32_t effective_chunk_limit = std::max<uint32_t>(1u, std::min<uint32_t>(kMaxScWordsPerTransaction, chunk_limit_words));
        for (uint32_t offset = 0; offset < words.size(); offset += effective_chunk_limit) {
                const uint32_t chunk_words = std::min<uint32_t>(effective_chunk_limit, words.size() - offset);
                const std::vector<uint32_t> chunk(words.begin() + offset, words.begin() + offset + chunk_words);
                if (!sc_write_raw(mu, link_index, start_word + offset, chunk)) {
                        return false;
                }
        }
        return true;
}

void print_mismatch(
        uint32_t op_index,
        uint32_t start_word,
        const std::vector<uint32_t> &expected,
        const std::vector<uint32_t> &got)
{
        std::cerr << "[FAIL] mismatch after op " << std::dec << op_index
                  << " start_word=" << hex32(start_word)
                  << " words=" << expected.size() << '\n';
        for (size_t i = 0; i < expected.size(); ++i) {
                if (expected[i] != got[i]) {
                        std::cerr << "        +" << std::setw(4) << std::setfill('0') << std::hex << (i * 4u)
                                  << " expected=" << hex32(expected[i])
                                  << " got=" << hex32(got[i]) << std::dec << '\n';
                }
        }
}

} // namespace

int main(int argc, char *argv[])
{
        Options opt;
        if (!parse_args(argc, argv, opt)) {
                print_usage();
                return 1;
        }

        if (!opt.seed_explicit) {
                opt.seed = 0x5343485542ULL ^ (static_cast<uint64_t>(opt.sb_port) << 8)
                           ^ (static_cast<uint64_t>(opt.scratch_words) << 20)
                           ^ static_cast<uint64_t>(opt.ops);
        }

        mudaq::DmaMudaqDevice mu(opt.device_path);
        if (!mu.open()) {
                std::cerr << "Could not open device: " << opt.device_path << '\n';
                return 1;
        }
        if (!mu.is_ok()) {
                std::cerr << "MuDAQ device not OK: " << opt.device_path << '\n';
                return 1;
        }

        const uint32_t enable_mask = (1u << opt.sb_port);
        const uint32_t old_enable = mu.read_register_rw(FEB_ENABLE_REGISTER_W);
        const uint32_t old_reset = mu.read_register_rw(RESET_REGISTER_W);

        if (opt.recover_all_reset) {
                mu.write_register(RESET_REGISTER_W, 0x0);
                mu.write_register_wait(RESET_REGISTER_W, SET_RESET_BIT_ALL(0), 1000);
                mu.write_register(RESET_REGISTER_W, 0x0);
        }

        mu.write_register(FEB_ENABLE_REGISTER_W, enable_mask);

        {
                const uint32_t current_reset = mu.read_register_rw(RESET_REGISTER_W);
                mu.write_register_wait(RESET_REGISTER_W, SET_RESET_BIT_SC_MAIN(current_reset), 1000);
                mu.write_register(RESET_REGISTER_W, UNSET_RESET_BIT_SC_MAIN(current_reset));
        }
        mu.toggle_register(RESET_REGISTER_W, SET_RESET_BIT_SC_SECONDARY(0), 1000);
        for (uint32_t i = 0; i < 2000u; ++i) {
                if ((mu.read_register_ro(SC_STATE_REGISTER_R) & 0x20000000u) == 0x20000000u) {
                        break;
                }
                maybe_sleep_us(1000);
        }

        std::cout << "Scratchpad random access test on SWB port " << std::dec << static_cast<uint32_t>(opt.sb_port) << '\n';
        std::cout << "Device: " << opt.device_path << '\n';
        std::cout << "Scratch words: " << opt.scratch_words << '\n';
        std::cout << "Ops: " << opt.ops << '\n';
        std::cout << "Burst max: " << opt.burst_max << '\n';
        std::cout << "Seed: 0x" << std::hex << opt.seed << std::dec << '\n';
        std::cout << "PLL_LOCKED_REGISTER_R: " << hex32(mu.read_register_ro(PLL_LOCKED_REGISTER_R)) << '\n';
        std::cout << "LINK_LOCKED_LOW_REGISTER_R: " << hex32(mu.read_register_ro(LINK_LOCKED_LOW_REGISTER_R)) << '\n';
        std::cout << "SC Secondary status: " << hex32(mu.read_register_ro(SC_STATE_REGISTER_R)) << '\n';
        std::cout << "FEB enable old=" << hex32(old_enable)
                  << " current=" << hex32(mu.read_register_rw(FEB_ENABLE_REGISTER_W)) << '\n';

        std::vector<uint32_t> original(opt.scratch_words, 0);
        if (!read_window(mu, opt.sb_port, kScratchBaseWord, original, opt.burst_max)) {
                std::cerr << "[FAIL] initial scratchpad snapshot failed\n";
                mu.write_register(FEB_ENABLE_REGISTER_W, old_enable);
                mu.write_register(RESET_REGISTER_W, old_reset);
                return 1;
        }

        std::vector<uint32_t> shadow = original;
        std::mt19937_64 rng(opt.seed);
        std::uniform_int_distribution<uint32_t> word_dist(0u, opt.scratch_words - 1u);
        std::uniform_int_distribution<uint32_t> burst_dist(1u, std::max<uint32_t>(1u, opt.burst_max));
        std::uniform_int_distribution<uint32_t> value_dist(0u, 0xFFFFFFFFu);

        uint64_t verified_words = 0;
        bool ok = true;

        for (uint32_t op = 0; op < opt.ops; ++op) {
                const uint32_t start = word_dist(rng);
                const uint32_t max_len = std::min<uint32_t>(burst_dist(rng), opt.scratch_words - start);

                std::vector<uint32_t> pattern(max_len, 0);
                for (auto &word : pattern) {
                        word = value_dist(rng);
                }

                if (!write_window(mu, opt.sb_port, kScratchBaseWord + start, pattern, opt.burst_max)) {
                        std::cerr << "[FAIL] write op " << std::dec << op
                                  << " start_word=" << hex32(kScratchBaseWord + start)
                                  << " words=" << pattern.size() << '\n';
                        ok = false;
                        break;
                }

                std::vector<uint32_t> readback(max_len, 0);
                if (!read_window(mu, opt.sb_port, kScratchBaseWord + start, readback, opt.burst_max)) {
                        std::cerr << "[FAIL] readback op " << std::dec << op
                                  << " start_word=" << hex32(kScratchBaseWord + start)
                                  << " words=" << pattern.size() << '\n';
                        ok = false;
                        break;
                }

                if (readback != pattern) {
                        print_mismatch(op, kScratchBaseWord + start, pattern, readback);
                        ok = false;
                        break;
                }

                std::copy(pattern.begin(), pattern.end(), shadow.begin() + start);
                verified_words += pattern.size();

                if (((op + 1u) % 64u) == 0u || (op + 1u) == opt.ops) {
                        std::cout << "[ OK ] op " << std::setw(4) << std::setfill(' ') << (op + 1u)
                                  << "/" << opt.ops
                                  << " start_word=" << hex32(kScratchBaseWord + start)
                                  << " words=" << pattern.size()
                                  << " verified_words=" << std::dec << verified_words << '\n';
                }
        }

        if (ok) {
                std::vector<uint32_t> full_readback(opt.scratch_words, 0);
                if (!read_window(mu, opt.sb_port, kScratchBaseWord, full_readback, opt.burst_max)) {
                        std::cerr << "[FAIL] final full snapshot failed\n";
                        ok = false;
                } else if (full_readback != shadow) {
                        std::cerr << "[FAIL] final full snapshot does not match shadow model\n";
                        for (size_t i = 0; i < full_readback.size(); ++i) {
                                if (full_readback[i] != shadow[i]) {
                                        std::cerr << "        word[" << std::dec << i << "] expected="
                                                  << hex32(shadow[i]) << " got=" << hex32(full_readback[i]) << '\n';
                                        break;
                                }
                        }
                        ok = false;
                } else {
                        std::cout << "[ OK ] final full snapshot matches shadow model\n";
                }
        }

        if (!write_window(mu, opt.sb_port, kScratchBaseWord, original, opt.burst_max)) {
                std::cerr << "[FAIL] restore original scratchpad failed\n";
                ok = false;
        } else {
                std::vector<uint32_t> restored(opt.scratch_words, 0);
                if (!read_window(mu, opt.sb_port, kScratchBaseWord, restored, opt.burst_max)) {
                        std::cerr << "[FAIL] restore verify failed\n";
                        ok = false;
                } else if (restored != original) {
                        std::cerr << "[FAIL] scratchpad restore verify mismatch\n";
                        ok = false;
                } else {
                        std::cout << "[ OK ] scratchpad restored to original contents\n";
                }
        }

        mu.write_register(FEB_ENABLE_REGISTER_W, old_enable);
        mu.write_register(RESET_REGISTER_W, old_reset);
        std::cout << "FEB_ENABLE_REGISTER_W restored to " << hex32(old_enable) << '\n';

        if (!ok) {
                        return 1;
        }

        std::cout << "[PASS] scratchpad random access test complete\n";
        return 0;
}
