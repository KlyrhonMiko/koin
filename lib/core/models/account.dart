import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double initialBalance;
  final bool excludeFromTotal;

  final int position;

  Account({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    this.initialBalance = 0.0,
    this.excludeFromTotal = false,
    this.position = 0,
  });

  Account copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? colorHex,
    double? initialBalance,
    bool? excludeFromTotal,
    int? position,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      initialBalance: initialBalance ?? this.initialBalance,
      excludeFromTotal: excludeFromTotal ?? this.excludeFromTotal,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'colorHex': colorHex,
      'initialBalance': initialBalance,
      'excludeFromTotal': excludeFromTotal ? 1 : 0,
      'position': position,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      iconCodePoint: map['iconCodePoint'],
      colorHex: map['colorHex'],
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0.0,
      excludeFromTotal: map['excludeFromTotal'] == 1,
      position: map['position'] ?? 0,
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
