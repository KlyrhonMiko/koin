import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/sheets/confirmation_sheet.dart';

void main() {

  Future<BuildContext> mountToastHost(
    WidgetTester tester, {
    ValueNotifier<bool>? reducedMotion,
  }) async {
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
        builder: reducedMotion == null
            ? null
            : (context, child) => ValueListenableBuilder<bool>(
                valueListenable: reducedMotion,
                builder: (context, reduced, _) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: child!,
                ),
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
    return source;
  }

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
      final iconRect = tester.getRect(find.byIcon(KoinIcons.check));
      final toastRect = tester.getRect(find.byType(Dismissible));
      expect(iconRect.center.dy, closeTo(toastRect.center.dy, 1));
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
    await tester.drag(find.byType(Dismissible), const Offset(0, 180));
    await tester.pumpAndSettle();
    expect(find.text('Income processed'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short feedback stays compact and clears headers and navigation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext source;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), true),
          home: Scaffold(
            appBar: AppBar(title: const Text('Archive manager')),
            bottomNavigationBar: const SizedBox(
              height: 68,
              key: Key('navigation'),
            ),
            body: Builder(
              builder: (context) {
                source = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );
      KoinSnackBar.success(source, 'Maya archived');
      await tester.pumpAndSettle();
      final toast = tester.getRect(find.byType(Dismissible));
      expect(toast.height, lessThanOrEqualTo(56));
      expect(toast.width, lessThan(300));
      expect(
        toast.top,
        greaterThan(tester.getRect(find.byType(AppBar)).bottom),
      );
      expect(
        toast.bottom,
        lessThan(tester.getRect(find.byKey(const Key('navigation'))).top),
      );
      expect(find.text('Maya archived').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(Dismissible), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sheet errors remain visible above a changing keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final keyboard = ValueNotifier(0.0);
    addTearDown(keyboard.dispose);
    late BuildContext source;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, inset, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(viewInsets: EdgeInsets.only(bottom: inset)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              source = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    showModalBottomSheet<void>(
      context: source,
      builder: (context) => SizedBox(
        height: 350,
        child: Center(
          child: TextButton(
            onPressed: () => KoinSnackBar.error(
              context,
              'Could not save budget',
              subtitle: 'Your changes are kept. Try again.',
            ),
            child: const Text('Show error'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show error'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save budget').hitTestable(), findsOneWidget);
    final before = tester.getRect(find.byType(Dismissible));
    keyboard.value = 350;
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byType(Dismissible));
    expect(after.bottom, lessThanOrEqualTo(600));
    expect(after.top, lessThan(before.top));
    expect(
      find.text('Your changes are kept. Try again.').hitTestable(),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opening confirmation clears feedback that would cover its content',
    (tester) async {
      final source = await mountToastHost(tester);
      KoinSnackBar.success(source, 'Maya restored');
      await tester.pumpAndSettle();
      expect(find.text('Maya restored'), findsOneWidget);
      ConfirmationSheet.show(
        context: source,
        title: 'Archive Cash?',
        description: 'History and balances are kept.',
        confirmLabel: 'Archive',
        confirmColor: AppTheme.primaryColor(source),
        icon: KoinIcons.archive,
      );
      await tester.pumpAndSettle();
      expect(find.text('Maya restored'), findsNothing);
      expect(find.text('Archive Cash?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

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

  for (final replacingDuringExit in [false, true]) {
    testWidgets(
      'new toast replaces a toast during ${replacingDuringExit ? 'exit' : 'entry'}',
      (tester) async {
        final source = await mountToastHost(tester);
        KoinSnackBar.show(
          source,
          message: 'First message',
          duration: const Duration(seconds: 1),
        );
        await tester.pump();
        if (replacingDuringExit) {
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 40));

        KoinSnackBar.info(source, 'Replacement message');
        await tester.pump();
        expect(find.text('First message'), findsNothing);
        expect(find.text('Replacement message'), findsOneWidget);
        expect(find.byType(Dismissible), findsOneWidget);

        // The old timer or canceled exit must never remove the replacement.
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Replacement message'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(find.text('Replacement message'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('enabling reduced motion during exit completes dismissal', (
    tester,
  ) async {
    final reducedMotion = ValueNotifier(false);
    addTearDown(reducedMotion.dispose);
    final source = await mountToastHost(tester, reducedMotion: reducedMotion);
    KoinSnackBar.show(
      source,
      message: 'Finishing message',
      duration: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 40));
    final fadingToast = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Finishing message'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fadingToast.opacity.value, inExclusiveRange(0, 1));

    reducedMotion.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Finishing message'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);

    KoinSnackBar.info(source, 'Next message');
    await tester.pump();
    expect(find.text('Next message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Next message'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
