import 'dart:convert';

import 'package:flutter/material.dart';

import 'transaction.dart';

class TransactionCategory {
  final String id;
  final String name;
  final bool isArchived;
  final int iconCodePoint;
  final String colorHex;
  final double? budget;
  final double? budgetPercent;
  final bool isPercentBudget;

  /// Additional categories spending from this category's single budget.
  final List<String> sharedBudgetCategoryIds;

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
    this.sharedBudgetCategoryIds = const [],
    this.position = 0,
    this.isArchived = false,
  });

  TransactionCategory copyWith({
    String? id,
    String? name,
    bool? isArchived,
    int? iconCodePoint,
    String? colorHex,
    double? budget,
    double? budgetPercent,
    bool? isPercentBudget,
    List<String>? sharedBudgetCategoryIds,
    TransactionType? type,
    int? position,
  }) {
    return TransactionCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      budget: budget ?? this.budget,
      budgetPercent: budgetPercent ?? this.budgetPercent,
      isPercentBudget: isPercentBudget ?? this.isPercentBudget,
      sharedBudgetCategoryIds:
          sharedBudgetCategoryIds ?? this.sharedBudgetCategoryIds,
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
    sharedBudgetCategoryIds: sharedBudgetCategoryIds,
    position: position,
    isArchived: isArchived,
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
    sharedBudgetCategoryIds: sharedBudgetCategoryIds,
    position: position,
    isArchived: isArchived,
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
    isArchived: isArchived,
  );

  TransactionCategory withBudgetFrom(TransactionCategory source) =>
      (source.isPercentBudget
              ? withPercentBudget(source.budgetPercent)
              : withFixedBudget(source.budget))
          .copyWith(sharedBudgetCategoryIds: source.sharedBudgetCategoryIds);

  /// Keeps a shared limit with its remaining expense categories on removal.
  static List<TransactionCategory> detachFromBudgets(
    List<TransactionCategory> categories,
    String categoryId,
  ) {
    final updates = <TransactionCategory>[];
    for (final budget in categories.where(
      (c) => c.type == TransactionType.expense && c.hasBudget,
    )) {
      if (budget.id == categoryId) {
        final remaining = categories
            .where(
              (c) =>
                  c.id != categoryId &&
                  c.type == TransactionType.expense &&
                  !c.hasBudget &&
                  budget.sharedBudgetCategoryIds.contains(c.id),
            )
            .toList();
        if (remaining.isNotEmpty) {
          updates.add(
            remaining.first
                .withBudgetFrom(budget)
                .copyWith(
                  sharedBudgetCategoryIds: remaining
                      .skip(1)
                      .map((c) => c.id)
                      .toList(),
                ),
          );
        }
      } else if (budget.sharedBudgetCategoryIds.contains(categoryId)) {
        updates.add(
          budget.copyWith(
            sharedBudgetCategoryIds: budget.sharedBudgetCategoryIds
                .where((id) => id != categoryId)
                .toList(),
          ),
        );
      }
    }
    return updates;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isArchived': isArchived ? 1 : 0,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'type': type.name,
      'budget': budget,
      'budgetPercent': budgetPercent,
      'isPercentBudget': isPercentBudget ? 1 : 0,
      'sharedBudgetCategoryIds': jsonEncode(sharedBudgetCategoryIds),
      'position': position,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      name: map['name'],
      isArchived: map['isArchived'] == 1,
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      type: map['type'] != null
          ? TransactionType.values.byName(map['type'])
          : TransactionType.expense,
      budget: map['budget']?.toDouble(),
      budgetPercent: map['budgetPercent']?.toDouble(),
      isPercentBudget: map['isPercentBudget'] == 1,
      sharedBudgetCategoryIds: List<String>.from(
        jsonDecode(map['sharedBudgetCategoryIds'] as String? ?? '[]'),
      ),
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
    return hasBudget && spent > b;
  }
}
