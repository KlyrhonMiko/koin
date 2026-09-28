import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/models/debt_item.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/categorization/categorization_engine.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/select_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';

Future<DebtItem?> showAddPurchaseSheet({
  required BuildContext context,
  required DebtType debtType,
  required Color primaryColor,
  required List<TransactionCategory> categories,
  required DateTime defaultDate,
  DebtItem? existingItem,
}) {
  String name = existingItem?.name ?? '';
  String amountStr = existingItem?.amount.toString().replaceAll(RegExp(r'\.0$'), '') ?? '';
  String installmentsStr = existingItem?.totalInstallments.toString() ?? '';
  DateTime firstDate = existingItem?.firstPaymentDate ?? DateTime(defaultDate.year, defaultDate.month, defaultDate.day);
  TransactionCategory? selectedCategory = existingItem?.categoryId != null 
      ? categories.where((c) => c.id == existingItem!.categoryId).firstOrNull 
      : null;

  Timer? debounceTimer;
  final engine = CategorizationEngine();
  int autoCatKey = 0;

  void runAutoCategorize(void Function(void Function()) setSheetState) {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return;

      final amt = double.tryParse(amountStr.replaceAll(',', '')) ?? 1.0;
      final effectiveAmt = amt == 0.0 ? 1.0 : amt;
      final targetType = debtType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;
      final signedAmount = targetType == TransactionType.expense ? -effectiveAmt : effectiveAmt;

      try {
        final result = await engine.categorize(
          rawText: trimmed,
          amount: signedAmount,
          date: firstDate,
          currentAccountId: '',
        );

        if (result != null) {
          final matched = categories
              .where((c) => c.id == result.destinationId && c.type == targetType)
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
        }
      } catch (_) {}
    });
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(ctx),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Gap(24),
                    Text(
                      existingItem != null ? 'Edit Purchase' : 'Add Purchase',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textColor(ctx), letterSpacing: -0.5),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(24),
                    TextFormField(
                      initialValue: name,
                      decoration: InputDecoration(
                        labelText: 'Item Name (e.g. Phone)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppTheme.surfaceColor(ctx),
                      ),
                      style: TextStyle(color: AppTheme.textColor(ctx)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        Widget child = _buildSelectionRow(
                          ctx,
                          fallbackIcon: Icons.category_rounded,
                          label: 'Category (Optional)',
                          selectedName: selectedCategory?.name,
                          selectedColor: selectedCategory?.color,
                          selectedIconCodePoint: selectedCategory?.iconCodePoint,
                          placeholder: 'Select Category',
                          onTap: () async {
                            final categoryType = debtType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;
                            final filtered = categories.where((c) => c.type == categoryType).toList();

                            final id = await showSelectSheet<String>(
                              context: ctx,
                              title: 'Category',
                              subtitle: debtType == DebtType.owedToMe
                                  ? 'Link an income category'
                                  : 'Link an expense category',
                              itemCount: filtered.length,
                              itemBuilder: (c, index) {
                                final cat = filtered[index];
                                return SelectSheetItem(
                                  name: cat.name,
                                  accentColor: cat.color,
                                  iconCodePoint: cat.iconCodePoint,
                                  selected: cat.id == selectedCategory?.id,
                                  onTap: () => Navigator.pop(c, cat.id),
                                );
                              },
                            );
                            if (id != null) {
                              setSheetState(() => selectedCategory = categories.firstWhere((c) => c.id == id));
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              final dt = await showDatePicker(
                                context: ctx,
                                initialDate: firstDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (dt != null) setSheetState(() => firstDate = dt);
                            },
                            decoration: InputDecoration(
                              labelText: 'First Payment',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: AppTheme.surfaceColor(ctx),
                              suffixIcon: Icon(Icons.calendar_month, color: primaryColor, size: 20),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final amt = double.tryParse(amountStr.replaceAll(',', '')) ?? 0;
                        final inst = int.tryParse(installmentsStr) ?? 1;
                        if (name.isNotEmpty && amt > 0 && inst > 0) {
                          HapticService.light();
                          debounceTimer?.cancel();

                          if (selectedCategory != null) {
                            final targetType = debtType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;
                            final signedAmount = targetType == TransactionType.expense ? -amt : amt;
                            engine.processFeedback(
                              rawText: name.trim(),
                              amount: signedAmount,
                              originId: '',
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
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
  ).whenComplete(() => debounceTimer?.cancel());
}

Widget _buildSelectionRow(
  BuildContext context, {
  required IconData fallbackIcon,
  required String label,
  required String? selectedName,
  required Color? selectedColor,
  required int? selectedIconCodePoint,
  String? selectedLogoAsset,
  required String placeholder,
  required VoidCallback onTap,
  Widget? trailing,
}) {
  final hasSelection =
      selectedName != null &&
      selectedColor != null &&
      selectedIconCodePoint != null;

  return InkWell(
    onTap: () async {
      HapticService.light();
      final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
      FocusManager.instance.primaryFocus?.unfocus();
      if (hadFocus) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      onTap();
    },
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        contentPadding: EdgeInsets.zero,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: AppTheme.surfaceColor(context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
        children: [
            Builder(builder: (context) {
              if (hasSelection && selectedLogoAsset != null && selectedLogoAsset.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    selectedLogoAsset,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                );
              }

              return Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasSelection
                    ? selectedColor.withValues(alpha: 0.12)
                    : AppTheme.surfaceLightColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasSelection
                    ? IconUtils.getIcon(selectedIconCodePoint)
                    : fallbackIcon,
                size: 17,
                color: hasSelection
                    ? selectedColor
                    : AppTheme.textLightColor(context),
              ),
            );
            }),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textLightColor(
                        context,
                      ).withValues(alpha: 0.65),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    hasSelection ? selectedName : placeholder,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasSelection
                          ? AppTheme.textColor(context)
                          : AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const Gap(8), trailing],
            const Gap(4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.4),
              size: 22,
            ),
          ],
        ),
      ),
    ),
  );
}
