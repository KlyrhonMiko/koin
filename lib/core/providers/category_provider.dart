import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/category.dart';

class CategoryNotifier extends Notifier<List<TransactionCategory>> {
  @override
  List<TransactionCategory> build() {
    _loadCategories();
    return [];
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseHelper.instance.getCategories();
    state = categories;
  }

  Future<void> addCategory(TransactionCategory category) async {
    await DatabaseHelper.instance.insertCategory(category);
    await _loadCategories();
  }

  Future<void> editCategory(TransactionCategory category) async {
    await DatabaseHelper.instance.updateCategory(category);
    await _loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    await _loadCategories();
  }
}

final categoryProvider = NotifierProvider<CategoryNotifier, List<TransactionCategory>>(() {
  return CategoryNotifier();
});
