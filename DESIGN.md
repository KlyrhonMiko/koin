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
