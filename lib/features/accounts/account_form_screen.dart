import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/core.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccountFormScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  late final TextEditingController nameController;
  late final TextEditingController balanceController;
  late final TextEditingController transferFeeController;
  late int selectedIcon;
  late Color selectedColor;
  late bool excludeFromTotal;
  late bool isTransferFeePercentage;
  String? selectedLogoAsset;
  String? selectedTemplateId;
  bool _colorInitialized = false;
  Color? selectedCardColor; // null = Default (no explicit card background)
  final ScrollController _iconScrollController = ScrollController();
  final ScrollController _colorScrollController = ScrollController();
  final ScrollController _cardColorScrollController = ScrollController();
  final ScrollController _cardShapeScrollController = ScrollController();
  final ScrollController _templateScrollController = ScrollController();
  int? selectedCardShape;

  final List<IconData> icons = [
    Icons.account_balance_wallet_rounded,
    Icons.account_balance_rounded,
    Icons.savings_rounded,
    Icons.payments_rounded,
    Icons.credit_card_rounded,
    Icons.wallet_rounded,
    Icons.money_rounded,
    Icons.currency_exchange_rounded,
    Icons.trending_up_rounded,
    Icons.monetization_on_rounded,
    Icons.paid_rounded,
    Icons.local_atm_rounded,
    Icons.request_quote_rounded,
    Icons.account_tree_rounded,
    Icons.business_center_rounded,
    Icons.storefront_rounded,
    Icons.currency_bitcoin_rounded,
    Icons.currency_pound_rounded,
    Icons.currency_yen_rounded,
    Icons.currency_franc_rounded,
  ];

  @override
  void initState() {
    super.initState();
    final isEditing = widget.account != null;
    nameController = TextEditingController(text: widget.account?.name)
      ..addListener(_onInputChanged);

    String amountText = '';
    if (isEditing) {
      final dashboardStats = ref.read(dashboardStatsProvider);
      double currentBalance =
          dashboardStats.accountBalances[widget.account!.id] ??
          widget.account!.initialBalance;
      amountText = currentBalance == currentBalance.truncateToDouble()
          ? currentBalance.toInt().toString()
          : currentBalance.toString();
    }

    balanceController = TextEditingController(text: amountText)
      ..addListener(_onInputChanged);

    transferFeeController = TextEditingController(
      text:
          widget.account?.transferFeeAmount != null &&
              widget.account!.transferFeeAmount > 0
          ? widget.account!.transferFeeAmount.toString()
          : '',
    )..addListener(_onInputChanged);
    selectedIcon =
        widget.account?.iconCodePoint ??
        Icons.account_balance_wallet_rounded.codePoint;
    excludeFromTotal = widget.account?.excludeFromTotal ?? false;
    isTransferFeePercentage = widget.account?.isTransferFeePercentage ?? false;
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
      _scrollToSelectedIcon();
      _scrollToSelectedColor();
      _scrollToSelectedCardColor();
      _scrollToSelectedTemplate();
    });
  }

  void _onInputChanged() {
    setState(() {});
  }

  void _scrollToSelectedIcon() {
    final index = icons.indexWhere((icon) => icon.codePoint == selectedIcon);
    if (index != -1 && _iconScrollController.hasClients) {
      final offset = index * 60.0;
      final targetOffset = (offset - MediaQuery.of(context).size.width / 2 + 30)
          .clamp(0.0, _iconScrollController.position.maxScrollExtent);
      _iconScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
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
      _colorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
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
      _templateScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
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
      _cardColorScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _applyTemplate(BankTemplate? template) {
    HapticService.light();
    setState(() {
      if (template == null) {
        selectedTemplateId = null;
        selectedLogoAsset = null;
        selectedIcon = icons.first.codePoint;
        selectedColor = AppTheme.accentColors.first;
      } else {
        selectedTemplateId = template.id;
        selectedLogoAsset = template.logoAsset;
        nameController.text = template.name;
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
    _iconScrollController.dispose();
    _colorScrollController.dispose();
    _cardColorScrollController.dispose();
    _cardShapeScrollController.dispose();
    _templateScrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    HapticService.medium();
    final confirmed = await ConfirmationSheet.show(
      context: context,
      title: 'Delete Account?',
      description:
          'All transactions associated with this account will be unlinked. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.errorColor(context),
      icon: Icons.delete_forever_rounded,
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      ref.read(accountProvider.notifier).deleteAccount(widget.account!.id);
      Navigator.pop(context);
    }
  }

  Future<void> _saveAccount() async {
    if (nameController.text.isNotEmpty) {
      HapticService.success();
      final isEditing = widget.account != null;
      final cardHex = selectedCardColor == null
          ? null
          : '#${selectedCardColor!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

      double newInitialBalance = double.tryParse(balanceController.text) ?? 0.0;
      if (isEditing) {
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
        id: isEditing ? widget.account!.id : const Uuid().v4(),
        name: nameController.text,
        initialBalance: newInitialBalance,
        iconCodePoint: selectedIcon,
        colorHex:
            '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        excludeFromTotal: excludeFromTotal,
        transferFeeAmount: double.tryParse(transferFeeController.text) ?? 0.0,
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

  BoxDecoration _previewCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_previewHasColoredBackground) {
      final baseColor = selectedCardColor ?? selectedColor;
      return BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.8),
          ],
          stops: const [0.2, 1.0],
        ),
        boxShadow: [
          AppTheme.boxShadow(
            context,
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          AppTheme.boxShadow(
            context,
            color: baseColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      );
    }

    final surfaceColor = AppTheme.surfaceColor(context);
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.dividerColor(context).withValues(alpha: 0.6),
        width: 1.2,
      ),
      boxShadow: [
        AppTheme.boxShadow(
          context,
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  List<Widget> _previewBackgroundShapes() {
    if (!_previewHasColoredBackground) return const [];

    final shapeType =
        selectedCardShape ?? (widget.account?.id.hashCode.abs() ?? 0) % 4;
    // AccountItem uses multiplier 3.0 for isPreview = true
    const opacityMultiplier = 3.0;

    return [
      Positioned.fill(
        child: CardBackgroundShapes(
          shapeType: shapeType,
          opacityMultiplier: opacityMultiplier,
        ),
      ),
    ];
  }

  Widget _buildInteractivePreview(
    BuildContext context,
    List<Color> colors,
    Currency currency,
  ) {
    final colored = _previewHasColoredBackground;
    final nameEnabled = selectedTemplateId == null;

    // Adaptive colors based on card background
    final primaryTextColor = colored
        ? Colors.white
        : AppTheme.textColor(context);
    final secondaryTextColor = colored
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.textLightColor(context);
    final hintColor = colored
        ? Colors.white.withValues(alpha: 0.5)
        : AppTheme.textLightColor(context).withValues(alpha: 0.5);
    final cursorColor = colored ? Colors.white : AppTheme.primaryColor(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: _previewCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          ..._previewBackgroundShapes(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KoinSpacing.screenInset,
              vertical: 16,
            ),
            child: Row(
              children: [
                // Account Icon / Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selectedLogoAsset == null
                        ? (colored
                              ? Colors.white.withValues(alpha: 0.15)
                              : selectedColor.withValues(alpha: 0.1))
                        : null,
                    border: selectedLogoAsset == null
                        ? Border.all(
                            color: colored
                                ? Colors.white.withValues(alpha: 0.25)
                                : selectedColor.withValues(alpha: 0.15),
                            width: 1,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: selectedLogoAsset != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            selectedLogoAsset!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Icon(
                            IconUtils.getIcon(selectedIcon),
                            color: colored ? Colors.white : selectedColor,
                            size: 24,
                          ),
                        ),
                ),
                const Gap(16),

                // Name + Balance column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Inline name field
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: const InputDecorationTheme(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            isCollapsed: true,
                          ),
                        ),
                        child: TextField(
                          controller: nameController,
                          enabled: nameEnabled,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontWeight: KoinTypography.labelWeight,
                            fontSize: KoinTypography.caption,
                            letterSpacing: -0.1,
                          ),
                          cursorColor: cursorColor,
                          cursorHeight: 14,
                          decoration: InputDecoration(
                            hintText: 'Account Name',
                            hintStyle: TextStyle(
                              color: hintColor,
                              fontWeight: KoinTypography.labelWeight,
                              fontSize: KoinTypography.caption,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                      const Gap(2),
                      // Inline balance field
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currency.symbol,
                            style: TextStyle(
                              color: primaryTextColor,
                              fontWeight: KoinTypography.headingWeight,
                              fontSize: KoinTypography.sectionTitle,
                              letterSpacing: KoinTypography.headingTracking,
                            ),
                          ),
                          Flexible(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme:
                                    const InputDecorationTheme(
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      isCollapsed: true,
                                    ),
                              ),
                              child: TextField(
                                controller: balanceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: KoinTypography.headingWeight,
                                  fontSize: KoinTypography.sectionTitle,
                                  letterSpacing: KoinTypography.headingTracking,
                                ),
                                cursorColor: cursorColor,
                                cursorHeight: 18,
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(
                                    color: hintColor,
                                    fontWeight: KoinTypography.headingWeight,
                                    fontSize: KoinTypography.sectionTitle,
                                    letterSpacing:
                                        KoinTypography.headingTracking,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                  isCollapsed: true,
                                ),
                              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              icon: const Icon(Icons.delete_outline, color: Colors.red),
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
            // ── Interactive Preview Card ──
            _buildInteractivePreview(context, colors, currency),
            const Gap(32),

            // ── Templates Section ──
            Row(
              children: [
                Icon(
                  Icons.style_rounded,
                  size: 16,
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.7),
                ),
                const Gap(6),
                Text(
                  'Templates',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.7),
                    fontSize: KoinTypography.caption,
                    fontWeight: KoinTypography.labelWeight,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Gap(12),
            SizedBox(
              height: 80,
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
                              duration: const Duration(milliseconds: 200),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.1)
                                    : AppTheme.dividerColor(
                                        context,
                                      ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: isSelected
                                    ? selectedColor
                                    : AppTheme.textLightColor(
                                        context,
                                      ).withValues(alpha: 0.5),
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
                            duration: const Duration(milliseconds: 200),
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: isSelected
                                    ? templateColor
                                    : AppTheme.dividerColor(
                                        context,
                                      ).withValues(alpha: 0.3),
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
              duration: const Duration(milliseconds: 250),
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
                                      Icons.image_rounded,
                                      size: 16,
                                      color: AppTheme.primaryColor(
                                        context,
                                      ).withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Icon',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.7),
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
                                      Icons.color_lens_rounded,
                                      size: 16,
                                      color: AppTheme.primaryColor(
                                        context,
                                      ).withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Color',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.7),
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
                                      Icons.wallpaper_rounded,
                                      size: 16,
                                      color: AppTheme.primaryColor(
                                        context,
                                      ).withValues(alpha: 0.7),
                                    ),
                                    const Gap(6),
                                    Text(
                                      'Card Background',
                                      style: TextStyle(
                                        color: AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.7),
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
                                            duration: const Duration(
                                              milliseconds: 200,
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
                                                  : AppTheme.dividerColor(
                                                      context,
                                                    ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              border: Border.all(
                                                color: selectedCardColor == null
                                                    ? AppTheme.primaryColor(
                                                        context,
                                                      )
                                                    : AppTheme.dividerColor(
                                                        context,
                                                      ).withValues(alpha: 0.3),
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
                                              duration: const Duration(
                                                milliseconds: 200,
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
                                                      Icons.check_rounded,
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
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 16,
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.7),
                ),
                const Gap(6),
                Text(
                  'Card Decoration',
                  style: TextStyle(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.7),
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
                itemCount: 9, // Default (None/Hash) + 8 shapes
                itemBuilder: (context, index) {
                  final isSelected = index == 0
                      ? selectedCardShape == null
                      : selectedCardShape == (index - 1);
                  final shapeIndex = index == 0 ? null : index - 1;

                  return GestureDetector(
                    onTap: () {
                      HapticService.light();
                      setState(() => selectedCardShape = shapeIndex);
                    },
                    child: Container(
                      width: 140,
                      height: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor(context)
                              : AppTheme.dividerColor(
                                  context,
                                ).withValues(alpha: 0.15),
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                AppTheme.boxShadow(
                                  context,
                                  color: AppTheme.primaryColor(
                                    context,
                                  ).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 20,
                                    color: isSelected
                                        ? AppTheme.primaryColor(context)
                                        : AppTheme.textLightColor(
                                            context,
                                          ).withValues(alpha: 0.5),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'Auto',
                                    style: TextStyle(
                                      fontSize: KoinTypography.small,
                                      fontWeight: KoinTypography.titleWeight,
                                      color: isSelected
                                          ? AppTheme.textColor(context)
                                          : AppTheme.textLightColor(
                                              context,
                                            ).withValues(alpha: 0.7),
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
                                          iconCodePoint: selectedIcon,
                                          colorHex:
                                              '#${(selectedCardColor ?? selectedColor).toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                                          cardColorHex:
                                              '#${(selectedCardColor ?? selectedColor).toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
                                          cardShapeType: index - 1,
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
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor(context),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
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

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
                ),
              ),
              child: Material(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  title: const Text(
                    'Make Account Private',
                    style: TextStyle(
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.labelWeight,
                    ),
                  ),
                  subtitle: const Text(
                    'This will obfuscate the balance and exclude it from the total balance amount',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: excludeFromTotal,
                  onChanged: (value) {
                    HapticService.light();
                    setState(() => excludeFromTotal = value);
                  },
                  activeThumbColor: AppTheme.primaryColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const Gap(24),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.dividerColor(context).withValues(alpha: 0.1),
                ),
              ),
              child: Material(
                color: AppTheme.dividerColor(context).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  title: const Text(
                    'Use Percentage Fee',
                    style: TextStyle(
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.labelWeight,
                    ),
                  ),
                  subtitle: const Text(
                    'Calculate fee as a % of the transfer amount',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isTransferFeePercentage,
                  onChanged: (value) {
                    HapticService.light();
                    setState(() => isTransferFeePercentage = value);
                  },
                  activeThumbColor: AppTheme.primaryColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const Gap(16),
            TextFormField(
              controller: transferFeeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: KoinTypography.itemTitle,
                fontWeight: KoinTypography.labelWeight,
                color: AppTheme.textColor(context),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceColor(context),
                prefixIcon: Icon(
                  isTransferFeePercentage
                      ? Icons.percent_rounded
                      : Icons.payments_rounded,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.8),
                ),
                labelText: isTransferFeePercentage
                    ? 'Percentage Fee (e.g. 0.5)'
                    : 'Fixed Fee (e.g. 10.00)',
                labelStyle: TextStyle(
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.7),
                  fontSize: KoinTypography.compact,
                  fontWeight: KoinTypography.supportingWeight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor(context),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KoinSpacing.screenInset,
                  vertical: 20,
                ),
              ),
            ),
            const Gap(40),

            KoinPrimaryButton(
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
