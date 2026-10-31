# Koin polish and refinement inventory — 30 October 2026

Implementation follow-up: see the [resolution map](polish-resolution-2026-10-31.md) and [visual checklist](polish-visual-checklist-2026-10-31.md). The findings below describe the original before-state.

Method: native design/source review with current Flutter widget-render evidence. Impeccable native critique/audit guidance and the app-screen review guidance informed this review. A web detector is not applicable to this Flutter Android app.

Scope: the native app in D:/projects/koin, including all feature screen families, editors, shared controls, secondary sheets, Quick Entry source, voice source, and recovery flows. The separate koin-web project was outside this native-app review.

Evidence: 27 primary screen fixtures plus 10 secondary states, each rendered in five variants (185 captures): light phone 390×844, dark phone 390×844, dark 320×640 at 180% text, landscape 640×360, tablet 1000×800. Focused probes reproduced the grouped-amount exception, repayment draft dismissal, and actual modal overflows. The render harness records Flutter errors rather than failing the test, so its runner's “All tests passed” message is not a clean UI result. The secondary matrix recorded 10 overflow cases and 5 active-filter tap-target failures.

No production implementation was changed and no real financial records were edited. The existing Outfit, teal, patterned summaries, account privacy/inclusion choices, icon-only phone navigation, and compact layouts were treated as intentional design commitments.

Limitations: no Android device was attached, and the configured Android SDK had no emulator executable. These are widget renders, not device screenshots. System Back/predictive Back, IME transitions, speech/microphone permissions, device authentication, native window behavior, file pickers, real backup restore/export, physical haptics, and frame-time performance were not exercised. A few currency/bold-icon glyphs render as fallback boxes in the test harness; those are excluded from app findings. Some fixtures mount feature bodies directly; tablet observations about full routes are grounded in the corresponding route source, not in stretched standalone tab fixtures.

Priorities: P1 = fix before cosmetic work; P2 = meaningful usability/accessibility refinement; P3 = optional polish or efficiency. Evidence types distinguish reproduced defects, source-confirmed behavior, rendered observations, and optional proposals. This is a comprehensive observed inventory, not a guarantee that every possible runtime issue has been found.

What is already working: a coherent Outfit/teal identity; reusable financial cards, form components, and themed feedback; robust validation/draft protection in most primary editors; distinct recorded balances and projections; a labeled expanded-width navigation rail and reduced-motion support. The 135 primary-state renders produced no captured layout exceptions or target/label guideline failures. Problems emerged in secondary states and visual inspection.

## 1. [P1] Savings Helper rejects a valid grouped amount on Save

Area: Savings. Evidence: Reproduced defect.

Typing 1,000 passes currency validation as 1000, then Save plan throws FormatException because it calls double.parse on the original text. Reproduced in the focused widget probe.

Refinement: Save the already validated currency parser result.

Location: [lib/features/savings/widgets/savings_plan_editor.dart](D:/projects/koin/lib/features/savings/widgets/savings_plan_editor.dart:184).

## 2. [P1] Repayment and credit-increase sheets overflow

Area: Debt sheets. Evidence: Reproduced defect.

Both sheets overflow at 320×640 with 180% text and at 640×360. Their fixed Column has no scrolling fallback; the keypad and completion action extend beyond the viewport.

Refinement: Use a height-aware scrollable sheet and keep the completion action reachable.

Location: [lib/features/debts/widgets/add_repayment_sheet.dart](D:/projects/koin/lib/features/debts/widgets/add_repayment_sheet.dart:151).

## 3. [P1] Budget editor overflows in constrained layouts

Area: Budgets. Evidence: Reproduced defect.

The current budget sheet overflows at enlarged text and in landscape, despite the overview screen rendering successfully.

Refinement: Allow the header, amount, guidance, and keypad to scroll or reflow together.

Location: [lib/features/budgets/widgets/budget_editor_sheet.dart](D:/projects/koin/lib/features/budgets/widgets/budget_editor_sheet.dart:149).

## 4. [P1] Savings contribution/release sheet needs a short-screen layout

Area: Savings. Evidence: Reproduced defect.

SavingsLogSheet overflows at 180% text and in landscape. Draft protection exists, but the full keypad cannot fit.

Refinement: Add the same adaptive entry layout used by the transaction editor, retaining validation and draft handling.

Location: [lib/features/savings/widgets/savings_log_sheet.dart](D:/projects/koin/lib/features/savings/widgets/savings_log_sheet.dart:221).

## 5. [P1] Scheduled-payment confirmation overflows

Area: Recurring payments. Evidence: Reproduced overflow; long-expression risk from source.

The confirmation sheet overflows at enlarged text and in landscape. Its amount expression also sits in an unconstrained horizontal Row, making long amounts/calculations another vulnerable state.

Refinement: Use the shared calculator amount display and a scrollable, height-aware layout.

Location: [lib/core/widgets/sheets/payment_confirmation_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/payment_confirmation_sheet.dart).

## 6. [P1] Upcoming rows become unreadable at enlarged text

Area: Upcoming. Evidence: Current-render observation.

At 320×640 and 180% text, the trailing amount consumes almost the entire row. The title vanishes and the date/status wraps into vertical letters. No RenderFlex exception is raised.

Refinement: Stack amount and date beneath the title when intrinsic widths no longer fit.

Location: [lib/features/dashboard/widgets/upcoming_entry_tile.dart](D:/projects/koin/lib/features/dashboard/widgets/upcoming_entry_tile.dart).

## 7. [P1] Repayment and scheduled-confirmation drafts lack dismissal protection

Area: Financial drafts. Evidence: Repayment dismissal reproduced; scheduled sheet confirmed in source.

These two sheets use showModalBottomSheet without UnsavedChangesGuard. A repayment note can be dismissed with no confirmation; the focused probe reproduced the lost draft. Repayment dismissal is also not blocked during its async save.

Refinement: Apply the established draft guard, distinguish unchanged defaults from edits, and block dismissal while committing.

Location: [lib/features/debts/widgets/add_repayment_sheet.dart](D:/projects/koin/lib/features/debts/widgets/add_repayment_sheet.dart).

## 8. [P1] The confirmation sheet closes before the payment is persisted

Area: Recurring payments. Evidence: Confirmed control flow; failure not injected.

_submit pops the edited amount/account/category; _confirmAndProcess performs the write afterward. A write failure shows a snackbar after the editable draft has gone.

Refinement: Keep the confirmation and its edited fields mounted through save, with a loading state and in-place retry.

Location: [lib/core/widgets/sheets/payment_confirmation_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/payment_confirmation_sheet.dart).

## 9. [P1] Purchase save failures can lose the edited draft

Area: Credit purchases. Evidence: Confirmed control flow; failure not injected.

The purchase sheet returns a DebtItem before persistence. Both add/edit callbacks in debt details await saveDebtItem without a local error handler after the sheet closes.

Refinement: Retain the purchase draft until persistence succeeds and show a retryable error beside it.

Location: [lib/features/debts/debt_details_screen.dart](D:/projects/koin/lib/features/debts/debt_details_screen.dart).

## 10. [P2] Savings details silently fall back to stale data

Area: Savings. Evidence: Confirmed source behavior.

The summary uses the route's original goal on provider error and when the goal is absent from refreshed results. Users can see an apparently current balance with enabled actions.

Refinement: Distinguish loading, refresh failure, and a missing goal; label retained data and gate actions that need fresh balances.

Location: [lib/features/savings/savings_details_screen.dart](D:/projects/koin/lib/features/savings/savings_details_screen.dart:94).

## 11. [P2] Active-filter Clear is too small

Area: Transactions. Evidence: Measured accessibility failure.

The Android tap-target check measures Clear at approximately 44.2×22 dp at normal text and 65.7×34 dp at enlarged text. All five tested variants fail this check.

Refinement: Use a shared accessible button with an actual 48×48 dp target and keyboard focus feedback.

Location: [lib/features/transactions/transactions_list_screen.dart](D:/projects/koin/lib/features/transactions/transactions_list_screen.dart).

## 12. [P2] Joined choices split words at enlarged text

Area: Shared controls. Evidence: Current-render observation.

Current enlarged renders split Transactions and Expenses across the middle of words. _SegmentTrack holds equal-width segments and allows two lines without measuring whether each word fits.

Refinement: Switch to stacked options or horizontally scrollable tabs based on measured label width.

Location: [lib/core/widgets/primitives/koin_segmented_control.dart](D:/projects/koin/lib/core/widgets/primitives/koin_segmented_control.dart).

## 13. [P2] Money can wrap mid-number or shrink against text preferences

Area: Financial typography. Evidence: Current renders plus source.

The debt list's original amount wraps its last digit onto another line at 180% text. Other list amounts use FittedBox and become smaller as text grows; savings names remain single-line and heavily truncated.

Refinement: Give amounts and entity names their own lines before scaling down; keep complete numeric tokens together.

Location: [lib/features/debts/debts_tab.dart](D:/projects/koin/lib/features/debts/debts_tab.dart).

## 14. [P2] Entity name fields rely on disappearing hints

Area: Shared forms. Evidence: Current renders plus source.

Goal, debt, and schedule name fields use large centered placeholders with no persistent field label. Once filled, their purpose is no longer visible; the light-mode hint is particularly faint.

Refinement: Keep the established open-input appearance while adding a quiet persistent label and an explicit accessible field name.

Location: [lib/core/widgets/inputs/koin_entity_fields.dart](D:/projects/koin/lib/core/widgets/inputs/koin_entity_fields.dart).

## 15. [P2] Validation should identify and reveal the exact missing field

Area: Validation. Evidence: Confirmed source behavior.

Transaction save reports generic required fields, including Category for a transfer where no category is required. Schedule/category/account errors often use a snackbar without focusing or scrolling to the field.

Refinement: Show contextual inline errors, focus the first invalid input, and use transaction-type-specific copy.

Location: [lib/features/transactions/add_transaction_screen.dart](D:/projects/koin/lib/features/transactions/add_transaction_screen.dart:329).

## 16. [P2] Empty and failed pickers can strand the user

Area: Pickers. Evidence: Confirmed source behavior.

Shared pickers snapshot provider.value or an empty list. Category picker supplies no empty message, so zero available categories produce a blank options area. Account picker has an empty message but no create/retry path.

Refinement: Preserve loading/error states and provide a relevant create, restore, or retry action.

Location: [lib/core/widgets/sheets/category_picker_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/category_picker_sheet.dart).

## 17. [P2] Shared picker selection needs explicit accessibility state

Area: Pickers. Evidence: Source accessibility gap; TalkBack not run.

SelectSheetItem draws a check/radio indicator for the chosen option but does not expose selected or mutually exclusive semantics as the newer shared choice controls do.

Refinement: Expose option labels and selection state consistently; avoid announcing decorative indicators separately.

Location: [lib/core/widgets/sheets/select_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/select_sheet.dart).

## 18. [P3] Long option lists need search

Area: Pickers. Evidence: Optional efficiency refinement.

Account/category and currency pickers rely on scrolling. Speech languages also render the full installed-language list without search.

Refinement: Add search when lists exceed a useful threshold and keep the current selection easy to find.

Location: [lib/core/widgets/sheets/select_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/select_sheet.dart).

## 19. [P2] Voice stop/cancel orb has no explicit action label

Area: Voice. Evidence: Source accessibility gap; microphone not exercised.

The orb is an icon-only PressableScale whose action changes between stopping listening and canceling. It supplies no semanticLabel.

Refinement: Expose the current action and listening state, with restrained live announcements for status changes.

Location: [lib/features/transactions/widgets/voice_input_sheet.dart](D:/projects/koin/lib/features/transactions/widgets/voice_input_sheet.dart).

## 20. [P2] Voice errors need direct recovery controls

Area: Voice. Evidence: Confirmed UI branch; OS errors not exercised.

The initial listening/error view shows Something went wrong, the error string, and an X orb. Retry exists in the parsed-review view, but not in this initial error view.

Refinement: Offer Retry and Enter manually, and a permission-specific settings action when appropriate.

Location: [lib/features/transactions/widgets/voice_input_sheet.dart](D:/projects/koin/lib/features/transactions/widgets/voice_input_sheet.dart).

## 21. [P3] Make the overview chart's time window explicit

Area: Home. Evidence: Copy refinement grounded in source.

Home labels its chart Spending Overview while its implementation always uses the current calendar week. The summary above discusses this month.

Refinement: Label it Spending this week so the two nearby summaries are easy to reconcile.

Location: [lib/features/dashboard/dashboard_screen.dart](D:/projects/koin/lib/features/dashboard/dashboard_screen.dart).

## 22. [P2] Monthly trend compresses away days with no spending

Area: Analysis. Evidence: Confirmed chart construction.

The month branch builds bars from sortedDaily entries only and spaces them evenly. Two spending days far apart appear adjacent, unlike the weekly view's complete calendar sequence.

Refinement: Include every calendar date with a zero value or use a genuinely time-spaced axis.

Location: [lib/core/widgets/cards/spending_trend_chart.dart](D:/projects/koin/lib/core/widgets/cards/spending_trend_chart.dart).

## 23. [P2] Trend values need an accessible equivalent

Area: Charts. Evidence: Source accessibility gap; TalkBack not run.

The category donut has an explicit semantic summary; SpendingTrendChart does not provide equivalent date/value semantics or a textual data view.

Refinement: Provide a concise chart summary and an accessible date/value list.

Location: [lib/core/widgets/cards/spending_trend_chart.dart](D:/projects/koin/lib/core/widgets/cards/spending_trend_chart.dart).

## 24. [P3] Improve date tooltips and axis numbers

Area: Charts. Evidence: Current renders plus source.

Weekly labels and tooltips reuse single-letter weekdays, making Tuesday/Thursday and Saturday/Sunday ambiguous. Y-axis ticks are arbitrary fractions of the maximum, such as 69, 138, and 207 in the fixture.

Refinement: Use full dates in tooltips and rounded, legible tick intervals while retaining compact axis labels.

Location: [lib/core/widgets/cards/spending_trend_chart.dart](D:/projects/koin/lib/core/widgets/cards/spending_trend_chart.dart).

## 25. [P2] Shortfall guidance should lead directly to the relevant commitments

Area: Forecast. Evidence: Workflow refinement.

Forecast details tells the user to review upcoming payments but offers no navigation action to do so.

Refinement: Add Review upcoming payments beside the warning and retain the explicit estimate horizon and existing privacy behavior.

Location: [lib/features/analysis/widgets/forecast_summary.dart](D:/projects/koin/lib/features/analysis/widgets/forecast_summary.dart).

## 26. [P2] Show what the active filters actually are

Area: Transaction filters. Evidence: Confirmed source behavior.

The summary says Date range and 1 category or 1 account, without the selected dates or names. Users must reopen the sheet to remember the scope.

Refinement: Show meaningful names and the actual interval, wrapping or disclosing the complete summary accessibly.

Location: [lib/core/models/transactions/transaction_filter.dart](D:/projects/koin/lib/core/models/transactions/transaction_filter.dart).

## 27. [P2] Search needs a clear-query action and a precise scope hint

Area: Search. Evidence: Confirmed source behavior.

KoinSearchField has no clear suffix. Transaction search matches notes/category names, while its hint simply says Search transactions. Clearing all filters also clears the query.

Refinement: Add a 48 dp clear-query control that preserves other filters and clarify searchable fields.

Location: [lib/core/widgets/inputs/koin_search_field.dart](D:/projects/koin/lib/core/widgets/inputs/koin_search_field.dart).

## 28. [P2] Make the calculator's evaluation rule understandable

Area: Calculator entry. Evidence: Confirmed arithmetic rule; UX recommendation.

NumPad deliberately evaluates left to right, so 2+3×4 becomes 20. Users familiar with operator precedence may expect 14; no visible rule explains the difference.

Refinement: Keep the agreed arithmetic behavior unless changed deliberately; make its left-to-right rule discoverable in a concise calculator explanation and retain the existing evaluated-result display.

Location: [lib/core/widgets/inputs/numpad.dart](D:/projects/koin/lib/core/widgets/inputs/numpad.dart).

## 29. [P2] Explain the total-changing effect of account privacy

Area: Accounts. Evidence: Clarity refinement; existing behavior retained.

The account eye controls both hiding the balance and exclusion from totals. This is stated in a tooltip and the Private account hint, but the visible icon resembles a presentation-only privacy control.

Refinement: Make the effect visible when the setting changes, for example in concise feedback and the account-setting explanation; preserve the intentional account behavior.

Location: [lib/core/widgets/cards/account_item.dart](D:/projects/koin/lib/core/widgets/cards/account_item.dart).

## 30. [P2] Credit account needs a consequence-oriented helper

Area: Accounts. Evidence: Copy refinement.

The account settings row offers a Credit account switch without explaining the permitted negative balance or how the account represents borrowed money.

Refinement: Add concise visible help before users switch financial interpretation.

Location: [lib/features/accounts/account_form_screen.dart](D:/projects/koin/lib/features/accounts/account_form_screen.dart).

## 31. [P2] Automatic release explanation should open its transaction

Area: Savings activity. Evidence: Confirmed workflow gap.

The expandable read-only explanation tells users to edit/delete the linked transaction but provides no shortcut, even though the log stores transactionId.

Refinement: Offer View transaction while retaining the read-only savings log.

Location: [lib/features/savings/savings_details_screen.dart](D:/projects/koin/lib/features/savings/savings_details_screen.dart).

## 32. [P3] Connect the due contribution to Save

Area: Savings routines. Evidence: Optional efficiency refinement.

The routine shows Next contribution and its amount, but the main Save action opens a blank contribution sheet rather than using that planned amount.

Refinement: Offer an editable suggested contribution when a plan is due, with no automatic balance change.

Location: [lib/features/savings/widgets/savings_routine_card.dart](D:/projects/koin/lib/features/savings/widgets/savings_routine_card.dart).

## 33. [P2] Use direction-specific repayment language and shared currency formatting

Area: Debt wording. Evidence: Current renders plus source.

Owed-to-me records still use Credit Details, Log Payment, Remaining Credit, and Increase Credit. The account subtitle manually formats balances without grouping, unlike other financial screens.

Refinement: Use Money owed to you / Record repayment received or equivalent context, and the shared currency formatter.

Location: [lib/features/debts/widgets/add_repayment_sheet.dart](D:/projects/koin/lib/features/debts/widgets/add_repayment_sheet.dart).

## 34. [P2] Balance-only increases show misleading transaction feedback

Area: Debt feedback. Evidence: Confirmed success-message branch.

Increasing credit with no account selected can succeed, but the success subtitle still says Transaction added to Account.

Refinement: Describe a balance-only update accurately; name the account only when a ledger entry was recorded.

Location: [lib/features/debts/widgets/add_repayment_sheet.dart](D:/projects/koin/lib/features/debts/widgets/add_repayment_sheet.dart).

## 35. [P2] Clarify which occurrence is being paid or collected

Area: Recurring payments. Evidence: Confirmed source behavior.

Future scheduled items can expose an enabled Make payment / Collect income action. The confirmation shows title, amount, category, and account but not the occurrence's scheduled date or what advances afterward.

Refinement: Show the occurrence date and an early-payment/collection explanation when applicable.

Location: [lib/core/widgets/sheets/payment_confirmation_sheet.dart](D:/projects/koin/lib/core/widgets/sheets/payment_confirmation_sheet.dart).

## 36. [P2] Warn before a category-type change removes its budget

Area: Categories. Evidence: Confirmed source behavior.

Changing an existing expense category to Income calls withoutBudget on save without explaining the lost budget configuration.

Refinement: Show the specific budget consequence before committing the type change.

Location: [lib/features/categories/category_detail_screen.dart](D:/projects/koin/lib/features/categories/category_detail_screen.dart).

## 37. [P2] Optional appearance controls dominate the save path

Area: Category editor. Evidence: Current renders plus source.

Category save is below the entire icon/color palette in the scrolling body. On tablets, the unbounded-width editor stretches its icon grid into large cells; on phones, simple renaming requires scrolling past appearance choices.

Refinement: Group appearance in a disclosure and keep the save action consistently reachable, following the account editor pattern.

Location: [lib/features/categories/category_detail_screen.dart](D:/projects/koin/lib/features/categories/category_detail_screen.dart).

## 38. [P2] Prevent contradictory transaction-type and category selections

Area: Reports. Evidence: Confirmed selection logic.

Report type selection changes _selectedType without reconciling selected category IDs. All categories remain shown, so Salary plus Expenses can silently produce no results.

Refinement: Show compatible choices and explicitly handle selected categories that conflict with the chosen transaction type.

Location: [lib/features/reports/custom_reports_screen.dart](D:/projects/koin/lib/features/reports/custom_reports_screen.dart).

## 39. [P2] Make implicit all-selection and filter reset explicit

Area: Reports. Evidence: Confirmed selection logic.

An empty account/category selection means all items, while every tile appears unselected. There is no clear All categories / All accounts state or one-step report filter reset.

Refinement: Name the all-selection state and offer a predictable reset.

Location: [lib/features/reports/custom_reports_screen.dart](D:/projects/koin/lib/features/reports/custom_reports_screen.dart).

## 40. [P3] Explain Total Volume and offer a small export preview

Area: Reports. Evidence: Optional clarity/preview refinement.

The preview sums positive transaction amounts across the selected records, labeled Total Volume. It does not show a transaction preview or explain how income, expenses, transfers, and loan activity contribute.

Refinement: Explain the metric and let users inspect a few matching rows before exporting.

Location: [lib/features/reports/custom_reports_screen.dart](D:/projects/koin/lib/features/reports/custom_reports_screen.dart).

## 41. [P2] Password entry needs visible rules and a visibility toggle

Area: Backup passwords. Evidence: Confirmed form configuration.

The eight-character rule appears only after submission. Both fields are always obscured and omit password-manager autofill hints and explicit next/done configuration.

Refinement: Show the rule up front, support accessible show/hide controls, and use new-password versus existing-password autofill appropriately.

Location: [lib/features/settings/backup_password_sheet.dart](D:/projects/koin/lib/features/settings/backup_password_sheet.dart).

## 42. [P3] Preview backup identity before replacement

Area: Backup restore. Evidence: Optional workflow refinement; restore not executed.

Import confirmation names the selected file, then decryption/validation happens afterward. The user cannot review backup date, currency, or record/account counts before replacement.

Refinement: Validate/unlock first, then show a concise metadata preview and the existing recovery-copy reassurance.

Location: [lib/features/settings/settings_screen.dart](D:/projects/koin/lib/features/settings/settings_screen.dart).

## 43. [P2] Differentiate the three destructive actions more clearly

Area: Destructive settings. Evidence: Copy refinement.

Delete All Records, Delete All Data, and Factory Reset require users to infer the distinction between transactions, financial entities, and preferences. Confirmations help, but the initial choices remain similar.

Refinement: Use explicit transaction/data/settings wording and concise consequence summaries while retaining the existing confirmations and backups.

Location: [lib/features/settings/settings_screen.dart](D:/projects/koin/lib/features/settings/settings_screen.dart).

## 44. [P2] A displayed zero opening balance is not an entered zero

Area: First-run setup. Evidence: Confirmed form behavior.

Current balance shows a 0.00 hint but starts with an empty controller; Start tracking rejects an untouched field. A user with no cash must type an otherwise identical zero.

Refinement: Choose a deliberate zero default or make the required entry state visibly distinct from a valid zero.

Location: [lib/features/onboarding/account_setup_screen.dart](D:/projects/koin/lib/features/onboarding/account_setup_screen.dart:409).

## 45. [P3] Secondary detail screens need a consistent maximum width

Area: Wide layouts. Evidence: Current renders plus source.

MainLayout centers rail content within 760 dp, and account/entity editors cap their forms. Savings/debt details and Settings can still stretch their content across a full tablet route.

Refinement: Apply suitable content-width constraints to secondary routes, retaining the existing rail and phone navigation.

Location: [lib/features/savings/savings_details_screen.dart](D:/projects/koin/lib/features/savings/savings_details_screen.dart).

## 46. [P3] Remove duplicate haptic calls

Area: Touch feedback. Evidence: Confirmed calls; physical effect not measured.

PressableScale triggers light haptics by default, while many wrapped callbacks call HapticService.light again, including transaction rows and account/card actions.

Refinement: Let the shared control own feedback or explicitly disable it when a callback supplies its own haptic.

Location: [lib/core/widgets/primitives/pressable_scale.dart](D:/projects/koin/lib/core/widgets/primitives/pressable_scale.dart).

## 47. [P2] Provide a non-drag reorder path

Area: Account reordering. Evidence: Source accessibility gap; TalkBack not run.

The custom account grid uses LongPressDraggable and DragTarget without explicit Move before / Move after accessibility or keyboard actions.

Refinement: Expose semantic reorder actions or a compact reorder mode alongside the existing drag gesture.

Location: [lib/features/accounts/account_reorder_grid.dart](D:/projects/koin/lib/features/accounts/account_reorder_grid.dart).

## 48. [P3] Build debt activity lazily

Area: Long histories. Evidence: Source performance opportunity; no device benchmark.

Repayments are expanded into a Column inside SliverToBoxAdapter, and purchase schedules/items are expanded eagerly. Large credit histories therefore build off-screen rows together.

Refinement: Use lazy slivers for activity and bound expensive purchase-schedule work; profile with a long-history fixture before optimizing further.

Location: [lib/features/debts/debt_details_screen.dart](D:/projects/koin/lib/features/debts/debt_details_screen.dart).

## 49. [P3] Archive toggle label should match its exclusive behavior

Area: Archive manager. Evidence: Confirmed source behavior.

Show archived items replaces the active list rather than adding archived entries. The switch does not name the two mutually exclusive modes.

Refinement: Use an explicit Active / Archived choice or label the current exclusive state clearly; preserve direct archive/restore card actions.

Location: [lib/features/settings/archive_manager_screen.dart](D:/projects/koin/lib/features/settings/archive_manager_screen.dart).

## 50. [P3] Normalize secondary headers and action copy

Area: Visual consistency. Evidence: Current renders plus source.

Settings, Reports, Archive, category management, and entity editors mix header components, title alignment, type sizes, and title/sentence case. Generic keypad Save also appears where the task is confirming a payment.

Refinement: Apply shared header roles and task-specific action labels, and standardize sentence case without changing the established Outfit/teal visual identity.

Location: [lib/core/widgets/inputs/numpad.dart](D:/projects/koin/lib/core/widgets/inputs/numpad.dart).

## Evidence files and recommended order

- Primary capture results: [.impeccable/review/polish-2026-10-30/results.json](D:/projects/koin/.impeccable/review/polish-2026-10-30/results.json).
- Secondary capture results: [.impeccable/review/polish-extra-2026-10-30/results.json](D:/projects/koin/.impeccable/review/polish-extra-2026-10-30/results.json).
- Interaction probes: [.impeccable/review/polish-probes.json](D:/projects/koin/.impeccable/review/polish-probes.json).
- Large-text Upcoming evidence: [large-upcoming.png](D:/projects/koin/.impeccable/review/polish-2026-10-30/large-upcoming.png).
- Budget overflow evidence: [large-budget-editor.png](D:/projects/koin/.impeccable/review/polish-extra-2026-10-30/large-budget-editor.png).

Fix 1–9 first; address shared accessibility/adaptive controls next; then refine financial copy and workflow shortcuts. Use Impeccable harden/adapt for those first passes, clarify for financial language, optimize only after profiling the long-history state, and polish for final consistency. Preserve the established visual system.

Run notes: native single-context method; no dual-agent isolation or web detector required for native. No critique ignore file was found. No live server or emulator was started. Review harnesses/captures remain in the ignored .impeccable/review directory; this report is the durable tracked artifact. Questions skipped: the request was for an enumerated review, with no implementation decision needed.
