# Local model test results

Manual exploratory tests from 18–19 October 2026 (Asia/Manila).
These are a handful of observations, not a representative accuracy benchmark.
See [the development handoff](offline-ai-handoff.md).

## Models and execution

| Model | Observation | Limits of evidence |
| --- | --- | --- |
| Gemma 4 E2B IT | User downloaded it in Gallery and saw a memory warning | Successful generation was not recorded; warning is not proof it cannot run |
| Gemma 3 270M IT | User reported the Philippines-capital question answered "Brasilia" | Exact settings/backend of that run were not recorded; a corrected CPU retest was not established |
| Gemma 3 1B IT on GPU | Screenshot showed "Bangkok" for the Philippines-capital question | One incorrect example; not proof every GPU output is bad |
| Gemma 3 1B IT on CPU | Same question answered Manila; subsequent four prompts were tested directly | CPU is the working baseline; factual/financial reliability is not established |
| Qwen3 0.6B | Suggested as an alternative | Not downloaded or evaluated during this investigation |
| DeepSeek R1 Distill Qwen 1.5B | User saw it as a small catalog option | Not evaluated |

The user reported the Gemma 1B download as approximately 600 MB. The exact file,
checksum, quantization, Gallery version and sampling parameters were not captured.
Do not invent those details or treat file size as runtime memory usage.

The suggested imported 270M artifact was `gemma3-270m-it-q8.litertlm` from
[LiteRT Community](https://huggingface.co/litert-community/gemma-3-270m-it).
The suggested import configuration was CPU only with optional image, audio,
thinking, tiny-garden, mobile-action and speculative-decoding switches off.
Capability switches do not add capabilities to a model. The suggestion is not
proof of the exact settings used in the earlier failed 270M response.

The CPU/GPU difference on 1B suggests an execution/backend issue worth investigating;
it does not isolate whether drivers, runtime, precision, settings, or another factor
caused it. The earlier claim that model size alone explained the wrong capitals
was premature. Continue comparisons with controlled fresh chats and fixed settings.

## Four direct tests: Gemma 3 1B IT, CPU

Entered into AI Edge Gallery through wireless debugging, each in a new chat.
Wi-Fi remained connected. All data was synthetic. Times are Gallery's displayed
generation times, not full request or app-integration latency.

### 1. Extract a transaction

Prompt:

```text
Extract only amount, currency, and category from this transaction: I spent PHP 85 on lunch. Reply in one short line.
```

Response: `PHP85 Lunch` — 2.2 seconds.

Assessment: preserved amount/currency and meal description. It did not produce
structured JSON or map the category to a real Koin category ID. This is not yet
a verified transaction-extraction contract.

### 2. Calculate savings

Actual entered prompt (the phone keyboard changed "receive" to "received" before
submission; numeric inputs were checked):

```text
I received PHP 150 per school day and spend PHP 90 per school day. I attend school for 20 days this month. How much can I save this month? Answer briefly.
```

Response: `You can save PHP 600!` — 1.4 seconds.

Assessment: **incorrect**. Expected `(150 - 90) * 20 = PHP 1200`.

### 3. Ask about savings with missing expenses

Prompt:

```text
My school allowance is PHP 150 per day for 20 days. How much money can I save this month?
```

Response included `PHP 150 * 20 = PHP 3150` and asked about a savings goal and
existing savings — 6.0 seconds.

Assessment: **incorrect arithmetic** (expected allowance PHP 3000), and it did
not ask for expenses, which are necessary to estimate savings from allowance.
Missing-information handling must be enforced in app code.

### 4. Explain a precomputed result

Prompt:

```text
The app has calculated these verified figures: daily allowance PHP 150, daily spending PHP 90, school days 20, monthly savings PHP 1200. Explain the monthly savings in one sentence. Use the provided result without recalculating.
```

Response: `Monthly savings PHP 1200` — 1.2 seconds.

Assessment: preserved the supplied number, but the response was terse. One success
does not establish reliable numerical fidelity across generated explanations.

## Next evaluation

Record exact model filename/hash, runtime/Gallery version, CPU/backend, sampling
settings, prompt template and context/output limits before comparing runs.

Build a repeatable set covering:

- Expense vs income vs transfers; corrections and negations.
- English, Filipino and Taglish phrasing.
- PHP symbols/currency, decimals, zero/negative/implausible amounts.
- Existing category IDs and ambiguous categories requiring user choice.
- Missing expenses, allowance schedules and actual remaining school days.
- Correct deterministic savings calculations and explanations of supplied values.
- Month-end forecast assumptions and existing reservations/commitments.
- Invalid/malformed model output and safe fallback to manual entry.
- Fresh offline prompts after a cold app start; failure/loading/memory behavior.

Measure field accuracy, abstentions, incorrect auto-filled values, unsupported
claims, latency and memory. Define acceptance thresholds before enabling automatic
suggestions. Keep records synthetic or explicitly user-approved for testing.

Financial calculations, required-field decisions and ledger writes remain
deterministic. A language model is not needed to calculate a savings formula or
to replace Koin's existing transaction-history forecasting engine.
