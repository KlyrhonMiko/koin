import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/transaction_filter.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/date_range_selector.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late TransactionFilter _filter;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = ref.read(transactionFilterProvider);
    _minAmountController.text = _filter.minAmount?.toString() ?? '';
    _maxAmountController.text = _filter.maxAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filter.type != null) count++;
    if (_filter.dateRange != null) count++;
    if (_filter.categoryIds.isNotEmpty) count += _filter.categoryIds.length;
    if (_filter.accountIds.isNotEmpty) count += _filter.accountIds.length;
    if (_minAmountController.text.isNotEmpty) count++;
    if (_maxAmountController.text.isNotEmpty) count++;
    return count;
  }

  void _apply() {
    final min = double.tryParse(_minAmountController.text);
    final max = double.tryParse(_maxAmountController.text);

    final finalFilter = _filter.copyWith(
      minAmount: min,
      maxAmount: max,
      clearMinAmount: _minAmountController.text.isEmpty,
      clearMaxAmount: _maxAmountController.text.isEmpty,
    );

    ref.read(transactionFilterProvider.notifier).updateFilter(finalFilter);
    HapticService.medium();
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _filter = const TransactionFilter();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    HapticService.light();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountProvider).value ?? [];
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final primary = AppTheme.primaryColor(context);
    final filterCount = _activeFilterCount;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Handle ──
          const Gap(12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(20),

          // ── Header ──
          Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (filterCount > 0) ...[
                      const Gap(10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$filterCount',
                          style: TextStyle(
                            color: primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PressableScale(
                      onTap: _reset,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.dividerColor(
                              context,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'Reset All',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(
                begin: -0.1,
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              ),

          const Gap(16),

          // ── Gradient divider ──
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.dividerColor(context).withValues(alpha: 0),
                  AppTheme.dividerColor(context).withValues(alpha: 0.5),
                  AppTheme.dividerColor(context).withValues(alpha: 0),
                ],
              ),
            ),
          ),

          // ── Scrollable content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
              children: [
                // Transaction Type
                _buildSectionTitle('Transaction Type', Icons.swap_vert_rounded)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(12),
                SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeChip(null, 'All', Icons.grid_view_rounded),
                          const Gap(8),
                          _buildTypeChip(
                            TransactionType.income,
                            'Income',
                            Icons.arrow_downward_rounded,
                          ),
                          const Gap(8),
                          _buildTypeChip(
                            TransactionType.expense,
                            'Expense',
                            Icons.arrow_upward_rounded,
                          ),
                          const Gap(8),
                          _buildTypeChip(
                            TransactionType.transfer,
                            'Transfer',
                            Icons.swap_horiz_rounded,
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 300.ms)
                    .slideX(
                      begin: 0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),

                const Gap(28),

                // Date Range
                _buildSectionTitle('Date Range', Icons.calendar_today_rounded)
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(12),
                DateRangeSelector(
                  initialDateRange: _filter.dateRange,
                  showClearButton: true,
                  onChanged: (range) {
                    setState(() {
                      _filter = _filter.copyWith(
                        dateRange: range,
                        clearDateRange: range == null,
                      );
                    });
                  },
                ).animate().fadeIn(delay: 250.ms, duration: 300.ms),

                const Gap(28),

                // Categories
                _buildSectionTitle('Categories', Icons.category_rounded)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: categories
                      .map((c) => _buildCategoryChip(c))
                      .toList(),
                ).animate().fadeIn(delay: 350.ms, duration: 300.ms),

                const Gap(28),

                // Accounts
                _buildSectionTitle(
                      'Accounts',
                      Icons.account_balance_wallet_rounded,
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: accounts.map((a) => _buildAccountChip(a)).toList(),
                ).animate().fadeIn(delay: 450.ms, duration: 300.ms),

                const Gap(28),

                // Amount Range
                _buildSectionTitle('Amount Range', Icons.payments_rounded)
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 300.ms)
                    .slideX(
                      begin: -0.05,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountField(
                        _minAmountController,
                        'Min',
                        currency.symbol,
                      ),
                    ),
                    const Gap(12),
                    Container(
                      width: 20,
                      height: 1.5,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor(
                          context,
                        ).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: _buildAmountField(
                        _maxAmountController,
                        'Max',
                        currency.symbol,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 550.ms, duration: 300.ms),
              ],
            ),
          ),

          // ── Frosted Apply Button ──
          ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(
                        context,
                      ).withValues(alpha: 0.85),
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    child: PressableScale(
                      onTap: _apply,
                      hapticLevel: HapticLevel.medium,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient(context),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const Gap(8),
                            Text(
                              filterCount > 0
                                  ? 'Apply $filterCount Filter${filterCount > 1 ? 's' : ''}'
                                  : 'Apply Filters',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 300.ms)
              .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  // ── Section Title with accent bar ──
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.textLightColor(context).withValues(alpha: 0.5),
        ),
        const Gap(6),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Type Chip with icon ──
  Widget _buildTypeChip(TransactionType? type, String label, IconData icon) {
    final isSelected = _filter.type == type;
    final primary = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          _filter = _filter.copyWith(type: type, clearType: type == null);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary : AppTheme.surfaceLightColor(context),
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? null
              : Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : AppTheme.textLightColor(context),
            ),
            const Gap(6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Chip with animated checkmark ──
  Widget _buildCategoryChip(dynamic category) {
    final isSelected = _filter.categoryIds.contains(category.id);
    final primary = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          final newIds = Set<String>.from(_filter.categoryIds);
          if (isSelected) {
            newIds.remove(category.id);
          } else {
            newIds.add(category.id);
          }
          _filter = _filter.copyWith(categoryIds: newIds);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.12)
              : AppTheme.surfaceLightColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.4)
                : AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, size: 15, color: primary),
              const Gap(6),
            ] else ...[
              Icon(
                IconUtils.getIcon(category.iconCodePoint),
                size: 14,
                color: category.color,
              ),
              const Gap(6),
            ],
            Text(
              category.name,
              style: TextStyle(
                color: isSelected ? primary : AppTheme.textColor(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Account Chip with animated checkmark ──
  Widget _buildAccountChip(dynamic account) {
    final isSelected = _filter.accountIds.contains(account.id);
    final primary = AppTheme.primaryColor(context);

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          final newIds = Set<String>.from(_filter.accountIds);
          if (isSelected) {
            newIds.remove(account.id);
          } else {
            newIds.add(account.id);
          }
          _filter = _filter.copyWith(accountIds: newIds);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.12)
              : AppTheme.surfaceLightColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.4)
                : AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, size: 15, color: primary),
              const Gap(6),
            ],
            Text(
              account.name,
              style: TextStyle(
                color: isSelected ? primary : AppTheme.textColor(context),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Amount input field with currency prefix ──
  Widget _buildAmountField(
    TextEditingController controller,
    String label,
    String currencySymbol,
  ) {
    final primary = AppTheme.primaryColor(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppTheme.textColor(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textLightColor(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Text(
            currencySymbol,
            style: TextStyle(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: AppTheme.surfaceLightColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }
}
