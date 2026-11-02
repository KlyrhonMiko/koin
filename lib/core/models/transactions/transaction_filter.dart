import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'transaction.dart';

enum TransactionSortOrder {
  newestFirst,
  amountAscending,
  amountDescending;

  int compare(AppTransaction a, AppTransaction b) {
    if (this != newestFirst) {
      final amount = a.amount.compareTo(b.amount);
      if (amount != 0) return this == amountAscending ? amount : -amount;
    }
    final date = b.date.compareTo(a.date);
    return date == 0 ? b.id.compareTo(a.id) : date;
  }
}

class TransactionFilter {
  final String query;
  final DateTimeRange? dateRange;
  final Set<String> categoryIds;
  final Set<String> accountIds;
  final double? minAmount;
  final double? maxAmount;
  final TransactionType? type;
  final TransactionSortOrder sortOrder;
  final bool pendingCashbackOnly;

  const TransactionFilter({
    this.query = '',
    this.dateRange,
    this.categoryIds = const {},
    this.accountIds = const {},
    this.minAmount,
    this.maxAmount,
    this.type,
    this.sortOrder = TransactionSortOrder.newestFirst,
    this.pendingCashbackOnly = false,
  });

  TransactionFilter copyWith({
    String? query,
    DateTimeRange? dateRange,
    Set<String>? categoryIds,
    Set<String>? accountIds,
    double? minAmount,
    double? maxAmount,
    TransactionType? type,
    TransactionSortOrder? sortOrder,
    bool? pendingCashbackOnly,
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
      sortOrder: sortOrder ?? this.sortOrder,
      pendingCashbackOnly: pendingCashbackOnly ?? this.pendingCashbackOnly,
    );
  }

  bool get isAmountSort => sortOrder != TransactionSortOrder.newestFirst;

  bool get isEmpty =>
      query.isEmpty &&
      dateRange == null &&
      categoryIds.isEmpty &&
      accountIds.isEmpty &&
      minAmount == null &&
      maxAmount == null &&
      type == null &&
      !pendingCashbackOnly &&
      !isAmountSort;

  /// Whether only the search query differs (used to debounce search alone).
  bool hasSameCriteria(TransactionFilter other) =>
      sortOrder == other.sortOrder &&
      pendingCashbackOnly == other.pendingCashbackOnly &&
      dateRange == other.dateRange &&
      type == other.type &&
      minAmount == other.minAmount &&
      maxAmount == other.maxAmount &&
      categoryIds.length == other.categoryIds.length &&
      categoryIds.containsAll(other.categoryIds) &&
      accountIds.length == other.accountIds.length &&
      accountIds.containsAll(other.accountIds);

  /// The count of non-query filters actively applied.
  int get activeFilterCount {
    int count = isAmountSort ? 1 : 0;
    if (pendingCashbackOnly) count++;
    if (type != null) count++;
    if (dateRange != null) count++;
    count += categoryIds.length;
    count += accountIds.length;
    if (minAmount != null) count++;
    if (maxAmount != null) count++;
    return count;
  }

  /// Localized summary description of active filter criteria.
  String get summaryText => describe();

  String describe({
    Map<String, String> categories = const {},
    Map<String, String> accounts = const {},
  }) {
    final parts = <String>[];
    if (pendingCashbackOnly) parts.add('Pending cashback');
    if (type != null) {
      parts.add(type!.name[0].toUpperCase() + type!.name.substring(1));
    }
    if (dateRange != null) {
      parts.add(
        '${DateFormat.yMMMd().format(dateRange!.start)}–${DateFormat.yMMMd().format(dateRange!.end)}',
      );
    }
    if (categoryIds.isNotEmpty) {
      parts.add(
        categoryIds.map((id) => categories[id] ?? 'Category').join(', '),
      );
    }
    if (accountIds.isNotEmpty) {
      parts.add(accountIds.map((id) => accounts[id] ?? 'Account').join(', '));
    }
    if (minAmount != null || maxAmount != null) {
      parts.add('Amount ${minAmount ?? 0}–${maxAmount ?? 'any'}');
    }
    if (isAmountSort) {
      parts.add(
        sortOrder == TransactionSortOrder.amountAscending
            ? 'Amount: low to high'
            : 'Amount: high to low',
      );
    }
    return parts.join(' • ');
  }

  /// Pure domain predicate: returns whether [tx] satisfies this filter's criteria.
  bool matches(AppTransaction tx, {Map<String, String>? categoryNamesById}) {
    if (isEmpty) return true;

    if (pendingCashbackOnly &&
        (!tx.cashbackPending || tx.expectedCashback <= 0)) {
      return false;
    }

    // Type filter
    if (type != null && (tx.type != type || tx.isDebtTransfer)) {
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
      final startBoundary = DateTime(
        dateRange!.start.year,
        dateRange!.start.month,
        dateRange!.start.day,
      );
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

    // Transfers belong to both endpoint accounts, without duplicating the row.
    final matchesAccount =
        accountIds.contains(tx.accountId) ||
        (tx.type == TransactionType.transfer &&
            accountIds.contains(tx.toAccountId));
    if (accountIds.isNotEmpty && !matchesAccount) {
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
    final result = transactions
        .where((tx) => matches(tx, categoryNamesById: categoryNamesById))
        .toList();
    if (isAmountSort) result.sort(sortOrder.compare);
    return result;
  }
}
