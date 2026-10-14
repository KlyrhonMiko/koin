import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';
import 'package:koin/features/debts/add_edit_debt_screen.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/features/debts/widgets/bnpl_schedule_selectors.dart';
import 'package:koin/features/debts/widgets/debt_purchase_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    prefs = await SharedPreferences.getInstance();
    if (const bool.fromEnvironment('FORM_PREVIEWS')) {
      final outfit = FontLoader('Outfit');
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ]) {
        outfit.addFont(
          rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'),
        );
      }
      await outfit.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  Future<void> open(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    double bottomSafeArea = 0,
    DebtRepository? debts,
    PlannedPaymentRepository? payments,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomSafeArea);
    tester.view.viewPadding = FakeViewPadding(bottom: bottomSafeArea);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryAdapter(),
          ),
          debtRepositoryProvider.overrideWithValue(
            debts ?? InMemoryDebtAdapter(),
          ),
          plannedPaymentRepositoryProvider.overrideWithValue(
            payments ?? InMemoryPlannedPaymentAdapter(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: const Key('preview'), child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => page),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('FORM_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/form_previews').create(recursive: true);
      await File(
        'build/form_previews/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> selectRecordType(WidgetTester tester, String label) async {
    final field = find.widgetWithText(SelectionTile, 'Record type');
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    if (label == 'BNPL') {
      final narrow = tester.view.physicalSize.width <= 320;
      await screenshot(
        tester,
        narrow ? 'debt_record_types_narrow' : 'debt_record_types',
      );
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(450));
      expect(tester.takeException(), isNull);
    }
    final option = find.widgetWithText(ListTile, label);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  void expectMatchingHint(WidgetTester tester, String hint, double size) {
    final field = find.widgetWithText(TextFormField, hint);
    final input = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    final placeholder = tester.widget<Text>(
      find.descendant(of: field, matching: find.text(hint)),
    );
    expect(placeholder.style!.fontSize, size);
    expect(placeholder.style!.fontSize, input.style.fontSize);
    expect(placeholder.style!.fontWeight, input.style.fontWeight);
    expect(placeholder.style!.letterSpacing, input.style.letterSpacing);
    expect(placeholder.style!.height, input.style.height);
    expect(placeholder.style!.fontFamily, input.style.fontFamily);
  }

  for (final narrow in [false, true]) {
    final size = narrow ? const Size(320, 700) : const Size(390, 844);
    final scale = narrow ? 1.6 : 1.0;
    final suffix = narrow ? 'narrow_dark' : 'phone_light';
    testWidgets('cashflow schedule stays usable $suffix', (tester) async {
      await open(
        tester,
        const AddEditCashflowScreen(),
        size: size,
        scale: scale,
        dark: narrow,
      );
      expectMatchingHint(tester, 'Name your payment', KoinTypography.formTitle);
      expectMatchingHint(tester, '0', KoinTypography.inputAmount);
      await screenshot(tester, 'cashflow_$suffix');
      await tester.tap(find.text('Repeats'));
      await tester.pumpAndSettle();
      await screenshot(tester, 'cashflow_repeats_$suffix');
      await tester.scrollUntilVisible(
        find.text('Monthly'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.ensureVisible(find.text('Monthly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('Next payment date'), findsOneWidget);
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      expectMatchingHint(tester, 'Notes (Optional)', KoinTypography.body);
      expect(find.text('Create Planned Payment').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('debt form and installments stay usable $suffix', (
      tester,
    ) async {
      await open(
        tester,
        const AddEditDebtScreen(),
        size: size,
        scale: scale,
        dark: narrow,
      );
      expectMatchingHint(tester, 'Who is involved?', KoinTypography.formTitle);
      expectMatchingHint(tester, '0', KoinTypography.inputAmount);
      expect(find.byType(DebtPurchaseSectionHeader), findsNothing);
      expect(find.text('Add Purchase / Sub-Plan'), findsNothing);
      await screenshot(tester, 'debt_$suffix');
      expect(
        find.byWidgetPredicate((widget) => widget is SegmentedButton),
        findsNothing,
      );
      expect(find.widgetWithText(SelectionTile, 'Record type'), findsOneWidget);
      await selectRecordType(tester, 'BNPL');
      expect(
        tester.widget<Text>(find.byKey(const Key('bnpl_balance'))).data,
        '0',
      );
      await tester.ensureVisible(find.text('BNPL provider'));
      await tester.pumpAndSettle();
      await screenshot(tester, 'bnpl_empty_$suffix');
      await selectRecordType(tester, 'I owe');
      final count = find.widgetWithText(TextFormField, 'Installments');
      await tester.ensureVisible(count);
      expectMatchingHint(tester, 'None', KoinTypography.body);
      await tester.enterText(count, '4');
      await tester.pumpAndSettle();
      expect(find.text('Start payment date'), findsOneWidget);
      expect(find.text('Payment frequency'), findsOneWidget);
      expect(find.text('Add Purchase / Sub-Plan'), findsNothing);
      expect(find.text('Add Purchase'), findsNothing);
      expect(find.byType(DebtPurchaseSectionHeader), findsNothing);
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Create').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('purchase validates and saves with keyboard $suffix', (
      tester,
    ) async {
      DebtItem? result;
      await open(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAddPurchaseSheet(
                  context: context,
                  debtType: DebtType.iOwe,
                  primaryColor: Colors.teal,
                  categories: [],
                  defaultDate: DateTime(2026, 10, 12),
                );
              },
              child: const Text('Purchase'),
            ),
          ),
        ),
        size: size,
        scale: scale,
        dark: narrow,
      );
      tester.view.padding = const FakeViewPadding(bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Purchase'));
      await tester.pumpAndSettle();
      expectMatchingHint(
        tester,
        'Name your purchase',
        KoinTypography.formTitle,
      );
      expectMatchingHint(tester, '0', KoinTypography.inputAmount);
      expectMatchingHint(tester, '1', KoinTypography.body);
      final buttonBottom = tester
          .getBottomLeft(find.byType(KoinPrimaryButton).last)
          .dy;
      expect(size.height - 24 - buttonBottom, greaterThanOrEqualTo(24));
      await screenshot(tester, 'purchase_$suffix');
      await tester.tap(find.text('Add to Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a purchase name'), findsOneWidget);
      final name = find.widgetWithText(TextFormField, 'Name your purchase');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Phone');
      final amount = find.widgetWithText(TextFormField, '0');
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '1200');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      tester.view.padding = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.text('Add to Plan').hitTestable(), findsOneWidget);
      final keyboardButtonBottom = tester
          .getBottomLeft(find.byType(KoinPrimaryButton).last)
          .dy;
      expect(
        size.height - 250 - keyboardButtonBottom,
        greaterThanOrEqualTo(24),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Add to Plan'));
      await tester.pumpAndSettle();
      expect(result?.name, 'Phone');
      expect(result?.amount, 1200);
      expect(result?.totalInstallments, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final narrow in [false, true]) {
    testWidgets(
      'BNPL purchase first and last bills stay editable narrow=$narrow',
      (tester) async {
        DebtItem? result;
        await open(
          tester,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Purchase'),
                onPressed: () async {
                  result = await showAddPurchaseSheet(
                    context: context,
                    debtType: DebtType.iOwe,
                    primaryColor: Colors.teal,
                    categories: [],
                    defaultDate: DateTime(2026, 10, 5),
                    monthlyBillingDay: 5,
                    existingItem: DebtItem(
                      id: 'phone',
                      debtId: 'provider',
                      name: 'Phone',
                      amount: 900,
                      totalInstallments: 3,
                      firstPaymentDate: DateTime(2026, 10, 5),
                    ),
                  );
                },
              ),
            ),
          ),
          size: narrow ? const Size(320, 700) : const Size(390, 844),
          scale: narrow ? 1.6 : 1,
          dark: narrow,
        );
        await tester.tap(find.text('Purchase'));
        await tester.pumpAndSettle();
        expect(find.text('Installments'), findsNothing);
        expect(find.text('First payment'), findsNothing);
        expect(find.text('Last bill month'), findsOneWidget);
        expect(find.text('3 monthly payments'), findsOneWidget);
        final lastBill = tester.widget<DateSelectorTile>(
          find.widgetWithText(DateSelectorTile, 'Last bill month'),
        );
        lastBill.onDateSelected!(DateTime(2026, 9, 1));
        await tester.pumpAndSettle();
        expect(find.text('1 monthly payment'), findsOneWidget);
        final firstBill = tester.widget<DateSelectorTile>(
          find.widgetWithText(DateSelectorTile, 'First bill month'),
        );
        firstBill.onDateSelected!(DateTime(2026, 11, 23));
        await tester.pumpAndSettle();
        expect(find.text('1 monthly payment'), findsOneWidget);
        final updatedLast = tester.widget<DateSelectorTile>(
          find.widgetWithText(DateSelectorTile, 'Last bill month'),
        );
        expect(updatedLast.date, DateTime(2026, 11, 5));
        updatedLast.onDateSelected!(DateTime(2026, 12, 1));
        await tester.pumpAndSettle();
        expect(find.text('2 monthly payments'), findsOneWidget);
        await tester.ensureVisible(find.text('First bill month'));
        await tester.pumpAndSettle();
        await screenshot(
          tester,
          narrow ? 'bnpl_purchase_narrow' : 'bnpl_purchase',
        );
        await tester.tap(find.text('First bill month'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.text('Jan'), findsOneWidget);
        expect(find.text('Dec'), findsOneWidget);
        expect(find.byType(CalendarDatePicker), findsNothing);
        await screenshot(
          tester,
          narrow ? 'bnpl_month_picker_narrow' : 'bnpl_month_picker',
        );
        await tester.tap(find.text('Oct'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('October 2026'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DateSelectorTile>(
                find.widgetWithText(DateSelectorTile, 'First bill month'),
              )
              .date,
          DateTime(2026, 11, 5),
        );
        await tester.tap(find.text('Update Plan'));
        await tester.pumpAndSettle();
        expect(result?.totalInstallments, 2);
        expect(result?.firstPaymentDate, DateTime(2026, 11, 5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('BNPL month grid confirms a month and year together', (
    tester,
  ) async {
    DateTime? result;
    await open(
      tester,
      Scaffold(
        body: BillMonthSelector(
          label: 'First bill month',
          date: DateTime(2026, 10),
          primaryColor: Colors.teal,
          onMonthSelected: (date) => result = date,
        ),
      ),
    );
    await tester.tap(find.text('First bill month'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('October 2026'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10));
    await tester.tap(find.text('First bill month'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    expect(find.byType(YearPicker), findsOneWidget);
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 10));
    expect(find.text('March 2027'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2027, 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('BNPL hides provider installment count and derives balance', (
    tester,
  ) async {
    final debt = Debt(
      id: 'provider',
      personName: 'Shopping',
      amount: 900,
      currentAmount: 300,
      type: DebtType.iOwe,
      startDate: DateTime(2026, 10, 5),
      isPurchaseAccount: true,
      items: [
        DebtItem(
          id: 'phone',
          debtId: 'provider',
          name: 'Phone',
          amount: 900,
          totalInstallments: 3,
          firstPaymentDate: DateTime(2026, 10, 5),
        ),
      ],
    );
    final repo = InMemoryDebtAdapter(initial: [debt]);
    await open(
      tester,
      AddEditDebtScreen(debt: debt),
      debts: repo,
      size: const Size(320, 700),
      scale: 1.6,
      dark: true,
    );
    expect(find.text('Outstanding balance'), findsOneWidget);
    expect(find.text('Installment plan'), findsNothing);
    expect(find.text('Monthly due day'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('bnpl_balance'))).data,
      '600',
    );
    await screenshot(tester, 'bnpl_provider_narrow');
    await tester.ensureVisible(find.text('Monthly due day'));
    await tester.tap(find.text('Monthly due day'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '1'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    await screenshot(tester, 'bnpl_day_picker_narrow');
    await tester.ensureVisible(find.widgetWithText(TextButton, '31'));
    await tester.tap(find.widgetWithText(TextButton, '31'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('5th of every month'), findsOneWidget);
    await selectRecordType(tester, 'I owe');
    expect(
      find.text('Remove purchases before switching to a single debt'),
      findsOneWidget,
    );
    expect(find.text('Installment plan'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await selectRecordType(tester, 'I am owed');
    expect(
      find.text('Remove purchases before switching to an IOU'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    final saved = (await repo.getDebts()).single;
    expect(saved.isPurchaseAccount, isTrue);
    expect(saved.currentAmount, 300);
    expect(saved.remainingAmount, 600);
    expect(saved.totalInstallments, 0);
    expect(tester.takeException(), isNull);
  });

  for (final delay in [0, 1, 2]) {
    testWidgets(
      'new BNPL purchase starts $delay months later on the inherited due day',
      (tester) async {
        final repo = InMemoryDebtAdapter();
        await open(tester, const AddEditDebtScreen(), debts: repo);
        await selectRecordType(tester, 'BNPL');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'BNPL provider'),
          'Shopping',
        );
        await tester.ensureVisible(find.byType(BillingDaySelector));
        await tester.tap(find.text('Monthly due day'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarDatePicker), findsNothing);
        if (delay == 0) await screenshot(tester, 'bnpl_day_picker');
        await tester.tap(find.text('5'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('5th of every month'), findsOneWidget);
        await tester.ensureVisible(find.text('Add Purchase'));
        await tester.tap(find.text('Add Purchase'));
        await tester.pumpAndSettle();
        expect(find.text('Remaining balance (PHP)'), findsOneWidget);
        expect(find.text('First payment'), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Name your purchase'),
          'Phone',
        );
        await tester.enterText(find.widgetWithText(TextFormField, '0'), '600');
        final firstBill = tester.widget<DateSelectorTile>(
          find.widgetWithText(DateSelectorTile, 'First bill month'),
        );
        firstBill.onDateSelected!(
          DateTime(firstBill.date.year, firstBill.date.month + delay, 1),
        );
        await tester.pumpAndSettle();
        final lastBill = tester.widget<DateSelectorTile>(
          find.widgetWithText(DateSelectorTile, 'Last bill month'),
        );
        lastBill.onDateSelected!(
          DateTime(lastBill.date.year, lastBill.date.month + 2, 1),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 monthly payments'), findsOneWidget);
        await tester.tap(find.text('Add to Plan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        final saved = (await repo.getDebts()).single;
        expect(saved.isPurchaseAccount, isTrue);
        expect(saved.totalInstallments, 0);
        expect(saved.frequency, InstallmentFrequency.monthly);
        expect(saved.items.single.totalInstallments, 3);
        expect(saved.items.single.firstPaymentDate.day, saved.startDate.day);
        expect(
          saved.items.single.firstPaymentDate,
          saved.monthlyBillDate(
            firstBill.date.year,
            firstBill.date.month + delay,
          ),
        );
        expect(saved.remainingAmount, 600);
        expect(saved.upcomingPaymentAmount, 200);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('BNPL keeps cents and a readable large balance', (tester) async {
    final debt = Debt(
      id: 'provider',
      personName: 'Shopping',
      amount: 12345678.5,
      type: DebtType.iOwe,
      startDate: DateTime(2026, 10, 5),
      isPurchaseAccount: true,
      items: [
        DebtItem(
          id: 'purchase',
          debtId: 'provider',
          name: 'Purchase',
          amount: 12345678.5,
          totalInstallments: 3,
          firstPaymentDate: DateTime(2026, 10, 5),
        ),
      ],
    );
    await open(
      tester,
      AddEditDebtScreen(debt: debt),
      size: const Size(320, 700),
      scale: 1.6,
      dark: true,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('bnpl_balance'))).data,
      '12,345,678.50',
    );
    await screenshot(tester, 'bnpl_fractional_narrow');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing debt preserves repaid amount and items', (tester) async {
    final item = DebtItem(
      id: 'item',
      debtId: 'debt',
      name: 'Phone',
      amount: 1200,
      totalInstallments: 4,
      firstPaymentDate: DateTime(2026),
    );
    final debt = Debt(
      id: 'debt',
      personName: 'Alex',
      amount: 1200,
      currentAmount: 300,
      type: DebtType.iOwe,
      startDate: DateTime(2026),
      items: [item],
    );
    final repo = InMemoryDebtAdapter(initial: [debt]);
    await open(tester, AddEditDebtScreen(debt: debt), debts: repo);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Alex'),
      'Alex updated',
    );
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    final saved = (await repo.getDebts()).single;
    expect(saved.personName, 'Alex updated');
    expect(saved.currentAmount, 300);
    expect(saved.items.single.id, 'item');
    expect(tester.takeException(), isNull);
  });
}
