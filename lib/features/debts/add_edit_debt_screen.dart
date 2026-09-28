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
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/widgets/select_sheet.dart';
import 'package:koin/core/widgets/account_item.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/utils/snackbar_utils.dart';
import 'package:koin/core/widgets/koin_back_button.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:koin/features/debts/widgets/add_purchase_sheet.dart';
import 'package:koin/core/widgets/confirmation_sheet.dart';
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
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _installmentsController.dispose();
    _tabController.dispose();
    super.dispose();
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
                    _buildSectionTitle(context, 'Type'),
                    const Gap(12),
                    _buildPremiumTypeSwitcher(
                      context,
                      primaryColor,
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Installment Plan
                    _buildSectionTitle(context, 'Installment Plan (Optional)'),
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
                    _buildSectionTitle(
                      context,
                      int.tryParse(_installmentsController.text) != null &&
                              int.parse(_installmentsController.text) > 0
                          ? 'Start Payment Date'
                          : 'Record Date',
                    ),
                    const Gap(12),
                    _buildDateSelector(
                      context,
                      label: int.tryParse(_installmentsController.text) != null &&
                              int.parse(_installmentsController.text) > 0
                          ? 'Start Payment Date'
                          : 'Record Date',
                      date: _startDate,
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final dt = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (dt != null) {
                          setState(() => _startDate = dt);
                        }
                      },
                    ).animate().fade(duration: 250.ms, curve: Curves.easeOutCubic).scale(begin: const Offset(0.95, 0.95), duration: 250.ms, curve: Curves.easeOutCubic),
                    const Gap(32),

                    // Details Section
                    _buildSectionTitle(context, 'Details'),
                    const Gap(12),
                    Column(
                      children: [
                        // Account Picker (Optional)
                        _buildSelectionRow(
                          context,
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
                        _buildSelectionRow(
                          context,
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textLightColor(context),
        letterSpacing: 1.2,
      ),
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

          // Amount Input
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${currency.symbol} ',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
              IntrinsicWidth(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: _amountController.text.isEmpty
                        ? primaryColor.withValues(alpha: 0.35)
                        : primaryColor,
                    letterSpacing: -2,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      color: primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          // Little subtle animated underline
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _amountController.text.isNotEmpty ? 60 : 40,
            height: 3,
            margin: const EdgeInsets.only(top: 8, bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: primaryColor.withValues(
                alpha: _amountController.text.isNotEmpty ? 0.35 : 0.15,
              ),
            ),
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

  Widget _buildDateSelector(
    BuildContext context, {
    required String label,
    required DateTime date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: () async {
        final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
        FocusManager.instance.primaryFocus?.unfocus();
        if (hadFocus) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const Gap(6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              DateFormat.yMMMd().format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
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
  }) {
    final hasSelection =
        selectedName != null &&
        selectedColor != null &&
        selectedIconCodePoint != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticService.light();
            final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
            FocusManager.instance.primaryFocus?.unfocus();
            if (hadFocus) {
              await Future.delayed(const Duration(milliseconds: 150));
            }
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                const Gap(4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.4),
                  size: 22,
                ),
              ],
            ),
          ),
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
    final filtered = categories.where((c) => c.type == categoryType).toList();

    final id = await _showPremiumSelectionSheet<String>(
      context: context,
      title: 'Category',
      subtitle: _selectedType == DebtType.owedToMe
          ? 'Link an income category'
          : 'Link an expense category',
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final cat = filtered[index];
        return _PremiumSheetItem(
          name: cat.name,
          accentColor: cat.color,
          iconCodePoint: cat.iconCodePoint,
          selected: cat.id == _selectedCategoryId,
          onTap: () => Navigator.pop(context, cat.id),
        );
      },
    );
    if (id != null && mounted) {
      setState(() => _selectedCategoryId = id);
    }
  }

  Future<void> _openAccountPicker(
    BuildContext context,
    List<Account> accounts,
  ) async {
    final stats = ref.read(dashboardStatsProvider);
    final currency = ref.read(settingsProvider).currency;
    final id = await showSelectSheet<String>(
      context: context,
      title: 'Account',
      subtitle: 'Where is this money from/going?',
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        return Consumer(
          builder: (context, ref, _) {
            final liveAccounts = ref.watch(accountProvider).value ?? [];
            final acc = liveAccounts.firstWhere(
              (a) => a.id == accounts[index].id,
              orElse: () => accounts[index],
            );
            final balance = stats.accountBalances[acc.id] ?? 0.0;
            return AccountItem(
              account: acc,
              balance: balance,
              currencySymbol: currency.symbol,
              isSelected: acc.id == _selectedAccountId,
              onTap: () => Navigator.pop(context, acc.id),
            );
          },
        );
      },
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
    final freq = await _showPremiumSelectionSheet<InstallmentFrequency>(
      context: context,
      title: 'Payment Frequency',
      subtitle: 'How often are payments made?',
      itemCount: frequencies.length,
      itemBuilder: (context, index) {
        final f = frequencies[index];
        return _PremiumSheetItem(
          name: f.name[0].toUpperCase() + f.name.substring(1),
          accentColor: primaryColor,
          iconCodePoint: Icons.event_repeat_rounded.codePoint,
          selected: f == _selectedFrequency,
          onTap: () => Navigator.pop(context, f),
        );
      },
    );
    if (freq != null && mounted) {
      setState(() => _selectedFrequency = freq);
    }
  }

  Future<T?> _showPremiumSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    final typeColor = AppTheme.primaryColor(context);

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(sheetContext).top + 12,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(sheetContext),
                  border: Border.all(
                    color: AppTheme.dividerColor(sheetContext),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(10),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dividerColor(sheetContext),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: typeColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const Gap(10),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: AppTheme.textColor(sheetContext),
                                ),
                              ),
                            ],
                          ),
                          const Gap(4),
                          Padding(
                            padding: const EdgeInsets.only(left: 14),
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: AppTheme.textLightColor(sheetContext),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + bottomInset,
                        ),
                        itemCount: itemCount,
                        separatorBuilder: (context, index) => const Gap(8),
                        itemBuilder: (context, index) {
                          return itemBuilder(context, index)
                              .animate()
                              .fadeIn(delay: (index * 40).ms, duration: 250.ms)
                              .slideX(
                                begin: 0.04,
                                duration: 250.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildPurchasesSection(BuildContext context, Color primaryColor, List<TransactionCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(context, 'Purchases / Sub-Plans (Optional)'),
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

  void _showAddPurchaseSheet(BuildContext context, Color primaryColor, List<TransactionCategory> categories) {
    String name = '';
    String amountStr = '';
    String installmentsStr = '';
    DateTime firstDate = DateTime.now();
    TransactionCategory? selectedCategory;
    
    final pDate = _startDate;
    firstDate = DateTime(pDate.year, pDate.month, pDate.day);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool didAdd = false;

    showModalBottomSheet(
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
                        'Add Purchase', 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textColor(ctx), letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const Gap(24),
                    TextFormField(
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
                      onChanged: (v) => name = v,
                    ),
                    const Gap(16),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Total Amount',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppTheme.surfaceColor(ctx),
                      ),
                      style: TextStyle(color: AppTheme.textColor(ctx)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => amountStr = v,
                    ),
                    const Gap(16),
                    _buildSelectionRow(
                      ctx,
                      fallbackIcon: Icons.category_rounded,
                      label: 'Category (Optional)',
                      selectedName: selectedCategory?.name,
                      selectedColor: selectedCategory?.color,
                      selectedIconCodePoint: selectedCategory?.iconCodePoint,
                      placeholder: 'Select Category',
                      onTap: () async {
                        final categoryType = _selectedType == DebtType.owedToMe ? TransactionType.income : TransactionType.expense;
                        final filtered = categories.where((c) => c.type == categoryType).toList();
                        
                        final id = await _showPremiumSelectionSheet<String>(
                          context: ctx,
                          title: 'Category',
                          subtitle: _selectedType == DebtType.owedToMe
                              ? 'Link an income category'
                              : 'Link an expense category',
                          itemCount: filtered.length,
                          itemBuilder: (c, index) {
                            final cat = filtered[index];
                            return _PremiumSheetItem(
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
                    ),
                    const Gap(16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final dt = await showDatePicker(
                                context: ctx,
                                initialDate: firstDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (dt != null) setSheetState(() => firstDate = dt);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'First Payment',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: AppTheme.surfaceColor(ctx),
                                suffixIcon: Icon(Icons.calendar_month, color: primaryColor, size: 20),
                              ),
                              child: Text(
                                DateFormat.yMMMd().format(firstDate),
                                style: TextStyle(color: AppTheme.textColor(ctx), fontSize: 15),
                              ),
                            ),
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
                          didAdd = true;
                          HapticService.light();
                          setState(() {
                            _items.add(DebtItem(
                              id: const Uuid().v4(),
                              debtId: '',
                              name: name,
                              amount: amt,
                              totalInstallments: inst,
                              firstPaymentDate: firstDate,
                              categoryId: selectedCategory?.id,
                            ));
                            _updateAmountFromItems();
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Add to Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        );
      },
    );
  }
}

class _PremiumSheetItem extends StatelessWidget {
  const _PremiumSheetItem({
    required this.name,
    required this.accentColor,
    required this.iconCodePoint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color accentColor;
  final int iconCodePoint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.45)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.65),
              width: selected ? 1.5 : 1,
            ),
            color: selected
                ? primary.withValues(alpha: 0.08)
                : AppTheme.surfaceLightColor(context).withValues(alpha: 0.45),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  IconUtils.getIcon(iconCodePoint),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 26)
              else
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.25),
                          width: 1.5,
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
  }
}
