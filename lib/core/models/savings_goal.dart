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
      'endDate': endDate?.toIso8601String() ?? DateTime(2099, 12, 31).toIso8601String(),
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
      endDate: (isStash && parsedEndDateStr.startsWith('2099')) ? null : DateTime.parse(parsedEndDateStr),
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
      targetAmount: targetAmount != null && targetAmount == -1 ? null : (targetAmount ?? this.targetAmount),
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate != null && endDate.year == 1970 ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
      isStash: isStash ?? this.isStash,
    );
  }

  // Calculations
  int? get totalDays => endDate?.difference(startDate).inDays;
  int? get remainingDays => endDate?.difference(DateTime.now()).inDays;
  double? get remainingAmount => targetAmount != null ? targetAmount! - currentAmount : null;

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
}
