# Bank interest

In **Accounts**, create or edit a deposit account and turn on **Interest**.
Choose **Daily**, **Monthly**, or **Yearly** under **Interest paid**.
Enter the bank's annual interest rate (p.a.), then optionally enter the percentage
of interest withheld as tax. An empty tax field means zero; Koin does not assume
a tax rate for your bank. Credit accounts cannot earn deposit interest.

Tracking starts on the day you enable it. Each completed day uses:

`net interest = closing balance × annual rate / 100 / 365 × (1 − tax rate / 100)`

Daily payouts round the net amount to the currency's precision each day.
Monthly and yearly payouts accumulate unrounded daily interest and round the
combined amount once at payout. Monthly payouts occur at calendar month-end;
yearly payouts occur at calendar year-end. Partial first periods include only
days since tracking began. Unpaid interest does not increase the account balance.
Deposits, expenses, transfers, and fees affect that day's closing balance. Saved
money reserved in a savings goal still belongs to the account and earns interest.
Negative or zero balances earn no interest. Recorded interest increases the next
day's balance, so net interest compounds at your selected payout frequency.

Koin checks at launch, when you return to the app, and every minute while it is
running. It catches up on completed days since tracking began, including days the
app was closed. It uses your device's local calendar dates. No background service
or bank connection is required. Changes to rates apply from today; the editor
finishes outstanding days at the previous rate before saving the new rate.
Changing the payout frequency carries unpaid interest forward to the next payout
under the new schedule.

Entries appear in Transactions as **Daily interest**,
**Monthly interest**, or **Yearly interest** under the
**Interest** income category, and count toward account balances, income, and
reports. The account editor shows a compact estimate for a full day, calendar
month, or calendar year at your current balance, after tax. Expand
**How it works** for the tracking start date, calculation details, and total
interest recorded. Interest is calculated separately for each enabled account.

These entries are estimates: bank rounding, balance tiers, promotional conditions,
caps, and a different day-count basis can produce a different amount. Edit an
entry to match the bank's credited amount. Editing or deleting an entry does not
cause Koin to recreate it, and past entries are not recalculated when you edit old
transactions. Those corrections affect future unprocessed days.

Turning tracking off keeps past entries. Re-enabling starts from that day and
skips the period when tracking was disabled. Any unpaid interest from before
disabling is carried forward. Account privacy and excluded savings
affect displayed totals, not the balance used to calculate interest. Interest
settings, entries, and processing progress are included in local backups.
