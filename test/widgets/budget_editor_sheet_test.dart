import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/budgets/widgets/budget_editor_sheet.dart';

class TestCategories extends CategoryNotifier {
  TestCategories(this.items);
  final List<TransactionCategory> items;
  TransactionCategory? saved;

  @override
  Future<List<TransactionCategory>> build() async => items;

  @override
  Future<void> editCategory(TransactionCategory category) async {
    saved = category;
  }

  @override
  Future<void> saveBudget({
    required Set<String> categoryIds,
    required double amount,
    required bool isPercent,
    String? originalBudgetId,
  }) async {
    final ownerId = categoryIds.contains(originalBudgetId)
        ? originalBudgetId
        : categoryIds.first;
    final owner = items.firstWhere((c) => c.id == ownerId);
    saved =
        (isPercent
                ? owner.withPercentBudget(amount)
                : owner.withFixedBudget(amount))
            .copyWith(
              sharedBudgetCategoryIds: categoryIds
                  .where((id) => id != ownerId)
                  .toList(),
            );
  }
}

TransactionCategory category(String id, double percent) => TransactionCategory(
  id: id,
  name: id,
  iconCodePoint: KoinIcons.forkKnife.codePoint,
  colorHex: '#FF9800',
  type: TransactionType.expense,
  budgetPercent: percent,
  isPercentBudget: true,
);

void main() {
  setUpAll(() async {
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    for (final entry in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/phosphor_icons/PhosphorFill':
          'packages/phosphor_icons/lib/fonts/Phosphor-Fill.ttf',
      'packages/phosphor_icons/PhosphorRegular':
          'packages/phosphor_icons/lib/fonts/Phosphor.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
    final fallbackPath = Platform.environment['KOIN_PREVIEW_FALLBACK_FONT'];
    if (fallbackPath != null) {
      await (FontLoader('Roboto')..addFont(
            File(fallbackPath).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  Future<TestCategories> pumpEditor(
    WidgetTester tester, {
    double initial = 30,
    double other = 0,
    bool dark = true,
    double income = 2700,
    List<String> shared = const [],
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final food = category(
      'Food',
      initial,
    ).copyWith(sharedBudgetCategoryIds: shared);
    final notifier = TestCategories([
      food,
      category('Drinks', 0),
      if (other > 0) category('Rent', other),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [categoriesProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark).copyWith(
            textTheme: AppTheme.getTheme(
              const Color(0xFF00C9A0),
              dark,
            ).textTheme.apply(fontFamilyFallback: ['Roboto']),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const Key('shared-budget-editor-preview'),
            child: Scaffold(
              body: BudgetEditorSheet(
                category: food,
                currency: const Currency(
                  code: 'PHP',
                  symbol: '₱',
                  name: 'Philippine Peso',
                ),
                totalIncome: income,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('Custom percentage above 30 saves and resolves income', (
    tester,
  ) async {
    final notifier = await pumpEditor(tester);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(find.text('45% of ₱2,700.00 = ₱1,215.00'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved?.budgetPercent, 45);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Combined percentage over 100 is rejected; exactly 100 saves', (
    tester,
  ) async {
    final notifier = await pumpEditor(tester, other: 70, dark: false);
    await tester.tap(find.text('4'));
    await tester.tap(find.text('0'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved, isNull);
    expect(find.textContaining('Up to 30% is available.'), findsOneWidget);
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved?.budgetPercent, 30);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opening and saving preserves fractional percentages', (
    tester,
  ) async {
    final notifier = await pumpEditor(tester, initial: 12.5, income: 0);
    expect(find.text('12.5'), findsOneWidget);
    expect(find.textContaining('No income recorded yet'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved?.budgetPercent, 12.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Food and Drinks save one 25% budget and can be detached', (
    tester,
  ) async {
    final notifier = await pumpEditor(
      tester,
      initial: 25,
      other: 75,
      income: 20000,
    );
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    final drinks = find.byKey(const ValueKey('budget_category_Drinks'));
    await tester.ensureVisible(drinks);
    await tester.tap(drinks);
    await tester.pumpAndSettle();
    final rent = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('budget_category_Rent')),
    );
    expect(rent.onChanged, isNotNull);
    await tester.tap(find.text('Apply categories'));
    await tester.pumpAndSettle();
    expect(find.text('Food + Drinks'), findsOneWidget);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved?.budgetPercent, 25);
    expect(notifier.saved?.sharedBudgetCategoryIds, ['Drinks']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Existing sharing can be removed without removing the budget', (
    tester,
  ) async {
    final notifier = await pumpEditor(tester, initial: 25, shared: ['Drinks']);
    expect(find.text('Food + Drinks'), findsOneWidget);
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_category_Drinks')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notifier.saved?.budgetPercent, 25);
    expect(notifier.saved?.sharedBudgetCategoryIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'shared editor fits enlarged text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await pumpEditor(
          tester,
          initial: 25,
          shared: ['Drinks'],
          income: 20000,
          width: 320,
          scale: 1.5,
          dark: dark,
        );
        await tester.tap(find.text('Categories'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply categories'));
        await tester.pumpAndSettle();
        expect(find.text('Food + Drinks'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('shared-budget-editor-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/shared-budget-preview')
              .create(recursive: true);
          await File(
            'build/shared-budget-preview/editor-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'category editing is staged and either selected category can be removed',
    (tester) async {
      final notifier = await pumpEditor(
        tester,
        initial: 25,
        shared: ['Drinks'],
      );
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget_category_Food')));
      await tester.tap(find.byTooltip('Cancel category selection'));
      await tester.pumpAndSettle();
      expect(find.text('Food + Drinks'), findsOneWidget);
      expect(notifier.saved, isNull);
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('budget_category_Food')));
      await tester.tap(find.text('Apply categories'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(notifier.saved?.id, 'Drinks');
      expect(notifier.saved?.budgetPercent, 25);
      expect(notifier.saved?.sharedBudgetCategoryIds, isEmpty);
    },
  );
}
