# Reusable UI

The shared widgets are exported through `package:koin/core/core.dart`. Feature
widgets retain their providers, financial rules, formatting, navigation and save
callbacks. Prefer the smallest matching component over a generic financial card.

## Components

| Component | Responsibility | Current consumers |
| --- | --- | --- |
| `KoinQuickAction` | Circular icon and caption; optional tooltip, disabled state and tonal appearance | Dashboard, savings details, debt details |
| `KoinActivityRow` | Flat activity layout, with title/amount stacking at narrow widths or large text | Transactions, savings activity, repayments |
| `KoinSheetSurface` | Shared rounded sheet surface and optional padding/shadows | Confirmations, scheduled payments, savings logs, repayments, budget editing, Settings pickers |
| `showRadioSelectionSheet<T>` | Scrollable typed choice list; optional checkmark presentation; dismissal returns null | Cashflow frequency, debt record type, savings frequency |
| `KoinCalculatorAmount` | Numpad-driven expression and optional evaluated result; scales long expressions to available width | Quick Entry, savings logs, repayments |
| `KoinSummaryContent` | Summary label/currency, caller-provided amount and optional footer | Analysis, Budgets, Savings, Credit/IOUs |
| `KoinVisibilityButton` | Accessible show/hide action; callers own the preference | Dashboard and portfolio/analysis/budget summaries |
| `KoinIconBadge` | Tinted circular or rounded-square entity icon | Activity rows, budget previews, active budgets, top categories, report choices |
| `KoinAccountAvatar` | Logo rendering with icon fallback | Compact account cards/previews, linked savings account, report choices |
| `KoinEntityNameField` | Prominent centered name input with feature-supplied validation and callbacks | Savings, debt, cashflow editors |
| `KoinNotesField` | Multiline optional notes input | Debt and cashflow editors |
| `KoinEntityFormBody` | Scrollable, width-constrained form and bottom action with safe area | Savings, debt, cashflow editors |
| `KoinProgressBar` | Rounded determinate track, clamping and reduced-motion animation | Budget preview, active budgets, savings overview |
| `KoinSelectableOption` | Accessible selection presentation in grid or chip form | Report account/category options, transaction account/category filters |
| `FormSectionTitle.field` | Persistent field-label typography | Savings, debt, cashflow editors |
| `Widget.koinEntrance` | Existing fade/scale entrance preset respecting motion preferences | Accounts, cashflow, debts, repayments, reports |
| `KoinPeriodNavigation` | Previous/next controls and optional return-to-current action | Budgets and Analysis |
| `KoinMetric` | Quiet label/value/detail stack | Savings-plan metrics and goal saving rates |
| `KoinPageHeader` | Back button and flexible title with supporting/trailing slots | Debt details, Upcoming, Reports |
| `KoinSearchField` | Borderless search input for a header or capsule | Categories and transaction history |
| `CoachAmountSlider`, `CoachStepper` | Feature-local simulation controls | Goal coach and stash coach |

Use `KoinAddButton` for the cashflow add action as well as portfolio lists.
Stash coach uses the existing `KoinChoiceControl` for its mode selection.

## Usage

```dart
KoinQuickAction(
  icon: Icons.add_rounded,
  label: 'Save',
  color: AppTheme.incomeContentColor(context),
  onPressed: openSavingsSheet,
);

final frequency = await showRadioSelectionSheet<PaymentFrequency>(
  context: context,
  title: 'Repeats',
  options: PaymentFrequency.values,
  selected: selectedFrequency,
  label: (value) => value.label,
);
```

## Boundaries

- Summary visibility and per-account privacy/inclusion remain separate states.
- Transaction, savings and repayment rows retain their existing edit/delete
  wrappers and domain-specific dates, amount signs and explanations.
- Sheet callers retain keyboard insets, safe areas and scrolling policies.
  Numpad sheets and informational sheets need different sizing behavior.
- Editable amount inputs continue to use `HeroAmountField`; calculator displays
  are read-only and driven by `NumPad`.
- Account, savings, debt, schedule and purchase cards remain domain components.
  Budget and category rows share icons/progress primitives rather than an
  overly configurable all-purpose financial row.

## Manual regression checklist

Repeat the high-priority checks in light/dark themes and on a narrow screen with
large text. Test long names/amounts and keyboard-open states where applicable.

1. **Dashboard:** total visibility, independent account privacy, bank logos,
   quick-action navigation and budget previews.
2. **Savings overview/details:** totals and privacy, progress, Save/Release/Edit/
   Delete, activity rows, swipe deletion, automatic-release explanations and
   saving-rate metrics.
3. **Savings/goal editor:** name validation, amount entry, scrolling, keyboard
   dismissal and save action.
4. **Savings plan editor:** frequency selection/checkmark, cancellation,
   recalculated estimates and Save plan.
5. **Credit/IOU overview/details:** totals/privacy, quick actions, repayment rows,
   swipe deletion and purchases.
6. **Debt/BNPL editor:** record-type selection, name/notes, installments,
   validation, saving and retained draft values.
7. **Amount/confirmation sheets:** Add/Release Savings, Log Payment, Increase
   Credit, scheduled payment/income confirmation and delete confirmations;
   check expressions, warnings, disabled/loading actions and dismissal.
8. **Analysis:** hidden/visible spending, conditional comparison, previous/next
   period, category rows and forecast access.
9. **Budgets/editor:** hidden totals, month navigation/reset, progress, amount
   entry and saving.
10. **Planned payments/recurring income:** add action, name, frequency, notes,
    optional dates and saving.
11. **Quick Entry:** long expressions, result, Next/Review, account selection,
    validation and successful saving.
12. **Reports:** account/category multi-selection and CSV/PDF exports.
13. **Transactions/filters:** search, account/category selection, retained filters,
    activity rows and editing.
14. **Savings coach:** mode selection, sliders, date/amount steppers, Reset and
    Use this amount.
15. **Settings:** currency, appearance and confirmation sheets.
16. **Upcoming/Categories/Accounts:** back navigation, category search, account
    logos/previews and entrance animations.

## Automated validation

`test/widgets/reusable_ui_test.dart` checks typed selection/dismissal, keyboard
activation, selected semantics, disabled actions, reduced-motion progress,
missing-logo fallback and narrow layouts in both themes at 1x/2x text scale.
The existing feature tests cover migrated financial flows and persistence.

Run Flutter tests with `FLUTTER_ROOT` pointing at the installed SDK. The existing
savings preview tests load Material icons from that path. To render the shared
component previews, run:

```powershell
$env:FLUTTER_ROOT = 'C:\flutter'
flutter test --dart-define=UI_PREVIEWS=true test/widgets/reusable_ui_test.dart
```

Previews are written to the ignored `build/reuse_previews/` directory.
