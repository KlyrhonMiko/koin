import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  int _autoCatKey = 0;
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
                if (_selectedCategoryId != matchingCat.id) _autoCatKey++;
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
    final topPadding = MediaQuery.paddingOf(context).top;
    final settings = ref.read(settingsProvider);
    final currency = settings.currency;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.fieldBorderColor(context, lightOpacity: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Gap(topPadding + 4),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KoinSpacing.screenInset,
            ),
            child: Row(
              children: [
                const KoinBackButton(),
                const Spacer(),
                if (widget.payment != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.expenseColor(context),
                      size: 24,
                    ),
                    onPressed: _showDeleteConfirmation,
                  ),
              ],
            ),
          ),
          const Gap(8),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KoinSpacing.screenInset,
            ),
            child: TextFormField(
              controller: _titleController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: KoinTypography.formTitle,
                fontWeight: KoinTypography.headingWeight,
                color: AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
              decoration: InputDecoration(
                hintText: _isIncome
                    ? 'Name your income (e.g. Salary)'
                    : 'Name your subscription / bill',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: AppTheme.fieldHintColor(context, lightOpacity: 0.4),
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _onTitleChanged();
              },
            ),
          ),

          const Gap(4),

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
      ),
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
    final categoriesState = ref.watch(categoriesProvider);
    final accountsState = ref.watch(accountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context, primaryColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                KoinSpacing.screenInset,
                24,
                KoinSpacing.screenInset,
                100,
              ),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Repeats Section
                    const FormSectionTitle(title: 'Repeats'),
                    const Gap(12),
                    SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: PaymentFrequency.values.length,
                            itemBuilder: (context, index) {
                              final f = PaymentFrequency.values[index];
                              final isSelected = _selectedFrequency == f;
                              return GestureDetector(
                                onTap: () {
                                  HapticService.light();
                                  setState(() => _selectedFrequency = f);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: KoinSpacing.screenInset,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryColor
                                        : AppTheme.surfaceColor(context),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : AppTheme.dividerColor(context),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            AppTheme.boxShadow(
                                              context,
                                              color: primaryColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Text(
                                    f.name[0].toUpperCase() +
                                        f.name.substring(1),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textColor(context),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const Gap(32),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _selectedFrequency != PaymentFrequency.flexible
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  [
                                        const FormSectionTitle(
                                          title: 'Timeline',
                                        ),
                                        const Gap(12),
                                        DateSelectorTile(
                                          label:
                                              _selectedFrequency ==
                                                  PaymentFrequency.flexible
                                              ? 'Start Date'
                                              : (_isIncome
                                                    ? 'Next Expected Date'
                                                    : 'Next Payment Date'),
                                          date: _startDate,
                                          icon: Icons.calendar_month_rounded,
                                          primaryColor: primaryColor,
                                          onDateSelected: (dt) =>
                                              setState(() => _startDate = dt),
                                        ),
                                        const Gap(32),
                                      ]
                                      .animate(interval: 40.ms)
                                      .fade(
                                        duration: 250.ms,
                                        curve: Curves.easeOutCubic,
                                      )
                                      .scale(
                                        begin: const Offset(0.95, 0.95),
                                        duration: 250.ms,
                                        curve: Curves.easeOutCubic,
                                      ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Details Section
                    const FormSectionTitle(title: 'Details'),
                    const Gap(12),
                    Column(
                          children: [
                            // Category Picker
                            Builder(
                              builder: (context) {
                                Widget child = SelectionTile(
                                  fallbackIcon: Icons.category_rounded,
                                  label: 'Category',
                                  selectedName: categoriesState.when(
                                    data: (categories) => categories
                                        .where(
                                          (c) => c.id == _selectedCategoryId,
                                        )
                                        .firstOrNull
                                        ?.name,
                                    loading: () => null,
                                    error: (_, stackTrace) => null,
                                  ),
                                  selectedColor: categoriesState.when(
                                    data: (categories) => categories
                                        .where(
                                          (c) => c.id == _selectedCategoryId,
                                        )
                                        .firstOrNull
                                        ?.color,
                                    loading: () => null,
                                    error: (_, stackTrace) => null,
                                  ),
                                  selectedIconCodePoint: categoriesState.when(
                                    data: (categories) => categories
                                        .where(
                                          (c) => c.id == _selectedCategoryId,
                                        )
                                        .firstOrNull
                                        ?.iconCodePoint,
                                    loading: () => null,
                                    error: (_, stackTrace) => null,
                                  ),
                                  placeholder: 'Select Category',
                                  onTap: () => _openCategoryPicker(context),
                                );

                                if (_autoCatKey > 0) {
                                  child = child
                                      .animate(key: ValueKey(_autoCatKey))
                                      .shimmer(
                                        duration: 400.ms,
                                        color: primaryColor.withValues(
                                          alpha: 0.2,
                                        ),
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
                            const Gap(12),
                            // Account Picker
                            SelectionTile(
                              fallbackIcon:
                                  Icons.account_balance_wallet_rounded,
                              label: _isIncome
                                  ? 'Receiving Account'
                                  : 'Payment Account',
                              selectedName: accountsState.when(
                                data: (accounts) => accounts
                                    .where((a) => a.id == _selectedAccountId)
                                    .firstOrNull
                                    ?.name,
                                loading: () => null,
                                error: (_, stackTrace) => null,
                              ),
                              selectedColor: accountsState.when(
                                data: (accounts) => accounts
                                    .where((a) => a.id == _selectedAccountId)
                                    .firstOrNull
                                    ?.color,
                                loading: () => null,
                                error: (_, stackTrace) => null,
                              ),
                              selectedIconCodePoint: accountsState.when(
                                data: (accounts) => accounts
                                    .where((a) => a.id == _selectedAccountId)
                                    .firstOrNull
                                    ?.iconCodePoint,
                                loading: () => null,
                                error: (_, stackTrace) => null,
                              ),
                              selectedLogoAsset: accountsState.when(
                                data: (accounts) => accounts
                                    .where((a) => a.id == _selectedAccountId)
                                    .firstOrNull
                                    ?.logoAsset,
                                loading: () => null,
                                error: (_, stackTrace) => null,
                              ),
                              placeholder: 'Select Account',
                              onTap: () => _openAccountPicker(context),
                            ),
                            const Gap(12),
                            // Auto Process Toggle
                            _buildAutoProcessRow(context, primaryColor),
                            const Gap(12),
                            // Notes field
                            _buildNotesInput(context),
                          ],
                        )
                        .animate()
                        .fade(duration: 250.ms, curve: Curves.easeOutCubic)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KoinSpacing.screenInset,
                ),
                child: PressableScale(
                  onTap: _savePayment,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          primaryColor,
                          primaryColor.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        AppTheme.boxShadow(
                          context,
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Create $_domainNoun',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: KoinTypography.itemTitle,
                        fontWeight: KoinTypography.titleWeight,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fade(duration: 250.ms, curve: Curves.easeOutCubic)
              .scale(
                begin: const Offset(0.95, 0.95),
                duration: 250.ms,
                curve: Curves.easeOutCubic,
              ),
    );
  }

  Widget _buildAutoProcessRow(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.fieldBorderColor(context, lightOpacity: 0.7),
        ),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.light();
            setState(() => _isAutoProcess = !_isAutoProcess);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Process $_domainNoun',
                        style: TextStyle(
                          fontSize: KoinTypography.overline,
                          fontWeight: KoinTypography.labelWeight,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.65),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        'Create transaction automatically',
                        style: TextStyle(
                          fontSize: KoinTypography.compact,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isAutoProcess,
                  activeThumbColor: primaryColor,
                  onChanged: (val) {
                    HapticService.light();
                    setState(() => _isAutoProcess = val);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.fieldBorderColor(context, lightOpacity: 0.7),
        ),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLightColor(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.sticky_note_2_rounded,
                size: 17,
                color: AppTheme.textLightColor(context),
              ),
            ),
            const Gap(12),
            Expanded(
              child: TextField(
                controller: _notesController,
                onTap: () {
                  HapticService.light();
                },
                style: TextStyle(
                  fontWeight: KoinTypography.labelWeight,
                  fontSize: KoinTypography.body,
                  color: AppTheme.textColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Notes (Optional)',
                  hintStyle: TextStyle(
                    color: AppTheme.fieldHintColor(context, lightOpacity: 0.45),
                    fontWeight: FontWeight.w400,
                    fontSize: KoinTypography.body,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
