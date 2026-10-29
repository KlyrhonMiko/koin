import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/services/device_privacy.dart';
import 'package:koin/core/widgets/app_privacy_gate.dart';

class _Privacy extends DevicePrivacy {
  final protection = <bool>[];
  var unlock = Completer<bool>();
  bool failProtection = false;
  @override
  bool get supported => true;
  @override
  Future<bool> authenticate() => unlock.future;
  @override
  Future<void> setProtected(bool enabled) async {
    if (failProtection) throw PlatformException(code: 'unavailable');
    protection.add(enabled);
  }
}

void main() {
  Future<ProviderContainer> setup(
    _Privacy privacy, {
    bool enabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({'app_protection_enabled': enabled});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        devicePrivacyProvider.overrideWithValue(privacy),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer c,
    Widget child,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          builder: (context, child) => AppPrivacyGate(child: child!),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('denied device authentication keeps financial content hidden', (
    tester,
  ) async {
    final privacy = _Privacy();
    final c = await setup(privacy);
    await open(tester, c, const Text('Private financial content'));
    expect(find.text('Private financial content'), findsNothing);
    privacy.unlock.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Koin is locked'), findsOneWidget);
    expect(find.text('Private financial content'), findsNothing);
    expect(privacy.protection, contains(true));
    privacy.unlock = Completer<bool>()..complete(true);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Private financial content'), findsOneWidget);
  });

  testWidgets('background locking preserves the open draft', (tester) async {
    final privacy = _Privacy()..unlock.complete(true);
    final c = await setup(privacy);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await open(tester, c, TextField(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved draft');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Koin is locked'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    privacy.unlock = Completer<bool>()..complete(true);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Unsaved draft');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('protection failures keep the app locked', (tester) async {
    final privacy = _Privacy()..failProtection = true;
    final c = await setup(privacy);
    await open(tester, c, const Text('Private financial content'));
    await tester.pumpAndSettle();
    expect(find.text('Koin is locked'), findsOneWidget);
    expect(find.text('Private financial content'), findsNothing);
    expect(find.textContaining('Could not unlock Koin'), findsOneWidget);
  });

  testWidgets(
    'native protection notification masks another active engine immediately',
    (tester) async {
      final c = await setup(_Privacy(), enabled: false);
      await open(tester, c, const Text('Private financial content'));
      final handled = Completer<void>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            DevicePrivacy.channel.name,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('protectionChanged', true),
            ),
            (_) => handled.complete(),
          );
      await handled.future;
      await tester.pumpAndSettle();
      expect(find.text('Private financial content'), findsNothing);
      expect(find.text('Koin is locked'), findsOneWidget);
    },
  );

  test(
    'device protection stays local and is preserved across other settings',
    () async {
      final c = await setup(_Privacy(), enabled: false);
      await c.read(settingsProvider.notifier).setAppProtection(true);
      await c.read(settingsProvider.notifier).setHapticsEnabled(false);
      expect(c.read(settingsProvider).appProtectionEnabled, isTrue);
      final snapshot = SettingsSnapshot.capture(
        c.read(sharedPreferencesProvider),
      );
      expect(snapshot.containsKey('app_protection_enabled'), isFalse);
    },
  );

  testWidgets(
    'protection enabled by another engine locks an unauthenticated session',
    (tester) async {
      final privacy = _Privacy();
      final c = await setup(privacy, enabled: false);
      await open(tester, c, const Text('Private financial content'));
      expect(find.text('Private financial content'), findsOneWidget);
      await c
          .read(sharedPreferencesProvider)
          .setBool('app_protection_enabled', true);
      c.invalidate(settingsProvider);
      await tester.pumpAndSettle();
      expect(find.text('Private financial content'), findsNothing);
      expect(find.text('Koin is locked'), findsOneWidget);
    },
  );
}
