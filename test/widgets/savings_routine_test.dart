import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:koin/features/savings/widgets/savings_projection_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:koin/features/savings/widgets/savings_plan_editor.dart';
import 'package:koin/features/savings/widgets/savings_routine_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final fonts = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons');
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'D:/dev/flutter';
    icons.addFont(
      File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await icons.load();
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    prefs = await SharedPreferences.getInstance();
  });
  final boundary = GlobalKey();
  final account = Account(
    id: 'bank',
    name: 'Main account',
    iconCodePoint: Icons.wallet.codePoint,
    colorHex: '#00C9A0',
    initialBalance: 10000,
  );
  SavingsGoal emergency({SavingsPlan? plan}) => SavingsGoal(
    id: 'emergency',
    name: 'Emergency fund',
    startDate: DateTime.now(),
    isEmergencyFund: true,
    linkedAccountId: 'bank',
    includeInDashboardBalance: false,
    savingsPlan: plan,
  );

  Future<InMemorySavingsAdapter> render(
    WidgetTester tester, {
    required Widget screen,
    List<SavingsGoal> goals = const [],
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = InMemorySavingsAdapter(initial: goals);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savingsRepositoryProvider.overrideWithValue(repo),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountAdapter(initial: [account]),
          ),
          dashboardStatsProvider.overrideWithValue(
            DashboardStats.calculate(accounts: [account], transactions: []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/savings-preview');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pump();
  }

  Future<void> openRoutine(WidgetTester tester) async {
    final setup = find.descendant(
      of: find.byType(SavingsRoutineCard),
      matching: find.text('Set up'),
    );
    await tester.ensureVisible(setup);
    await tester.tap(setup);
    await tester.pumpAndSettle();
  }

  for (final dark in [true, false]) {
    testWidgets(
      'new goal keeps the compact name and full-width type selector, dark=$dark',
      (tester) async {
        await render(tester, screen: const AddSavingsGoalScreen(), dark: dark);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('goal_name')),
                  matching: find.byType(TextField),
                ),
              )
              .maxLines,
          1,
        );
        expect(find.byType(ChoiceChip), findsNothing);
        expect(
          find.byKey(const ValueKey('savings_type_selector')),
          findsOneWidget,
        );
        await screenshot(tester, 'new-goal-layout-$dark');
        expect(tester.takeException(), isNull);
        final selector = tester.getRect(
          find.byKey(const ValueKey('savings_type_selector')),
        );
        expect(selector.width, 350);
        await tester.tap(find.text('Savings'));
        await tester.pumpAndSettle();
        expect(find.text('Target date'), findsNothing);
        expect(find.text('Target amount (optional)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Savings creation has an optional target and no deadline on a narrow screen with large text',
    (tester) async {
      final repo = await render(
        tester,
        screen: const AddSavingsGoalScreen(initialSavings: true),
        size: const Size(320, 900),
        scale: 1.6,
      );
      expect(find.text('Target amount (optional)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('goal_name')), 'Rainy days');
      expect(find.text('Target date'), findsNothing);
      await screenshot(tester, 'savings-form-large-text');
      await tester.tap(find.text('Create Savings'));
      await tester.pumpAndSettle();
      final saved = (await repo.getSavingsGoals()).single;
      expect(saved.isEmergencyFund, false);
      expect(saved.isStash, true);
      expect(saved.targetAmount, isNull);
      expect(saved.endDate, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'routine can be saved, reopened and stopped without changing existing savings',
    (tester) async {
      final fund = emergency();
      final repo = await render(
        tester,
        goals: [fund],
        screen: SavingsDetailsScreen(goal: fund),
      );
      final setup = find.descendant(
        of: find.byType(SavingsRoutineCard),
        matching: find.text('Set up'),
      );
      await tester.ensureVisible(setup);
      await tester.tap(setup);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('plan_amount')), '500');
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      var saved = (await repo.getSavingsGoals()).single;
      expect(saved.savingsPlan!.amount, 500);
      expect(saved.currentAmount, 0);
      expect(saved.includeInDashboardBalance, false);
      final edit = find.descendant(
        of: find.byType(SavingsRoutineCard),
        matching: find.text('Edit plan'),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('plan_amount')))
            .controller!
            .text,
        '500.00',
      );
      await tester.tap(find.text('Schedule options'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove plan'));
      await tester.tap(find.text('Remove plan'));
      await tester.pumpAndSettle();
      saved = (await repo.getSavingsGoals()).single;
      expect(saved.savingsPlan, isNull);
      expect(saved.currentAmount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'quick set aside records a real contribution and advances the routine',
    (tester) async {
      final fund = emergency(
        plan: SavingsPlan(
          amount: 500,
          frequency: SavingsFrequency.weekly,
          startDate: DateTime.now(),
        ),
      );
      final repo = await render(
        tester,
        goals: [fund],
        screen: SavingsDetailsScreen(goal: fund),
      );
      await screenshot(tester, 'savings-details-planned');
      expect(find.text('Savings Helper'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Goal targets'), findsNothing);
      await tester.tap(find.text('Set aside'));
      await tester.pumpAndSettle();
      final save = find.text('Save').last;
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect((await repo.getSavingsGoals()).single.currentAmount, 500);
      expect((await repo.getSavingsLogs(fund.id)).single.amount, 500);
      expect(find.textContaining('Next contribution:'), findsOneWidget);
      expect(find.text('1 of 1 saving periods fulfilled'), findsNothing);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Set aside'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'routine suggestions stay pending until saved and keep Savings open-ended',
    (tester) async {
      final fund = emergency();
      final repo = await render(
        tester,
        goals: [fund],
        screen: SavingsDetailsScreen(goal: fund),
      );
      expect(find.text('Coach'), findsNothing);
      await openRoutine(tester);
      await tester.enterText(find.byKey(const Key('plan_amount')), '200');
      await tester.pumpAndSettle();
      expect(find.text('Savings Helper'), findsOneWidget);
      expect(find.text('Projected savings'), findsOneWidget);
      expect(find.byKey(const ValueKey('helper_result_panel')), findsOneWidget);
      await tester.ensureVisible(find.text('This year'));
      await tester.tap(find.text('This year'));
      await tester.pumpAndSettle();
      expect((await repo.getSavingsGoals()).single.savingsPlan, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('plan_amount')))
            .controller!
            .text,
        '200',
      );
      await tester.ensureVisible(find.text('Save plan'));
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      final saved = (await repo.getSavingsGoals()).single;
      expect(saved.savingsPlan!.amount, 200);
      expect(saved.targetAmount, isNull);
      expect(saved.endDate, isNull);
      expect(saved.includeInDashboardBalance, false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discarding a suggested routine leaves savings and existing schedule unchanged',
    (tester) async {
      final plan = SavingsPlan(
        amount: 200,
        frequency: SavingsFrequency.monthly,
        startDate: DateTime.now(),
      );
      final fund = emergency(plan: plan);
      final repo = await render(
        tester,
        goals: [fund],
        screen: SavingsDetailsScreen(goal: fund),
      );
      final edit = find.descendant(
        of: find.byType(SavingsRoutineCard),
        matching: find.text('Edit plan'),
      );
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('plan_amount')), '400');
      await tester.pumpAndSettle();
      expect(find.text('Projected savings'), findsOneWidget);
      expect(find.byKey(const ValueKey('helper_result_panel')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('plan_amount')))
            .controller!
            .text,
        '400',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      final saved = (await repo.getSavingsGoals()).single;
      expect(saved.savingsPlan!.amount, 200);
      expect(saved.savingsPlan!.frequency, SavingsFrequency.monthly);
      expect(saved.savingsPlan!.startDate, plan.startDate);
      expect(saved.currentAmount, fund.currentAmount);
      expect(saved.targetAmount, isNull);
      expect(saved.endDate, isNull);
      expect(saved.includeInDashboardBalance, false);
    },
  );

  testWidgets('routine editor fits a small light screen with large text', (
    tester,
  ) async {
    await render(
      tester,
      screen: const SavingsPlanEditor(),
      size: const Size(320, 900),
      scale: 1.6,
      dark: false,
    );
    expect(find.text('First contribution'), findsNothing);
    expect(find.byKey(const ValueKey('saved_fill')), findsNothing);
    expect(find.text('Save plan'), findsOneWidget);
    expect(tester.getRect(find.text('Save plan')).bottom, lessThan(900));
    await screenshot(tester, 'routine-editor-large-text');
    expect(tester.takeException(), isNull);
  });
  for (final stash in [true, false]) {
    for (final dark in [true, false]) {
      testWidgets(
        'projection fits narrow screen and large text: stash=$stash, dark=$dark',
        (tester) async {
          final now = DateTime.now();
          final goal = SavingsGoal(
            id: 'preview',
            name: stash ? 'Rainy days' : 'New phone',
            currentAmount: 1000,
            targetAmount: stash ? null : 5000,
            isStash: stash,
            startDate: now,
            endDate: stash ? null : now.add(const Duration(days: 70)),
            savingsPlan: SavingsPlan(
              amount: 200,
              frequency: SavingsFrequency.weekly,
              startDate: now,
            ),
          );
          await render(
            tester,
            goals: [goal],
            screen: SavingsDetailsScreen(goal: goal),
            size: const Size(320, 900),
            scale: 1.6,
            dark: dark,
          );
          final message = find.byKey(
            const ValueKey('helper_projection_message'),
          );
          await tester.ensureVisible(message);
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('saved_fill')), findsOneWidget);
          expect(find.byKey(const ValueKey('projected_fill')), findsOneWidget);
          await screenshot(tester, 'helper-$stash-$dark-large-text');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'month and year update projections while Saved stays the real balance',
    (tester) async {
      final today = DateTime(2026, 10, 12);
      final goal = SavingsGoal(
        id: 'pot',
        name: 'Savings',
        currentAmount: 1000,
        startDate: today,
        isStash: true,
        savingsPlan: SavingsPlan(
          amount: 200,
          frequency: SavingsFrequency.weekly,
          startDate: today,
        ),
      );
      await render(
        tester,
        screen: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SavingsProjectionView(
              goal: goal,
              logs: const [],
              format: NumberFormat.simpleCurrency(name: 'PHP'),
              today: today,
            ),
          ),
        ),
      );
      expect(find.textContaining('1,600.00 by Oct 31, 2026'), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('saved_fill')),
            )
            .widthFactor,
        1000 / 1600,
      );
      await tester.tap(find.text('This year'));
      await tester.pumpAndSettle();
      expect(find.textContaining('3,400.00 by Dec 31, 2026'), findsOneWidget);
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('saved_fill')),
            )
            .widthFactor,
        1000 / 3400,
      );
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('projected_fill')),
            )
            .widthFactor,
        1,
      );
      expect(goal.currentAmount, 1000);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'goal bar separates actual and projected progress against the target',
    (tester) async {
      final today = DateTime(2026, 10, 12);
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Phone',
        currentAmount: 1000,
        targetAmount: 5000,
        startDate: today,
        endDate: DateTime(2026, 10, 31),
        savingsPlan: SavingsPlan(
          amount: 200,
          frequency: SavingsFrequency.weekly,
          startDate: today,
        ),
      );
      await render(
        tester,
        screen: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: SavingsProjectionView(
              goal: goal,
              logs: const [],
              format: NumberFormat.simpleCurrency(name: 'PHP'),
              today: today,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('saved_fill')),
            )
            .widthFactor,
        0.2,
      );
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const ValueKey('projected_fill')),
            )
            .widthFactor,
        0.32,
      );
      expect(find.textContaining('1,333.34 every week'), findsOneWidget);
      expect(find.text('This year'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'overview with a planned goal fits narrow screens and large text',
    (tester) async {
      final now = DateTime.now();
      final goal = SavingsGoal(
        id: 'phone',
        name: 'New phone',
        currentAmount: 1000,
        targetAmount: 5000,
        startDate: now,
        endDate: now.add(const Duration(days: 70)),
        savingsPlan: SavingsPlan(
          amount: 200,
          frequency: SavingsFrequency.weekly,
          startDate: now,
        ),
      );
      await render(
        tester,
        goals: [goal],
        screen: const Scaffold(body: SavingsTab(showEntranceAnimations: false)),
        size: const Size(320, 900),
        scale: 1.6,
      );
      expect(find.text('Savings Helper'), findsNothing);
      expect(find.byType(SavingsRoutineCard), findsNothing);
      expect(find.textContaining('projected by'), findsOneWidget);
      await screenshot(tester, 'savings-overview-simplified');
      expect(tester.takeException(), isNull);
    },
  );
  for (final dark in [true, false]) {
    testWidgets(
      'frequency picker matches the form and updates estimates: dark=$dark',
      (tester) async {
        await render(
          tester,
          screen: const SavingsPlanEditor(),
          dark: dark,
          size: const Size(320, 900),
          scale: 1.6,
        );
        await tester.tap(find.byKey(const ValueKey('frequency_field')));
        await tester.pumpAndSettle();
        expect(
          find.byType(DropdownButtonFormField<SavingsFrequency>),
          findsNothing,
        );
        expect(
          tester
              .widget<ListTile>(find.byKey(const ValueKey('frequency_weekly')))
              .selected,
          true,
        );
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await screenshot(tester, 'frequency-picker-$dark');
        await tester.tap(find.byKey(const ValueKey('frequency_monthly')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('frequency_picker')), findsNothing);
        expect(find.text('Monthly'), findsOneWidget);
        expect(find.textContaining('every month'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('frequency_field')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ListTile>(find.byKey(const ValueKey('frequency_monthly')))
              .selected,
          true,
        );
        await tester.tapAt(const Offset(12, 100));
        await tester.pumpAndSettle();
        expect(find.text('Monthly'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'helper focuses on one forecast and hides schedule settings until opened',
    (tester) async {
      final now = DateTime.now();
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Phone',
        startDate: now,
        targetAmount: 5000,
        endDate: now.add(const Duration(days: 70)),
      );
      await render(
        tester,
        goals: [goal],
        screen: SavingsPlanEditor(goal: goal),
      );
      expect(find.text('What could you save?'), findsNothing);
      expect(find.text('First contribution'), findsNothing);
      expect(find.text('Reach goal by'), findsNothing);
      expect(find.byType(SavingsProjectionBar), findsNothing);
      expect(
        find.byKey(const ValueKey('helper_projection_message')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('use_deadline_amount')), findsNothing);
      expect(tester.getRect(find.text('Save plan')).bottom, lessThan(844));
      await screenshot(tester, 'helper-editor-simplified');
      await tester.tap(find.text('Schedule options'));
      await tester.pumpAndSettle();
      expect(find.text('First contribution'), findsOneWidget);
      expect(find.text('Reach goal by'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'helper uses the amount needed for a goal deadline only after Save plan',
    (tester) async {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Trip',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 28)),
        targetAmount: 1000,
        includeInDashboardBalance: false,
      );
      final repo = await render(
        tester,
        goals: [goal],
        screen: SavingsDetailsScreen(goal: goal),
      );
      await openRoutine(tester);
      await tester.enterText(find.byKey(const Key('plan_amount')), '100');
      await tester.pumpAndSettle();
      expect(find.text('Estimated finish'), findsOneWidget);
      expect(find.byKey(const ValueKey('helper_result_value')), findsOneWidget);
      expect(find.byKey(const ValueKey('use_deadline_amount')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('show_deadline_amount')));
      await tester.pumpAndSettle();
      final use = find.byKey(const ValueKey('use_deadline_amount'));
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect((await repo.getSavingsGoals()).single.savingsPlan, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('plan_amount')))
            .controller!
            .text,
        '200.00',
      );
      await tester.ensureVisible(find.text('Save plan'));
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      final saved = (await repo.getSavingsGoals()).single;
      expect(saved.endDate, goal.endDate);
      expect(saved.savingsPlan!.amount, 200);
      expect(saved.currentAmount, 0);
      expect(saved.includeInDashboardBalance, false);
      expect(tester.takeException(), isNull);
    },
  );
}
