#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_POINTS 128
#define MAX_TOKENS 32
#define PAGE_WIDTH 2970
#define PAGE_HEIGHT 2100
#define CLK_HZ 125000000.0f

typedef struct {
  char case_name[160];
  char pattern[160];
  int rate_hz;
  int run_cycles;
  int interval_cycles;
  long long expected;
  long long total;
  long long dropped;
  long long bin_sum;
  int active_asics;
  char result[32];
} summary_t;

typedef struct {
  int n;
  float read_ms[MAX_POINTS];
  float total_rate_khz[MAX_POINTS];
  float bin_rate_khz[MAX_POINTS];
  float total_hits[MAX_POINTS];
  float bin_hits[MAX_POINTS];
  float target_rate_khz[MAX_POINTS];
  float target_hits[MAX_POINTS];
  float dropped_hits[MAX_POINTS];
  unsigned int bank_status[MAX_POINTS];
} series_t;

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

static int read_summary(const char *path, const char *case_name, summary_t *summary) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "could not open summary CSV: %s\n", path);
    return 0;
  }

  memset(summary, 0, sizeof(*summary));
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 20 || strcmp(tokens[0], case_name) != 0) {
      continue;
    }

    snprintf(summary->case_name, sizeof(summary->case_name), "%s", tokens[0]);
    snprintf(summary->pattern, sizeof(summary->pattern), "%s", tokens[4]);
    summary->rate_hz = atoi(tokens[3]);
    summary->run_cycles = atoi(tokens[5]);
    summary->interval_cycles = atoi(tokens[6]);
    summary->expected = atoll(tokens[7]);
    summary->total = atoll(tokens[12]);
    summary->dropped = atoll(tokens[13]);
    summary->bin_sum = atoll(tokens[14]);
    if (ntok >= 21) {
      summary->active_asics = atoi(tokens[18]);
      snprintf(summary->result, sizeof(summary->result), "%s", tokens[20]);
    } else {
      int period = summary->rate_hz > 0 ? (int)(CLK_HZ / (float)summary->rate_hz) : 0;
      int hits_per_source = period > 0 ? summary->run_cycles / period : 0;
      summary->active_asics = hits_per_source > 0 ? (int)(summary->expected / hits_per_source) : 0;
      snprintf(summary->result, sizeof(summary->result), "%s", tokens[19]);
    }
    if (summary->active_asics <= 0) {
      fprintf(stderr, "invalid active ASIC count derived from summary for case %s\n", case_name);
      fclose(fp);
      return 0;
    }
    fclose(fp);
    return 1;
  }

  fclose(fp);
  fprintf(stderr, "case %s not found in summary CSV: %s\n", case_name, path);
  return 0;
}

static int read_intervals(const char *path, const summary_t *summary, series_t *series) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;
  const float interval_s = (float)summary->interval_cycles / CLK_HZ;
  const float interval_ms = interval_s * 1000.0f;
  const float target_rate_khz = (float)summary->rate_hz / 1000.0f;
  const float active_asics = (float)summary->active_asics;
  const float target_hits = ((float)summary->rate_hz * interval_s) * active_asics;

  if (fp == NULL) {
    fprintf(stderr, "could not open interval CSV: %s\n", path);
    return 0;
  }

  memset(series, 0, sizeof(*series));
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;
    int row;
    float total_hits;
    float bin_hits;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok < 15 || strcmp(tokens[0], summary->case_name) != 0) {
      continue;
    }
    if (series->n >= MAX_POINTS) {
      fprintf(stderr, "too many interval rows; max=%d\n", MAX_POINTS);
      fclose(fp);
      return 0;
    }

    row = series->n;
    idx = atoi(tokens[1]);
    total_hits = (float)atof(tokens[5]);
    bin_hits = (float)atof(tokens[7]);
    series->read_ms[row] = ((float)idx + 1.0f) * interval_ms;
    series->total_hits[row] = total_hits;
    series->bin_hits[row] = bin_hits;
    series->dropped_hits[row] = (float)atof(tokens[6]);
    series->total_rate_khz[row] = total_hits / interval_s / active_asics / 1000.0f;
    series->bin_rate_khz[row] = bin_hits / interval_s / active_asics / 1000.0f;
    series->target_rate_khz[row] = target_rate_khz;
    series->target_hits[row] = target_hits;
    series->bank_status[row] = (unsigned int)strtoul(tokens[14], NULL, 0);
    series->n++;
  }

  fclose(fp);
  if (series->n == 0) {
    fprintf(stderr, "no interval rows found for case %s in %s\n", summary->case_name, path);
    return 0;
  }
  return 1;
}

static float nice_step(float raw) {
  float exponent;
  float base;
  float scaled;

  if (raw <= 0.0f) {
    return 1.0f;
  }
  exponent = floorf(log10f(raw));
  base = powf(10.0f, exponent);
  scaled = raw / base;
  if (scaled <= 1.0f) {
    return base;
  }
  if (scaled <= 2.0f) {
    return 2.0f * base;
  }
  if (scaled <= 5.0f) {
    return 5.0f * base;
  }
  return 10.0f * base;
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

static void draw_curve(const char *line_color,
                       int dashed,
                       int width,
                       int marker_id,
                       const float *x,
                       const float *y,
                       int n) {
  color(line_color);
  if (dashed) {
    dash();
  } else {
    solid();
  }
  linwid(width);
  marker(marker_id);
  curve((float *)x, (float *)y, n);
  marker(0);
  solid();
  linwid(1);
  color("fore");
}

static void minmax2(const float *a,
                    const float *b,
                    int n,
                    float seed,
                    float *min_out,
                    float *max_out) {
  float mn = seed;
  float mx = seed;

  for (int i = 0; i < n; i++) {
    if (a[i] < mn) {
      mn = a[i];
    }
    if (a[i] > mx) {
      mx = a[i];
    }
    if (b[i] < mn) {
      mn = b[i];
    }
    if (b[i] > mx) {
      mx = b[i];
    }
  }
  *min_out = mn;
  *max_out = mx;
}

static void draw_rate_panel(const summary_t *summary, const series_t *series) {
  const int axis_x = 360;
  const int axis_y = 900;
  const int axis_w = 2300;
  const int axis_h = 520;
  const float run_ms = (float)summary->run_cycles / CLK_HZ * 1000.0f;
  const float target = (float)summary->rate_hz / 1000.0f;
  float ymin;
  float ymax;
  float ypad;
  float ystep;

  minmax2(series->total_rate_khz, series->bin_rate_khz, series->n, target, &ymin, &ymax);
  ypad = fmaxf(target * 0.02f, (ymax - ymin) * 0.30f);
  if (ypad < 10.0f) {
    ypad = 10.0f;
  }
  ymin -= ypad;
  ymax += ypad;
  ystep = nice_step((ymax - ymin) / 5.0f);
  ymin = floorf(ymin / ystep) * ystep;
  ymax = ceilf(ymax / ystep) * ystep;

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  name("ping-pong read time while RUNNING [ms]", "x");
  name("per-ASIC Type0 rate [kHz]", "y");
  labdig(1, "x");
  labdig(0, "y");
  ticks(2, "x");
  graf(0.0f, run_ms, 0.0f, 1.0f, ymin, ymax, ymin, ystep);
  grid(1, 1);

  incmrk(1);
  hsymbl(32);
  draw_curve("black", 1, 3, 0, series->read_ms, series->target_rate_khz, series->n);
  draw_curve("green", 1, 5, 1, series->read_ms, series->bin_rate_khz, series->n);
  draw_curve("blue", 0, 7, 3, series->read_ms, series->total_rate_khz, series->n);
  endgrf();
}

static void draw_count_panel(const summary_t *summary, const series_t *series) {
  const int axis_x = 360;
  const int axis_y = 1700;
  const int axis_w = 2300;
  const int axis_h = 520;
  const float run_ms = (float)summary->run_cycles / CLK_HZ * 1000.0f;
  const float target = series->target_hits[0];
  float ymin;
  float ymax;
  float ypad;
  float ystep;

  minmax2(series->total_hits, series->bin_hits, series->n, target, &ymin, &ymax);
  ypad = fmaxf(target * 0.05f, (ymax - ymin) * 0.30f);
  if (ypad < 10.0f) {
    ypad = 10.0f;
  }
  ymin -= ypad;
  ymax += ypad;
  ystep = nice_step((ymax - ymin) / 5.0f);
  ymin = floorf(ymin / ystep) * ystep;
  ymax = ceilf(ymax / ystep) * ystep;

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  name("ping-pong read time while RUNNING [ms]", "x");
  name("hits per 1 ms bank read", "y");
  labdig(1, "x");
  labdig(0, "y");
  ticks(2, "x");
  graf(0.0f, run_ms, 0.0f, 1.0f, ymin, ymax, ymin, ystep);
  grid(1, 1);

  incmrk(1);
  hsymbl(32);
  draw_curve("black", 1, 3, 0, series->read_ms, series->target_hits, series->n);
  draw_curve("green", 1, 5, 1, series->read_ms, series->bin_hits, series->n);
  draw_curve("blue", 0, 7, 3, series->read_ms, series->total_hits, series->n);
  endgrf();
}

static void render_plot(const summary_t *summary, const series_t *series, const char *out_path) {
  char title[256];
  char subtitle[320];
  char caption[320];

  start_page(out_path);
  snprintf(title,
           sizeof(title),
           "FEB generated RTL Type0 max-rate ping-pong readback");
  snprintf(subtitle,
           sizeof(subtitle),
           "10 ms RUNNING, 1 ms ping-pong bank reads, %d kHz/ASIC, %s, active ASICs=%d",
           summary->rate_hz / 1000,
           summary->pattern,
           summary->active_asics);
  page_message_centered(title, 82, 46);
  page_message_centered(subtitle, 138, 30);
  page_message_centered("No post-END_RUN readback or rescaling: plotted points are the in-run 1 ms latch and bin reads.", 178, 24);

  draw_rate_panel(summary, series);
  draw_count_panel(summary, series);
  page_message_centered("blue = CSR LAST_TOTAL readback, green = 256-bin sum readback, black dashed = declared target", 1990, 22);
  snprintf(caption,
           sizeof(caption),
           "Result: %d in-run reads, %.0f hits/read expected, total=%lld, bin_sum=%lld, dropped=%lld, %s",
           series->n,
           series->target_hits[0],
           summary->total,
           summary->bin_sum,
           summary->dropped,
           summary->result);
  page_message_centered(caption, 2025, 22);
  disfin();
}

int main(int argc, char **argv) {
  summary_t summary;
  series_t series;

  if (argc != 5) {
    fprintf(stderr, "usage: %s <intervals.csv> <summary.csv> <case_name> <output.png|output.pdf>\n", argv[0]);
    return 2;
  }
  if (!read_summary(argv[2], argv[3], &summary)) {
    return 1;
  }
  if (strcmp(summary.result, "PASS") != 0) {
    fprintf(stderr, "case %s is not PASS in summary (%s)\n", argv[3], summary.result);
    return 1;
  }
  if (!read_intervals(argv[1], &summary, &series)) {
    return 1;
  }

  render_plot(&summary, &series, argv[4]);
  printf("TYPE0_RATE_DISLIN_RENDER case=%s points=%d target_khz=%.3f total=%lld dropped=%lld bin_sum=%lld output=%s\n",
         summary.case_name,
         series.n,
         (float)summary.rate_hz / 1000.0f,
         summary.total,
         summary.dropped,
         summary.bin_sum,
         argv[4]);
  return 0;
}
