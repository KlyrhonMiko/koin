import 'package:flutter/material.dart';
import 'transaction.dart';

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

  /// Pure domain predicate: returns whether [tx] satisfies this filter's criteria.
  bool matches(
    AppTransaction tx, {
    Map<String, String>? categoryNamesById,
  }) {
    if (isEmpty) return true;

    // Type filter
    if (type != null && tx.type != type) {
      return false;
    }

    // Query filter (matches note or category name)
    if (query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      final matchesNote = tx.note.toLowerCase().contains(q);
      final catName = categoryNamesById?[tx.categoryId]?.toLowerCase() ?? '';
      final matchesCat = catName.isNotEmpty && catName.contains(q);
      if (!matchesNote && !matchesCat) return false;
    }

    // Date range filter
    if (dateRange != null) {
      final startBoundary = dateRange!.start.subtract(const Duration(seconds: 1));
      final endBoundary = DateTime(
        dateRange!.end.year,
        dateRange!.end.month,
        dateRange!.end.day,
        23,
        59,
        59,
        999,
      );
      if (tx.date.isBefore(startBoundary) || tx.date.isAfter(endBoundary)) {
        return false;
      }
    }

    // Category filter
    if (categoryIds.isNotEmpty && !categoryIds.contains(tx.categoryId)) {
      return false;
    }

    // Account filter
    if (accountIds.isNotEmpty && !accountIds.contains(tx.accountId)) {
      return false;
    }

    // Min and Max amount filter
    if (minAmount != null && tx.amount < minAmount!) {
      return false;
    }
    if (maxAmount != null && tx.amount > maxAmount!) {
      return false;
    }

    return true;
  }

  /// Filters a collection of [transactions] using this filter.
  List<AppTransaction> apply(
    Iterable<AppTransaction> transactions, {
    Map<String, String>? categoryNamesById,
  }) {
    if (isEmpty) return transactions.toList();
    return transactions
        .where((tx) => matches(tx, categoryNamesById: categoryNamesById))
        .toList();
  }
}
