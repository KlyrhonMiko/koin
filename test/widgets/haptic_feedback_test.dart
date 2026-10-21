import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/widgets/cards/spending_trend_chart.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/inputs/numpad.dart';
import 'package:koin/features/debts/widgets/bnpl_schedule_selectors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final haptics = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    HapticService.enabled = true;
    haptics.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  });
  tearDown(() {
    HapticService.enabled = true;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'saved preference mutes every feedback level and reset restores it',
    () async {
      SharedPreferences.setMockInitialValues({'haptics_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      expect(container.read(settingsProvider).hapticsEnabled, isFalse);
      for (final send in [
        HapticService.light,
        HapticService.medium,
        HapticService.heavy,
        HapticService.selection,
        HapticService.success,
        HapticService.error,
      ]) {
        await send();
      }
      expect(haptics, isEmpty);
      final notifier = container.read(settingsProvider.notifier);
      await notifier.setHapticsEnabled(true);
      expect(prefs.getBool('haptics_enabled'), isTrue);
      expect(container.read(settingsProvider).hapticsEnabled, isTrue);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await notifier.setHapticsEnabled(false);
      await HapticService.success();
      expect(haptics, hasLength(1));
      await notifier.resetSettings();
      expect(container.read(settingsProvider).hapticsEnabled, isTrue);
      expect(HapticService.enabled, isTrue);
    },
  );

  test('nested tap feedback is coalesced, results remain distinct', () async {
    final first = HapticService.light();
    final nested = HapticService.medium();
    await Future.wait([first, nested]);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await HapticService.success();
    await HapticService.error();
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  testWidgets('keypad does not announce success when submit is rejected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumPad(onValueChanged: (_, _) {}, onDone: HapticService.error),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
    haptics.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumPad(
            enabled: false,
            onValueChanged: (_, _) => fail('Disabled keypad changed its value'),
            onDone: () => fail('Disabled keypad submitted'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
  });

  testWidgets(
    'billing day ticks on a new selection, not a repeated selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BillingDaySelector(
              day: 15,
              primaryColor: Colors.teal,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Monthly due day'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      haptics.clear();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      expect(haptics, hasLength(1));
    },
  );

  testWidgets('chart ticks only on a changed valid touch selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpendingTrendChart(
            expenses: [
              AppTransaction(
                id: 'one',
                amount: 50,
                date: DateTime(2026, 10, 12),
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
            ],
            currency: const Currency(code: 'PHP', symbol: 'P', name: 'Peso'),
            filterIndex: 0,
            baseDate: DateTime(2026, 10, 14),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    final callback = data.barTouchData.touchCallback!;
    BarTouchResponse response(int index) {
      final group = data.barGroups[index];
      return BarTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        spot: BarTouchedSpot(
          group,
          index,
          group.barRods.first,
          0,
          null,
          -1,
          const FlSpot(0, 50),
          Offset.zero,
        ),
      );
    }

    callback(FlTapDownEvent(TapDownDetails()), null);
    await tester.pump();
    expect(haptics, isEmpty);
    callback(FlTapDownEvent(TapDownDetails()), response(0));
    await tester.pump();
    callback(
      FlPanUpdateEvent(DragUpdateDetails(globalPosition: Offset.zero)),
      response(0),
    );
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    callback(
      FlPanUpdateEvent(DragUpdateDetails(globalPosition: Offset.zero)),
      response(1),
    );
    await tester.pump();
    expect(haptics, hasLength(2));
    callback(const FlPointerHoverEvent(PointerHoverEvent()), response(2));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(2));
  });
}
