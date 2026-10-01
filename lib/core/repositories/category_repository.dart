import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving categories.
abstract class CategoryRepository {
  Future<List<TransactionCategory>> getCategories();
  Future<TransactionCategory> insertCategory(TransactionCategory category);
  Future<void> updateCategory(TransactionCategory category);
  Future<void> deleteCategory(String id);
  Future<void> updateCategoryPositions(List<TransactionCategory> categories);
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteCategoryAdapter implements CategoryRepository {
  final DatabaseHelper _dbHelper;

  SqliteCategoryAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<TransactionCategory>> getCategories() => _dbHelper.getCategories();

  @override
  Future<TransactionCategory> insertCategory(TransactionCategory category) =>
      _dbHelper.insertCategory(category);

  @override
  Future<void> updateCategory(TransactionCategory category) async {
    await _dbHelper.updateCategory(category);
  }

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
  Future<TransactionCategory> insertCategory(TransactionCategory category) async {
    _categories.removeWhere((c) => c.id == category.id);
    _categories.add(category);
    _sort();
    return category;
  }

  @override
  Future<void> updateCategory(TransactionCategory category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      _categories[idx] = category;
      _sort();
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> updateCategoryPositions(List<TransactionCategory> categories) async {
    for (final updated in categories) {
      final idx = _categories.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        _categories[idx] = _categories[idx].copyWith(position: updated.position);
      }
    }
    _sort();
  }
}

/// Riverpod provider exposing the CategoryRepository seam.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SqliteCategoryAdapter();
});
