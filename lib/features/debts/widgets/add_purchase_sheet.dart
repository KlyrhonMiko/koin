import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'bnpl_schedule_selectors.dart';

Future<DebtItem?> showAddPurchaseSheet({
  required BuildContext context,
  required DebtType debtType,
  required Color primaryColor,
  required List<TransactionCategory> categories,
  required DateTime defaultDate,
  int? monthlyBillingDay,
  DebtItem? existingItem,
  CategorySuggester? suggester,
  void Function(DebtItem item)? onCategoryConfirmed,
}) {
  final currency = ProviderScope.containerOf(context)
      .read(settingsProvider)
      .currency;
  String name = existingItem?.name ?? '';
  String amountStr =
      existingItem?.amount.toString().replaceAll(RegExp(r'\.0$'), '') ?? '';
  String installmentsStr = existingItem?.totalInstallments.toString() ?? '';
  DateTime firstDate =
      existingItem?.firstPaymentDate ??
      DateTime(defaultDate.year, defaultDate.month, defaultDate.day);
  DateTime billDate(int year, int month) => DateTime(
    year,
    month,
    (monthlyBillingDay ?? firstDate.day).clamp(
      1,
      DateTime(year, month + 1, 0).day,
    ),
  );
  if (monthlyBillingDay != null) {
    firstDate = billDate(firstDate.year, firstDate.month);
  }
  var lastDate = billDate(
    firstDate.year,
    firstDate.month +
        ((existingItem?.totalInstallments ?? 1).clamp(1, 1000000) - 1),
  );
  int numberOfPayments() =>
      (lastDate.year - firstDate.year) * 12 +
      lastDate.month -
      firstDate.month +
      1;
  TransactionCategory? selectedCategory = existingItem?.categoryId != null
      ? categories.where((c) => c.id == existingItem!.categoryId).firstOrNull
      : null;

  final effectiveSuggester = suggester ?? HybridMlSuggesterAdapter();
  final coordinator = DebouncedSuggesterCoordinator(
    suggester: effectiveSuggester,
    debounceDuration: const Duration(milliseconds: 350),
  );
  int autoCatKey = 0;
  bool manualCategory = existingItem != null;
  bool categoryConfirmed = false;
  bool saved = false;

  void runAutoCategorize(void Function(void Function()) setSheetState) {
    coordinator.cancel();
    if (manualCategory) return;
    if (selectedCategory != null) setSheetState(() => selectedCategory = null);
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final amt = currency.tryParseInput(amountStr) ?? 1.0;
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
        if (manualCategory ||
            !suggestion.canAutoApply ||
            name.trim() != trimmed) {
          return;
        }
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

  final formKey = GlobalKey<FormState>();

  return showEditorBottomSheet<DebtItem?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => KoinFormTheme(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final nameStyle = KoinTypography.entityNameStyle.copyWith(
            color: AppTheme.textColor(ctx),
          );
          final amountStyle = KoinTypography.inputAmountStyle.copyWith(
            color: AppTheme.contentColor(ctx, primaryColor),
          );
          final inset = MediaQuery.viewInsetsOf(ctx).bottom;
          final maxHeight = (MediaQuery.sizeOf(ctx).height * 0.9 - inset).clamp(
            0.0,
            double.infinity,
          );
          return UnsavedChangesGuard(
            title: 'Discard purchase changes?',
            draft: () => (
              name,
              amountStr,
              installmentsStr,
              firstDate,
              lastDate,
              selectedCategory?.id,
            ),
            canLeave: () => saved,
            child: Padding(
              padding: EdgeInsets.only(bottom: inset),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor(ctx),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KoinShape.sheet),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KoinBottomSheetHandle(
                      padding: EdgeInsets.only(top: 10, bottom: 8),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              existingItem != null
                                  ? 'Edit Purchase'
                                  : 'Add Purchase',
                              style: Theme.of(ctx).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(KoinIcons.x),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    initialValue: name,
                                    textAlign: TextAlign.center,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.next,
                                    style: nameStyle,
                                    decoration: InputDecoration(
                                      hintText: 'Name your purchase',
                                      hintMaxLines: 2,
                                      hintStyle: nameStyle.copyWith(
                                        color: AppTheme.fieldHintColor(
                                          ctx,
                                          lightOpacity: 0.4,
                                        ),
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter a purchase name'
                                        : null,
                                    onChanged: (value) {
                                      setSheetState(() => name = value);
                                      runAutoCategorize(setSheetState);
                                    },
                                  ),
                                  const Gap(16),
                                  Text(
                                    monthlyBillingDay != null &&
                                            existingItem == null
                                        ? 'Remaining balance (${currency.code})'
                                        : 'Total amount (${currency.code})',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(ctx).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.textLightColor(ctx),
                                        ),
                                  ),
                                  const Gap(8),
                                  TextFormField(
                                    initialValue: amountStr,
                                    textAlign: TextAlign.center,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: amountStyle,
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: amountStyle.copyWith(
                                        color: AppTheme.hasEditorAppearance(ctx)
                                            ? AppTheme.textLightColor(ctx)
                                            : primaryColor.withValues(
                                                alpha: 0.35,
                                              ),
                                      ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      errorMaxLines: 3,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    validator: (value) {
                                      final amount = currency.tryParseInput(
                                        (value ?? ''),
                                      );
                                      return amount == null ||
                                              !amount.isFinite ||
                                              amount <= 0
                                          ? 'Enter an amount greater than zero'
                                          : null;
                                    },
                                    onChanged: (value) {
                                      setSheetState(() => amountStr = value);
                                      if (selectedCategory == null) {
                                        runAutoCategorize(setSheetState);
                                      }
                                    },
                                  ),
                                  const Gap(24),
                                  Text(
                                    monthlyBillingDay != null
                                        ? 'Payment schedule'
                                        : 'Installment plan',
                                    style: Theme.of(ctx).textTheme.titleSmall,
                                  ),
                                  const Gap(8),
                                  if (monthlyBillingDay == null)
                                    TextFormField(
                                      initialValue: installmentsStr,
                                      keyboardType: TextInputType.number,
                                      style: Theme.of(ctx).textTheme.bodyLarge,
                                      decoration: InputDecoration(
                                        labelText: 'Installments',
                                        hintText: '1',
                                        hintStyle: Theme.of(ctx)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppTheme.fieldHintColor(
                                                ctx,
                                              ),
                                            ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? null
                                          : (int.tryParse(value) ?? 0) <= 0
                                          ? 'Enter at least one installment'
                                          : null,
                                      onChanged: (value) => setSheetState(
                                        () => installmentsStr = value,
                                      ),
                                    ),
                                  const Gap(12),
                                  if (monthlyBillingDay == null)
                                    DateSelectorTile(
                                      label: 'First payment',
                                      date: firstDate,
                                      primaryColor: primaryColor,
                                      onDateSelected: (date) =>
                                          setSheetState(() => firstDate = date),
                                    ),
                                  if (monthlyBillingDay != null) ...[
                                    Text(
                                      'Monthly due day: $monthlyBillingDay',
                                      style: Theme.of(ctx).textTheme.bodyMedium,
                                    ),
                                    const Gap(12),
                                    BillMonthSelector(
                                      label: 'First bill month',
                                      date: firstDate,
                                      primaryColor: primaryColor,
                                      onMonthSelected: (date) =>
                                          setSheetState(() {
                                            firstDate = billDate(
                                              date.year,
                                              date.month,
                                            );
                                            if (lastDate.isBefore(firstDate)) {
                                              lastDate = firstDate;
                                            }
                                          }),
                                    ),
                                    const Gap(12),
                                    BillMonthSelector(
                                      label: 'Last bill month',
                                      date: lastDate,
                                      primaryColor: primaryColor,
                                      onMonthSelected: (date) =>
                                          setSheetState(() {
                                            final selected = billDate(
                                              date.year,
                                              date.month,
                                            );
                                            lastDate =
                                                selected.isBefore(firstDate)
                                                ? firstDate
                                                : selected;
                                          }),
                                    ),
                                    const Gap(12),
                                    Text(
                                      '${numberOfPayments()} monthly ${numberOfPayments() == 1 ? 'payment' : 'payments'}',
                                      style: Theme.of(ctx).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const Gap(28),
                                  Divider(
                                    height: 1,
                                    color: AppTheme.dividerColor(ctx),
                                  ),
                                  const Gap(24),
                                  Text(
                                    'Optional details',
                                    style: Theme.of(ctx).textTheme.titleSmall,
                                  ),
                                  const Gap(12),
                                  Builder(
                                    builder: (ctx) {
                                      Widget child = SelectionTile(
                                        fallbackIcon: KoinIcons.squaresFour,
                                        label: 'Linked category',
                                        selectedName: selectedCategory?.name,
                                        selectedColor: selectedCategory?.color,
                                        selectedIconCodePoint:
                                            selectedCategory?.iconCodePoint,
                                        placeholder: 'Choose a category',
                                        onTap: () async {
                                          final categoryType =
                                              debtType == DebtType.owedToMe
                                              ? TransactionType.income
                                              : TransactionType.expense;
                                          final id =
                                              await showCategoryPickerSheet(
                                                context: ctx,
                                                type: categoryType,
                                                selectedCategoryId:
                                                    selectedCategory?.id,
                                                subtitle:
                                                    debtType ==
                                                        DebtType.owedToMe
                                                    ? 'Link an income category'
                                                    : 'Link an expense category',
                                                categoriesOverride: categories,
                                              );
                                          if (id != null && ctx.mounted) {
                                            manualCategory = true;
                                            categoryConfirmed = true;
                                            coordinator.cancel();
                                            setSheetState(
                                              () => selectedCategory =
                                                  categories.firstWhere(
                                                    (c) => c.id == id,
                                                  ),
                                            );
                                          }
                                        },
                                      );
                                      if (autoCatKey > 0 &&
                                          !MediaQuery.disableAnimationsOf(
                                            ctx,
                                          )) {
                                        child = child
                                            .koinAnimate(
                                              context,
                                              autoPlay:
                                                  !MediaQuery.disableAnimationsOf(
                                                    context,
                                                  ),
                                              onInit: KoinMotion.onInit(
                                                context,
                                              ),
                                              key: ValueKey(autoCatKey),
                                            )
                                            .shimmer(
                                              duration: 400.ms,
                                              color: primaryColor.withValues(
                                                alpha: 0.2,
                                              ),
                                            );
                                      }
                                      return child;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          heightFactor: 1,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: KoinPrimaryButton(
                              label: existingItem != null
                                  ? 'Update Plan'
                                  : 'Add to Plan',
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;
                                final amt =
                                    currency.tryParseInput(amountStr) ?? 0;
                                final inst = monthlyBillingDay != null
                                    ? numberOfPayments()
                                    : int.tryParse(installmentsStr) ?? 1;
                                if (name.isNotEmpty && amt > 0 && inst > 0) {
                                  HapticService.light();
                                  coordinator.cancel();

                                  final newItem = DebtItem(
                                    id: existingItem?.id ?? const Uuid().v4(),
                                    debtId: existingItem?.debtId ?? '',
                                    name: name,
                                    amount: amt,
                                    totalInstallments: inst,
                                    firstPaymentDate: firstDate,
                                    categoryId: selectedCategory?.id,
                                  );
                                  if (categoryConfirmed) {
                                    onCategoryConfirmed?.call(newItem);
                                  }
                                  saved = true;
                                  Navigator.pop(ctx, newItem);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ).whenComplete(() => coordinator.dispose());
}
