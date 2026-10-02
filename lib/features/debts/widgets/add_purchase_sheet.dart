import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:flutter_animate/flutter_animate.dart';

Future<DebtItem?> showAddPurchaseSheet({
  required BuildContext context,
  required DebtType debtType,
  required Color primaryColor,
  required List<TransactionCategory> categories,
  required DateTime defaultDate,
  DebtItem? existingItem,
  CategorySuggester? suggester,
}) {
  String name = existingItem?.name ?? '';
  String amountStr =
      existingItem?.amount.toString().replaceAll(RegExp(r'\.0$'), '') ?? '';
  String installmentsStr = existingItem?.totalInstallments.toString() ?? '';
  DateTime firstDate =
      existingItem?.firstPaymentDate ??
      DateTime(defaultDate.year, defaultDate.month, defaultDate.day);
  TransactionCategory? selectedCategory = existingItem?.categoryId != null
      ? categories.where((c) => c.id == existingItem!.categoryId).firstOrNull
      : null;

  final effectiveSuggester = suggester ?? HybridMlSuggesterAdapter();
  final coordinator = DebouncedSuggesterCoordinator(
    suggester: effectiveSuggester,
    debounceDuration: const Duration(milliseconds: 350),
  );
  int autoCatKey = 0;

  void runAutoCategorize(void Function(void Function()) setSheetState) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final amt = double.tryParse(amountStr.replaceAll(',', '')) ?? 1.0;
    final effectiveAmt = amt == 0.0 ? 1.0 : amt;
    final targetType = debtType == DebtType.owedToMe
        ? TransactionType.income
        : TransactionType.expense;

    coordinator.run(
      context: SuggestionContext(
        text: trimmed,
        amount: effectiveAmt,
        type: targetType,
        date: firstDate,
        currentAccountId: '',
      ),
      onSuggested: (suggestion) {
        final matched = categories
            .where((c) => c.id == suggestion.categoryId && c.type == targetType)
            .firstOrNull;
        if (matched != null) {
          if (selectedCategory?.id != matched.id) {
            HapticService.light();
            setSheetState(() {
              autoCatKey++;
              selectedCategory = matched;
            });
          }
        }
      },
    );
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<DebtItem?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor(ctx),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                KoinSpacing.screenInset,
                16,
                KoinSpacing.screenInset,
                24 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KoinBottomSheetHandle(
                      padding: EdgeInsets.only(bottom: 24),
                    ),
                    Text(
                      existingItem != null ? 'Edit Purchase' : 'Add Purchase',
                      style: TextStyle(
                        fontSize: KoinTypography.screenTitle,
                        fontWeight: KoinTypography.headingWeight,
                        color: AppTheme.textColor(ctx),
                        letterSpacing: KoinTypography.headingTracking,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24),
                    TextFormField(
                      initialValue: name,
                      decoration: InputDecoration(
                        labelText: 'Item Name (e.g. Phone)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor(ctx),
                      ),
                      style: TextStyle(color: AppTheme.textColor(ctx)),
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      onChanged: (v) {
                        name = v;
                        runAutoCategorize(setSheetState);
                      },
                    ),
                    const Gap(16),
                    TextFormField(
                      initialValue: amountStr,
                      decoration: InputDecoration(
                        labelText: 'Total Amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor(ctx),
                      ),
                      style: TextStyle(color: AppTheme.textColor(ctx)),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) {
                        amountStr = v;
                        if (selectedCategory == null) {
                          runAutoCategorize(setSheetState);
                        }
                      },
                    ),
                    const Gap(16),
                    Builder(
                      builder: (ctx) {
                        Widget child = SelectionTile(
                          fallbackIcon: Icons.category_rounded,
                          label: 'Category (Optional)',
                          selectedName: selectedCategory?.name,
                          selectedColor: selectedCategory?.color,
                          selectedIconCodePoint:
                              selectedCategory?.iconCodePoint,
                          placeholder: 'Select Category',
                          onTap: () async {
                            final categoryType = debtType == DebtType.owedToMe
                                ? TransactionType.income
                                : TransactionType.expense;
                            final id = await showCategoryPickerSheet(
                              context: ctx,
                              type: categoryType,
                              selectedCategoryId: selectedCategory?.id,
                              subtitle: debtType == DebtType.owedToMe
                                  ? 'Link an income category'
                                  : 'Link an expense category',
                              categoriesOverride: categories,
                            );
                            if (id != null) {
                              setSheetState(
                                () => selectedCategory = categories.firstWhere(
                                  (c) => c.id == id,
                                ),
                              );
                            }
                          },
                        );

                        if (autoCatKey > 0) {
                          child = child
                              .animate(key: ValueKey(autoCatKey))
                              .shimmer(
                                duration: 400.ms,
                                color: primaryColor.withValues(alpha: 0.2),
                              )
                              .scale(
                                duration: 150.ms,
                                curve: Curves.easeOut,
                                begin: const Offset(1, 1),
                                end: const Offset(1.02, 1.02),
                              )
                              .then()
                              .scale(
                                duration: 250.ms,
                                curve: Curves.easeOutBack,
                                begin: const Offset(1.02, 1.02),
                                end: const Offset(1, 1),
                              );
                        }
                        return child;
                      },
                    ),
                    const Gap(16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: installmentsStr,
                            decoration: InputDecoration(
                              labelText: 'Installments',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceColor(ctx),
                            ),
                            style: TextStyle(color: AppTheme.textColor(ctx)),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => installmentsStr = v,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(firstDate),
                            initialValue: DateFormat.MMMd().format(firstDate),
                            readOnly: true,
                            onTap: () async {
                              final dt = await showThemedDatePicker(
                                context: ctx,
                                initialDate: firstDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                primaryColor: primaryColor,
                              );
                              if (dt != null) {
                                setSheetState(() => firstDate = dt);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'First Payment',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceColor(ctx),
                              suffixIcon: Icon(
                                Icons.calendar_month,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            style: TextStyle(color: AppTheme.textColor(ctx)),
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final amt =
                            double.tryParse(amountStr.replaceAll(',', '')) ?? 0;
                        final inst = int.tryParse(installmentsStr) ?? 1;
                        if (name.isNotEmpty && amt > 0 && inst > 0) {
                          HapticService.light();
                          coordinator.cancel();

                          if (selectedCategory != null) {
                            final targetType = debtType == DebtType.owedToMe
                                ? TransactionType.income
                                : TransactionType.expense;
                            effectiveSuggester.recordFeedback(
                              text: name.trim(),
                              amount: amt,
                              type: targetType,
                              originAccountId: '',
                              destinationId: selectedCategory!.id,
                            );
                          }

                          final newItem = DebtItem(
                            id: existingItem?.id ?? const Uuid().v4(),
                            debtId: existingItem?.debtId ?? '',
                            name: name,
                            amount: amt,
                            totalInstallments: inst,
                            firstPaymentDate: firstDate,
                            categoryId: selectedCategory?.id,
                          );
                          Navigator.pop(ctx, newItem);
                        }
                      },
                      child: Text(
                        existingItem != null ? 'Update Plan' : 'Add to Plan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: KoinTypography.titleWeight,
                          fontSize: KoinTypography.itemTitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() => coordinator.dispose());
}
