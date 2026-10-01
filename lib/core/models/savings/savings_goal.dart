import 'dart:math';

class SavingsGoal {
  final String id;
  final String name;
  final double? targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final String? linkedAccountId;
  final bool isStash;

  SavingsGoal({
    required this.id,
    required this.name,
    this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    this.endDate,
    this.notes,
    this.linkedAccountId,
    this.isStash = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount ?? 0.0,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'endDate':
          endDate?.toIso8601String() ??
          DateTime(2099, 12, 31).toIso8601String(),
      'notes': notes,
      'linkedAccountId': linkedAccountId,
      'isStash': isStash ? 1 : 0,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    final isStash = map['isStash'] == 1;
    final parsedTarget = (map['targetAmount'] as num).toDouble();
    final parsedEndDateStr = map['endDate'] as String;

    return SavingsGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: (isStash && parsedTarget == 0.0) ? null : parsedTarget,
      currentAmount: (map['currentAmount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate']),
      endDate: (isStash && parsedEndDateStr.startsWith('2099'))
          ? null
          : DateTime.parse(parsedEndDateStr),
      notes: map['notes'],
      linkedAccountId: map['linkedAccountId'],
      isStash: isStash,
    );
  }

  SavingsGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? linkedAccountId,
    bool? isStash,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      // allow nullification of targetAmount and endDate
      targetAmount: targetAmount != null && targetAmount == -1
          ? null
          : (targetAmount ?? this.targetAmount),
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate != null && endDate.year == 1970
          ? null
          : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isStash: isStash ?? this.isStash,
    );
  }

  // Calculations
  int? get totalDays => endDate?.difference(startDate).inDays;
  int? get remainingDays => endDate?.difference(DateTime.now()).inDays;
  double? get remainingAmount =>
      targetAmount != null ? targetAmount! - currentAmount : null;

  double? get dailyNeeded {
    if (remainingDays == null || remainingAmount == null) return null;
    if (remainingDays! <= 0) return 0;
    return remainingAmount! / remainingDays!;
  }

  double? get weeklyNeeded {
    if (dailyNeeded == null || remainingAmount == null) return null;
    return (dailyNeeded! * 7).clamp(0, remainingAmount!);
  }

  double? get monthlyNeeded {
    if (dailyNeeded == null || remainingAmount == null) return null;
    return (dailyNeeded! * 30).clamp(0, remainingAmount!);
  }

  double get progress {
    if (targetAmount == null || targetAmount! <= 0) return 0.0;
    return (currentAmount / targetAmount!).clamp(0.0, 1.0);
  }

  /// Whether the goal has an explicit target amount set.
  bool get hasTarget => targetAmount != null && targetAmount! > 0;

  /// Whether the savings goal target has been reached or exceeded.
  bool get isCompleted => hasTarget && currentAmount >= targetAmount!;

  /// Whether adding [additionalAmount] to current savings will achieve or exceed the target.
  bool willComplete(double additionalAmount) =>
      hasTarget && (currentAmount + additionalAmount) >= targetAmount!;

  // ═══════════════════════════════════════════════════════
  // Coach & Pace Analytics
  // ═══════════════════════════════════════════════════════

  /// Elapsed days from [startDate] up to [today].
  int elapsedDays(DateTime today) {
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return max(0, todayDay.difference(startDay).inDays);
  }

  /// Total duration in days from start to target end date.
  int totalGoalDays() {
    if (endDate == null) return 1;
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return max(1, endDay.difference(startDay).inDays);
  }

  /// Expected accumulation amount at [today] according to linear milestone pacing.
  double expectedAmountToday(DateTime today) {
    if (targetAmount == null || targetAmount! <= 0) return 0.0;
    final eDays = elapsedDays(today);
    final tDays = totalGoalDays();
    if (eDays >= tDays) return targetAmount!;
    return targetAmount! * (eDays / tDays);
  }

  /// The amount user is trailing behind expected linear pace.
  double goalGap(DateTime today) {
    final expected = expectedAmountToday(today);
    return max(0.0, expected - currentAmount);
  }

  /// Current historical weekly savings pace.
  double currentWeeklyPace(DateTime today) {
    final target = targetAmount ?? 0.0;
    final eDays = elapsedDays(today);
    if (eDays < 7) {
      final tWeeks = totalGoalDays() / 7.0;
      if (tWeeks == 0) return target;
      return target / tWeeks;
    }
    final eWeeks = eDays / 7.0;
    return currentAmount / eWeeks;
  }
}
