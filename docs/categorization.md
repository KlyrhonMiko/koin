# Local category suggestions

Categorization remains on-device. It learns from saved transaction labels and
explicit corrections. The model rebuilds after history, accounts, or categories
change; model version 4 aggregates history in memory and writes a batch. SQLite
schema version 41 adds indexed, cached exact-match evidence and feedback snapshots.
Exact matches no longer scan all transactions and feedback on each keystroke.

Exact history selects the category with the most matching examples. Recency only
breaks ties. Explicit manual feedback takes precedence over history that existed
when it was recorded. A later conflicting matching transaction or an edit/deletion
of its matching history expires the remembered choice. Legacy feedback without a
snapshot remains ordinary evidence, without a privileged automatic override.

Exact matching and word matching now share a normalizer that lowercases text,
retains Unicode letters, marks, and digits, and turns punctuation into spaces.
Short names such as SM are retained. Each word contributes once per training
note, so repeated words cannot simulate multiple examples.

Category word evidence combines all accounts for a destination category. The
selected account is preserved independently. Class priors count examples;
word likelihood denominators count words. Only destinations compatible with
the selected transaction type compete. Transfer hints cannot change an income
or expense form into a transfer; amount/date pairing remains a suggestion and
never automatically applies a transfer.

The returned confidence is an evidence score, not a calibrated probability:

- Exact history: `(supporting examples + 1) / (matching examples + 2)`.
  Automatic application requires at least three supporting examples and at
  least 90% agreement. Explicit remembered feedback can apply directly with a
  score of 0.95; a history match is never declared 100% certain.
- Word matching: normalized ranking score multiplied by word coverage and
  `support / (support + 2)`. Support is the minimum occurrence count among
  shared words for the winning category. A single matching class is no longer
  reported as certain. Ambiguous rankings below 0.70 abstain; automatic
  application also needs at least three supporting examples, a ranking score of
  at least 0.90, and word coverage of at least 75%.

The transaction editor displays weaker category suggestions as an explicit
“Use suggested category” action. Quick Entry, debt, purchase, scheduled-payment,
and voice forms only auto-fill suggestions with sufficient evidence. User-picked
categories take precedence. Debt, purchase, and scheduled-payment forms clear
automatic categories when their descriptions change. Saving an automatic category
does not record explicit feedback. Manual corrections in the transaction editor
and Quick Entry are remembered after their transactions are saved. Purchase sheets
return manual choices to their
parent; learning occurs only after the debt or purchase has been saved successfully.

Voice accepts only an unambiguous, whole category name compatible with the parsed
transaction type. Other inference goes through the shared suggestion engine.
Spending phrases such as "paid for" remain expenses; receiving phrases such as
"got paid" indicate income. Type switches can clear incompatible parsed categories.

Debounced requests discard results after cancellation,
disposal, or replacement; callers also validate their current context.

These are conservative heuristics, not measured precision guarantees. Threshold
changes or model replacements should be evaluated on chronologically held-out,
user-reviewed labels, reporting automatic-assignment precision, suggestion
coverage, and correction rates. Repeated words, multiple accounts, Unicode notes,
explicit corrections, sparse evidence, and stale requests have regression tests.
