import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/snackbar_utils.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> showToast(
    WidgetTester tester, {
    bool dark = true,
    double scale = 1,
    bool reduceMotion = false,
  }) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              source = context;
              return const Text('Dashboard');
            },
          ),
        ),
      ),
    );
    KoinSnackBar.success(
      source,
      'Income processed',
      subtitle: 'Your recurring income has been completed',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('full confirmation wraps on narrow phones in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [true, false]) {
      await showToast(tester, dark: dark, scale: 1.5);
      final subtitle = tester.widget<Text>(
        find.text('Your recurring income has been completed'),
      );
      expect(subtitle.maxLines, isNull);
      expect(tester.takeException(), isNull);
      final titleRect = tester.getRect(find.text('Income processed'));
      final subtitleRect = tester.getRect(find.text(subtitle.data!));
      expect(subtitleRect.top, greaterThan(titleRect.bottom));
      expect(subtitleRect.right, lessThanOrEqualTo(300));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Income processed'), findsNothing);
    }
  });

  testWidgets('swipe dismissal cancels the timeout without removing twice', (
    tester,
  ) async {
    await showToast(tester);
    await tester.drag(find.byType(Dismissible), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(find.text('Income processed'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion presents and dismisses without animation', (
    tester,
  ) async {
    await showToast(tester, reduceMotion: true);
    expect(
      tester
          .widget<FadeTransition>(find.byType(FadeTransition).last)
          .opacity
          .value,
      1,
    );
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(semantics.properties.onDismiss, isNotNull);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Income processed'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
