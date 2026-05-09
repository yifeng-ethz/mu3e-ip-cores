#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define MAX_ROWS 256
#define MAX_TOKENS 40
#define PAGE_WIDTH 2970
#define PAGE_HEIGHT 1835

typedef struct {
  int n;
  float x_khz[MAX_ROWS];
  float offered[MAX_ROWS];
  float model_delivered[MAX_ROWS];
  float model_dropped[MAX_ROWS];
  float measured_delivered[MAX_ROWS];
  float measured_dropped[MAX_ROWS];
} scan_t;

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

static float token_float(char **tokens, int ntok, int idx) {
  if (idx >= ntok || tokens[idx][0] == '\0') {
    return 0.0f;
  }
  return (float)atof(tokens[idx]);
}

static int read_scan_csv(const char *path, scan_t *scan, int measured) {
  FILE *fp = fopen(path, "r");
  char line[4096];
  int first = 1;

  if (fp == NULL) {
    fprintf(stderr, "could not open rate scan CSV: %s\n", path);
    return 0;
  }

  memset(scan, 0, sizeof(*scan));
  while (fgets(line, sizeof(line), fp) != NULL) {
    char *tokens[MAX_TOKENS] = {0};
    int ntok;
    int idx;
    float expected_hits;
    float seconds;

    if (first) {
      first = 0;
      continue;
    }
    if (scan->n >= MAX_ROWS) {
      break;
    }
    ntok = split_csv_preserve_empty(line, tokens, MAX_TOKENS);
    if (ntok <= 28) {
      continue;
    }

    idx = scan->n++;
    scan->x_khz[idx] = token_float(tokens, ntok, 1) / 1000.0f;
    seconds = token_float(tokens, ntok, 3) * 8.0e-9f;
    expected_hits = measured ? token_float(tokens, ntok, 7) : token_float(tokens, ntok, 22);
    scan->offered[idx] = (seconds > 0.0f) ? expected_hits / seconds / 1.0e6f : 0.0f;
    scan->model_delivered[idx] = token_float(tokens, ntok, 25);
    scan->model_dropped[idx] = token_float(tokens, ntok, 26);
    scan->measured_delivered[idx] = token_float(tokens, ntok, 18);
    scan->measured_dropped[idx] = token_float(tokens, ntok, 19);
  }

  fclose(fp);
  return 1;
}

static void page_message_centered(const char *text, int y, int h) {
  int width;
  height(h);
  width = nlmess(text);
  messag(text, (PAGE_WIDTH - width) / 2, y);
}

static void draw_vertical(float x, float ymax) {
  float xs[2] = {x, x};
  float ys[2] = {0.0f, ymax};
  color("green");
  dash();
  linwid(4);
  curve(xs, ys, 2);
  solid();
  linwid(1);
}

static void draw_line(const char *line_color,
                      const char *style,
                      const float *x,
                      const float *y,
                      int n,
                      int width) {
  color(line_color);
  if (strcmp(style, "dash") == 0) {
    dash();
  } else if (strcmp(style, "dot") == 0) {
    dot();
  } else {
    solid();
  }
  linwid(width);
  curve((float *)x, (float *)y, n);
  solid();
  linwid(1);
}

static void render_plot(const char *model_csv, const char *measured_csv, const char *out_path) {
  scan_t model;
  scan_t measured;
  float y_max = 280.0f;
  float x_min = 0.0f;
  float x_max = 1050.0f;
  float knee_khz;
  char subtitle[256];
  const char *fmt = output_format_from_path(out_path);

  if (!read_scan_csv(model_csv, &model, 0)) {
    exit(1);
  }
  if (!read_scan_csv(measured_csv, &measured, 1)) {
    measured.n = 0;
  }

  for (int i = 0; i < model.n; i++) {
    if (model.offered[i] > y_max) {
      y_max = ceilf(model.offered[i] / 20.0f) * 20.0f;
    }
  }
  knee_khz = 2047.0f / (256.0f * 2048.0f * 8.0e-9f) / 1000.0f;

  metafl(fmt);
  setfil(out_path);
  filmod("delete");
  if (strcasecmp(fmt, "PNG") == 0) {
    winsiz(1800, 1112);
  }
  page(PAGE_WIDTH, PAGE_HEIGHT);
  scrmod("reverse");
  disini();
  pagera();
  complx();

  page_message_centered("FEB/SWB OPQ Poisson iid throughput pre-scan and rate scan", 80, 44);
  snprintf(subtitle,
           sizeof(subtitle),
           "model: E[D]=sum_f E[min(Poisson(256*r*dt_f),2047)]/T; one active OPQ lane; knee %.0f kHz/ch",
           knee_khz);
  page_message_centered(subtitle, 138, 28);

  axspos(420, 1300);
  axslen(2180, 760);
  name("offered rate per channel [kHz/ch]", "x");
  name("aggregate hit rate [Mhit/s]", "y");
  labdig(0, "x");
  labdig(0, "y");
  ticks(2, "x");
  ticks(2, "y");
  graf(x_min, x_max, 0.0f, 200.0f, 0.0f, y_max, 0.0f, 50.0f);
  grid(1, 1);

  draw_line("gray", "dot", model.x_khz, model.offered, model.n, 3);
  draw_line("orange", "dash", model.x_khz, model.model_dropped, model.n, 5);
  if (measured.n > 0) {
    draw_line("green", "solid", measured.x_khz, measured.measured_delivered, measured.n, 7);
    draw_line("red", "solid", measured.x_khz, measured.measured_dropped, measured.n, 7);
  }
  draw_line("black", "dash", model.x_khz, model.model_delivered, model.n, 4);
  draw_vertical(knee_khz, y_max);
  color("fore");
  solid();
  linwid(1);
  endgrf();

  height(28);
  color("gray");
  messag("gray dotted: offered aggregate", 430, 1540);
  color("fore");
  messag("black dashed: model delivered cap", 430, 1592);
  color("orange");
  messag("orange dashed: model dropped", 430, 1644);
  color("green");
  messag("green: measured DMA delivered", 1580, 1540);
  color("red");
  messag("red: measured drop", 1580, 1592);
  color("green");
  messag("green dashed: full-frame knee", 1580, 1644);
  color("fore");

  disfin();

  printf("RATE_SCAN_DISLIN_PASS model_rows=%d measured_rows=%d plot=%s\n",
         model.n,
         measured.n,
         out_path);
}

int main(int argc, char **argv) {
  if (argc != 4) {
    fprintf(stderr, "usage: %s model_csv measured_csv output_plot\n", argv[0]);
    return 2;
  }
  render_plot(argv[1], argv[2], argv[3]);
  return 0;
}
