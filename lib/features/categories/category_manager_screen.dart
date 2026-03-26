import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/navigation_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';

import 'package:koin/features/categories/category_detail_screen.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> {
  String _searchQuery = '';
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    final filtered = _searchQuery.isEmpty
        ? categories
        : categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? _buildSearchField(context)
            : const Text('Manage Categories'),
        actions: [
          if (!_showSearch && categories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 22),
              onPressed: () => setState(() => _showSearch = true),
            ),
          if (_showSearch)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 22),
              onPressed: () => setState(() {
                _showSearch = false;
                _searchQuery = '';
              }),
            ),
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'Manage Budgets',
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
                ref.read(navigationProvider.notifier).setIndex(4);
                ref.read(pageControllerProvider).animateToPage(
                  4,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            const Gap(8),
          ],
        ],
      ),
      body: categories.isEmpty
          ? _buildEmptyState(context)
          : _buildCategoryList(context, filtered, currency),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return TextField(
      autofocus: true,
      style: TextStyle(
        color: AppTheme.textColor(context),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Search categories...',
        hintStyle: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.08),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Icons.category_outlined,
              size: 52,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
          ),
          const Gap(28),
          Text(
            'No categories yet',
            style: TextStyle(
              color: AppTheme.textColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          Text(
            'Create your first category to get started',
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: 14,
            ),
          ),
          const Gap(28),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppTheme.primaryGradient(context),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CategoryDetailScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildCategoryList(BuildContext context, List<TransactionCategory> categories, currency) {
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      children: [
        // Category count header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text(
                '${categories.length} ${categories.length == 1 ? 'Category' : 'Categories'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textLightColor(context),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ).animate().fade(duration: 300.ms),

        // Category tiles
        ...categories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;

          return Dismissible(
            key: Key(category.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(context, category),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.dangerGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                  Gap(4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailScreen(category: category),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.dividerColor(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                          child: Row(
                            children: [
                              // Glowing icon
                              Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: category.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: category.color.withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  IconData(category.iconCodePoint, fontFamily: 'MaterialIcons'),
                                  color: category.color,
                                  size: 22,
                                ),
                              ),
                              const Gap(14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (category.budget != null && category.budget! > 0) ...[
                                      const Gap(4),
                                      Text(
                                        'Budget: ${fmt.format(category.budget)}',
                                        style: TextStyle(
                                          color: AppTheme.textLightColor(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.04);
        }),

        // Add category card
        const Gap(6),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoryDetailScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.dividerColor(context),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: AppTheme.primaryColor(context),
                  ),
                ),
                const Gap(10),
                Text(
                  'Add Category',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.primaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ).animate().fade(delay: (categories.length * 50 + 100).ms),
      ],
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, TransactionCategory category) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(categoryProvider.notifier).deleteCategory(category.id);
              Navigator.pop(context, true);
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppTheme.expenseColor(context)),
            ),
          ),
        ],
      ),
    );
  }
}
