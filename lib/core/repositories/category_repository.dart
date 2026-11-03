import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving categories.
abstract class CategoryRepository {
  Future<List<TransactionCategory>> getCategories();
  Future<TransactionCategory> insertCategory(TransactionCategory category);
  Future<void> updateCategory(TransactionCategory category);
  Future<void> updateBudgets(List<TransactionCategory> categories);
  Future<void> deleteCategory(String id);
  Future<void> updateCategoryPositions(List<TransactionCategory> categories);
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteCategoryAdapter implements CategoryRepository {
  final DatabaseHelper _dbHelper;

  SqliteCategoryAdapter({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<TransactionCategory>> getCategories() =>
      _dbHelper.getCategories();

  @override
  Future<TransactionCategory> insertCategory(TransactionCategory category) =>
      _dbHelper.insertCategory(category);

  @override
  Future<void> updateCategory(TransactionCategory category) async {
    await _dbHelper.updateCategory(category);
  }

  @override
  Future<void> updateBudgets(List<TransactionCategory> categories) =>
      _dbHelper.updateCategoryBudgets(categories);

  @override
  Future<void> deleteCategory(String id) async {
    await _dbHelper.deleteCategory(id);
  }

  @override
  Future<void> updateCategoryPositions(List<TransactionCategory> categories) =>
      _dbHelper.updateCategoryPositions(categories);
}

/// In-Memory Test Adapter: provides deterministic category persistence for testing.
class InMemoryCategoryAdapter implements CategoryRepository {
  final List<TransactionCategory> _categories = [];

  InMemoryCategoryAdapter({List<TransactionCategory> initial = const []}) {
    _categories.addAll(initial);
    _sort();
  }

  void _sort() {
    _categories.sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  Future<List<TransactionCategory>> getCategories() async {
    _sort();
    return List.unmodifiable(_categories);
  }

  @override
  Future<TransactionCategory> insertCategory(
    TransactionCategory category,
  ) async {
    _categories.removeWhere((c) => c.id == category.id);
    _categories.add(category);
    _sort();
    return category;
  }

  @override
  Future<void> updateCategory(TransactionCategory category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      if (category.type != TransactionType.expense) {
        _detachBudgetCategory(category.id);
      }
      _categories[idx] = category.type == TransactionType.expense
          ? category
          : category.withoutBudget();
      _sort();
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    _detachBudgetCategory(id);
    _categories.removeWhere((c) => c.id == id);
  }

  void _detachBudgetCategory(String id) {
    for (final updated in TransactionCategory.detachFromBudgets(
      _categories,
      id,
    )) {
      final index = _categories.indexWhere((c) => c.id == updated.id);
      _categories[index] = updated;
    }
  }

  @override
  Future<void> updateBudgets(List<TransactionCategory> categories) async {
    if (categories.any(
      (updated) => !_categories.any((c) => c.id == updated.id),
    )) {
      throw StateError('A selected category is no longer available.');
    }
    for (final updated in categories) {
      final index = _categories.indexWhere((c) => c.id == updated.id);
      final current = _categories[index];
      _categories[index] = current.withBudgetFrom(updated);
    }
  }

  @override
  Future<void> updateCategoryPositions(
    List<TransactionCategory> categories,
  ) async {
    for (final updated in categories) {
      final idx = _categories.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        _categories[idx] = _categories[idx].copyWith(
          position: updated.position,
        );
      }
    }
    _sort();
  }
}

/// Riverpod provider exposing the CategoryRepository seam.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SqliteCategoryAdapter();
});
