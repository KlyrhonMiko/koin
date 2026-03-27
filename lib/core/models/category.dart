import 'package:flutter/material.dart';
import 'package:koin/core/models/transaction.dart';

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
}
