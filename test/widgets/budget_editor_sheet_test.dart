import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
}

TransactionCategory category(String id, double percent) => TransactionCategory(
  id: id,
  name: id,
  iconCodePoint: Icons.restaurant.codePoint,
  colorHex: '#FF9800',
  type: TransactionType.expense,
  budgetPercent: percent,
  isPercentBudget: true,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<TestCategories> pumpEditor(
    WidgetTester tester, {
    double initial = 30,
    double other = 0,
    bool dark = true,
    double income = 2700,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final food = category('Food', initial);
    final notifier = TestCategories([
      food,
      if (other > 0) category('Rent', other),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [categoriesProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark),
          home: Scaffold(
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
}
