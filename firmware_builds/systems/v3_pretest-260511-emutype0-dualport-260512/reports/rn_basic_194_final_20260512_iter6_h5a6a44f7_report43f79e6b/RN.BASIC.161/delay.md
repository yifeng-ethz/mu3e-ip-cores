# RN.BASIC.161 delay (2 hist plot + scoreboard)

## hist bin A
![hist_bin_a](plots/hist_bin_a.pdf)
bank-A sum: 1,280; expected: 1,280; delta: 0.00%

## hist bin B
![hist_bin_b](plots/hist_bin_b.pdf)
bank-B sum: 1,280; expected: 1,280; delta: 0.00%

combined bank sum: 2,560; rate total: 2,560; delta: 0

## scoreboard delay vs true ts
![scoreboard_delay](plots/scoreboard_delay.pdf)
delay_mean_ns: 0
delay_stddev_ns: 0
count: 2,560

## delay range bound
| metric | value |
|---|---:|
| delay_min_cycles | 0 |
| delay_p05_cycles | 0 |
| delay_p50_cycles | 0 |
| delay_p95_cycles | 0 |
| delay_max_cycles | 0 |
| abs(max - min) | 0 |
| slice target bound | periodic/main-clock base 900 x pulses_per_frame 10 = 9,000 |
| bound PASS | ✅ |
