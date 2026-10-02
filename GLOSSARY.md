# Domain Glossary

This document establishes the ubiquitous language and domain concepts of the Koin codebase.

## Core Financial Entities

### Ledger
The recording authority for financial state mutations. Encapsulates balances, transactions, and cascade rules (e.g. voiding a transaction, reverting payment schedules, and adjusting debt balances). The UI and domain notifiers communicate with the Ledger through a narrow interface, hiding persistence details behind an adapter seam.

### Account
A distinct holding bucket for funds (e.g., Cash, Bank, Savings). Holds balance, configuration for transfer fees (fixed amount or percentage), position/ordering, and exclusion from total net worth.

### Transaction
A point-in-time value exchange (`AppTransaction`). Has a direction/type (`expense`, `income`, `transfer`), primary account (`accountId`), optional destination account (`toAccountId`), category (`categoryId`), and optional linkages to a `PlannedPayment` or `DebtRepayment`.

### Cashflow Schedule
A recurring planned cash movement (`PlannedPayment`), either an anticipated outflow (bill/planned payment) or inflow (recurring income). Governed by a recurrence frequency (`daily`, `weekly`, `biWeekly`, `monthly`, `quarterly`, `yearly`, `flexible`), an auto-process flag, and forward date computation. Replaces fragmented implementations with a unified deep Cashflow Schedule module.

### Debt
A bilateral credit relationship between the user and an external counterparty (`owedToMe` vs `iOwe`). Encapsulates:
- Current principal / remaining balance
- Amortization and installment progress
- Itemized sub-plans (`DebtItem`)
- Historical repayments (`DebtRepayment`)

### Debt Item
A specific sub-purchase or itemized obligation associated with a parent Debt, tracking its own principal, installment count, and starting payment date.

### Category Suggester
A predictive classification module that consumes narrative input context (raw description text, monetary value, current account) and yields recommended category and account destinations via a local hybrid frequency dictionary and pattern matching. Behind a clean seam, it supports live SQLite dictionary adapters and mock/in-memory test adapters.

### Savings Goal & Stash
A savings accumulation target tracking progress toward a financial milestone, optionally linked to an underlying holding account.

### Cashflow Forecaster
A predictive projection engine that combines historical variable cashflow (using exponential moving average - EMA), fixed recurring cashflow schedules (`PlannedPayment`), debt amortization schedules, and savings target timelines to project net cashflow balances across weekly, monthly, and yearly horizons.

### Spending Analysis
A time-series spending aggregation and comparative analysis engine (`SpendingAnalysis`, `AnalysisPeriod`). Encapsulates inclusive date boundaries for weekly, monthly, and yearly horizons, prior-period baseline comparisons, trend deltas, and ranked category spending breakdowns.

### Transfer Draft
A domain value model (`TransferDraft`) that encapsulates transfer fee evaluation (fixed or percentage fee rules based on source account configuration), transfer validation (balance checks, distinct counterparty accounts, fee limits), and atomic assembly of the primary transfer transaction and linked expense fee transaction.

### Domain Repositories
Decoupled persistence seams (`AccountRepository`, `CategoryRepository`, `DebtRepository`, `PlannedPaymentRepository`, `SavingsRepository`, `ForecastRepository`) that isolate domain state notifiers from raw SQL database access. Each repository provides dual concrete adapters: a production `Sqlite...Adapter` and a deterministic `InMemory...Adapter` for headless domain testing.

### App Maintenance
The lifecycle and maintenance authority (`AppMaintenanceService`) encapsulating database checkpointing, encrypted/plain file backup generation, database file restoration with SharedPreferences reconciliation, transaction purging, complete database purging, and factory reset cascades behind a unified high-leverage interface.

### Debt Summary
An immutable domain value object (`DebtSummary`) that encapsulates portfolio-wide debt aggregation. Determines net debt balance (owed to user minus owed by user), total repaid capital, active loan counts, settled obligations, and overdue statuses without leaking calculation logic into presentation widgets.

### Upcoming Timeline & Entry
A unified, strongly-typed domain timeline (`UpcomingTimeline`, `UpcomingEntry`) consolidating recurring cashflow schedules (`PlannedPayment`) and debt installment obligations into an ordered forward commitment schedule. Computes due horizons, overdue status, and total due capital across heterogeneous financial sources without dynamic typecasting.

### Savings Summary
An immutable domain value model (`SavingsSummary`) computing aggregate savings portfolio metrics (total saved, total target milestones, overall progress percentage, active goals, and stashes) behind a clean domain interface.

### Budget Overview & Layout Packing
A reactive domain calculation and presentation layout module (`BudgetOverview`, `UnbudgetedChipItem`, `monthlyBudgetOverviewProvider`). Consolidates category-level spending limits, dynamic income percentage resolutions, and progress metrics while encapsulating greedy row bin-packing for unbudgeted category management without leaking untyped collections or algorithms into UI build trees.

### Transaction Group & Filter
Domain modules (`TransactionGroup`, `TransactionFilter`) encapsulating transaction collection boundaries, chronological day grouping, net daily balance aggregation (signed positive income and negative expense), composite criteria filtering (by query, transaction type, date range, categories, accounts, and monetary limits), active filter counter, and summary text generation. Eliminates scattered collection manipulation and grouping loops across transaction lists and dashboard screens.

