import 'package:flutter/material.dart';

class Account {
  final String id;
  final String name;
  final int iconCodePoint;
  final String colorHex;
  final double initialBalance;
  final bool excludeFromTotal;
  final String? logoAsset;
  final String? cardColorHex;

  final int position;
  final int? cardShapeType;
  final double transferFeeAmount;
  final bool isTransferFeePercentage;

  Account({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorHex,
    this.initialBalance = 0.0,
    this.excludeFromTotal = false,
    this.position = 0,
    this.transferFeeAmount = 0.0,
    this.isTransferFeePercentage = false,
    this.logoAsset,
    this.cardColorHex,
    this.cardShapeType,
  });

  Account copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? colorHex,
    double? initialBalance,
    bool? excludeFromTotal,
    int? position,
    double? transferFeeAmount,
    bool? isTransferFeePercentage,
    String? Function()? logoAsset,
    String? Function()? cardColorHex,
    int? Function()? cardShapeType,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorHex: colorHex ?? this.colorHex,
      initialBalance: initialBalance ?? this.initialBalance,
      excludeFromTotal: excludeFromTotal ?? this.excludeFromTotal,
      position: position ?? this.position,
      transferFeeAmount: transferFeeAmount ?? this.transferFeeAmount,
      isTransferFeePercentage: isTransferFeePercentage ?? this.isTransferFeePercentage,
      logoAsset: logoAsset != null ? logoAsset() : this.logoAsset,
      cardColorHex: cardColorHex != null ? cardColorHex() : this.cardColorHex,
      cardShapeType: cardShapeType != null
          ? cardShapeType()
          : this.cardShapeType,
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
      'transferFeeAmount': transferFeeAmount,
      'isTransferFeePercentage': isTransferFeePercentage ? 1 : 0,
      'logoAsset': logoAsset,
      'cardColorHex': cardColorHex,
      'cardShapeType': cardShapeType,
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
      transferFeeAmount: (map['transferFeeAmount'] as num?)?.toDouble() ?? 0.0,
      isTransferFeePercentage: map['isTransferFeePercentage'] == 1,
      logoAsset: map['logoAsset'],
      cardColorHex: map['cardColorHex'],
      cardShapeType: map['cardShapeType'],
    );
  }

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  /// Returns the explicit card background color if set, otherwise null.
  Color? get cardColor => cardColorHex == null
      ? null
      : Color(int.parse(cardColorHex!.replaceFirst('#', '0xFF')));
}
