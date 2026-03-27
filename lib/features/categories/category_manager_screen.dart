import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/providers/category_provider.dart';

import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/utils/haptic_utils.dart';

import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/features/categories/category_detail_screen.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  bool _showSearch = false;
  late TabController _tabController;
  bool _showEntranceAnimations = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Only show entrance animations once
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showEntranceAnimations = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  final filtered = categories.where((c) {
                    final matchesSearch = _searchQuery.isEmpty || 
                        c.name.toLowerCase().contains(_searchQuery.toLowerCase());
                    return matchesSearch;
                  }).toList();

                  final expenseCategories = filtered.where((c) => c.type == TransactionType.expense).toList();
                  final incomeCategories = filtered.where((c) => c.type == TransactionType.income).toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      expenseCategories.isEmpty
                          ? _buildEmptyState(context, TransactionType.expense)
                          : _buildCategoryList(context, expenseCategories, currency, TransactionType.expense),
                      incomeCategories.isEmpty
                          ? _buildEmptyState(context, TransactionType.income)
                          : _buildCategoryList(context, incomeCategories, currency, TransactionType.income),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  HapticService.light();
                  Navigator.pop(context);
                },
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: AppTheme.textColor(context)),
                ),
              ),
              Expanded(
                child: _showSearch
                    ? _buildSearchField(context)
                    : Center(
                        child: Text(
                          'Manage Categories',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    _showSearch ? Icons.close_rounded : Icons.search_rounded,
                    size: 18,
                    color: AppTheme.textColor(context),
                  ),
                ),
                onPressed: () {
                  HapticService.light();
                  setState(() {
                    if (_showSearch) {
                      _showSearch = false;
                      _searchQuery = '';
                    } else {
                      _showSearch = true;
                    }
                  });
                },
              ),
            ],
          ).animate().fade(duration: 400.ms).slideY(begin: -0.2),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSegmentedControl(context),
          ).animate().fade(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / 2;
                  final animationValue = _tabController.animation!.value;
                  
                  return Stack(
                    children: [
                      // Real-time tracking Indicator
                      Positioned(
                        top: 4,
                        bottom: 4,
                        left: 4 + (tabWidth - 4) * animationValue,
                        width: tabWidth - 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor(context),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: 3,
                              width: 32,
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor(context).withValues(alpha: 0.6),
                                    AppTheme.primaryColor(context),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticService.selection();
                                _tabController.animateTo(0);
                              },
                              child: Center(
                                child: Text(
                                  'Expenses',
                                  style: TextStyle(
                                    fontWeight: _tabController.index == 0 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabController.index == 0 ? AppTheme.primaryColor(context) : AppTheme.textLightColor(context),
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticService.selection();
                                _tabController.animateTo(1);
                              },
                              child: Center(
                                child: Text(
                                  'Income',
                                  style: TextStyle(
                                    fontWeight: _tabController.index == 1 ? FontWeight.w700 : FontWeight.w600,
                                    color: _tabController.index == 1 ? AppTheme.primaryColor(context) : AppTheme.textLightColor(context),
                                    fontSize: 14,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
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

  Widget _buildEmptyState(BuildContext context, TransactionType type) {
    final isExpense = type == TransactionType.expense;
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
                  color: (isExpense ? AppTheme.expenseColor(context) : AppTheme.incomeColor(context)).withValues(alpha: 0.08),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              isExpense ? Icons.category_outlined : Icons.add_chart_rounded,
              size: 52,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.3),
            ),
          ),
          const Gap(28),
          Text(
            isExpense ? 'No expense categories' : 'No income categories',
            style: TextStyle(
              color: AppTheme.textColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(8),
          Text(
            'Create your first ${isExpense ? 'expense' : 'income'} category',
            style: TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: 14,
            ),
          ),
          const Gap(28),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isExpense ? AppTheme.dangerGradient : AppTheme.successGradient,
              boxShadow: [
                BoxShadow(
                  color: (isExpense ? AppTheme.expenseColor(context) : AppTheme.incomeColor(context)).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
            onPressed: () {
              HapticService.medium();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoryDetailScreen(category: null, initialType: type)),
              );
            },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Create ${isExpense ? 'Expense' : 'Income'}', style: const TextStyle(color: Colors.white)),
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

  Widget _buildCategoryList(BuildContext context, List<TransactionCategory> categories, currency, TransactionType type) {
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) {
        HapticService.medium();
        ref.read(categoriesProvider.notifier).reorderCategories(oldIndex, newIndex, type);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final elevation = Curves.easeOut.transform(animation.value) * 16;
            final scale = 1.0 + (Curves.easeOut.transform(animation.value) * 0.03);
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                shadowColor: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      header: Padding(
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
      ).animate(autoPlay: _showEntranceAnimations, key: ValueKey('header_${type.name}')).fade(duration: 300.ms),
      footer: Column(
        children: [
          const Gap(6),
          GestureDetector(
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoryDetailScreen(initialType: type)),
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
                      color: (type == TransactionType.expense ? AppTheme.expenseColor(context) : AppTheme.incomeColor(context)).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: type == TransactionType.expense ? AppTheme.expenseColor(context) : AppTheme.incomeColor(context),
                    ),
                  ),
                  const Gap(10),
                  Text(
                    'Add ${type == TransactionType.expense ? 'Expense' : 'Income'} Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: type == TransactionType.expense ? AppTheme.expenseColor(context) : AppTheme.incomeColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ).animate(autoPlay: _showEntranceAnimations, key: ValueKey('footer_${type.name}')).fade(delay: 100.ms),
        ],
      ),
      itemBuilder: (context, index) {
        final category = categories[index];

        return Dismissible(
            key: Key('dismiss_${category.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) {
              HapticService.medium();
              return _confirmDelete(context, category);
            },
            onDismissed: (_) {
              HapticService.heavy();
              ref.read(categoriesProvider.notifier).deleteCategory(category.id);
            },
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
                HapticService.light();
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
                          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                          child: Row(
                            children: [
                              // Drag handle
                              Listener(
                                onPointerDown: (_) => HapticService.light(),
                                child: ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: AppTheme.textLightColor(context).withValues(alpha: 0.25),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(8),
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
                                  IconUtils.getIcon(category.iconCodePoint),
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (category.type == TransactionType.expense && ((category.budget != null && category.budget! > 0) || (category.isPercentBudget && category.budgetPercent != null && category.budgetPercent! > 0))) ...[
                                      const Gap(4),
                                      Text(
                                        category.isPercentBudget
                                            ? 'Budget: ${category.budgetPercent?.toStringAsFixed(0)}% of income'
                                            : 'Budget: ${fmt.format(category.budget)}',
                                        style: TextStyle(
                                          color: AppTheme.textLightColor(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Gap(8),
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
        ).animate(autoPlay: _showEntranceAnimations, key: ValueKey(category.id)).fade(delay: (index * 50).ms).slideX(begin: 0.04);
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, TransactionCategory category) {
    return ConfirmationSheet.show(
      context: context,
      title: 'Delete Category?',
      description: 'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_forever_rounded,
      isDanger: true,
    );
  }
}
