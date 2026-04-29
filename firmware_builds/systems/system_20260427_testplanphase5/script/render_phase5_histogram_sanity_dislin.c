#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_POINTS 4096
#define MAX_SERIES 8

typedef struct {
  int n;
  int nseries;
  char label[MAX_SERIES][64];
  float x[MAX_POINTS];
  float y[MAX_SERIES][MAX_POINTS];
} table_t;

static void trim(char *s) {
  size_t len;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
    memmove(s, s + 1, strlen(s));
  }
  len = strlen(s);
  while (len > 0 &&
         (s[len - 1] == ' ' || s[len - 1] == '\t' || s[len - 1] == '\n' ||
          s[len - 1] == '\r')) {
    s[--len] = '\0';
  }
}

static int split_csv(char *line, char **tokens, int max_tokens) {
  int ntok = 0;
  char *tok = strtok(line, ",");
  while (tok != NULL && ntok < max_tokens) {
    trim(tok);
    tokens[ntok++] = tok;
    tok = strtok(NULL, ",");
  }
  return ntok;
}

static int parse_float_strict(const char *text, float *out) {
  char *endptr = NULL;
  float value;
  if (text == NULL || *text == '\0') {
    return 0;
  }
  value = strtof(text, &endptr);
  while (endptr != NULL && *endptr != '\0' && isspace((unsigned char)*endptr)) {
    endptr++;
  }
  if (endptr == NULL || *endptr != '\0') {
    return 0;
  }
  *out = value;
  return 1;
}

static void set_default_labels(table_t *table, const char *mode) {
  if (strcmp(mode, "rate") == 0) {
    table->nseries = 2;
    snprintf(table->label[0], sizeof(table->label[0]), "10 kHz");
    snprintf(table->label[1], sizeof(table->label[1]), "100 kHz");
  } else if (strcmp(mode, "header") == 0) {
    table->nseries = 3;
    snprintf(table->label[0], sizeof(table->label[0]), "1/header");
    snprintf(table->label[1], sizeof(table->label[1]), "2/header");
    snprintf(table->label[2], sizeof(table->label[2]), "5/header");
  } else {
    table->nseries = 8;
    for (int i = 0; i < table->nseries; i++) {
      snprintf(table->label[i], sizeof(table->label[i]), "lane %d", i);
    }
  }
}

static int parse_data_tokens(table_t *table, char **tokens, int ntok, int expected_series) {
  float x;
  if (ntok < expected_series + 1 || table->n >= MAX_POINTS) {
    return 0;
  }
  if (!parse_float_strict(tokens[0], &x)) {
    return 0;
  }
  table->x[table->n] = x;
  for (int i = 0; i < expected_series; i++) {
    float y;
    if (!parse_float_strict(tokens[i + 1], &y)) {
      y = 0.0f;
    }
    table->y[i][table->n] = y;
  }
  table->n++;
  return 1;
}

static int read_table_csv(const char *path, const char *mode, int expected_series, table_t *table) {
  FILE *fp = fopen(path, "r");
  char line[8192];
  int saw_header = 0;

  memset(table, 0, sizeof(*table));
  set_default_labels(table, mode);

  if (fp == NULL) {
    fprintf(stderr, "could not open CSV: %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    char work[8192];
    char *tokens[MAX_SERIES + 2] = {0};
    int ntok;
    float dummy;

    trim(line);
    if (line[0] == '\0' || line[0] == '#') {
      continue;
    }

    snprintf(work, sizeof(work), "%s", line);
    ntok = split_csv(work, tokens, MAX_SERIES + 2);
    if (ntok < expected_series + 1) {
      continue;
    }

    if (!saw_header && !parse_float_strict(tokens[0], &dummy)) {
      for (int i = 0; i < expected_series; i++) {
        snprintf(table->label[i], sizeof(table->label[i]), "%s", tokens[i + 1]);
      }
      table->nseries = expected_series;
      saw_header = 1;
      continue;
    }

    parse_data_tokens(table, tokens, ntok, expected_series);
    saw_header = 1;
  }

  fclose(fp);
  if (table->n == 0) {
    fprintf(stderr, "no data rows in CSV: %s\n", path);
    return 0;
  }
  table->nseries = expected_series;
  return 1;
}

static const char *output_format_from_path(const char *path) {
  const char *dot = strrchr(path, '.');
  if (dot != NULL && strcasecmp(dot, ".svg") == 0) {
    return "SVG";
  }
  if (dot != NULL && strcasecmp(dot, ".pdf") == 0) {
    return "PDF";
  }
  return "PNG";
}

static void start_page(const char *out_path) {
  const char *fmt = output_format_from_path(out_path);
  metafl(fmt);
  setfil(out_path);
  filmod("delete");
  if (strcasecmp(fmt, "PNG") == 0) {
    winsiz(1900, 1180);
  }
  page(2970, 1845);
  scrmod("reverse");
  disini();
  pagera();
  complx();
}

static void finish_page(void) {
  disfin();
}

static void set_series_style(int idx) {
  static const float colors[][3] = {
      {0.05f, 0.23f, 0.72f}, {0.82f, 0.12f, 0.08f}, {0.05f, 0.55f, 0.20f},
      {0.52f, 0.18f, 0.70f}, {0.92f, 0.48f, 0.00f}, {0.00f, 0.55f, 0.62f},
      {0.20f, 0.20f, 0.20f}, {0.62f, 0.05f, 0.30f}};
  setrgb(colors[idx % 8][0], colors[idx % 8][1], colors[idx % 8][2]);
  if (idx == 0) {
    solid();
  } else if (idx == 1) {
    dash();
  } else if (idx == 2) {
    dot();
  } else if (idx == 3) {
    dashl();
  } else {
    solid();
  }
  linwid(idx < 3 ? 6 : 4);
}

static float max_y(const table_t *table) {
  float ymax = 0.0f;
  for (int s = 0; s < table->nseries; s++) {
    for (int i = 0; i < table->n; i++) {
      if (table->y[s][i] > ymax) {
        ymax = table->y[s][i];
      }
    }
  }
  return ymax;
}

static float min_x(const table_t *table) {
  float xmin = table->x[0];
  for (int i = 1; i < table->n; i++) {
    if (table->x[i] < xmin) {
      xmin = table->x[i];
    }
  }
  return xmin;
}

static float max_x(const table_t *table) {
  float xmax = table->x[0];
  for (int i = 1; i < table->n; i++) {
    if (table->x[i] > xmax) {
      xmax = table->x[i];
    }
  }
  return xmax;
}

static float nice_step(float span, int target_ticks) {
  float raw;
  float base;
  float frac;
  if (span <= 0.0f) {
    return 1.0f;
  }
  raw = span / (float) target_ticks;
  base = powf(10.0f, floorf(log10f(raw)));
  frac = raw / base;
  if (frac <= 1.0f) {
    return base;
  }
  if (frac <= 2.0f) {
    return 2.0f * base;
  }
  if (frac <= 5.0f) {
    return 5.0f * base;
  }
  return 10.0f * base;
}

static void draw_dislin_legend(const table_t *table) {
  int x0 = 2360;
  int y0 = 600;
  int dy = table->nseries > 4 ? 43 : 58;
  int box_h = dy * (table->nseries + 1) + 60;
  int box_w = 410;

  color("fore");
  solid();
  linwid(3);
  angle(0);
  rectan(x0 - 45, y0 - 55, box_w, box_h);
  height(40);
  messag("Legend", x0 + 95, y0 - 18);

  height(32);
  for (int s = 0; s < table->nseries; s++) {
    int y = y0 + 38 + s * dy;
    set_series_style(s);
    line(x0, y, x0 + 130, y);
    color("fore");
    solid();
    linwid(1);
    messag(table->label[s], x0 + 155, y + 10);
  }
}

static void render_table(
    const table_t *table,
    const char *out_path,
    const char *title_text,
    const char *subtitle_text,
    const char *x_label,
    const char *y_label,
    float forced_xmin,
    float forced_xmax,
    float forced_xstep) {
  float xmin = isnan(forced_xmin) ? min_x(table) : forced_xmin;
  float xmax = isnan(forced_xmax) ? max_x(table) : forced_xmax;
  float ymax = max_y(table);
  float ytop = ymax > 0.0f ? ymax * 1.16f : 1.0f;
  float xstep = forced_xstep > 0.0f ? forced_xstep : nice_step(xmax - xmin, 8);
  float ystep = nice_step(ytop, 6);

  if (xmax <= xmin) {
    xmax = xmin + 1.0f;
  }
  if (ytop <= 0.0f) {
    ytop = 1.0f;
  }

  start_page(out_path);
  titlin(title_text, 2);
  titlin(subtitle_text, 4);
  name(x_label, "x");
  name(y_label, "y");
  labdig(0, "x");
  labdig(0, "y");
  axspos(420, 1400);
  axslen(1820, 900);
  height(30);
  graf(xmin, xmax, xmin, xstep, 0.0f, ytop, 0.0f, ystep);
  grid(1, 1);

  for (int s = 0; s < table->nseries; s++) {
    set_series_style(s);
    curve((float *) table->x, (float *) table->y[s], table->n);
  }

  draw_dislin_legend(table);
  color("fore");
  solid();
  linwid(1);
  title();
  finish_page();
}

int main(int argc, char **argv) {
  table_t table;
  if (argc != 4) {
    fprintf(stderr, "usage: %s <rate|header|delay> <input.csv> <output.png|svg|pdf>\n", argv[0]);
    return 2;
  }

  if (strcmp(argv[1], "rate") == 0) {
    if (!read_table_csv(argv[2], "rate", 2, &table)) {
      return 1;
    }
    render_table(
        &table,
        argv[3],
        "Phase-5 Rate Sanity: 256 Global Channels",
        "Histogram Statistics preset, 1 s accumulation; 10 kHz and 100 kHz periodic injection",
        "global channel = ASIC * 32 + channel",
        "counts per 1 s",
        0.0f,
        255.0f,
        32.0f);
    return 0;
  }

  if (strcmp(argv[1], "header") == 0) {
    if (!read_table_csv(argv[2], "header", 3, &table)) {
      return 1;
    }
    render_table(
        &table,
        argv[3],
        "Phase-5 Header-Mode Sanity",
        "One-second histogram windows, 1 / 2 / 5 injected hits per observed header",
        "delay bin center [cycles]",
        "bin count",
        NAN,
        NAN,
        0.0f);
    return 0;
  }

  if (strcmp(argv[1], "delay") == 0) {
    if (!read_table_csv(argv[2], "delay", 8, &table)) {
      return 1;
    }
    render_table(
        &table,
        argv[3],
        "Phase-5 Delay Sanity by MuTRiG Lane",
        "Eight isolated lane measurements; narrow delta peak shifts with injector delay",
        "delay bin center [cycles]",
        "bin count",
        NAN,
        NAN,
        0.0f);
    return 0;
  }

  fprintf(stderr, "unsupported mode: %s\n", argv[1]);
  return 2;
}
