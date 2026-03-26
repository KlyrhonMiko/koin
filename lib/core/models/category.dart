import 'package:flutter/material.dart';
import 'package:koin/core/models/transaction.dart';

class TransactionCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double? budget;

  final TransactionType type;

  TransactionCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    required this.type,
    this.budget,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'type': type.name,
      'budget': budget,
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
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
