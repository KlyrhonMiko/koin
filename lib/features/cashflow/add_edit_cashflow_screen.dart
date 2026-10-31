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
  bool _saving = false;
  final _nameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _categoryFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _categoryKey = GlobalKey();
  final _accountKey = GlobalKey();
  String? _invalidField;
  void _requireSelection(String field, GlobalKey key, FocusNode focus) {
    setState(() => _invalidField = field);
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: KoinMotion.duration(
          context,
          const Duration(milliseconds: 160),
        ),
        alignment: .3,
      );
    }
    focus.requestFocus();
  }

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
    _nameFocus.dispose();
    _amountFocus.dispose();
    _categoryFocus.dispose();
    _accountFocus.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    _suggestionRevision++;
    if (widget.payment != null) return;
    if (!_manualCategory) setState(() => _selectedCategoryId = null);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 400),
      _runAutoCategorization,
    );
  }

  Future<void> _runAutoCategorization() async {
    if (!mounted || _saving || _manualCategory || widget.payment != null) {
      return;
    }
    if (_titleController.text.trim().isEmpty) return;
    final revision = _suggestionRevision;
    final text = _titleController.text;
    final amount =
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(
              _amountController.text,
              originalValue: widget.payment?.amount,
            ) ??
        0;
    try {
      final suggestion = await ref
          .read(categorySuggesterProvider)
          .suggest(
            SuggestionContext(
              text: text,
              amount: amount,
              type: _selectedType,
              date: _startDate,
              currentAccountId: _selectedAccountId ?? '',
            ),
          );
      if (!mounted ||
          _saving ||
          _manualCategory ||
          revision != _suggestionRevision ||
          suggestion == null ||
          !suggestion.canAutoApply ||
          suggestion.type != _selectedType) {
        return;
      }
      final category = (ref.read(categoriesProvider).value ?? [])
          .where(
            (c) => c.id == suggestion.categoryId && c.type == _selectedType,
          )
          .firstOrNull;
      if (category != null && _selectedCategoryId != category.id) {
        HapticService.light();
        setState(() => _selectedCategoryId = category.id);
      }
    } catch (_) {}
  }

  void _savePayment() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _savePaymentImpl();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not save schedule',
          subtitle: 'Your changes are kept. Try again.',
        );
        HapticService.error();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePaymentImpl() async {
    if (!_formKey.currentState!.validate()) {
      if (_titleController.text.trim().isEmpty) {
        _nameFocus.requestFocus();
      } else {
        _amountFocus.requestFocus();
      }
      HapticService.error();
      return;
    }
    if (_endDate != null &&
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day).isBefore(
          DateTime(_startDate.year, _startDate.month, _startDate.day),
        )) {
      KoinSnackBar.error(
        context,
        'Check the end date',
        subtitle: 'The end date must be on or after the start date.',
      );
      HapticService.error();
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Please enter a title',
        subtitle: 'A title is required for this schedule',
      );
      return;
    }

    final amount =
        ref
            .read(settingsProvider)
            .currency
            .tryParseInput(
              _amountController.text,
              originalValue: widget.payment?.amount,
            ) ??
        0.0;
    if (!amount.isFinite || amount <= 0) {
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Invalid amount',
        subtitle: 'Please enter an amount greater than zero',
      );
      return;
    }

    if (_selectedCategoryId == null) {
      _requireSelection('Category', _categoryKey, _categoryFocus);
      HapticService.error();
      KoinSnackBar.error(
        context,
        'Category required',
        subtitle: 'Please select a category',
      );
      return;
    }

    if (_selectedAccountId == null) {
      _requireSelection('Account', _accountKey, _accountFocus);
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
        if (_selectedFrequency == PaymentFrequency.flexible) {
          calcDate = today;
        } else {
          calcDate = PlannedPayment(
            id: '',
            title: '',
            amount: amount,
            type: _selectedType,
            categoryId: _selectedCategoryId!,
            accountId: _selectedAccountId!,
            startDate: _startDate,
            recurrenceDay: _startDate.day,
            nextDate: calcDate,
            frequency: _selectedFrequency,
          ).computeNextDate();
        }
      }
      nextDate = calcDate;
    }

    if (widget.payment != null &&
        widget.payment!.startDate == _startDate &&
        widget.payment!.frequency == _selectedFrequency) {
      nextDate = widget.payment!.nextDate;
    }
    final newPayment = PlannedPayment(
      id: widget.payment?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      amount: amount,
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId!,
      startDate: _startDate,
      recurrenceDay:
          widget.payment != null && widget.payment!.startDate == _startDate
          ? widget.payment!.recurrenceDay
          : _startDate.day,
      endDate: _endDate,
      nextDate: nextDate,
      frequency: _selectedFrequency,
      notes: _notesController.text.isEmpty
          ? null
          : _notesController.text.trim(),
      isAutoProcess:
          _isAutoProcess && _selectedFrequency != PaymentFrequency.flexible,
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

    if (_manualCategory) {
      await ref
          .read(categorySuggesterProvider)
          .recordFeedback(
            text: _titleController.text,
            amount: amount,
            type: _selectedType,
            originAccountId: _selectedAccountId!,
            destinationId: _selectedCategoryId!,
          )
          .catchError((Object _) {});
    }
    if (mounted) {
      HapticService.success();
      Navigator.pop(context);
    }
  }

  final KoinAsyncActionGuard _deleteGuard = KoinAsyncActionGuard();

  Future<void> _showDeleteConfirmation() => _deleteGuard.run(
    context,
    () => _showDeleteConfirmationImpl(),
    errorTitle: 'Could not delete this item',
  );

  Future<void> _showDeleteConfirmationImpl() async {
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete $_domainNoun?',
      description:
          'Are you sure you want to delete this $_domainNoun? This action cannot be undone.',
      confirmLabel: 'Delete $_domainNoun',
      confirmColor: AppTheme.expenseColor(context),
      icon: KoinIcons.trash,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KoinEntityNameField(
          controller: _titleController,
          focusNode: _nameFocus,
          label: _isIncome ? 'Income name' : 'Payment name',
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Enter a name' : null,
          textCapitalization: TextCapitalization.sentences,
          hintText: _isIncome ? 'Name your income' : 'Name your payment',
          onChanged: (_) {
            setState(() {});
            _onTitleChanged();
          },
        ),
        const Gap(16),
        Text(
          'Amount',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppTheme.textLightColor(context)),
        ),
        HeroAmountField(
          controller: _amountController,
          focusNode: _amountFocus,
          validator: (value) {
            final amount = ref
                .read(settingsProvider)
                .currency
                .tryParseInput(value ?? '');
            return amount == null || amount <= 0
                ? 'Enter an amount greater than zero'
                : null;
          },
          currencySymbol: currency.symbol,
          currency: currency,
          originalValue: widget.payment?.amount,
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
      _suggestionRevision++;
      setState(() => _selectedAccountId = id);
    }
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    title: 'Discard schedule changes?',
    draft: () => (
      _titleController.text,
      _amountController.text,
      _notesController.text,
      _selectedType,
      _selectedCategoryId,
      _selectedAccountId,
      _startDate,
      _endDate,
      _selectedFrequency,
      _isAutoProcess,
    ),
    listenables: [_titleController, _amountController, _notesController],
    isSaving: () => _saving,
    child: KoinFormTheme(builder: _buildContent),
  );

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
                KoinIcons.trash,
                color: AppTheme.expenseContentColor(context),
              ),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: KoinEntityFormBody(
        form: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, primaryColor),
              _fieldLabel(context, 'Schedule'),
              const Gap(8),
              SelectionTile(
                fallbackIcon: KoinIcons.repeat,
                label: 'Repeats',
                selectedName: _selectedFrequency.label,
                selectedColor: primaryColor,
                selectedIconCodePoint: KoinIcons.repeat.codePoint,
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
              _buildEndDateSection(context, primaryColor),
              const Gap(24),
              _fieldLabel(context, 'Details'),
              const Gap(12),
              KoinGroupedCard(
                borderRadius: 16,
                borderColor: AppTheme.fieldBorderColor(context),
                children: [
                  SelectionTile(
                    asCard: false,
                    key: _categoryKey,
                    focusNode: _categoryFocus,
                    errorText:
                        _invalidField == 'Category' &&
                            _selectedCategoryId == null
                        ? 'Choose a category'
                        : null,
                    fallbackIcon: KoinIcons.squaresFour,
                    label: 'Category',
                    selectedName: category?.name,
                    selectedColor: category?.color,
                    selectedIconCodePoint: category?.iconCodePoint,
                    placeholder: 'Choose a category',
                    onTap: () => _openCategoryPicker(context),
                  ),
                  SelectionTile(
                    asCard: false,
                    fallbackIcon: KoinIcons.wallet,
                    key: _accountKey,
                    focusNode: _accountFocus,
                    errorText:
                        _invalidField == 'Account' && _selectedAccountId == null
                        ? 'Choose an account'
                        : null,
                    label: _isIncome ? 'Receiving account' : 'Payment account',
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
              Divider(height: 1, color: AppTheme.dividerColor(context)),
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
        action: KoinPrimaryButton(
          isLoading: _saving,
          label: isEditing ? 'Save Changes' : 'Create $_domainNoun',
          onPressed: _savePayment,
        ),
      ),
    );
  }

  Future<PaymentFrequency?> _selectFrequency(
    BuildContext context,
    Color primaryColor,
  ) => showRadioSelectionSheet<PaymentFrequency>(
    context: context,
    title: 'Repeats',
    options: PaymentFrequency.values,
    selected: _selectedFrequency,
    label: (frequency) => frequency.label,
    accentColor: primaryColor,
  );
  Widget _fieldLabel(BuildContext context, String label) =>
      FormSectionTitle.field(title: label);

  Widget _buildAutoProcessRow(BuildContext context, Color primaryColor) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text('Auto-Process $_domainNoun'),
      subtitle: Text(
        _selectedFrequency == PaymentFrequency.flexible
            ? 'Choose a repeating schedule to enable automatic entries.'
            : 'Records due entries while Koin is open or when you return.',
      ),
      value: _selectedFrequency != PaymentFrequency.flexible && _isAutoProcess,
      onChanged: _selectedFrequency == PaymentFrequency.flexible
          ? null
          : (value) {
              HapticService.light();
              setState(() => _isAutoProcess = value);
            },
    );
  }

  Widget _buildEndDateSection(BuildContext context, Color primaryColor) {
    final child = _endDate != null
        ? Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: DateSelectorTile(
                    label: 'Ends on',
                    date: _endDate!,
                    primaryColor: primaryColor,
                    onDateSelected: (date) => setState(() => _endDate = date),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove end date',
                  onPressed: () => setState(() => _endDate = null),
                  icon: const Icon(KoinIcons.x),
                ),
              ],
            ),
          ).koinEntrance(context)
        : !_isIncome
        ? Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _endDate = _startDate.add(const Duration(days: 30)),
              ),
              icon: const Icon(KoinIcons.calendarCheck),
              label: const Text('Add end date'),
            ),
          )
        : const SizedBox.shrink();
    return KeyedSubtree(
      key: const ValueKey('cashflow-end-date'),
      child: MediaQuery.disableAnimationsOf(context)
          ? child
          : AnimatedSize(
              duration: KoinMotion.entrance,
              curve: KoinMotion.curve,
              alignment: Alignment.topCenter,
              child: child,
            ),
    );
  }

  Widget _buildNotesInput(BuildContext context) =>
      KoinNotesField(controller: _notesController);
}
