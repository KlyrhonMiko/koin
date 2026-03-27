import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double initialBalance;
  final bool excludeFromTotal;

  Account({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    this.initialBalance = 0.0,
    this.excludeFromTotal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'initialBalance': initialBalance,
      'excludeFromTotal': excludeFromTotal ? 1 : 0,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      initialBalance: map['initialBalance'] ?? 0.0,
      excludeFromTotal: map['excludeFromTotal'] == 1,
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
