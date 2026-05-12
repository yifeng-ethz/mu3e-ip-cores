# RN.BASIC.069 delay (2 hist plot + scoreboard)

## hist bin A
![hist_bin_a](plots/hist_bin_a.pdf)
bank-A sum: 0; expected: 976.500; delta: -100.00%

## hist bin B
![hist_bin_b](plots/hist_bin_b.pdf)
bank-B sum: 1,952; expected: 976.500; delta: 99.90%

combined bank sum: 1,952; rate total: 1,952; delta: 0

## scoreboard delay vs true ts
![scoreboard_delay](plots/scoreboard_delay.pdf)
delay_mean_ns: 0
delay_stddev_ns: 0
count: 1,952

## delay range bound
| metric | value |
|---|---:|
| delay_min_cycles | 0 |
| delay_p05_cycles | 0 |
| delay_p50_cycles | 0 |
| delay_p95_cycles | 0 |
| delay_max_cycles | 0 |
| abs(max - min) | 0 |
| slice target bound | periodic/main-clock base 900 x pulses_per_frame 1 = 900 |
| bound PASS | ✅ |
