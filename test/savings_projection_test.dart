import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/models/savings/savings_projection.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  SavingsGoal savings({
    double saved = 1000,
    double? target,
    DateTime? start,
    double amount = 200,
    SavingsFrequency frequency = SavingsFrequency.weekly,
  }) => SavingsGoal(
    id: 's',
    name: 'Savings',
    startDate: today,
    currentAmount: saved,
    targetAmount: target,
    isStash: target == null,
    savingsPlan: SavingsPlan(
      amount: amount,
      frequency: frequency,
      startDate: start ?? today,
    ),
  );
  SavingsLog log(double amount, DateTime date) =>
      SavingsLog(id: '$amount-$date', goalId: 's', amount: amount, date: date);

  test('month and year use actual calendar occurrences, including today', () {
    final p = SavingsProjection(goal: savings(), today: today);
    expect(p.totalBy(DateTime(2026, 10, 31)), 1600);
    expect(p.totalBy(DateTime(2026, 12, 31)), 3400);
    expect(p.completionDate, isNull);
  });
  test('future starts contribute nothing until their first occurrence', () {
    final p = SavingsProjection(
      goal: savings(start: DateTime(2026, 11, 1)),
      today: today,
    );
    expect(p.totalBy(DateTime(2026, 10, 31)), 1000);
    expect(p.totalBy(DateTime(2026, 11, 1)), 1200);
  });
  test('partial and fulfilled deposits are not projected twice', () {
    final partial = SavingsProjection(
      goal: savings(saved: 1050),
      today: today,
      logs: [log(50, today)],
    );
    expect(partial.totalBy(DateTime(2026, 10, 31)), 1600);
    final fulfilled = SavingsProjection(
      goal: savings(saved: 1200),
      today: today,
      logs: [log(200, today)],
    );
    expect(fulfilled.totalBy(DateTime(2026, 10, 31)), 1600);
    expect(fulfilled.nextDate, DateTime(2026, 10, 19));
  });
  test('missed contributions are not added as arrears', () {
    final p = SavingsProjection(
      goal: savings(start: DateTime(2026, 1, 5)),
      today: today,
    );
    expect(p.additionalBy(today), 200);
    expect(p.totalBy(DateTime(2026, 10, 31)), 1600);
  });
  test(
    'goal projects completion in 20 weeks with a first payment next week',
    () {
      final p = SavingsProjection(
        goal: savings(target: 5000, start: DateTime(2026, 10, 19)),
        today: today,
      );
      expect(p.completionDate, DateTime(2027, 3, 1));
      expect(p.totalBy(DateTime(2027, 12, 31)), 5000);
      expect(p.requiredBy(DateTime(2026, 12, 21)), 400);
    },
  );
  test(
    'required amount credits partial current contributions and rounds up',
    () {
      final p = SavingsProjection(
        goal: savings(saved: 1050, target: 5000),
        today: today,
        logs: [log(50, today)],
      );
      expect(p.requiredBy(DateTime(2026, 10, 26)), 1333.34);
      final suggested = SavingsProjection(
        goal: savings(saved: 1050, target: 5000, amount: 1333.34),
        today: today,
        logs: [log(50, today)],
      );
      expect(suggested.totalBy(DateTime(2026, 10, 26)), 5000);
    },
  );
  test('lower deadline amount skips an already fulfilled current period', () {
    final p = SavingsProjection(
      goal: savings(saved: 4900, target: 5000),
      today: today,
      logs: [log(200, today)],
    );
    expect(p.requiredBy(DateTime(2026, 10, 19)), 100);
  });
  test('no suggestion for expired deadlines or dates before the start', () {
    final p = SavingsProjection(
      goal: savings(target: 5000, start: DateTime(2026, 11, 1)),
      today: today,
    );
    expect(p.requiredBy(DateTime(2026, 10, 11)), isNull);
    expect(p.requiredBy(DateTime(2026, 10, 31)), isNull);
  });
  test('monthly projection keeps month-end anchor across leap February', () {
    final p = SavingsProjection(
      goal: savings(
        start: DateTime(2028, 1, 31),
        frequency: SavingsFrequency.monthly,
      ),
      today: DateTime(2028, 1, 1),
    );
    expect(p.additionalBy(DateTime(2028, 2, 29)), 400);
    expect(p.additionalBy(DateTime(2028, 3, 30)), 400);
    expect(p.additionalBy(DateTime(2028, 3, 31)), 600);
  });
  test('completed goals never project further contributions', () {
    final p = SavingsProjection(
      goal: savings(saved: 5100, target: 5000),
      today: today,
    );
    expect(p.totalBy(DateTime(2026, 12, 31)), 5100);
    expect(p.completionDate, today);
    expect(p.requiredBy(DateTime(2026, 12, 31)), isNull);
  });
}
