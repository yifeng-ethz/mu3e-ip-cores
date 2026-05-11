/**
 * test slow control Arria 10 to FEB
 *
 *
 * @author      Marius Koeppel <mkoeppel@uni-mainz.de>
 *
 * @date        2021-12-13
 */

#include <iostream>
#include <unistd.h>
#include <chrono>
#include <stdio.h>
#include <sstream>
#include <limits>
#include <fstream>
#include <math.h>
#include <sys/mman.h>
#include <cerrno>
#include <cstdlib>

#include <cassert>
#include <chrono>

using namespace std::chrono;


#include "../../switching_pc/slowcontrol/FEBSlowcontrolInterface.h"
#include "a10_pcie_registers.h"
#include "mudaq_device.h"

using namespace std;

void print_usage() {
    cout << "Usage: " << endl;
    cout << "       test_slowcontrol <link_index> [--once]" << endl;
    cout << "       test_slowcontrol <link_index> --set-id <value> [--once]" << endl;
    cout << "       test_slowcontrol <link_index> --write <addr> <value> [--once]" << endl;
    cout << "       test_slowcontrol <link_index> --read <addr> [len] [--once]" << endl;
    cout << "       test_slowcontrol <link_index> --dump-dp [--once]" << endl;
    cout << "       test_slowcontrol <link_index> --dump-dp-full [--once]" << endl;
    cout << endl;
    cout << "Notes:" << endl;
    cout << "  - Firmware expects bits[13:8] to contain the link index (0..63), not a one-hot mask." << endl;
    cout << "  - addr is 16-bit (Mu3e slow control address space)." << endl;
}

static bool parse_u32(const char* s, uint32_t& out)
{
    if (!s || !*s) return false;
    char* end = nullptr;
    errno = 0;
    unsigned long v = std::strtoul(s, &end, 0);
    if (errno != 0 || end == s || *end != '\0') return false;
    out = static_cast<uint32_t>(v);
    return true;
}

int main(int argc, char *argv[])
{
    if(argc < 2) {
        print_usage();
        return -1;
    }

    uint32_t link_index = 0;
    if (!parse_u32(argv[1], link_index)) {
        cout << "Invalid link_index: " << argv[1] << endl;
        return -1;
    }

    bool run_once = false;
    bool do_read = false;
    bool do_dump_dp = false;
    bool dump_dp_full = false;
    bool quiet = false;
    uint32_t startaddr = 0;
    uint32_t xfer_len = 0;
    vector<uint32_t> data = {0,1,6};
    xfer_len = data.size();

    for (int i = 2; i < argc; i++) {
        const string arg(argv[i]);
        if (arg == "--quiet") {
            quiet = true;
            continue;
        }
        if (arg == "--once") {
            run_once = true;
            continue;
        }
        if (arg == "--dump-dp" || arg == "--dump-dp-full") {
            do_dump_dp = true;
            dump_dp_full = (arg == "--dump-dp-full");
            do_read = true;
            run_once = true;
            continue;
        }
        if (arg == "--set-id") {
            if (i + 1 >= argc) {
                cout << "Missing value for --set-id" << endl;
                return -1;
            }
            uint32_t val = 0;
            if (!parse_u32(argv[i + 1], val)) {
                cout << "Invalid value for --set-id: " << argv[i + 1] << endl;
                return -1;
            }
            startaddr = 0xFC03; // FPGA_ID_REGISTER_RW (common/firmware/registers/feb_sc_registers.vhd)
            data = {val};
            xfer_len = data.size();
            do_read = false;
            run_once = true;
            i += 1;
            continue;
        }
        if (arg == "--write") {
            if (i + 2 >= argc) {
                cout << "Missing args for --write <addr> <value>" << endl;
                return -1;
            }
            uint32_t addr = 0;
            uint32_t val = 0;
            if (!parse_u32(argv[i + 1], addr) || !parse_u32(argv[i + 2], val)) {
                cout << "Invalid args for --write " << argv[i + 1] << " " << argv[i + 2] << endl;
                return -1;
            }
            if (addr >= (1u << 16)) {
                cout << "Address out of 16-bit range: 0x" << std::hex << addr << endl;
                return -1;
            }
            startaddr = addr;
            data = {val};
            xfer_len = data.size();
            do_read = false;
            run_once = true;
            i += 2;
            continue;
        }
        if (arg == "--read") {
            if (i + 1 >= argc) {
                cout << "Missing args for --read <addr> [len]" << endl;
                return -1;
            }
            uint32_t addr = 0;
            if (!parse_u32(argv[i + 1], addr)) {
                cout << "Invalid addr for --read: " << argv[i + 1] << endl;
                return -1;
            }
            uint32_t len = 1;
            if (i + 2 < argc) {
                // Optional length argument (only if next arg is not an option)
                if (argv[i + 2][0] != '-') {
                    if (!parse_u32(argv[i + 2], len) || len == 0) {
                        cout << "Invalid len for --read: " << argv[i + 2] << endl;
                        return -1;
                    }
                    i += 1;
                }
            }
            if (addr >= (1u << 16)) {
                cout << "Address out of 16-bit range: 0x" << std::hex << addr << endl;
                return -1;
            }
            startaddr = addr;
            data.clear();
            xfer_len = len;
            do_read = true;
            run_once = true;
            i += 1;
            continue;
        }
        if (arg == "--batch-wr-test") {
            // handled after arg parsing
            if (i + 2 >= argc) { cout << "Missing args for --batch-wr-test <base> <count>" << endl; return -1; }
            i += 2;
            continue;
        }
        if (arg == "-h" || arg == "--help") {
            print_usage();
            return 0;
        }

        cout << "Unknown arg: " << arg << endl;
        print_usage();
        return -1;
    }



    /* Open mudaq device */
    mudaq::DmaMudaqDevice mu("/dev/mudaq0");
    if ( !mu.open() ) {
      cout << "Could not open device " << endl;
      return -1;
    }
    if ( !mu.is_ok() ) return -1;
    cout << "MuDaq is ok" << endl;

    cout << std::hex;
    cout << "PLL_LOCKED_REGISTER_R: 0x" << mu.read_register_ro(PLL_LOCKED_REGISTER_R) << endl;
    cout << "LINK_LOCKED_LOW_REGISTER_R: 0x" << mu.read_register_ro(LINK_LOCKED_LOW_REGISTER_R) << endl;
    cout << "LINK_LOCKED_HIGH_REGISTER_R: 0x" << mu.read_register_ro(LINK_LOCKED_HIGH_REGISTER_R) << endl;
    cout << std::dec;

    cout << "Reset Link Status Reg " << RESET_LINK_STATUS_REGISTER_R << endl;

    // set FEB enable regs
    mu.write_register(FEB_ENABLE_REGISTER_W, 0xFFFFFFFF);

    // Reset slow control main/secondary (matches FEBSlowcontrolInterface init)
    {
        const uint32_t old_reset = mu.read_register_rw(RESET_REGISTER_W);
        mu.write_register_wait(RESET_REGISTER_W, SET_RESET_BIT_SC_MAIN(old_reset), 1000);
        mu.write_register(RESET_REGISTER_W, UNSET_RESET_BIT_SC_MAIN(old_reset));
    }
    mu.toggle_register(RESET_REGISTER_W, SET_RESET_BIT_SC_SECONDARY(0), 1000);
    // Wait until SC secondary reset is complete (clearing the RAM takes time)
    for (uint32_t i = 0; i < 2000; i++) {
        if ((mu.read_register_ro(SC_STATE_REGISTER_R) & 0x20000000) == 0x20000000) break;
        usleep(1000);
    }
    // Note: transceiver alignment noise fills the queue after reset.
    // trigger_sc() syncs the pointer just before each request to skip it.

    auto read_sc_top = [&]() -> uint32_t {
        return (mu.read_register_ro(MEM_WRITEADDR_LOW_REGISTER_R) + 1) & 0xFFFF;
    };

    auto rmem_incr = [&](uint32_t& addr) {
        addr = ((addr + 1) == MUDAQ_MEM_RO_LEN) ? 0 : (addr + 1);
    };

    auto rmem_distance = [&](uint32_t from, uint32_t to) -> uint32_t {
        // Number of words to advance from 'from' to reach 'to' in the ring buffer.
        if (to >= from) return to - from;
        return (MUDAQ_MEM_RO_LEN - from) + to;
    };

    auto decode_pkt_type = [&](uint32_t header) -> uint32_t {
        return (header >> 24) & 0x3;
    };

    auto decode_link_index = [&](uint32_t header) -> uint32_t {
        return (header >> 8) & 0xFF;
    };

    auto fmt_hex32 = [&](uint32_t v) -> std::string {
        char buf[32];
        snprintf(buf, sizeof(buf), "0x%08X", v);
        return std::string(buf);
    };

    // check for 0xFFFF
    uint32_t fpga_rmem_addr = read_sc_top();
    uint32_t sc_rmem_ptr = fpga_rmem_addr; // consume everything currently in the queue
    while(fpga_rmem_addr == 0xFFFF){
        fpga_rmem_addr = read_sc_top();
        cout << "Last written SC Sec Low: " << std::hex << fpga_rmem_addr << endl;
        usleep(1000);
    }
    sc_rmem_ptr = fpga_rmem_addr;

    auto trigger_sc = [&]() {
        auto start = high_resolution_clock::now();
        uint32_t packet_type = do_read ? PACKET_TYPE_SC_READ : PACKET_TYPE_SC_WRITE;

        if(startaddr >= pow(2,16)){
            cout << "Address out of range: " << std::hex << startaddr << endl;
        }

        if(!do_read && !data.size()){
            cout << "Length zero" << endl;
            return;
        }

        if(!(mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R)&0x1)){ // FPGA is busy, should not be here...
            cout << "FPGA busy" << endl;
        }

        // Sync to current SC secondary write pointer RIGHT BEFORE sending
        // the request.  This skips any transceiver alignment noise that
        // accumulated since the last reset.
        sc_rmem_ptr = read_sc_top();

        // two most significant bits are 0
        // NOTE: firmware expects bits[13:8] to contain the link index (0..63), not a one-hot mask
        // (see common/firmware/a10/swb/swb_sc_main.vhd).
        mu.write_memory_rw(0, PACKET_TYPE_SC << 26 | packet_type << 24 | ((uint16_t)(link_index & 0x000000FF)) << 8 | 0xBC);
        mu.write_memory_rw(1, startaddr);
        mu.write_memory_rw(2, xfer_len);

        if (!do_read) {
            for (uint32_t i = 0; i < data.size(); i++) {
                mu.write_memory_rw(3 + i, data[i]);
            }
            mu.write_memory_rw(3 + data.size(), 0x0000009c);
        } else {
            mu.write_memory_rw(3, 0x0000009c);
        }

        // Ensure the full command packet is visible to the FPGA before triggering SC main.
        // (PCIe posted writes / write-combining can otherwise lead to truncated packets.)
        (void)mu.read_memory_rw(do_read ? 3 : (3 + data.size()));

        // SC_MAIN_LENGTH_REGISTER_W starts from 1
        // length for SC Main does not include preamble and trailer, thats why it is 2+length
        mu.write_register(SC_MAIN_LENGTH_REGISTER_W, do_read ? 2 : (2 + data.size()));
        mu.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
        mu.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1,100);
        // firmware regs SC_MAIN_ENABLE_REGISTER_W so that it only starts on a 0->1 transition

        // check the memory for the main
        if (!quiet) {
            for (uint32_t i = 0; i < 4 + data.size(); i++) {
                cout << "WriteMem " << i << ": " << hex << mu.read_memory_rw(i) << endl;
            }
        }

        // check if SC Main is done
        uint32_t count = 0;
        while(count < 10000){
            if ( mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1 ) break;
            usleep(100);
            count++;
        }
        fpga_rmem_addr = read_sc_top();
        cout << "Last written SC Sec Low: " << std::hex << fpga_rmem_addr << endl;
        cout << "SC MAIN STATUS: " << std::hex << mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R) << endl;

        // Parse any new packets in the SC secondary queue
        const uint32_t min_words = 4; // header + startaddr + length + trailer (+payload)
        uint32_t safety = 0;
        while (sc_rmem_ptr != fpga_rmem_addr) {
            // Wait for a complete packet if the FPGA is still writing.
            if (rmem_distance(sc_rmem_ptr, fpga_rmem_addr) < min_words) {
                if (++safety > 1000) break;
                usleep(1000);
                fpga_rmem_addr = read_sc_top();
                continue;
            }

            const uint32_t hdr_addr = sc_rmem_ptr;
            const uint32_t header = mu.read_memory_ro(sc_rmem_ptr);
            if ((header & 0x1c0000bc) != 0x1c0000bc) {
                if (!quiet) {
                    cout << "SC secondary: bad preamble at 0x" << std::hex << hdr_addr
                         << " word=" << header << std::dec << endl;
                }
                // resync: skip one word
                rmem_incr(sc_rmem_ptr);
                continue;
            }

            rmem_incr(sc_rmem_ptr);
            const uint32_t start_addr_word = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);
            const uint32_t len_word = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);

            // sc_hub v2 puts the AVMM response code in bits[17:16] of the
            // length word.  Write acknowledgements still carry the original
            // request length in bits[15:0], but never return payload words.
            // Treat all secondary-queue write packets as zero-payload replies
            // or the trailer gets consumed as data and the parser walks
            // garbage through the rest of the ring.
            const uint32_t avmm_rsp = (len_word >> 16) & 0x3;
            uint32_t payload_len = (len_word & 0xFFFF);
            const uint32_t pkt_type = decode_pkt_type(header);
            const bool is_read_pkt = (pkt_type == PACKET_TYPE_SC_READ) || (pkt_type == PACKET_TYPE_SC_READ_NONINCREMENTING);
            const bool is_write_pkt = (pkt_type == PACKET_TYPE_SC_WRITE) || (pkt_type == PACKET_TYPE_SC_WRITE_NONINCREMENTING);
            if (is_write_pkt) {
                payload_len = 0;
            }

            const uint32_t total_words = 4 + payload_len;
            if (rmem_distance(hdr_addr, fpga_rmem_addr) < total_words) {
                // Incomplete packet, wait for more.
                sc_rmem_ptr = hdr_addr;
                if (++safety > 1000) break;
                usleep(1000);
                fpga_rmem_addr = read_sc_top();
                continue;
            }

            vector<uint32_t> payload;
            payload.reserve(payload_len);
            for (uint32_t i = 0; i < payload_len; i++) {
                payload.push_back(mu.read_memory_ro(sc_rmem_ptr));
                rmem_incr(sc_rmem_ptr);
            }

            const uint32_t trailer = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);
            if (trailer != 0x9c) {
                if (!quiet) {
                    cout << "SC secondary: bad trailer after header@0x" << std::hex << hdr_addr
                         << " trailer=" << trailer << std::dec << endl;
                }
                sc_rmem_ptr = hdr_addr;
                rmem_incr(sc_rmem_ptr);
                continue;
            }

            if (!quiet) {
                static const char* rsp_names[] = {"OK", "SLVERR", "DECERR", "RSP3"};
                cout << "SC secondary packet: "
                     << (is_read_pkt ? "RD" : (is_write_pkt ? "WR" : "??"))
                     << " rsp=" << rsp_names[avmm_rsp]
                     << " link=" << std::dec << decode_link_index(header)
                     << " addr=0x" << std::hex << (start_addr_word & 0xFFFF)
                     << " len=" << std::dec << payload_len
                     << " header=" << fmt_hex32(header)
                     << endl;

                for (size_t i = 0; i < payload.size(); i++) {
                    cout << "  payload[" << i << "]=" << fmt_hex32(payload[i]) << endl;
                }
            }
        }
        auto stop = high_resolution_clock::now();
        auto duration = duration_cast<microseconds>(stop - start);

        cout << duration.count() << endl;
    };

    struct DumpSegment {
        const char* label;
        uint32_t base_addr;
        uint32_t span_bytes;
        bool full_only;
    };

    // SC word addresses for datapath CSRs behind mm_bridge.
    // mm_bridge.s0 base = byte 0x20000 = SC word 0x8000
    // (confirmed from router_001 address decoder in compiled RTL).
    // SC_word = 0x8000 + dp_internal_byte_offset / 4
    static const DumpSegment scifi_dp_segments[] = {
        {"lvds_rx_controller_pro_0.csr", 0x8000, 0x40, false},

        {"mch_count_subsystem[0].avmm_rst_interval", 0x8020, 0x4, true},
        {"mch_count_subsystem[1].avmm_rst_interval", 0x8420, 0x4, true},
        {"mch_count_subsystem[2].avmm_rst_interval", 0x8820, 0x4, true},
        {"mch_count_subsystem[3].avmm_rst_interval", 0x8C20, 0x4, true},
        {"mch_count_subsystem[4].avmm_rst_interval", 0x9020, 0x4, true},
        {"mch_count_subsystem[5].avmm_rst_interval", 0x9420, 0x4, true},
        {"mch_count_subsystem[6].avmm_rst_interval", 0x9820, 0x4, true},
        {"mch_count_subsystem[7].avmm_rst_interval", 0x9C20, 0x4, true},

        {"backpressure_fifo[0].csr", 0x8218, 0x10, true},
        {"backpressure_fifo[1].csr", 0x8618, 0x10, true},
        {"backpressure_fifo[2].csr", 0x8A18, 0x10, true},
        {"backpressure_fifo[3].csr", 0x8E18, 0x10, true},
        {"backpressure_fifo[4].csr", 0x9218, 0x10, true},
        {"backpressure_fifo[5].csr", 0x9618, 0x10, true},
        {"backpressure_fifo[6].csr", 0x9A18, 0x10, true},
        {"backpressure_fifo[7].csr", 0x9E18, 0x10, true},

        {"mutrig_frame_deassembly[0].csr", 0x8240, 0x10, false},
        {"mutrig_frame_deassembly[1].csr", 0x8640, 0x10, false},
        {"mutrig_frame_deassembly[2].csr", 0x8A40, 0x10, false},
        {"mutrig_frame_deassembly[3].csr", 0x8E40, 0x10, false},
        {"mutrig_frame_deassembly[4].csr", 0x9240, 0x10, false},
        {"mutrig_frame_deassembly[5].csr", 0x9640, 0x10, false},
        {"mutrig_frame_deassembly[6].csr", 0x9A40, 0x10, false},
        {"mutrig_frame_deassembly[7].csr", 0x9E40, 0x10, false},

        {"mts_preprocessor_0.csr", 0x9000, 0x20, false},
        {"mts_preprocessor_1.csr", 0xA000, 0x20, false},

        {"chid_counter[0].value", 0xA400, 0x80, true},
        {"chid_counter[1].value", 0xA420, 0x80, true},
        {"chid_counter[2].value", 0xA440, 0x80, true},
        {"chid_counter[3].value", 0xA460, 0x80, true},
        {"chid_counter[4].value", 0xA480, 0x80, true},
        {"chid_counter[5].value", 0xA4A0, 0x80, true},
        {"chid_counter[6].value", 0xA4C0, 0x80, true},
        {"chid_counter[7].value", 0xA4E0, 0x80, true},

        {"histogram_statistics_0.hist_bin", 0xA800, 0x400, true},
        {"histogram_statistics_1.hist_bin", 0xAA00, 0x400, true},
        {"histogram_statistics_2.hist_bin", 0xB000, 0x400, true},

        {"histogram_statistics_0.csr", 0xA900, 0x40, false},
        {"histogram_statistics_1.csr", 0xAB00, 0x40, false},
        {"histogram_statistics_2.csr", 0xB100, 0x40, false},

        {"ring_buffer_cam_0.csr", 0xAC00, 0x80, false},
        {"ring_buffer_cam_1.csr", 0xAC20, 0x80, false},
        {"ring_buffer_cam_2.csr", 0xAC40, 0x80, false},
        {"ring_buffer_cam_3.csr", 0xAC60, 0x80, false},
        {"ring_buffer_cam_4.csr", 0xAD00, 0x80, false},
        {"ring_buffer_cam_5.csr", 0xAD20, 0x80, false},
        {"ring_buffer_cam_6.csr", 0xAD40, 0x80, false},
        {"ring_buffer_cam_7.csr", 0xAD60, 0x80, false},

        {"mutrig_injector_0.csr", 0xAC80, 0x40, false},

        {"feb_frame_assembly_0.csr", 0xB400, 0x40, false},
        {"feb_frame_assembly_1.csr", 0xB410, 0x40, false},
    };

    auto sc_read = [&](uint32_t addr, uint32_t len_words, vector<uint32_t>& out) -> bool {
        if (addr >= (1u << 16) || len_words == 0 || len_words > 255) {
            return false;
        }

        // Drain any existing traffic from the SC secondary queue. The ring buffer may also
        // contain other streams; for dumps we only care about responses to *this* request.
        sc_rmem_ptr = read_sc_top();

        do_read = true;
        startaddr = addr;
        xfer_len = len_words;
        data.clear();

        // Trigger SC main
        uint32_t packet_type = PACKET_TYPE_SC_READ;
        mu.write_memory_rw(0, PACKET_TYPE_SC << 26 | packet_type << 24 | ((uint16_t)(link_index & 0x000000FF)) << 8 | 0xBC);
        mu.write_memory_rw(1, startaddr);
        mu.write_memory_rw(2, xfer_len);
        mu.write_memory_rw(3, 0x0000009c);

        // Ensure the full command packet is visible to the FPGA before triggering SC main.
        (void)mu.read_memory_rw(3);

        mu.write_register(SC_MAIN_LENGTH_REGISTER_W, 2);
        mu.write_register(SC_MAIN_ENABLE_REGISTER_W, 0x0);
        mu.toggle_register(SC_MAIN_ENABLE_REGISTER_W, 0x1, 100);

        uint32_t count = 0;
        while (count < 10000) {
            if (mu.read_register_ro(SC_MAIN_STATUS_REGISTER_R) & 0x1) break;
            usleep(100);
            count++;
        }
        if (count >= 10000) {
            cout << "SC read timeout waiting for SC_MAIN_STATUS" << endl;
            return false;
        }

        const uint32_t min_words = 4;
        const auto deadline = steady_clock::now() + std::chrono::milliseconds(5000);
        while (steady_clock::now() < deadline) {
            fpga_rmem_addr = read_sc_top();

            if (sc_rmem_ptr == fpga_rmem_addr) {
                // No new words yet; response can arrive slightly after SC main is done.
                usleep(1000);
                continue;
            }

            if (rmem_distance(sc_rmem_ptr, fpga_rmem_addr) < min_words) {
                usleep(1000);
                continue;
            }

            const uint32_t hdr_addr = sc_rmem_ptr;
            const uint32_t header = mu.read_memory_ro(sc_rmem_ptr);
            if ((header & 0x1c0000bc) != 0x1c0000bc) {
                rmem_incr(sc_rmem_ptr);
                continue;
            }

            rmem_incr(sc_rmem_ptr);
            const uint32_t start_addr_word = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);
            const uint32_t len_word = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);

            // sc_hub v2: AVMM response code in bits[17:16], OK = "00".
            uint32_t payload_len = (len_word & 0xFFFF);
            const uint32_t pkt_type = decode_pkt_type(header);
            const bool is_read_pkt = (pkt_type == PACKET_TYPE_SC_READ) || (pkt_type == PACKET_TYPE_SC_READ_NONINCREMENTING);

            // Sanity: any other value is almost certainly a desync/mis-parse.
            if (payload_len > 255) {
                sc_rmem_ptr = hdr_addr;
                rmem_incr(sc_rmem_ptr);
                continue;
            }

            const uint32_t total_words = 4 + payload_len;
            if (rmem_distance(hdr_addr, fpga_rmem_addr) < total_words) {
                // Incomplete packet, wait for more.
                sc_rmem_ptr = hdr_addr;
                usleep(1000);
                continue;
            }

            vector<uint32_t> payload;
            payload.reserve(payload_len);
            for (uint32_t i = 0; i < payload_len; i++) {
                payload.push_back(mu.read_memory_ro(sc_rmem_ptr));
                rmem_incr(sc_rmem_ptr);
            }

            const uint32_t trailer = mu.read_memory_ro(sc_rmem_ptr);
            rmem_incr(sc_rmem_ptr);
            if (trailer != 0x9c) {
                // Desync; discard one word and retry.
                sc_rmem_ptr = hdr_addr;
                rmem_incr(sc_rmem_ptr);
                continue;
            }

            // SC secondary only contains packets FROM the FEB, so any
            // matching packet is a response.  Don't require is_response
            // bit — sc_hub v2 uses OK="00" which leaves bit 16 clear.
            const uint32_t pkt_link = decode_link_index(header);
            const uint32_t pkt_addr = start_addr_word & 0xFFFF;
            if (is_read_pkt && pkt_link == link_index && pkt_addr == addr && payload_len == len_words) {
                out = std::move(payload);
                return true;
            }
            // Otherwise keep scanning; ignore other packet types/links/addresses.
        }

        if (!quiet) {
            cout << "SC read: no matching response for addr=0x" << std::hex << addr << std::dec << " len=" << len_words << endl;
        }
        return false;
    };

    auto dump_sc_words = [&](const char* label, uint32_t base_addr, uint32_t span_bytes) -> bool {
        if (base_addr >= (1u << 16)) return false;
        const uint32_t n_words = (span_bytes + 3U) / 4U;
        if (n_words == 0) return true;

        vector<uint32_t> words;
        words.reserve(n_words);
        for (uint32_t offset = 0; offset < n_words;) {
            const uint32_t chunk_words = std::min<uint32_t>(255, n_words - offset);
            vector<uint32_t> chunk;
            bool ok = sc_read(base_addr + offset, chunk_words, chunk);
            if (!ok) {
                // One retry helps with occasional desync/traffic in the secondary queue.
                ok = sc_read(base_addr + offset, chunk_words, chunk);
            }
            if (!ok) {
                cout << "[SC dump] " << label << ": read failed at addr=0x" << std::hex << (base_addr + offset) << std::dec << endl;
                return false;
            }
            words.insert(words.end(), chunk.begin(), chunk.end());
            offset += chunk_words;
        }

        cout << "\n[SC dump] " << label << ": base=0x" << std::hex << base_addr << std::dec
             << " span=0x" << std::hex << span_bytes << std::dec
             << " (" << n_words << " words)" << endl;
        for (uint32_t i = 0; i < n_words; i++) {
            cout << "  +0x" << std::hex << (i * 4U) << ": " << fmt_hex32(words[i]) << std::dec << endl;
        }
        return true;
    };

    auto dump_scifi_datapath = [&](bool full) {
        // This dump uses the same Mu3e SC word addresses as the BTS custom page (behind the sc_hub datapath window).
        for (const auto& s : scifi_dp_segments) {
            if (s.full_only && !full) continue;
            dump_sc_words(s.label, s.base_addr, s.span_bytes);
        }
    };

    // --batch-wr-test <base_addr> <count>
    // Writes pattern to [base_addr .. base_addr+count-1], then reads each back.
    // All within a single invocation (single SWB reset).
    bool do_batch_wr_test = false;
    uint32_t batch_base = 0;
    uint32_t batch_count = 0;
    for (int i = 2; i < argc; i++) {
        if (string(argv[i]) == "--batch-wr-test") {
            if (i + 2 >= argc) { cout << "Missing args for --batch-wr-test <base> <count>" << endl; return -1; }
            if (!parse_u32(argv[i+1], batch_base) || !parse_u32(argv[i+2], batch_count)) {
                cout << "Invalid args for --batch-wr-test" << endl; return -1;
            }
            do_batch_wr_test = true;
            break;
        }
    }

    if (do_batch_wr_test) {
        cout << "=== Batch write-readback test ===" << endl;
        cout << "base=0x" << std::hex << batch_base << " count=" << std::dec << batch_count << endl;

        // Helper lambdas for batch test
        auto batch_write = [&](uint32_t addr, uint32_t val) {
            startaddr = addr;
            data = {val};
            xfer_len = 1;
            do_read = false;
            quiet = true;
            trigger_sc();
        };

        auto batch_read = [&](uint32_t addr) -> uint32_t {
            vector<uint32_t> result;
            if (sc_read(addr, 1, result) && result.size() == 1) {
                return result[0];
            }
            return 0xFFFFFFFF; // sentinel for failed read
        };

        uint32_t pass = 0, fail = 0;

        // Phase 1: write all
        cout << "\n--- Phase 1: Writing patterns ---" << endl;
        for (uint32_t i = 0; i < batch_count; i++) {
            uint32_t addr = batch_base + i;
            uint32_t val = 0xABCD0000 | (addr & 0xFFFF);
            batch_write(addr, val);
            if (i % 16 == 0) cout << "  wrote 0x" << std::hex << addr << " = 0x" << val << endl;
            usleep(50000); // 50ms between writes
        }

        // Phase 2: readback all
        cout << "\n--- Phase 2: Reading back ---" << endl;
        for (uint32_t i = 0; i < batch_count; i++) {
            uint32_t addr = batch_base + i;
            uint32_t expected = 0xABCD0000 | (addr & 0xFFFF);
            uint32_t got = batch_read(addr);
            if (got == expected) {
                pass++;
                if (i % 16 == 0) cout << "  [0x" << std::hex << addr << "] OK: 0x" << got << endl;
            } else {
                fail++;
                cout << "  [0x" << std::hex << addr << "] FAIL: expected=0x" << expected << " got=0x" << got << endl;
            }
            usleep(50000); // 50ms between reads
        }

        // Phase 3: read sc_hub diag
        cout << "\n--- Diagnostic CSRs ---" << endl;
        {
            vector<uint32_t> diag;
            if (sc_read(0xFE84, 2, diag) && diag.size() == 2) {
                cout << "  ERR_FLAGS=0x" << std::hex << diag[0] << " ERR_COUNT=0x" << diag[1] << endl;
            }
            usleep(100000);
            vector<uint32_t> cnt;
            if (sc_read(0xFE8F, 9, cnt) && cnt.size() == 9) {
                cout << "  EXT_PKT_RD=0x" << cnt[0] << " EXT_PKT_WR=0x" << cnt[1]
                     << " EXT_WORD_RD=0x" << cnt[2] << " EXT_WORD_WR=0x" << cnt[3] << endl;
                cout << "  LAST_RD_ADDR=0x" << cnt[4] << " LAST_RD_DATA=0x" << cnt[5] << endl;
                cout << "  LAST_WR_ADDR=0x" << cnt[6] << " LAST_WR_DATA=0x" << cnt[7] << endl;
                cout << "  PKT_DROP_CNT=0x" << cnt[8] << endl;
            }
        }

        cout << std::dec << "\n=== Results: PASS=" << pass << " FAIL=" << fail << " ===" << endl;
        goto exit_loop;
    }

    if (run_once) {
        if (do_dump_dp) {
            // Dumping would otherwise spam the terminal with raw packet/memory debug.
            quiet = true;
            dump_scifi_datapath(dump_dp_full);
            goto exit_loop;
        }
        trigger_sc();
        goto exit_loop;
    }

    char cmd;
    while (1) {
        printf("  [1] => trigger a test slow control \n");
        printf("  [q] => return \n");
        cout << "Select entry ...";
        cin >> cmd;
        switch(cmd) {
        case '1':
            trigger_sc();
            break;
        case 'q':
            goto exit_loop;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }
    exit_loop: ;

    // unset FEB enable regs
    mu.write_register(FEB_ENABLE_REGISTER_W, 0x0);
    return 0;
}
