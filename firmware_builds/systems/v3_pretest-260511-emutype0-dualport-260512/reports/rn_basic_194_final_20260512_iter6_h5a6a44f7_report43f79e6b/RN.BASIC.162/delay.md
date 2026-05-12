# RN.BASIC.162 delay (2 hist plot + scoreboard)

## hist bin A
![hist_bin_a](plots/hist_bin_a.pdf)
bank-A sum: 40; expected: 40; delta: 0.00%

## hist bin B
![hist_bin_b](plots/hist_bin_b.pdf)
bank-B sum: 40; expected: 40; delta: 0.00%

combined bank sum: 80; rate total: 80; delta: 0

## scoreboard delay vs true ts
![scoreboard_delay](plots/scoreboard_delay.pdf)
delay_mean_ns: 0
delay_stddev_ns: 0
count: 80

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
