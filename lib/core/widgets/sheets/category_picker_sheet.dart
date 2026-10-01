import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'select_sheet.dart';

/// Deep Category Picker Module: Encapsulates category filtering by TransactionType,
/// styling, and sheet presentation behind a single method call.
Future<String?> showCategoryPickerSheet({
  required BuildContext context,
  WidgetRef? ref,
  required String? selectedCategoryId,
  required TransactionType type,
  String title = 'Category',
  String subtitle = 'Choose a category',
  Color? indicatorColor,
  List<TransactionCategory>? categoriesOverride,
}) async {
  final allCategories = categoriesOverride ?? (ref?.read(categoriesProvider).value ?? []);
  final filteredCategories = allCategories
      .where((c) => c.type == type)
      .toList();

  return await showSelectSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    itemCount: filteredCategories.length,
    itemBuilder: (sheetContext, index) {
      final cat = filteredCategories[index];
      return SelectSheetItem(
        name: cat.name,
        accentColor: cat.color,
        iconCodePoint: cat.iconCodePoint,
        selected: cat.id == selectedCategoryId,
        onTap: () => Navigator.pop(sheetContext, cat.id),
      );
    },
  );
}
