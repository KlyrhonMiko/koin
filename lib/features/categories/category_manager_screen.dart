import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/categories/category_detail_screen.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() =>
      _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  bool _showSearch = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        HapticService.selection();
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
                    final matchesSearch =
                        _searchQuery.isEmpty ||
                        c.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        );
                    return matchesSearch && !c.isArchived;
                  }).toList();

                  final expenseCategories = filtered
                      .where((c) => c.type == TransactionType.expense)
                      .toList();
                  final incomeCategories = filtered
                      .where((c) => c.type == TransactionType.income)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      CategoryList(
                        key: const PageStorageKey('expense_list'),
                        categories: expenseCategories,
                        type: TransactionType.expense,
                        currency: currency,
                      ),
                      CategoryList(
                        key: const PageStorageKey('income_list'),
                        categories: incomeCategories,
                        type: TransactionType.income,
                        currency: currency,
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => KoinErrorState(
                  onRetry: () => ref.invalidate(categoriesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        8,
        KoinSpacing.screenInset,
        16,
      ),
      child: Column(
        children: [
          Row(
                children: [
                  const KoinBackButton(),
                  Expanded(
                    child: _showSearch
                        ? _buildSearchField(context)
                        : Center(
                            child: Text(
                              'Manage Categories',
                              style: TextStyle(
                                fontSize: KoinTypography.sectionTitle,
                                fontWeight: KoinTypography.headingWeight,
                                letterSpacing: KoinTypography.headingTracking,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context)
                            .withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppTheme.dividerColor(context)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        _showSearch
                            ? Icons.close_rounded
                            : Icons.search_rounded,
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
              )
              .koinAnimate(
                context,
                autoPlay: !MediaQuery.disableAnimationsOf(context),
                onInit: KoinMotion.onInit(context),
              )
              .fade(duration: 250.ms)
              .slideY(begin: -0.2),
          const SizedBox(height: 16),
          Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: KoinSegmentedControl(
                  controller: _tabController,
                  leftLabel: 'Expenses',
                  rightLabel: 'Income',
                ),
              )
              .koinAnimate(
                context,
                autoPlay: !MediaQuery.disableAnimationsOf(context),
                onInit: KoinMotion.onInit(context),
              )
              .fade(delay: 100.ms)
              .scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return KoinSearchField(
      hintText: 'Search categories...',
      inline: true,
      autofocus: true,
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildEmptyState(BuildContext context, TransactionType type) {
    final isExpense = type == TransactionType.expense;
    return KoinEmptyState(
      fullScreen: true,
      icon: isExpense ? Icons.category_outlined : Icons.add_chart_rounded,
      title: isExpense ? 'No expense categories' : 'No income categories',
      subtitle:
          'Create your first ${isExpense ? 'expense' : 'income'} category',
      action: KoinPrimaryButton(
        label: 'Create ${isExpense ? 'Expense' : 'Income'}',
        icon: Icons.add_rounded,
        onPressed: () {
          HapticService.medium();
          Navigator.push(
            context,
            SlideUpRoute(page: CategoryDetailScreen(initialType: type)),
          );
        },
      ),
    );
  }
}

class CategoryList extends ConsumerStatefulWidget {
  final List<TransactionCategory> categories;
  final TransactionType type;
  final Currency currency;

  const CategoryList({
    super.key,
    required this.categories,
    required this.type,
    required this.currency,
  });

  @override
  ConsumerState<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends ConsumerState<CategoryList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.categories.isEmpty) {
      return context
          .findAncestorStateOfType<_CategoryManagerScreenState>()!
          ._buildEmptyState(context, widget.type);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        8,
        KoinSpacing.screenInset,
        100,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.categories.length,
      onReorderItem: (oldIndex, newIndex) {
        HapticService.medium();
        ref
            .read(categoriesProvider.notifier)
            .reorderCategories(oldIndex, newIndex, widget.type);
      },
      proxyDecorator: koinReorderProxyDecorator,
      header: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Text(
              '${widget.categories.length} ${widget.categories.length == 1 ? 'Category' : 'Categories'}',
              style: TextStyle(
                fontSize: KoinTypography.compact,
                fontWeight: KoinTypography.labelWeight,
                color: AppTheme.textLightColor(context),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ).koinEntrance(context, token: 'category_header_${widget.type.name}'),
      footer: Column(
        children: [
          const Gap(6),
          PressableScale(
            onTap: () {
              HapticService.medium();
              Navigator.push(
                context,
                SlideUpRoute(
                  page: CategoryDetailScreen(initialType: widget.type),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.dividerColor(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          (widget.type == TransactionType.expense
                                  ? AppTheme.expenseColor(context)
                                  : AppTheme.incomeColor(context))
                              .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: widget.type == TransactionType.expense
                          ? AppTheme.expenseColor(context)
                          : AppTheme.incomeColor(context),
                    ),
                  ),
                  const Gap(10),
                  Text(
                    'Add ${widget.type == TransactionType.expense ? 'Expense' : 'Income'} Category',
                    style: TextStyle(
                      fontWeight: KoinTypography.labelWeight,
                      fontSize: KoinTypography.compact,
                      color: widget.type == TransactionType.expense
                          ? AppTheme.expenseColor(context)
                          : AppTheme.incomeColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ).koinEntrance(context, token: 'category_footer_${widget.type.name}'),
        ],
      ),
      itemBuilder: (context, index) {
        final category = widget.categories[index];

        return SwipeToDeleteTile(
          key: Key('dismiss_${category.id}'),
          margin: const EdgeInsets.only(bottom: 10),
          borderRadius: BorderRadius.circular(20),
          confirmTitle: 'Delete Category?',
          confirmDescription:
              'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
          icon: Icons.delete_forever_rounded,
          onDelete: () async {
            HapticService.heavy();
            await ref
                .read(categoriesProvider.notifier)
                .deleteCategory(category.id);
          },
          child: CategoryItem(
            category: category,
            currency: widget.currency,
            onTap: () {
              HapticService.light();
              Navigator.push(
                context,
                SlideUpRoute(page: CategoryDetailScreen(category: category)),
              );
            },
            leading: Listener(
              onPointerDown: (_) => HapticService.light(),
              child: ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppTheme.textLightColor(context)
                        .withValues(alpha: 0.25),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ).koinEntrance(context, token: 'category_row_${category.id}');
      },
    );
  }
}
