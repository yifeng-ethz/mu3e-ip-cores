#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_VALUES 65536
#define MAX_BINS 256
#define MAX_TOKENS 40
#define PAGE_WIDTH 2970
#define PAGE_HEIGHT 4200

typedef struct {
  const char *key;
  const char *label;
  const char *color;
  const char *equation;
  int col;
  float bound_low;
  float bound_high;
  int n;
  float values[MAX_VALUES];
} metric_t;

typedef struct {
  int n;
  float min;
  float p50;
  float p95;
  float max;
  float mean;
} stats_t;

typedef struct {
  int n;
  float frame_seq[MAX_VALUES];
  float wait_cycles[MAX_VALUES];
  float model_wait_cycles[MAX_VALUES];
  float input_hits[MAX_VALUES];
  float output_hits[MAX_VALUES];
  float missing_hits[MAX_VALUES];
  float ingress_iat_cycles[MAX_VALUES];
  float service_iat_cycles[MAX_VALUES];
  int n_ingress_iat;
  int n_service_iat;
} queue_model_t;

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot == NULL) {
    return "PNG";
  }
  if (strcasecmp(dot, ".pdf") == 0) {
    return "PDF";
  }
  if (strcasecmp(dot, ".svg") == 0) {
    return "SVG";
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

static int read_lifetime_csv(const char *path, metric_t *metrics, int nmetrics) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "could not open lifetime CSV: %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;

    if (first) {
      first = 0;
      continue;
    }

    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok <= 17) {
      continue;
    }

    for (int i = 0; i < nmetrics; i++) {
      const int col = metrics[i].col;
      if (col >= ntok || tokens[col][0] == '\0' || metrics[i].n >= MAX_VALUES) {
        continue;
      }
      metrics[i].values[metrics[i].n++] = (float)atof(tokens[col]);
    }
  }

  fclose(fp);
  return 1;
}

static void make_sibling_path(const char *path,
                              const char *name,
                              char *out,
                              size_t out_size) {
  const char *slash = strrchr(path, '/');
  if (slash == NULL) {
    snprintf(out, out_size, "%s", name);
    return;
  }
  snprintf(out, out_size, "%.*s/%s", (int)(slash - path), path, name);
}

static void read_reference_csv(const char *path, metric_t *metrics, int nmetrics) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "reference rbCAM CSV not found, using corun markers: %s\n", path);
    return;
  }

  for (int i = 0; i < nmetrics && i < 2; i++) {
    metrics[i].n = 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok <= 3) {
      continue;
    }
    for (int i = 0; i < nmetrics; i++) {
      if (strcmp(tokens[0], metrics[i].key) != 0 || metrics[i].n >= MAX_VALUES) {
        continue;
      }
      metrics[i].values[metrics[i].n++] = (float)atof(tokens[3]);
    }
  }

  fclose(fp);
}

static void read_bounds_csv(const char *path, metric_t *metrics, int nmetrics) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "range validation CSV not found, using default bounds: %s\n", path);
    return;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    float low;
    float high;

    if (first) {
      first = 0;
      continue;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok <= 4) {
      continue;
    }
    low = (float)atof(tokens[3]);
    high = (float)atof(tokens[4]);
    for (int i = 0; i < nmetrics; i++) {
      if (strcmp(tokens[1], metrics[i].key) != 0) {
        continue;
      }
      if ((i == 0 || i == 1) && fabsf(high - low) < 0.001f) {
        continue;
      }
      metrics[i].bound_low = low;
      metrics[i].bound_high = high;
    }
  }

  fclose(fp);
}

static int read_queue_model_csv(const char *path, queue_model_t *model) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "could not open OPQ queue CSV: %s\n", path);
    return 0;
  }

  memset(model, 0, sizeof(*model));
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;

    if (first) {
      first = 0;
      continue;
    }
    if (model->n >= MAX_VALUES) {
      break;
    }

    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok <= 11) {
      continue;
    }

    idx = model->n++;
    model->frame_seq[idx] = (float)atof(tokens[0]);
    model->ingress_iat_cycles[idx] = (tokens[4][0] == '\0') ? 0.0f : (float)atof(tokens[4]);
    model->service_iat_cycles[idx] = (tokens[5][0] == '\0') ? 0.0f : (float)atof(tokens[5]);
    model->wait_cycles[idx] = (float)atof(tokens[6]);
    model->model_wait_cycles[idx] = (float)atof(tokens[7]);
    model->input_hits[idx] = (float)atof(tokens[9]);
    model->output_hits[idx] = (float)atof(tokens[10]);
    model->missing_hits[idx] = (float)atof(tokens[11]);
    if (tokens[4][0] != '\0' && model->n_ingress_iat < MAX_VALUES) {
      model->ingress_iat_cycles[model->n_ingress_iat++] = (float)atof(tokens[4]);
    }
    if (tokens[5][0] != '\0' && model->n_service_iat < MAX_VALUES) {
      model->service_iat_cycles[model->n_service_iat++] = (float)atof(tokens[5]);
    }
  }

  fclose(fp);
  return 1;
}

static int cmp_float(const void *lhs, const void *rhs) {
  const float a = *(const float *)lhs;
  const float b = *(const float *)rhs;
  return (a > b) - (a < b);
}

static float percentile_sorted(const float *values, int n, float pct) {
  float rank;
  int low;
  int high;
  float frac;

  if (n <= 0) {
    return 0.0f;
  }
  if (n == 1) {
    return values[0];
  }

  rank = (pct / 100.0f) * (float)(n - 1);
  low = (int)floorf(rank);
  high = low + 1;
  if (high >= n) {
    high = n - 1;
  }
  frac = rank - (float)low;
  return values[low] * (1.0f - frac) + values[high] * frac;
}

static stats_t compute_stats(const metric_t *metric) {
  stats_t stats = {0};
  float *sorted;
  double sum = 0.0;

  stats.n = metric->n;
  if (metric->n <= 0) {
    return stats;
  }

  sorted = (float *)malloc((size_t)metric->n * sizeof(float));
  if (sorted == NULL) {
    fprintf(stderr, "could not allocate stats buffer\n");
    exit(1);
  }
  memcpy(sorted, metric->values, (size_t)metric->n * sizeof(float));
  qsort(sorted, (size_t)metric->n, sizeof(float), cmp_float);

  for (int i = 0; i < metric->n; i++) {
    sum += metric->values[i];
  }

  stats.min = sorted[0];
  stats.p50 = percentile_sorted(sorted, metric->n, 50.0f);
  stats.p95 = percentile_sorted(sorted, metric->n, 95.0f);
  stats.max = sorted[metric->n - 1];
  stats.mean = (float)(sum / (double)metric->n);
  free(sorted);
  return stats;
}

static stats_t compute_array_stats(const float *values, int n) {
  stats_t stats = {0};
  float *sorted;
  double sum = 0.0;

  stats.n = n;
  if (n <= 0) {
    return stats;
  }

  sorted = (float *)malloc((size_t)n * sizeof(float));
  if (sorted == NULL) {
    fprintf(stderr, "could not allocate stats buffer\n");
    exit(1);
  }
  memcpy(sorted, values, (size_t)n * sizeof(float));
  qsort(sorted, (size_t)n, sizeof(float), cmp_float);

  for (int i = 0; i < n; i++) {
    sum += values[i];
  }

  stats.min = sorted[0];
  stats.p50 = percentile_sorted(sorted, n, 50.0f);
  stats.p95 = percentile_sorted(sorted, n, 95.0f);
  stats.max = sorted[n - 1];
  stats.mean = (float)(sum / (double)n);
  free(sorted);
  return stats;
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

static int common_histogram_bin_count(float xmin, float xmax) {
  int bins = (int)ceilf((xmax - xmin) / 512.0f);
  if (bins < 32) {
    bins = 32;
  }
  if (bins > MAX_BINS) {
    bins = MAX_BINS;
  }
  return bins;
}

static void start_page(const char *out_path) {
  const char *fmt = output_format_from_path(out_path);
  metafl(fmt);
  setfil(out_path);
  filmod("delete");
  if (strcasecmp(fmt, "PNG") == 0) {
    winsiz(1800, 2545);
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

static void draw_vertical(const char *line_color, float x, float ymax, int dashed) {
  float xs[2] = {x, x};
  float ys[2] = {0.0f, ymax};

  color(line_color);
  if (dashed) {
    dash();
  } else {
    solid();
  }
  linwid(5);
  curve(xs, ys, 2);
  solid();
  linwid(1);
}

static void compute_common_x_range(metric_t *metrics,
                                   int nmetrics,
                                   float *xmin_out,
                                   float *xmax_out) {
  float xmin = 0.0f;
  float xmax = 1.0f;
  int seen = 0;

  for (int i = 0; i < nmetrics; i++) {
    stats_t stats = compute_stats(&metrics[i]);
    if (stats.n > 0) {
      if (!seen || stats.min < xmin) {
        xmin = stats.min;
      }
      if (!seen || stats.max > xmax) {
        xmax = stats.max;
      }
      seen = 1;
    }
    if (!seen || metrics[i].bound_low < xmin) {
      xmin = metrics[i].bound_low;
    }
    if (!seen || metrics[i].bound_high > xmax) {
      xmax = metrics[i].bound_high;
    }
  }

  if (xmin > 0.0f) {
    xmin = 0.0f;
  }
  if (fabsf(xmax - xmin) < 1.0f) {
    xmax = xmin + 1.0f;
  }
  xmax = ceilf((xmax + 1000.0f) / 5000.0f) * 5000.0f;
  if (xmin < 0.0f) {
    xmin = floorf((xmin - 1000.0f) / 5000.0f) * 5000.0f;
  }
  *xmin_out = xmin;
  *xmax_out = xmax;
}

static void draw_panel(metric_t *metric,
                       int panel_index,
                       float common_xmin,
                       float common_xmax) {
  static const int y_positions[5] = {780, 1500, 2220, 2940, 3660};
  const int axis_x = 430;
  const int axis_y = y_positions[panel_index];
  const int axis_w = 2200;
  const int axis_h = 380;
  const int bins = common_histogram_bin_count(common_xmin, common_xmax);
  stats_t stats = compute_stats(metric);
  float xmin = common_xmin;
  float xmax = common_xmax;
  float xrange;
  float bin_width;
  float xstep;
  float ymax = 1.0f;
  float ystep;
  float xbins[MAX_BINS];
  float yzero[MAX_BINS];
  float ycount[MAX_BINS];
  char title_buf[160];
  char equation_buf[220];
  int counts[MAX_BINS] = {0};

  snprintf(title_buf,
           sizeof(title_buf),
           "%s checkpoint lifetime, bound [%.1f, %.1f] cycles",
           metric->label,
           metric->bound_low,
           metric->bound_high);
  page_message_centered(title_buf, axis_y - axis_h - 70, 34);
  snprintf(equation_buf, sizeof(equation_buf), "%s", metric->equation);
  page_message_centered(equation_buf, axis_y - axis_h - 32, 20);

  if (metric->n <= 0) {
    axspos(axis_x, axis_y);
    axslen(axis_w, axis_h);
    name("hit lifetime [8 ns cycles]", "x");
    name("hits / bin [%]", "y");
    graf(xmin, xmax, xmin, 1.0f, 0.0f, 1.0f, 0.0f, 0.2f);
    height(30);
    rlmess("no checkpoint samples", 0.35f, 0.55f);
    endgrf();
    return;
  }

  xrange = xmax - xmin;
  bin_width = xrange / (float)bins;

  for (int i = 0; i < metric->n; i++) {
    int bin = (int)floorf((metric->values[i] - xmin) / bin_width);
    if (bin < 0) {
      bin = 0;
    }
    if (bin >= bins) {
      bin = bins - 1;
    }
    counts[bin]++;
  }

  for (int i = 0; i < bins; i++) {
    xbins[i] = xmin + ((float)i + 0.5f) * bin_width;
    yzero[i] = 0.0f;
    ycount[i] = 100.0f * (float)counts[i] / (float)metric->n;
    if (ycount[i] > ymax) {
      ymax = ycount[i];
    }
  }

  ymax = ceilf(ymax * 1.18f);
  ystep = nice_step(ymax / 4.0f);
  ymax = ceilf(ymax / ystep) * ystep;
  xstep = nice_step(xrange / 5.0f);

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  name("hit lifetime [8 ns cycles]", "x");
  name("hits / bin [%]", "y");
  labdig(0, "x");
  labdig(0, "y");
  ticks(2, "x");
  graf(xmin, xmax, ceilf(xmin / xstep) * xstep, xstep, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);

  color(metric->color);
  barwth(0.85f);
  shdpat(16L);
  bars(xbins, yzero, ycount, bins);

  draw_vertical("green", metric->bound_low, ymax, 0);
  draw_vertical("green", metric->bound_high, ymax, 0);
  draw_vertical("black", stats.p50, ymax, 0);
  draw_vertical("black", stats.p95, ymax, 1);
  color("fore");
  solid();
  linwid(1);
  endgrf();

  printf(
      "%s n=%d min=%.3f p50=%.3f p95=%.3f max=%.3f mean=%.3f cycles\n",
      metric->key,
      stats.n,
      stats.min,
      stats.p50,
      stats.p95,
      stats.max,
      stats.mean);
}

static void render_lifetime_plot(const char *csv_path, const char *out_path) {
  metric_t metrics[] = {
      {"pre_rbcam_lifetime_cycles",
       "pre-rbCAM",
       "blue",
       "D_pre = T_pre - GTS_hit, reference window [0,2000]",
       13,
       0.0f,
       2000.0f,
       0,
       {0.0f}},
      {"post_rbcam_lifetime_cycles",
       "post-rbCAM",
       "green",
       "D_post = (GTS_post - ts_hit) mod 8192, window [2000,2200)",
       14,
       2000.0f,
       2200.0f,
       0,
       {0.0f}},
      {"feb_egress_lifetime_cycles",
       "FEB egress",
       "cyan",
       "D_feb <= 2F - p + 2O + eps_clk",
       15,
       2049.0f,
       6143.0f,
       0,
       {0.0f}},
      {"opq_ingress_lifetime_cycles",
       "OPQ ingress",
       "magenta",
       "D_ing = D_feb + adapter_sync",
       16,
       2049.0f,
       6159.0f,
       0,
       {0.0f}},
      {"opq_egress_lifetime_cycles",
       "OPQ egress",
       "red",
       "D_opq = D_ing + W_n, W_n=max(0,W_{n-1}+S_n-A_n)",
       17,
       0.0f,
       100000.0f,
       0,
       {0.0f}},
  };
  const int nmetrics = (int)(sizeof(metrics) / sizeof(metrics[0]));
  char reference_path[4096];
  char bounds_path[4096];
  float common_xmin;
  float common_xmax;

  if (!read_lifetime_csv(csv_path, metrics, nmetrics)) {
    exit(1);
  }
  make_sibling_path(csv_path, "feb_swb_rbcam_reference_trace.csv", reference_path, sizeof(reference_path));
  make_sibling_path(csv_path, "feb_swb_range_validation.csv", bounds_path, sizeof(bounds_path));
  read_reference_csv(reference_path, metrics, nmetrics);
  read_bounds_csv(bounds_path, metrics, nmetrics);
  compute_common_x_range(metrics, nmetrics, &common_xmin, &common_xmax);

  start_page(out_path);
  page_message_centered("FEB/SWB ASIC0 all-channel hit lifetime", 95, 46);
  page_message_centered("master equation: D_i = (T_i - GTS_hit) / 8 ns; alpha(t)=32*ceil(t/1250 cycles)", 152, 30);
  page_message_centered("all panels share one x-axis; green = derived bound, p50 = solid black, p95 = dashed black", 196, 26);

  for (int i = 0; i < nmetrics; i++) {
    draw_panel(&metrics[i], i, common_xmin, common_xmax);
  }

  disfin();
}

static void draw_queue_wait_panel(queue_model_t *model) {
  const int axis_x = 430;
  const int axis_y = 1680;
  const int axis_w = 2200;
  const int axis_h = 820;
  stats_t wait_stats = compute_array_stats(model->wait_cycles, model->n);
  float xmin = -1.0f;
  float xmax = (model->n > 0) ? model->frame_seq[model->n - 1] + 1.0f : 1.0f;
  float xstep = nice_step((xmax - xmin) / 8.0f);
  float ymax = (wait_stats.max <= 0.0f) ? 1.0f : wait_stats.max * 1.10f;
  float ystep = nice_step(ymax / 5.0f);

  ymax = ceilf(ymax / ystep) * ystep;
  page_message_centered("OPQ frame wait: measured vs deterministic queue recurrence", 720, 34);

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  name("OPQ frame sequence", "x");
  name("frame wait [8 ns cycles]", "y");
  labdig(0, "x");
  labdig(0, "y");
  ticks(2, "x");
  graf(xmin, xmax, 0.0f, xstep, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);

  color("blue");
  solid();
  linwid(6);
  curve(model->frame_seq, model->wait_cycles, model->n);

  color("black");
  dash();
  linwid(4);
  curve(model->frame_seq, model->model_wait_cycles, model->n);

  color("fore");
  solid();
  linwid(1);
  endgrf();
}

static void draw_queue_count_panel(queue_model_t *model) {
  const int axis_x = 430;
  const int axis_y = 3300;
  const int axis_w = 2200;
  const int axis_h = 820;
  float xmin = -1.0f;
  float xmax = (model->n > 0) ? model->frame_seq[model->n - 1] + 1.0f : 1.0f;
  float xstep = nice_step((xmax - xmin) / 8.0f);
  float ymax = 1.0f;
  float ystep;

  for (int i = 0; i < model->n; i++) {
    if (model->input_hits[i] > ymax) {
      ymax = model->input_hits[i];
    }
    if (model->output_hits[i] > ymax) {
      ymax = model->output_hits[i];
    }
    if (model->missing_hits[i] > ymax) {
      ymax = model->missing_hits[i];
    }
  }
  ymax = ceilf(ymax * 1.20f);
  ystep = nice_step(ymax / 5.0f);
  ymax = ceilf(ymax / ystep) * ystep;
  page_message_centered("OPQ frame hit counts: offered, delivered, missing", 2340, 34);

  axspos(axis_x, axis_y);
  axslen(axis_w, axis_h);
  name("OPQ frame sequence", "x");
  name("hits/frame", "y");
  labdig(0, "x");
  labdig(0, "y");
  ticks(2, "x");
  graf(xmin, xmax, 0.0f, xstep, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);

  color("black");
  solid();
  linwid(4);
  curve(model->frame_seq, model->input_hits, model->n);

  color("green");
  solid();
  linwid(6);
  curve(model->frame_seq, model->output_hits, model->n);

  color("red");
  dash();
  linwid(5);
  curve(model->frame_seq, model->missing_hits, model->n);

  color("fore");
  solid();
  linwid(1);
  endgrf();
}

static void render_queue_model_plot(const char *csv_path, const char *out_path) {
  queue_model_t model;
  stats_t ingress_iat_stats;
  stats_t service_iat_stats;
  stats_t wait_stats;
  float rho = 0.0f;
  char subtitle[240];

  if (!read_queue_model_csv(csv_path, &model)) {
    exit(1);
  }
  ingress_iat_stats = compute_array_stats(model.ingress_iat_cycles, model.n_ingress_iat);
  service_iat_stats = compute_array_stats(model.service_iat_cycles, model.n_service_iat);
  wait_stats = compute_array_stats(model.wait_cycles, model.n);
  if (ingress_iat_stats.mean > 0.0f) {
    rho = service_iat_stats.mean / ingress_iat_stats.mean;
  }

  start_page(out_path);
  page_message_centered("FEB/SWB OPQ queue model", 95, 46);
  snprintf(
      subtitle,
      sizeof(subtitle),
      "rho = mean service / mean ingress = %.3f / %.3f = %.3f; wait max %.1f cycles",
      service_iat_stats.mean,
      ingress_iat_stats.mean,
      rho,
      wait_stats.max);
  page_message_centered(subtitle, 152, 30);
  page_message_centered("wait: blue measured, black dashed model; counts: black input, green output, red dashed missing", 196, 26);

  draw_queue_wait_panel(&model);
  draw_queue_count_panel(&model);

  disfin();

  printf(
      "opq_queue_model frames=%d ingress_iat_mean=%.3f service_iat_mean=%.3f rho=%.3f wait_min=%.3f wait_max=%.3f cycles\n",
      model.n,
      ingress_iat_stats.mean,
      service_iat_stats.mean,
      rho,
      wait_stats.min,
      wait_stats.max);
}

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: %s lifetime|queue input_csv output_plot\n", argv[0]);
    return 2;
  }

  if (strcmp(argv[1], "lifetime") == 0) {
    render_lifetime_plot(argv[2], argv[3]);
  } else if (strcmp(argv[1], "queue") == 0) {
    render_queue_model_plot(argv[2], argv[3]);
  } else {
    fprintf(stderr, "unknown render mode: %s\n", argv[1]);
    return 2;
  }
  return 0;
}
