# Cashflow forecasts

Forecasts project the included account balance from today through the next seven
days, calendar month, or calendar year. The end date is exclusive. Future-dated
transactions do not contribute to today's starting balance.

Variable income and spending use the existing three-period exponential moving
average, applied to at most twelve recent completed calendar months. Months
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

Forecasts wait for accounts, transactions, debts, savings, and schedules to load,
and refresh when those inputs change. Tests cover historical sampling, calendar
boundaries, repayment limits, savings limits, and provider loading and refresh.
Those regression tests establish calculation correctness; they do not establish
a measured improvement on real users' future transactions.
