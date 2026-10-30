import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/primitives/pressable_scale.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('touch tint is bounded and clears on release (dark=$dark)', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 240,
                  height: 80,
                  child: TextButton(
                    onPressed: () => calls++,
                    child: const Text('Touch feedback'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(TextButton);
      final bounds = tester.getRect(button);
      Future<ui.Image> frame(String state) async => (await tester.runAsync(
        () async {
          final image =
              await (boundaryKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          if (Platform.environment['KOIN_TOUCH_CAPTURE'] == '1') {
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/touch-feedback/${dark ? 'dark' : 'light'}-$state.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
          }
          return image;
        },
      ))!;

      Future<Color> pixel(ui.Image image, int x, int y) async =>
          (await tester.runAsync(() async {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset = (y * image.width + x) * 4;
            return Color.fromARGB(
              data.getUint8(offset + 3),
              data.getUint8(offset),
              data.getUint8(offset + 1),
              data.getUint8(offset + 2),
            );
          }))!;

      final rest = await frame('rest');
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      final pressed = await frame('pressed');
      final before = await pixel(rest, 10, 40);
      final after = await pixel(pressed, 10, 40);
      expect(after, isNot(before));
      // The resting surface is neutral; a held touch adds the chosen teal.
      expect(after.g - after.r, greaterThan(before.g - before.r));
      expect(await pixel(pressed, 0, 0), await pixel(rest, 0, 0));
      expect(calls, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      final released = await frame('released');
      expect(await pixel(released, 10, 40), before);
      expect(calls, 1);
      rest.dispose();
      pressed.dispose();
      released.dispose();
    });
  }

  testWidgets('press scale cancels and settles without overshooting', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressableScale(
            enableHaptic: false,
            onTap: () => calls++,
            child: const SizedBox(
              width: 120,
              height: 60,
              child: Text('Action'),
            ),
          ),
        ),
      ),
    );
    final scale = find.descendant(
      of: find.byType(PressableScale),
      matching: find.byType(ScaleTransition),
    );
    double value() => tester.widget<ScaleTransition>(scale).scale.value;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Action')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 100));
    expect(value(), closeTo(0.97, 0.001));
    await gesture.cancel();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(value(), inInclusiveRange(0.97, 1.0));
    }
    expect(value(), 1);
    expect(calls, 0);
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(value(), 1);
  });

  testWidgets('reduced motion and disabled actions never scale', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Column(
            children: [
              PressableScale(
                enableHaptic: false,
                onTap: () => calls++,
                child: const SizedBox(
                  width: 120,
                  height: 60,
                  child: Text('Enabled'),
                ),
              ),
              const PressableScale(
                onTap: null,
                child: SizedBox(
                  width: 120,
                  height: 60,
                  child: Text('Disabled'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(PressableScale),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Enabled')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, 0);
    await gesture.up();
    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
