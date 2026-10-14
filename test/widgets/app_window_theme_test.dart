import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/app_window_theme.dart';

void main() {
  const channel = MethodChannel('koin/window_theme');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'native window follows app theme even when system is light',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      final mode = ValueNotifier(ThemeMode.dark);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, themeMode, child) => MaterialApp(
            theme: AppTheme.getTheme(Colors.teal, false),
            darkTheme: AppTheme.getTheme(Colors.teal, true),
            themeMode: themeMode,
            themeAnimationDuration: Duration.zero,
            builder: (context, child) => AppWindowTheme(child: child!),
            home: const Scaffold(),
          ),
        ),
      );
      await tester.pump();
      expect(calls.last.method, 'setTheme');
      expect(calls.last.arguments, {
        'backgroundColor': const Color(0xFF171A1C).toARGB32(),
        'dark': true,
      });

      mode.value = ThemeMode.light;
      await tester.pumpAndSettle();
      expect(calls.last.arguments, {
        'backgroundColor': const Color(0xFFF8F9FA).toARGB32(),
        'dark': false,
      });

      final count = calls.length;
      await tester.pump();
      expect(calls, hasLength(count));
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'older native builds can open without window theme bridge',
    (tester) async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw MissingPluginException();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => AppWindowTheme(child: child!),
          home: const Scaffold(body: Text('Ready')),
        ),
      );
      await tester.pump();
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
