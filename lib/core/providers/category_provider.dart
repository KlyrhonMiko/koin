import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'dart:developer' as dev;

class CategoryNotifier extends AsyncNotifier<List<TransactionCategory>> {
  @override
  Future<List<TransactionCategory>> build() async {
    return await DatabaseHelper.instance.getCategories();
  }

  Future<void> _loadCategories() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getCategories();
    });
  }

  Future<void> addCategory(TransactionCategory category) async {
    final currentCategories = state.value ?? [];
    final categoryWithPosition = category.copyWith(position: currentCategories.length);
    await DatabaseHelper.instance.insertCategory(categoryWithPosition);
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

  Future<void> reorderCategories(int oldIndex, int newIndex, TransactionType type) async {
    final categories = state.value;
    if (categories == null) return;

    // Filter categories by type to reorder within that type
    final typeCategories = categories.where((c) => c.type == type).toList();
    final otherCategories = categories.where((c) => c.type != type).toList();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = typeCategories.removeAt(oldIndex);
    typeCategories.insert(newIndex, item);

    // Update positions for type categories
    final updatedTypeCategories = <TransactionCategory>[];
    for (int i = 0; i < typeCategories.length; i++) {
      updatedTypeCategories.add(typeCategories[i].copyWith(position: i));
    }

    // Combine and sort to maintain state consistency
    final updatedAll = [...updatedTypeCategories, ...otherCategories];
    updatedAll.sort((a, b) {
      // Primary sort by type (Expenses first, or whatever)
      if (a.type != b.type) return a.type == TransactionType.expense ? -1 : 1;
      // Secondary sort by position
      return a.position.compareTo(b.position);
    });

    state = AsyncValue.data(updatedAll);

    // Update database
    try {
      await DatabaseHelper.instance.updateCategoryPositions(updatedTypeCategories);
    } catch (e, stackTrace) {
      dev.log('Error updating category positions', error: e, stackTrace: stackTrace);
    }
  }
}

final categoriesProvider = AsyncNotifierProvider<CategoryNotifier, List<TransactionCategory>>(() {
  return CategoryNotifier();
});
