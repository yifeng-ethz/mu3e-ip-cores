/* Zero-trust user-space PCIe DMA reader for the SWB DMA ring. */

#include <algorithm>
#include <atomic>
#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <limits>
#include <signal.h>
#include <sstream>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>
#include <vector>

#include "a10_pcie_registers.h"
#include "mudaq_device_constants.h"

#ifndef MAP_HUGETLB
#define MAP_HUGETLB 0x40000
#endif

#ifndef SWB_DATA_TYPE_REGISTER_W
#ifdef KWORD_W
#define SWB_DATA_TYPE_REGISTER_W KWORD_W
#endif
#endif

namespace {

constexpr size_t k_mb = 1024u * 1024u;
constexpr size_t k_word_bytes = sizeof(uint32_t);
constexpr size_t k_bar_bytes = 64u * 1024u;
constexpr size_t k_flush_bytes = 1u * k_mb;
constexpr size_t k_max_write_bytes = 16u * k_mb;
constexpr size_t k_min_headroom_bytes = 1u * k_mb;
constexpr uint32_t k_reg_max_words = MUDAQ_REGS_RW_LEN;

volatile sig_atomic_t g_stop = 0;

struct Options {
	std::string device = "/dev/mudaq0";
	std::string dmabuf = "/dev/mudaq0_dmabuf";
	std::string out = "dma_capture.bin";
	size_t staging_mb = 256;
	uint32_t af_pct = 80;
	uint32_t resume_pct = 60;
	uint32_t duration_s = 10;
	uint32_t backpressure_reg = SWB_READOUT_STATE_REGISTER_W;
	bool quiet = false;
};

struct Staging {
	uint32_t *words = nullptr;
	size_t bytes = 0;
	size_t n_words = 0;
	bool hugetlb_locked = false;
};

struct RawDevice {
	int fd = -1;
	volatile uint32_t *regs = nullptr;
	volatile uint32_t *regs_ro = nullptr;
	volatile uint32_t *dma_ctrl = nullptr;
	size_t regs_bytes = k_bar_bytes;
	long pagesize = 4096;
	bool has_dma_ctrl = false, has_regs_ro = false;
};

struct DmaMap {
	int fd = -1;
	const uint32_t *words = nullptr;
	size_t bytes = 0;
	size_t n_words = 0;
};

struct Shared {
	const Options *opt = nullptr;
	RawDevice *dev = nullptr;
	DmaMap *dma = nullptr;
	Staging *staging = nullptr;
	std::atomic<uint64_t> rd_seq{0};
	std::atomic<uint64_t> wr_seq{0};
	std::atomic<bool> running{true};
	std::atomic<bool> io_error{false};
	std::atomic<uint64_t> dma_words_read{0};
	std::atomic<uint64_t> file_words_written{0};
	uint32_t run_state_value = 1;
	size_t af_words = 0;
	size_t resume_words = 0;
};

static void on_signal(int)
{
	g_stop = 1;
}

static void log_msg(const Options& opt, const std::string& msg)
{
	if (!opt.quiet)
		std::cerr << "dma_tool: " << msg << '\n';
}

static std::string errno_msg(const std::string& what)
{
	return what + ": " + std::strerror(errno);
}

static std::string hex_u32(uint32_t value)
{
	std::ostringstream os;
	os << "0x" << std::hex << std::uppercase << value;
	return os.str();
}

static void print_usage()
{
	std::cout
		<< "Usage:\n  dma_tool [options]\n\nOptions:\n"
		<< "  --device <path>          MuDAQ device node (default /dev/mudaq0)\n"
		<< "  --dmabuf <path>          DMA buffer device node (default /dev/mudaq0_dmabuf)\n"
		<< "  --out <path>             output binary file (default dma_capture.bin)\n"
		<< "  --staging-mb <N>         staging ring size in MB (default 256, max 1024, min 16)\n"
		<< "  --af-pct <0..100>        almost-full threshold (default 80)\n"
		<< "  --resume-pct <0..100>    resume threshold (default 60)\n"
		<< "  --duration-s <N>         run duration; 0 = until SIGINT (default 10)\n"
		<< "  --backpressure-reg <hex> SWB register to halt (default 0x13)\n"
		<< "  --quiet                  reduce stderr\n  -h, --help               Show this help\n";
}

static bool parse_u64(const std::string& text, uint64_t *out)
{
	char *end = nullptr;
	unsigned long long value;

	if (!out || text.empty())
		return false;

	errno = 0;
	value = std::strtoull(text.c_str(), &end, 0);
	if (errno || end == text.c_str() || *end != '\0')
		return false;

	*out = static_cast<uint64_t>(value);
	return true;
}

static bool take_value(int *idx, int argc, char **argv, std::string *out)
{
	if (!idx || !out || *idx + 1 >= argc)
		return false;
	*out = argv[++(*idx)];
	return true;
}

static bool parse_args(int argc, char **argv, Options *opt)
{
	if (!opt)
		return false;

	for (int i = 1; i < argc; ++i) {
		const std::string arg = argv[i];
		std::string value;
		uint64_t number = 0;

		if (arg == "-h" || arg == "--help") {
			print_usage();
			std::exit(0);
		} else if (arg == "--device") {
			if (!take_value(&i, argc, argv, &opt->device)) {
				std::cerr << "dma_tool: --device requires a value\n";
				return false;
			}
		} else if (arg == "--dmabuf") {
			if (!take_value(&i, argc, argv, &opt->dmabuf)) {
				std::cerr << "dma_tool: --dmabuf requires a value\n";
				return false;
			}
		} else if (arg == "--out") {
			if (!take_value(&i, argc, argv, &opt->out)) {
				std::cerr << "dma_tool: --out requires a value\n";
				return false;
			}
		} else if (arg == "--staging-mb") {
			if (!take_value(&i, argc, argv, &value) || !parse_u64(value, &number) ||
			    number < 16 || number > 1024) {
				std::cerr << "dma_tool: --staging-mb must be in 16..1024\n";
				return false;
			}
			opt->staging_mb = static_cast<size_t>(number);
		} else if (arg == "--af-pct") {
			if (!take_value(&i, argc, argv, &value) || !parse_u64(value, &number) ||
			    number > 100) {
				std::cerr << "dma_tool: --af-pct must be in 0..100\n";
				return false;
			}
			opt->af_pct = static_cast<uint32_t>(number);
		} else if (arg == "--resume-pct") {
			if (!take_value(&i, argc, argv, &value) || !parse_u64(value, &number) ||
			    number > 100) {
				std::cerr << "dma_tool: --resume-pct must be in 0..100\n";
				return false;
			}
			opt->resume_pct = static_cast<uint32_t>(number);
		} else if (arg == "--duration-s") {
			if (!take_value(&i, argc, argv, &value) || !parse_u64(value, &number) ||
			    number > std::numeric_limits<uint32_t>::max()) {
				std::cerr << "dma_tool: --duration-s must fit in 32 bits\n";
				return false;
			}
			opt->duration_s = static_cast<uint32_t>(number);
		} else if (arg == "--backpressure-reg") {
			if (!take_value(&i, argc, argv, &value) || !parse_u64(value, &number) ||
			    number >= k_reg_max_words) {
				std::cerr << "dma_tool: --backpressure-reg is out of BAR0 range\n";
				return false;
			}
			opt->backpressure_reg = static_cast<uint32_t>(number);
		} else if (arg == "--quiet") {
			opt->quiet = true;
		} else {
			std::cerr << "dma_tool: unknown option: " << arg << '\n';
			return false;
		}
	}

	if (opt->resume_pct >= opt->af_pct) {
		std::cerr << "dma_tool: --resume-pct must be lower than --af-pct\n";
		return false;
	}
	return true;
}

static std::vector<size_t> allocation_candidates(size_t requested_mb)
{
	const size_t tiers[] = {1024, 512, 256, 128, 64, 32, 16};
	std::vector<size_t> out;

	if (requested_mb >= 16 && requested_mb <= 1024)
		out.push_back(requested_mb);

	for (size_t mb : tiers) {
		if (mb <= requested_mb &&
		    std::find(out.begin(), out.end(), mb) == out.end())
			out.push_back(mb);
	}
	return out;
}

static bool alloc_staging(const Options& opt, Staging *staging)
{
	const auto candidates = allocation_candidates(opt.staging_mb);
	const int strict_flags = MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_LOCKED;
	const int loose_flags = MAP_PRIVATE | MAP_ANONYMOUS;

	for (int pass = 0; pass < 2; ++pass) {
		const int flags = pass == 0 ? strict_flags : loose_flags;
		for (size_t mb : candidates) {
			const size_t bytes = mb * k_mb;
			void *ptr = mmap(nullptr, bytes, PROT_READ | PROT_WRITE, flags, -1, 0);
			if (ptr == MAP_FAILED)
				continue;

			staging->words = static_cast<uint32_t*>(ptr);
			staging->bytes = bytes;
			staging->n_words = bytes / k_word_bytes;
			staging->hugetlb_locked = (pass == 0);
			if (pass != 0) {
				(void)madvise(ptr, bytes, MADV_HUGEPAGE);
				if (mlock(ptr, bytes) != 0)
					log_msg(opt, "mlock failed on fallback staging ring; continuing unlocked");
			}
			log_msg(opt, "staging ring: " + std::to_string(mb) + " MB (" +
				     (pass == 0 ? "MAP_HUGETLB|MAP_LOCKED" : "anonymous fallback") + ")");
			return true;
		}
	}

	std::cerr << "dma_tool: could not allocate staging ring down to 16 MB\n";
	return false;
}

static void free_staging(Staging *staging)
{
	if (!staging || !staging->words)
		return;
	if (!staging->hugetlb_locked)
		(void)munlock(staging->words, staging->bytes);
	munmap(staging->words, staging->bytes);
	*staging = Staging{};
}

static std::string basename_of(const std::string& path)
{
	const size_t pos = path.find_last_of('/');
	return pos == std::string::npos ? path : path.substr(pos + 1);
}

static bool read_size_file(const std::string& path, size_t *size)
{
	std::ifstream in(path);
	uint64_t value = 0;
	if (!in)
		return false;
	in >> value;
	if (!in || value == 0)
		return false;
	*size = static_cast<size_t>(value);
	return true;
}

static size_t detect_dmabuf_size(int fd, const std::string& dmabuf, const Options& opt)
{
	size_t size = 0;
	const std::string sysfs = "/sys/class/mudaq/" + basename_of(dmabuf) + "/size";
	struct stat st {};

	if (read_size_file(sysfs, &size)) {
		log_msg(opt, "dmabuf size from " + sysfs + ": " + std::to_string(size) + " bytes");
		return size;
	}

	if (fstat(fd, &st) == 0 && st.st_size > 0) {
		size = static_cast<size_t>(st.st_size);
		log_msg(opt, "dmabuf size from fstat: " + std::to_string(size) + " bytes");
		return size;
	}

	errno = 0;
	const off_t end = lseek(fd, 0, SEEK_END);
	if (end > 0) {
		(void)lseek(fd, 0, SEEK_SET);
		size = static_cast<size_t>(end);
		log_msg(opt, "dmabuf size from lseek: " + std::to_string(size) + " bytes");
		return size;
	}

	size = MUDAQ_DMABUF_DATA_LEN;
	log_msg(opt, "dmabuf size unavailable from sysfs/fstat/lseek; using compiled fallback " +
		     std::to_string(size) + " bytes");
	return size;
}

static bool open_raw_device(const Options& opt, RawDevice *dev)
{
	dev->pagesize = sysconf(_SC_PAGESIZE);
	if (dev->pagesize <= 0)
		dev->pagesize = 4096;

	dev->fd = open(opt.device.c_str(), O_RDWR | O_SYNC | O_CLOEXEC);
	if (dev->fd < 0) {
		std::cerr << "dma_tool: " << errno_msg("open " + opt.device) << '\n';
		return false;
	}

	void *regs = mmap(nullptr, k_bar_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
	if (regs == MAP_FAILED) {
		dev->regs_bytes = MUDAQ_REGS_RW_LEN * k_word_bytes;
		regs = mmap(nullptr, dev->regs_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
		if (regs != MAP_FAILED)
			log_msg(opt, "BAR0 64KB mmap rejected; using exact RW register page size");
	}
	if (regs == MAP_FAILED) {
		std::cerr << "dma_tool: " << errno_msg("mmap BAR0 registers") << '\n';
		close(dev->fd);
		*dev = RawDevice{};
		return false;
	}
	dev->regs = static_cast<volatile uint32_t*>(regs);

	void *regs_ro = mmap(nullptr, MUDAQ_REGS_RO_LEN * k_word_bytes, PROT_READ, MAP_SHARED,
			    dev->fd, dev->pagesize);
	if (regs_ro != MAP_FAILED) {
		dev->regs_ro = static_cast<volatile uint32_t*>(regs_ro);
		dev->has_regs_ro = true;
	} else {
		log_msg(opt, "RO register page unavailable; RO summary counters will be omitted");
	}

	void *ctrl = mmap(nullptr, MUDAQ_DMABUF_CTRL_WORDS * k_word_bytes, PROT_READ, MAP_SHARED,
			 dev->fd, 4 * dev->pagesize);
	if (ctrl != MAP_FAILED) {
		dev->dma_ctrl = static_cast<volatile uint32_t*>(ctrl);
		dev->has_dma_ctrl = true;
		log_msg(opt, "DMA metadata ctrl page mapped at device page index 4");
	} else {
		log_msg(opt, "DMA metadata ctrl page unavailable; using GET_N_DMA_WORDS register");
	}

	return true;
}

static void close_raw_device(RawDevice *dev)
{
	if (!dev)
		return;
	if (dev->dma_ctrl)
		munmap(const_cast<uint32_t*>(dev->dma_ctrl), MUDAQ_DMABUF_CTRL_WORDS * k_word_bytes);
	if (dev->regs_ro)
		munmap(const_cast<uint32_t*>(dev->regs_ro), MUDAQ_REGS_RO_LEN * k_word_bytes);
	if (dev->regs)
		munmap(const_cast<uint32_t*>(dev->regs), dev->regs_bytes);
	if (dev->fd >= 0)
		close(dev->fd);
	*dev = RawDevice{};
}

static bool open_dma_map(const Options& opt, DmaMap *dma)
{
	dma->fd = open(opt.dmabuf.c_str(), O_RDONLY | O_CLOEXEC);
	if (dma->fd < 0) {
		std::cerr << "dma_tool: " << errno_msg("open " + opt.dmabuf) << '\n';
		return false;
	}

	dma->bytes = detect_dmabuf_size(dma->fd, opt.dmabuf, opt);
	dma->bytes &= ~(k_word_bytes - 1u);
	if (dma->bytes == 0) {
		std::cerr << "dma_tool: dmabuf size is not usable\n";
		close(dma->fd);
		*dma = DmaMap{};
		return false;
	}

	void *ptr = mmap(nullptr, dma->bytes, PROT_READ, MAP_SHARED, dma->fd, 0);
	if (ptr == MAP_FAILED) {
		std::cerr << "dma_tool: " << errno_msg("mmap " + opt.dmabuf) << '\n';
		close(dma->fd);
		*dma = DmaMap{};
		return false;
	}

	dma->words = static_cast<const uint32_t*>(ptr);
	dma->n_words = dma->bytes / k_word_bytes;
	log_msg(opt, "DMA ring mapped read-only: " + std::to_string(dma->bytes) + " bytes");
	return true;
}

static void close_dma_map(DmaMap *dma)
{
	if (!dma)
		return;
	if (dma->words)
		munmap(const_cast<uint32_t*>(dma->words), dma->bytes);
	if (dma->fd >= 0)
		close(dma->fd);
	*dma = DmaMap{};
}

static uint32_t read_register_rw(const RawDevice& dev, uint32_t idx)
{
	if (!dev.regs || idx >= k_reg_max_words)
		return 0;
	return dev.regs[idx];
}

static uint32_t read_register_ro(const RawDevice& dev, uint32_t idx)
{
	if (!dev.has_regs_ro || !dev.regs_ro || idx >= MUDAQ_REGS_RO_LEN)
		return 0;
	return dev.regs_ro[idx];
}

static void write_register(const RawDevice& dev, uint32_t idx, uint32_t value)
{
	if (!dev.regs || idx >= k_reg_max_words)
		return;
	dev.regs[idx] = value;
	std::atomic_thread_fence(std::memory_order_seq_cst);
}

static void ensure_dma_enabled(const Options& opt, const RawDevice& dev)
{
	const uint32_t dma_reg = read_register_rw(dev, DMA_REGISTER_W);
	/* Other short-lived board helpers can deactivate DMA on close.  The
	 * capture process therefore owns this bit for as long as it is alive. */
	write_register(dev, DMA_REGISTER_W, dma_reg | 0x1u);
	if ((dma_reg & 0x1u) == 0) {
		log_msg(opt, "DMA enable asserted: DMA_REGISTER_W " + hex_u32(dma_reg) +
			     " -> " + hex_u32(read_register_rw(dev, DMA_REGISTER_W)));
	}
}

static uint32_t dma_write_word(const RawDevice& dev, const DmaMap& dma)
{
	uint32_t word = 0;
	if (dev.has_dma_ctrl && dev.dma_ctrl) {
		const uint32_t ctrl3_word = dev.dma_ctrl[3] >> 2;
		const uint32_t ctrl0_lines_256b = dev.dma_ctrl[0];
		if (ctrl3_word != 0)
			word = ctrl3_word;
		else
			word = ctrl0_lines_256b * 8u;
	} else {
		word = read_register_rw(dev, GET_N_DMA_WORDS_REGISTER_W);
	}
	return dma.n_words ? (word % dma.n_words) : 0;
}

static size_t ring_distance(size_t from, size_t to, size_t ring_words)
{
	if (to >= from)
		return to - from;
	return ring_words - from + to;
}

static void copy_ring_words(uint32_t *dst, size_t dst_words, size_t dst_pos,
			    const uint32_t *src, size_t src_words, size_t src_pos,
			    size_t words)
{
	while (words > 0) {
		const size_t dst_i = dst_pos % dst_words;
		const size_t src_i = src_pos % src_words;
		const size_t chunk = std::min(words, std::min(dst_words - dst_i, src_words - src_i));
		std::memcpy(dst + dst_i, src + src_i, chunk * k_word_bytes);
		dst_pos += chunk;
		src_pos += chunk;
		words -= chunk;
	}
}

static bool write_all(int fd, const uint32_t *data, size_t bytes)
{
	const char *ptr = reinterpret_cast<const char*>(data);
	size_t left = bytes;
	while (left > 0) {
		const ssize_t n = write(fd, ptr, left);
		if (n < 0) {
			if (errno == EINTR)
				continue;
			return false;
		}
		if (n == 0)
			return false;
		ptr += n;
		left -= static_cast<size_t>(n);
	}
	return true;
}

static void set_backpressure(Shared& sh, bool *halted, bool halt)
{
	if (*halted == halt)
		return;
	if (halt) {
		write_register(*sh.dev, sh.opt->backpressure_reg, 0);
		log_msg(*sh.opt, "backpressure: HALT at staging fill >= " +
			 std::to_string(sh.opt->af_pct) + "%");
	} else {
		write_register(*sh.dev, sh.opt->backpressure_reg, sh.run_state_value);
		log_msg(*sh.opt, "backpressure: RESUME at staging fill < " +
			 std::to_string(sh.opt->resume_pct) + "%");
	}
	*halted = halt;
}

static void reader_thread(Shared *sh)
{
	size_t dma_rd = dma_write_word(*sh->dev, *sh->dma);
	bool halted = false;

	while (sh->running.load(std::memory_order_seq_cst) && !g_stop) {
		const uint64_t rd = sh->rd_seq.load(std::memory_order_seq_cst);
		const uint64_t wr = sh->wr_seq.load(std::memory_order_seq_cst);
		const size_t fill = static_cast<size_t>(wr - rd);

		if (fill >= sh->af_words)
			set_backpressure(*sh, &halted, true);
		else if (fill < sh->resume_words)
			set_backpressure(*sh, &halted, false);

		if (fill >= sh->staging->n_words - 1) {
			std::this_thread::sleep_for(std::chrono::microseconds(50));
			continue;
		}

		const size_t dma_wr = dma_write_word(*sh->dev, *sh->dma);
		const size_t available = ring_distance(dma_rd, dma_wr, sh->dma->n_words);
		if (available == 0) {
			std::this_thread::sleep_for(std::chrono::microseconds(50));
			continue;
		}

		const size_t free_words = sh->staging->n_words - fill - 1;
		const size_t to_copy = std::min(available, free_words);
		if (to_copy == 0)
			continue;

		std::atomic_thread_fence(std::memory_order_seq_cst);
		copy_ring_words(sh->staging->words, sh->staging->n_words,
				static_cast<size_t>(wr % sh->staging->n_words),
				sh->dma->words, sh->dma->n_words, dma_rd, to_copy);
		dma_rd = (dma_rd + to_copy) % sh->dma->n_words;
		sh->dma_words_read.fetch_add(to_copy, std::memory_order_seq_cst);
		sh->wr_seq.store(wr + to_copy, std::memory_order_seq_cst);
	}

	write_register(*sh->dev, sh->opt->backpressure_reg, 0);
}

static void writer_thread(Shared *sh)
{
	const int fd = open(sh->opt->out.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
	if (fd < 0) {
		std::cerr << "dma_tool: " << errno_msg("open output " + sh->opt->out) << '\n';
		sh->io_error.store(true, std::memory_order_seq_cst);
		sh->running.store(false, std::memory_order_seq_cst);
		return;
	}

	auto last_flush = std::chrono::steady_clock::now();
	off_t file_off = 0;
	const size_t flush_words = k_flush_bytes / k_word_bytes;
	const size_t max_write_words = k_max_write_bytes / k_word_bytes;

	while (sh->running.load(std::memory_order_seq_cst) ||
	       sh->rd_seq.load(std::memory_order_seq_cst) != sh->wr_seq.load(std::memory_order_seq_cst)) {
		const uint64_t rd = sh->rd_seq.load(std::memory_order_seq_cst);
		const uint64_t wr = sh->wr_seq.load(std::memory_order_seq_cst);
		const size_t fill = static_cast<size_t>(wr - rd);
		const auto now = std::chrono::steady_clock::now();
		const bool timeout = std::chrono::duration_cast<std::chrono::milliseconds>(
					     now - last_flush).count() >= 100;

		if (fill == 0 || (fill < flush_words && sh->running.load(std::memory_order_seq_cst) && !timeout)) {
			std::this_thread::sleep_for(std::chrono::milliseconds(1));
			continue;
		}

		size_t todo = std::min(fill, max_write_words);
		uint64_t rd_local = rd;
		while (todo > 0) {
			const size_t idx = static_cast<size_t>(rd_local % sh->staging->n_words);
			const size_t chunk = std::min(todo, sh->staging->n_words - idx);
			const size_t bytes = chunk * k_word_bytes;
			if (!write_all(fd, sh->staging->words + idx, bytes)) {
				std::cerr << "dma_tool: " << errno_msg("write output") << '\n';
				sh->io_error.store(true, std::memory_order_seq_cst);
				sh->running.store(false, std::memory_order_seq_cst);
				close(fd);
				return;
			}
			(void)posix_fadvise(fd, file_off, static_cast<off_t>(bytes), POSIX_FADV_DONTNEED);
			file_off += static_cast<off_t>(bytes);
			sh->file_words_written.fetch_add(chunk, std::memory_order_seq_cst);
			uint64_t expected = rd_local;
			while (!sh->rd_seq.compare_exchange_weak(expected, rd_local + chunk,
								 std::memory_order_seq_cst,
								 std::memory_order_seq_cst)) {
				expected = rd_local;
			}
			rd_local += chunk;
			todo -= chunk;
		}
		last_flush = std::chrono::steady_clock::now();
	}

	(void)fsync(fd);
	close(fd);
}

static void log_sg_detection(const Options& opt, const RawDevice& dev)
{
#ifdef SWB_DATA_TYPE_REGISTER_W
	const uint32_t data_type = read_register_rw(dev, SWB_DATA_TYPE_REGISTER_W);
#else
	const uint32_t data_type = 0;
#endif
	const uint32_t get_n_dma_words = read_register_rw(dev, GET_N_DMA_WORDS_REGISTER_W);
	const uint32_t dma_num_addr = read_register_rw(dev, DMA_NUM_ADDRESSES_REGISTER_W);
	const uint32_t num_addr = dma_num_addr & 0xfffu;

	std::ostringstream os;
	os << "SG detection: data_type=" << hex_u32(data_type)
	   << " get_n_dma_words=" << hex_u32(get_n_dma_words)
	   << " dma_num_addresses=" << num_addr << "; ";
	if (num_addr > 1)
		os << "multi-address DMA is configured, exported dmabuf is still read as one contiguous mmap ring";
	else
		os << "no SG layout flag found in register header, treating dmabuf as contiguous ring";
	log_msg(opt, os.str());
}

static void log_drop_counter(const Options& opt, const RawDevice& dev)
{
	std::ostringstream os;
	os << "drop counters: no OPQ_DROP register is defined";
	if (dev.has_regs_ro) {
		os << "; CNT_SKIP_EVENT_DMA_RAM_R=" << read_register_ro(dev, CNT_SKIP_EVENT_DMA_RAM_R)
		   << " CNT_SKIP_EVENT_LINK_FIFO_R=" << read_register_ro(dev, CNT_SKIP_EVENT_LINK_FIFO_R);
	} else {
		os << "; RO register page unavailable";
	}
	log_msg(opt, os.str());
}

static void configure_thresholds(const Options& opt, Shared *sh)
{
	sh->af_words = (sh->staging->n_words * opt.af_pct) / 100u;
	sh->resume_words = (sh->staging->n_words * opt.resume_pct) / 100u;
	const size_t min_headroom_words = k_min_headroom_bytes / k_word_bytes;
	if (sh->staging->n_words > min_headroom_words &&
	    sh->staging->n_words - sh->af_words < min_headroom_words) {
		sh->af_words = sh->staging->n_words - min_headroom_words;
		log_msg(opt, "AF threshold clamped to leave at least 1 MB headroom");
	}
	log_msg(opt, "AF headroom: " +
		     std::to_string((sh->staging->n_words - sh->af_words) * k_word_bytes / k_mb) +
		     " MB; PCIe RTT/inflight allowance is <= 8 KB plus <= 2 us RTT");
}

} // namespace

int main(int argc, char **argv)
{
	Options opt;
	if (!parse_args(argc, argv, &opt)) {
		print_usage();
		return 2;
	}

	struct sigaction sa {};
	sa.sa_handler = on_signal;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGINT, &sa, nullptr);
	sigaction(SIGTERM, &sa, nullptr);

	Staging staging;
	RawDevice dev;
	DmaMap dma;
	int exit_code = 0;

	if (!alloc_staging(opt, &staging))
		return 1;
	if (!open_raw_device(opt, &dev)) {
		free_staging(&staging);
		return 1;
	}
	if (!open_dma_map(opt, &dma)) {
		close_raw_device(&dev);
		free_staging(&staging);
		return 1;
	}

	Shared sh;
	sh.opt = &opt;
	sh.dev = &dev;
	sh.dma = &dma;
	sh.staging = &staging;
	sh.run_state_value = read_register_rw(dev, opt.backpressure_reg);
	if (sh.run_state_value == 0)
		sh.run_state_value = 1;

	configure_thresholds(opt, &sh);
	log_sg_detection(opt, dev);
	log_drop_counter(opt, dev);
	ensure_dma_enabled(opt, dev);
	log_msg(opt, "starting reader/writer threads");

	std::thread reader(reader_thread, &sh);
	std::thread writer(writer_thread, &sh);

	const auto start = std::chrono::steady_clock::now();
	while (!g_stop && !sh.io_error.load(std::memory_order_seq_cst)) {
		if (opt.duration_s != 0) {
			const auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
				std::chrono::steady_clock::now() - start);
			if (elapsed.count() >= opt.duration_s)
				break;
		}
		ensure_dma_enabled(opt, dev);
		std::this_thread::sleep_for(std::chrono::milliseconds(100));
	}

	sh.running.store(false, std::memory_order_seq_cst);
	if (reader.joinable())
		reader.join();
	if (writer.joinable())
		writer.join();

	write_register(dev, opt.backpressure_reg, 0);
	write_register(dev, DMA_REGISTER_W, 0);

	const uint64_t dma_words_read = sh.dma_words_read.load(std::memory_order_seq_cst);
	const uint64_t file_words_written = sh.file_words_written.load(std::memory_order_seq_cst);
	const uint32_t dma_cnt_words = read_register_ro(dev, DMA_CNT_WORDS_REGISTER_R);

	if (dma_words_read != file_words_written) {
		std::cerr << "dma_tool: conservation mismatch: read " << dma_words_read
			  << " words, wrote " << file_words_written << " words\n";
		exit_code = 1;
	}
	if (sh.io_error.load(std::memory_order_seq_cst))
		exit_code = 1;

	std::cerr << "dma_tool: summary: read_words=" << dma_words_read
		  << " written_words=" << file_words_written
		  << " bytes_written=" << (file_words_written * k_word_bytes)
		  << " DMA_CNT_WORDS_REGISTER_R=" << dma_cnt_words
		  << " output=" << opt.out << '\n';

	close_dma_map(&dma);
	close_raw_device(&dev);
	free_staging(&staging);
	return exit_code;
}
