import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/repositories/daily_interest_repository.dart';
import 'package:koin/core/widgets/inputs/app_input_focus.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InterestRepository extends DailyInterestRepository {
  Future<int> Function()? action;
  int calls = 0;
  @override
  Future<int> processDue({required DateTime now, int decimalDigits = 2}) async {
    calls++;
    return action == null ? 0 : await action!();
  }
}

void main() {
  late ProviderContainer container;
  late InMemoryAccountAdapter accounts;
  late InMemoryLedgerAdapter ledger;
  late _InterestRepository interest;
  final boundary = GlobalKey();
  Account bank({
    bool enabled = false,
    bool credit = false,
    InterestPayoutFrequency frequency = InterestPayoutFrequency.daily,
  }) => Account(
    id: 'bank',
    name: 'Everyday savings',
    iconCodePoint: Icons.account_balance_rounded.codePoint,
    colorHex: '#00D09E',
    initialBalance: 10000,
    isCredit: credit,
    annualInterestRate: enabled ? 3.65 : 0,
    interestTaxRate: enabled ? 20 : 0,
    interestStartDate: enabled ? DateTime(2026, 10, 20) : null,
    interestFrequency: frequency,
  );

  Future<void> launch(
    WidgetTester tester, {
    Account? account,
    double width = 390,
    double scale = 1,
    bool dark = false,
    bool disableAnimations = true,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    final prefs = await SharedPreferences.getInstance();
    accounts = InMemoryAccountAdapter(initial: [?account]);
    ledger = InMemoryLedgerAdapter();
    interest = _InterestRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(accounts),
        ledgerProvider.overrideWithValue(ledger),
        dailyInterestRepositoryProvider.overrideWithValue(interest),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountProvider.future);
    await container.read(transactionProvider.future);
    await container.read(categoriesProvider.future);
    await container.read(savingsGoalsProvider.future);
    await tester.runAsync(() async {
      final fonts = FontLoader(KoinTypography.fontFamily);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        fonts.addFont(
          rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'),
        );
      }
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: disableAnimations,
            ),
            child: AppInputFocus(
              child: RepaintBoundary(key: boundary, child: child!),
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AccountFormScreen(account: account),
                    ),
                  ),
                  child: const Text('Open account'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.byKey(ValueKey(key));

  Future<void> toggle(WidgetTester tester, String title) async {
    final finder = find.widgetWithText(SwitchListTile, title);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  double revealOpacity(WidgetTester tester, Finder content) => tester
      .widget<FadeTransition>(
        find.ancestor(of: content, matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  testWidgets(
    'interest reveal grows smoothly, staggers content, and survives rapid toggles',
    (tester) async {
      await launch(tester, account: bank(), disableAnimations: false);
      final toggle = find.widgetWithText(SwitchListTile, 'Interest');
      final reveal = find.byKey(const ValueKey('account_interest_reveal'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(reveal).height, 0);
      await tester.tap(toggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 40));
      final rate = field('account_interest_rate_field');
      final estimate = find.text('Est. ₱0.00 / day after tax');
      final midwayHeight = tester.getSize(reveal).height;
      expect(
        revealOpacity(tester, rate),
        greaterThan(revealOpacity(tester, estimate)),
      );
      await tester.pumpAndSettle();
      expect(midwayHeight, greaterThan(0));
      expect(midwayHeight, lessThan(tester.getSize(reveal).height));
      expect(revealOpacity(tester, rate), 1);
      expect(revealOpacity(tester, find.text('How it works')), 1);
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '4.5');
      await tester.pumpAndSettle();
      expect(revealOpacity(tester, rate), 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(rate).controller!.text, '4.5');
      expect(revealOpacity(tester, rate), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interest help uses the same staggered reveal and settles after interruption',
    (tester) async {
      await launch(
        tester,
        account: bank(enabled: true),
        disableAnimations: false,
      );
      final help = find.text('How it works');
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      await tester.tap(help);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      final tracking = find.textContaining('Tracking from');
      final explanation = find.textContaining('Uses your closing balance');
      expect(
        revealOpacity(tester, tracking),
        greaterThan(revealOpacity(tester, explanation)),
      );
      await tester.pumpAndSettle();
      expect(revealOpacity(tester, explanation), 1);
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(revealOpacity(tester, explanation), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('interest reveals finish immediately with reduced motion', (
    tester,
  ) async {
    await launch(tester, account: bank());
    await toggle(tester, 'Interest');
    expect(revealOpacity(tester, field('account_interest_rate_field')), 1);
    await tester.ensureVisible(find.text('How it works'));
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(
      revealOpacity(tester, find.textContaining('Uses your closing balance')),
      1,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'interest fields retain focus while the animated keyboard opens',
    (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await launch(
        tester,
        account: bank(enabled: true),
        dark: true,
        disableAnimations: false,
      );
      final rate = field('account_interest_rate_field');
      final tax = field('account_interest_tax_field');
      await tester.ensureVisible(rate);
      await tester.pumpAndSettle();
      await tester.tap(rate);
      await tester.pump();
      final editable = find.descendant(
        of: rate,
        matching: find.byType(EditableText),
      );
      final original = tester.state<EditableTextState>(editable);
      final focus = tester.widget<EditableText>(editable).focusNode;
      expect(focus.hasFocus, isTrue);
      for (final inset in [30.0, 100.0, 200.0, 300.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.state<EditableTextState>(editable), same(original));
        expect(focus.hasFocus, isTrue);
      }
      await tester.pumpAndSettle();
      await tester.enterText(rate, '4.5');
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.ensureVisible(tax);
      await tester.tap(tax);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: tax, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );
  Future<void> save(WidgetTester tester, {bool creating = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final button = find.text(creating ? 'Create Account' : 'Save Changes');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('enables automatic interest with optional zero tax', (
    tester,
  ) async {
    await launch(tester);
    await tester.enterText(field('account_name_field'), 'Savings bank');
    await tester.enterText(field('account_balance_field'), '10000');
    expect(field('account_interest_rate_field'), findsNothing);
    await toggle(tester, 'Interest');
    await tester.enterText(field('account_interest_rate_field'), '3.65');
    await tester.pumpAndSettle();
    expect(find.text('Est. ₱1.00 / day after tax'), findsOneWidget);
    await save(tester, creating: true);
    final saved = (await accounts.getAccounts()).single;
    expect(saved.hasDailyInterest, isTrue);
    expect(saved.annualInterestRate, 3.65);
    expect(saved.interestTaxRate, 0);
    expect(saved.interestStartDate, DailyInterest.day(DateTime.now()));
    expect(saved.initialBalance, 10000);
    expect(interest.calls, 0);
    expect(find.byType(AccountFormScreen), findsNothing);
  });

  testWidgets(
    'rejects invalid percentages without saving; shows net estimate',
    (tester) async {
      await launch(tester, account: bank());
      await toggle(tester, 'Interest');
      await tester.enterText(field('account_interest_rate_field'), '3.65');
      await tester.enterText(field('account_interest_tax_field'), '101');
      await save(tester);
      expect(find.text('Check interest rates'), findsOneWidget);
      expect((await accounts.getAccounts()).single.hasDailyInterest, isFalse);
      await tester.ensureVisible(field('account_interest_tax_field'));
      await tester.enterText(field('account_interest_tax_field'), '20');
      await tester.pumpAndSettle();
      expect(find.text('Est. ₱0.80 / day after tax'), findsOneWidget);
      await save(tester);
      expect((await accounts.getAccounts()).single.interestTaxRate, 20);
    },
  );

  testWidgets(
    'finishes old-rate days and preserves interest added during editing',
    (tester) async {
      await launch(tester, account: bank(enabled: true));
      interest.action = () async {
        await ledger.recordTransaction(
          AppTransaction(
            id: 'interest:bank:2026-10-20',
            amount: 0.8,
            date: DateTime(2026, 10, 20),
            type: TransactionType.income,
            categoryId: 'cat_interest',
            accountId: 'bank',
          ),
        );
        return 1;
      };
      await tester.ensureVisible(field('account_interest_rate_field'));
      await tester.enterText(field('account_interest_rate_field'), '7.3');
      await save(tester);
      expect(interest.calls, 1);
      final saved = (await accounts.getAccounts()).single;
      expect(saved.initialBalance, 10000);
      expect(saved.annualInterestRate, 7.3);
      expect(saved.interestStartDate, DateTime(2026, 10, 20));
      expect(
        TransactionRules.balance(saved, await ledger.getTransactions()),
        10000.8,
      );
    },
  );

  testWidgets('failed accrual keeps draft and old rates for retry', (
    tester,
  ) async {
    await launch(tester, account: bank(enabled: true));
    interest.action = () async => throw StateError('disk unavailable');
    await tester.ensureVisible(field('account_interest_rate_field'));
    await tester.enterText(field('account_interest_rate_field'), '7.3');
    await save(tester);
    expect(find.text('Could not save account'), findsOneWidget);
    expect((await accounts.getAccounts()).single.annualInterestRate, 3.65);
    expect(
      tester
          .widget<TextField>(field('account_interest_rate_field'))
          .controller!
          .text,
      '7.3',
    );
    interest.action = null;
    await save(tester);
    expect((await accounts.getAccounts()).single.annualInterestRate, 7.3);
  });

  testWidgets('turning a deposit account into credit disables interest', (
    tester,
  ) async {
    await launch(tester, account: bank(enabled: true));
    final interestRow = find.widgetWithText(SwitchListTile, 'Interest');
    final settingsCard = find
        .ancestor(of: interestRow, matching: find.byType(Material))
        .first;
    final initialSize = tester.getSize(settingsCard);
    await toggle(tester, 'Credit account');
    expect(tester.getSize(settingsCard), initialSize);
    expect(field('account_interest_rate_field'), findsNothing);
    await tester.ensureVisible(interestRow);
    await tester.tap(interestRow);
    await tester.pumpAndSettle();
    expect(field('account_interest_rate_field'), findsNothing);
    expect(tester.getSize(settingsCard), initialSize);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Interest'),
          )
          .onChanged,
      isNull,
    );
    await save(tester);
    final saved = (await accounts.getAccounts()).single;
    expect(saved.isCredit, isTrue);
    expect(saved.hasDailyInterest, isFalse);
    expect(saved.annualInterestRate, 0);
  });

  testWidgets('percentage inputs expose distinct screen-reader labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester, account: bank(enabled: true));
    await tester.ensureVisible(field('account_interest_rate_field'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(field('account_interest_rate_field')).label,
      contains('Annual interest rate (p.a.)'),
    );
    expect(
      tester.getSemantics(field('account_interest_tax_field')).label,
      contains('Tax on interest (optional)'),
    );
    semantics.dispose();
  });

  for (final frequency in [
    InterestPayoutFrequency.monthly,
    InterestPayoutFrequency.yearly,
  ]) {
    testWidgets(
      '${frequency.label} payout can be selected and saved without losing rate or tax',
      (tester) async {
        await launch(tester, account: bank(enabled: true), dark: true);
        final selector = field('account_interest_frequency_field');
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('interest_frequency_daily')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('interest_frequency_monthly')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('interest_frequency_yearly')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(ValueKey('interest_frequency_${frequency.name}')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('/ ${frequency.periodLabel} after tax'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(field('account_interest_rate_field'))
              .controller!
              .text,
          '3.65',
        );
        await save(tester);
        final saved = (await accounts.getAccounts()).single;
        expect(saved.hasInterest, isTrue);
        expect(saved.interestFrequency, frequency);
        expect(saved.annualInterestRate, 3.65);
        expect(saved.interestTaxRate, 20);
        expect(saved.interestStartDate, DateTime(2026, 10, 20));
        expect(interest.calls, 1);
      },
    );

    testWidgets('${frequency.label} payout reopens as enabled interest', (
      tester,
    ) async {
      await launch(tester, account: bank(enabled: true, frequency: frequency));
      await tester.ensureVisible(field('account_interest_frequency_field'));
      await tester.pumpAndSettle();
      expect(find.text(frequency.label), findsOneWidget);
      expect(
        find.textContaining('/ ${frequency.periodLabel} after tax'),
        findsOneWidget,
      );
      await save(tester);
      expect(
        (await accounts.getAccounts()).single.interestFrequency,
        frequency,
      );
    });
  }

  testWidgets(
    'interest explanation stays collapsed until requested and preserves the draft',
    (tester) async {
      await launch(tester, account: bank(enabled: true));
      final rate = field('account_interest_rate_field');
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '4.5');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.textContaining('Uses your closing balance'), findsNothing);
      await tester.ensureVisible(find.text('How it works'));
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Uses your closing balance'), findsOneWidget);
      expect(find.textContaining('Tracking from'), findsOneWidget);
      await tester.ensureVisible(find.text('How it works'));
      await tester.tap(find.text('How it works'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Uses your closing balance'), findsNothing);
      expect(tester.widget<TextField>(rate).controller!.text, '4.5');
      await save(tester);
      expect((await accounts.getAccounts()).single.annualInterestRate, 4.5);
    },
  );

  for (final (width, scale, dark) in [
    (390.0, 1.0, true),
    (320.0, 1.8, false),
    (800.0, 1.0, false),
  ]) {
    testWidgets('interest form fits $width at text scale $scale', (
      tester,
    ) async {
      await launch(
        tester,
        account: bank(enabled: true),
        width: width,
        scale: scale,
        dark: dark,
      );
      await tester.ensureVisible(field('account_interest_rate_field'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Tax (optional)'), findsOneWidget);
      final rateY = tester.getTopLeft(field('account_interest_rate_field')).dy;
      final taxY = tester.getTopLeft(field('account_interest_tax_field')).dy;
      if (scale == 1) {
        expect(rateY, taxY);
      } else {
        expect(taxY, greaterThan(rateY));
      }
      final capture = Platform.environment['KOIN_CAPTURE_INTEREST'];
      if (capture != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(capture).create(recursive: true);
          await File('$capture/interest-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final selector = field('account_interest_frequency_field');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final daily = find.byKey(const ValueKey('interest_frequency_daily'));
      final dailyTile = tester.widget<ListTile>(daily);
      expect(dailyTile.selectedTileColor, isNull);
      expect(dailyTile.minTileHeight, 48);
      final selectedLabel = find.descendant(
        of: daily,
        matching: find.text('Daily'),
      );
      final selectedCheck = find.descendant(
        of: daily,
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(
        tester.getTopLeft(selectedCheck).dx -
            tester.getTopRight(selectedLabel).dx,
        inInclusiveRange(0, 24),
      );
      if (capture != null) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$capture/payout-picker-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(daily);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Transfer fee'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
