#include "dislin.h"

#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FRAMES 512
#define CHANNELS 256

static int frame_seen[MAX_FRAMES];
static int hist[MAX_FRAMES][CHANNELS];

static int parse_int(const char *s, int *out) {
  char *end = NULL;
  long v;
  errno = 0;
  v = strtol(s, &end, 10);
  if (errno != 0 || end == s) {
    return 0;
  }
  while (end && *end) {
    if (!isspace((unsigned char)*end)) {
      return 0;
    }
    end++;
  }
  *out = (int)v;
  return 1;
}

static int read_csv(const char *path) {
  FILE *fp = fopen(path, "r");
  char line[256];
  int max_frame = -1;

  if (!fp) {
    fprintf(stderr, "could not open %s\n", path);
    return -1;
  }
  if (!fgets(line, sizeof(line), fp)) {
    fclose(fp);
    return -1;
  }
  while (fgets(line, sizeof(line), fp)) {
    char *tok0 = strtok(line, ",");
    char *tok1 = strtok(NULL, ",");
    char *tok2 = strtok(NULL, ",\n\r");
    int frame = 0;
    int channel = 0;
    int count = 0;
    if (!tok0 || !tok1 || !tok2) {
      continue;
    }
    if (!parse_int(tok0, &frame) || !parse_int(tok1, &channel) || !parse_int(tok2, &count)) {
      continue;
    }
    if (frame < 0 || frame >= MAX_FRAMES || channel < 0 || channel >= CHANNELS) {
      continue;
    }
    frame_seen[frame] = 1;
    hist[frame][channel] = count;
    if (frame > max_frame) {
      max_frame = frame;
    }
  }
  fclose(fp);
  return max_frame;
}

static float nice_step(float x) {
  float p;
  float f;
  if (x <= 1.0f) {
    return 1.0f;
  }
  p = powf(10.0f, floorf(log10f(x)));
  f = x / p;
  if (f <= 1.0f) return p;
  if (f <= 2.0f) return 2.0f * p;
  if (f <= 5.0f) return 5.0f * p;
  return 10.0f * p;
}

static void render_frame(const char *out_dir, int frame) {
  float x[CHANNELS];
  float y0[CHANNELS];
  float y[CHANNELS];
  int ymax_i = 1;
  float ymax;
  float ystep;
  char out_path[1024];
  char title_buf[160];

  for (int ch = 0; ch < CHANNELS; ch++) {
    x[ch] = (float)ch;
    y0[ch] = 0.0f;
    y[ch] = (float)hist[frame][ch];
    if (hist[frame][ch] > ymax_i) {
      ymax_i = hist[frame][ch];
    }
  }

  ymax = (float)ymax_i * 1.18f;
  ystep = nice_step(ymax / 4.0f);
  ymax = ceilf(ymax / ystep) * ystep;

  snprintf(out_path, sizeof(out_path), "%s/frame_%03d.png", out_dir, frame);
  snprintf(title_buf, sizeof(title_buf), "RDMA frame %03d: 256-channel hit histogram", frame);

  metafl("PNG");
  setfil(out_path);
  filmod("delete");
  winsiz(980, 420);
  page(2400, 1050);
  scrmod("reverse");
  disini();
  pagera();
  complx();
  titlin(title_buf, 1);
  axspos(260, 760);
  axslen(1880, 430);
  name("global channel", "x");
  name("hits", "y");
  labdig(0, "x");
  labdig(0, "y");
  ticks(4, "x");
  ticks(2, "y");
  graf(0.0f, 255.0f, 0.0f, 32.0f, 0.0f, ymax, 0.0f, ystep);
  grid(1, 1);
  color("fore");
  title();
  color("blue");
  shdpat(16L);
  barwth(0.85f);
  bars(x, y0, y, CHANNELS);
  color("fore");
  endgrf();
  disfin();
}

int main(int argc, char **argv) {
  int max_frame;
  if (argc != 3) {
    fprintf(stderr, "usage: %s <frame_channel_hist.csv> <output_dir>\n", argv[0]);
    return 2;
  }
  max_frame = read_csv(argv[1]);
  if (max_frame < 0) {
    fprintf(stderr, "no frame histogram rows in %s\n", argv[1]);
    return 1;
  }
  for (int frame = 0; frame <= max_frame; frame++) {
    if (frame_seen[frame]) {
      render_frame(argv[2], frame);
      printf("RDMA_CHANNEL_HIST_DISLIN frame=%d\n", frame);
    }
  }
  return 0;
}
