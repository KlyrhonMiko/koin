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

### Budget Overview
A centralized budget calculation module (`BudgetOverview`). Evaluates category fixed and percentage spending limits against aggregate income and category expense totals, determining overall progress, category remaining balances, and over-budget states.

