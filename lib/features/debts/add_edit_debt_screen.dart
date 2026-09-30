import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/models/category.dart';
import 'package:koin/core/models/debt_item.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/categorization/category_suggester.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/widgets/selection_tile.dart';
import 'package:koin/core/widgets/account_picker_sheet.dart';
import 'package:koin/core/widgets/category_picker_sheet.dart';
import 'package:koin/core/widgets/premium_selection_sheet.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/koin_back_button.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
import 'package:koin/core/widgets/date_selector_tile.dart';
import 'package:koin/core/widgets/form_section_title.dart';
import 'package:koin/core/widgets/hero_amount_field.dart';
import 'package:uuid/uuid.dart';

class AddEditDebtScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  const AddEditDebtScreen({super.key, this.debt});

  @override
  ConsumerState<AddEditDebtScreen> createState() => _AddEditDebtScreenState();
}

class _AddEditDebtScreenState extends ConsumerState<AddEditDebtScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
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
  late TabController _tabController;
  List<DebtItem> _items = [];
  Timer? _debounceTimer;
  int _autoCatKey = 0;

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
    } else {
      _selectedType = DebtType.owedToMe;
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedType == DebtType.owedToMe ? 0 : 1,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = _tabController.index == 0
              ? DebtType.owedToMe
              : DebtType.iOwe;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _installmentsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runAutoCategorization() async {
    if (!mounted) return;
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    final amt = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 1.0;
    final effectiveAmt = amt == 0.0 ? 1.0 : amt;
    final targetType = _selectedType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;

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

      if (suggestion != null && mounted) {
        final categories = ref.read(categoriesProvider).value ?? [];
        final matchedCat = categories.where((c) => c.id == suggestion.categoryId).firstOrNull;
        if (matchedCat != null) {
          if (_selectedCategoryId != matchedCat.id || (_selectedAccountId == null && suggestion.originAccountId != null && suggestion.originAccountId!.isNotEmpty)) {
            HapticService.light();
            setState(() {
              if (_selectedCategoryId != matchedCat.id) _autoCatKey++;
              _selectedCategoryId = matchedCat.id;
              if (_selectedAccountId == null && suggestion.originAccountId != null && suggestion.originAccountId!.isNotEmpty) {
                _selectedAccountId = suggestion.originAccountId;
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    final notes = _notesController.text.trim();
    final isEdit = widget.debt != null;
    final id = isEdit ? widget.debt!.id : const Uuid().v4();
    final currentAmount = isEdit ? widget.debt!.currentAmount : 0.0;

    final installmentsText = _installmentsController.text.trim();
    int installments = 0;
    if (installmentsText.isNotEmpty) {
      installments = int.tryParse(installmentsText) ?? 0;
    }

    final finalAmount = _items.isNotEmpty ? _items.fold(0.0, (sum, i) => sum + i.amount) : amount;

    final debt = Debt(
      id: id,
      personName: name,
      amount: finalAmount,
      type: _selectedType,
      startDate: _startDate,
      description: notes.isEmpty ? null : notes,
      totalInstallments: installments,
      frequency: _selectedFrequency,
      currentAmount: currentAmount,
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      items: _items,
    );

    if (isEdit) {
      await ref.read(debtsProvider.notifier).updateDebt(debt);
      final oldItems = widget.debt!.items;
      for (var oldItem in oldItems) {
        if (!_items.any((i) => i.id == oldItem.id)) {
          await ref.read(debtsProvider.notifier).deleteDebtItem(oldItem);
        }
      }
      for (var newItem in _items) {
        final existing = oldItems.where((i) => i.id == newItem.id).firstOrNull;
        if (existing == null) {
          await ref.read(debtsProvider.notifier).addDebtItem(newItem.copyWith(debtId: id));
        } else if (existing.amount != newItem.amount || existing.name != newItem.name || existing.totalInstallments != newItem.totalInstallments || existing.firstPaymentDate != newItem.firstPaymentDate || existing.categoryId != newItem.categoryId) {
          await ref.read(debtsProvider.notifier).updateDebtItem(existing, newItem.copyWith(debtId: id));
        }
      }
      if (mounted) {
        KoinSnackBar.success(
          context,
          'Record updated',
          subtitle: 'Your record has been saved successfully',
        );
      }
    } else {
      await ref.read(debtsProvider.notifier).addDebt(debt);
      for (var item in _items) {
        await ref.read(debtsProvider.notifier).addDebtItem(item.copyWith(debtId: id));
      }
    }

    if (_selectedCategoryId != null && notes.isNotEmpty) {
      final targetType = _selectedType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;
      ref.read(categorySuggesterProvider).recordFeedback(
        text: notes,
        amount: finalAmount,
        type: targetType,
        originAccountId: _selectedAccountId ?? '',
        destinationId: _selectedCategoryId!,
      );
    }

    if (mounted) {
      HapticService.light();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.debt != null;
    final primaryColor = AppTheme.primaryColor(context);
    final accountsState = ref.watch(accountProvider);
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context, primaryColor),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type Selector
                    const FormSectionTitle.subhead(title: 'Type'),
                    const Gap(12),
                    _buildPremiumTypeSwitcher(
                      context,
                      primaryColor,
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Installment Plan
                    const FormSectionTitle.subhead(title: 'Installment Plan (Optional)'),
                    const Gap(12),
                    _buildInstallmentsCard(
                      context,
                      primaryColor,
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Purchases / Sub-Items
                    _buildPurchasesSection(context, primaryColor, categoriesState.value ?? []).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Date
                    FormSectionTitle.subhead(
                      title: int.tryParse(_installmentsController.text) != null &&
                              int.parse(_installmentsController.text) > 0
                          ? 'Start Payment Date'
                          : 'Record Date',
                    ),
                    const Gap(12),
                    DateSelectorTile(
                      label: int.tryParse(_installmentsController.text) != null &&
                              int.parse(_installmentsController.text) > 0
                          ? 'Start Payment Date'
                          : 'Record Date',
                      date: _startDate,
                      icon: Icons.calendar_today_rounded,
                      primaryColor: primaryColor,
                      onDateSelected: (dt) {
                        setState(() => _startDate = dt);
                      },
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Details Section
                    const FormSectionTitle.subhead(title: 'Details'),
                    const Gap(12),
                    Column(
                      children: [
                        // Account Picker (Optional)
                        SelectionTile(
                          fallbackIcon: Icons.account_balance_wallet_rounded,
                          label: 'Link to Account (Optional)',
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
                          onTap: () => accountsState.whenData(
                            (accounts) => _openAccountPicker(context, accounts),
                          ),
                        ),
                        const Gap(12),
                        // Category Picker (Optional)
                        Builder(
                          builder: (context) {
                            Widget child = SelectionTile(
                              fallbackIcon: Icons.category_rounded,
                              label: 'Link to Category (Optional)',
                              selectedName: categoriesState.when(
                                data: (cats) => cats
                                    .where((c) => c.id == _selectedCategoryId)
                                    .firstOrNull
                                    ?.name,
                                loading: () => null,
                                error: (_, _) => null,
                              ),
                              selectedColor: categoriesState.when(
                                data: (cats) => cats
                                    .where((c) => c.id == _selectedCategoryId)
                                    .firstOrNull
                                    ?.color,
                                loading: () => null,
                                error: (_, _) => null,
                              ),
                              selectedIconCodePoint: categoriesState.when(
                                data: (cats) => cats
                                    .where((c) => c.id == _selectedCategoryId)
                                    .firstOrNull
                                    ?.iconCodePoint,
                                loading: () => null,
                                error: (_, _) => null,
                              ),
                              placeholder: 'Select Category',
                              onTap: () => categoriesState.whenData(
                                (cats) => _openCategoryPicker(context, cats),
                              ),
                            );

                            if (_autoCatKey > 0) {
                              child = child
                                  .animate(key: ValueKey(_autoCatKey))
                                  .shimmer(
                                    duration: 400.ms,
                                    color: AppTheme.primaryColor(context)
                                        .withValues(alpha: 0.2),
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
                        // Notes Input
                        _buildNotesInput(context),
                      ],
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: PressableScale(
          onTap: _save,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              isEdit ? 'Update' : 'Create',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
    );
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
            color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Gap(topPadding + 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [const KoinBackButton(), const Spacer()]),
          ),
          const Gap(8),

          // Debt Name Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                hintText: 'Who is involved?',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          const Gap(4),

          HeroAmountField(
            controller: _amountController,
            currencySymbol: currency.symbol,
            primaryColor: primaryColor,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTypeSwitcher(BuildContext context, Color primaryColor) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          _buildSwitcherItem(
            context,
            'I am owed',
            DebtType.owedToMe,
            AppTheme.incomeColor(context),
          ),
          _buildSwitcherItem(
            context,
            'I owe',
            DebtType.iOwe,
            AppTheme.expenseColor(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitcherItem(
    BuildContext context,
    String label,
    DebtType type,
    Color activeColor,
  ) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          setState(() {
            _selectedType = type;
            _tabController.animateTo(type == DebtType.owedToMe ? 0 : 1);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AppTheme.textLightColor(context),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildInstallmentsCard(BuildContext context, Color primaryColor) {
    final settings = ref.read(settingsProvider);
    final currencyFormat = NumberFormat.simpleCurrency(
      name: settings.currency.code,
    );

    double? paymentAmount;
    final amtStr = _amountController.text.replaceAll(',', '');
    final amt = double.tryParse(amtStr) ?? 0.0;
    final inst = int.tryParse(_installmentsController.text) ?? 0;
    if (amt > 0 && inst > 0) {
      paymentAmount = amt / inst;
    }

    final freqName =
        _selectedFrequency.name[0].toUpperCase() +
        _selectedFrequency.name.substring(1);

    final String frequencySuffix = switch (_selectedFrequency) {
      InstallmentFrequency.weekly => '/ week',
      InstallmentFrequency.biweekly => '/ 2 weeks',
      InstallmentFrequency.monthly => '/ month',
      InstallmentFrequency.yearly => '/ year',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.dividerColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Count (Optional)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Gap(6),
                    Row(
                      children: [
                        Icon(
                          Icons.tag_rounded,
                          size: 16,
                          color: primaryColor.withValues(alpha: 0.8),
                        ),
                        const Gap(8),
                        Expanded(
                          child: TextFormField(
                            controller: _installmentsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                            ),
                            onTap: () => HapticService.light(),
                            onChanged: (val) {
                              final count = int.tryParse(val) ?? 0;
                              setState(() {
                                if (count > 0 && !_frequencyUserSet) {
                                  _selectedFrequency = InstallmentFrequency.monthly;
                                }
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'None',
                              hintStyle: TextStyle(
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.3),
                              ),
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(12),
            Expanded(
              child: PressableScale(
                onTap: () {
                  if (inst <= 0) return;
                  HapticService.light();
                  _frequencyUserSet = true;
                  _openFrequencyPicker(context, primaryColor);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.dividerColor(
                        context,
                      ).withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequency',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Gap(6),
                      Row(
                        children: [
                          Icon(
                            Icons.event_repeat_rounded,
                            size: 16,
                            color: inst > 0
                                ? primaryColor.withValues(alpha: 0.8)
                                : AppTheme.textLightColor(context).withValues(alpha: 0.3),
                          ),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              inst > 0 ? freqName : 'None',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: inst > 0
                                    ? AppTheme.textColor(context)
                                    : AppTheme.textLightColor(context).withValues(alpha: 0.35),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 16,
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: inst > 0 ? 0.4 : 0.2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (paymentAmount != null) ...[
          const Gap(12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Payment',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const Gap(2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            currencyFormat.format(paymentAmount),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            frequencySuffix,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesInput(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
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
                onChanged: (_) {
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(
                    const Duration(milliseconds: 350),
                    _runAutoCategorization,
                  );
                },
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Notes (Optional)',
                  hintStyle: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.45),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
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
      setState(() => _selectedCategoryId = id);
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
    final freq = await PremiumSelectionSheet.show<InstallmentFrequency>(
      context: context,
      title: 'Payment Frequency',
      subtitle: 'How often are payments made?',
      indicatorColor: primaryColor,
      itemCount: frequencies.length,
      itemBuilder: (sheetContext, index) {
        final f = frequencies[index];
        return PremiumSheetItem(
          name: f.name[0].toUpperCase() + f.name.substring(1),
          accentColor: primaryColor,
          iconCodePoint: Icons.event_repeat_rounded.codePoint,
          selected: f == _selectedFrequency,
          onTap: () => Navigator.pop(sheetContext, f),
        );
      },
    );
    if (freq != null && mounted) {
      setState(() => _selectedFrequency = freq);
    }
  }
  Widget _buildPurchasesSection(BuildContext context, Color primaryColor, List<TransactionCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormSectionTitle.subhead(title: 'Purchases / Sub-Plans (Optional)'),
        const Gap(12),
        if (_items.isNotEmpty)
          ..._items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: PressableScale(
              onTap: () async {
                HapticService.light();
                final updatedItem = await showAddPurchaseSheet(
                  context: context,
                  debtType: _selectedType,
                  primaryColor: primaryColor,
                  categories: categories,
                  defaultDate: _startDate,
                  existingItem: item,
                );
                if (updatedItem != null) {
                  setState(() {
                    final index = _items.indexOf(item);
                    if (index != -1) {
                      _items[index] = updatedItem;
                      _updateAmountFromItems();
                    }
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor(context).withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name, 
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textColor(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          Text(
                            '${item.totalInstallments} months • Starts ${DateFormat.MMMd().format(item.firstPaymentDate)}', 
                            style: TextStyle(color: AppTheme.textLightColor(context), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    Text(
                      NumberFormat.simpleCurrency(name: ref.read(settingsProvider).currency.code).format(item.amount),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryColor),
                      textAlign: TextAlign.right,
                    ),
                    const Gap(12),
                    GestureDetector(
                      onTap: () async {
                        HapticService.light();
                        final confirm = await ConfirmationSheet.show(
                          context: context,
                          title: 'Remove Purchase?',
                          description: 'Are you sure you want to remove "${item.name}"? This will not update your existing credit limit.',
                          confirmLabel: 'Remove',
                          confirmColor: AppTheme.expenseColor(context),
                          icon: Icons.delete_outline_rounded,
                          isDanger: true,
                        );
                        if (confirm == true) {
                          setState(() {
                             _items.remove(item);
                             _updateAmountFromItems();
                          });
                        }
                      },
                      child: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.expenseColor(context), size: 24),
                    ),
                  ],
                ),
              ),
            ),
          )),
        
        PressableScale(
          onTap: () async {
            HapticService.light();
            final newItem = await showAddPurchaseSheet(
              context: context,
              debtType: _selectedType,
              primaryColor: primaryColor,
              categories: categories,
              defaultDate: _startDate,
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
                Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: 20),
                const Gap(8),
                Text('Add Purchase / Sub-Plan', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateAmountFromItems() {
    if (_items.isNotEmpty) {
      final total = _items.fold(0.0, (sum, i) => sum + i.amount);
      _amountController.text = total.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }
  }
}
