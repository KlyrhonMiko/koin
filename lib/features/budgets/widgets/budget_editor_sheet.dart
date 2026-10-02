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
    return showModalBottomSheet(
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

  @override
  void initState() {
    super.initState();
    _isPercentMode = widget.category.isPercentBudget;
    if (_isPercentMode &&
        widget.category.budgetPercent != null &&
        widget.category.budgetPercent! > 0) {
      _currentExpression = widget.category.budgetPercent!.toStringAsFixed(0);
    } else if (!_isPercentMode &&
        widget.category.budget != null &&
        widget.category.budget! > 0) {
      _currentExpression = widget.category.budget!.toStringAsFixed(0);
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

  void _saveUpdatedCategory(TransactionCategory updated) {
    HapticService.success();
    ref.read(categoriesProvider.notifier).editCategory(updated);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final currency = widget.currency;
    final totalIncome = widget.totalIncome;
    final fmt = NumberFormat.currency(symbol: currency.symbol);

    double? resolvedAmount;
    if (_isPercentMode && _currentResult.isNotEmpty) {
      final pct = double.tryParse(_currentResult);
      if (pct != null && pct > 0) {
        resolvedAmount = totalIncome * pct / 100;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                          icon: Icons.delete_sweep_rounded,
                          isDanger: true,
                        );

                        if (confirmed == true && context.mounted) {
                          HapticService.heavy();
                          _saveUpdatedCategory(category.withoutBudget());
                          Navigator.pop(context);
                        }
                      },
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.expenseColor(context),
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
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightColor(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          if (_isPercentMode) {
                            setState(() {
                              _isPercentMode = false;
                              _currentExpression = '';
                              _currentResult = '';
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isPercentMode
                                ? AppTheme.primaryColor(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Fixed Amount',
                            style: TextStyle(
                              fontWeight: KoinTypography.titleWeight,
                              fontSize: KoinTypography.caption,
                              color: !_isPercentMode
                                  ? Colors.white
                                  : AppTheme.textLightColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticService.selection();
                          if (!_isPercentMode) {
                            setState(() {
                              _isPercentMode = true;
                              _currentExpression = '';
                              _currentResult = '';
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isPercentMode
                                ? AppTheme.primaryColor(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '% of Income',
                            style: TextStyle(
                              fontWeight: KoinTypography.titleWeight,
                              fontSize: KoinTypography.caption,
                              color: _isPercentMode
                                  ? Colors.white
                                  : AppTheme.textLightColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                            ? AppTheme.textLightColor(
                                context,
                              ).withValues(alpha: 0.3)
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
                              ? AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.3)
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
                duration: const Duration(milliseconds: 200),
                child: resolvedAmount != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KoinSpacing.screenInset,
                          0,
                          KoinSpacing.screenInset,
                          12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: category.color.withValues(alpha: 0.7),
                              ),
                              const Gap(8),
                              Text(
                                '$_currentResult% of ${fmt.format(totalIncome)} = ${fmt.format(resolvedAmount)}',
                                style: TextStyle(
                                  fontSize: KoinTypography.caption,
                                  fontWeight: KoinTypography.labelWeight,
                                  color: category.color,
                                ),
                              ),
                            ],
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
            const Gap(4),
            // Quick presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
              ),
              child: Row(
                children: _isPercentMode
                    ? [5, 10, 15, 20, 25, 30].map((pct) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              HapticService.light();
                              setState(() {
                                _currentExpression = pct.toString();
                                _currentResult = pct.toString();
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
              compact: true,
              initialValue: _currentExpression,
              onValueChanged: (expr, res) {
                setState(() {
                  _currentExpression = expr;
                  _currentResult = res;
                });
              },
              onDone: () {
                final value = double.tryParse(_currentResult);
                if (_isPercentMode) {
                  _saveUpdatedCategory(category.withPercentBudget(value));
                } else {
                  _saveUpdatedCategory(category.withFixedBudget(value));
                }
                Navigator.pop(context);
              },
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }
}
