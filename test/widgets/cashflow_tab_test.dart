import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/cashflow.dart';

class FakePlannedPaymentNotifier extends PlannedPaymentNotifier {
  final List<PlannedPayment> initial;
  FakePlannedPaymentNotifier(this.initial);

  @override
  Future<List<PlannedPayment>> build() async => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('CashflowScheduleTab Widget Tests', () {
    testWidgets('renders planned payments expense list items and auto badges', (tester) async {
      final payments = [
        PlannedPayment(
          id: 'test_pp_1',
          title: 'Netflix Subscription',
          amount: 15.99,
          type: TransactionType.expense,
          categoryId: 'cat_entertainment',
          accountId: 'acc_main',
          startDate: DateTime(2026, 1, 1),
          nextDate: DateTime(2026, 10, 5),
          frequency: PaymentFrequency.monthly,
          isAutoProcess: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            plannedPaymentProvider.overrideWith(() => FakePlannedPaymentNotifier(payments)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlannedPaymentsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Netflix Subscription'), findsOneWidget);
      expect(find.text('MONTHLY'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
    });

    testWidgets('renders recurring incomes list items and receive action', (tester) async {
      final incomes = [
        PlannedPayment(
          id: 'test_inc_1',
          title: 'Design Client Retainer',
          amount: 3200.00,
          type: TransactionType.income,
          categoryId: 'cat_salary',
          accountId: 'acc_main',
          startDate: DateTime(2026, 1, 1),
          nextDate: DateTime(2026, 10, 15),
          frequency: PaymentFrequency.monthly,
          isAutoProcess: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            plannedPaymentProvider.overrideWith(() => FakePlannedPaymentNotifier(incomes)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecurringIncomesTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Design Client Retainer'), findsOneWidget);
      expect(find.text('MONTHLY'), findsOneWidget);
      expect(find.text('Receive'), findsOneWidget);
    });

    testWidgets('renders clean empty state when no items exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            plannedPaymentProvider.overrideWith(() => FakePlannedPaymentNotifier([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PlannedPaymentsTab(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No subscriptions'), findsOneWidget);
      expect(find.text('Add Your First Subscription'), findsOneWidget);
    });
  });
}
