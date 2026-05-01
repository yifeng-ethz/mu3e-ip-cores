#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

#include "dislin.h"

#define N_CHANNELS 256

typedef struct {
  int count;
  float channel[N_CHANNELS];
  float rate_khz[N_CHANNELS];
  double total_hz;
  double mean_hz;
  double min_hz;
  double max_hz;
  double cv_hz;
  int nonzero;
} rate_table_t;

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

static int parse_csv_count(const char *line, int *bin, double *count) {
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
  trim(tok2);
  if (!isdigit((unsigned char)tok0[0])) {
    return 0;
  }
  *bin = (int)strtol(tok0, &endptr, 0);
  if (endptr == tok0) {
    return 0;
  }
  *count = strtod(tok2, &endptr);
  if (endptr == tok2) {
    return 0;
  }
  return 1;
}

static int read_rate_csv(const char *path, rate_table_t *table) {
  FILE *fp;
  char line[512];
  int seen[N_CHANNELS] = {0};

  memset(table, 0, sizeof(*table));
  table->min_hz = 0.0;
  table->max_hz = 0.0;

  fp = fopen(path, "r");
  if (fp == NULL) {
    fprintf(stderr, "could not open %s\n", path);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) != NULL) {
    int bin = 0;
    double count = 0.0;
    if (!parse_csv_count(line, &bin, &count)) {
      continue;
    }
    if (bin < 0 || bin >= N_CHANNELS) {
      continue;
    }
    table->channel[bin] = (float)bin;
    table->rate_khz[bin] = (float)(count / 1000.0);
    seen[bin] = 1;
  }
  fclose(fp);

  table->count = N_CHANNELS;
  table->min_hz = table->rate_khz[0] * 1000.0;
  table->max_hz = table->rate_khz[0] * 1000.0;
  for (int i = 0; i < N_CHANNELS; i++) {
    double hz = table->rate_khz[i] * 1000.0;
    if (!seen[i]) {
      table->channel[i] = (float)i;
      hz = 0.0;
      table->rate_khz[i] = 0.0f;
    }
    table->total_hz += hz;
    if (hz > 0.0) {
      table->nonzero++;
    }
    if (i == 0 || hz < table->min_hz) {
      table->min_hz = hz;
    }
    if (i == 0 || hz > table->max_hz) {
      table->max_hz = hz;
    }
  }
  table->mean_hz = table->total_hz / (double)N_CHANNELS;
  if (table->mean_hz > 0.0) {
    double var = 0.0;
    for (int i = 0; i < N_CHANNELS; i++) {
      double hz = table->rate_khz[i] * 1000.0;
      double d = hz - table->mean_hz;
      var += d * d;
    }
    table->cv_hz = sqrt(var / (double)N_CHANNELS) / table->mean_hz;
  }
  return 1;
}

static float nice_step(float span, int target_ticks) {
  float raw;
  float base;
  float frac;
  if (span <= 0.0f) {
    return 1.0f;
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

static void draw_reference_lines(float ymin, float ymax) {
  float x_ref[2] = {0.0f, 255.0f};
  float y_target[2] = {100.0f, 100.0f};
  float y_low[2] = {99.0f, 99.0f};
  float y_high[2] = {101.0f, 101.0f};

  if (ymin <= 100.0f && ymax >= 100.0f) {
    setrgb(0.72f, 0.05f, 0.05f);
    solid();
    linwid(5);
    curve(x_ref, y_target, 2);
  }
  if (ymin <= 99.0f && ymax >= 101.0f) {
    setrgb(0.72f, 0.33f, 0.05f);
    dash();
    linwid(3);
    curve(x_ref, y_low, 2);
    curve(x_ref, y_high, 2);
  }
}

static void draw_asic_boundaries(float ymin, float ymax) {
  setrgb(0.45f, 0.45f, 0.45f);
  dot();
  linwid(2);
  for (int boundary = 32; boundary < 256; boundary += 32) {
    float x[2] = {(float)boundary - 0.5f, (float)boundary - 0.5f};
    float y[2] = {ymin, ymax};
    curve(x, y, 2);
  }
}

static void render_rate_plot(const rate_table_t *table,
                             const char *out_path,
                             int pulse_high,
                             const char *subtitle) {
  float ymin = 0.0f;
  float ymax = 120.0f;
  float ystep;
  float mean_khz = (float)(table->mean_hz / 1000.0);
  char title_buf[256];
  char stat_buf[512];
  char pulse_buf[64];

  if (table->max_hz > 0.0) {
    float min_khz = (float)(table->min_hz / 1000.0);
    float max_khz = (float)(table->max_hz / 1000.0);
    if (min_khz > 65.0f && max_khz < 130.0f) {
      ymin = floorf((min_khz - 5.0f) / 5.0f) * 5.0f;
      if (ymin < 0.0f) {
        ymin = 0.0f;
      }
      ymax = ceilf((max_khz + 5.0f) / 5.0f) * 5.0f;
      if (ymax < 110.0f) {
        ymax = 110.0f;
      }
    } else {
      ymin = 0.0f;
      ymax = ceilf((max_khz * 1.10f) / 20.0f) * 20.0f;
      if (ymax < 120.0f) {
        ymax = 120.0f;
      }
    }
  }
  ystep = nice_step(ymax - ymin, 6);

  snprintf(title_buf, sizeof(title_buf),
           "Phase-6 Real MuTRiG Rate Sweep: pulse_high=%d", pulse_high);
  snprintf(stat_buf, sizeof(stat_buf),
           "mean=%.1f kHz/ch, min=%.1f, max=%.1f, nonzero=%d/256, CV=%.4f",
           mean_khz, table->min_hz / 1000.0, table->max_hz / 1000.0,
           table->nonzero, table->cv_hz);
  snprintf(pulse_buf, sizeof(pulse_buf), "pulse_high=%d", pulse_high);

  start_page(out_path);
  titlin(title_buf, 2);
  titlin(subtitle, 4);
  name("global channel = ASIC * 32 + channel", "x");
  name("rate [kHz/channel]", "y");
  labdig(0, "x");
  labdig(1, "y");
  axspos(420, 1380);
  axslen(2050, 920);
  height(30);
  graf(0.0f, 255.0f, 0.0f, 32.0f, ymin, ymax, ymin, ystep);
  grid(1, 1);

  draw_asic_boundaries(ymin, ymax);
  draw_reference_lines(ymin, ymax);

  setrgb(0.02f, 0.28f, 0.72f);
  solid();
  linwid(5);
  curve((float *)table->channel, (float *)table->rate_khz, table->count);

  setrgb(0.02f, 0.28f, 0.72f);
  incmrk(1);
  marker(16);
  hsymbl(18);
  curve((float *)table->channel, (float *)table->rate_khz, table->count);
  incmrk(-1);

  color("fore");
  solid();
  linwid(1);
  height(34);
  messag(stat_buf, 420, 1605);
  messag("red=100 kHz target, dashed=+/-1%; dotted vertical lines mark ASIC boundaries",
         420, 1660);
  height(38);
  messag(pulse_buf, 2320, 520);
  title();
  disfin();
}

int main(int argc, char **argv) {
  rate_table_t table;
  int pulse_high;
  const char *subtitle =
      "1 s histogram_statistics rate preset; periodic injector interval=1250 cycles";

  if (argc < 4 || argc > 5) {
    fprintf(stderr, "usage: %s <input.csv> <output.png> <pulse_high> [subtitle]\n",
            argv[0]);
    return 2;
  }
  pulse_high = atoi(argv[3]);
  if (argc == 5) {
    subtitle = argv[4];
  }
  if (!read_rate_csv(argv[1], &table)) {
    return 1;
  }
  render_rate_plot(&table, argv[2], pulse_high, subtitle);
  printf("%d\t%.0f\t%.6f\t%d\t%.3f\t%.3f\t%.3f\t%.6f\t%s\n",
         pulse_high,
         table.total_hz,
         table.mean_hz,
         table.nonzero,
         table.min_hz,
         table.max_hz,
         table.max_hz - table.min_hz,
         table.cv_hz,
         argv[2]);
  return 0;
}
