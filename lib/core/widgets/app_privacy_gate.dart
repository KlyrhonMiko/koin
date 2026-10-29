import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/device_privacy.dart';
import 'primitives/koin_primary_button.dart';

/// Keep the navigator mounted so locking never discards an open draft.
class AppPrivacyGate extends ConsumerStatefulWidget {
  const AppPrivacyGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppPrivacyGate> createState() => _AppPrivacyGateState();
}

class _AppPrivacyGateState extends ConsumerState<AppPrivacyGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  String? _error;
  late final DevicePrivacy _privacy;

  @override
  void initState() {
    super.initState();
    _privacy = ref.read(devicePrivacyProvider);
    WidgetsBinding.instance.addObserver(this);
    if (_privacy.supported) {
      DevicePrivacy.channel.setMethodCallHandler(_nativeProtectionChanged);
    }
    _locked = ref.read(settingsProvider).appProtectionEnabled;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_locked) {
        await _unlock();
      } else {
        await _syncProtection();
      }
    });
  }

  Future<void> _nativeProtectionChanged(MethodCall call) async {
    if (!mounted || call.method != 'protectionChanged') return;
    final privacy = ref.read(devicePrivacyProvider);
    if (call.arguments == true && !privacy.authenticated) {
      setState(() => _locked = true);
    }
    await _reloadSettings();
  }

  Future<void> _syncProtection() async {
    final privacy = ref.read(devicePrivacyProvider);
    if (!privacy.supported) return;
    try {
      await privacy.setProtected(
        ref.read(settingsProvider).appProtectionEnabled,
      );
    } catch (_) {
      if (mounted && _locked) {
        setState(
          () => _error = 'Could not enable screen protection. Try again.',
        );
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      await _privacy.setProtected(true);
      final accepted = await _privacy.authenticate();
      _privacy.authenticated = accepted;
      if (mounted) {
        setState(() {
          _locked = !accepted;
          if (!accepted) _error = 'Koin stays locked. Unlock to continue.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not unlock Koin. Check your device screen lock and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final privacy = ref.read(devicePrivacyProvider);
    if (!_authenticating &&
        !privacy.authenticating &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      privacy.authenticated = false;
      if (ref.read(settingsProvider).appProtectionEnabled) {
        setState(() => _locked = true);
      }
    }
    if (state == AppLifecycleState.resumed) _reloadSettings();
  }

  Future<void> _reloadSettings() async {
    try {
      await ref.read(sharedPreferencesProvider).reload();
      if (mounted) ref.invalidate(settingsProvider);
    } catch (_) {
      // Remain locked if settings cannot be refreshed after a second engine ran.
    }
  }

  @override
  void dispose() {
    if (_privacy.supported) {
      DevicePrivacy.channel.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((settings) => settings.appProtectionEnabled),
      (previous, enabled) {
        final locked =
            enabled && !ref.read(devicePrivacyProvider).authenticated;
        if (_locked != locked) setState(() => _locked = locked);
        _syncProtection();
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _locked,
          child: Offstage(
            offstage: _locked,
            child: TickerMode(enabled: !_locked, child: widget.child),
          ),
        ),
        if (_locked)
          Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Koin is locked',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error ?? 'Use your device PIN, pattern or password to continue.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        KoinPrimaryButton(
                          label: 'Unlock',
                          isLoading: _authenticating,
                          onPressed: _unlock,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
