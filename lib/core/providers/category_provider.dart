import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/repositories/category_repository.dart';

import 'dart:developer' as dev;

import 'transaction_provider.dart';
import 'planned_payment_provider.dart';
import 'debt_provider.dart';

class CategoryNotifier extends AsyncNotifier<List<TransactionCategory>> {
  bool _reordering = false;
  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  @override
  Future<List<TransactionCategory>> build() async {
    return await _repository.getCategories();
  }

  Future<void> _loadCategories() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getCategories();
    });
  }

  Future<void> addCategory(TransactionCategory category) async {
    final currentCategories = state.value ?? [];
    _validateBudgetSharing(category, currentCategories);
    final categoryWithPosition = category.copyWith(
      position: currentCategories.length,
    );

    final previousState = state;
    state = AsyncValue.data([...currentCategories, categoryWithPosition]);

    try {
      await _repository.insertCategory(categoryWithPosition);
    } catch (e, st) {
      state = previousState;
      dev.log('Error adding category', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> editCategory(TransactionCategory category) async {
    if (!state.hasValue) throw StateError('Categories are not available');

    final previousState = state;
    final currentCategories = state.value!;
    final detached = category.type == TransactionType.expense
        ? <String, TransactionCategory>{}
        : {
            for (final c in TransactionCategory.detachFromBudgets(
              currentCategories,
              category.id,
            ))
              c.id: c,
          };
    if (category.type != TransactionType.expense) {
      category = category.withoutBudget();
    }
    _validateBudgetSharing(category, currentCategories);

    state = AsyncValue.data(
      currentCategories
          .map((c) => c.id == category.id ? category : detached[c.id] ?? c)
          .toList(),
    );

    try {
      await _repository.updateCategory(category);
    } catch (e, st) {
      state = previousState;
      dev.log('Error updating category', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    ref.invalidate(transactionProvider);
    ref.invalidate(plannedPaymentProvider);
    ref.invalidate(debtsProvider);
    await _loadCategories();
  }

  /// Saves a budget's coverage and limit together, including category moves.
  Future<void> saveBudget({
    required Set<String> categoryIds,
    required double amount,
    required bool isPercent,
    String? originalBudgetId,
  }) async {
    final categories = state.value;
    if (categories == null) throw StateError('Categories are not available.');
    final expenses = {
      for (final c in categories)
        if (c.type == TransactionType.expense) c.id: c,
    };
    if (categoryIds.isEmpty ||
        categoryIds.any((id) => !expenses.containsKey(id))) {
      throw StateError('Choose at least one available expense category.');
    }
    if (!amount.isFinite || amount <= 0 || (isPercent && amount > 100)) {
      throw StateError('Enter a valid budget limit.');
    }
    if (originalBudgetId != null && !expenses.containsKey(originalBudgetId)) {
      throw StateError('This budget is no longer available.');
    }
    final updates = <String, TransactionCategory>{};
    for (final budget in expenses.values.where((c) => c.hasBudget)) {
      final members = {
        budget.id,
        ...budget.sharedBudgetCategoryIds,
      }.where(expenses.containsKey).toSet();
      if (budget.id == originalBudgetId) {
        updates[budget.id] = budget.withoutBudget();
      } else if (members.intersection(categoryIds).isNotEmpty) {
        final remaining = members.difference(categoryIds);
        updates[budget.id] = budget.withoutBudget();
        if (remaining.isNotEmpty) {
          final ownerId = remaining.contains(budget.id)
              ? budget.id
              : remaining.first;
          final owner = expenses[ownerId]!;
          updates[ownerId] = owner
              .withBudgetFrom(budget)
              .copyWith(
                sharedBudgetCategoryIds: remaining
                    .where((id) => id != ownerId)
                    .toList(),
              );
        }
      }
    }
    final ownerId = categoryIds.contains(originalBudgetId)
        ? originalBudgetId!
        : categoryIds.first;
    final owner = expenses[ownerId]!;
    updates[ownerId] =
        (isPercent
                ? owner.withPercentBudget(amount)
                : owner.withFixedBudget(amount))
            .copyWith(
              sharedBudgetCategoryIds: categoryIds
                  .where((id) => id != ownerId)
                  .toList(),
            );
    final updatedCategories = categories
        .map((c) => updates[c.id] ?? c)
        .toList();
    final totalPercent = updatedCategories
        .where((c) => c.type == TransactionType.expense && c.isPercentBudget)
        .fold(0.0, (sum, c) => sum + (c.budgetPercent ?? 0));
    if (totalPercent > 100.000001) {
      throw StateError(
        'Percentage budgets exceed 100%. Reduce the limit to continue.',
      );
    }
    await _repository.updateBudgets(updates.values.toList());
    state = AsyncValue.data([
      for (final category in state.value ?? categories)
        if (updates[category.id] case final updated?)
          category.withBudgetFrom(updated)
        else
          category,
    ]);
  }

  void _validateBudgetSharing(
    TransactionCategory category,
    List<TransactionCategory> categories,
  ) {
    if (!category.hasBudget) return;
    final selectedIds = {category.id, ...category.sharedBudgetCategoryIds};
    final previousIds = categories
        .where((c) => c.id == category.id)
        .expand((c) => c.sharedBudgetCategoryIds)
        .toSet();
    if (category.type != TransactionType.expense ||
        category.sharedBudgetCategoryIds.any(
          (id) =>
              id == category.id ||
              (!previousIds.contains(id) &&
                  !categories.any(
                    (c) =>
                        c.id == id &&
                        c.type == TransactionType.expense &&
                        !c.hasBudget,
                  )),
        )) {
      throw StateError(
        'Shared budgets require expense categories without another budget.',
      );
    }
    for (final other in categories) {
      if (other.id == category.id || !other.hasBudget) continue;
      if ({
        other.id,
        ...other.sharedBudgetCategoryIds,
      }.intersection(selectedIds).isNotEmpty) {
        throw StateError('A category can only belong to one budget.');
      }
    }
  }

  Future<void> setArchived(String id, bool archived) async {
    final current = (await _repository.getCategories()).firstWhere(
      (c) => c.id == id,
    );
    await editCategory(current.copyWith(isArchived: archived));
  }

  Future<void> reorderCategories(
    int oldIndex,
    int newIndex,
    TransactionType type, {
    List<String>? visibleIds,
  }) async {
    final categories = state.value;
    if (categories == null || _reordering) return;
    final previousState = state;

    // Filter categories by type to reorder within that type
    final typeCategories = categories
        .where((c) => c.type == type && !c.isArchived)
        .toList();
    final otherCategories = categories
        .where((c) => c.type != type || c.isArchived)
        .toList();

    final visible = typeCategories
        .where(
          (category) => visibleIds == null || visibleIds.contains(category.id),
        )
        .toList();
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }
    final visibleSet = visible.map((category) => category.id).toSet();
    final item = visible.removeAt(oldIndex);
    visible.insert(newIndex, item);
    var visibleIndex = 0;
    final reordered = typeCategories
        .map(
          (category) => visibleSet.contains(category.id)
              ? visible[visibleIndex++]
              : category,
        )
        .toList();

    // Update positions for type categories
    final updatedTypeCategories = <TransactionCategory>[];
    for (int i = 0; i < reordered.length; i++) {
      updatedTypeCategories.add(reordered[i].copyWith(position: i));
    }

    // Combine and sort to maintain state consistency
    final updatedAll = [...updatedTypeCategories, ...otherCategories];
    updatedAll.sort((a, b) {
      // Primary sort by type (Expenses first, or whatever)
      if (a.type != b.type) return a.type == TransactionType.expense ? -1 : 1;
      // Secondary sort by position
      return a.position.compareTo(b.position);
    });

    _reordering = true;
    state = AsyncValue.data(updatedAll);

    // Update database
    try {
      await _repository.updateCategoryPositions(updatedTypeCategories);
    } catch (e, stackTrace) {
      if (identical(state.value, updatedAll)) state = previousState;
      dev.log(
        'Error updating category positions',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      _reordering = false;
    }
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoryNotifier, List<TransactionCategory>>(() {
      return CategoryNotifier();
    });

/// Reactive provider for monthly category budgets and progress metrics.
final monthlyBudgetOverviewProvider = Provider.family<BudgetOverview, DateTime>(
  (ref, month) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final stats = ref.watch(monthlyDashboardStatsProvider(month));
    return BudgetOverview.calculate(
      categories: categories,
      categorySpending: stats.categorySpending,
      totalIncome: stats.totalIncome,
    );
  },
);
