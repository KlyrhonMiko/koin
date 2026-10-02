import 'package:flutter/material.dart';
import 'transaction.dart';

class TransactionCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double? budget;
  final double? budgetPercent;
  final bool isPercentBudget;

  final TransactionType type;
  final int position;

  TransactionCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    required this.type,
    this.budget,
    this.budgetPercent,
    this.isPercentBudget = false,
    this.position = 0,
  });

  TransactionCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? colorHex,
    double? budget,
    double? budgetPercent,
    bool? isPercentBudget,
    TransactionType? type,
    int? position,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      budget: budget ?? this.budget,
      budgetPercent: budgetPercent ?? this.budgetPercent,
      isPercentBudget: isPercentBudget ?? this.isPercentBudget,
      type: type ?? this.type,
      position: position ?? this.position,
    );
  }

  /// Returns a category copy with the specified fixed budget amount.
  TransactionCategory withFixedBudget(double? amount) => TransactionCategory(
        id: id,
        name: name,
        iconCodePoint: iconCodePoint,
        colorHex: colorHex,
        type: type,
        budget: (amount == null || amount <= 0) ? null : amount,
        budgetPercent: null,
        isPercentBudget: false,
        position: position,
      );

  /// Returns a category copy with the specified percentage budget.
  TransactionCategory withPercentBudget(double? percent) => TransactionCategory(
        id: id,
        name: name,
        iconCodePoint: iconCodePoint,
        colorHex: colorHex,
        type: type,
        budget: null,
        budgetPercent: (percent == null || percent <= 0) ? null : percent,
        isPercentBudget: percent != null && percent > 0,
        position: position,
      );

  /// Returns a category copy with any budget configuration cleared.
  TransactionCategory withoutBudget() => TransactionCategory(
        id: id,
        name: name,
        iconCodePoint: iconCodePoint,
        colorHex: colorHex,
        type: type,
        budget: null,
        budgetPercent: null,
        isPercentBudget: false,
        position: position,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'type': type.name,
      'budget': budget,
      'budgetPercent': budgetPercent,
      'isPercentBudget': isPercentBudget ? 1 : 0,
      'position': position,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      type: map['type'] != null
          ? TransactionType.values.byName(map['type'])
          : TransactionType.expense,
      budget: map['budget']?.toDouble(),
      budgetPercent: map['budgetPercent']?.toDouble(),
      isPercentBudget: map['isPercentBudget'] == 1,
      position: map['position'] ?? 0,
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  /// Returns whether this category has an active budget configured (fixed or percentage).
  bool get hasBudget =>
      (isPercentBudget && budgetPercent != null && budgetPercent! > 0) ||
      (!isPercentBudget && budget != null && budget! > 0);

  /// Resolves the effective budget amount in currency, computing percentage against [totalIncome] if configured as percentage-based.
  double resolvedBudget([double totalIncome = 0.0]) {
    if (isPercentBudget && budgetPercent != null && budgetPercent! > 0) {
      return totalIncome * budgetPercent! / 100;
    }
    return budget ?? 0.0;
  }

  /// Calculates the fraction (0.0 to 1.0) of budget consumed by [spent].
  double calculateProgress({required double spent, double totalIncome = 0.0}) {
    final b = resolvedBudget(totalIncome);
    return b > 0 ? (spent / b).clamp(0.0, 1.0) : 0.0;
  }

  /// Returns whether [spent] exceeds the resolved budget.
  bool isOverBudget({required double spent, double totalIncome = 0.0}) {
    final b = resolvedBudget(totalIncome);
    return b > 0 && spent > b;
  }
}
