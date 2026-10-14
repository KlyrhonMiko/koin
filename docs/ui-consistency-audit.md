# UI consistency audit — 14 October 2026

## Implementation status — 14 October 2026

The 15 findings below have been addressed. Their source locations describe the pre-fix snapshot.

- Added shared entity-name, amount-input and summary styles; unified chart/badge sizes and startup Outfit typography.
- Added semantic foreground colors, contrast-aware action foregrounds and opaque action gradients. Restored the original bright summary-card gradients following user feedback; automatic card darkening was removed. Bright selected accents remain available for solid controls.
- Standardized fields to 16, sheets to 28 and summary cards to 28 through shared shape tokens; Reports now uses the common choice control.
- Unified back arrows and rounded delete icons.
- PDF exports use embedded Outfit, readable print colors and high-resolution glyph images rendered from Flutter's bundled Material Icons. Direct embedding of that CFF font is unsupported by the PDF library, so glyph images preserve the actual icon shapes.
- Validation: the complete suite passed 406 tests; palette tests exercise actual action labels/icons across every accent in both themes. Phone, narrow/large-text layouts and a sample PDF were rendered for visual inspection. Flutter analysis reported no issues.

The original source audit follows for traceability.

Source-based review of typography, colors, component shapes, and icons across Koin. No app implementation was changed during the original audit. This is not a claim that every route and state was exercised on a device. Values below describe the pre-fix source; contrast figures are calculated from its opaque palette colors, not sampled from screenshots.

Coverage: Dashboard and Upcoming; Activity, Analysis and transaction history; Budgets and its editor; Portfolio, Accounts, Savings, Credit/IOUs, planned payments and recurring income; their creation/edit/detail flows; savings coach, plans and projections; transaction entry, Quick Entry, voice input and filters; categories; reports/export; Settings and backup/recovery; startup; shared cards, inputs, selectors, sheets, empty/error states and navigation. The inventory found 76 Dart files with widget/rendering signatures across features and shared widgets, including the PDF rendering service. Supporting theme, typography, icon mapping, assets and existing UI tests were also inspected.

Baseline: `DESIGN.md`, `lib/core/theme.dart`, `lib/core/typography.dart`, and shared components. Outfit is bundled at weights 400–900. Shared heading weight is 700; section titles are 18, screen titles 24, form titles 28, summary amounts 38 and amount inputs 48. Intentional shape differences are part of the design: circular quick actions, rounded portfolio cards, patterned summary cards and flat activity rows.

15 findings: 1 P1, 7 P2, 7 P3. Priorities refer to this consistency review: P1 = significant readability problem; P2 = visible or semantic inconsistency; P3 = polish or branding consistency. No P0 blocker was identified in this scope.

## Colors

### C1 · P1 · Primary foreground overrides bypass the theme

- `lib/core/theme.dart:124` chooses a black foreground for bright accents in dark mode, and its standard elevated buttons inherit this at line 330.
- `lib/core/widgets/primitives/koin_primary_button.dart:112` and `:121` explicitly force white icons and labels.
- `lib/features/main_layout.dart:225` forces white on the primary FAB.
- `lib/features/debts/widgets/add_repayment_sheet.dart:410` forces white on its confirmation button.
- `lib/features/reports/custom_reports_screen.dart:350` forces white selected text over the chosen primary color.
- Quick Entry instead computes a contrast-aware foreground for both appearances at `lib/features/transactions/quick_entry_app.dart:93`.

Impact: the same selected accent produces different foregrounds across controls. White over opaque default teal `#00D09E` is approximately 2.00:1; white over yellow `#EAB308` is approximately 1.92:1. Gradients, patterns and transparency can change local contrast further. The base light theme also always chooses white, so simply replacing overrides with its current `onPrimary` would not solve every light-theme case.

Recommendation: calculate primary foregrounds consistently for both appearances. For solid primary fills, consume `onPrimary`; for gradient heroes, preserve the documented white-text design by choosing a sufficiently dark hero fill. Do not blindly change all hero text to black, since `DESIGN.md` explicitly requires white text there.

### C2 · P2 · Money foregrounds have different light-mode treatments

- Quick Entry uses light-mode income `#007A5D`, expense `#B42332`, and transfer `#1D4ED8`: `lib/features/transactions/quick_entry_app.dart:1042`.
- Main transaction entry uses the brighter base semantic colors: `lib/features/transactions/add_transaction_screen.dart:598`.
- Shared transaction amounts use income `#00D09E` and expense `#FF6B6B`: `lib/core/widgets/cards/transaction_tile.dart:97` and `:210`.
- Savings activity already uses `incomeContentColor`: `lib/features/savings/savings_details_screen.dart:770`.

Impact: income and expense amounts change shade between flows. Opaque income teal and expense coral on white produce approximately 2.00:1 and 2.78:1 respectively; the darker income foreground produces 5.33:1. Small amount text is particularly affected.

Recommendation: centralize separate content and fill colors for income, expense and transfer. Use content colors for text/icons on neutral surfaces; preserve bright colors for decorative fills where appropriate. Move Quick Entry's local expense/transfer foreground values into those tokens.

### C3 · P2 · Destructive and overdue states use unrelated reds

- Theme expense/error: `#FF6B6B`, `lib/core/theme.dart:59` and `:144`.
- Account editor delete: `Colors.red`, `lib/features/accounts/account_form_screen.dart:681`.
- Settings destructive icons and labels: `Colors.red`, `lib/core/widgets/cards/koin_grouped_card.dart:113` and `:163`.
- Over-budget percentage and progress: `Colors.red`, `lib/features/budgets/budgets_screen.dart:790`, `:799`, `:837`.
- Overdue debt date: `Colors.redAccent`, `lib/features/debts/debts_tab.dart:442`.

Impact: warning, destructive and expense colors vary by implementation rather than a documented semantic rule.

Recommendation: define error/destructive content, fill and on-fill roles with light/dark variants. If overdue warnings should intentionally differ from deletion, document that distinction and use one warning token everywhere.

## Typography

### T1 · P2 · Startup failure text does not use Outfit

`lib/core/widgets/app_startup.dart:50` creates an independent `ThemeData` without the app's font family or text scale. Its failure message and retry action therefore use platform/default typography, while the initialized app uses Outfit.

Impact: a user-visible recovery state looks like a different app. Independence from database initialization is sensible, but Outfit is already bundled and does not require a download.

Recommendation: give the lightweight startup theme the bundled font and appropriate shared text styles without introducing provider/database dependencies.

### T2 · P2 · Amount inputs vary in weight and tracking

- `HeroAmountField` uses 48 / weight 700 / tracking −2: `lib/core/widgets/inputs/hero_amount_field.dart:45`.
- Savings log uses 48 / weight 800 / tracking −2: `lib/features/savings/widgets/savings_log_sheet.dart:251`.
- Repayment uses 48 / weight 800 / tracking −2: `lib/features/debts/widgets/add_repayment_sheet.dart:208`.
- Purchase entry uses 48 / weight 800 / tracking 0: `lib/features/debts/widgets/add_purchase_sheet.dart:120`.
- Quick Entry also uses weight 800: `lib/features/transactions/quick_entry_app.dart:1082`.

Impact: equivalent amount-entry controls differ in density and emphasis, most noticeably in purchase entry's untracked amount.

Recommendation: define one amount-input style with the intended weight, tracking and line height, then apply it to both keyboard and numpad implementations. Retain differences only where a distinct role is documented.

### T3 · P3 · Entity-name fields use different tracking

Savings/goal name uses 28 / weight 800 / tracking −0.5 at `lib/features/savings/add_savings_goal_screen.dart:221`. Debt name uses 28 / weight 800 / tracking 0 at `lib/features/debts/add_edit_debt_screen.dart:261`; scheduled cashflow uses the latter at `lib/features/cashflow/add_edit_cashflow_screen.dart:339`. Purchase name also uses tracking 0 at `lib/features/debts/widgets/add_purchase_sheet.dart:114`.

Impact: the same form-heading role has a subtly different texture across editors.

Recommendation: share an entity-name style. These fields all use weight 800 already; the confirmed discrepancy here is tracking, not font family.

### T4 · P3 · Summary typography drifts despite a common card

- Shared portfolio summary label: 13 / weight 500 / tracking 0.5, `lib/core/widgets/cards/portfolio_card_style.dart:37`.
- Dashboard uses that same label pattern, `lib/features/dashboard/dashboard_screen.dart:220`.
- Savings details label uses 15 with inherited weight/tracking, `lib/features/savings/savings_details_screen.dart:411`.
- Shared summary amount tracking is −1, `lib/core/widgets/cards/portfolio_card_style.dart:49`; savings details sets −1.5, `lib/features/savings/savings_details_screen.dart:425`.

Impact: the summary card is visually shared but its label and number styling are not.

Recommendation: use shared summary label/amount styles, with explicit variants only when justified by hierarchy.

### T5 · P3 · Charts and metadata introduce sizes below the shared scale

The type scale's smallest role is 11 at `lib/core/typography.dart:21`. Trend axis labels use 10 at `lib/core/widgets/cards/spending_trend_chart.dart:250` and `:297`; analysis breakdown amounts use 10 at `lib/features/analysis/analysis_screen.dart:759`; recurrence badges use 9 at `lib/features/dashboard/widgets/upcoming_entry_tile.dart:132`, `lib/features/cashflow/cashflow_tab.dart:267`, and `lib/features/transactions/transactions_list_screen.dart:373`.

Impact: small financial metadata is harder to scan and introduces undocumented text roles. Raw numbers matching an existing token are not automatically visual bugs; these particular sizes fall below the defined scale.

Recommendation: adopt a shared chart/badge text role, preferably at least the existing overline size, and accommodate it in the layout. Verify readability with real fonts and larger text settings.

## Shapes

### S1 · P2 · Bottom sheets use three corner radii

| Sheet | Top radius | Location |
|---|---:|---|
| Select | 24 | `lib/core/widgets/sheets/select_sheet.dart:237` |
| Savings plan | 24 | `lib/features/savings/widgets/savings_plan_editor.dart:68` |
| Add/edit purchase | 24 | `lib/features/debts/widgets/add_purchase_sheet.dart:138` |
| Budget editor | 28 | `lib/features/budgets/widgets/budget_editor_sheet.dart:139` |
| Voice input | 28 | `lib/features/transactions/widgets/voice_input_sheet.dart:315` |
| Confirmation | 32 | `lib/core/widgets/sheets/confirmation_sheet.dart:67` |
| Savings log | 32 | `lib/features/savings/widgets/savings_log_sheet.dart:190` |
| Repayment | 32 | `lib/features/debts/widgets/add_repayment_sheet.dart:143` |
| Transaction filters | 32 | `lib/features/transactions/widgets/filter_bottom_sheet.dart:116` |

Impact: similar modal surfaces change silhouette between workflows. Purchase and repayment are especially comparable editing flows.

Recommendation: define one modal radius, or documented compact/full-height variants. Share the outer sheet shell so individual flows cannot drift accidentally.

### S2 · P3 · Summary card defaults differ from the dominant implementation

`lib/core/widgets/cards/koin_summary_card.dart:32` defaults to 32. Dashboard (`dashboard_screen.dart:209`), Budgets (`budgets_screen.dart:490`), Savings details (`savings_details_screen.dart:401`) and Debt details (`debt_details_screen.dart:193`) override it to 28. Savings overview (`savings_list_screen.dart:134`), Credit overview (`debts_tab.dart:152`) and Analysis (`analysis_screen.dart:199`) retain 32.

Impact: the same summary component has different corners on overview/detail screens. The written savings-detail design explicitly requires 28, which its implementation correctly follows.

Recommendation: make the common summary radius a token/default of 28, unless 32 is an intentional overview variant; document the variant if retained.

### S3 · P2 · Reports use a different segmented-selection language

`lib/core/widgets/primitives/koin_segmented_control.dart:148` defines joined 16-radius segments with separators, neutral text and a tinted selected background. Activity, Categories and form choices use this family. Reports recreates its type selector with a 20-radius outer container, separated 16-radius options, solid accent selection and white text at `lib/features/reports/custom_reports_screen.dart:292` and `:328`.

Impact: the same mutually exclusive selection task changes shape, color and emphasis on one screen.

Recommendation: use `KoinChoiceControl` for the report type selector. Analysis's translucent Wk/Mo/Yr control is inside a colored hero and can remain a documented inverse variant; its different context is not by itself a defect.

### S4 · P2 · Transaction fields diverge from the form-field shape

The base theme's input borders use 16 (`lib/core/theme.dart:358` onward), matching `SelectionTile` at `lib/core/widgets/inputs/selection_tile.dart:131`. Transaction note, fee and related form containers use 18 at `lib/features/transactions/add_transaction_screen.dart:1318`, `:1396`, and `:1495`.

Impact: adjacent input and selection surfaces in the transaction editor have slightly different corner treatments, and the editor differs from other forms.

Recommendation: use a shared field radius for text inputs, selectors and their enclosing containers. Keep a separate larger radius for actual cards.

## Icons

### I1 · P3 · Back navigation mixes chevrons and arrows

`KoinBackButton` explicitly uses `arrow_back_ios_new_rounded`, size 20, at `lib/core/widgets/primitives/koin_back_button.dart:27`. Quick Entry explicitly uses `arrow_back_rounded` at `lib/features/transactions/quick_entry_app.dart:764`. The Accounts standalone screen and savings coach use automatic AppBar back buttons at `lib/features/accounts/accounts_screen.dart:13`, `lib/features/savings/coach/coach_screen.dart:138` and `lib/features/savings/coach/stash_coach_view.dart:69`.

Impact: the same navigation action alternates between an iOS-style chevron and an Android-style arrow, with different sizing/padding.

Recommendation: choose a platform-appropriate back treatment and use it consistently, including automatically generated AppBar leading controls. Confirm whether the standalone Accounts route is actually exposed before prioritizing that instance.

### I2 · P3 · Account editor delete icon is an unrounded outlier

`lib/features/accounts/account_form_screen.dart:681` uses `Icons.delete_outline`, while cashflow editor (`add_edit_cashflow_screen.dart:453`) and savings/debt detail actions (`savings_details_screen.dart:369`, `debt_details_screen.dart:344`) use `delete_outline_rounded`.

Impact: the same delete action has subtly different geometry across editors.

Recommendation: standardize functional action icons through a small mapping. Keep selectable category/account icons and brand logos separate; their variety is user data, not an automatic consistency defect. The bottom navigation's outlined/filled active-state pair is also intentional.

## Export surface

### E1 · P3 · PDF output does not carry the app's typography and icon assets

`lib/features/reports/report_service.dart:191` constructs `pw.Document()` without loading Outfit or supplying a document theme. It also attempts to load `MaterialIcons-Regular.ttf` at line 184, but `pubspec.yaml` does not declare that asset. Existing widget preview tests load Flutter's icon asset as `fonts/MaterialIcons-Regular.otf` (`test/widgets/consistency_ui_regression_test.dart:61`). The report catches a failed font load and conditionally omits icons at `report_service.dart:549`.

Impact: exported reports use default PDF typography and are expected to omit category/account icons when the requested asset is unavailable. This is a source-level conclusion; a fresh export was not generated in this audit. The PDF also fixes primary teal at line 201 rather than using the chosen app accent; a fixed print palette may be intentional.

Recommendation: explicitly bundle/load export fonts and icon assets, set the PDF theme, and decide whether reports use fixed brand teal or the selected accent. Verify a rendered export after changes. Print-specific type sizes and corner radii need not match mobile UI dimensions.

## What is already consistent

- Main app UI uses Outfit throughout; no active Google Fonts or Font Awesome UI usage was found despite those dependencies being present.
- Shared typography roles are used broadly across the application.
- Portfolio Accounts/Savings/Credit cards and add actions already share `PortfolioCardStyle` and `KoinAddButton`.
- Dashboard, Savings and Debt details largely agree on 28-radius summary cards and circular quick actions.
- Activity, Categories and many form choices share the joined segmented control.
- Light/dark neutral surfaces are centralized. The quieter dark editor appearance is explicitly designed, not an accidental palette mismatch.
- Existing dark-theme tests verify theme foreground contrast, but explicit child overrides can bypass those assurances.

## Suggested correction order

1. Fix C1 and C2: unify foreground/content roles and check actual buttons and money text across light/dark appearances and bright accents.
2. Fix C3: consolidate destructive/warning semantics.
3. Fix T1/T2 and S1/S3/S4: share startup font, amount styles, sheet shell, report choice control and field radius.
4. Finish T3–T5, S2, I1/I2 and export branding after the shared foundations are settled.
5. Visually verify representative main screens, editors, sheets and export output with real fonts, then complete an Impeccable polish pass. Keep checks bounded; do not change intentional component hierarchy to make every shape identical.

Suggested skill passes: `/impeccable colorize` for semantic foregrounds, `/impeccable typeset` for the typography roles, `/impeccable shape` for the shared shape/control rules, then `/impeccable polish`. These are proposed follow-up changes, not work performed by this audit.

Tooling note: the skill's context loader does not recognize the prose value in PRODUCT.md's Platform field and treats it as web. The implementation is Flutter/Android; this review used native source guidance. The metadata was not modified.
