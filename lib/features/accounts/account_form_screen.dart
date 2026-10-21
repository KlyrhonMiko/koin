import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/widgets/cards/account_card_layout.dart';
import 'package:koin/core/widgets/cards/account_card_amount.dart';
import 'package:koin/core/widgets/inputs/grouped_amount_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  bool _saving = false;
  late final TextEditingController nameController;
  late final TextEditingController balanceController;
  late final TextEditingController transferFeeController;
  late final TextEditingController interestRateController;
  late final TextEditingController interestTaxController;
  late final String _openingBalanceText;
  late bool _dailyInterestEnabled;
  late InterestPayoutFrequency _interestFrequency;
  bool _showInterestDetails = false;
  late int selectedIcon;
  late Color selectedColor;
  late bool excludeFromTotal;
  late bool isTransferFeePercentage;
  late bool isCredit;
  String? selectedLogoAsset;
  String? selectedTemplateId;
  String? _suggestedName;
  bool _colorInitialized = false;
  Color? selectedCardColor; // null = Default (no explicit card background)
  final ScrollController _iconScrollController = ScrollController();
  final ScrollController _colorScrollController = ScrollController();
  final ScrollController _cardColorScrollController = ScrollController();
  final ScrollController _cardShapeScrollController = ScrollController();
  final ScrollController _templateScrollController = ScrollController();
  int? selectedCardShape;

  final List<IconData> icons = [
    KoinIcons.wallet,
    KoinIcons.bank,
    KoinIcons.piggyBank,
    KoinIcons.money,
    KoinIcons.creditCard,
    KoinIcons.wallet,
    KoinIcons.money,
    KoinIcons.currencyCircleDollar,
    KoinIcons.trendUp,
    KoinIcons.currencyCircleDollar,
    KoinIcons.currencyCircleDollar,
    KoinIcons.money,
    KoinIcons.invoice,
    KoinIcons.treeStructure,
    KoinIcons.briefcase,
    KoinIcons.storefront,
    KoinIcons.currencyBtc,
    KoinIcons.currencyGbp,
    KoinIcons.currencyJpy,
    KoinIcons.coins,
  ];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.account != null;
    nameController = TextEditingController(text: widget.account?.name)
      ..addListener(_onNameChanged);

    String amountText = '';
    if (isEditing) {
      final dashboardStats = ref.read(dashboardStatsProvider);
      double currentBalance =
          dashboardStats.accountBalances[widget.account!.id] ??
          widget.account!.initialBalance;
      amountText = currentBalance == currentBalance.truncateToDouble()
          ? currentBalance.toInt().toString()
          : currentBalance.toStringAsFixed(
              ref.read(settingsProvider).currency.decimalDigits,
            );
    }

    balanceController = TextEditingController(
      text: GroupedAmountFormatter.formatText(amountText),
    )..addListener(_onInputChanged);
    _openingBalanceText = balanceController.text;
    _dailyInterestEnabled = widget.account?.hasInterest ?? false;
    _interestFrequency =
        widget.account?.interestFrequency ?? InterestPayoutFrequency.daily;
    interestRateController = TextEditingController(
      text: _dailyInterestEnabled
          ? widget.account!.annualInterestRate.toString()
          : '',
    )..addListener(_onInputChanged);
    interestTaxController = TextEditingController(
      text: _dailyInterestEnabled && widget.account!.interestTaxRate > 0
          ? widget.account!.interestTaxRate.toString()
          : '',
    )..addListener(_onInputChanged);

    transferFeeController = TextEditingController(
      text:
          widget.account?.transferFeeAmount != null &&
              widget.account!.transferFeeAmount > 0
          ? widget.account!.transferFeeAmount.toString()
          : '',
    )..addListener(_onInputChanged);
    selectedIcon =
        widget.account?.iconCodePoint ??
        KoinIcons.wallet.codePoint;
    excludeFromTotal = widget.account?.excludeFromTotal ?? false;
    isTransferFeePercentage = widget.account?.isTransferFeePercentage ?? false;
    isCredit = widget.account?.isCredit ?? false;
    selectedLogoAsset = widget.account?.logoAsset;
    selectedCardColor = widget.account?.cardColor;
    selectedCardShape = widget.account?.cardShapeType;

    // Find matching template for existing account
    if (widget.account?.logoAsset != null) {
      final matchingTemplate = BankTemplate.templates.where(
        (t) => t.logoAsset == widget.account!.logoAsset,
      );
      if (matchingTemplate.isNotEmpty) {
        selectedTemplateId = matchingTemplate.first.id;
      }
    }

    // Auto-scroll to selected icon and color
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToSelectedIcon();
      _scrollToSelectedColor();
      _scrollToSelectedCardColor();
      _scrollToSelectedTemplate();
    });
  }

  void _onNameChanged() {
    if (nameController.text != _suggestedName) {
      _suggestedName = null;
    }
    _onInputChanged();
  }

  void _onInputChanged() {
    setState(() {});
  }

  void _updateSuggestedName(BankTemplate template) {
    if (nameController.text.isNotEmpty &&
        nameController.text != _suggestedName) {
      return;
    }
    _suggestedName = isCredit ? '${template.name} Credit' : template.name;
    nameController.text = _suggestedName!;
  }

  void _setCredit(bool value) {
    HapticService.light();
    setState(() {
      isCredit = value;
      for (final template in BankTemplate.templates) {
        if (template.id == selectedTemplateId) {
          _updateSuggestedName(template);
          break;
        }
      }
    });
  }

  void _scrollToSelectedIcon() {
    final index = icons.indexWhere((icon) => icon.codePoint == selectedIcon);
    if (index != -1 && _iconScrollController.hasClients) {
      final offset = index * 60.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 30)
          .clamp(0.0, _iconScrollController.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        _iconScrollController.jumpTo(targetOffset);
      } else {
        _iconScrollController.animateTo(
          targetOffset,
          duration: KoinMotion.entrance,
          curve: KoinMotion.curve,
        );
      }
    }
  }

  void _scrollToSelectedColor() {
    final index = AppTheme.accentColors.indexWhere(
      (c) => c.toARGB32() == selectedColor.toARGB32(),
    );
    if (index != -1 && _colorScrollController.hasClients) {
      final offset = index * 56.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 28)
          .clamp(0.0, _colorScrollController.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        _colorScrollController.jumpTo(targetOffset);
      } else {
        _colorScrollController.animateTo(
          targetOffset,
          duration: KoinMotion.entrance,
          curve: KoinMotion.curve,
        );
      }
    }
  }

  void _scrollToSelectedTemplate() {
    if (selectedTemplateId == null || !_templateScrollController.hasClients) {
      return;
    }
    final templateIndex = BankTemplate.templates.indexWhere(
      (t) => t.id == selectedTemplateId,
    );
    if (templateIndex != -1) {
      final offset = (templateIndex + 1) * 88.0; // +1 for "Custom" item
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 44)
          .clamp(0.0, _templateScrollController.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        _templateScrollController.jumpTo(targetOffset);
      } else {
        _templateScrollController.animateTo(
          targetOffset,
          duration: KoinMotion.entrance,
          curve: KoinMotion.curve,
        );
      }
    }
  }

  void _scrollToSelectedCardColor() {
    if (selectedCardColor == null || !_cardColorScrollController.hasClients) {
      return;
    }
    final index = AppTheme.cardColors.indexWhere(
      (c) => c.toARGB32() == selectedCardColor!.toARGB32(),
    );
    if (index != -1) {
      final offset = 80.0 + index * 56.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 28)
          .clamp(0.0, _cardColorScrollController.position.maxScrollExtent);
      if (MediaQuery.disableAnimationsOf(context)) {
        _cardColorScrollController.jumpTo(targetOffset);
      } else {
        _cardColorScrollController.animateTo(
          targetOffset,
          duration: KoinMotion.entrance,
          curve: KoinMotion.curve,
        );
      }
    }
  }

  void _applyTemplate(BankTemplate? template) {
    HapticService.light();
    setState(() {
      if (template == null) {
        selectedTemplateId = null;
        _suggestedName = null;
        selectedLogoAsset = null;
        selectedIcon = icons.first.codePoint;
        selectedColor = AppTheme.accentColors.first;
      } else {
        selectedTemplateId = template.id;
        selectedLogoAsset = template.logoAsset;
        _updateSuggestedName(template);
        selectedIcon = template.iconCodePoint;
        selectedColor = Color(
          int.parse(template.colorHex.replaceFirst('#', '0xFF')),
        );
      }
    });

    // Auto-scroll to selected icon and color
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedIcon();
      _scrollToSelectedColor();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_colorInitialized) {
      if (widget.account != null) {
        selectedColor = widget.account!.color;
      } else {
        selectedColor = AppTheme.primaryColor(context);
      }
      _colorInitialized = true;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    transferFeeController.dispose();
    interestRateController.dispose();
    interestTaxController.dispose();
    _iconScrollController.dispose();
    _colorScrollController.dispose();
    _cardColorScrollController.dispose();
    _cardShapeScrollController.dispose();
    _templateScrollController.dispose();
    super.dispose();
  }

  final KoinAsyncActionGuard _deleteGuard = KoinAsyncActionGuard();

  Future<void> _deleteAccount() => _deleteGuard.run(
    context,
    () => _deleteAccountImpl(),
    errorTitle: 'Could not delete this item',
  );

  Future<void> _deleteAccountImpl() async {
    HapticService.medium();
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Account?',
      description: 'All transactions associated with this account will be unlinked. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.errorColor(context),
      icon: KoinIcons.trash,
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      try {
        await ref
            .read(accountProvider.notifier)
            .deleteAccount(widget.account!.id);
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          KoinSnackBar.error(
            context,
            'Could not delete account',
            subtitle: 'Your account is kept. Try again.',
          );
        }
      }
    }
  }

  Future<void> _saveAccount() async {
    if (_saving) return;
    final balance = ref
        .read(settingsProvider)
        .currency
        .tryParseInput(balanceController.text);
    final fee = ref
        .read(settingsProvider)
        .currency
        .tryParseInput(
          transferFeeController.text.isEmpty ? '0' : transferFeeController.text,
          precision: isTransferFeePercentage ? 2 : null,
        );
    if (nameController.text.trim().isEmpty ||
        balance == null ||
        !balance.isFinite ||
        fee == null ||
        !fee.isFinite ||
        fee < 0) {
      KoinSnackBar.error(
        context,
        'Check account details',
        subtitle: 'Enter a name, a valid balance, and a non-negative fee.',
      );
      return;
    }
    if (_dailyInterestEnabled &&
        !isCredit &&
        !DailyInterest.validRates(
          _interestRate ?? double.nan,
          _interestTax ?? double.nan,
        )) {
      KoinSnackBar.error(
        context,
        'Check interest rates',
        subtitle: 'Enter an annual rate above 0% up to 100%, and tax from 0% to 100%.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _saveAccountImpl();
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not save account',
          subtitle: 'Your changes are kept. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAccountImpl() async {
    if (nameController.text.isNotEmpty) {
      // Finish outstanding days with the old rate before changing or disabling it.
      if (widget.account?.hasInterest ?? false) {
        await ref.read(dailyInterestProvider.notifier).processDue();
        await ref.read(transactionProvider.future);
      }
      HapticService.success();
      final isEditing = widget.account != null;
      final cardHex = selectedCardColor == null
          ? null
          : '#${selectedCardColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

      double newInitialBalance =
          ref
              .read(settingsProvider)
              .currency
              .tryParseInput(balanceController.text) ??
          0.0;
      if (isEditing && balanceController.text == _openingBalanceText) {
        // Automatic interest received while editing must not be erased by an
        // unchanged balance field that still shows the opening value.
        newInitialBalance = widget.account!.initialBalance;
      } else if (isEditing) {
        final dashboardStats = ref.read(dashboardStatsProvider);
        final currentBalance =
            dashboardStats.accountBalances[widget.account!.id] ??
            widget.account!.initialBalance;
        newInitialBalance = widget.account!.computeAdjustedInitialBalance(
          targetBalance: newInitialBalance,
          currentBalance: currentBalance,
        );
      }

      final updatedAccount = Account(
        isArchived: widget.account?.isArchived ?? false,
        id: isEditing ? widget.account!.id : const Uuid().v4(),
        name: nameController.text.trim(),
        initialBalance: newInitialBalance,
        iconCodePoint: selectedIcon,
        colorHex:
            '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        excludeFromTotal: excludeFromTotal,
        isCredit: isCredit,
        annualInterestRate: _dailyInterestEnabled && !isCredit
            ? _interestRate!
            : 0,
        interestTaxRate: _dailyInterestEnabled && !isCredit ? _interestTax! : 0,
        interestFrequency: _interestFrequency,
        interestStartDate: _dailyInterestEnabled && !isCredit
            ? widget.account?.hasInterest == true
                  ? widget.account!.interestStartDate
                  : DailyInterest.day(DateTime.now())
            : null,
        transferFeeAmount:
            ref
                .read(settingsProvider)
                .currency
                .tryParseInput(
                  transferFeeController.text,
                  precision: isTransferFeePercentage ? 2 : null,
                ) ??
            0.0,
        isTransferFeePercentage: isTransferFeePercentage,
        position: isEditing
            ? widget.account!.position
            : ref.read(accountProvider).value?.length ?? 0,
        logoAsset: selectedLogoAsset,
        cardColorHex: cardHex,
        cardShapeType: selectedCardShape,
      );

      if (isEditing) {
        await ref.read(accountProvider.notifier).updateAccount(updatedAccount);
      } else {
        await ref.read(accountProvider.notifier).addAccount(updatedAccount);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  /// Whether the preview card has a coloured (non-default) background.
  bool get _previewHasColoredBackground =>
      selectedCardColor != null || selectedLogoAsset != null;

  Widget _buildAccountPreview(BuildContext context, Currency currency) {
    String hex(Color color) =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    final account = Account(
      id: widget.account?.id ?? 'account_preview',
      name: nameController.text.trim(),
      iconCodePoint: selectedIcon,
      colorHex: hex(selectedColor),
      logoAsset: selectedLogoAsset,
      cardColorHex: selectedCardColor == null ? null : hex(selectedCardColor!),
      cardShapeType: selectedCardShape,
    );
    final foreground = account.cardForeground ?? Colors.white;
    final primary = _previewHasColoredBackground
        ? foreground
        : AppTheme.textColor(context);
    final secondary = _previewHasColoredBackground
        ? foreground.withValues(alpha: 0.9)
        : AppTheme.textLightColor(context);
    final balance = currency.tryParseInput(balanceController.text) ?? 0;
    return AccountCardLayout(
      account: account,
      name: Text(
        account.name.isEmpty ? 'Account name' : account.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: secondary,
          fontWeight: KoinTypography.labelWeight,
          fontSize: KoinTypography.caption,
          height: 1.25,
        ),
      ),
      amount: SizedBox(
        height:
            MediaQuery.textScalerOf(context)
                .scale(KoinTypography.sectionTitle) *
            1.25,
        child: AccountCardAmount(
          value: balance,
          currency: currency,
          style: TextStyle(
            color: primary,
            fontWeight: KoinTypography.titleWeight,
            fontSize: KoinTypography.sectionTitle,
            height: 1.25,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountFields(BuildContext context, Currency currency) {
    final style = TextStyle(
      fontSize: KoinTypography.itemTitle,
      fontWeight: KoinTypography.labelWeight,
      color: AppTheme.textColor(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, 'Account name'),
        TextField(
          key: const ValueKey('account_name_field'),
          controller: nameController,
          minLines: 1,
          maxLines: null,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: style.copyWith(fontSize: KoinTypography.cardAmount),
          decoration: InputDecoration(
            filled: false,
            border: const UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.fieldBorderColor(context)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.primaryColor(context),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            hintText: 'e.g. Everyday account',
          ),
        ),
        const Gap(24),
        _fieldLabel(context, 'Balance'),
        TextField(
          key: const ValueKey('account_balance_field'),
          controller: balanceController,
          inputFormatters: const [GroupedAmountFormatter()],
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          textInputAction: TextInputAction.done,
          style: style.copyWith(fontSize: KoinTypography.formTitle),
          decoration: InputDecoration(
            filled: false,
            border: const UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.fieldBorderColor(context)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.primaryColor(context),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            hintText: '0.00',
            prefixText: '${currency.symbol} ',
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textLightColor(context),
        fontSize: KoinTypography.caption,
        fontWeight: KoinTypography.labelWeight,
      ),
    ),
  );

  Widget _sectionLabel(BuildContext context, String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.textColor(context),
        fontSize: KoinTypography.sectionTitle,
        fontWeight: KoinTypography.titleWeight,
      ),
    ),
  );

  Widget _settingRow(
    BuildContext context, {
    required String title,
    String? hint,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final enabled = onChanged != null;
    final disabledColor = AppTheme.textLightColor(context)
        .withValues(alpha: 0.45);
    final tile = SwitchListTile.adaptive(
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: KoinTypography.body,
                fontWeight: KoinTypography.labelWeight,
                color: enabled ? AppTheme.textColor(context) : disabledColor,
              ),
            ),
          ),
          if (!enabled) ...[
            const Gap(8),
            Icon(KoinIcons.lockSimple, size: 16, color: disabledColor),
          ],
        ],
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).colorScheme.onPrimary,
      activeTrackColor: AppTheme.primaryColor(context),
      inactiveThumbColor: enabled
          ? AppTheme.textLightColor(context)
          : disabledColor,
      inactiveTrackColor: enabled
          ? AppTheme.fieldBorderColor(context)
          : AppTheme.fieldBorderColor(context).withValues(alpha: 0.25),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
    return hint == null ? tile : Tooltip(message: hint, child: tile);
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    title: 'Discard account changes?',
    draft: () => (
      nameController.text,
      balanceController.text,
      transferFeeController.text,
      interestRateController.text,
      interestTaxController.text,
      _dailyInterestEnabled,
      _interestFrequency,
      selectedIcon,
      selectedColor,
      excludeFromTotal,
      isTransferFeePercentage,
      isCredit,
      selectedLogoAsset,
      selectedCardColor,
      selectedCardShape,
    ),
    listenables: [
      nameController,
      balanceController,
      transferFeeController,
      interestRateController,
      interestTaxController,
    ],
    isSaving: () => _saving,
    child: KoinFormTheme(builder: _buildContent),
  );

  double? get _interestRate => ref
      .read(settingsProvider)
      .currency
      .tryParseInput(interestRateController.text, precision: 6);

  double? get _interestTax => ref
      .read(settingsProvider)
      .currency
      .tryParseInput(
        interestTaxController.text.isEmpty ? '0' : interestTaxController.text,
        precision: 6,
      );

  Future<void> _selectInterestFrequency() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showRadioSelectionSheet<InterestPayoutFrequency>(
      context: context,
      title: 'Interest paid',
      options: InterestPayoutFrequency.values,
      selected: _interestFrequency,
      label: (frequency) => frequency.label,
      showCheckmark: true,
      compact: true,
      itemKey: (frequency) => ValueKey('interest_frequency_${frequency.name}'),
    );
    if (selected != null && mounted) {
      setState(() => _interestFrequency = selected);
    }
  }

  Widget _interestPercentageField(
    BuildContext context, {
    required String label,
    required String semanticLabel,
    required String fieldKey,
    required TextEditingController controller,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: _fieldLabel(context, label)),
      Semantics(
        label: semanticLabel,
        child: TextField(
          key: ValueKey(fieldKey),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          style: TextStyle(
            fontSize: KoinTypography.cardAmount,
            fontWeight: KoinTypography.titleWeight,
            color: AppTheme.textColor(context),
          ),
          decoration: InputDecoration(
            hintText: '0',
            suffixIcon: Center(
              widthFactor: 1,
              child: Text(
                '%',
                style: TextStyle(
                  color: AppTheme.textLightColor(context),
                  fontSize: KoinTypography.body,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 48,
            ),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: const UnderlineInputBorder(),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.fieldBorderColor(context)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.primaryColor(context),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildInterestFields(BuildContext context, Currency currency) {
    final estimate = DailyInterest.estimatePayout(
      balance: currency.tryParseInput(balanceController.text) ?? 0,
      annualRate: _interestRate ?? 0,
      taxRate: _interestTax ?? 0,
      decimalDigits: currency.decimalDigits,
      frequency: _interestFrequency,
      at: DateTime.now(),
    );
    final start = widget.account?.hasInterest == true
        ? widget.account!.interestStartDate!
        : DailyInterest.day(DateTime.now());
    final processing = ref.watch(dailyInterestProvider);
    final earned = widget.account == null
        ? 0.0
        : (ref.watch(transactionProvider).value ?? <AppTransaction>[])
              .where(
                (t) =>
                    t.accountId == widget.account!.id &&
                    t.type == TransactionType.income &&
                    t.id.startsWith('interest:${widget.account!.id}:'),
              )
              .fold<double>(0, (sum, t) => sum + t.amount);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            [
                  TextButton(
                    key: const ValueKey('account_interest_frequency_field'),
                    onPressed: _selectInterestFrequency,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppTheme.textColor(context),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Interest paid',
                            style: TextStyle(
                              fontSize: KoinTypography.caption,
                              color: AppTheme.textLightColor(context),
                            ),
                          ),
                        ),
                        Text(
                          _interestFrequency.label,
                          style: const TextStyle(fontSize: KoinTypography.body),
                        ),
                        const Gap(6),
                        Icon(
                          KoinIcons.caretRight,
                          color: AppTheme.textLightColor(context),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final rate = _interestPercentageField(
                        context,
                        label: 'Annual rate',
                        semanticLabel: 'Annual interest rate (p.a.)',
                        fieldKey: 'account_interest_rate_field',
                        controller: interestRateController,
                      );
                      final tax = _interestPercentageField(
                        context,
                        label: 'Tax (optional)',
                        semanticLabel: 'Tax on interest (optional)',
                        fieldKey: 'account_interest_tax_field',
                        controller: interestTaxController,
                      );
                      if (constraints.maxWidth < 320 ||
                          MediaQuery.textScalerOf(context).scale(13) > 17) {
                        return Column(children: [rate, const Gap(16), tax]);
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: rate),
                          const Gap(24),
                          Expanded(child: tax),
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Est. ${currency.formatter.format(estimate)} / ${_interestFrequency.periodLabel} after tax',
                      style: TextStyle(
                        fontSize: KoinTypography.caption,
                        color: AppTheme.textLightColor(context),
                      ),
                    ),
                  ),
                  Column(
                    key: const ValueKey('account_interest_details'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        expanded: _showInterestDetails,
                        child: TextButton(
                          style:
                              TextButton.styleFrom(
                                foregroundColor: AppTheme.textLightColor(
                                  context,
                                ),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 48),
                                alignment: Alignment.centerLeft,
                                splashFactory: NoSplash.splashFactory,
                              ).copyWith(
                                overlayColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.focused)
                                      ? null
                                      : Colors.transparent,
                                ),
                              ),
                          onPressed: () {
                            HapticService.light();
                            setState(
                              () =>
                                  _showInterestDetails = !_showInterestDetails,
                            );
                          },
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'How it works',
                                  style: TextStyle(
                                    fontSize: KoinTypography.caption,
                                  ),
                                ),
                              ),
                              Icon(
                                _showInterestDetails
                                    ? KoinIcons.caretUp
                                    : KoinIcons.caretDown,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildInterestReveal(
                        context,
                        key: const ValueKey('account_interest_help_reveal'),
                        visible: _showInterestDetails,
                        builder: (context) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                [
                                      Text(
                                        'Tracking from ${DateFormat.yMMMd().format(start)}.',
                                        style: TextStyle(
                                          fontSize: KoinTypography.caption,
                                          color: AppTheme.textLightColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                      if (earned > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            'Interest recorded: ${currency.formatter.format(earned)}',
                                            style: TextStyle(
                                              fontSize: KoinTypography.caption,
                                              color: AppTheme.textLightColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Uses your closing balance and a 365-day year. Tax is deducted from interest; leave it blank for none. '
                                          'Interest is added ${_interestFrequency == InterestPayoutFrequency.daily
                                              ? 'after each day'
                                              : _interestFrequency == InterestPayoutFrequency.monthly
                                              ? 'at month-end'
                                              : 'at year-end'}. '
                                          'Koin catches up when open. Unpaid interest carries forward if you change the payout schedule. '
                                          'This estimate assumes the current balance for a full period. '
                                          'Rate changes start today. Edit entries to match your bank.',
                                          style: TextStyle(
                                            fontSize: KoinTypography.caption,
                                            height: 1.4,
                                            color: AppTheme.textLightColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]
                                    .koinAnimate(
                                      context,
                                      autoPlay: !MediaQuery.disableAnimationsOf(
                                        context,
                                      ),
                                      onInit: KoinMotion.onInit(context),
                                      interval: KoinMotion.duration(
                                        context,
                                        40.ms,
                                      ),
                                    )
                                    .fade(
                                      duration: KoinMotion.entrance,
                                      curve: KoinMotion.curve,
                                    )
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      duration: KoinMotion.entrance,
                                      curve: KoinMotion.curve,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (processing.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Could not update interest. Koin will retry automatically.',
                        style: TextStyle(
                          fontSize: KoinTypography.caption,
                          color: AppTheme.errorColor(context),
                        ),
                      ),
                    ),
                ]
                .koinAnimate(
                  context,
                  autoPlay: !MediaQuery.disableAnimationsOf(context),
                  onInit: KoinMotion.onInit(context),
                  interval: KoinMotion.duration(context, 40.ms),
                )
                .fade(duration: KoinMotion.entrance, curve: KoinMotion.curve)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  duration: KoinMotion.entrance,
                  curve: KoinMotion.curve,
                ),
      ),
    );
  }

  /// Match the app reveal guide: smooth top-anchored size change around the
  /// staggered fade/scale children. Reduced motion renders the final state.
  Widget _buildInterestReveal(
    BuildContext context, {
    required bool visible,
    required WidgetBuilder builder,
    Key? key,
  }) {
    final child = visible ? builder(context) : const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      key: key,
      duration: KoinMotion.entrance,
      curve: KoinMotion.curve,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _buildContent(BuildContext context) {
    final isEditing = widget.account != null;
    final colors = AppTheme.accentColors;
    final cardBgColors = AppTheme.cardColors;
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Account' : 'Add Account'),
        leading: const Center(child: KoinBackButton()),
        leadingWidth: 70,
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _deleteAccount,
              icon: Icon(
                KoinIcons.trash,
                color: AppTheme.errorContentColor(context),
              ),
            ),
          const Gap(8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: KoinSpacing.screenInset,
          vertical: 20,
        ),
        child: Column(
          children: [
            // Account preview
            LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(13) > 19.5;
                final columns = constraints.maxWidth < 280 || largeText ? 1 : 2;
                final cardWidth =
                    (constraints.maxWidth -
                        KoinSpacing.cardGap * (columns - 1)) /
                    columns;
                return Center(
                  child: SizedBox(
                    width: cardWidth,
                    child: _buildAccountPreview(context, currency),
                  ),
                );
              },
            ),
            const Gap(24),
            _buildAccountFields(context, currency),
            const Gap(32),

            // ── Templates Section ──
            Row(
              children: [
                Icon(
                  KoinIcons.cards,
                  size: 16,
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.7),
                ),
                const Gap(6),
                Text(
                  'Templates',
                  style: TextStyle(
                    color: AppTheme.textLightColor(context)
                        .withValues(alpha: 0.7),
                    fontSize: KoinTypography.caption,
                    fontWeight: KoinTypography.labelWeight,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Gap(12),
            SizedBox(
              height:
                  60 +
                  MediaQuery.textScalerOf(context)
                          .scale(KoinTypography.overline) *
                      1.5,
              child: ListView.builder(
                controller: _templateScrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: BankTemplate.templates.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = selectedTemplateId == null;
                    return GestureDetector(
                      onTap: () => _applyTemplate(null),
                      child: Container(
                        width: 76,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: KoinMotion.duration(
                                context,
                                const Duration(milliseconds: 200),
                              ),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.1)
                                    : AppTheme.fieldBorderColor(
                                        context,
                                        lightOpacity: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                KoinIcons.slidersHorizontal,
                                color: isSelected
                                    ? selectedColor
                                    : AppTheme.fieldHintColor(
                                        context,
                                        lightOpacity: 0.5,
                                      ),
                                size: 22,
                              ),
                            ),
                            const Gap(6),
                            Text(
                              'Custom',
                              style: TextStyle(
                                fontSize: KoinTypography.overline,
                                fontWeight: isSelected
                                    ? KoinTypography.titleWeight
                                    : KoinTypography.supportingWeight,
                                color: isSelected
                                    ? AppTheme.textColor(context)
                                    : AppTheme.textLightColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final template = BankTemplate.templates[index - 1];
                  final isSelected = selectedTemplateId == template.id;
                  final templateColor = Color(
                    int.parse(template.colorHex.replaceFirst('#', '0xFF')),
                  );

                  return GestureDetector(
                    onTap: () => _applyTemplate(template),
                    child: Container(
                      width: 76,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: KoinMotion.duration(
                              context,
                              const Duration(milliseconds: 200),
                            ),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isSelected
                                    ? templateColor
                                    : AppTheme.fieldBorderColor(
                                        context,
                                        lightOpacity: 0.3,
                                      ),
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      AppTheme.boxShadow(
                                        context,
                                        color: templateColor.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                isSelected ? 10.5 : 12.0,
                              ),
                              child: Image.asset(
                                template.logoAsset,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const Gap(6),
                          Text(
                            template.name,
                            style: TextStyle(
                              fontSize: KoinTypography.overline,
                              fontWeight: isSelected
                                  ? KoinTypography.titleWeight
                                  : KoinTypography.supportingWeight,
                              color: isSelected
                                  ? AppTheme.textColor(context)
                                  : AppTheme.textLightColor(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(24),

            AnimatedSize(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 250),
              ),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: selectedTemplateId == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          [
                                Row(
                                  children: [
                                    Icon(
                                      KoinIcons.image,
                                      size: 16,
                                      color: AppTheme.primaryColor(context)
                                          .withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Icon',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context)
                                            .withValues(alpha: 0.7),
                                        fontSize: KoinTypography.caption,
                                        fontWeight: KoinTypography.labelWeight,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(12),
                                IconPaletteGrid(
                                  icons: icons,
                                  selectedCodePoint: selectedIcon,
                                  activeColor: selectedColor,
                                  isScrollableRow: true,
                                  shape: BoxShape.circle,
                                  scrollController: _iconScrollController,
                                  onCodePointSelected: (code) =>
                                      setState(() => selectedIcon = code),
                                ),
                                const Gap(24),

                                Row(
                                  children: [
                                    Icon(
                                      KoinIcons.palette,
                                      size: 16,
                                      color: AppTheme.primaryColor(context)
                                          .withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Color',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context)
                                            .withValues(alpha: 0.7),
                                        fontSize: KoinTypography.caption,
                                        fontWeight: KoinTypography.labelWeight,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(12),
                                ColorPaletteGrid(
                                  colors: colors,
                                  selectedColor: selectedColor,
                                  isScrollableRow: true,
                                  shape: BoxShape.circle,
                                  scrollController: _colorScrollController,
                                  onColorSelected: (c) =>
                                      setState(() => selectedColor = c),
                                ),
                                const Gap(24),

                                Row(
                                  children: [
                                    Icon(
                                      KoinIcons.imageSquare,
                                      size: 16,
                                      color: AppTheme.primaryColor(context)
                                          .withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Card Background',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context)
                                            .withValues(alpha: 0.7),
                                        fontSize: KoinTypography.caption,
                                        fontWeight: KoinTypography.labelWeight,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(12),
                                SizedBox(
                                  height: 50,
                                  child: ListView(
                                    controller: _cardColorScrollController,
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          HapticService.light();
                                          setState(
                                            () => selectedCardColor = null,
                                          );
                                        },
                                        child: Center(
                                          child: AnimatedContainer(
                                            duration: KoinMotion.duration(
                                              context,
                                              const Duration(milliseconds: 200),
                                            ),
                                            margin: const EdgeInsets.only(
                                              right: 12,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: selectedCardColor == null
                                                  ? AppTheme.primaryColor(
                                                      context,
                                                    ).withValues(alpha: 0.1)
                                                  : AppTheme.fieldBorderColor(
                                                      context,
                                                      lightOpacity: 0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: selectedCardColor == null
                                                    ? AppTheme.primaryColor(
                                                        context,
                                                      )
                                                    : AppTheme.fieldBorderColor(
                                                        context,
                                                        lightOpacity: 0.3,
                                                      ),
                                                width: selectedCardColor == null
                                                    ? 2
                                                    : 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .format_color_reset_rounded,
                                                  size: 16,
                                                  color:
                                                      selectedCardColor == null
                                                      ? AppTheme.primaryColor(
                                                          context,
                                                        )
                                                      : AppTheme.textLightColor(
                                                          context,
                                                        ).withValues(
                                                          alpha: 0.5,
                                                        ),
                                                ),
                                                const Gap(6),
                                                Text(
                                                  'Default',
                                                  style: TextStyle(
                                                    fontSize:
                                                        KoinTypography.caption,
                                                    fontWeight:
                                                        selectedCardColor ==
                                                            null
                                                        ? KoinTypography
                                                              .titleWeight
                                                        : KoinTypography
                                                              .supportingWeight,
                                                    color:
                                                        selectedCardColor ==
                                                            null
                                                        ? AppTheme.primaryColor(
                                                            context,
                                                          )
                                                        : AppTheme.textLightColor(
                                                            context,
                                                          ).withValues(
                                                            alpha: 0.5,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      ...cardBgColors.map((c) {
                                        final isSelected =
                                            selectedCardColor != null &&
                                            selectedCardColor!.toARGB32() ==
                                                c.toARGB32();
                                        return GestureDetector(
                                          onTap: () {
                                            HapticService.light();
                                            setState(
                                              () => selectedCardColor = c,
                                            );
                                          },
                                          child: Center(
                                            child: AnimatedContainer(
                                              duration: KoinMotion.duration(
                                                context,
                                                const Duration(
                                                  milliseconds: 200,
                                                ),
                                              ),
                                              margin: const EdgeInsets.only(
                                                right: 12,
                                              ),
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: c,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.transparent,
                                                  width: 3,
                                                ),
                                                boxShadow: isSelected
                                                    ? [
                                                        AppTheme.boxShadow(
                                                          context,
                                                          color: c.withValues(
                                                            alpha: 0.4,
                                                          ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ]
                                                    : null,
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      KoinIcons.check,
                                                      color: Colors.white,
                                                      size: 22,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const Gap(24),
                              ]
                              .koinAnimate(
                                context,
                                autoPlay: !MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                                onInit: KoinMotion.onInit(context),
                                interval: KoinMotion.duration(context, 40.ms),
                              )
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
            AnimatedSize(
              duration: KoinMotion.duration(
                context,
                const Duration(milliseconds: 250),
              ),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _previewHasColoredBackground
                  ? Column(
                      children:
                          [
                                Row(
                                  children: [
                                    Icon(
                                      KoinIcons.stack,
                                      size: 16,
                                      color: AppTheme.primaryColor(context)
                                          .withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Card Decoration',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(context)
                                            .withValues(alpha: 0.7),
                                        fontSize: KoinTypography.caption,
                                        fontWeight: KoinTypography.labelWeight,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const Gap(12),
                                SizedBox(
                                  height: 90,
                                  child: ListView.builder(
                                    controller: _cardShapeScrollController,
                                    scrollDirection: Axis.horizontal,
                                    clipBehavior: Clip.none,
                                    itemCount:
                                        9, // Default (None/Hash) + 8 shapes
                                    itemBuilder: (context, index) {
                                      final isSelected = index == 0
                                          ? selectedCardShape == null
                                          : selectedCardShape == (index - 1);
                                      final shapeIndex = index == 0
                                          ? null
                                          : index - 1;

                                      return GestureDetector(
                                        onTap: () {
                                          HapticService.light();
                                          setState(
                                            () =>
                                                selectedCardShape = shapeIndex,
                                          );
                                        },
                                        child: Container(
                                          width: 140,
                                          height: 80,
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.surfaceColor(
                                              context,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.primaryColor(
                                                      context,
                                                    )
                                                  : AppTheme.fieldBorderColor(
                                                      context,
                                                      lightOpacity: 0.15,
                                                    ),
                                              width: 2.5,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    AppTheme.boxShadow(
                                                      context,
                                                      color:
                                                          AppTheme.primaryColor(
                                                            context,
                                                          ).withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Stack(
                                            children: [
                                              if (index == 0)
                                                Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .auto_awesome_rounded,
                                                        size: 20,
                                                        color: isSelected
                                                            ? AppTheme.primaryColor(
                                                                context,
                                                              )
                                                            : AppTheme.fieldHintColor(
                                                                context,
                                                                lightOpacity:
                                                                    0.5,
                                                              ),
                                                      ),
                                                      const Gap(4),
                                                      Text(
                                                        'Auto',
                                                        style: TextStyle(
                                                          fontSize:
                                                              KoinTypography
                                                                  .small,
                                                          fontWeight:
                                                              KoinTypography
                                                                  .titleWeight,
                                                          color: isSelected
                                                              ? AppTheme.textColor(
                                                                  context,
                                                                )
                                                              : AppTheme.textLightColor(
                                                                  context,
                                                                ).withValues(
                                                                  alpha: 0.7,
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Positioned.fill(
                                                  child: Center(
                                                    child: IgnorePointer(
                                                      child: Transform.scale(
                                                        scale: 0.6,
                                                        child: SizedBox(
                                                          width: 200,
                                                          height: 120,
                                                          child: AccountItem(
                                                            account: Account(
                                                              id: 'shape_preview_$index',
                                                              name: 'Preview',
                                                              iconCodePoint:
                                                                  selectedIcon,
                                                              colorHex:
                                                                  '#${(selectedCardColor ?? selectedColor).toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                                                              cardColorHex:
                                                                  '#${(selectedCardColor ?? selectedColor).toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                                                              cardShapeType:
                                                                  index - 1,
                                                            ),
                                                            balance: 0,
                                                            currencySymbol: '',
                                                            onTap: () {},
                                                            isPreview: true,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (isSelected)
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppTheme.primaryColor(
                                                            context,
                                                          ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      KoinIcons.check,
                                                      color: Colors.white,
                                                      size: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const Gap(24),
                              ]
                              .koinAnimate(
                                context,
                                autoPlay: !MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                                onInit: KoinMotion.onInit(context),
                                interval: KoinMotion.duration(context, 40.ms),
                              )
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

            _sectionLabel(context, 'Account settings'),
            const Gap(12),
            Material(
              color: AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(KoinShape.field),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _settingRow(
                    context,
                    title: 'Private account',
                    hint: 'Hide balance and exclude from totals.',
                    value: excludeFromTotal,
                    onChanged: (value) {
                      HapticService.light();
                      setState(() => excludeFromTotal = value);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: AppTheme.fieldBorderColor(context),
                    ),
                  ),
                  _settingRow(
                    context,
                    title: 'Credit account',
                    value: isCredit,
                    onChanged: _setCredit,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: AppTheme.fieldBorderColor(context),
                    ),
                  ),
                  _settingRow(
                    context,
                    title: 'Interest',
                    hint: isCredit ? 'Available for deposit accounts.' : null,
                    value: _dailyInterestEnabled && !isCredit,
                    onChanged: isCredit
                        ? null
                        : (value) {
                            HapticService.light();
                            setState(() => _dailyInterestEnabled = value);
                          },
                  ),
                ],
              ),
            ),
            _buildInterestReveal(
              context,
              key: const ValueKey('account_interest_reveal'),
              visible: _dailyInterestEnabled && !isCredit,
              builder: (context) => _buildInterestFields(context, currency),
            ),
            const Gap(32),
            _sectionLabel(context, 'Transfer fee'),
            const Gap(16),
            KoinChoiceControl(
              segments: const [
                KoinSegmentItem(label: 'Fixed amount'),
                KoinSegmentItem(label: 'Percentage'),
              ],
              selectedIndex: isTransferFeePercentage ? 1 : 0,
              onChanged: (index) =>
                  setState(() => isTransferFeePercentage = index == 1),
            ),
            const Gap(20),
            _fieldLabel(
              context,
              isTransferFeePercentage ? 'Fee rate' : 'Fee amount',
            ),
            TextField(
              key: const ValueKey('account_transfer_fee_field'),
              controller: transferFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: KoinTypography.cardAmount,
                fontWeight: KoinTypography.titleWeight,
                color: AppTheme.textColor(context),
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: isTransferFeePercentage
                    ? null
                    : '${currency.symbol} ',
                suffixText: isTransferFeePercentage ? '%' : null,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: const UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.fieldBorderColor(context),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor(context),
                    width: 2,
                  ),
                ),
              ),
            ),
            const Gap(8),
            _fieldLabel(context, 'Set to 0 for no fee.'),
            const Gap(40),

            KoinPrimaryButton(
              isLoading: _saving,
              label: isEditing ? 'Save Changes' : 'Create Account',
              onPressed: _saveAccount,
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
