import 'package:flutter/material.dart';
import 'package:koin/core/models/transaction.dart';

class TransactionFilter {
  final String query;
  final DateTimeRange? dateRange;
  final Set<String> categoryIds;
  final Set<String> accountIds;
  final double? minAmount;
  final double? maxAmount;
  final TransactionType? type;

  const TransactionFilter({
    this.query = '',
    this.dateRange,
    this.categoryIds = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
    this.type,
  });

  TransactionFilter copyWith({
    String? query,
    DateTimeRange? dateRange,
    Set<String>? categoryIds,
    Set<String>? accountIds,
    double? minAmount,
    double? maxAmount,
    TransactionType? type,
    bool clearDateRange = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearType = false,
  }) {
    return TransactionFilter(
      query: query ?? this.query,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      categoryIds: categoryIds ?? this.categoryIds,
      accountIds: accountIds ?? this.accountIds,
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      type: clearType ? null : (type ?? this.type),
    );
  }

  bool get isEmpty =>
      query.isEmpty &&
      dateRange == null &&
      categoryIds.isEmpty &&
      accountIds.isEmpty &&
      minAmount == null &&
      maxAmount == null &&
      type == null;
}
