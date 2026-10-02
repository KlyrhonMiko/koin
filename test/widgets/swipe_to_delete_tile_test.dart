import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/primitives/swipe_to_delete_tile.dart';

void main() {
  testWidgets('rounded swipe fills corner gaps and clears on cancel', (
    tester,
  ) async {
    const captureKey = ValueKey('capture');
    const cardKey = ValueKey('card');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: SizedBox(
                width: 320,
                height: 120,
                child: SwipeToDeleteTile(
                  key: const ValueKey('swipe'),
                  borderRadius: BorderRadius.circular(24),
                  fillRoundedCorners: true,
                  backgroundColor: Colors.red,
                  onDelete: () => fail('A partial swipe must not delete'),
                  child: Container(
                    key: cardKey,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(captureKey),
    );
    Future<Color> pixelAt(int x, int y) async =>
        (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final offset = (y * image.width + x) * 4;
          final color = Color.fromARGB(
            bytes.getUint8(offset + 3),
            bytes.getUint8(offset),
            bytes.getUint8(offset + 1),
            bytes.getUint8(offset + 2),
          );
          image.dispose();
          return color;
        }))!;

    expect(await pixelAt(318, 2), Colors.transparent);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(cardKey)),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    final cardRight = boundary
        .globalToLocal(tester.getTopRight(find.byKey(cardKey)))
        .dx;

    // Just inside the moving card's bounding box, outside its curved corner.
    expect(
      (await pixelAt(cardRight.floor() - 2, 2)).toARGB32(),
      Colors.red.toARGB32(),
    );
    expect(
      (await pixelAt(cardRight.floor() - 30, 60)).toARGB32(),
      Colors.blue.toARGB32(),
    );
    // The stationary background keeps the same rounded outer silhouette.
    expect(await pixelAt(318, 2), Colors.transparent);

    await gesture.cancel();
    await tester.pumpAndSettle();
    expect((await pixelAt(300, 2)).toARGB32(), isNot(Colors.red.toARGB32()));
    expect((await pixelAt(160, 60)).toARGB32(), Colors.blue.toARGB32());
  });
}
