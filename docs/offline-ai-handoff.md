# Offline AI investigation and development handoff

Last updated: 19 October 2026 (Asia/Manila).

## Resume here

The goal is an offline assistant for Koin that understands expense entry,
allowance/savings questions, and month-end forecast questions. Speech input is
also desired. Keep investigating Android AICore in the future; it has not been
abandoned or proven permanently incompatible.

Current status:

- **AICore / Gemini Nano:** blocked on the tested phone by model configuration
  and delivery errors, including in the official developer-preview build.
- **Independent local model:** Gemma 3 1B IT runs in Google AI Edge Gallery on
  CPU. The small manual test found incorrect arithmetic and missing-information
  handling. It is a candidate for evaluation, not a validated financial assistant.
- **Koin integration:** no AICore or LiteRT-LM integration has been implemented.
  Gallery is a separate test app, not a model service already connected to Koin.
- **Offline verification:** the AICore generation test failed while disconnected.
  The four Gemma 1B test prompts were sent with Wi-Fi connected; a successful
  airplane-mode run of that model has not been recorded.

Start by reading [the AICore investigation](aicore-investigation.md) and
[the model test results](offline-ai-test-results.md). A portable standalone
[AICore probe](../tools/aicore-probe/README.md) is included for future checks.
Model weights, APKs, credentials, wireless-debugging addresses and local SDK paths
are not included in this handoff.

## What the app should do

1. Interpret text such as "I spent PHP 85 on lunch" into a transaction draft.
2. Understand allowance and school-day scenarios and request missing inputs.
3. Explain forecasts based on recorded transactions and scheduled commitments.
4. Eventually transcribe speech, including evaluation of English, Filipino,
   and Taglish, before interpreting the resulting text.

Use deterministic app code for balances, arithmetic, dates, savings projections,
and forecasts. The language model can propose structured fields or a requested
operation and explain verified outputs. It must not invent transactions, decide
unknown expenses, or write financial records without user review.

For example, with PHP 150 daily allowance, PHP 90 daily expenses, and 20 school
days, code computes `(150 - 90) * 20 = PHP 1200`. If expenses are missing, the
app asks for them; total allowance is not automatically available savings.

## Existing Koin implementation to reuse

The repository already has local forecasting, categorization, transaction entry,
and speech-input plumbing. Inspect current sources before adding another engine:

| Area | Sources / documentation |
| --- | --- |
| Financial forecast | [cashflow_forecaster.dart](../lib/core/forecasting/cashflow_forecaster.dart), [forecast_provider.dart](../lib/core/providers/forecast_provider.dart), [forecasting.md](forecasting.md) |
| Category suggestions | [categorization_engine.dart](../lib/core/categorization/categorization_engine.dart), [category_suggester.dart](../lib/core/categorization/category_suggester.dart), [categorization.md](categorization.md) |
| Voice parsing | [voice_command_parser.dart](../lib/core/categorization/voice_command_parser.dart), [intent_classifier.dart](../lib/core/categorization/intent_classifier.dart) |
| Speech recognition | [voice_input_provider.dart](../lib/core/providers/voice_input_provider.dart), [voice_input_sheet.dart](../lib/features/transactions/widgets/voice_input_sheet.dart) |
| Transaction entry | [add_transaction_screen.dart](../lib/features/transactions/add_transaction_screen.dart), [transaction_provider.dart](../lib/core/providers/transaction_provider.dart) |
| Savings semantics | [savings.md](savings.md), [savings_plan.dart](../lib/core/models/savings/savings_plan.dart), [savings_projection.dart](../lib/core/models/savings/savings_projection.dart) |
| Existing regression tests | `test/voice_command_parser_test.dart`, `test/categorization_history_test.dart`, `test/forecast_accuracy_test.dart`, `test/forecast_cold_start_test.dart`, `test/savings_projection_test.dart` |

At handoff, `pubspec.yaml` uses `speech_to_text: ^7.5.0`. The voice provider calls
the platform recognizer and chooses a Philippine English / Filipino locale when
available. This does **not** establish offline speech support. The inspected
listen options do not explicitly request on-device recognition. Audio support
must be evaluated separately from the text model, on each target device/locale.

## Proposed implementation sequence — not implemented

1. Verify Gemma 3 1B on CPU with fresh prompts while airplane mode is enabled
   and Wi-Fi/mobile data are off. Record exact model artifact, Gallery version,
   generation settings, latency, and failures.
2. Build a small evaluation set of 20–30 representative expense and savings
   prompts before selecting a production model. Include Taglish, corrections,
   missing amounts, ambiguous categories, decimal amounts, and invalid dates.
3. Define a narrow structured-output contract for expense drafts and questions.
   Validate amounts, currency, category IDs, dates, operation names and missing
   fields in app code. Reject malformed output and keep manual entry available.
4. Add a replaceable local-inference boundary. Evaluate LiteRT-LM as one backend;
   keep AICore as a future alternative behind capability checks. AICore checks
   should distinguish unavailable, downloadable, downloading, available, and
   errors. Do not make app startup depend on a model being present.
5. Implement one reviewed expense-entry flow first. Keep the existing category
   suggestion engine and ledger rules authoritative; do not silently replace
   current behavior with unvalidated model output.
6. Route forecast questions to existing forecast logic. Show assumptions,
   limited-history caveats, and the difference between allowance, balance,
   available funds and money reserved for savings. Reuse current savings semantics.
7. Add model explanations only after calculations. Check that all numbers in
   generated explanations match computed results; deterministic wording is a
   fallback if the model changes them.
8. Evaluate speech separately, then reuse the same text-to-draft path. Confirm
   recognized money amounts before saving. Test offline English/Filipino/Taglish
   rather than assuming platform speech recognition remains available offline.

Model file download size is not peak runtime memory. Record CPU/GPU backend,
context limits, output limits and app/device memory pressure. Start from the
CPU baseline that worked; GPU compatibility on this phone remains unresolved.
Do not assume a model downloaded into Gallery is accessible to Koin. Model
distribution, license acceptance, storage, download/cleanup behavior, and runtime
integration need their own implementation.

## Continuing on another computer or phone

- Commit these documents and `tools/aicore-probe/`; the old `build/aicore-check/`
  folder is ignored and is not the portable source of truth.
- Follow [README development setup](../README.md#development), including the
  compatible Flutter SDK. Do not commit `android/local.properties` or other
  machine-specific SDK paths.
- Pair wireless debugging afresh when needed. Discover the current connection
  port; pairing and connection ports differ and can change. No old phone IP,
  serial, or pairing code is required by this handoff.
- On a different phone, record its own results rather than inheriting the POCO's
  AICore failure or CPU/GPU conclusion.
- Recheck current official SDK versions and supported-device lists before a new
  AICore attempt. The versions in this handoff describe the investigation, not
  a permanent recommendation.

Suggested continuation request:

> Read docs/offline-ai-handoff.md, docs/aicore-investigation.md, and
> docs/offline-ai-test-results.md. Continue the offline assistant investigation
> for Koin. Keep AICore as an open future option. First confirm the connected
> device, exact model/backend, and a fresh offline-generation result. Then
> evaluate structured transaction extraction and reuse Koin's deterministic
> calculations and forecasts. Do not treat the current Gallery demo as an
> existing app integration or assume the model's arithmetic is reliable.

## Primary references

- [ML Kit GenAI overview and device support](https://developers.google.com/ml-kit/genai)
- [Prompt API setup and common failures](https://developers.google.com/ml-kit/genai/prompt/android/get-started)
- [AICore Developer Preview](https://developers.google.com/ml-kit/genai/aicore-dev-preview)
- [LiteRT-LM overview](https://developers.google.com/edge/litert-lm/overview)
- [AI Edge Gallery](https://github.com/google-ai-edge/gallery)
- [Importing local models into Gallery](https://github.com/google-ai-edge/gallery/wiki/6.-Importing-Local-Models-%28optional%29)
