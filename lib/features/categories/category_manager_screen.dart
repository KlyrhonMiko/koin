import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/features/categories/category_detail_screen.dart';

class CategoryManagerScreen extends ConsumerWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.category_outlined, size: 48, color: AppTheme.textLightColor(context).withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No categories yet',
                    style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _CategoryTile(category: category, index: index);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CategoryDetailScreen(),
            ),
          );
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final TransactionCategory category;
  final int index;

  const _CategoryTile({required this.category, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
            color: category.color,
            size: 22,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: AppTheme.textLightColor(context)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailScreen(category: category),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    ).animate().fade(delay: (index * 50).ms).slideY(begin: 0.06);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).deleteCategory(category.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }
}
