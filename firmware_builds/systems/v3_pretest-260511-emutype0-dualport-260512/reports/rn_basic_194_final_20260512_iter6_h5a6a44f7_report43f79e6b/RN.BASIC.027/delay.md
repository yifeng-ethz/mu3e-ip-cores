# RN.BASIC.027 delay (2 hist plot + scoreboard)

## hist bin A
![hist_bin_a](plots/hist_bin_a.pdf)
bank-A sum: 23,472; expected: 11,719; delta: 100.29%

## hist bin B
![hist_bin_b](plots/hist_bin_b.pdf)
bank-B sum: 0; expected: 11,719; delta: -100.00%

combined bank sum: 23,472; rate total: 23,472; delta: 0

## scoreboard delay vs true ts
![scoreboard_delay](plots/scoreboard_delay.pdf)
delay_mean_ns: 0
delay_stddev_ns: 0
count: 23,472

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
