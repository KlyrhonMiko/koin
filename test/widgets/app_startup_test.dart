import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/app_startup.dart';

void main() {
  const readyApp = MaterialApp(home: Scaffold(body: Text('Ready')));

  testWidgets('draws loading UI before initialization and opens when ready', (
    tester,
  ) async {
    final initialization = Completer<Widget>();
    var calls = 0;
    var hadFirstFrame = false;
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          calls++;
          hadFirstFrame = find
              .byType(LinearProgressIndicator)
              .evaluate()
              .isNotEmpty;
          return initialization.future;
        },
      ),
    );

    expect(hadFirstFrame, isTrue);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1);

    initialization.complete(readyApp);
    await tester.pump();
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('offers recovery when initialization fails', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          calls++;
          if (calls == 1) throw StateError('Initialization failed');
          return readyApp;
        },
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Ready'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('startup follows system $brightness', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final initialization = Completer<Widget>();
      await tester.pumpWidget(
        AppStartup(initialize: () => initialization.future),
      );
      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, brightness);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        brightness == Brightness.dark
            ? const Color(0xFF171A1C)
            : const Color(0xFFF8F9FA),
      );
      await tester.pumpWidget(const SizedBox());
      initialization.complete(readyApp);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading respects reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final initialization = Completer<Widget>();
    await tester.pumpWidget(
      AppStartup(initialize: () => initialization.future),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
