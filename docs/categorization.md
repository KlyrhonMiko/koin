# Local category suggestions

Categorization remains on-device. It learns from saved transaction labels and
explicit corrections. The model rebuilds after history, accounts, or categories
change; model version 3 rebuilds older dictionaries with the new normalization.
Explicit feedback is replayed after ledger history so corrections take precedence.

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
categories take precedence. Debounced requests discard results after cancellation,
disposal, or replacement; callers also validate their current context.

These are conservative heuristics, not measured precision guarantees. Threshold
changes or model replacements should be evaluated on chronologically held-out,
user-reviewed labels, reporting automatic-assignment precision, suggestion
coverage, and correction rates. Repeated words, multiple accounts, Unicode notes,
explicit corrections, sparse evidence, and stale requests have regression tests.
