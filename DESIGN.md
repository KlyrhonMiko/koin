# Koin interface

The established app uses Outfit, teal accents, light and dark theme tokens, Phosphor icons (regular by default; filled for selected navigation, entity/category icons, and the dashboard greeting sun/moon), patterned summary cards, and rounded grouped surfaces. Visibility controls retain Koin's original Material rounded eye and eye-off icons by user preference. Use shared components across savings surfaces.

## Shared consistency rules

All tooltips inherit the shared app tooltip theme: theme surface and text colors, a subtle outline, 12px corners, 16px horizontal and 12px vertical padding, and Outfit compact label text. Use the same treatment for full account amounts, action hints, navigation hints, and chart popups; avoid local tooltip styling.

Enabled, selected switches use a white thumb in light mode on the selected accent track. Account settings inherit the same shared switch treatment.

Use KoinTypography's entity-name, amount-input and summary styles. Entity names use 28px, weight 800 and -0.5 tracking; amount inputs use 48px, weight 700 and -2 tracking. Summary labels use 13px, weight 500; summary amounts use 38px, weight 700 and -1 tracking. Chart and compact badge labels use the shared 11px metadata roles.

Use KoinShape for 16px field corners, 28px modal-sheet top corners and 28px summary-card corners. Keep circular quick actions and 24px portfolio cards as separate intentional component roles. Reports and forms use the shared joined choice control. Back actions use the Phosphor arrowLeft; delete actions use trash. Budgets use calculator, Activity uses chartBar, Home uses house, and Portfolio uses wallet.

Keep semantic fill and content colors separate. Use readable income, expense, transfer and error foregrounds on neutral surfaces. Solid action foregrounds follow onPrimary in both themes; gradient actions use a foreground chosen against their opaque stops. Preserve the original bright summary-card palette and white text: the default card gradient uses the selected accent and its 80%-opacity stop; custom card gradients retain their supplied colors. Do not darken main cards as part of contrast or consistency fixes. PDF exports retain fixed brand teal with readable print colors, embedded Outfit and rendered bundled Phosphor glyphs.

## Savings details

Use the shared app theme without local palette overrides. Keep the goal name, linked account, and back navigation in a compact header. Show the linked account logo beside its name, falling back to the account icon when no image is available. Truncate long names safely and allow the goal title to wrap at larger text sizes.

Show total saved in a KoinSummaryCard with the savings pattern, 28px corners, 24px horizontal and 20px vertical padding, and the shared summary amount scale. Use white text throughout the main summary card, matching the dashboard hero. Retain actual target progress and remaining savings for goals with targets; omit target UI for open-ended savings.

Place Save, Release, Edit, and Delete in one row of circular surface buttons with labels below the main card, matching dashboard quick actions. Wrap them into two columns at large text sizes or on narrow screens. Disable release for empty savings and preserve linked-account balance warnings.

Use an open savings-plan section with the shared section header, muted edit action, and two columns for next contribution and projected total. Put muted labels above neutral amounts and scheduled dates below. Stack the metrics on narrow screens or at large text sizes. Offer plan setup with a short explanation when no plan exists.

Use a shared section heading for recent activity and flat rows for entries with subtle separators and no enclosing card. Use the transaction-list typography and small tinted circular direction icons. Keep entry dates, signed amounts, swipe deletion, manual editing, and expandable automatic-release explanations. Preserve loading, error, empty, and reduced-motion behavior.

For goals (not open-ended savings), keep the main summary card focused on the saved balance like the reference savings screen. Place target progress, deadline, saving pace, and schedule editing in an open Goal progress section below the action row. Show daily, weekly, and monthly rates without adding a separate Savings plan section. Completed goals show Target reached; goals without a deadline explain that a deadline is needed for pace estimates.

Text fields across routes, dialogs, and sheets clear focus on outside taps and when the software keyboard finishes closing. Keep field-to-field focus transfer and grouped input accessories working. Apply this behavior to both the main app and standalone quick entry.

Entity editors share UnsavedChangesGuard and the existing danger confirmation sheet for unsaved changes. Back, close, outside taps, and sheet dismissal must preserve the draft until Discard is confirmed; Cancel keeps every field. Unchanged or reverted drafts leave without a prompt. Successful saves leave directly, while pending saves block dismissal and failures retain the draft. Confirmation content scrolls when large text exceeds the available height.

Transient notifications use KoinSnackBar throughout the app. Keep short feedback content-sized, with a 48px minimum height, 12px corners, a small unboxed status icon, and a 360px maximum width. Center the icon vertically against the full text block, including subtitles and wrapped lines. Float near the bottom with clearance for navigation, save controls, system insets, and the keyboard; keep headers and tabs visible. Preserve full wrapping text for errors and subtitles, live announcements, reduced motion, swipe-down dismissal, and replacement of an earlier message. Keep the overlay above modal sheets so their errors remain visible. Opening a confirmation clears earlier feedback so it cannot cover the prompt or its actions.

## Account cards

Use the dashboard's compact account card across the dashboard, accounts grid, and create/edit previews: 16px corners, 16px horizontal and 12px vertical padding, a top row with a 24px logo beside a two-line name, and a 4px gap before the balance. Center the top-right eye on the name row as text scales. Keep the base card under 105px tall at normal text scale. Reserve the same name height on all cards; truncate unusually long names with an ellipsis. Keep the compact card and grid slot at the same height with or without linked savings. Put the in-savings breakdown in the balance tooltip and accessible description instead of an extra visible row; hide it together with a private balance. Keep the preview read-only. Place separate full-width Account name and Balance fields immediately below it, updating the preview live. Allow the name field to grow for long names. Keep bank foreground colors and background patterns consistent. Accounts use two columns, falling back to one on narrow screens or at large text sizes. Use a direct eye toggle in the top-right corner to hide or show it without adding a control row. Support press-and-hold dragging to rearrange accounts and swipe deletion. Center create/edit previews at the same grid-card width as dashboard and account cards, with editing handled by the labeled fields below. The dashboard's main balance eye controls only its summary visibility; each account card uses its own eye and saved account privacy state, shared with the Accounts screen.

The archive manager uses these same compact AccountItem cards and responsive grid, preserving bank logos, colors, patterns, balance formatting, and stored privacy. Keep the cards clear of repeated buttons or labels. Category entries reuse CategoryItem from Manage Categories, including its rounded surface, colored icon badge, name, and budget subtitle; omit the chevron and drag handle here. Explain the direct card action once above the list: tap to archive in the active view or restore in the archived view. Do not add a menu for a single choice; archiving opens its confirmation directly and restoring acts immediately. Show a small progress indicator only while saving an item.

## Savings overview

Use a balance-only summary and one Savings & goals list with one outlined Add savings / goal action beneath the last item, using the shared portfolio add button. Align item amounts with the right content inset. Distinguish item types in their compact subtitles and icons, without separate group headings or type badges. Keep current balances prominent and target progress visible. Show only a short cadence label for savings (Weekly savings, Monthly savings, or Every 2 weeks), without repeating contribution amounts; use Open-ended savings when no schedule exists. Keep contribution amounts and projections in details. Preserve item navigation and swipe deletion.

## Transaction history

Use open, flat day sections matching the activity rows in flutter_03.png. Keep date headings and daily totals on the page background, with no enclosing surface cards or header borders. Use small tinted category icons, bold signed amounts aligned with the title, and category, account, and time together underneath. Preserve search, filters, editing, swipe deletion, and reduced-motion behavior.

## Spending analysis

Keep spending primary within Koin's established teal, Outfit, patterned-card design. Keep the Activity & Flow header, tabs, spending card, period toolbar, chart, and category list on the shared KoinSpacing.screenInset (20px on both sides). Inset only Forecast by an additional 8px on each side (28px total), centering its content slightly inward from the surrounding sections.

Place the regular spending card directly after the Analysis/Transactions tabs. Match the dashboard's 24px horizontal and 20px vertical padding, shared summary typography, 12px gaps between the label, amount, and supporting text, full-width amount row, and top-right show/hide control beside the label. Use the shared balance-privacy preference and replace the comparison with a hidden-state message when spending is hidden. Put one compact comparison sentence below the amount. Preserve the bright teal card and white text; large totals must use the available width rather than a narrow column beside a cutout.

Use one joined period toolbar below the card: date navigation on the left and week/month/year choices on the right, separated by a subtle divider within one outlined surface. Keep dates on one line and shorten same-month week ranges. At narrow widths or large text sizes, stack the period choices above date navigation within the same surface.

Keep Forecast as a compact open row directly below the period toolbar and above the spending chart, inset 8px beyond the surrounding content. Put the explicit future horizon and Estimated balance label above the neutral 20px amount, with a muted Details action on the right. Omit a separate Forecast heading. Stack the action below the estimate on narrow widths or at large text sizes. The whole row and Details open the existing details sheet; keep shortfall warnings visible beneath the row and the estimation explanation in the sheet.

Place the chart below the compact forecast row, with a labeled action switching between Trend and Categories. Follow the chart with Top Categories as flat rows on the page background. Preserve category drilldowns, loading, error, empty, refresh, and reduced-motion behavior.

Category-list dividers appear only between rows in Top Categories and Active Budgets. Do not put a rule beneath the last item or a single-item list.

## Monthly budgets

Match Activity & Flow's plain screen header, shared 20px screen inset, and compact patterned teal summary card. Use 24px horizontal and 20px vertical card padding, the shared summary label and amount styles, a currency label, and the shared balance-privacy control. Show usage as a short sentence below the full-width amount instead of a circular gauge.

Place month navigation as plain text with previous/next arrows beneath the card, without a pill background or border. Keep the controls accessible, prevent navigation beyond the current month, and let the month label return to the current month. Keep navigation available when no budgets are configured.

Make Remaining the main teal card's label and large amount, using the shared summary typography. When overspent, show Over Budget and the amount exceeded. Show only the spent amount and percentage used in the wrapping sentence beneath the main amount, using the shared privacy preference. Keep the remaining or over-budget amount in the main figure only. Omit separate Spent and Monthly Budget footer metrics. Do not add a separate totals section, progress bar, or metric cards beneath the month switcher. Use flat active-budget rows with small tinted category icons, progress bars, and separators only between items, preserving editing and setup actions.

## Native quick entry

The short window opened from Android Quick Settings uses the same KoinFormTheme as the transaction editor, the shared page background throughout, 20px content insets, Outfit heading styles, and 28px sheet corners. Keep Add transaction as the primary teal action, with Claim income and Open app as compact shared action rows below. Use the app icon beside the opening title, grouped transaction-type choices with semantic icon colors, shared account/category selectors and keypad, and KoinPrimaryButton for saving. Preserve content-driven native window sizing, drag dismissal, draft handling, accessibility, and all transaction validation.

## First-run setup

Start new users in PHP · Philippine Peso unless a currency is already saved. Keep the centered Koin startup logo steady until account and transaction data are ready; do not insert a circular loading screen before the form. Startup progress appears only when initialization lasts beyond 400ms, without delaying a ready form.

Keep onboarding as one optional setup screen. Use a compact Koin logo/name row with a quiet Skip for now action, a clear introductory heading, and the existing explanatory copy. Group currency and account choices in one shared surface; allow selected names to wrap fully at large text sizes. Use open underlined name and balance inputs, persistent labels, and the shared prominent amount typography. Keep the savings explanation quiet and unboxed. Anchor Start tracking near the bottom on regular-height screens, and place it in the scrolling form when the keyboard, large text, or short landscape height needs the space. Preserve drafts through layout changes and keep initial balances separate from income.

## IOU creation

New “I am owed” records default to Lend money, with a required Source account directly below the choice control. Existing debt records an opening IOU without changing cash. Keep loan principal and repayments visible as Loan activity, separate from income, spending, and budget totals; repayments credit the selected receiving account. Editing an existing record must never repeat the original deduction.

Credit details use a compact summary with 24px horizontal and 16px vertical padding. Place the remaining balance directly below the name, with totals or billing context and repayment progress grouped beneath it. Keep the shared amount typography, fit long amounts on one line, and let repayment labels wrap at large text sizes.

## Account editor

Use one quiet “Swipe to browse” hint beside Templates. Avoid repeating instruction rows beneath each horizontal picker. Appearance carousels use the full screen width on phones and the centered 600px editor viewport on wider screens. Put the 20px content inset inside each horizontal scroll view so templates, icons, colors, backgrounds, and decoration previews clip at the viewport edge. Keep ordinary editor content capped at 560px.

Use open underlined name and balance inputs with persistent labels above, a 20px name and 28px balance, and live preview updates. Group Private account and Credit account in one quiet surface with a divider and native teal switches. Transfer fee has its own section with the shared Fixed amount / Percentage choice control, a labeled input with currency or percent units, and concise zero-fee guidance. Preserve account storage and validation.

Place functional account settings and transfer fees before the optional expandable Appearance section. Keep all templates, icons, colors, backgrounds, and patterns available there, preserving their state when collapsed. Cap the form at 560px and keep its preview at the actual account-grid card width. Rail-based main content is centered within 760px.

## Adaptive entry and privacy

Use a scrollable transaction form beside the keypad in short landscape windows when text scale allows it. At enlarged text sizes or other short layouts, let header, form, and keypad scroll together. Keep normal portrait entry compact. Planned-payment and income cards stack their amount, date, and full-width action when enlarged text or narrow widths need more room. Debt detail actions wrap into two columns under the same constraints. Interactive targets remain at least 48px while compact visuals may remain smaller.

Show Portfolio's section names beneath its existing selector so the other sections are visible without opening it. Keep the local-recovery/device-loss distinction and Export backup action visible in backup status. Budget editing explains that the same recurring category limit applies to past months.

Offer optional Android App protection in Settings using the existing device PIN, pattern, or password. Lock content after backgrounding and hide system previews/screenshots while protection is enabled. Preserve the mounted navigator and drafts behind the locked view. Keep this device-specific preference outside exported financial settings; use the same behavior in the main and Quick Entry engines.

## Audit follow-up behavior

Summary visibility also masks forecast amounts, including all monetary metrics and possible ranges in Forecast details. The user reviewed and confirmed this linked masking behavior. Keep per-account privacy and total-inclusion preferences separate. The forecast remains available even when spending history or the selected expense period is empty; keep its explicit future horizon visible.

Keep the phone bottom navigation icon-only, with equal-width destinations, a compact 58px bar, and no active-destination text. Preserve tooltips and screen-reader destination labels and selected state. At expanded widths (840px and above), use the labeled navigation rail. Retain the teal materials, Add transaction action, tab history, lazy pages, and inactive-page ticker suppression.

Report category/account options have at least 48px touch height and content-driven height for two-line labels, with one column on narrow windows or at large text sizes and a full-name tooltip. Stack report summary metrics and transaction-type choices when large text makes horizontal layouts cramped. Dashboard quick actions wrap into two rows under the same constraints.

Refresh date-dependent values at local midnight and on app resume. Budget and Analysis views that were following the current period advance; deliberately selected historical periods remain selected. Upcoming preserves loading/error states across its schedule and debt sources rather than substituting an empty list.

## Compact layouts — 30 October 2026

Use 20px between ordinary sections and 8px between section titles and content. Dashboard headings with 48px actions use 12px before the row and 4–8px after it; do not add trailing margins to the last upcoming or budget-preview item. Keep all interactive targets at least 48px. Shared heading actions use PressableScale for button semantics, keyboard activation, and focus indication.

Portfolio uses the 28px form-title role, with 12px top and 8px bottom header padding. Keep its section chooser and visible section hints. Compact account grids and account previews share AccountCardLayout.columnsFor: choose columns from the remaining name width after padding, avatar, and privacy control, including scaled text. Check 130% and 150% text sizes as well as 100% and 200%.

Income/payment cards use PortfolioCardStyle decoration and padding: the shared surface and subtle border, 24px corners, and 20px horizontal and 16px vertical padding. Center a compact 32px category badge vertically beside the details with a 12px gap; use an 18px icon and 10px badge corners. Give the 15px semibold title its own line. Put the signed shared 17px semibold amount 4px below, left-aligned, with 12px regular availability text flush right on the same row and at least 12px between them. Use semantic income/expense color for the amount. When their intrinsic widths exceed the available space, stack amount and availability left-aligned with a 2px gap. Put optional cadence and Automatic metadata 2px below in the same 12px regular style. Keep the details together without a separate divider or availability footer. Place a full-width filled teal button within the card content insets, 12px below the details, with shared 16px field corners. Use Collect income or Make payment with an 18px direction icon and the shared 14px choice label; show Unavailable when processing is disabled. Give the action a 48px minimum actual height and 16px horizontal and 12px vertical padding. Flexible schedules show Available anytime without a second FLEXIBLE/Availability explanation. Preserve edit, swipe deletion, scheduling, and confirmation/processing behavior. Category rows use a 56px minimum, 8px vertical padding, and 8px inter-row margin, growing with content. Budget rows use 12px vertical padding. Transaction date groups use 24px separation and 8px below date headers.

Settings uses a compact 48px app icon with name, version, and description instead of a large branding card. Main-screen end clearance follows the inherited actual Scaffold navigation/system inset plus 12px. Reports puts export actions in Scaffold.bottomNavigationBar with safe-area padding, so scrolling content never needs a guessed footer height.

Home charts and recent activity use the effective transaction clock. Weekly charts filter actual expenses to the current calendar week, including dates from the preceding month, and show a compact No spending this week state when empty. Future records remain available in transaction history but do not occupy Home's recent completed activity. Report presets and the initial report range share normalized inclusive calendar dates; 30d means 30 dates, including today.

Payment-sheet selectors and keypad fade in together over the existing 160ms feedback duration, without an entrance delay or positional slide. Preserve reduced-motion behavior and all money validation.


## Touch feedback

Use no expanding Android ink ripple. Material controls use a restrained accent-tinted pressed state; solid primary buttons use their contrasting foreground tint. Preserve hover and keyboard-focus feedback. Shared PressableScale actions compress to 97% over 100ms and settle over 140ms with easeOutCubic and no overshoot; reduced motion omits the scale. Local button foreground styling must also supply an accent overlay so it cannot reintroduce grey touch feedback.
