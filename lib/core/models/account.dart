import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double initialBalance;

  Account({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    this.initialBalance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'initialBalance': initialBalance,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      initialBalance: map['initialBalance'] ?? 0.0,
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
