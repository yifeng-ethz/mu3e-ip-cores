#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_POINTS 8192
#define MAX_RATE_POINTS 64
#define MAX_SERIES 8

typedef struct {
  int n;
  float x[MAX_POINTS];
  float y[MAX_POINTS];
  float total;
} hist_series_t;

typedef struct {
  int n;
  float x[MAX_RATE_POINTS];
  float board_y[MAX_RATE_POINTS];
  float tlm_y[MAX_RATE_POINTS];
  int has_board[MAX_RATE_POINTS];
  int has_tlm[MAX_RATE_POINTS];
} rate_series_t;

typedef struct {
  char name[64];
  int n;
  float x[MAX_RATE_POINTS];
  float y[MAX_RATE_POINTS];
} named_series_t;

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "PNG";
  }
  if (strcasecmp(dot, ".svg") == 0) {
    return "SVG";
  }
  if (strcasecmp(dot, ".pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static void trim(char *s) {
  size_t len;
  while (*s != '\0' && isspace((unsigned char) *s)) {
    memmove(s, s + 1, strlen(s));
  }
  len = strlen(s);
  while (len > 0 && isspace((unsigned char) s[len - 1])) {
    s[--len] = '\0';
  }
}

static int read_latency_hist(const char *path, hist_series_t *series, int max_x) {
  FILE *fp = fopen(path, "r");
  char line[256];
  int first = 1;
  int bin;
  int count;
  int bins[MAX_POINTS];
  int counts[MAX_POINTS];
  int n = 0;
  long total = 0;

  if (fp == NULL) {
    fprintf(stderr, "could not open latency CSV: %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    if (first) {
      first = 0;
      continue;
    }
    if (sscanf(line, "%d,%d", &bin, &count) != 2) {
      continue;
    }
    if (bin < 0 || bin > max_x || n >= MAX_POINTS) {
      continue;
    }
    bins[n] = bin;
    counts[n] = count;
    total += count;
    n++;
  }
  fclose(fp);

  series->n = n;
  series->total = (float) total;
  if (total <= 0) {
    return 1;
  }
  for (int i = 0; i < n; i++) {
    series->x[i] = (float) bins[i];
    series->y[i] = 100.0f * (float) counts[i] / (float) total;
  }
  return 1;
}

static int read_rate_csv(const char *path, rate_series_t *series) {
  FILE *fp = fopen(path, "r");
  char line[512];
  int first = 1;
  memset(series, 0, sizeof(*series));
  if (fp == NULL) {
    fprintf(stderr, "could not open rate CSV: %s\n", path);
    return 0;
  }
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[10] = {0};
    int ntok = 0;
    char *tok;
    char source[64];
    int rate_word;
    float hits_per_s;
    int idx = -1;

    if (first) {
      first = 0;
      continue;
    }
    tok = strtok(line, ",");
    while (tok != NULL && ntok < 10) {
      tokens[ntok++] = tok;
      tok = strtok(NULL, ",");
    }
    if (ntok < 7) {
      continue;
    }
    snprintf(source, sizeof(source), "%s", tokens[0]);
    trim(source);
    rate_word = (int) strtol(tokens[2], NULL, 10);
    hits_per_s = (float) atof(tokens[6]) / 1000000.0f;
    for (int i = 0; i < series->n; i++) {
      if (fabsf(series->x[i] - ((float) rate_word / 256.0f)) < 0.01f) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      if (series->n >= MAX_RATE_POINTS) {
        continue;
      }
      idx = series->n++;
      series->x[idx] = (float) rate_word / 256.0f;
    }
    if (strcmp(source, "board") == 0) {
      series->board_y[idx] = hits_per_s;
      series->has_board[idx] = 1;
    } else if (strcmp(source, "tlm_hdl") == 0) {
      series->tlm_y[idx] = hits_per_s;
      series->has_tlm[idx] = 1;
    }
  }
  fclose(fp);
  return 1;
}

static int find_or_add_series(named_series_t *series, int *nseries, const char *name) {
  for (int i = 0; i < *nseries; i++) {
    if (strcmp(series[i].name, name) == 0) {
      return i;
    }
  }
  if (*nseries >= MAX_SERIES) {
    return -1;
  }
  snprintf(series[*nseries].name, sizeof(series[*nseries].name), "%s", name);
  series[*nseries].n = 0;
  (*nseries)++;
  return *nseries - 1;
}

static int keep_queue_mode(const char *mode) {
  return strcmp(mode, "iid_256") == 0 ||
         strcmp(mode, "cluster8_local") == 0 ||
         strcmp(mode, "cluster8_roaming") == 0 ||
         strcmp(mode, "mix50_iid_cluster8") == 0 ||
         strcmp(mode, "injection_all256") == 0;
}

static const char *queue_mode_label(const char *mode) {
  if (strcmp(mode, "iid_256") == 0) {
    return "iid 256 bins";
  }
  if (strcmp(mode, "cluster8_local") == 0) {
    return "local cluster-8";
  }
  if (strcmp(mode, "cluster8_roaming") == 0) {
    return "roaming cluster-8";
  }
  if (strcmp(mode, "mix50_iid_cluster8") == 0) {
    return "50/50 iid+cluster";
  }
  if (strcmp(mode, "injection_all256") == 0) {
    return "all-256 injection";
  }
  return mode;
}

static int read_queue_regions(const char *path, named_series_t *series, int *nseries) {
  FILE *fp = fopen(path, "r");
  char line[512];
  int first = 1;
  *nseries = 0;
  if (fp == NULL) {
    fprintf(stderr, "could not open queue-depth CSV: %s\n", path);
    return 0;
  }
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[8] = {0};
    int ntok = 0;
    char *tok;
    char mode[64];
    float rate_mhit;
    float threshold;
    float required_depth;
    int idx;

    if (first) {
      first = 0;
      continue;
    }
    tok = strtok(line, ",");
    while (tok != NULL && ntok < 8) {
      tokens[ntok++] = tok;
      tok = strtok(NULL, ",");
    }
    if (ntok < 6) {
      continue;
    }
    snprintf(mode, sizeof(mode), "%s", tokens[0]);
    trim(mode);
    if (!keep_queue_mode(mode)) {
      continue;
    }
    threshold = (float) atof(tokens[2]);
    if (fabsf(threshold - 1.0e-6f) > 1.0e-9f) {
      continue;
    }
    rate_mhit = (float) atof(tokens[1]);
    required_depth = (float) atof(tokens[5]);
    idx = find_or_add_series(series, nseries, mode);
    if (idx < 0 || series[idx].n >= MAX_RATE_POINTS) {
      continue;
    }
    series[idx].x[series[idx].n] = rate_mhit;
    series[idx].y[series[idx].n] = required_depth;
    series[idx].n++;
  }
  fclose(fp);
  return 1;
}

static int keep_latency_rate(float rate) {
  return fabsf(rate - 1.0f) < 0.01f ||
         fabsf(rate - 10.0f) < 0.01f ||
         fabsf(rate - 25.0f) < 0.01f ||
         fabsf(rate - 30.0f) < 0.01f;
}

static int read_mutrig_latency(const char *path, named_series_t *series, int *nseries) {
  FILE *fp = fopen(path, "r");
  char line[768];
  int first = 1;
  *nseries = 0;
  if (fp == NULL) {
    fprintf(stderr, "could not open MuTRiG latency CSV: %s\n", path);
    return 0;
  }
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[12] = {0};
    int ntok = 0;
    char *tok;
    char frame_mode[32];
    char label[64];
    float rate;
    float offset_frame;
    float latency_frames;
    int idx;

    if (first) {
      first = 0;
      continue;
    }
    tok = strtok(line, ",");
    while (tok != NULL && ntok < 12) {
      tokens[ntok++] = tok;
      tok = strtok(NULL, ",");
    }
    if (ntok < 11) {
      continue;
    }
    snprintf(frame_mode, sizeof(frame_mode), "%s", tokens[0]);
    trim(frame_mode);
    if (strcmp(frame_mode, "short") != 0) {
      continue;
    }
    rate = (float) atof(tokens[2]);
    if (!keep_latency_rate(rate)) {
      continue;
    }
    snprintf(label, sizeof(label), "%.0f Mhit/s%s", rate, (rate > 25.0f) ? " clipped" : "");
    offset_frame = (float) atof(tokens[5]);
    latency_frames = (float) atof(tokens[10]);
    idx = find_or_add_series(series, nseries, label);
    if (idx < 0 || series[idx].n >= MAX_RATE_POINTS) {
      continue;
    }
    series[idx].x[series[idx].n] = offset_frame;
    series[idx].y[series[idx].n] = latency_frames;
    series[idx].n++;
  }
  fclose(fp);
  return 1;
}

static void set_series_style(int idx) {
  static const char *colors[] = {"blue", "red", "green", "orange", "magenta", "cyan"};
  color(colors[idx % 6]);
  if (idx == 0) {
    solid();
  } else if (idx == 1) {
    dash();
  } else {
    dot();
  }
  linwid(6);
}

static void draw_legend_entry(float x, float y, float dx, const char *label, int idx) {
  float xs[2] = {x, x + dx};
  float ys[2] = {y, y};
  set_series_style(idx);
  curve(xs, ys, 2);
  color("fore");
  solid();
  linwid(1);
  height(24);
  rlmess(label, x + dx * 1.2f, y);
}

static void render_latency_plot(const char *tlm_csv, const char *rtl_csv, const char *out_path) {
  hist_series_t tlm;
  hist_series_t rtl;
  const int max_x = 2000;
  if (!read_latency_hist(tlm_csv, &tlm, max_x) || !read_latency_hist(rtl_csv, &rtl, max_x)) {
    exit(1);
  }

  metafl(output_format_from_path(out_path));
  setfil(out_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format_from_path(out_path), "PNG") == 0) {
    winsiz(2048, 1448);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  titlin("Phase 4 Dispatch-Latency Shape", 2);
  name("latency [156.25 MHz cycles]", "x");
  name("probability per cycle bin [%]", "y");
  intax();
  labdig(0, "x");
  labdig(2, "y");
  axspos(430, 1600);
  axslen(2050, 970);
  graf(0.0f, 2000.0f, 0.0f, 250.0f, 0.0f, 0.70f, 0.0f, 0.10f);

  set_series_style(0);
  curve(tlm.x, tlm.y, tlm.n);
  set_series_style(1);
  curve(rtl.x, rtl.y, rtl.n);
  solid();
  linwid(1);
  color("fore");
  grid(1, 1);
  draw_legend_entry(1540.0f, 0.63f, 130.0f, "HDL TLM", 0);
  draw_legend_entry(1540.0f, 0.57f, 130.0f, "RTL sim", 1);
  height(42);
  title();
  height(18);
  color("fore");
  messag("TLM is a cycle-count front-end timing model; RTL data is from the FE SciFi datapath harness histogram CSV.", 430, 1905);
  disfin();
}

static void render_rate_plot(const char *rate_csv, const char *out_path) {
  rate_series_t rate;
  float board_x[MAX_RATE_POINTS], board_y[MAX_RATE_POINTS];
  float tlm_x[MAX_RATE_POINTS], tlm_y[MAX_RATE_POINTS];
  float cap_x[2] = {0.0f, 128.0f};
  float cap_y[2] = {200.0f, 200.0f};
  int nb = 0, nt = 0;
  if (!read_rate_csv(rate_csv, &rate)) {
    exit(1);
  }
  for (int i = 0; i < rate.n; i++) {
    if (rate.has_board[i]) {
      board_x[nb] = rate.x[i];
      board_y[nb] = rate.board_y[i];
      nb++;
    }
    if (rate.has_tlm[i]) {
      tlm_x[nt] = rate.x[i];
      tlm_y[nt] = rate.tlm_y[i];
      nt++;
    }
  }

  metafl(output_format_from_path(out_path));
  setfil(out_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format_from_path(out_path), "PNG") == 0) {
    winsiz(2048, 1448);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  titlin("Phase 4 Histogram Throughput Sweep", 2);
  name("emulator hit-rate word / 0x0100", "x");
  name("accepted histogram rate [Mhit/s]", "y");
  intax();
  labdig(0, "x");
  labdig(0, "y");
  axspos(430, 1600);
  axslen(2050, 970);
  graf(0.0f, 128.0f, 0.0f, 16.0f, 0.0f, 230.0f, 0.0f, 25.0f);

  if (nt > 1) {
    set_series_style(0);
    curve(tlm_x, tlm_y, nt);
  }
  if (nb > 1) {
    set_series_style(1);
    incmrk(12);
    marker(15);
    curve(board_x, board_y, nb);
    marker(-1);
    incmrk(0);
  }
  set_series_style(2);
  curve(cap_x, cap_y, 2);
  solid();
  linwid(1);
  color("fore");
  grid(1, 1);
  draw_legend_entry(82.0f, 210.0f, 8.0f, "HDL TLM physical cap", 0);
  draw_legend_entry(82.0f, 194.0f, 8.0f, "Board Phase 4", 1);
  draw_legend_entry(82.0f, 178.0f, 8.0f, "8-MuTRiG target", 2);
  height(42);
  title();
  height(18);
  color("fore");
  messag("Physical target is 25 Mhit/s per MuTRiG, 100 Mhit/s per 4-lane datapath, 200 Mhit/s for the 8-MuTRiG histogram.", 430, 1905);
  disfin();
}

static void render_queue_plot(const char *queue_csv, const char *out_path) {
  named_series_t series[MAX_SERIES];
  int nseries = 0;
  if (!read_queue_regions(queue_csv, series, &nseries)) {
    exit(1);
  }

  metafl(output_format_from_path(out_path));
  setfil(out_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format_from_path(out_path), "PNG") == 0) {
    winsiz(2048, 1448);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  titlin("Phase 4 Coalescing Queue Depth", 2);
  name("offered histogram hit rate [Mhit/s]", "x");
  name("required queue depth for 1 ppm drop", "y");
  intax();
  labdig(0, "x");
  labdig(0, "y");
  axspos(430, 1600);
  axslen(2050, 970);
  graf(0.0f, 225.0f, 0.0f, 25.0f, 0.0f, 270.0f, 0.0f, 30.0f);

  for (int i = 0; i < nseries; i++) {
    if (series[i].n > 1) {
      set_series_style(i);
      curve(series[i].x, series[i].y, series[i].n);
    }
  }
  solid();
  linwid(1);
  color("fore");
  grid(1, 1);
  for (int i = 0; i < nseries; i++) {
    draw_legend_entry(118.0f, 145.0f - 15.0f * i, 9.0f, queue_mode_label(series[i].name), i);
  }
  height(42);
  title();
  height(18);
  color("fore");
  messag("Queue model uses RTL-style tag coalescing; above 78.125 M queue-elements/s it relies on repeated-bin merging, not raw SRAM update rate.", 430, 1905);
  disfin();
}

static void render_mutrig_latency_plot(const char *latency_csv, const char *out_path) {
  named_series_t series[MAX_SERIES];
  int nseries = 0;
  if (!read_mutrig_latency(latency_csv, series, &nseries)) {
    exit(1);
  }

  metafl(output_format_from_path(out_path));
  setfil(out_path);
  filmod("delete");
  setpag("da4l");
  if (strcasecmp(output_format_from_path(out_path), "PNG") == 0) {
    winsiz(2048, 1448);
  }
  scrmod("reverse");
  disini();
  pagera();
  complx();
  titlin("MuTRiG Injection-Mode Latency Envelope", 2);
  name("injection offset after frame mark [frames]", "x");
  name("maximum latency [frames]", "y");
  intax();
  labdig(2, "x");
  labdig(2, "y");
  axspos(430, 1600);
  axslen(2050, 970);
  graf(0.0f, 1.0f, 0.0f, 0.2f, 0.0f, 2.1f, 0.0f, 0.3f);

  for (int i = 0; i < nseries; i++) {
    if (series[i].n > 1) {
      set_series_style(i);
      curve(series[i].x, series[i].y, series[i].n);
    }
  }
  solid();
  linwid(1);
  color("fore");
  grid(1, 1);
  for (int i = 0; i < nseries; i++) {
    draw_legend_entry(0.58f, 1.95f - 0.13f * i, 0.08f, series[i].name, i);
  }
  height(42);
  title();
  height(18);
  color("fore");
  messag("Short-frame model uses FRAME_INTERVAL_SHORT=910 from emulator_mutrig_pkg; saturation adds up to one extra frame of L2 FIFO delay.", 430, 1905);
  disfin();
}

int main(int argc, char **argv) {
  if (argc != 10) {
    fprintf(stderr,
            "Usage: %s <tlm_latency.csv> <rtl_latency.csv> <rate.csv> <queue_regions.csv> <mutrig_latency.csv> <latency_out> <rate_out> <queue_out> <mutrig_out>\n",
            argv[0]);
    return 1;
  }
  render_latency_plot(argv[1], argv[2], argv[6]);
  render_rate_plot(argv[3], argv[7]);
  render_queue_plot(argv[4], argv[8]);
  render_mutrig_latency_plot(argv[5], argv[9]);
  return 0;
}
