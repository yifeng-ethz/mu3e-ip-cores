#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define N_BINS 256
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
  char pattern[160];
  char result[32];
  char delay_model[120];
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

static void header_case_name(char *buf, size_t buf_sz, const char *source) {
  snprintf(buf, buf_sz, "%s_latency_hsync910_qsys", source);
}

static int read_summary(const char *path, const char *source, panel_t *panel) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  char wanted[160];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "could not open summary CSV: %s\n", path);
    return 0;
  }

  memset(panel, 0, sizeof(*panel));
  header_case_name(wanted, sizeof(wanted), source);
  for (int bin = 0; bin < N_BINS; bin++) {
    panel->centers[bin] = bin * 32;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 23 || strcmp(tokens[0], wanted) != 0) {
      continue;
    }

    snprintf(panel->summary.case_name, sizeof(panel->summary.case_name), "%s", tokens[0]);
    snprintf(panel->summary.source, sizeof(panel->summary.source), "%s", tokens[1]);
    panel->summary.rate_hz = atoi(tokens[3]);
    snprintf(panel->summary.pattern, sizeof(panel->summary.pattern), "%s", tokens[4]);
    panel->summary.run_cycles = atoi(tokens[5]);
    panel->summary.interval_cycles = atoi(tokens[6]);
    panel->summary.expected = atoll(tokens[7]);
    panel->summary.total = atoll(tokens[12]);
    panel->summary.dropped = atoll(tokens[13]);
    panel->summary.bin_sum = atoll(tokens[14]);
    panel->summary.active_asics = atoi(tokens[18]);
    snprintf(panel->summary.result, sizeof(panel->summary.result), "%s", tokens[20]);
    snprintf(panel->summary.delay_model, sizeof(panel->summary.delay_model), "%s", tokens[21]);
    panel->summary.delay_target_cycles = atoi(tokens[22]);
    fclose(fp);
    if (strcmp(panel->summary.result, "PASS") != 0) {
      fprintf(stderr, "summary row is not PASS for %s: %s\n",
              panel->summary.case_name,
              panel->summary.result);
      return 0;
    }
    return 1;
  }

  fclose(fp);
  fprintf(stderr, "missing summary row for %s in %s\n", wanted, path);
  return 0;
}

static int read_delay_bins(const char *path, panel_t *panel) {
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
    int bin;
    long long count;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 15 || strcmp(tokens[0], panel->summary.case_name) != 0) {
      continue;
    }
    bin = atoi(tokens[9]);
    if (bin < 0 || bin >= N_BINS) {
      fprintf(stderr, "bad bin index %d for case %s\n", bin, tokens[0]);
      fclose(fp);
      return 0;
    }
    panel->centers[bin] = atoi(tokens[10]);
    count = atoll(tokens[11]);
    panel->bins[bin] += count;
    matched++;
  }
  fclose(fp);

  if (matched == 0) {
    fprintf(stderr, "no delay-bin rows matched %s in %s\n",
            panel->summary.case_name,
            path);
    return 0;
  }
  return 1;
}

static int read_meta_bins(const char *path, panel_t *panel) {
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
    int latency;
    int bin;
    int ready;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 16 || strcmp(tokens[0], panel->summary.case_name) != 0) {
      continue;
    }
    ready = atoi(tokens[15]);
    if (!ready) {
      continue;
    }
    latency = atoi(tokens[10]);
    if (latency < 0) {
      fprintf(stderr, "negative metadata latency %d for case %s\n",
              latency,
              tokens[0]);
      fclose(fp);
      return 0;
    }
    bin = latency / 32;
    if (bin < 0 || bin >= N_BINS) {
      fprintf(stderr, "metadata latency %d is outside %d bins for case %s\n",
              latency,
              N_BINS,
              tokens[0]);
      fclose(fp);
      return 0;
    }
    panel->meta_bins[bin]++;
    matched++;
  }
  fclose(fp);

  if (matched == 0) {
    fprintf(stderr, "no Type1 metadata rows matched %s in %s\n",
            panel->summary.case_name,
            path);
    return 0;
  }
  return 1;
}

static int compute_stats(panel_t *panel) {
  long long peak_count = 0;
  long long meta_peak_count = 0;

  panel->total = 0;
  panel->meta_total = 0;
  panel->in_window = 0;
  panel->out_window = 0;
  panel->nonzero_bins = 0;
  panel->meta_nonzero_bins = 0;
  panel->peak_bin = -1;
  panel->meta_peak_bin = -1;
  panel->min_center = 0;
  panel->max_center = 0;
  panel->meta_min_center = 0;
  panel->meta_max_center = 0;

  for (int bin = 0; bin < N_BINS; bin++) {
    long long count = panel->bins[bin];
    long long meta_count = panel->meta_bins[bin];
    int center = panel->centers[bin];

    panel->total += count;
    panel->meta_total += meta_count;
    if (count != 0) {
      if (panel->nonzero_bins == 0) {
        panel->min_center = center;
        panel->max_center = center;
      } else {
        if (center < panel->min_center) {
          panel->min_center = center;
        }
        if (center > panel->max_center) {
          panel->max_center = center;
        }
      }
      panel->nonzero_bins++;
      if (center >= RBCAM_LOW_CYCLES && center <= RBCAM_HIGH_CYCLES) {
        panel->in_window += count;
      } else {
        panel->out_window += count;
      }
      if (count > peak_count) {
        peak_count = count;
        panel->peak_bin = bin;
        panel->peak_center = center;
      }
    }
    if (meta_count != 0) {
      if (panel->meta_nonzero_bins == 0) {
        panel->meta_min_center = center;
        panel->meta_max_center = center;
      } else {
        if (center < panel->meta_min_center) {
          panel->meta_min_center = center;
        }
        if (center > panel->meta_max_center) {
          panel->meta_max_center = center;
        }
      }
      panel->meta_nonzero_bins++;
      if (meta_count > meta_peak_count) {
        meta_peak_count = meta_count;
        panel->meta_peak_bin = bin;
        panel->meta_peak_center = center;
      }
    }
  }

  if (panel->total == 0) {
    fprintf(stderr, "case %s has no delay-bin hits\n", panel->summary.case_name);
    return 0;
  }
  if (panel->out_window != 0) {
    fprintf(stderr,
            "case %s has %lld hits outside rbCAM [%d,%d] cycles; range [%d,%d]\n",
            panel->summary.case_name,
            panel->out_window,
            RBCAM_LOW_CYCLES,
            RBCAM_HIGH_CYCLES,
            panel->min_center,
            panel->max_center);
    return 0;
  }
  if (panel->summary.bin_sum != panel->total) {
    fprintf(stderr,
            "case %s summary bin_sum=%lld but delay-bin CSV total=%lld\n",
            panel->summary.case_name,
            panel->summary.bin_sum,
            panel->total);
    return 0;
  }
  if (panel->meta_total != 0 && panel->meta_total != panel->total) {
    fprintf(stderr,
            "case %s metadata total=%lld but CSR delay-bin total=%lld\n",
            panel->summary.case_name,
            panel->meta_total,
            panel->total);
    return 0;
  }
  if (panel->nonzero_bins != 1) {
    fprintf(stderr,
            "case %s CSR histogram is not delta-like: nonzero bins=%d\n",
            panel->summary.case_name,
            panel->nonzero_bins);
    return 0;
  }
  if (panel->meta_total != 0 && panel->meta_nonzero_bins != 1) {
    fprintf(stderr,
            "case %s metadata histogram is not delta-like: nonzero bins=%d\n",
            panel->summary.case_name,
            panel->meta_nonzero_bins);
    return 0;
  }

  panel->peak_percent = 100.0f * (float)peak_count / (float)panel->total;
  panel->meta_peak_percent = panel->meta_total == 0 ? 0.0f :
    100.0f * (float)meta_peak_count / (float)panel->meta_total;
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

static void panel_message_left(const char *text, int x, int y, int h) {
  height(h);
  messag(text, x, y);
}

static void draw_panel(const panel_t *panel) {
  const int axis_x = 390;
  const int axis_y = 1370;
  const int axis_w = 2200;
  const int axis_h = 620;
  char title[256];
  char subtitle[320];
  char line1[320];
  char line2[320];
  char line3[320];
  float peak_for_axis = panel->meta_peak_percent > panel->peak_percent ?
                        panel->meta_peak_percent : panel->peak_percent;
  float ymax = nice_ymax(peak_for_axis * 1.18f);
  float ystep = ymax / 5.0f;

  snprintf(title,
           sizeof(title),
           "Header-sync mimic delay: %s, internal trigger 910 cycles",
           panel->summary.source);
  snprintf(subtitle,
           sizeof(subtitle),
           "10 ms RUNNING, 1 ms ping-pong reads, one channel per active ASIC, %s",
           panel->summary.delay_model);
  page_message_centered(title, 160, 34);
  page_message_centered(subtitle, 214, 24);

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  height(20);
  hname(24);
  labdis(14, "xy");
  namdis(28, "xy");
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
  linwid(8);
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
    linwid(5);
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
           "CSR total=%lld hits; nonzero=%d/%d; peak bin=%d at %d cycles (%.3f%%)",
           panel->total,
           panel->nonzero_bins,
           N_BINS,
           panel->peak_bin,
           panel->peak_center,
           panel->peak_percent);
  snprintf(line2,
           sizeof(line2),
           "CSR range=%d..%d cycles; rbCAM[%d,%d] in=%lld (%.6f%%), out=%lld; target=%d cycles",
           panel->min_center,
           panel->max_center,
           RBCAM_LOW_CYCLES,
           RBCAM_HIGH_CYCLES,
           panel->in_window,
           100.0f * (float)panel->in_window / (float)panel->total,
           panel->out_window,
           panel->summary.delay_target_cycles);
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
  panel_message_left(line1, axis_x, axis_y + 154, 22);
  panel_message_left(line2, axis_x, axis_y + 194, 22);
  panel_message_left(line3, axis_x, axis_y + 234, 22);
}

static void render_plot(const panel_t *panel, const char *out_path) {
  char footer[320];
  const float rate_khz = (float)panel->summary.rate_hz / 1000.0f;

  start_page(out_path);
  page_message_centered("FEB generated RTL Type1 header-sync delay histogram", 82, 42);
  snprintf(footer,
           sizeof(footer),
           "rate %.3f kHz/ASIC from 125 MHz / 910 cycles; active ASICs=%d; blue=CSR readback, red=meta checkpoint, no post-read rescaling.",
           rate_khz,
           panel->summary.active_asics);
  draw_panel(panel);
  page_message_centered(footer, 2028, 24);
  disfin();
}

int main(int argc, char **argv) {
  panel_t panel;

  if (argc != 5 && argc != 6) {
    fprintf(stderr, "usage: %s <delay_bins.csv> <summary.csv> <source_name> <output.png|output.pdf> [type1_meta.csv]\n", argv[0]);
    return 2;
  }
  if (!read_summary(argv[2], argv[3], &panel)) {
    return 1;
  }
  if (!read_delay_bins(argv[1], &panel)) {
    return 1;
  }
  if (argc == 6 && !read_meta_bins(argv[5], &panel)) {
    return 1;
  }
  if (!compute_stats(&panel)) {
    return 1;
  }
  render_plot(&panel, argv[4]);
  printf("TYPE1_HEADER_SYNC_DISLIN_RENDER source=%s total=%lld peak=%d meta_total=%lld meta_peak=%d output=%s\n",
         argv[3],
         panel.total,
         panel.peak_center,
         panel.meta_total,
         panel.meta_peak_center,
         argv[4]);
  return 0;
}
