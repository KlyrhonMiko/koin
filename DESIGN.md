# Koin interface

The established app uses Outfit, teal accents, light and dark theme tokens, Material icons, patterned summary cards, and rounded grouped surfaces. Use shared components across savings surfaces.

## Shared consistency rules

Use KoinTypography's entity-name, amount-input and summary styles. Entity names use 28px, weight 800 and -0.5 tracking; amount inputs use 48px, weight 700 and -2 tracking. Summary labels use 13px, weight 500; summary amounts use 38px, weight 700 and -1 tracking. Chart and compact badge labels use the shared 11px metadata roles.

Use KoinShape for 16px field corners, 28px modal-sheet top corners and 28px summary-card corners. Keep circular quick actions and 24px portfolio cards as separate intentional component roles. Reports and forms use the shared joined choice control. Back actions use the Material rounded arrow; functional delete actions use the rounded outlined glyph.

Keep semantic fill and content colors separate. Use readable income, expense, transfer and error foregrounds on neutral surfaces. Solid action foregrounds follow onPrimary in both themes; gradient actions use a foreground chosen against their opaque stops. Preserve the original bright summary-card palette and white text: the default card gradient uses the selected accent and its 80%-opacity stop; custom card gradients retain their supplied colors. Do not darken main cards as part of contrast or consistency fixes. PDF exports retain fixed brand teal with readable print colors, embedded Outfit and rendered bundled Material glyphs.

## Savings details

Use the shared app theme without local palette overrides. Keep the goal name, linked account, and back navigation in a compact header. Show the linked account logo beside its name, falling back to the account icon when no image is available. Truncate long names safely and allow the goal title to wrap at larger text sizes.

Show total saved in a KoinSummaryCard with the savings pattern, 28px corners, 24px padding, and the shared summary amount scale. Use white text throughout the main summary card, matching the dashboard hero. Retain actual target progress and remaining savings for goals with targets; omit target UI for open-ended savings.

Place Save, Release, Edit, and Delete in one row of circular surface buttons with labels below the main card, matching dashboard quick actions. Wrap them into two columns at large text sizes or on narrow screens. Disable release for empty savings and preserve linked-account balance warnings.

Use an open savings-plan section with the shared section header, muted edit action, and two columns for next contribution and projected total. Put muted labels above neutral amounts and scheduled dates below. Stack the metrics on narrow screens or at large text sizes. Offer plan setup with a short explanation when no plan exists.

Use a shared section heading for recent activity and flat rows for entries with subtle separators and no enclosing card. Use the transaction-list typography and small tinted circular direction icons. Keep entry dates, signed amounts, swipe deletion, manual editing, and expandable automatic-release explanations. Preserve loading, error, empty, and reduced-motion behavior.

For goals (not open-ended savings), keep the main summary card focused on the saved balance like the reference savings screen. Place target progress, deadline, saving pace, and schedule editing in an open Goal progress section below the action row. Show daily, weekly, and monthly rates without adding a separate Savings plan section. Completed goals show Target reached; goals without a deadline explain that a deadline is needed for pace estimates.

## Savings overview

Use a balance-only summary and one Savings & goals list with one outlined Add savings / goal action beneath the last item, using the shared portfolio add button. Align item amounts with the right content inset. Distinguish item types in their compact subtitles and icons, without separate group headings or type badges. Keep current balances prominent and target progress visible. Show only a short cadence label for savings (Weekly savings, Monthly savings, or Every 2 weeks), without repeating contribution amounts; use Open-ended savings when no schedule exists. Keep contribution amounts and projections in details. Preserve item navigation and swipe deletion.

## Transaction history

Use open, flat day sections matching the activity rows in flutter_03.png. Keep date headings and daily totals on the page background, with no enclosing surface cards or header borders. Use small tinted category icons, bold signed amounts aligned with the title, and category, account, and time together underneath. Preserve search, filters, editing, swipe deletion, and reduced-motion behavior.

## Spending analysis

Keep spending primary within Koin's established teal, Outfit, patterned-card design. Keep the Activity & Flow header, tabs, spending card, period toolbar, chart, and category list on the shared KoinSpacing.screenInset (20px on both sides). Inset only Forecast by an additional 8px on each side (28px total), centering its content slightly inward from the surrounding sections.

Place the regular spending card directly after the Analysis/Transactions tabs. Match the dashboard's internal 24px horizontal and 16px vertical padding, shared summary typography, label-to-amount spacing, full-width amount row, and trailing show/hide control. Use the shared balance-privacy preference and replace the comparison with a hidden-state message when spending is hidden. Put one compact comparison sentence below the amount. Preserve the bright teal card and white text; large totals must use the available width rather than a narrow column beside a cutout.

Use one joined period toolbar below the card: date navigation on the left and week/month/year choices on the right, separated by a subtle divider within one outlined surface. Keep dates on one line and shorten same-month week ranges. At narrow widths or large text sizes, stack the period choices above date navigation within the same surface.

Keep Forecast as a compact open row directly below the period toolbar and above the spending chart, inset 8px beyond the surrounding content. Put the explicit future horizon and Estimated balance label above the neutral 20px amount, with a muted Details action on the right. Omit a separate Forecast heading. Stack the action below the estimate on narrow widths or at large text sizes. The whole row and Details open the existing details sheet; keep shortfall warnings visible beneath the row and the estimation explanation in the sheet.

Place the chart below the compact forecast row, with a labeled action switching between Trend and Categories. Follow the chart with Top Categories as flat rows on the page background. Preserve category drilldowns, loading, error, empty, refresh, and reduced-motion behavior.

Category-list dividers appear only between rows in Top Categories and Active Budgets. Do not put a rule beneath the last item or a single-item list.

## Monthly budgets

Match Activity & Flow's plain screen header, shared 20px screen inset, and compact patterned teal summary card. Use 24px horizontal and 16px vertical card padding, the shared summary label and amount styles, a currency label, and the shared balance-privacy control. Show usage as a short sentence below the full-width amount instead of a circular gauge.

Place month navigation as plain text with previous/next arrows beneath the card, without a pill background or border. Keep the controls accessible, prevent navigation beyond the current month, and let the month label return to the current month. Keep navigation available when no budgets are configured.

Make Remaining the main teal card's label and large amount, using the shared summary typography. When overspent, show Over Budget and the amount exceeded. Combine the spent amount, percentage used, and remaining (or over-budget) amount into one wrapping sentence beneath the main amount, using the shared privacy preference. Omit separate Spent and Monthly Budget footer metrics. Do not add a separate totals section, progress bar, or metric cards beneath the month switcher. Use flat active-budget rows with small tinted category icons, progress bars, and separators only between items, preserving editing and setup actions.

## Native quick entry

The short window opened from Android Quick Settings uses the same KoinFormTheme as the transaction editor, the shared page background throughout, 20px content insets, Outfit heading styles, and 28px sheet corners. Keep Add transaction as the primary teal action, with Claim income and Open app as compact shared action rows below. Use the app icon beside the opening title, grouped transaction-type choices with semantic icon colors, shared account/category selectors and keypad, and KoinPrimaryButton for saving. Preserve content-driven native window sizing, drag dismissal, draft handling, accessibility, and all transaction validation.
