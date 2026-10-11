import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';

import 'package:koin/core/core.dart';

/// Deep Cashflow Module: Unified management for scheduled cash movements
/// (both recurring incomes and planned payment expenses).
class AddEditCashflowScreen extends ConsumerStatefulWidget {
  final PlannedPayment? payment;
  final TransactionType initialType;

  const AddEditCashflowScreen({
    super.key,
    this.payment,
    this.initialType = TransactionType.expense,
  });

  @override
  ConsumerState<AddEditCashflowScreen> createState() =>
      _AddEditCashflowScreenState();
}

class _AddEditCashflowScreenState extends ConsumerState<AddEditCashflowScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late TransactionType _selectedType;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  PaymentFrequency _selectedFrequency = PaymentFrequency.flexible;
  bool _isAutoProcess = false;
  Timer? _debounceTimer;
  bool _manualCategory = false;
  int _suggestionRevision = 0;

  bool get _isIncome => _selectedType == TransactionType.income;
  String get _domainNoun => _isIncome ? 'Recurring Income' : 'Planned Payment';

  @override
  void initState() {
    super.initState();
    _selectedType = widget.payment?.type ?? widget.initialType;
    _titleController = TextEditingController(text: widget.payment?.title ?? '');
    _amountController = TextEditingController(
      text: widget.payment != null
          ? widget.payment!.amount
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'\.00$'), '')
          : '',
    );
    _notesController = TextEditingController(text: widget.payment?.notes ?? '');

    if (widget.payment != null) {
      _selectedCategoryId = widget.payment!.categoryId;
      _selectedAccountId = widget.payment!.accountId;
      _startDate = widget.payment!.startDate;
      _endDate = widget.payment!.endDate;
      _selectedFrequency = widget.payment!.frequency;
      _isAutoProcess = widget.payment!.isAutoProcess;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    _suggestionRevision++;
    if (widget.payment != null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 400),
      _runAutoCategorization,
    );
  }

  Future<void> _runAutoCategorization() async {
    if (!mounted || _manualCategory || widget.payment != null) return;
    if (_titleController.text.trim().isEmpty) return;
    final revision = _suggestionRevision;

    double amount = double.tryParse(_amountController.text) ?? 1.0;
    if (amount == 0.0) amount = 1.0;

    try {
      final suggester = ref.read(categorySuggesterProvider);
      final suggestion = await suggester.suggest(
        SuggestionContext(
          text: _titleController.text,
          amount: amount,
          type: _selectedType,
          date: _startDate,
          currentAccountId: _selectedAccountId ?? '',
        ),
      );

      if (suggestion != null &&
          mounted &&
          suggestion.canAutoApply &&
          !_manualCategory &&
          revision == _suggestionRevision) {
        if (!suggestion.isTransfer) {
          final categories = ref.read(categoriesProvider).value ?? [];
          final matchingCat = categories
              .where(
                (c) => c.id == suggestion.categoryId && c.type == _selectedType,
              )
              .firstOrNull;

          if (matchingCat != null) {
            final originId = suggestion.originAccountId ?? '';
            if (_selectedCategoryId != matchingCat.id ||
                (_selectedAccountId != originId && originId.isNotEmpty)) {
              HapticService.light();
              setState(() {
                _selectedCategoryId = matchingCat.id;
                if (originId.isNotEmpty) {
                  _selectedAccountId = originId;
                }
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  void _savePayment() async {
    if (_titleController.text.isEmpty) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Please enter a title',
        subtitle: 'A title is required for this schedule',
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Invalid amount',
        subtitle: 'Please enter an amount greater than zero',
      );
      return;
    }

    if (_selectedCategoryId == null) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Category required',
        subtitle: 'Please select a category',
      );
      return;
    }

    if (_selectedAccountId == null) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Account required',
        subtitle: 'Please select an account',
      );
      return;
    }

    DateTime nextDate = _startDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime calcDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    if (calcDate.isBefore(today)) {
      while (calcDate.isBefore(today)) {
        switch (_selectedFrequency) {
          case PaymentFrequency.daily:
            calcDate = calcDate.add(const Duration(days: 1));
            break;
          case PaymentFrequency.weekly:
            calcDate = calcDate.add(const Duration(days: 7));
            break;
          case PaymentFrequency.biWeekly:
            calcDate = calcDate.add(const Duration(days: 14));
            break;
          case PaymentFrequency.monthly:
            calcDate = DateTime(
              calcDate.year,
              calcDate.month + 1,
              calcDate.day,
            );
            break;
          case PaymentFrequency.quarterly:
            calcDate = DateTime(
              calcDate.year,
              calcDate.month + 3,
              calcDate.day,
            );
            break;
          case PaymentFrequency.yearly:
            calcDate = DateTime(
              calcDate.year + 1,
              calcDate.month,
              calcDate.day,
            );
            break;
          case PaymentFrequency.flexible:
            calcDate = today;
            break;
        }
      }
      nextDate = calcDate;
    }

    final newPayment = PlannedPayment(
      id: widget.payment?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId!,
      startDate: _startDate,
      endDate: _endDate,
      nextDate: nextDate,
      frequency: _selectedFrequency,
      notes: _notesController.text.isEmpty
          ? null
          : _notesController.text.trim(),
      isAutoProcess: _isAutoProcess,
    );

    if (widget.payment == null) {
      await ref
          .read(plannedPaymentProvider.notifier)
          .addPlannedPayment(newPayment);
    } else {
      await ref
          .read(plannedPaymentProvider.notifier)
          .updatePlannedPayment(newPayment);
    }

    ref
        .read(categorySuggesterProvider)
        .recordFeedback(
          text: _titleController.text,
          amount: amount,
          type: _selectedType,
          originAccountId: _selectedAccountId!,
          destinationId: _selectedCategoryId!,
        );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete $_domainNoun?',
      description:
          'Are you sure you want to delete this $_domainNoun? This action cannot be undone.',
      confirmLabel: 'Delete $_domainNoun',
      confirmColor: AppTheme.expenseColor(context),
      icon: Icons.delete_outline_rounded,
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      await ref
          .read(plannedPaymentProvider.notifier)
          .deletePlannedPayment(widget.payment!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    final currency = ref.watch(settingsProvider).currency;
    final nameStyle = TextStyle(
      fontSize: KoinTypography.formTitle,
      fontWeight: FontWeight.w800,
      letterSpacing: 0,
      color: AppTheme.textColor(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _titleController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          style: nameStyle,
          decoration: InputDecoration(
            hintText: _isIncome ? 'Name your income' : 'Name your payment',
            hintMaxLines: 2,
            hintStyle: nameStyle.copyWith(
              color: AppTheme.fieldHintColor(context, lightOpacity: 0.4),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (_) {
            setState(() {});
            _onTitleChanged();
          },
        ),
        const Gap(16),
        Text(
          'Amount',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textLightColor(context),
          ),
        ),
        HeroAmountField(
          controller: _amountController,
          currencySymbol: currency.symbol,
          primaryColor: primaryColor,
          onChanged: (_) {
            setState(() {});
            _onTitleChanged();
          },
        ),
      ],
    );
  }

  Future<void> _openCategoryPicker(BuildContext context) async {
    final id = await showCategoryPickerSheet(
      context: context,
      ref: ref,
      selectedCategoryId: _selectedCategoryId,
      type: _selectedType,
      title: 'Category',
      subtitle: 'Choose a category for this ${_domainNoun.toLowerCase()}',
    );
    if (id != null && mounted) {
      _suggestionRevision++;
      setState(() {
        _selectedCategoryId = id;
        _manualCategory = true;
      });
    }
  }

  Future<void> _openAccountPicker(BuildContext context) async {
    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _selectedAccountId,
      title: 'Account',
      subtitle: _isIncome
          ? 'Choose receiving account'
          : 'Choose payment account',
    );
    if (id != null && mounted) {
      setState(() => _selectedAccountId = id);
    }
  }

  @override
  Widget build(BuildContext context) => KoinFormTheme(builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final isEditing = widget.payment != null;
    final primaryColor = _isIncome
        ? AppTheme.incomeColor(context)
        : AppTheme.primaryColor(context);
    final category = (ref.watch(categoriesProvider).value ?? [])
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final account = (ref.watch(accountProvider).value ?? [])
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        leading: const KoinBackButton(),
        title: Text(
          '${isEditing ? 'Edit' : 'New'} ${_isIncome ? 'income' : 'payment'}',
        ),
        centerTitle: false,
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Delete $_domainNoun',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.expenseColor(context),
              ),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(context, primaryColor),
                        _fieldLabel(context, 'Schedule'),
                        const Gap(8),
                        SelectionTile(
                          fallbackIcon: Icons.repeat_rounded,
                          label: 'Repeats',
                          selectedName:
                              _selectedFrequency.name[0].toUpperCase() +
                              _selectedFrequency.name.substring(1),
                          selectedColor: primaryColor,
                          selectedIconCodePoint: Icons.repeat_rounded.codePoint,
                          placeholder: 'Choose frequency',
                          onTap: () async {
                            final frequency = await _selectFrequency(
                              context,
                              primaryColor,
                            );
                            if (frequency != null && mounted) {
                              setState(() => _selectedFrequency = frequency);
                            }
                          },
                        ),
                        AnimatedSize(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _selectedFrequency == PaymentFrequency.flexible
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: DateSelectorTile(
                                    label: _isIncome
                                        ? 'Next expected date'
                                        : 'Next payment date',
                                    date: _startDate,
                                    primaryColor: primaryColor,
                                    onDateSelected: (date) =>
                                        setState(() => _startDate = date),
                                  ),
                                ),
                        ),
                        const Gap(24),
                        _fieldLabel(context, 'Details'),
                        const Gap(12),
                        KoinGroupedCard(
                          borderRadius: 16,
                          borderColor: AppTheme.fieldBorderColor(context),
                          children: [
                            SelectionTile(
                              asCard: false,
                              fallbackIcon: Icons.category_rounded,
                              label: 'Category',
                              selectedName: category?.name,
                              selectedColor: category?.color,
                              selectedIconCodePoint: category?.iconCodePoint,
                              placeholder: 'Choose a category',
                              onTap: () => _openCategoryPicker(context),
                            ),
                            SelectionTile(
                              asCard: false,
                              fallbackIcon:
                                  Icons.account_balance_wallet_rounded,
                              label: _isIncome
                                  ? 'Receiving account'
                                  : 'Payment account',
                              selectedName: account?.name,
                              selectedColor: account?.color,
                              selectedIconCodePoint: account?.iconCodePoint,
                              selectedLogoAsset: account?.logoAsset,
                              placeholder: 'Choose an account',
                              onTap: () => _openAccountPicker(context),
                            ),
                          ],
                        ),
                        const Gap(28),
                        Divider(
                          height: 1,
                          color: AppTheme.dividerColor(context),
                        ),
                        const Gap(24),
                        _fieldLabel(context, 'Optional details'),
                        const Gap(12),
                        _buildAutoProcessRow(context, primaryColor),
                        const Gap(20),
                        _fieldLabel(context, 'Notes'),
                        const Gap(8),
                        _buildNotesInput(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: KoinPrimaryButton(
                  label: isEditing ? 'Save Changes' : 'Create $_domainNoun',
                  onPressed: _savePayment,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<PaymentFrequency?> _selectFrequency(
    BuildContext context,
    Color primaryColor,
  ) => showModalBottomSheet<PaymentFrequency>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor(context),
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                'Repeats',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: KoinTypography.headingWeight,
                ),
              ),
            ),
            for (final frequency in PaymentFrequency.values)
              Semantics(
                selected: frequency == _selectedFrequency,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  minTileHeight: 64,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    frequency.name[0].toUpperCase() +
                        frequency.name.substring(1),
                    style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                      fontWeight: frequency == _selectedFrequency
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: Icon(
                    frequency == _selectedFrequency
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: frequency == _selectedFrequency
                        ? primaryColor
                        : AppTheme.textLightColor(sheetContext),
                    size: 24,
                  ),
                  onTap: () {
                    HapticService.selection();
                    Navigator.pop(sheetContext, frequency);
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _fieldLabel(BuildContext context, String label) => Text(
    label,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: AppTheme.textColor(context),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildAutoProcessRow(BuildContext context, Color primaryColor) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text('Auto-Process $_domainNoun'),
      subtitle: const Text('Create transaction automatically'),
      value: _isAutoProcess,
      onChanged: (value) {
        HapticService.light();
        setState(() => _isAutoProcess = value);
      },
    );
  }

  Widget _buildNotesInput(BuildContext context) => TextFormField(
    controller: _notesController,
    style: Theme.of(context).textTheme.bodyLarge,
    minLines: 1,
    maxLines: 4,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      hintText: 'Notes (Optional)',
      hintStyle: Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(color: AppTheme.fieldHintColor(context)),
    ),
  );
}
