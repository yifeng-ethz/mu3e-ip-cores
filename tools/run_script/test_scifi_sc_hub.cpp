#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>

#include "../../switching_pc/slowcontrol/FEBSlowcontrolInterface.h"
#include "../../switching_pc/slowcontrol/linkstatus.h"
#include "../../switching_pc/slowcontrol/mappedfeb.h"
#include "a10_pcie_registers.h"
#include "mudaq_device.h"

namespace {

constexpr uint32_t kScifiDatapathBridgeBaseWord = 0x10000u / 4u;
constexpr uint32_t kDeviceInfoBaseWord = 0x0003f000u / 4u;
constexpr uint32_t kScHubMaxBurstWords = 255u;

struct Probe {
        const char *name;
        uint32_t start_word;
        uint32_t n_words;
        bool is_hist_bin;
};

constexpr std::array<Probe, 10> kDefaultProbes = {{
        {"scratch_pad_ram.word0", 0x0000u, 1u, false},
        {"device_info.words[0:3]", kDeviceInfoBaseWord, 4u, false},
        {"lvds_rx_controller_pro_0.csr", kScifiDatapathBridgeBaseWord + (0x0000u / 4u), 0x40u / 4u, false},
        {"mutrig_frame_deassembly_0.csr", kScifiDatapathBridgeBaseWord + (0x0900u / 4u), 0x10u / 4u, false},
        {"mts_preprocessor_0.csr", kScifiDatapathBridgeBaseWord + (0x4000u / 4u), 0x20u / 4u, false},
        {"histogram_statistics_0.csr", kScifiDatapathBridgeBaseWord + (0xA400u / 4u), 0x40u / 4u, false},
        {"histogram_statistics_0.hist_bin", kScifiDatapathBridgeBaseWord + (0xA000u / 4u), 0x400u / 4u, true},
        {"hit_stack_subsystem_0_ring_buffer_cam_0.csr", kScifiDatapathBridgeBaseWord + (0xB000u / 4u), 0x80u / 4u, false},
        {"mutrig_injector_0.csr", kScifiDatapathBridgeBaseWord + (0xB200u / 4u), 0x40u / 4u, false},
        {"hit_stack_subsystem_0_feb_frame_assembly_0.csr", kScifiDatapathBridgeBaseWord + (0xD000u / 4u), 0x40u / 4u, false},
}};

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

std::string hex32(uint32_t value)
{
        char buf[16];
        std::snprintf(buf, sizeof(buf), "0x%08X", value);
        return std::string(buf);
}

const char *rc_name(int rc)
{
        using ERRCODES = FEBSlowcontrolInterface::ERRCODES;

        switch (rc) {
        case ERRCODES::OK:
                return "OK";
        case ERRCODES::ADDR_INVALID:
                return "ADDR_INVALID";
        case ERRCODES::SIZE_INVALID:
                return "SIZE_INVALID";
        case ERRCODES::SIZE_ZERO:
                return "SIZE_ZERO";
        case ERRCODES::FPGA_BUSY:
                return "FPGA_BUSY";
        case ERRCODES::FPGA_TIMEOUT:
                return "FPGA_TIMEOUT";
        case ERRCODES::BAD_PACKET:
                return "BAD_PACKET";
        case ERRCODES::WRONG_SIZE:
                return "WRONG_SIZE";
        case ERRCODES::NIOS_RPC_TIMEOUT:
                return "NIOS_RPC_TIMEOUT";
        case ERRCODES::LINK_BAD:
                return "LINK_BAD";
        case ERRCODES::SETTING_FEBIDS_FAILED:
                return "SETTING_FEBIDS_FAILED";
        case ERRCODES::SETTING_LINKMASK_FAILED:
                return "SETTING_LINKMASK_FAILED";
        default:
                return "UNKNOWN";
        }
}

mappedFEB make_test_feb(uint8_t sb_port)
{
        static LinkStatus link_status;
        static std::vector<uint16_t> empty_u16;

        link_status.SetStatus(LINKSTATUS::OK);

        return mappedFEB(
                FEBTYPE::Unused,
                link_status,
                sb_port,
                0,
                sb_port,
                FEBLINKMASK::SCOn,
                "test_scifi_sc_hub",
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                empty_u16,
                empty_u16,
                empty_u16,
                empty_u16,
                empty_u16,
                0);
}

int read_words(
        FEBSlowcontrolInterface &sc,
        const mappedFEB &feb,
        uint32_t start_word,
        uint32_t n_words,
        std::vector<uint32_t> &out_words)
{
        out_words.assign(n_words, 0);
        for (uint32_t offset = 0; offset < n_words; ) {
                const uint32_t chunk_words = std::min(kScHubMaxBurstWords, n_words - offset);
                std::vector<uint32_t> chunk(chunk_words, 0);
                const int rc = sc.FEB_read(feb, start_word + offset, chunk, false, true);
                if (rc != FEBSlowcontrolInterface::ERRCODES::OK) {
                        return rc;
                }
                std::copy(chunk.begin(), chunk.end(), out_words.begin() + offset);
                offset += chunk_words;
        }
        return FEBSlowcontrolInterface::ERRCODES::OK;
}

void print_words(const Probe &probe, const std::vector<uint32_t> &words)
{
        std::cout << probe.name
                  << " start_word=" << hex32(probe.start_word)
                  << " words=" << std::dec << words.size() << '\n';

        for (size_t i = 0; i < words.size(); ++i) {
                std::cout << "        +0x"
                          << std::hex << std::setw(4) << std::setfill('0') << (static_cast<uint32_t>(i) * 4u)
                          << "  "
                          << hex32(words[i])
                          << std::dec << '\n';
        }
}

void print_usage()
{
        std::cout << "Usage:\n";
        std::cout << "        test_scifi_sc_hub <sb_port> [--include-hist-bin] [--recover-all-reset] [--device PATH]\n";
        std::cout << '\n';
        std::cout << "Notes:\n";
        std::cout << "        - sb_port is the physical SWB slow-control port selected by the active LinksLabor mapping.\n";
        std::cout << "        - This tool is read-only by default and uses FEBSlowcontrolInterface over /dev/mudaq0.\n";
        std::cout << "        - Probe addresses match fe_scifi debug_sc_system/feb_system via sc_hub word addressing.\n";
        std::cout << "        - --recover-all-reset pulses RESET_BIT_ALL before probing, then reapplies the selected FEB enable bit.\n";
}

} // namespace

int main(int argc, char *argv[])
{
        if (argc < 2) {
                print_usage();
                return 1;
        }

        uint32_t sb_port_u32 = 0;
        if (!parse_u32(argv[1], sb_port_u32) || sb_port_u32 > 63u) {
                std::cerr << "Invalid sb_port: " << argv[1] << '\n';
                return 1;
        }

        bool include_hist_bin = false;
        bool recover_all_reset = false;
        std::string device_path = "/dev/mudaq0";

        for (int i = 2; i < argc; ++i) {
                const std::string arg(argv[i]);
                if (arg == "--include-hist-bin") {
                        include_hist_bin = true;
                        continue;
                }
                if (arg == "--recover-all-reset") {
                        recover_all_reset = true;
                        continue;
                }
                if (arg == "--device") {
                        if (i + 1 >= argc) {
                                std::cerr << "Missing value for --device\n";
                                return 1;
                        }
                        device_path = argv[++i];
                        continue;
                }
                if (arg == "-h" || arg == "--help") {
                        print_usage();
                        return 0;
                }
                std::cerr << "Unknown argument: " << arg << '\n';
                print_usage();
                return 1;
        }

        mudaq::DmaMudaqDevice mu(device_path);
        if (!mu.open()) {
                std::cerr << "Could not open device: " << device_path << '\n';
                return 1;
        }
        if (!mu.is_ok()) {
                std::cerr << "MuDAQ device not OK: " << device_path << '\n';
                return 1;
        }

        if (sb_port_u32 >= 32u) {
                std::cerr << "sb_port must be < 32 for FEB_ENABLE_REGISTER_W bitmasking\n";
                return 1;
        }

        const uint32_t enable_mask = (1u << sb_port_u32);
        const uint32_t old_enable = mu.read_register_rw(FEB_ENABLE_REGISTER_W);
        const uint32_t old_reset = mu.read_register_rw(RESET_REGISTER_W);
        const uint32_t old_sc_state = mu.read_register_ro(SC_STATE_REGISTER_R);
        const uint32_t old_sc_top = (mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) + 1u) & 0xffffu;

        if (recover_all_reset) {
                mu.write_register(RESET_REGISTER_W, 0x0);
                mu.write_register_wait(RESET_REGISTER_W, SET_RESET_BIT_ALL(0), 1000);
                mu.write_register(RESET_REGISTER_W, 0x0);
        }

        mu.write_register(FEB_ENABLE_REGISTER_W, enable_mask);

        FEBSlowcontrolInterface sc(mu, "test_scifi_sc_hub");
        const auto feb = make_test_feb(static_cast<uint8_t>(sb_port_u32));

        bool all_ok = true;

        std::cout << "SC hub directed readback on SWB port " << sb_port_u32 << '\n';
        std::cout << "Device: " << device_path << '\n';
        std::cout << "Recovery: " << (recover_all_reset ? "RESET_BIT_ALL pulse applied" : "none") << '\n';
        std::cout << "RESET_REGISTER_W old=" << hex32(old_reset)
                  << " current=" << hex32(mu.read_register_rw(RESET_REGISTER_W)) << '\n';
        std::cout << "SC_STATE_REGISTER_R old=" << hex32(old_sc_state)
                  << " current=" << hex32(mu.read_register_ro(SC_STATE_REGISTER_R)) << '\n';
        std::cout << "SC secondary top old=" << hex32(old_sc_top)
                  << " current=" << hex32((mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) + 1u) & 0xffffu) << '\n';
        std::cout << "FEB_ENABLE_REGISTER_W old=" << hex32(old_enable)
                  << " new=" << hex32(enable_mask) << '\n';

        for (const auto &probe : kDefaultProbes) {
                if (probe.is_hist_bin && !include_hist_bin) {
                        continue;
                }

                std::vector<uint32_t> words;
                const int rc = read_words(sc, feb, probe.start_word, probe.n_words, words);
                if (rc != FEBSlowcontrolInterface::ERRCODES::OK) {
                        all_ok = false;
                        std::cout << "[FAIL] " << probe.name
                                  << " start_word=" << hex32(probe.start_word)
                                  << " words=" << std::dec << probe.n_words
                                  << " rc=" << rc_name(rc)
                                  << " (" << rc << ")\n";
                        continue;
                }

                std::cout << "[ OK ] ";
                print_words(probe, words);
        }

        mu.write_register(FEB_ENABLE_REGISTER_W, old_enable);
        std::cout << "FEB_ENABLE_REGISTER_W restored to " << hex32(old_enable) << '\n';

        return all_ok ? 0 : 1;
}
