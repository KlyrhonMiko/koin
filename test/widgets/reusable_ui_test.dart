import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';

Widget host(Widget child, {bool dark = false, double scale = 1}) => MaterialApp(
  theme: AppTheme.getTheme(const Color(0xFF009688), dark),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
    ),
    child: Scaffold(body: child),
  ),
);

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await fonts.load();
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        File(
          '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await icons.load();
    }
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('radio sheet returns a typed choice and null on dismissal', (
    tester,
  ) async {
    int? result = -1;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showRadioSelectionSheet<int>(
              context: context,
              title: 'Choose frequency',
              options: [1, 2, 3],
              selected: 2,
              label: (value) => 'Option $value',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    await tester.tap(find.text('Option 3'));
    await tester.pumpAndSettle();
    expect(result, 3);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('quick actions support keyboard activation and disabled state', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        Row(
          children: [
            KoinQuickAction(
              icon: Icons.add,
              label: 'Save',
              color: Colors.teal,
              onPressed: () => calls++,
            ),
            const KoinQuickAction(
              icon: Icons.remove,
              label: 'Release',
              color: Colors.teal,
              onPressed: null,
              tonal: true,
            ),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    final disabled = tester.widget<IconButton>(find.byType(IconButton));
    expect(disabled.onPressed, isNull);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets(
    'selection reports selected semantics and activates with keyboard',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = false;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.topLeft,
              child: KoinSelectableOption(
                label: 'Travel',
                selected: selected,
                compact: true,
                accentColor: Colors.teal,
                onTap: () => setState(() => selected = !selected),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Travel')),
        matchesSemantics(
          label: 'Travel',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'progress respects reduced motion and avatar recovers from missing logo',
    (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const KoinProgressBar(value: 2, color: Colors.teal),
              KoinAccountAvatar(
                iconCodePoint: Icons.wallet_rounded.codePoint,
                color: Colors.teal,
                logoAsset: 'assets/missing-bank.png',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      expect(find.byIcon(Icons.wallet_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared components fit 320dp: dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1050);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: AppTheme.getTheme(
                  const Color(0xFF009688),
                  dark,
                ).scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const KoinPageHeader(title: 'Reusable components'),
                      const SizedBox(height: 20),
                      KoinSummaryCard(
                        topRightAction: KoinVisibilityButton(
                          hidden: false,
                          subject: 'balance',
                          onPressed: () {},
                        ),
                        child: const KoinSummaryContent(
                          label: 'Total saved',
                          currencyCode: 'PHP',
                          amount: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₱1,234,567.89',
                              style: KoinTypography.summaryAmountStyle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          KoinQuickAction(
                            icon: Icons.add,
                            label: 'Save',
                            color: Colors.teal,
                            onPressed: () {},
                          ),
                          const KoinQuickAction(
                            icon: Icons.remove,
                            label: 'Release',
                            color: Colors.teal,
                            onPressed: null,
                            tonal: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const KoinActivityRow(
                        leading: KoinIconBadge(
                          icon: Icons.north_east,
                          color: Colors.teal,
                        ),
                        title: 'Long activity title with additional details',
                        amount: Text(
                          '+₱123,456,789.00',
                          textAlign: TextAlign.end,
                        ),
                        subtitle: Text('Oct 18 · Linked account · 10:30 AM'),
                      ),
                      const SizedBox(height: 20),
                      const KoinProgressBar(value: 0.65, color: Colors.teal),
                      const SizedBox(height: 20),
                      KoinSelectableOption(
                        label: 'A very long category name',
                        selected: true,
                        compact: true,
                        accentColor: Colors.teal,
                        onTap: () {},
                      ),
                      const SizedBox(height: 20),
                      const KoinCalculatorAmount(
                        symbol: '₱',
                        expression: '9999999999999999+12345678',
                        result: '10000000012345677',
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 20),
                      KoinPeriodNavigation(
                        label: 'October 2026',
                        onPrevious: () {},
                        onNext: null,
                        previousTooltip: 'Previous month',
                        nextTooltip: 'Next month',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            dark: dark,
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('UI_PREVIEWS')) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/reuse_previews').create(recursive: true);
            await File(
              'build/reuse_previews/components_${dark ? 'dark' : 'light'}_$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
