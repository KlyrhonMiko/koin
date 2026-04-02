class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final String? linkedAccountId;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.linkedAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'notes': notes,
      'linkedAccountId': linkedAccountId,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'],
      name: map['name'],
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      notes: map['notes'],
      linkedAccountId: map['linkedAccountId'],
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
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      linkedAccountId: linkedAccountId ?? this.linkedAccountId,
    );
  }

  // Calculations
  int get totalDays => endDate.difference(startDate).inDays;
  int get remainingDays => endDate.difference(DateTime.now()).inDays;
  double get remainingAmount => targetAmount - currentAmount;

  double get dailyNeeded {
    if (remainingDays <= 0) return 0;
    return remainingAmount / remainingDays;
  }

  double get weeklyNeeded => dailyNeeded * 7;
  double get monthlyNeeded => dailyNeeded * 30;

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);
}
