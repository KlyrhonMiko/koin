# Koin polish resolution — 31 October 2026

This maps the [original inventory](polish-audit-2026-10-30.md) to the native app changes. The inventory preserves the historical before-state. No real financial records were edited.

| Audit IDs | Implemented refinement |
| --- | --- |
| 1 | Savings Helper parses the current currency input on Save, including grouped amounts. |
| 2–5 | Repayment, increase, budget, savings log, and scheduled confirmation sheets scroll within constrained height. Long keypad action labels stay on one line and fit within the key. |
| 6 | Upcoming uses adaptive activity rows with readable titles, amounts, and dates. |
| 7 | Repayment and confirmation protect drafts and block dismissal while saving. |
| 8–9 | Confirmation and purchase editing persist before closing; failures retain edits. |
| 10 | Savings details show loading, retry, or unavailable states instead of silently using the original goal. |
| 11 | Filter Clear has a 48px minimum target. |
| 12 | Joined choices measure scaled labels and stack when needed. |
| 13 | Debt cards adapt to large text; amounts remain complete with horizontal scrolling for long numbers. Savings names can wrap. |
| 14 | Entity names have persistent labels and readable hints. |
| 15 | Transaction/schedule validation reveals the missing input with contextual transfer requirements. Category validation focuses its name. |
| 16–17 | Account/category pickers preserve loading/errors, retry, and creation paths; shared choices and account cards expose selected state. |
| 18 | Account/category, currency/long radio lists, and speech-language options support search and keyboard clearance. |
| 19–20 | Voice controls have action labels; errors offer Retry or Enter manually. |
| 21 | Home explicitly labels Spending this week. |
| 22–24 | Monthly trend includes zero days, full-date tooltips, readable ticks, accessible summary, and date/value list. Trend/category footprints stay equal. |
| 25 | Shortfall guidance opens Upcoming. |
| 26–27 | Filters show dates/resolved names; search has a separate clear action and accurate scope hint. |
| 28 | Calculator guidance explains left-to-right evaluation. |
| 29–30 | Privacy explains its total-changing effect; credit mode explains balance meaning. |
| 31–32 | Automatic releases link to their transaction; Save prefills the plan contribution due. |
| 33–35 | Payment copy follows debt direction, uses shared currency formatting, distinguishes balance-only updates, and identifies occurrence/early recording. |
| 36–37 | Category type changes confirm budget removal; appearance is optional and Save is pinned. |
| 38–40 | Report categories follow type, all-selection is explicit, reset is available, and volume has an explanation and preview. |
| 41–42 | Passwords show rules, visibility, autofill, and keyboard actions. Import validates a separate copy before previewing counts/currency/latest activity. |
| 43–44 | Destructive settings have distinct scope labels; opening balance starts as an actual zero. |
| 45 | Secondary routes use bounded centered content. |
| 46 | Duplicate wrapper/callback haptics were removed in affected controls, transaction tiles, and account interactions. |
| 47 | Account reordering supports screen-reader actions and Alt+Up / Alt+Down on a focused card. |
| 48 | Repayment rows build lazily; purchases start at 20 rows with Show more. Existing installment allocation is preserved. |
| 49–50 | Archive choices say Active / Archived; secondary headings align left and affected actions use task-specific labels. |

See the [visual checklist](polish-visual-checklist-2026-10-31.md) for manual review order and device-only limits.

Verification: the final full Flutter suite passed all 824 tests, and Flutter static analysis reported no issues. Added coverage checks grouped/current savings amounts, payment failure retention and pending-save dismissal, repayment discard cancellation, ten constrained sheet layouts, calendar-complete trend values, filter touch targets, searchable pickers with keyboard and enlarged text, and raw/compressed/corrupt backup previews without changing their source or the live database. The existing forecast provider test now uses a fixed month-end clock rather than a wall-clock-dependent month-length assumption.

The final code review removed snapshot overrides from account/category pickers so privacy changes and newly created choices remain live. Voice and purchase editors resolve selected records from the current provider state. Two regression tests cover account privacy toggling and new account/category choices in the transaction editor.

After the full run, a final visual check found a truncated password-rule hint at 180% text. Allowing the hint to wrap passed all 63 affected tests/captures; the secondary matrix remained free of recorded layout and accessibility-guideline failures.
