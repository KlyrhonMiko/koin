import 'package:flutter/material.dart';

class TransactionCategory {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double? budget;

  TransactionCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    this.budget,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'budget': budget,
    };
  }

  factory TransactionCategory.fromMap(Map<String, dynamic> map) {
    return TransactionCategory(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      budget: map['budget']?.toDouble(),
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
