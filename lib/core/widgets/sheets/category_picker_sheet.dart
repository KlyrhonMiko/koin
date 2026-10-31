import 'package:koin/core/icons.dart';
import 'package:koin/features/categories/category_detail_screen.dart';

import '../primitives/koin_error_state.dart';

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
}) async {
  return showSelectSheet<String>(
    context: context,
    title: title,
    subtitle: subtitle,
    itemCount: 0,
    itemBuilder: (_, index) => const SizedBox.shrink(),
    searchable: true,
    optionsBuilder: (sheetContext, query) => Consumer(
      builder: (context, liveRef, _) {
        final state = liveRef.watch(categoriesProvider);
        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, stack) => KoinErrorState(
            message: 'Could not load categories.',
            onRetry: () => liveRef.invalidate(categoriesProvider),
          ),
          data: (all) {
            final categories = all
                .where(
                  (c) =>
                      c.type == type &&
                      (!c.isArchived || c.id == selectedCategoryId),
                )
                .toList();
            return SelectSheetOptions(
              itemCount: categories.length,
              labelForIndex: (i) => categories[i].name,
              query: query,
              emptyMessage: 'No active categories for this transaction type',
              emptyAction: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryDetailScreen(initialType: type),
                  ),
                ),
                icon: const Icon(KoinIcons.plus),
                label: const Text('Create category'),
              ),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return SelectSheetItem(
                  name: cat.name,
                  accentColor: cat.color,
                  iconCodePoint: cat.iconCodePoint,
                  selected: cat.id == selectedCategoryId,
                  onTap: () => Navigator.pop(sheetContext, cat.id),
                );
              },
            );
          },
        );
      },
    ),
  );
}
