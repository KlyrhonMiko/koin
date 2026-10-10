import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  testWidgets(
    'full-screen empty state has bounded actions and clears navigation',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KoinEmptyState.sliver(
              contentKey: const ValueKey('empty_content'),
              icon: Icons.event_repeat_rounded,
              title: 'No subscriptions',
              subtitle:
                  'Add recurring payments to track your future obligations',
              action: KoinPrimaryButton(
                label: 'Add Subscription',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      final content = tester.getRect(
        find.byKey(const ValueKey('empty_content')),
      );
      expect(content.width, lessThanOrEqualTo(320));
      expect(content.center.dy, closeTo((852 - 96) / 2, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full-screen empty state scrolls in a short viewport with large text',
    (tester) async {
      tester.view.physicalSize = const Size(600, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(600, 320),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: KoinEmptyState.sliver(
                icon: Icons.event_repeat_rounded,
                title: 'No subscriptions',
                subtitle:
                    'Add recurring payments to track your future obligations',
                action: KoinPrimaryButton(
                  label: 'Add Subscription',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Add Subscription'), 100);
      expect(tester.takeException(), isNull);
      expect(find.text('Add Subscription').hitTestable(), findsOneWidget);
    },
  );
}
