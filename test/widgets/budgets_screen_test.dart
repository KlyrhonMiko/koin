import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    bool dark = true,
    double scale = 1,
    double width = 390,
    double spent = 815,
  }) async {
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'spent',
                amount: spent,
                date: now,
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
              AppTransaction(
                id: 'previous',
                amount: 100,
                date: DateTime(now.year, now.month - 1, 12),
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
            ],
          ),
        ),
        accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'food',
                name: 'Food',
                iconCodePoint: Icons.restaurant.codePoint,
                colorHex: '#FF9800',
                type: TransactionType.expense,
                budget: 912.5,
              ),
              TransactionCategory(
                id: 'transport',
                name: 'Transport',
                iconCodePoint: Icons.directions_bus.codePoint,
                colorHex: '#2196F3',
                type: TransactionType.expense,
              ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: RepaintBoundary(
              key: Key('budget-preview'),
              child: BudgetsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'month navigation updates spending and returns to current month',
    (tester) async {
      await launch(tester);
      expect(find.textContaining('spent · 89% used'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Next month',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('spent · 11% used'), findsOneWidget);
      final now = DateTime.now();
      await tester.tap(
        find.text(
          DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('spent · 89% used'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('summary privacy follows the shared preference', (tester) async {
    final container = await launch(tester);
    await tester.tap(find.byTooltip('Hide budget'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).hideBalance, isTrue);
    expect(find.text('Budget usage hidden'), findsOneWidget);
    expect(find.text('****'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KoinSummaryCard),
        matching: find.byType(AnimatedCounter),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Show budget'));
    await tester.pumpAndSettle();
    expect(find.textContaining('spent · 89% used'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCounter>(
            find.descendant(
              of: find.byType(KoinSummaryCard),
              matching: find.byType(AnimatedCounter),
            ),
          )
          .value,
      97.5,
    );
  });

  testWidgets('over-budget totals remain clear on narrow large-text screens', (
    tester,
  ) async {
    await launch(tester, width: 320, scale: 1.6, dark: false, spent: 1000);
    expect(find.textContaining('spent · 110% used'), findsOneWidget);
    expect(find.text('Over Budget'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCounter>(
            find.descendant(
              of: find.byType(KoinSummaryCard),
              matching: find.byType(AnimatedCounter),
            ),
          )
          .value,
      87.5,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget redesign preview', (tester) async {
    await launch(tester);
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('budget-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/budget-redesign.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
