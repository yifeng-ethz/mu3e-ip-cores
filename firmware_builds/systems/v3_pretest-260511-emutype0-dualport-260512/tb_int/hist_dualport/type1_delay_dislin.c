#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define N_BINS 256
#define N_RATES 4
#define MAX_TOKENS 40
#define PAGE_WIDTH 2970
#define PAGE_HEIGHT 2100
#define CLK_HZ 125000000.0f
#define RBCAM_LOW_CYCLES 0
#define RBCAM_HIGH_CYCLES 2000
#define X_MIN_CYCLES -1000.0f
#define X_MAX_CYCLES 3096.0f

typedef struct {
  char case_name[160];
  char source[80];
  char mode[40];
  char pattern[160];
  char result[32];
  char delay_model[80];
  int rate_hz;
  int run_cycles;
  int interval_cycles;
  int active_asics;
  int delay_target_cycles;
  long long expected;
  long long total;
  long long dropped;
  long long bin_sum;
} summary_t;

typedef struct {
  summary_t summary;
  long long bins[N_BINS];
  long long meta_bins[N_BINS];
  int centers[N_BINS];
  long long total;
  long long meta_total;
  long long in_window;
  long long out_window;
  int nonzero_bins;
  int meta_nonzero_bins;
  int peak_bin;
  int meta_peak_bin;
  int peak_center;
  int meta_peak_center;
  float peak_percent;
  float meta_peak_percent;
  int min_center;
  int max_center;
  int meta_min_center;
  int meta_max_center;
} panel_t;

static const int RATES[N_RATES] = {10000, 100000, 500000, 1000000};

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "PNG";
  }
  if (strcasecmp(dot, ".pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static void trim(char *s) {
  size_t len;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
    memmove(s, s + 1, strlen(s));
  }
  len = strlen(s);
  while (len > 0 && (s[len - 1] == ' ' || s[len - 1] == '\t' ||
                     s[len - 1] == '\n' || s[len - 1] == '\r')) {
    s[--len] = '\0';
  }
}

static int split_csv_preserve_empty(char *line, char **tokens, int max_tokens) {
  int ntok = 0;
  char *field = line;

  for (char *p = line; *p != '\0' && ntok < max_tokens; p++) {
    if (*p == ',') {
      *p = '\0';
      trim(field);
      tokens[ntok++] = field;
      field = p + 1;
    }
  }
  if (ntok < max_tokens) {
    trim(field);
    tokens[ntok++] = field;
  }
  return ntok;
}

static void rate_case_name(char *buf,
                           size_t buf_sz,
                           const char *source,
                           int rate_hz,
                           const char *pattern_suffix) {
  snprintf(buf, buf_sz, "%s_latency_%0dk_%s", source, rate_hz / 1000, pattern_suffix);
}

static const char *rate_label(int rate_hz) {
  switch (rate_hz) {
    case 10000:
      return "10k";
    case 100000:
      return "100k";
    case 500000:
      return "500k";
    case 1000000:
      return "1M";
    default:
      return "?";
  }
}

static const char *pattern_description(const char *pattern) {
  if (strcmp(pattern, "all_ch_all_asic") == 0) {
    return "all 32 channels enabled per ASIC";
  }
  if (strcmp(pattern, "raw_l2_all32ch_asic0") == 0) {
    return "raw MuTRiG L2 FIFO; ASIC0 all 32 channels";
  }
  if (strcmp(pattern, "raw_l2_onech_asic0") == 0) {
    return "raw MuTRiG L2 FIFO; ASIC0 one channel";
  }
  if (strcmp(pattern, "header_sync_one_ch_per_asic") == 0) {
    return "header-sync timestamp; one channel per ASIC";
  }
  return "one random channel per ASIC";
}

static int panel_for_case(panel_t panels[N_RATES], const char *case_name) {
  for (int i = 0; i < N_RATES; i++) {
    if (strcmp(panels[i].summary.case_name, case_name) == 0) {
      return i;
    }
  }
  return -1;
}

static int read_summaries(const char *path,
                          const char *source,
                          const char *pattern_suffix,
                          panel_t panels[N_RATES]) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;
  int found = 0;

  if (fp == NULL) {
    fprintf(stderr, "could not open summary CSV: %s\n", path);
    return 0;
  }

  for (int i = 0; i < N_RATES; i++) {
    memset(&panels[i], 0, sizeof(panels[i]));
    rate_case_name(panels[i].summary.case_name,
                   sizeof(panels[i].summary.case_name),
                   source,
                   RATES[i],
                   pattern_suffix);
    snprintf(panels[i].summary.source, sizeof(panels[i].summary.source), "%s", source);
    panels[i].summary.rate_hz = RATES[i];
    for (int bin = 0; bin < N_BINS; bin++) {
      panels[i].centers[bin] = bin * 32;
    }
    panels[i].peak_bin = -1;
    panels[i].min_center = 0;
    panels[i].max_center = 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 21) {
      continue;
    }
    idx = panel_for_case(panels, tokens[0]);
    if (idx < 0) {
      continue;
    }

    snprintf(panels[idx].summary.case_name, sizeof(panels[idx].summary.case_name), "%s", tokens[0]);
    snprintf(panels[idx].summary.source, sizeof(panels[idx].summary.source), "%s", tokens[1]);
    snprintf(panels[idx].summary.mode, sizeof(panels[idx].summary.mode), "%s", tokens[2]);
    panels[idx].summary.rate_hz = atoi(tokens[3]);
    snprintf(panels[idx].summary.pattern, sizeof(panels[idx].summary.pattern), "%s", tokens[4]);
    panels[idx].summary.run_cycles = atoi(tokens[5]);
    panels[idx].summary.interval_cycles = atoi(tokens[6]);
    panels[idx].summary.expected = atoll(tokens[7]);
    panels[idx].summary.total = atoll(tokens[12]);
    panels[idx].summary.dropped = atoll(tokens[13]);
    panels[idx].summary.bin_sum = atoll(tokens[14]);
    panels[idx].summary.active_asics = atoi(tokens[18]);
    snprintf(panels[idx].summary.result, sizeof(panels[idx].summary.result), "%s", tokens[20]);
    if (ntok >= 25) {
      snprintf(panels[idx].summary.delay_model, sizeof(panels[idx].summary.delay_model), "%s", tokens[21]);
      panels[idx].summary.delay_target_cycles = atoi(tokens[22]);
    }
    found++;
  }
  fclose(fp);

  for (int i = 0; i < N_RATES; i++) {
    if (panels[i].summary.run_cycles == 0) {
      fprintf(stderr, "missing summary row for %s\n", panels[i].summary.case_name);
      return 0;
    }
    if (strcmp(panels[i].summary.result, "PASS") != 0) {
      fprintf(stderr, "summary row is not PASS for %s: %s\n",
              panels[i].summary.case_name,
              panels[i].summary.result);
      return 0;
    }
  }
  return found >= N_RATES;
}

static int read_delay_bins(const char *path, panel_t panels[N_RATES]) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;
  int matched = 0;

  if (fp == NULL) {
    fprintf(stderr, "could not open delay-bin CSV: %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;
    int bin;
    long long count;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 15) {
      continue;
    }
    idx = panel_for_case(panels, tokens[0]);
    if (idx < 0) {
      continue;
    }
    bin = atoi(tokens[9]);
    if (bin < 0 || bin >= N_BINS) {
      fprintf(stderr, "bad bin index %d for case %s\n", bin, tokens[0]);
      fclose(fp);
      return 0;
    }
    panels[idx].centers[bin] = atoi(tokens[10]);
    count = atoll(tokens[11]);
    panels[idx].bins[bin] += count;
    matched++;
  }
  fclose(fp);

  if (matched == 0) {
    fprintf(stderr, "no delay-bin rows matched the requested cases in %s\n", path);
    return 0;
  }
  return 1;
}

static int read_meta_bins(const char *path, panel_t panels[N_RATES]) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;
  int matched = 0;

  if (fp == NULL) {
    fprintf(stderr, "could not open Type1 metadata CSV: %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;
    int latency;
    int bin;
    int ready;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 16) {
      continue;
    }
    idx = panel_for_case(panels, tokens[0]);
    if (idx < 0) {
      continue;
    }
    ready = atoi(tokens[15]);
    if (!ready) {
      continue;
    }
    latency = atoi(tokens[11]);
    if (latency < 0) {
      fprintf(stderr, "negative metadata latency %d for case %s\n", latency, tokens[0]);
      fclose(fp);
      return 0;
    }
    bin = latency / 32;
    if (bin < 0 || bin >= N_BINS) {
      fprintf(stderr, "metadata latency %d is outside %d bins for case %s\n",
              latency, N_BINS, tokens[0]);
      fclose(fp);
      return 0;
    }
    panels[idx].meta_bins[bin]++;
    matched++;
  }
  fclose(fp);

  if (matched == 0) {
    fprintf(stderr, "no Type1 metadata rows matched requested cases in %s\n", path);
    return 0;
  }
  return 1;
}

static int compute_panel_stats(panel_t panels[N_RATES]) {
  for (int i = 0; i < N_RATES; i++) {
    long long peak_count = 0;
    long long meta_peak_count = 0;

    panels[i].total = 0;
    panels[i].meta_total = 0;
    panels[i].in_window = 0;
    panels[i].out_window = 0;
    panels[i].nonzero_bins = 0;
    panels[i].meta_nonzero_bins = 0;
    panels[i].peak_bin = -1;
    panels[i].meta_peak_bin = -1;
    panels[i].min_center = 0;
    panels[i].max_center = 0;
    panels[i].meta_min_center = 0;
    panels[i].meta_max_center = 0;

    for (int bin = 0; bin < N_BINS; bin++) {
      long long count = panels[i].bins[bin];
      long long meta_count = panels[i].meta_bins[bin];
      int center = panels[i].centers[bin];

      panels[i].total += count;
      panels[i].meta_total += meta_count;
      if (count != 0) {
        if (panels[i].nonzero_bins == 0) {
          panels[i].min_center = center;
          panels[i].max_center = center;
        } else {
          if (center < panels[i].min_center) {
            panels[i].min_center = center;
          }
          if (center > panels[i].max_center) {
            panels[i].max_center = center;
          }
        }
        panels[i].nonzero_bins++;
        if (center >= RBCAM_LOW_CYCLES && center <= RBCAM_HIGH_CYCLES) {
          panels[i].in_window += count;
        } else {
          panels[i].out_window += count;
        }
        if (count > peak_count) {
          peak_count = count;
          panels[i].peak_bin = bin;
          panels[i].peak_center = center;
        }
      }
      if (meta_count != 0) {
        if (panels[i].meta_nonzero_bins == 0) {
          panels[i].meta_min_center = center;
          panels[i].meta_max_center = center;
        } else {
          if (center < panels[i].meta_min_center) {
            panels[i].meta_min_center = center;
          }
          if (center > panels[i].meta_max_center) {
            panels[i].meta_max_center = center;
          }
        }
        panels[i].meta_nonzero_bins++;
        if (meta_count > meta_peak_count) {
          meta_peak_count = meta_count;
          panels[i].meta_peak_bin = bin;
          panels[i].meta_peak_center = center;
        }
      }
    }

    if (panels[i].total == 0) {
      fprintf(stderr, "case %s has no delay-bin hits\n", panels[i].summary.case_name);
      return 0;
    }
    panels[i].peak_percent = 100.0f * (float)peak_count / (float)panels[i].total;
    panels[i].meta_peak_percent = panels[i].meta_total == 0 ? 0.0f :
      100.0f * (float)meta_peak_count / (float)panels[i].meta_total;
    if (panels[i].out_window != 0) {
      fprintf(stderr,
              "case %s has %lld hits outside rbCAM [%d,%d] cycles; nonzero center range [%d,%d]\n",
              panels[i].summary.case_name,
              panels[i].out_window,
              RBCAM_LOW_CYCLES,
              RBCAM_HIGH_CYCLES,
              panels[i].min_center,
              panels[i].max_center);
      return 0;
    }
    if (panels[i].summary.bin_sum != panels[i].total) {
      fprintf(stderr,
              "case %s summary bin_sum=%lld but delay-bin CSV total=%lld\n",
              panels[i].summary.case_name,
              panels[i].summary.bin_sum,
              panels[i].total);
      return 0;
    }
    if (panels[i].meta_total != 0 && panels[i].meta_total != panels[i].total) {
      fprintf(stderr,
              "case %s metadata total=%lld but CSR delay-bin total=%lld\n",
              panels[i].summary.case_name,
              panels[i].meta_total,
              panels[i].total);
      return 0;
    }
  }
  return 1;
}

static float nice_ymax(float peak) {
  if (peak <= 10.0f) {
    return 10.0f;
  }
  if (peak <= 20.0f) {
    return 20.0f;
  }
  if (peak <= 50.0f) {
    return 50.0f;
  }
  return 100.0f;
}

static void start_page(const char *out_path) {
  const char *fmt = output_format_from_path(out_path);
  metafl(fmt);
  setfil(out_path);
  filmod("delete");
  if (strcasecmp(fmt, "PNG") == 0) {
    winsiz(1800, 1273);
  }
  page(PAGE_WIDTH, PAGE_HEIGHT);
  scrmod("reverse");
  disini();
  pagera();
  complx();
}

static void page_message_centered(const char *text, int y, int h) {
  int width;
  height(h);
  width = nlmess(text);
  messag(text, (PAGE_WIDTH - width) / 2, y);
}

static void panel_message_centered(const char *text, int center_x, int y, int h) {
  int width;
  height(h);
  width = nlmess(text);
  messag(text, center_x - width / 2, y);
}

static void panel_message_left(const char *text, int x, int y, int h) {
  height(h);
  messag(text, x, y);
}

static void draw_panel(const panel_t *panel, int axis_x, int axis_y, int axis_w, int axis_h) {
  char title[256];
  char subtitle[256];
  char line1[256];
  char line2[256];
  char line3[256];
  float peak_for_axis = panel->meta_peak_percent > panel->peak_percent ?
                        panel->meta_peak_percent : panel->peak_percent;
  float ymax = nice_ymax(peak_for_axis * 1.18f);
  float ystep = ymax / 5.0f;
  int center_x = axis_x + axis_w / 2;

  snprintf(title,
           sizeof(title),
           "Phase-6 Periodic Mode=2 Delay: %s %s",
           panel->summary.source,
           rate_label(panel->summary.rate_hz));
  snprintf(subtitle,
           sizeof(subtitle),
           "mode=2 periodic; %s; %s",
           pattern_description(panel->summary.pattern),
           panel->summary.delay_model[0] != '\0' ?
             panel->summary.delay_model : "delay model not recorded");
  panel_message_centered(title, center_x, axis_y - axis_h - 88, 20);
  panel_message_centered(subtitle, center_x, axis_y - axis_h - 56, 16);

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  height(16);
  hname(18);
  labdis(14, "xy");
  namdis(26, "xy");
  name("signed hit latency bin center [cycles]", "x");
  name("hits / bin [% of captured interval]", "y");
  labdig(0, "x");
  labdig(1, "y");
  ticks(2, "x");
  ticks(2, "y");
  graf(X_MIN_CYCLES, X_MAX_CYCLES, -1000.0f, 512.0f, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);

  color("green");
  linwid(4);
  rline((float)RBCAM_LOW_CYCLES, 0.0f, (float)RBCAM_LOW_CYCLES, ymax);
  rline((float)RBCAM_HIGH_CYCLES, 0.0f, (float)RBCAM_HIGH_CYCLES, ymax);

  color("black");
  linwid(2);
  rline((float)panel->peak_center, 0.0f, (float)panel->peak_center, ymax);

  color("blue");
  linwid(5);
  for (int bin = 0; bin < N_BINS; bin++) {
    float percent;
    if (panel->bins[bin] == 0) {
      continue;
    }
    if (panel->centers[bin] < X_MIN_CYCLES || panel->centers[bin] > X_MAX_CYCLES) {
      continue;
    }
    percent = 100.0f * (float)panel->bins[bin] / (float)panel->total;
    rline((float)panel->centers[bin], 0.0f, (float)panel->centers[bin], percent);
  }

  if (panel->meta_total != 0) {
    color("red");
    linwid(3);
    for (int bin = 0; bin < N_BINS; bin++) {
      float percent;
      if (panel->meta_bins[bin] == 0) {
        continue;
      }
      if (panel->centers[bin] < X_MIN_CYCLES || panel->centers[bin] > X_MAX_CYCLES) {
        continue;
      }
      percent = 100.0f * (float)panel->meta_bins[bin] / (float)panel->meta_total;
      rline((float)panel->centers[bin] + 12.0f, 0.0f, (float)panel->centers[bin] + 12.0f, percent);
    }
  }

  linwid(1);
  color("fore");
  endgrf();

  snprintf(line1,
           sizeof(line1),
           "total=%lld hits; nonzero=%d/%d; peak bin=%d at %d cycles (%.3f%%)",
           panel->total,
           panel->nonzero_bins,
           N_BINS,
           panel->peak_bin,
           panel->peak_center,
           panel->peak_percent);
  snprintf(line2,
           sizeof(line2),
           "CSR range=%d..%d cycles; rbCAM[%d,%d] in=%lld (%.6f%%), out=%lld",
           panel->min_center,
           panel->max_center,
           RBCAM_LOW_CYCLES,
           RBCAM_HIGH_CYCLES,
           panel->in_window,
           100.0f * (float)panel->in_window / (float)panel->total,
           panel->out_window);
  if (panel->meta_total != 0) {
    snprintf(line3,
             sizeof(line3),
             "red=ingress meta checkpoint: total=%lld, range=%d..%d, peak=%d cycles (%.3f%%)",
             panel->meta_total,
             panel->meta_min_center,
             panel->meta_max_center,
             panel->meta_peak_center,
             panel->meta_peak_percent);
  } else {
    snprintf(line3, sizeof(line3), "blue=CSR histogram bins; green=rbCAM window; black=CSR peak");
  }
  panel_message_left(line1, axis_x, axis_y + 138, 13);
  panel_message_left(line2, axis_x, axis_y + 162, 13);
  panel_message_left(line3, axis_x, axis_y + 186, 13);
}

static void render_plot(panel_t panels[N_RATES],
                        const char *source,
                        const char *pattern_label,
                        const char *out_path) {
  int xs[2] = {260, 1600};
  int ys[2] = {760, 1575};
  const int axis_w = 1000;
  const int axis_h = 300;
  char title[256];
  char subtitle[320];

  start_page(out_path);
  snprintf(title,
           sizeof(title),
           "FEB generated RTL Type1 delay histogram sweep");
  snprintf(subtitle,
           sizeof(subtitle),
           "10 ms RUNNING, 1 ms ping-pong reads, %s, %s, rbCAM window [%d,%d] cycles",
           source,
           pattern_label,
           RBCAM_LOW_CYCLES,
           RBCAM_HIGH_CYCLES);
  page_message_centered(title, 72, 42);
  page_message_centered(subtitle, 128, 26);

  for (int i = 0; i < N_RATES; i++) {
    int row = i / 2;
    int col = i % 2;
    draw_panel(&panels[i], xs[col], ys[row], axis_w, axis_h);
  }

  page_message_centered("Bars are direct 1 ms in-run histogram-bin readbacks accumulated over the 10 ms RUNNING window; no post-read rescaling.", 2034, 22);
  disfin();
}

int main(int argc, char **argv) {
  panel_t panels[N_RATES];

  if (argc != 6 && argc != 7) {
    fprintf(stderr, "usage: %s <delay_bins.csv> <summary.csv> <source_name> <pattern_suffix> <output.png|output.pdf> [type1_meta.csv]\n", argv[0]);
    return 2;
  }
  if (!read_summaries(argv[2], argv[3], argv[4], panels)) {
    return 1;
  }
  if (!read_delay_bins(argv[1], panels)) {
    return 1;
  }
  if (argc == 7 && !read_meta_bins(argv[6], panels)) {
    return 1;
  }
  if (!compute_panel_stats(panels)) {
    return 1;
  }
  render_plot(panels,
              argv[3],
              strcmp(argv[4], "allch") == 0 ? "all 32 channels enabled per active ASIC" :
              strcmp(argv[4], "l2allch") == 0 ? "raw MuTRiG L2 FIFO, ASIC0 all 32 channels" :
              strcmp(argv[4], "onech") == 0 ? "header-sync one channel per active ASIC" :
                                                "one random channel per active ASIC",
              argv[5]);

  printf("TYPE1_DELAY_DISLIN_RENDER source=%s pattern=%s totals=%lld,%lld,%lld,%lld peaks=%d,%d,%d,%d output=%s\n",
         argv[3],
         argv[4],
         panels[0].total,
         panels[1].total,
         panels[2].total,
         panels[3].total,
         panels[0].peak_center,
         panels[1].peak_center,
         panels[2].peak_center,
         panels[3].peak_center,
         argv[5]);
  return 0;
}
