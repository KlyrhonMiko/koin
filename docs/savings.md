# Savings

Savings are reservations within an account, not bank transfers or new income.
Multiple goals and savings pots may share one account. Their
combined reservations are subtracted when checking the available balance.

## Savings types

- Goals have a target amount and an optional deadline.
- Savings are open-ended pots with an optional target and no deadline. Users choose their own names.
- Older stashes and emergency funds load as Savings, retaining names, balances, activity, account links, visibility settings, and routines.

Goal completion excludes open-ended Savings. Each goal's contribution
to completion is capped at its own target, so overfunding one goal does not
complete another. Remaining amounts never become negative.

## Savings Helper

One helper replaces the separate routine editor and coach flow. Choose an amount,
frequency (weekly, every two weeks, or monthly), and first contribution date.
The editor shows only amount, frequency, one forecast, and a pinned Save plan action.
Schedule options reveal contribution dates and plan removal; a separate target-date
option reveals the required amount only on request. Progress bars stay on the
overview and details screens.
The estimate updates as inputs change; Save plan is the only action that persists
those choices. Plans can be edited or removed without changing balances or history.

Savings pots offer This month / This year projections. Goals show an estimated
completion date, progress projected by their deadline, and the contribution needed
to meet that date. Use amount for target date applies that suggestion to the editor
for review. Existing goal deadlines can be adjusted here; they persist with Save plan.

The overview keeps its summary and list, with a short projection on planned items.
The helper lives inside each savings/goal detail, as a compact setup or edit row
and a brief plan summary. Open it for full forecasts and month/year controls. The solid bar is recorded savings. The lighter
extension is projected contributions; an open-ended pot uses its selected projected
total as the scale, while a goal uses its target. Every bar labels Saved and Projected.

Projections count actual calendar occurrences through the selected date, including
an unpaid current contribution as being made today. Partial current contributions
reduce the next projected amount; fulfilled periods advance to the next occurrence.
Missed periods do not become catch-up debts. Monthly schedules preserve their original
day and clamp short months, including leap years. Goals stop projecting contributions
at their target. Projections use no interest or investment return assumptions and
never write deposits or change account reservations.

Set aside opens the existing contribution sheet with the amount remaining for that
period. The user confirms it, and the provider rechecks account availability before
writing. Ordinary Save remains available for additional contributions. Completed
targets stop prompting. Positive contributions count toward the current period;
releases reduce the saved balance without erasing fulfilled contribution periods.
Future entries and entries before the plan starts do not fulfill current periods.

SQLite version 38 adds emergency classification and routine fields. Existing
savings and activity are retained during migration, and backup validation
recognizes the new schema. Legacy emergency flags are accepted when reading older records and backups, then normalized to the unified Savings type.
