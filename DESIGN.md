# Koin interface

The established app uses Outfit, teal accents, light and dark theme tokens, Material icons, patterned summary cards, and rounded grouped surfaces. Use shared components across savings surfaces.

## Shared consistency rules

All tooltips inherit the shared app tooltip theme: theme surface and text colors, a subtle outline, 12px corners, 16px horizontal and 12px vertical padding, and Outfit compact label text. Use the same treatment for full account amounts, action hints, navigation hints, and chart popups; avoid local tooltip styling.

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

Text fields across routes, dialogs, and sheets clear focus on outside taps and when the software keyboard finishes closing. Keep field-to-field focus transfer and grouped input accessories working. Apply this behavior to both the main app and standalone quick entry.

Entity editors share UnsavedChangesGuard and the existing danger confirmation sheet for unsaved changes. Back, close, outside taps, and sheet dismissal must preserve the draft until Discard is confirmed; Cancel keeps every field. Unchanged or reverted drafts leave without a prompt. Successful saves leave directly, while pending saves block dismissal and failures retain the draft. Confirmation content scrolls when large text exceeds the available height.

Transient notifications use KoinSnackBar throughout the app. Keep short feedback content-sized, with a 48px minimum height, 12px corners, a small unboxed status icon, and a 360px maximum width. Center the icon vertically against the full text block, including subtitles and wrapped lines. Float near the bottom with clearance for navigation, save controls, system insets, and the keyboard; keep headers and tabs visible. Preserve full wrapping text for errors and subtitles, live announcements, reduced motion, swipe-down dismissal, and replacement of an earlier message. Keep the overlay above modal sheets so their errors remain visible. Opening a confirmation clears earlier feedback so it cannot cover the prompt or its actions.

## Account cards

Use the dashboard's compact account card across the dashboard, accounts grid, and create/edit previews: 16px corners and padding, a top row with a 24px logo beside a two-line name, and the balance beneath with the eye at the top right. Keep the base card under 105px tall at normal text scale. Reserve the same name height on all cards; truncate unusually long names with an ellipsis. Keep the preview read-only. Place separate full-width Account name and Balance fields immediately below it, updating the preview live. Allow the name field to grow for long names. Keep bank foreground colors and background patterns consistent. Accounts use two columns, falling back to one on narrow screens or at large text sizes. Use a direct eye toggle in the top-right corner to hide or show it without adding a control row. Support press-and-hold dragging to rearrange accounts and swipe deletion. Center create/edit previews at the same grid-card width as dashboard and account cards, with editing handled by the labeled fields below. The dashboard's main balance eye controls only its summary visibility; each account card uses its own eye and saved account privacy state, shared with the Accounts screen.

The archive manager uses these same compact AccountItem cards and responsive grid, preserving bank logos, colors, patterns, balance formatting, and stored privacy. Keep the cards clear of repeated buttons or labels. Category entries reuse CategoryItem from Manage Categories, including its rounded surface, colored icon badge, name, and budget subtitle; omit the chevron and drag handle here. Explain the direct card action once above the list: tap to archive in the active view or restore in the archived view. Do not add a menu for a single choice; archiving opens its confirmation directly and restoring acts immediately. Show a small progress indicator only while saving an item.

## Savings overview

Use a balance-only summary and one Savings & goals list with one outlined Add savings / goal action beneath the last item, using the shared portfolio add button. Align item amounts with the right content inset. Distinguish item types in their compact subtitles and icons, without separate group headings or type badges. Keep current balances prominent and target progress visible. Show only a short cadence label for savings (Weekly savings, Monthly savings, or Every 2 weeks), without repeating contribution amounts; use Open-ended savings when no schedule exists. Keep contribution amounts and projections in details. Preserve item navigation and swipe deletion.

## Transaction history

Use open, flat day sections matching the activity rows in flutter_03.png. Keep date headings and daily totals on the page background, with no enclosing surface cards or header borders. Use small tinted category icons, bold signed amounts aligned with the title, and category, account, and time together underneath. Preserve search, filters, editing, swipe deletion, and reduced-motion behavior.

## Spending analysis

Keep spending primary within Koin's established teal, Outfit, patterned-card design. Keep the Activity & Flow header, tabs, spending card, period toolbar, chart, and category list on the shared KoinSpacing.screenInset (20px on both sides). Inset only Forecast by an additional 8px on each side (28px total), centering its content slightly inward from the surrounding sections.

Place the regular spending card directly after the Analysis/Transactions tabs. Match the dashboard's internal 24px padding on all sides, shared summary typography, 16px gaps between the label, amount, and supporting text, full-width amount row, and top-right show/hide control beside the label. Use the shared balance-privacy preference and replace the comparison with a hidden-state message when spending is hidden. Put one compact comparison sentence below the amount. Preserve the bright teal card and white text; large totals must use the available width rather than a narrow column beside a cutout.

Use one joined period toolbar below the card: date navigation on the left and week/month/year choices on the right, separated by a subtle divider within one outlined surface. Keep dates on one line and shorten same-month week ranges. At narrow widths or large text sizes, stack the period choices above date navigation within the same surface.

Keep Forecast as a compact open row directly below the period toolbar and above the spending chart, inset 8px beyond the surrounding content. Put the explicit future horizon and Estimated balance label above the neutral 20px amount, with a muted Details action on the right. Omit a separate Forecast heading. Stack the action below the estimate on narrow widths or at large text sizes. The whole row and Details open the existing details sheet; keep shortfall warnings visible beneath the row and the estimation explanation in the sheet.

Place the chart below the compact forecast row, with a labeled action switching between Trend and Categories. Follow the chart with Top Categories as flat rows on the page background. Preserve category drilldowns, loading, error, empty, refresh, and reduced-motion behavior.

Category-list dividers appear only between rows in Top Categories and Active Budgets. Do not put a rule beneath the last item or a single-item list.

## Monthly budgets

Match Activity & Flow's plain screen header, shared 20px screen inset, and compact patterned teal summary card. Use 24px horizontal and 16px vertical card padding, the shared summary label and amount styles, a currency label, and the shared balance-privacy control. Show usage as a short sentence below the full-width amount instead of a circular gauge.

Place month navigation as plain text with previous/next arrows beneath the card, without a pill background or border. Keep the controls accessible, prevent navigation beyond the current month, and let the month label return to the current month. Keep navigation available when no budgets are configured.

Make Remaining the main teal card's label and large amount, using the shared summary typography. When overspent, show Over Budget and the amount exceeded. Show only the spent amount and percentage used in the wrapping sentence beneath the main amount, using the shared privacy preference. Keep the remaining or over-budget amount in the main figure only. Omit separate Spent and Monthly Budget footer metrics. Do not add a separate totals section, progress bar, or metric cards beneath the month switcher. Use flat active-budget rows with small tinted category icons, progress bars, and separators only between items, preserving editing and setup actions.

## Native quick entry

The short window opened from Android Quick Settings uses the same KoinFormTheme as the transaction editor, the shared page background throughout, 20px content insets, Outfit heading styles, and 28px sheet corners. Keep Add transaction as the primary teal action, with Claim income and Open app as compact shared action rows below. Use the app icon beside the opening title, grouped transaction-type choices with semantic icon colors, shared account/category selectors and keypad, and KoinPrimaryButton for saving. Preserve content-driven native window sizing, drag dismissal, draft handling, accessibility, and all transaction validation.

## Account editor

Use open underlined name and balance inputs with persistent labels above, a 20px name and 28px balance, and live preview updates. Group Private account and Credit account in one quiet surface with a divider and native teal switches. Transfer fee has its own section with the shared Fixed amount / Percentage choice control, a labeled input with currency or percent units, and concise zero-fee guidance. Preserve account storage and validation.
