import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/category_repository.dart';
import 'dart:developer' as dev;

class CategoryNotifier extends AsyncNotifier<List<TransactionCategory>> {
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
    }
  }

  Future<void> editCategory(TransactionCategory category) async {
    if (!state.hasValue) return;

    final previousState = state;
    final currentCategories = state.value!;

    state = AsyncValue.data(
      currentCategories.map((c) => c.id == category.id ? category : c).toList(),
    );

    try {
      await _repository.updateCategory(category);
    } catch (e, st) {
      state = previousState;
      dev.log('Error updating category', error: e, stackTrace: st);
    }
  }

  Future<void> deleteCategory(String id) async {
    await _repository.deleteCategory(id);
    await _loadCategories();
  }

  Future<void> reorderCategories(
    int oldIndex,
    int newIndex,
    TransactionType type,
  ) async {
    final categories = state.value;
    if (categories == null) return;

    // Filter categories by type to reorder within that type
    final typeCategories = categories.where((c) => c.type == type).toList();
    final otherCategories = categories.where((c) => c.type != type).toList();

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
      await _repository.updateCategoryPositions(
        updatedTypeCategories,
      );
    } catch (e, stackTrace) {
      dev.log(
        'Error updating category positions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoryNotifier, List<TransactionCategory>>(() {
      return CategoryNotifier();
    });
