import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

class BudgetEditorSheet extends ConsumerStatefulWidget {
  final TransactionCategory category;
  final Currency currency;
  final double totalIncome;

  const BudgetEditorSheet({
    super.key,
    required this.category,
    required this.currency,
    required this.totalIncome,
  });

  /// Presents [BudgetEditorSheet] in a standardized modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required TransactionCategory category,
    required Currency currency,
    required double totalIncome,
  }) {
    HapticService.light();
    return showEditorBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetEditorSheet(
        category: category,
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

  @override
  void initState() {
    super.initState();
    _isPercentMode = widget.category.isPercentBudget;
    if (_isPercentMode &&
        widget.category.budgetPercent != null &&
        widget.category.budgetPercent! > 0) {
      _currentExpression = NumberFormat('0.##')
          .format(widget.category.budgetPercent!);
    } else if (!_isPercentMode &&
        widget.category.budget != null &&
        widget.category.budget! > 0) {
      _currentExpression = NumberFormat('0.##').format(widget.category.budget!);
    } else {
      _currentExpression = '';
    }
    _currentResult = _currentExpression;
  }

  bool get _hasBudget =>
      (widget.category.budget != null && widget.category.budget! > 0) ||
      (widget.category.isPercentBudget &&
          widget.category.budgetPercent != null &&
          widget.category.budgetPercent! > 0);

  Future<bool> _saveUpdatedCategory(TransactionCategory updated) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await ref.read(categoriesProvider.notifier).editCategory(updated);
      _saved = true;
      HapticService.success();
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _validationError =
              'Could not save budget. Your changes are kept. Try again.',
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
    draft: () => (_isPercentMode, _currentExpression),
    isSaving: () => _saving,
    canLeave: () => _saved,
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final category = widget.category;
    final currency = widget.currency;
    final totalIncome = widget.totalIncome;
    final fmt = currency.formatter;
    final otherCategories = (ref.watch(categoriesProvider).value ?? []).where(
      (c) => c.id != category.id && c.type == TransactionType.expense,
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
        color: AppTheme.surfaceColor(context),

        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const KoinBottomSheetHandle(padding: EdgeInsets.only(bottom: 20)),
            // Category header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      IconUtils.getIcon(category.iconCodePoint),
                      color: category.color,
                      size: 24,
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: KoinTypography.headingWeight,
                            fontSize: KoinTypography.sectionTitle,
                            letterSpacing: KoinTypography.headingTracking,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          _hasBudget
                              ? 'Edit monthly budget'
                              : 'Set monthly budget',
                          style: TextStyle(
                            color: AppTheme.textLightColor(context),
                            fontSize: KoinTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_hasBudget)
                    IconButton(
                      onPressed: () async {
                        HapticService.selection();
                        final confirmed = await ConfirmationSheet.show(
                          context: context,
                          title: 'Remove Budget?',
                          description:
                              'Are you sure you want to remove the monthly budget for ${category.name}?',
                          confirmLabel: 'Remove',
                          confirmColor: AppTheme.expenseColor(context),
                          icon: KoinIcons.broom,
                          isDanger: true,
                        );

                        if (confirmed == true && context.mounted) {
                          HapticService.heavy();
                          if (await _saveUpdatedCategory(
                                category.withoutBudget(),
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
              AnimatedSize(
                duration: KoinMotion.duration(
                  context,
                  const Duration(milliseconds: 200),
                ),
                child: resolvedAmount != null
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
                    : const SizedBox.shrink(),
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
                    ? [5, 10, 20, 30, 50, 75, 100].map((pct) {
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
                                    ? category.color.withValues(alpha: 0.15)
                                    : AppTheme.surfaceLightColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _currentExpression == pct.toString()
                                      ? category.color.withValues(alpha: 0.4)
                                      : AppTheme.dividerColor(context),
                                ),
                              ),
                              child: Text(
                                '$pct%',
                                style: TextStyle(
                                  fontWeight: KoinTypography.labelWeight,
                                  fontSize: KoinTypography.caption,
                                  color: _currentExpression == pct.toString()
                                      ? category.color
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
                final saved = await _saveUpdatedCategory(
                  _isPercentMode
                      ? category.withPercentBudget(value)
                      : category.withFixedBudget(value),
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
