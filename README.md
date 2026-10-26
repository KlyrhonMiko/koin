<p align="center">
  <img src="https://raw.githubusercontent.com/KlyrhonMiko/koin/main/assets/logo.png" alt="Koin" width="96" height="96">
</p>

<h1 align="center">Koin</h1>

<p align="center">
  Personal finance, thoughtfully organized.<br>
  Track your money today. Plan for what comes next.
</p>

<p align="center">
  <a href="https://github.com/KlyrhonMiko/koin/releases/latest"><strong>Download for Android</strong></a>
  &nbsp; · &nbsp;
  <a href="#features">Features</a>
  &nbsp; · &nbsp;
  <a href="#development">Development</a>
</p>

---

Koin brings accounts, transactions, budgets, debts, and savings into one place. Built with Flutter, it stores financial records locally and uses your transaction history to suggest categories and project future cashflow.

## Features

| Feature | What you can do |
| :--- | :--- |
| **Everyday tracking** | Manage multiple accounts, record income and expenses, and transfer money with fixed or percentage fees. Search and filter your transaction history. |
| **Bank interest** | Set an annual rate, optional tax deduction, and daily, monthly, or yearly payouts per account. Automatically record interest income and catch up when reopened. [How it works](docs/daily-interest.md). |
| **Budgets & insights** | Set category budgets, follow spending trends, compare periods, and export reports as CSV or PDF. |
| **Cashflow planning** | Organize recurring income and payments, see upcoming commitments, and project balances over the next week, month, or year. |
| **Debts & credit** | Track money owed in either direction, itemized purchases, installment plans, and repayment history. |
| **Savings goals** | Build savings goals and stashes. Set contribution schedules and see projected balances and completion dates. |
| **Faster entry** | Get category suggestions from your history, use voice input, or open a standalone entry window from Android Quick Settings. |

Light and dark themes, adjustable accent colors, bank templates, and consistent numeric keypads make Koin easy to personalize and use day to day.

See the [v1.1.3 release notes](docs/release-notes-next.md) for what's new in this update.

## Get started

Download the APK from the [latest GitHub release](https://github.com/KlyrhonMiko/koin/releases/latest), open it on your Android device, and follow the installation prompts. Android may ask you to allow installation from your browser or file manager.

For quick entry, add **Koin · Add entry** from the Android Quick Settings tile editor. Use it to record a transaction or claim recurring income without opening the full app.

New installations offer optional currency and opening-balance setup, starting with **PHP · Philippine Peso**. Existing saved currency choices are retained. Tap **+** to record a transaction; setting an opening balance does not create income.

Transaction history loads 100 entries at a time with **Load more transactions**. Search and filters cover the complete history, and day totals include entries on later pages. Speech input follows your system language by default; choose another installed language in **Settings → Speech language**.

## Your data

Financial records and category learning stay on your device. Cashflow forecasts use your history and scheduled commitments; they are estimates that change as your records change. Read more about [how forecasting works](docs/forecasting.md).

Koin checks for changes every 10 seconds while open and when moving between foreground and background. It keeps up to **three verified local recovery copies**, with dates, storage use, and restore options in Settings.

- **Folder backups:** Android, Windows, and Linux can save copies to a selected local folder or USB drive while Koin is running.
- **Manual export:** Save a `.koin` backup with optional password protection. Protected files require that password to import; Koin cannot recover it. Compressed `.koin` and earlier `.db` backups remain supported. See [backup formats](docs/backup-formats.md).
- **Device-loss protection:** Keep an exported copy on another device. Local copies may be removed on uninstall, and backup files contain personal financial data.

Password protection applies to the manual export you select. Automatic local recovery and folder copies retain their existing unencrypted format.

## Development

Install Flutter 3.47 or later with Dart compatible with `^3.13.0` and the platform tooling for your target device. Dependencies are defined in [pubspec.yaml](pubspec.yaml).

```bash
git clone https://github.com/KlyrhonMiko/koin.git
cd koin
flutter pub get
flutter run
```

Use the same Flutter installation for the terminal, editor, and Android's
`android/local.properties` (`flutter.sdk`). On Windows, `Get-Command flutter`
shows which installation PowerShell uses. Switching between SDK versions can
leave incompatible compiled native-hook caches and produce an “Invalid kernel
binary format version” error. After intentionally switching SDKs, run
`flutter clean` and `flutter pub get` with the selected SDK before building.

After changing Windows PATH, fully restart your editor and coding-agent app as
well as their terminals; existing processes keep the old PATH. Check both
`Get-Command flutter,dart` and `flutter --version` before running checks. If a
process still selects an older installation, use the compatible SDK's absolute
path for every Flutter command in that session, including `pub get`, `analyze`,
and `test`. Do not lower the project's SDK requirements to match a stale PATH.

**Check the project**

To update dependencies within the existing version constraints, run
`flutter pub upgrade`, review the `pubspec.lock` changes, then run the checks
below. Use `flutter pub outdated` to compare installed, upgradable, resolvable,
and latest versions. A newer version that is not resolvable can require a newer
Flutter SDK or changes in an upstream package; keep the compatible version
rather than adding dependency overrides. Flutter pins some test and framework
dependencies, so their versions may change when switching SDK installations.

```bash
flutter analyze
flutter test
```

**Build an Android APK**

```bash
flutter build apk --release
```

<details>
<summary><strong>Architecture & technology</strong></summary>

Koin uses **Flutter and Dart**, **Riverpod** for state management, and **SQLite** for financial records. Charts use fl_chart; reports use pdf and csv.

| Location | Purpose |
| :--- | :--- |
| `lib/main.dart` | Main app and Android quick-entry entrypoints |
| `lib/core/` | Domain models, ledger, repositories, state, forecasting, categorization, and recovery |
| `lib/core/widgets/` | Shared cards, inputs, controls, and sheets |
| `lib/features/` | Screens and feature-specific flows |
| `assets/` | App icon and bank logos |
| `test/` | Domain, integration, architecture, and widget tests |
| `docs/` | Forecast details and release notes |

See the [domain glossary](GLOSSARY.md) for the concepts used throughout the codebase.

</details>
