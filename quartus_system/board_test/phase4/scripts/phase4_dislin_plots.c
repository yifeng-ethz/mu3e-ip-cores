#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_POINTS 8192
#define MAX_RATE_POINTS 64

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

static void set_series_style(int idx) {
  static const char *colors[] = {"blue", "red", "green", "orange"};
  color(colors[idx % 4]);
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
  graf(0.0f, 128.0f, 0.0f, 16.0f, 0.0f, 160.0f, 0.0f, 20.0f);

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
  solid();
  linwid(1);
  color("fore");
  grid(1, 1);
  draw_legend_entry(86.0f, 145.0f, 8.0f, "HDL TLM cap", 0);
  draw_legend_entry(86.0f, 132.0f, 8.0f, "Board Phase 4", 1);
  height(42);
  title();
  height(18);
  color("fore");
  messag("Board points are live pre-TERMINATING samples; post-TERMINATING is used only as a flush/residue check.", 430, 1905);
  disfin();
}

int main(int argc, char **argv) {
  if (argc != 6) {
    fprintf(stderr,
            "Usage: %s <tlm_latency.csv> <rtl_latency.csv> <rate.csv> <latency_out> <rate_out>\n",
            argv[0]);
    return 1;
  }
  render_latency_plot(argv[1], argv[2], argv[4]);
  render_rate_plot(argv[3], argv[5]);
  return 0;
}
