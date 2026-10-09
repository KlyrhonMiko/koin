# Cashflow forecasts

Forecasts project the included account balance from today through the next seven
days, calendar month, or calendar year. The end date is exclusive. Future-dated
transactions do not contribute to today's starting balance.

Variable income and spending use at most twelve recent completed calendar months.
With fewer than six samples, the three-period exponential moving average remains
the baseline. With six or more, each direction compares the moving average,
historical mean, and last month's total using rolling monthly predictions. Each
prediction uses only preceding months, beginning with three training months;
the method with the lowest mean absolute error wins (ties keep the baseline).
This evaluates monthly totals, not weekly or yearly accuracy. Variable estimates
are scaled to the chosen horizon; they do not yet model seasonality. Months
without transactions contribute zero. The first recorded month is omitted if
tracking started after its first day. When no complete samples exist, at least
seven complete observed days are required before estimating a monthly run rate;
today's incomplete activity is excluded from that estimate. Linked planned
payments and debt repayments are excluded from both variable flow directions.

Planned payments use their next date and recurrence, stopping at their end date.
Expired schedules are ignored. Flexible payments contribute once at their known
next date. Outstanding occurrences on active schedules are treated as payable
within the forecast, including arrears; schedules must be processed or updated
when payments have already happened. Month-end dates clamp to the last valid day
without changing the original recurrence anchor.

Debts use their installment or lump-sum due dates and never project more than
the outstanding principal. An undated lump-sum debt contributes no scheduled
cashflow. Itemized debts follow each item's first payment date and installment
count; because repayments have no item allocation, they are applied to the oldest
installments first. An explicit debt due date describes the next installment.

Milestone savings contributions follow the remaining target and deadline, begin
no earlier than the goal's start date, and stop at the remaining target. Stashes,
completed goals, and expired goals contribute no new scheduled savings outflow.
These contributions represent money earmarked for goals in the projection.

Daily end-of-day balances place scheduled movements on their dates. Unpaid
arrears are assigned to the first projected day. Unknown variable income and
spending are spread evenly over the horizon, so unscheduled payday timing and
intraday payment order remain unknown. A warning includes the first date the
balance is projected below zero, even if the final balance recovers. A negative
starting balance also triggers a warning on the first day.

With at least nine aligned monthly samples (six held-out errors), the forecast
also shows a historical variation range. Signed monthly net errors are computed
by reselecting both methods using only history available at each cutoff. The
10th and 90th percentiles of those errors form a scenario range around the point
estimate, widened as necessary to include it. Errors scale linearly with the
horizon rather than assuming independent months. This is an empirical scenario
range, not a calibrated 80% prediction interval or a measured weekly/yearly
coverage guarantee. Scheduled commitments remain fixed in the range. Short
histories show a limited-history message instead; the cold-start run rate counts
as one monthly sample, not a fully observed month.

Forecasts wait for accounts, transactions, debts, savings, and schedules to load,
and refresh when those inputs change. Production historical samples use the same
loaded accounts, transactions, and reference date as the starting balance rather
than separately re-reading income and expense histories. Tests cover historical sampling, calendar
boundaries, repayment limits, savings limits, and provider loading and refresh.
Additional tests cover rolling model selection, exclusion of future observations,
temporary shortfalls, and range availability. These regression tests establish
calculation correctness; they do not establish a measured improvement on real
users' future transactions.

The analysis card shows the estimated balance and, when needed, a short prompt
to review payment timing. Income, outgoings, balance ranges, and assumptions are
available through Forecast details instead of adding several paragraphs to the
main card. The details sheet scrolls at larger text sizes.
