#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dislin.h"

#define N_BINS 256

typedef struct {
  float center[N_BINS];
  float zero[N_BINS];
  float percent[N_BINS];
  unsigned long long count[N_BINS];
  unsigned long long total;
  unsigned long long inband_0_2000;
  unsigned long long outband_lt0;
  unsigned long long outband_gt2000;
  int nonzero;
  int peak_bin;
  float peak_center;
  double peak_fraction;
  double inband_fraction;
  double outband_fraction;
} delay_table_t;

static void trim(char *s) {
  size_t len;
  while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') {
    memmove(s, s + 1, strlen(s));
  }
  len = strlen(s);
  while (len > 0 &&
         (s[len - 1] == ' ' || s[len - 1] == '\t' ||
          s[len - 1] == '\n' || s[len - 1] == '\r')) {
    s[--len] = '\0';
  }
}

static int parse_csv_row(const char *line, int *bin, double *center, unsigned long long *count) {
  char work[512];
  char *tok0;
  char *tok1;
  char *tok2;
  char *endptr = NULL;

  snprintf(work, sizeof(work), "%s", line);
  tok0 = strtok(work, ",");
  tok1 = strtok(NULL, ",");
  tok2 = strtok(NULL, ",");
  if (tok0 == NULL || tok1 == NULL || tok2 == NULL) {
    return 0;
  }
  trim(tok0);
  trim(tok1);
  trim(tok2);
  if (!isdigit((unsigned char)tok0[0])) {
    return 0;
  }
  *bin = (int)strtol(tok0, &endptr, 0);
  if (endptr == tok0) {
    return 0;
  }
  *center = strtod(tok1, &endptr);
  if (endptr == tok1) {
    return 0;
  }
  *count = strtoull(tok2, &endptr, 0);
  if (endptr == tok2) {
    return 0;
  }
  return 1;
}

static int read_delay_csv(const char *path, delay_table_t *table) {
  FILE *fp;
  char line[512];

  memset(table, 0, sizeof(*table));
  for (int i = 0; i < N_BINS; i++) {
    table->center[i] = -1000.0f + 16.0f * (float)i + 8.0f;
    table->zero[i] = 0.0f;
  }
  fp = fopen(path, "r");
  if (fp == NULL) {
    fprintf(stderr, "could not open %s\n", path);
    return 0;
  }
  while (fgets(line, sizeof(line), fp) != NULL) {
    int bin = 0;
    double center = 0.0;
    unsigned long long count = 0;
    if (!parse_csv_row(line, &bin, &center, &count)) {
      continue;
    }
    if (bin < 0 || bin >= N_BINS) {
      continue;
    }
    table->center[bin] = (float)center;
    table->count[bin] = count;
    table->total += count;
    if (center >= 0.0 && center <= 2000.0) {
      table->inband_0_2000 += count;
    } else if (center < 0.0) {
      table->outband_lt0 += count;
    } else {
      table->outband_gt2000 += count;
    }
    if (count > 0) {
      table->nonzero++;
    }
    if (count > table->count[table->peak_bin]) {
      table->peak_bin = bin;
    }
  }
  fclose(fp);

  table->peak_center = table->center[table->peak_bin];
  if (table->total > 0) {
    table->peak_fraction = (double)table->count[table->peak_bin] / (double)table->total;
    table->inband_fraction = (double)table->inband_0_2000 / (double)table->total;
    table->outband_fraction =
        (double)(table->outband_lt0 + table->outband_gt2000) / (double)table->total;
    for (int i = 0; i < N_BINS; i++) {
      table->percent[i] = (float)(100.0 * (double)table->count[i] / (double)table->total);
    }
  }
  return 1;
}

static float nice_step(float span, int target_ticks) {
  float raw;
  float base;
  float frac;
  if (span <= 0.0f) {
    return 10.0f;
  }
  raw = span / (float)target_ticks;
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

static void start_page(const char *out_path) {
  metafl("PNG");
  setfil(out_path);
  filmod("delete");
  winsiz(1900, 1180);
  page(2970, 1845);
  scrmod("reverse");
  disini();
  pagera();
  complx();
}

static void render_delay_plot(const delay_table_t *table,
                              const char *out_path,
                              const char *title_text,
                              const char *subtitle) {
  float ymin = 0.0f;
  float ymax = 100.0f;
  float ystep;
  char stat_buf[512];
  char window_buf[512];
  char peak_buf[256];
  float x_accept_left[2];
  float x_accept_right[2];
  float x_peak[2];
  float y_peak[2];

  for (int i = 0; i < N_BINS; i++) {
    if (table->percent[i] > ymax) {
      ymax = table->percent[i];
    }
  }
  ymax = ceilf((ymax * 1.12f) / 10.0f) * 10.0f;
  if (ymax < 10.0f) {
    ymax = 10.0f;
  }
  if (ymax > 100.0f) {
    ymax = 100.0f;
  }
  ystep = nice_step(ymax - ymin, 6);

  snprintf(stat_buf, sizeof(stat_buf),
           "total=%llu hits, nonzero=%d/256, peak bin=%d at %.1f cycles, peak fraction=%.3f%%",
           table->total,
           table->nonzero,
           table->peak_bin,
           table->peak_center,
           100.0 * table->peak_fraction);
  snprintf(window_buf, sizeof(window_buf),
           "rbCAM [0,2000]: in=%llu (%.6f%%), out=%llu (%.6f%%)",
           table->inband_0_2000,
           100.0 * table->inband_fraction,
           table->outband_lt0 + table->outband_gt2000,
           100.0 * table->outband_fraction);
  snprintf(peak_buf, sizeof(peak_buf),
           "black=peak %.1f cycles; green=rbCAM window edges 0 and 2000 cycles",
           table->peak_center);

  start_page(out_path);
  titlin(title_text, 2);
  titlin(subtitle, 4);
  name("signed MTS debug_ts latency bin center [cycles]", "x");
  name("hits / bin [% of captured interval]", "y");
  labdig(0, "x");
  labdig(1, "y");
  axspos(420, 1380);
  axslen(2050, 920);
  height(30);
  graf(-1000.0f, 3096.0f, -1000.0f, 512.0f, ymin, ymax, ymin, ystep);
  grid(1, 1);

  setrgb(0.05f, 0.36f, 0.70f);
  solid();
  barwth(0.90f);
  bartyp("VERT");
  bars((float *)table->center, (float *)table->zero, (float *)table->percent, N_BINS);

  x_accept_left[0] = 0.0f;
  x_accept_left[1] = 0.0f;
  x_accept_right[0] = 2000.0f;
  x_accept_right[1] = 2000.0f;
  y_peak[0] = ymin;
  y_peak[1] = ymax;
  setrgb(0.00f, 0.50f, 0.18f);
  solid();
  linwid(3);
  curve(x_accept_left, y_peak, 2);
  curve(x_accept_right, y_peak, 2);

  x_peak[0] = table->peak_center;
  x_peak[1] = table->peak_center;
  y_peak[0] = ymin;
  y_peak[1] = ymax;
  setrgb(0.05f, 0.05f, 0.05f);
  solid();
  linwid(5);
  curve(x_peak, y_peak, 2);

  color("fore");
  solid();
  linwid(1);
  height(28);
  messag(stat_buf, 420, 1605);
  messag(peak_buf, 420, 1660);
  messag(window_buf, 420, 1715);
  title();
  disfin();
}

int main(int argc, char **argv) {
  delay_table_t table;
  const char *subtitle = "header-sync injector; histogram_statistics delay preset";

  if (argc < 4 || argc > 5) {
    fprintf(stderr, "usage: %s <input.csv> <output.png> <title> [subtitle]\n", argv[0]);
    return 2;
  }
  if (argc == 5) {
    subtitle = argv[4];
  }
  if (!read_delay_csv(argv[1], &table)) {
    return 1;
  }
  render_delay_plot(&table, argv[2], argv[3], subtitle);
  printf("%llu\t%d\t%d\t%.3f\t%.9f\t%llu\t%llu\t%llu\t%.9f\t%.9f\t%.9f\t%s\n",
         table.total,
         table.nonzero,
         table.peak_bin,
         table.peak_center,
         table.peak_fraction,
         table.inband_0_2000,
         table.outband_lt0,
         table.outband_gt2000,
         table.inband_fraction,
         table.outband_fraction,
         table.outband_fraction,
         argv[2]);
  return 0;
}
