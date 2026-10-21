<!-- Release title: Koin v1.1.3 — Quick Entry, Forecasts & Savings Coach -->
<!-- Release notes cover changes since v1.1.2. -->

A new look for Koin, with faster transaction entry and more ways to plan your money. This update adds Android Quick Entry, cashflow forecasts, Savings Coach, and automatic backups.

## What's new

- **Quick Entry on Android** — Record an expense, income, or transfer from your Quick Settings panel. You can also claim recurring income in the same compact window.
- **Category suggestions** — Koin learns from your transaction history to suggest categories and accounts as you type. Learning happens on your device.
- **Cashflow forecasts** — See where your balance could be heading over the next week, month, or year, based on your activity, upcoming payments, debts, and savings plans.
- **Savings Coach** — Try different weekly contributions and deadlines to see how they affect your goal. For stashes, explore how much you could save by a date or when you could reach an amount.
- **Automatic recovery copies** — Koin keeps up to three local backups, with restore options in Settings. You can also export a `.koin` file or choose a backup folder on Android, Windows, and Linux.
- **More detailed debt tracking** — Add individual purchases and installment plans, increase existing debts, and see exactly how much remains when recording a repayment.

## Better day to day

- New app icon and launch screens, refreshed cards and forms, and improved dark-mode colors.
- An Upcoming screen that brings scheduled cashflow and debt installments together, plus flexible income schedules.
- Fixed or percentage transfer fees per account, with fees recorded as expenses.
- Account balances visible during entry, clearer budget progress, and smoother keypad and swipe interactions.

## Fixes & refinements

- Repayment edits enforce the remaining debt balance and preserve the payment direction.
- Percentage transfer fees round to the selected currency's precision and stay intact when edited.
- Automatic payments catch up using their due dates, including eligible occurrences before a schedule ended. Deleting an automatic entry skips it instead of recreating it.
- Failed automatic payments appear on Home with review and retry actions.
- Clearing or restoring records refreshes savings balances and cached activity histories.
- Future-dated entries stay out of actual spending totals until their date arrives.
- Clearing transaction filters also clears the visible search text. Busy transaction days render rows lazily, and account-balance validation uses indexed account queries.
- Reports show loading and retry states, disable export until data is ready, and adapt export actions to large text and narrow screens.
- Currency changes explain that existing amounts are relabeled without exchange-rate conversion.
- Unsaved account, category, transaction, debt, schedule, savings, and budget edits require the same discard confirmation before leaving. Editable sheets also protect changes when closed, swiped down, or dismissed by tapping outside.
- Settings includes an archive manager for accounts and categories. Archived items keep their history and balances, remain available to existing schedules, and are hidden from new entry choices.
- Color and icon choices expose accessible names and selected states. Transfer deletion confirmations explain that linked fees are removed too.
- Linked credit records now stay in sync when repayment transactions are edited.
- Repayments are limited to the remaining balance and remember your selected account.
- Improved database migrations, account ordering, and card customization.
- Decorative animations stop when idle.

---

**Try Quick Entry:** Edit your Android Quick Settings tiles and add **Koin · Add entry**.

**Keep a separate backup:** Local recovery copies stay on your device. Export a copy to another device to protect against device loss or uninstalling the app.
