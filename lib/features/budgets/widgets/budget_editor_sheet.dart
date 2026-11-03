import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

import 'budget_category_picker_sheet.dart';

class BudgetEditorSheet extends ConsumerStatefulWidget {
  final TransactionCategory? category;
  final List<String> initialCategoryIds;
  final Currency currency;
  final double totalIncome;

  const BudgetEditorSheet({
    super.key,
    this.category,
    this.initialCategoryIds = const [],
    required this.currency,
    required this.totalIncome,
  });

  /// Presents [BudgetEditorSheet] in a standardized modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    TransactionCategory? category,
    Set<String> initialCategoryIds = const {},
    required Currency currency,
    required double totalIncome,
  }) async {
    HapticService.light();
    Set<String>? selected;
    if (category == null) {
      selected = await BudgetCategoryPickerSheet.show(
        context,
        selectedIds: initialCategoryIds,
        continueToLimit: true,
      );
      if (selected == null || selected.isEmpty || !context.mounted) return;
    }
    return showEditorBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetEditorSheet(
        category: category,
        initialCategoryIds: selected?.toList() ?? const [],
        currency: currency,
        totalIncome: totalIncome,
      ),
    );
  }

  @override
  ConsumerState<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<BudgetEditorSheet> {
  late bool _isPercentMode;
  late String _currentExpression;
  late String _currentResult;
  String? _validationError;
  bool _saving = false;
  bool _saved = false;
  late final Set<String> _selectedCategoryIds;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _selectedCategoryIds = {
      if (category != null) ...[
        category.id,
        ...category.sharedBudgetCategoryIds,
      ],
      ...widget.initialCategoryIds,
    };
    _isPercentMode = category?.isPercentBudget ?? false;
    if (_isPercentMode &&
        category?.budgetPercent != null &&
        category!.budgetPercent! > 0) {
      _currentExpression = NumberFormat('0.##').format(category.budgetPercent!);
    } else if (!_isPercentMode &&
        category?.budget != null &&
        category!.budget! > 0) {
      _currentExpression = NumberFormat('0.##').format(category.budget!);
    } else {
      _currentExpression = '';
    }
    _currentResult = _currentExpression;
  }

  bool get _hasBudget => widget.category?.hasBudget ?? false;

  Future<bool> _persist(Future<void> Function() save) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await save();
      _saved = true;
      HapticService.success();
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => _validationError = error is StateError
              ? error.message.toString()
              : 'Could not save budget. Your changes are kept. Try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    title: 'Discard budget changes?',
    draft: () => (
      _isPercentMode,
      _currentExpression,
      (_selectedCategoryIds.toList()..sort()).join(','),
    ),
    isSaving: () => _saving || _confirming,
    canLeave: () => _saved,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final category = widget.category;
    final currency = widget.currency;
    final totalIncome = widget.totalIncome;
    final fmt = currency.formatter;
    final categories = ref.watch(categoriesProvider).value ?? [];
    final selectedCategories = categories
        .where(
          (c) =>
              c.type == TransactionType.expense &&
              _selectedCategoryIds.contains(c.id),
        )
        .toList();
    final budgetName = selectedCategories.map((c) => c.name).join(' + ');
    final accent =
        selectedCategories.firstOrNull?.color ?? AppTheme.primaryColor(context);
    final originalBudgetId = _hasBudget ? category!.id : null;
    final otherCategories = categories.where(
      (c) =>
          c.id != originalBudgetId &&
          c.type == TransactionType.expense &&
          c.hasBudget &&
          {c.id, ...c.sharedBudgetCategoryIds}.any(
            (id) =>
                !_selectedCategoryIds.contains(id) &&
                categories.any(
                  (member) =>
                      member.id == id && member.type == TransactionType.expense,
                ),
          ),
    );
    final otherPercent = otherCategories
        .where((c) => c.isPercentBudget)
        .fold(0.0, (sum, c) => sum + (c.budgetPercent ?? 0));
    final otherBudget = otherCategories.fold(
      0.0,
      (sum, c) => sum + c.resolvedBudget(totalIncome),
    );
    final value =
        widget.currency.tryParseInput(
          _currentResult,
          precision: _isPercentMode ? 2 : null,
        ) ??
        0;
    final allocation =
        otherBudget + (_isPercentMode ? totalIncome * value / 100 : value);

    double? resolvedAmount;
    if (_isPercentMode && _currentResult.isNotEmpty) {
      final pct = widget.currency.tryParseInput(
        _currentResult,
        precision: _isPercentMode ? 2 : null,
      );
      if (pct != null && pct > 0) {
        resolvedAmount = totalIncome * pct / 100;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: KoinSheetSurface(
        scrollable: true,
        color: AppTheme.surfaceColor(context),

        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const KoinBottomSheetHandle(padding: EdgeInsets.only(bottom: 20)),
            // Budget header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasBudget ? 'Edit budget' : 'New budget',
                          style: const TextStyle(
                            fontWeight: KoinTypography.headingWeight,
                            fontSize: KoinTypography.sectionTitle,
                            letterSpacing: KoinTypography.headingTracking,
                          ),
                        ),
                        const Gap(6),
                        Text(
                          'Repeats every month. Changes also apply to past months.',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontSize: KoinTypography.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasBudget)
                    IconButton(
                      onPressed: _saving || _confirming
                          ? null
                          : () async {
                              HapticService.selection();
                              final confirmed = await ConfirmationSheet.show(
                                context: context,
                                title: 'Remove Budget?',
                                description: 'Remove this monthly budget? Categories and transactions will be kept.',
                                confirmLabel: 'Remove',
                                confirmColor: AppTheme.expenseColor(context),
                                icon: KoinIcons.broom,
                                isDanger: true,
                              );

                              if (confirmed == true && context.mounted) {
                                HapticService.heavy();
                                if (await _persist(
                                      () => ref
                                          .read(categoriesProvider.notifier)
                                          .editCategory(
                                            category!.withoutBudget(),
                                          ),
                                    ) &&
                                    context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                      icon: Icon(
                        KoinIcons.trash,
                        color: AppTheme.expenseContentColor(context),
                      ),
                      tooltip: 'Remove Budget',
                    ),
                ],
              ),
            ),
            const Gap(20),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: SelectionTile(
                key: const ValueKey('budget_category_selector'),
                fallbackIcon: KoinIcons.squaresFour,
                label: 'Categories',
                selectedName: selectedCategories.isEmpty ? null : budgetName,
                selectedColor: accent,
                selectedIconCodePoint: KoinIcons.squaresFour.codePoint,
                selectedNameMaxLines: null,
                selectedNameDetail: selectedCategories.length > 1
                    ? 'One shared limit · no fixed split'
                    : null,
                placeholder: 'Choose categories',
                onTap: _saving || _confirming
                    ? null
                    : () async {
                        final selected = await BudgetCategoryPickerSheet.show(
                          context,
                          selectedIds: _selectedCategoryIds,
                        );
                        if (selected == null || !mounted) return;
                        setState(() {
                          _selectedCategoryIds
                            ..clear()
                            ..addAll(selected);
                          _validationError = null;
                        });
                      },
              ),
            ),
            const Gap(20),
            // Fixed / % of Income toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: KoinChoiceControl(
                segments: const [
                  KoinSegmentItem(label: 'Fixed Amount'),
                  KoinSegmentItem(label: '% of Income'),
                ],
                selectedIndex: _isPercentMode ? 1 : 0,
                onChanged: (index) => setState(() {
                  _isPercentMode = index == 1;
                  _currentExpression = '';
                  _currentResult = '';
                  _validationError = null;
                }),
              ),
            ),
            const Gap(20),
            // Amount / Percentage display
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isPercentMode ? '' : '${currency.symbol} ',
                      style: TextStyle(
                        fontSize: KoinTypography.summaryAmount,
                        fontWeight: KoinTypography.headingWeight,
                        letterSpacing: KoinTypography.amountTracking,
                        color: AppTheme.textLightColor(context),
                      ),
                    ),
                    Text(
                      _currentExpression.isEmpty ? '0' : _currentExpression,
                      style: TextStyle(
                        fontSize: KoinTypography.summaryAmount,
                        fontWeight: KoinTypography.headingWeight,
                        letterSpacing: KoinTypography.amountTracking,
                        color: _currentExpression.isEmpty
                            ? AppTheme.textLightColor(context)
                                  .withValues(alpha: 0.3)
                            : AppTheme.textColor(context),
                      ),
                    ),
                    if (_isPercentMode)
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: KoinTypography.summaryAmount,
                          fontWeight: KoinTypography.headingWeight,
                          letterSpacing: KoinTypography.amountTracking,
                          color: _currentExpression.isEmpty
                              ? AppTheme.textLightColor(context)
                                    .withValues(alpha: 0.3)
                              : AppTheme.textLightColor(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Resolved amount preview (percentage mode)
            if (_isPercentMode) ...[
              Builder(
                builder: (context) {
                  final preview = resolvedAmount != null
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            KoinSpacing.screenInset,
                            0,
                            KoinSpacing.screenInset,
                            12,
                          ),
                          child: Text(
                            totalIncome <= 0
                                ? 'No income recorded yet — budget will update when income is tracked'
                                : '$_currentResult% of ${fmt.format(totalIncome)} = ${fmt.format(resolvedAmount)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: KoinTypography.compact,
                              fontWeight: KoinTypography.supportingWeight,
                              color: AppTheme.textLightColor(context),
                            ),
                          ),
                        )
                      : totalIncome <= 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            KoinSpacing.screenInset,
                            0,
                            KoinSpacing.screenInset,
                            12,
                          ),
                          child: Text(
                            'No income recorded yet — budget will update when income is tracked',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: KoinTypography.small,
                              color: AppTheme.textLightColor(context),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                  return MediaQuery.disableAnimationsOf(context)
                      ? preview
                      : AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: preview,
                        );
                },
              ),
            ],
            if (_validationError != null || totalIncome > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KoinSpacing.screenInset,
                  0,
                  KoinSpacing.screenInset,
                  12,
                ),
                child: Text(
                  _validationError ??
                      (allocation > totalIncome
                          ? '${fmt.format(allocation - totalIncome)} over recorded income across all budgets'
                          : '${fmt.format(totalIncome - allocation)} unallocated across all budgets'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: KoinTypography.small,
                    color: _validationError != null || allocation > totalIncome
                        ? AppTheme.expenseColor(context)
                        : AppTheme.textLightColor(context),
                  ),
                ),
              ),
            const Gap(4),
            // Quick presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: Row(
                children: _isPercentMode
                    ? [5, 10, 20, 25, 30, 50, 75, 100].map((pct) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticService.light();
                              setState(() {
                                _currentExpression = pct.toString();
                                _currentResult = pct.toString();
                                _validationError = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _currentExpression == pct.toString()
                                    ? accent.withValues(alpha: 0.15)
                                    : AppTheme.surfaceLightColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _currentExpression == pct.toString()
                                      ? accent.withValues(alpha: 0.4)
                                      : AppTheme.dividerColor(context),
                                ),
                              ),
                              child: Text(
                                '$pct%',
                                style: TextStyle(
                                  fontWeight: KoinTypography.labelWeight,
                                  fontSize: KoinTypography.caption,
                                  color: _currentExpression == pct.toString()
                                      ? accent
                                      : AppTheme.textColor(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList()
                    : [100, 250, 500, 1000, 2500, 5000].map((amount) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticService.light();
                              setState(() {
                                _currentExpression = amount.toString();
                                _currentResult = amount.toString();
                                _validationError = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLightColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.dividerColor(context),
                                ),
                              ),
                              child: Text(
                                '${currency.symbol}$amount',
                                style: TextStyle(
                                  fontWeight: KoinTypography.labelWeight,
                                  fontSize: KoinTypography.caption,
                                  color: AppTheme.textColor(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
              ),
            ),
            const Gap(24),
            // NumPad
            NumPad(
              enabled: !_saving,
              decimalDigits: _isPercentMode ? 2 : currency.decimalDigits,
              compact: true,
              initialValue: _currentExpression,
              onValueChanged: (expr, res) {
                setState(() {
                  _currentExpression = expr;
                  _currentResult = res;
                  _validationError = null;
                });
              },
              onDone: () async {
                if (_saving || _confirming) return;
                if (selectedCategories.isEmpty) {
                  setState(
                    () => _validationError = 'Choose at least one category.',
                  );
                  return;
                }
                final value = widget.currency.tryParseInput(
                  _currentResult,
                  precision: _isPercentMode ? 2 : null,
                );
                if (value == null ||
                    !value.isFinite ||
                    value <= 0 ||
                    (_isPercentMode && value > 100)) {
                  setState(
                    () => _validationError = _isPercentMode
                        ? 'Enter a percentage greater than 0 and up to 100.'
                        : 'Enter a budget amount greater than 0.',
                  );
                  return;
                }
                if (_isPercentMode && otherPercent + value > 100.000001) {
                  setState(
                    () => _validationError =
                        'Percentage budgets exceed 100%. Up to ${NumberFormat('0.##').format((100 - otherPercent).clamp(0, 100))}% is available.',
                  );
                  return;
                }
                final moves = <String>[];
                for (final budget in categories.where(
                  (c) =>
                      c.type == TransactionType.expense &&
                      c.hasBudget &&
                      c.id != originalBudgetId,
                )) {
                  final members = categories
                      .where(
                        (c) =>
                            c.type == TransactionType.expense &&
                            (c.id == budget.id ||
                                budget.sharedBudgetCategoryIds.contains(c.id)),
                      )
                      .toList();
                  final moved = members
                      .where((c) => _selectedCategoryIds.contains(c.id))
                      .toList();
                  if (moved.isEmpty) continue;
                  final remaining = members
                      .where((c) => !_selectedCategoryIds.contains(c.id))
                      .toList();
                  final limit = budget.isPercentBudget
                      ? '${NumberFormat('0.##').format(budget.budgetPercent)}% of income'
                      : fmt.format(budget.budget);
                  moves.add(
                    remaining.isEmpty
                        ? 'Replace the ${members.map((c) => c.name).join(' + ')} budget ($limit).'
                        : '${moved.map((c) => c.name).join(' + ')} will move here. '
                              '${remaining.map((c) => c.name).join(' + ')} will keep the previous $limit limit.',
                  );
                }
                if (moves.isNotEmpty) {
                  _confirming = true;
                  final confirmed = await ConfirmationSheet.show(
                    context: context,
                    title: 'Update existing budgets?',
                    description: moves.join('\n\n'),
                    confirmLabel: 'Move & save',
                    confirmColor: AppTheme.primaryColor(context),
                    icon: KoinIcons.squaresFour,
                  );
                  _confirming = false;
                  if (confirmed != true || !context.mounted) return;
                }
                final saved = await _persist(
                  () => ref
                      .read(categoriesProvider.notifier)
                      .saveBudget(
                        categoryIds: selectedCategories
                            .map((c) => c.id)
                            .toSet(),
                        originalBudgetId: originalBudgetId,
                        amount: value,
                        isPercent: _isPercentMode,
                      ),
                );
                if (saved && context.mounted) Navigator.pop(context);
              },
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
