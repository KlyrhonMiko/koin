# Koin polish visual checklist — 31 October 2026

This pass covers the native Flutter app in `D:/projects/koin`. Preserve Outfit typography, teal, patterned summaries, and icon-only phone navigation when reviewing.

Start on your normal phone in light and dark mode. Repeat entry sheets with the keyboard open, in landscape, and at enlarged system text. Check 130%, 150%, 180%, and 200% text, plus a tablet or wide window. Controls should remain reachable by scrolling, labels should remain readable, and amounts should stay together.

| Order | Screen | Visually check |
| --- | --- | --- |
| 1 | Credit → repayment / increase balance | Amount, account, note, keypad, Confirm payment / Confirm increase. Check small landscape and large text. Edit a note, press Back, then Cancel the discard prompt. |
| 2 | Planned payments / recurring income → confirmation | Scheduled date, early-recording explanation, selectors, amount, and confirm action. Back protects edits; saving retains the sheet until completion. |
| 3 | Budgets → edit budget | Fixed and percentage modes, fields, keypad, and Save with keyboard and large text. |
| 4 | Savings details → Save / Release | Amount, explanation, keypad, and Save on short screens. With a plan, Save starts with the currently due contribution. |
| 5 | Savings Helper | Enter `1,000`, inspect the preview, and save. Change the amount repeatedly before saving. |
| 6 | Home → Upcoming | Long titles, dates, due metadata, and signed amounts at large text. Open an item and verify the destination. |
| 7 | Credit → purchase create / edit | Scrolling, category selection, save progress, failure feedback, and draft retention. |
| 8 | Activity → Analysis | Week/month/year trends, zero-spending days, full-date tooltips, ticks, and View amounts. Repeatedly switch Trend / Categories; the card must not jump in height. |
| 9 | Forecast details | Warning explanation and View upcoming action. Summary privacy still masks monetary values. |
| 10 | Transaction history | Search scope, clear-query icon, named filters, actual date ranges, and Clear action. Clearing search preserves other filters. |
| 11 | Add / edit transaction; Quick Entry | Expense, income, transfer, destination, and fee. Missing-field submission reveals the correct input. Check calculator guidance. |
| 12 | Account / category pickers | Search, selected indication, no matches, empty-state creation, loading/error retry, keyboard clearance, and long names. |
| 13 | Portfolio → Accounts | Cards, privacy eye, totals explanation, ordering, and screen-reader/keyboard Move before / Move after actions. |
| 14 | Add / edit account | Persistent labels, credit explanation, privacy helper, interest fields, appearance, and Save. |
| 15 | Savings list / details | Long names, loading/error/unavailable states, summary/actions, contribution due, and automatic release → View transaction. |
| 16 | Credit list / details | Long names, complete remaining/original amounts, debt-direction wording, balance-only feedback, long repayment history, and Show more after 20 purchases. |
| 17 | Planned payment / income editor | Persistent name label, required-field errors, account/category, and adaptive joined choices. |
| 18 | Manage categories → create / edit | Pinned Create category / Save changes, Appearance disclosure, and budget-loss warning when switching expense to income. Cancel retains the budget. |
| 19 | Custom reports | All-selection wording, compatible categories, reset/date reset, Total volume explanation, preview rows, and export footer. |
| 20 | Settings | Left-aligned header, bounded wide layout, currency search, speech-language search, and distinct destructive-action titles. |
| 21 | Settings → backup password / import | Password rule, show/hide, confirmation, keyboard actions, and validation. Import unlocks/validates before showing filename, counts, currency, latest activity, and replacement confirmation. Use disposable data for an actual restore. |
| 22 | Settings → archive manager | Active / Archived exclusive choices, account/category cards, archive confirmation, and restore feedback. |
| 23 | Voice entry | Listening/processing action labels, Retry and Enter manually on error, and review form. Test actual microphone permission denial/retry on a device. |
| 24 | First-run setup | Visible zero is a valid starting balance; labels/action remain readable with the keyboard. |
| 25 | Wide routes | Settings, savings details, credit details, and category editor remain centered at their intended content widths. |

The widget-render matrices covered 185 states across phone light/dark, 180% text, landscape, and tablet sizes, with no recorded layout exceptions, tap-target failures, or missing tap labels. Some currency/icon glyphs render as fallback boxes in the harness; check actual glyphs in the installed app.

No Android device was attached. Native keyboard transitions, physical haptics, predictive Back, microphone permissions, device authentication, native file selection, and actual export/import still need device checks. Regression tests cover draft/save behavior, constrained sheets, chart dates, search keyboard layouts, and backup preview integrity.
