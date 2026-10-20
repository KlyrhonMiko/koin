# AICore investigation — open for future retesting

Observed 18–19 October 2026 (Asia/Manila). See
[the handoff](offline-ai-handoff.md) for implementation plans and
[the portable probe](../tools/aicore-probe/README.md) for retesting.

## Device and observed versions

| Item | Recorded value |
| --- | --- |
| Phone | POCO X7 Pro; model `2412DPC0AG`; device `rodin` |
| Android | 16 / API 36 |
| Boot state | Locked bootloader, verified boot `green`, `user` / `release-keys` |
| AICore hardware declarations | `com.google.android.feature.AICORE_MT`, `com.google.android.feature.AICORE_MT_MT6899` |
| Free storage | Approximately 97 GB during investigation |
| Reported total memory | Approximately 7.1 GiB available to Android (`MemTotal: 7483628 kB`); not free app memory |
| Original AICore | `526934`, `0.release.mediatek.prod_aicore_20260917.00_RC01` |
| Updated AICore | `529204`, `0.thirdpartyexperimental.mediatek.ffdf_aicore_20260917.00_RC08` |
| Google Play services | `26.40.32 (260400-995630914)` |
| ML Kit tested | `com.google.mlkit:genai-prompt:1.0.0-beta4` and `1.0.0-beta2` |

Google's device list included POCO X7 Pro at investigation time. Being listed
and having AICore installed did not establish usable model delivery on this
particular phone. Hardware incompatibility has not been established either.

## Reproduced failures

- AICore installed, enabled, and reachable from the standalone diagnostic app.
- Production/default Prompt API check returned `UNAVAILABLE`.
- After the preview update, default and all four explicit combinations returned
  `UNAVAILABLE`: stable/full, stable/fast, preview/full, preview/fast.
- The user opened the updated preview app and reported an empty model list with
  no offered download. Exact account enrollment/terms state was not independently
  inspected.
- The offline test recorded zero networks advertising internet capability before
  submitting a fresh prompt. Generation failed with:

```text
606-FEATURE_NOT_FOUND: Feature 636 is not available.
```

AICore's own process logged:

```text
Failed to fetch manifest config from source for
com.google.android.aicore:18103149225492435673
INVALID_ARGUMENT: Request contains an invalid argument.
Initialization failed, but within backoff period.
```

After queued download/maintenance work was forced to run, another message was:

```text
Required labels are missing from the protected download manifest labels proto.
Download will not be triggered.
```

There were also intermittent DNS-resolution failures for
`ondevicesafety-pa.googleapis.com`. A later DNS lookup and ping from the phone
succeeded; subsequent configuration attempts still returned `INVALID_ARGUMENT`.
Background data restriction was disabled and Android reported validated Wi-Fi.
These checks do not prove all AICore requests were healthy or identify which
component supplied invalid configuration data.

## Attempted and not attempted

| Attempt | Result |
| --- | --- |
| Restart and leave online | User had already tried; no availability change |
| Check production update | No update initially offered |
| Install official developer-preview update | Version changed; empty list / unavailable persisted |
| Restart AICore process and diagnostic | Same manifest error |
| Run existing AICore maintenance, data-update and Wi-Fi download jobs | Jobs accepted; models remained unavailable |
| Earlier ML Kit beta2 workaround | Default check threw 606 / feature 636 unavailable |
| Give diagnostic normal internet permission | Same failure; its initial no-internet-permission build was not the only test |
| Cache-only cleanup | Command did not return and was interrupted; completion unconfirmed |
| Full AICore storage reset | **Not performed** |
| Factory reset, firmware changes, root, model sideload into AICore | **Not performed** |

The earlier-SDK experiment came from
[ML Kit issue #1061](https://github.com/googlesamples/mlkit/issues/1061), which
reports availability regressions on other devices/feature IDs. It did not solve
this phone's failure and is not established as the same underlying bug.

## Interpretation and next AICore check

The failure occurs during configuration/model delivery, before successful
inference. An app, firmware, request-eligibility, or service-side problem is
possible. The logs do not prove a server rollout restriction, device-attestation
failure, permanent hardware limitation, or a specific fix.

On a future attempt:

1. Record current device/OS, boot state, AICore version/channel, SDK version,
   account setup, and exact observation date. Recheck official device support.
2. Confirm the official AICore app initializes and its model picker offers models.
   If downloadable, finish the model download online before testing offline.
3. Run the probe's status checks for default and explicit model configurations.
4. If initialization fails, capture **fresh** AICore-process logs, including nested
   causes. Do not infer a new attempt's outcome from old log lines or the probe's
   appended results file.
5. If available, verify a short online inference, then a new prompt while airplane
   mode is on and Wi-Fi/mobile data are off. Restore wireless debugging afterward
   and read the saved result. A successful status check alone is insufficient.
6. If trying a storage reset, explain that AICore settings/downloads may be removed
   and setup/terms/downloads may need repeating. This is an unverified experiment,
   not an established fix. Do not clear Google Play services, other app data, or
   reset the phone as a routine continuation step.

Do not reuse the old scheduled job IDs or debugging port. Both are ephemeral.
Discover AICore's current jobs and use only relevant work if investigating the
scheduler again. Do not repeatedly rerun identical failing checks without a new
version, configuration change, or other reason to expect a different result.

Keep this path open even if a separate local model is used for the first Koin
prototype. Future availability should be detected at runtime rather than assumed.
