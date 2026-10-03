import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/core.dart';

class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  /// Displays [VoiceInputSheet] in a modal bottom sheet and returns parsed transaction data if accepted.
  static Future<ParsedTransactionData?> show(BuildContext context) {
    HapticService.selection();
    return showModalBottomSheet<ParsedTransactionData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceInputSheet(),
    );
  }

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _ringController;

  ParsedTransactionData? _parsedData;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  int _autoCatKey = 0;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(voiceInputProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _parseCurrentWords() async {
    final state = ref.read(voiceInputProvider);
    final categories = ref.read(categoriesProvider).value ?? [];
    final transactions = ref.read(transactionProvider).value ?? [];
    final accounts = ref.read(accountProvider).value ?? [];

    if (state.lastWords.isNotEmpty) {
      var parsed = VoiceCommandParser.parse(
        state.lastWords,
        categories,
        transactions,
        accounts,
      );
      _amountController.text =
          parsed.amount?.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '') ??
          '';
      _noteController.text = parsed.note;

      // Enhance with CategorySuggester Seam
      final suggester = ref.read(categorySuggesterProvider);
      final amount = parsed.amount ?? 0.0;
      final effectiveAmount = amount == 0.0 ? 1.0 : amount;

      try {
        final suggestion = await suggester.suggest(
          SuggestionContext(
            text: parsed.note,
            amount: effectiveAmount,
            type: parsed.type,
            date: DateTime.now(),
            currentAccountId: parsed.account?.id ?? '',
          ),
        );

        if (suggestion != null) {
          TransactionCategory? cat = parsed.category;
          Account? acc = parsed.account;
          Account? toAcc = parsed.toAccount;

          if (suggestion.isTransfer) {
            try {
              acc = accounts.firstWhere(
                (a) => a.id == suggestion.originAccountId,
              );
            } catch (_) {}
            try {
              toAcc = accounts.firstWhere(
                (a) => a.id == suggestion.destinationAccountId,
              );
            } catch (_) {}
            cat = null;
          } else {
            try {
              acc = accounts.firstWhere(
                (a) => a.id == suggestion.originAccountId,
              );
            } catch (_) {}
            try {
              final newCat = categories.firstWhere(
                (c) => c.id == suggestion.categoryId,
              );
              if (newCat != cat) {
                cat = newCat;
                _autoCatKey++;
              }
            } catch (_) {}
            toAcc = null;
          }

          parsed = parsed.copyWith(
            type: suggestion.type,
            category: cat,
            account: acc,
            toAccount: toAcc,
          );
        }
      } catch (e) {
        // Suggester enhancement failed, silently fallback to static parsing
      }

      if (mounted) {
        setState(() {
          _parsedData = parsed;
        });
      }
    }
  }

  void _onConfirm() {
    HapticService.medium();
    if (_parsedData != null && mounted) {
      Navigator.pop(context, _parsedData);
    }
  }

  void _onStopListening() async {
    HapticService.medium();
    await ref.read(voiceInputProvider.notifier).stopListening();
    _parseCurrentWords();
  }

  void _onCancel() {
    HapticService.light();
    ref.read(voiceInputProvider.notifier).stopListening();
    Navigator.pop(context, null);
  }

  // ═══════════════════════════════════════════════════════
  // Selection Helpers
  // ═══════════════════════════════════════════════════════
  Future<void> _editCategory() async {
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final categories = ref.read(categoriesProvider).value ?? [];

    final id = await showCategoryPickerSheet(
      context: context,
      ref: ref,
      selectedCategoryId: _parsedData!.category?.id,
      type: _parsedData!.type,
      categoriesOverride: categories,
      indicatorColor: _getTypeColor(context, _parsedData!.type),
    );
    if (id != null && mounted) {
      final category = categories.firstWhere((c) => c.id == id);
      setState(() {
        _parsedData = _parsedData!.copyWith(category: category);
      });
    }
  }

  Future<void> _editAccount() async {
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final accounts = ref.read(accountProvider).value ?? [];

    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _parsedData!.account?.id,
      title: 'Account',
      subtitle: 'Choose an account for this transaction',
      accountsOverride: accounts,
    );
    if (id != null && mounted) {
      final account = accounts.firstWhere((a) => a.id == id);
      setState(() {
        _parsedData = _parsedData!.copyWith(account: account);
      });
    }
  }

  Future<void> _editToAccount() async {
    final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (hadFocus) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final accounts = ref.read(accountProvider).value ?? [];

    final id = await showAccountPickerSheet(
      context: context,
      ref: ref,
      selectedAccountId: _parsedData!.toAccount?.id,
      title: 'Destination Account',
      subtitle: 'Choose where the money arrives',
      accountsOverride: accounts,
      excludeAccountId: _parsedData!.account?.id,
    );
    if (id != null && mounted) {
      final account = accounts.firstWhere((a) => a.id == id);
      setState(() {
        _parsedData = _parsedData!.copyWith(toAccount: account);
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // Styling Helpers
  // ═══════════════════════════════════════════════════════

  Color _getTypeColor(BuildContext context, TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return AppTheme.expenseColor(context);
      case TransactionType.income:
        return AppTheme.incomeColor(context);
      case TransactionType.transfer:
        return AppTheme.transferColor(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(voiceInputProvider.select((state) => state.isListening), (
      previous,
      isListening,
    ) {
      if (isListening) {
        _pulseController.repeat(reverse: true);
        _ringController.repeat();
      } else {
        _pulseController.stop();
        _ringController.stop();
      }
    });
    final state = ref.watch(voiceInputProvider);
    final primaryColor = AppTheme.primaryColor(context);
    final hasWords = state.lastWords.isNotEmpty;
    final showPreview = _parsedData != null && !state.isListening;

    // Parse on-the-fly when listening stops and we haven't parsed yet
    if (!state.isListening && hasWords && _parsedData == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _parseCurrentWords();
      });
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        KoinSpacing.screenInset,
        16,
        KoinSpacing.screenInset,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(KoinSpacing.sectionGap),

          // ── Animated mic orb ──
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final isListening = state.isListening;
              return PressableScale(
                onTap: isListening
                    ? _onStopListening
                    : (showPreview ? _onCancel : _onCancel),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse ring
                      if (isListening)
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (context, child) {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primaryColor.withValues(
                                    alpha: 0.12 * (1 - _ringController.value),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      // Middle glow ring
                      if (isListening)
                        Container(
                          width: 96 + 8 * _pulseAnimation.value,
                          height: 96 + 8 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withValues(
                              alpha: 0.06 + 0.04 * _pulseAnimation.value,
                            ),
                          ),
                        ),
                      // Core button
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isListening
                                ? [
                                    primaryColor,
                                    primaryColor.withValues(alpha: 0.85),
                                  ]
                                : showPreview
                                ? [
                                    AppTheme.incomeColor(context),
                                    AppTheme.incomeColor(
                                      context,
                                    ).withValues(alpha: 0.85),
                                  ]
                                : [
                                    AppTheme.surfaceColor(context),
                                    AppTheme.surfaceLightColor(context),
                                  ],
                          ),
                          boxShadow: isListening
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(
                                      alpha: 0.2 + 0.15 * _pulseAnimation.value,
                                    ),
                                    blurRadius: 20 + 10 * _pulseAnimation.value,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : showPreview
                              ? [
                                  BoxShadow(
                                    color: AppTheme.incomeColor(
                                      context,
                                    ).withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                          border: (isListening || showPreview)
                              ? null
                              : Border.all(
                                  color: AppTheme.dividerColor(
                                    context,
                                  ).withValues(alpha: 0.5),
                                ),
                        ),
                        child: Icon(
                          isListening
                              ? Icons.stop_rounded
                              : showPreview
                              ? (_parsedData!.category != null
                                    ? IconUtils.getIcon(
                                        _parsedData!.category!.iconCodePoint,
                                      )
                                    : Icons.check_rounded)
                              : Icons.close_rounded,
                          size: 32,
                          color: (isListening || showPreview)
                              ? Colors.white
                              : AppTheme.textLightColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Gap(20),

          // ── Status label ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              state.isListening
                  ? 'Listening…'
                  : state.error.isNotEmpty
                  ? 'Something went wrong'
                  : showPreview
                  ? 'Here\'s what I got'
                  : 'Processing…',
              key: ValueKey(
                state.isListening
                    ? 'listening'
                    : state.error.isNotEmpty
                    ? 'error'
                    : showPreview
                    ? 'preview'
                    : 'processing',
              ),
              style: TextStyle(
                fontSize: KoinTypography.sectionTitle,
                fontWeight: KoinTypography.headingWeight,
                color: state.error.isNotEmpty
                    ? AppTheme.errorColor(context)
                    : AppTheme.textColor(context),
                letterSpacing: KoinTypography.headingTracking,
              ),
            ),
          ),
          const Gap(6),

          // ── Hint / error subtitle ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              state.error.isNotEmpty
                  ? state.error
                  : state.isListening
                  ? 'Tap the button when done'
                  : showPreview
                  ? 'Review the details below'
                  : 'Almost there…',
              key: ValueKey(
                'sub_${state.error}_${state.isListening}_$showPreview',
              ),
              style: TextStyle(
                fontSize: KoinTypography.caption,
                fontWeight: KoinTypography.supportingWeight,
                color: state.error.isNotEmpty
                    ? AppTheme.errorColor(context).withValues(alpha: 0.7)
                    : AppTheme.textLightColor(context),
              ),
            ),
          ),
          const Gap(24),

          // ── Transcription card (visible while listening or if no preview) ──
          if (state.isListening || !showPreview)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: KoinSpacing.screenInset,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasWords
                      ? primaryColor.withValues(alpha: 0.25)
                      : AppTheme.dividerColor(context).withValues(alpha: 0.6),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  hasWords ? state.lastWords : 'Try: "Spent 50 on lunch"',
                  key: ValueKey(hasWords ? state.lastWords : 'placeholder'),
                  style: TextStyle(
                    fontSize: KoinTypography.body,
                    fontWeight: hasWords
                        ? KoinTypography.labelWeight
                        : FontWeight.w400,
                    fontStyle: hasWords ? FontStyle.normal : FontStyle.italic,
                    color: hasWords
                        ? AppTheme.textColor(context)
                        : AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // ── Preview Details card ──
          if (showPreview) ...[
            Flexible(
              child: SingleChildScrollView(child: _buildPreviewCard(context)),
            ),
            const Gap(16),
            // Actions
            Row(
              children: [
                // Retry
                Expanded(
                  child: PressableScale(
                    onTap: () {
                      HapticService.light();
                      setState(() => _parsedData = null);
                      ref.read(voiceInputProvider.notifier).startListening();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: AppTheme.textLightColor(context),
                          ),
                          const Gap(6),
                          Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: KoinTypography.compact,
                              fontWeight: KoinTypography.labelWeight,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(12),
                // Confirm
                Expanded(
                  flex: 2,
                  child: PressableScale(
                    onTap: _onConfirm,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient(context),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          Gap(6),
                          Text(
                            'Use This',
                            style: TextStyle(
                              fontSize: KoinTypography.compact,
                              fontWeight: KoinTypography.titleWeight,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0),
          ],
          const Gap(8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Parsed Data Preview Card
  // ═══════════════════════════════════════════════════════
  Widget _buildPreviewCard(BuildContext context) {
    final data = _parsedData!;
    final settings = ref.watch(settingsProvider);
    final currency = settings.currency;
    final typeColor = _getTypeColor(context, data.type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Amount row
          _buildPreviewRow(
            context,
            icon: Icons.payments_rounded,
            label: 'Amount',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  currency.symbol,
                  style: TextStyle(
                    fontSize: KoinTypography.compact,
                    fontWeight: KoinTypography.labelWeight,
                    color: typeColor.withValues(alpha: 0.6),
                  ),
                ),
                const Gap(4),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: KoinTypography.sectionTitle,
                      fontWeight: KoinTypography.headingWeight,
                      color: typeColor,
                      letterSpacing: KoinTypography.headingTracking,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: KoinTypography.sectionTitle,
                        letterSpacing: KoinTypography.headingTracking,
                        fontWeight: KoinTypography.headingWeight,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        setState(() {
                          _parsedData = _parsedData!.copyWith(amount: parsed);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          _buildPreviewDivider(context),

          // Type Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TransactionTypeSelector(
              selectedType: data.type,
              activeColor: typeColor,
              onChanged: (val) {
                if (val != data.type) {
                  setState(() {
                    _parsedData = _parsedData!.copyWith(
                      type: val,
                      category: null,
                    );
                  });
                }
              },
            ),
          ),
          const Gap(8),
          _buildPreviewDivider(context),

          // Category row (only if not transfer)
          if (data.type != TransactionType.transfer) ...[
            Builder(
              builder: (context) {
                Widget child = _buildPreviewRow(
                  context,
                  onTap: _editCategory,
                  icon: data.category != null
                      ? IconUtils.getIcon(data.category!.iconCodePoint)
                      : Icons.category_rounded,
                  iconColor: data.category?.color,
                  label: 'Category',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (data.category != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: data.category!.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          data.category!.name,
                          style: TextStyle(
                            fontSize: KoinTypography.compact,
                            fontWeight: KoinTypography.labelWeight,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ] else
                        Text(
                          'Not detected',
                          style: TextStyle(
                            fontSize: KoinTypography.compact,
                            fontWeight: KoinTypography.supportingWeight,
                            color: AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const Gap(8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                );

                if (_autoCatKey > 0) {
                  child = child
                      .animate(key: ValueKey(_autoCatKey))
                      .shimmer(
                        duration: 400.ms,
                        color: AppTheme.primaryColor(
                          context,
                        ).withValues(alpha: 0.2),
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
            _buildPreviewDivider(context),
          ],

          // Account row (From Account if transfer)
          _buildPreviewRow(
            context,
            onTap: _editAccount,
            icon: Icons.account_balance_wallet_rounded,
            iconColor: data.account?.color,
            label: data.type == TransactionType.transfer ? 'From' : 'Account',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.account != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: data.account!.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    data.account!.name,
                    style: TextStyle(
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.labelWeight,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ] else
                  Text(
                    'Select Account',
                    style: TextStyle(
                      fontSize: KoinTypography.compact,
                      fontWeight: KoinTypography.supportingWeight,
                      color: AppTheme.textLightColor(
                        context,
                      ).withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const Gap(8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          // To Account row (Transfer only)
          if (data.type == TransactionType.transfer) ...[
            _buildPreviewDivider(context),
            _buildPreviewRow(
              context,
              onTap: _editToAccount,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: data.toAccount?.color,
              label: 'To',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.toAccount != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: data.toAccount!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      data.toAccount!.name,
                      style: TextStyle(
                        fontSize: KoinTypography.compact,
                        fontWeight: KoinTypography.labelWeight,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ] else
                    Text(
                      'Select Target',
                      style: TextStyle(
                        fontSize: KoinTypography.compact,
                        fontWeight: KoinTypography.supportingWeight,
                        color: AppTheme.textLightColor(
                          context,
                        ).withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const Gap(8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ],
          _buildPreviewDivider(context),

          // Note row
          _buildPreviewRow(
            context,
            icon: Icons.sticky_note_2_rounded,
            label: 'Note',
            trailing: Flexible(
              child: TextField(
                controller: _noteController,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: KoinTypography.compact,
                  fontWeight: KoinTypography.labelWeight,
                  color: AppTheme.textColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Add note...',
                  hintStyle: TextStyle(
                    fontSize: KoinTypography.compact,
                    fontWeight: KoinTypography.supportingWeight,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  setState(() {
                    _parsedData = _parsedData!.copyWith(note: val);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPreviewRow(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppTheme.textLightColor(context))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? AppTheme.textLightColor(context),
                ),
              ),
              const Gap(12),
              Text(
                label,
                style: TextStyle(
                  fontSize: KoinTypography.compact,
                  fontWeight: KoinTypography.supportingWeight,
                  color: AppTheme.textLightColor(context),
                ),
              ),
              const Spacer(),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.dividerColor(context).withValues(alpha: 0.4),
    );
  }
}
