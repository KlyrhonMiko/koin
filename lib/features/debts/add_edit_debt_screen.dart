import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/features/debts/widgets/debt_purchase_card.dart';
import 'package:koin/features/debts/widgets/bnpl_schedule_selectors.dart';
import 'package:uuid/uuid.dart';

enum _DebtFormMode {
  owedToMe('I am owed'),
  iOwe('I owe'),
  bnpl('BNPL');

  final String label;
  const _DebtFormMode(this.label);
}

class AddEditDebtScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  const AddEditDebtScreen({super.key, this.debt});

  @override
  ConsumerState<AddEditDebtScreen> createState() => _AddEditDebtScreenState();
}

class _AddEditDebtScreenState extends ConsumerState<AddEditDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _installmentsController = TextEditingController();

  late DebtType _selectedType;
  DateTime _startDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedCategoryId;
  InstallmentFrequency _selectedFrequency = InstallmentFrequency.monthly;
  bool _frequencyUserSet = false;
  List<DebtItem> _items = [];
  Timer? _debounceTimer;
  bool _manualCategory = false;
  int _suggestionRevision = 0;
  final _manualPurchaseIds = <String>{};
  bool _bnpl = false;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameController.text = d.personName;
      _amountController.text = d.amount.toString();
      _notesController.text = d.description ?? '';
      _selectedType = d.type;
      _startDate = d.startDate;
      _installmentsController.text = d.totalInstallments > 0
          ? d.totalInstallments.toString()
          : '';
      _selectedFrequency = d.frequency;
      _frequencyUserSet = true;
      _selectedAccountId = d.accountId;
      _selectedCategoryId = d.categoryId;
      _items = List.from(d.items);
      _bnpl = d.isMonthlyPurchaseAccount;
    } else {
      _selectedType = DebtType.owedToMe;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  void _onNotesChanged() {
    _suggestionRevision++;
    _debounceTimer?.cancel();
    if (!_manualCategory && widget.debt == null) {
      setState(() => _selectedCategoryId = null);
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      _runAutoCategorization,
    );
  }

  Future<void> _runAutoCategorization() async {
    final revision = _suggestionRevision;
    if (!mounted || _saving || _manualCategory || widget.debt != null) return;
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    final amt =
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(_amountController.text) ??
        1.0;
    final effectiveAmt = amt == 0.0 ? 1.0 : amt;
    final targetType = _selectedType == DebtType.owedToMe
        ? TransactionType.income
        : TransactionType.expense;

    try {
      final suggester = ref.read(categorySuggesterProvider);
      final suggestion = await suggester.suggest(
        SuggestionContext(
          text: notes,
          amount: effectiveAmt,
          type: targetType,
          date: _startDate,
          currentAccountId: _selectedAccountId ?? '',
        ),
      );

      if (suggestion != null &&
          mounted &&
          suggestion.canAutoApply &&
          !_manualCategory &&
          !_saving &&
          revision == _suggestionRevision &&
          notes == _notesController.text.trim() &&
          targetType ==
              (_selectedType == DebtType.owedToMe
                  ? TransactionType.income
                  : TransactionType.expense)) {
        final categories = ref.read(categoriesProvider).value ?? [];
        final matchedCat = categories
            .where((c) => c.id == suggestion.categoryId)
            .firstOrNull;
        if (matchedCat != null) {
          if (_selectedCategoryId != matchedCat.id ||
              (_selectedAccountId == null &&
                  suggestion.originAccountId != null &&
                  suggestion.originAccountId!.isNotEmpty)) {
            HapticService.light();
            setState(() {
              _selectedCategoryId = matchedCat.id;
              if (_selectedAccountId == null &&
                  suggestion.originAccountId != null &&
                  suggestion.originAccountId!.isNotEmpty) {
                _selectedAccountId = suggestion.originAccountId;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveImpl();
    } catch (_) {
      if (mounted) {
        HapticService.error();
        KoinSnackBar.error(
          context,
          'Could not save debt',
          subtitle: 'Your changes are kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveImpl() async {
    if (!_formKey.currentState!.validate()) {
      HapticService.error();
      return;
    }
    if (_bnpl && _items.isEmpty) {
      HapticService.error();
      KoinSnackBar.error(context, 'Add at least one purchase');
      return;
    }

    final name = _nameController.text.trim();
    final amount =
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(_amountController.text.trim()) ??
        0;
    final notes = _notesController.text.trim();
    final isEdit = widget.debt != null;
    final id = isEdit ? widget.debt!.id : const Uuid().v4();
    final currentAmount = isEdit ? widget.debt!.currentAmount : 0.0;

    final installmentsText = _installmentsController.text.trim();
    int installments = 0;
    if (installmentsText.isNotEmpty) {
      installments = int.tryParse(installmentsText) ?? 0;
    }

    final finalAmount = _items.isNotEmpty
        ? _items.fold(0.0, (sum, i) => sum + i.amount)
        : amount;

    final debt = Debt(
      id: id,
      personName: name,
      amount: finalAmount,
      type: _selectedType,
      startDate: _startDate,
      description: notes.isEmpty ? null : notes,
      totalInstallments: _bnpl ? 0 : installments,
      frequency: _bnpl ? InstallmentFrequency.monthly : _selectedFrequency,
      dueDate: _bnpl ? null : widget.debt?.dueDate,
      sortOrder: widget.debt?.sortOrder ?? 0,
      currentAmount: currentAmount,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      items: _items,
      isPurchaseAccount: _bnpl,
    );

    // Ensure debt items have debtId assigned
    final preparedItems = _items.map((i) => i.copyWith(debtId: id)).toList();
    final preparedDebt = debt.copyWith(items: preparedItems);

    await ref.read(debtsProvider.notifier).saveDebt(preparedDebt);
    HapticService.success();

    if (mounted) {
      KoinSnackBar.success(
        context,
        isEdit ? 'Record updated' : 'Record created',
        subtitle: 'Your record has been saved successfully',
      );
    }

    if (_manualCategory && _selectedCategoryId != null && notes.isNotEmpty) {
      final targetType = _selectedType == DebtType.owedToMe
          ? TransactionType.income
          : TransactionType.expense;
      await ref
          .read(categorySuggesterProvider)
          .recordFeedback(
            text: notes,
            amount: finalAmount,
            type: targetType,
            originAccountId: _selectedAccountId ?? '',
            destinationId: _selectedCategoryId!,
          )
          .catchError((Object _) {});
    }

    for (final item in preparedItems.where(
      (item) => _manualPurchaseIds.contains(item.id),
    )) {
      if (item.categoryId == null) continue;
      await ref
          .read(categorySuggesterProvider)
          .recordFeedback(
            text: item.name,
            amount: item.amount,
            type: _selectedType == DebtType.owedToMe
                ? TransactionType.income
                : TransactionType.expense,
            originAccountId: _selectedAccountId ?? '',
            destinationId: item.categoryId!,
          )
          .catchError((Object _) {});
    }

    if (mounted) {
      HapticService.light();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    title: 'Discard debt changes?',
    draft: () => (
      _nameController.text,
      _amountController.text,
      _notesController.text,
      _installmentsController.text,
      _selectedType,
      _startDate,
      _selectedAccountId,
      _selectedCategoryId,
      _selectedFrequency,
      _bnpl,
      jsonEncode(_items.map((item) => item.toMap()).toList()),
    ),
    listenables: [
      _nameController,
      _amountController,
      _notesController,
      _installmentsController,
    ],
    isSaving: () => _saving,
    child: KoinFormTheme(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final isEdit = widget.debt != null;
    final primaryColor = AppTheme.primaryColor(context);
    final accounts = ref.watch(accountProvider).value ?? [];
    final categories = ref.watch(categoriesProvider).value ?? [];
    final account = accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;
    final category = categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final hasInstallments =
        (int.tryParse(_installmentsController.text) ?? 0) > 0;
    final currency = ref.watch(settingsProvider).currency;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        leading: const KoinBackButton(),
        title: Text(
          _bnpl
              ? (isEdit ? 'Edit BNPL' : 'New BNPL')
              : (isEdit ? 'Edit debt / IOU' : 'New debt / IOU'),
        ),
        centerTitle: false,
      ),
      body: KoinEntityFormBody(
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KoinEntityNameField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                hintText: _bnpl ? 'BNPL provider' : 'Who is involved?',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const Gap(16),
              Text(
                _bnpl ? 'Outstanding balance' : 'Total amount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppTheme.textLightColor(context)),
              ),
              if (_bnpl)
                _buildBnplAmount(context, currency.symbol, primaryColor)
              else
                HeroAmountField(
                  controller: _amountController,
                  currencySymbol: currency.symbol,
                  currency: currency,
                  primaryColor: primaryColor,
                  validator: (value) {
                    final amount = ref
                        .read(settingsProvider)
                        .currency
                        .tryParseInput((value ?? ''));
                    return amount == null || !amount.isFinite || amount <= 0
                        ? 'Enter an amount greater than zero'
                        : null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              _buildRecordTypeSelector(context, primaryColor),
              const Gap(24),
              _fieldLabel(context, _bnpl ? 'Billing schedule' : 'Timeline'),
              const Gap(8),
              if (_bnpl)
                BillingDaySelector(
                  day: _startDate.day,
                  primaryColor: primaryColor,
                  onDaySelected: _setBillingDay,
                )
              else
                DateSelectorTile(
                  label: hasInstallments ? 'Start payment date' : 'Record date',
                  date: _startDate,
                  primaryColor: primaryColor,
                  onDateSelected: (date) => setState(() {
                    _startDate = date;
                  }),
                ),
              const Gap(28),
              Divider(height: 1, color: AppTheme.dividerColor(context)),
              const Gap(24),
              if (!_bnpl) ...[
                _fieldLabel(context, 'Optional details'),
                const Gap(12),
              ],
              if (!_bnpl) ...[
                _fieldLabel(context, 'Installment plan'),
                const Gap(8),
                _buildInstallmentsCard(context, primaryColor),
                const Gap(24),
              ],
              if (_bnpl || _items.isNotEmpty) ...[
                _buildPurchasesSection(context, primaryColor, categories),
                const Gap(24),
              ],
              if (_bnpl) ...[
                _fieldLabel(context, 'Optional details'),
                const Gap(12),
              ],
              KoinGroupedCard(
                borderRadius: 16,
                borderColor: AppTheme.fieldBorderColor(context),
                children: [
                  SelectionTile(
                    asCard: false,
                    fallbackIcon: KoinIcons.wallet,
                    label: 'Linked account',
                    selectedName: account?.name,
                    selectedColor: account?.color,
                    selectedIconCodePoint: account?.iconCodePoint,
                    selectedLogoAsset: account?.logoAsset,
                    placeholder: 'Choose an account',
                    onTap: () => _openAccountPicker(context, accounts),
                  ),
                  SelectionTile(
                    asCard: false,
                    fallbackIcon: KoinIcons.squaresFour,
                    label: 'Linked category',
                    selectedName: category?.name,
                    selectedColor: category?.color,
                    selectedIconCodePoint: category?.iconCodePoint,
                    placeholder: 'Choose a category',
                    onTap: () => _openCategoryPicker(context, categories),
                  ),
                ],
              ),
              const Gap(20),
              _fieldLabel(context, 'Notes'),
              const Gap(8),
              _buildNotesInput(context),
            ],
          ),
        ),
        action: KoinPrimaryButton(
          isLoading: _saving,
          label: isEdit ? 'Update' : 'Create',
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) =>
      FormSectionTitle.field(title: label);

  _DebtFormMode get _recordType => _bnpl
      ? _DebtFormMode.bnpl
      : _selectedType == DebtType.owedToMe
      ? _DebtFormMode.owedToMe
      : _DebtFormMode.iOwe;

  Widget _buildBnplAmount(
    BuildContext context,
    String currencySymbol,
    Color primaryColor,
  ) {
    final balance =
        (_items.fold(0.0, (sum, item) => sum + item.amount) -
                (widget.debt?.currentAmount ?? 0))
            .clamp(0, double.infinity);
    final format = NumberFormat.decimalPattern()
      ..minimumFractionDigits = balance % 1 == 0 ? 0 : 2
      ..maximumFractionDigits = 2;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$currencySymbol ',
                style: TextStyle(
                  fontSize: KoinTypography.screenTitle,
                  fontWeight: KoinTypography.labelWeight,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
              Text(
                format.format(balance),
                key: const Key('bnpl_balance'),
                maxLines: 1,
                style: TextStyle(
                  fontSize: KoinTypography.inputAmount,
                  fontWeight: KoinTypography.headingWeight,
                  height: KoinTypography.amountHeight,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordTypeSelector(BuildContext context, Color primaryColor) =>
      SelectionTile(
        label: 'Record type',
        placeholder: 'Choose a type',
        fallbackIcon: KoinIcons.arrowsLeftRight,
        selectedName: _recordType.label,
        selectedColor: primaryColor,
        selectedIconCodePoint: switch (_recordType) {
          _DebtFormMode.owedToMe => KoinIcons.arrowDown.codePoint,
          _DebtFormMode.iOwe => KoinIcons.arrowUp.codePoint,
          _DebtFormMode.bnpl => KoinIcons.shoppingCart.codePoint,
        },
        onTap: () => _selectRecordType(context, primaryColor),
      );

  Future<void> _selectRecordType(
    BuildContext context,
    Color primaryColor,
  ) async {
    final selected = await showRadioSelectionSheet<_DebtFormMode>(
      context: context,
      title: 'Record type',
      options: _DebtFormMode.values,
      selected: _recordType,
      label: (mode) => mode.label,
      accentColor: primaryColor,
    );
    if (!mounted ||
        !context.mounted ||
        selected == null ||
        selected == _recordType) {
      return;
    }
    if (_bnpl && _items.isNotEmpty && selected != _DebtFormMode.bnpl) {
      KoinSnackBar.error(
        context,
        selected == _DebtFormMode.owedToMe
            ? 'Remove purchases before switching to an IOU'
            : 'Remove purchases before switching to a single debt',
      );
      return;
    }
    HapticService.light();
    setState(() {
      _suggestionRevision++;
      _debounceTimer?.cancel();
      _selectedCategoryId = null;
      _manualCategory = false;
      _bnpl = selected == _DebtFormMode.bnpl;
      _selectedType = selected == _DebtFormMode.owedToMe
          ? DebtType.owedToMe
          : DebtType.iOwe;
      if (_bnpl) {
        _selectedFrequency = InstallmentFrequency.monthly;
        _items = _items
            .map(
              (item) => item.copyWith(
                firstPaymentDate: DateTime(
                  item.firstPaymentDate.year,
                  item.firstPaymentDate.month,
                  _startDate.day.clamp(
                    1,
                    DateTime(
                      item.firstPaymentDate.year,
                      item.firstPaymentDate.month + 1,
                      0,
                    ).day,
                  ),
                ),
              ),
            )
            .toList();
      }
    });
  }

  Widget _buildInstallmentsCard(BuildContext context, Color primaryColor) {
    final count = int.tryParse(_installmentsController.text) ?? 0;
    final amount =
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(_amountController.text) ??
        0;
    final format = ref.watch(settingsProvider).currency.formatter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _installmentsController,
          keyboardType: TextInputType.number,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Installments',
            hintText: 'None',
            hintStyle: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: AppTheme.fieldHintColor(context)),
          ),
          onChanged: (value) => setState(() {
            if ((int.tryParse(value) ?? 0) > 0 && !_frequencyUserSet) {
              _selectedFrequency = InstallmentFrequency.monthly;
            }
          }),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: count <= 0
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(12),
                    SelectionTile(
                      fallbackIcon: KoinIcons.calendarDots,
                      label: 'Payment frequency',
                      selectedName: _selectedFrequency.label,
                      selectedColor: primaryColor,
                      selectedIconCodePoint:
                          KoinIcons.calendarDots.codePoint,
                      placeholder: 'Choose frequency',
                      onTap: () {
                        _frequencyUserSet = true;
                        _openFrequencyPicker(context, primaryColor);
                      },
                    ),
                    if (amount > 0) ...[
                      const Gap(12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            KoinIcons.chartLineUp,
                            size: 18,
                            color: primaryColor,
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              'Estimated payment: ${format.format(amount / count)} per installment.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textLightColor(context),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildNotesInput(BuildContext context) => KoinNotesField(
    controller: _notesController,
    onChanged: (_) => _onNotesChanged(),
  );

  Future<void> _openCategoryPicker(
    BuildContext context,
    List<TransactionCategory> categories,
  ) async {
    // Filter by the relevant type: income for "owed to me", expense for "I owe"
    final categoryType = _selectedType == DebtType.owedToMe
        ? TransactionType.income
        : TransactionType.expense;

    final id = await showCategoryPickerSheet(
      context: context,
      ref: ref,
      selectedCategoryId: _selectedCategoryId,
      type: categoryType,
      subtitle: _selectedType == DebtType.owedToMe
          ? 'Link an income category'
          : 'Link an expense category',
      categoriesOverride: categories,
    );
    if (id != null && mounted) {
      setState(() {
        _selectedCategoryId = id;
        _manualCategory = true;
        _suggestionRevision++;
      });
    }
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _selectedAccountId,
      subtitle: 'Where is this money from/going?',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id);
    }
  }

  Future<void> _openFrequencyPicker(
    BuildContext context,
    Color primaryColor,
  ) async {
    final frequencies = InstallmentFrequency.values;
    final freq = await showSelectSheet<InstallmentFrequency>(
      context: context,
      title: 'Payment Frequency',
      subtitle: 'How often are payments made?',
      itemCount: frequencies.length,
      itemBuilder: (sheetContext, index) {
        final f = frequencies[index];
        return SelectSheetItem(
          name: f.label,
          accentColor: primaryColor,
          selected: f == _selectedFrequency,
          onTap: () => Navigator.pop(sheetContext, f),
        );
      },
    );
    if (freq != null && mounted) {
      setState(() => _selectedFrequency = freq);
    }
  }

  Widget _buildPurchasesSection(
    BuildContext context,
    Color primaryColor,
    List<TransactionCategory> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_bnpl)
          _fieldLabel(context, 'Existing purchases')
        else
          DebtPurchaseSectionHeader(
            count: _items.length,
            color: _selectedType == DebtType.owedToMe
                ? AppTheme.incomeColor(context)
                : AppTheme.expenseColor(context),
          ),
        const Gap(16),
        ..._items.map(
          (item) => Padding(
            key: ValueKey('purchase_${item.id}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: SwipeToDeleteTile(
              key: Key('dismiss_purchase_${item.id}'),
              borderRadius: BorderRadius.circular(18),
              fillRoundedCorners: true,
              backgroundColor: AppTheme.errorColor(context),
              icon: KoinIcons.trash,
              confirmTitle: 'Remove Purchase?',
              confirmDescription:
                  'Remove "${item.name}" from this credit? Changes are applied when you save.',
              confirmLabel: 'Remove',
              onDelete: () => setState(() {
                _items.remove(item);
                _updateAmountFromItems();
              }),
              child: PressableScale(
                onTap: () async {
                  HapticService.light();
                  final updatedItem = await showAddPurchaseSheet(
                    context: context,
                    debtType: _selectedType,
                    primaryColor: primaryColor,
                    categories: categories,
                    defaultDate: _purchaseBillDate,
                    monthlyBillingDay: _bnpl ? _startDate.day : null,
                    existingItem: item,
                    suggester: ref.read(categorySuggesterProvider),
                    onCategoryConfirmed: (item) =>
                        _manualPurchaseIds.add(item.id),
                  );
                  if (updatedItem != null && mounted) {
                    setState(() {
                      final index = _items.indexOf(item);
                      if (index != -1) {
                        _items[index] = updatedItem;
                        _updateAmountFromItems();
                      }
                    });
                  }
                },
                child: DebtPurchaseCard(
                  item: item,
                  categories: categories,
                  currencyFormat: ref
                      .watch(settingsProvider)
                      .currency
                      .formatter,
                  color: _selectedType == DebtType.owedToMe
                      ? AppTheme.incomeColor(context)
                      : AppTheme.expenseColor(context),
                ),
              ),
            ),
          ),
        ),
        if (_bnpl) ...[
          const Gap(6),
          PressableScale(
            onTap: () async {
              HapticService.light();
              final newItem = await showAddPurchaseSheet(
                context: context,
                debtType: _selectedType,
                primaryColor: primaryColor,
                categories: categories,
                defaultDate: _purchaseBillDate,
                monthlyBillingDay: _bnpl ? _startDate.day : null,
                suggester: ref.read(categorySuggesterProvider),
                onCategoryConfirmed: (item) => _manualPurchaseIds.add(item.id),
              );
              if (newItem != null) {
                setState(() {
                  _items.add(newItem);
                  _updateAmountFromItems();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    KoinIcons.plusCircle,
                    color: primaryColor,
                    size: 20,
                  ),
                  const Gap(8),
                  Flexible(
                    child: Text(
                      'Add Purchase',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _updateAmountFromItems() {
    if (_items.isNotEmpty) {
      final total = _items.fold(0.0, (sum, i) => sum + i.amount);
      _amountController.text = total
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.00$'), '');
    }
  }

  DateTime get _purchaseBillDate {
    if (!_bnpl) return _startDate;
    return Debt(
      id: '',
      personName: '',
      amount: _items.fold(0.0, (sum, item) => sum + item.amount),
      type: DebtType.iOwe,
      startDate: _startDate,
      items: _items,
      currentAmount: widget.debt?.currentAmount ?? 0,
      isPurchaseAccount: true,
    ).nextPurchaseBillDate;
  }

  void _setBillingDay(int day) => setState(() {
    final now = DateTime.now();
    var anchor = DateTime(now.year, now.month);
    // Store a real date with the chosen day, including 29-31 in short months.
    while (DateTime(anchor.year, anchor.month + 1, 0).day < day) {
      anchor = DateTime(anchor.year, anchor.month - 1);
    }
    _startDate = DateTime(anchor.year, anchor.month, day);
    _items = _items
        .map(
          (item) => item.copyWith(
            firstPaymentDate: DateTime(
              item.firstPaymentDate.year,
              item.firstPaymentDate.month,
              day.clamp(
                1,
                DateTime(
                  item.firstPaymentDate.year,
                  item.firstPaymentDate.month + 1,
                  0,
                ).day,
              ),
            ),
          ),
        )
        .toList();
  });
}
