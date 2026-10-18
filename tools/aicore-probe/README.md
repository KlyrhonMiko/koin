# Standalone AICore probe

Portable source of the diagnostic used in the investigation. This is a separate
Android application (`dev.local.aicorecheck`), not a Koin integration. See
[the investigation](../../docs/aicore-investigation.md) for the observed results.

The project uses Android Gradle Plugin 9.0.1 and the repository's Gradle wrapper
(9.1.0 at handoff), compile/target SDK 36, min SDK 26, and ML Kit Prompt beta4.
These reproduce the investigation; recheck current Google guidance before using
the probe to evaluate a newly released API. The earlier beta2 experiment required
changing the one dependency and rebuilding; beta2 can throw an exception at the
default check, so the probe's later configuration checks may not run on that SDK.

## Build on another computer

Install JDK 17 or newer compatible with the pinned Android Gradle plugin
(JDK 21 was used), Android SDK platform 36 and platform-tools. Create an untracked
`local.properties` in this directory containing your SDK path. Forward slashes
avoid Windows properties-file escaping, for example:

```properties
sdk.dir=C:/path/to/Android/Sdk
```

From the repository root, build using its existing wrapper:

```powershell
.\android\gradlew.bat -p tools/aicore-probe assembleDebug --console=plain
```

On Linux/macOS, use `bash android/gradlew -p tools/aicore-probe assembleDebug`.
Do not copy `local.properties`, Gradle caches, generated builds or model weights
between machines via Git.

## Connect and run

Use USB debugging or Android wireless debugging. Pair the computer on the phone
first when needed. Run `adb mdns services` and `adb devices -l` to discover the
current service; do not reuse old pairing codes, IPs or ports from another session.
The pairing-screen port differs from the normal connection port.

Set `$deviceId` to an actual connected identifier from `adb devices -l`, then:

```powershell
adb -s $deviceId install -r tools/aicore-probe/app/build/outputs/apk/debug/app-debug.apk
adb -s $deviceId shell am force-stop dev.local.aicorecheck
adb -s $deviceId shell am start -n dev.local.aicorecheck/.MainActivity
adb -s $deviceId shell run-as dev.local.aicorecheck cat files/results.txt
```

The probe checks the default client. When default is available it gets the model
name and asks `What is 17 plus 25? Answer with just the number.` It then checks
stable/full, stable/fast, preview/full and preview/fast configurations. The first
available explicit configuration is kept for the offline button during that run.
The probe does not initiate model downloads; downloadable status is distinct from
available status. Finish downloads through AICore or add the documented download
flow in a future diagnostic revision.

Results are appended to an app-private file. Inspect the **latest** run after
waiting for `DONE` or an error; old failures remain in the file across reinstalls.
Response objects are logged with `toString()` rather than an enforced structured
schema. Read the actual text before deciding correctness.

## Offline button

After confirming availability online:

1. Keep the probe in the foreground. It is deliberately a basic diagnostic UI.
2. Turn on airplane mode and turn Wi-Fi off. Wireless debugging will disconnect.
3. Return to the probe and tap **Run offline test**.
4. It checks that no Android network advertises internet capability, submits a
   fresh arithmetic prompt, and saves the response or error locally.
5. Restore connectivity and wireless debugging, discover the current port, and
   read `files/results.txt` again.

`OFFLINE_TEST_PASSED` means the API returned a response with no internet-capable
network detected at the initial check. It does not grade the response's arithmetic
or monitor connectivity throughout the entire inference. Keep the phone offline
until completion, verify the answer, and record observed settings. The manifest
has normal internet permission for setup; the button's network check and the
physical disconnection are what distinguish the offline run.

Never disable the phone's network remotely without arranging reconnection. The
probe's status and generation calls can take time; repeated button presses are
disabled during the offline request, but this is not a production lifecycle or
concurrency implementation.

## Service logs

Read the current AICore PID with:

```powershell
adb -s $deviceId shell pidof com.google.android.aicore
```

Use that observed PID with `adb -s $deviceId logcat -d --pid=<PID>`, inspect fresh
timestamps and nested causes, and redact personal information before sharing.
Do not clear the entire device log or reset unrelated system services merely
to collect a diagnostic. Package names, dependency versions and error IDs are
more useful in a report than pairing credentials or device serial numbers.
