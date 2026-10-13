# Koin interface

The established app uses Outfit, teal accents, light and dark theme tokens, Material icons, patterned summary cards, and rounded grouped surfaces. Use shared components across savings surfaces.

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
