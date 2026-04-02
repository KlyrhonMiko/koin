import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/providers/voice_input_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/utils/voice_command_parser.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/pressable_scale.dart';
import 'package:gap/gap.dart';

class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _ringController;

  ParsedTransactionData? _parsedData;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceInputProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  void _parseCurrentWords() {
    final state = ref.read(voiceInputProvider);
    final categories = ref.read(categoriesProvider).value ?? [];
    final transactions = ref.read(transactionProvider).value ?? [];

    if (state.lastWords.isNotEmpty) {
      setState(() {
        _parsedData = VoiceCommandParser.parse(
          state.lastWords,
          categories,
          transactions,
        );
      });
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

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.income:
        return 'Income';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  IconData _typeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        24,
        16,
        24,
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
          const Gap(28),

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
                              ? Icons.check_rounded
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: state.error.isNotEmpty
                    ? AppTheme.errorColor(context)
                    : AppTheme.textColor(context),
                letterSpacing: -0.3,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    fontSize: 15,
                    fontWeight: hasWords ? FontWeight.w600 : FontWeight.w400,
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

          // ── Parsed preview ──
          if (showPreview) ...[_buildPreviewCard(context)],

          // ── Bottom actions ──
          if (showPreview) ...[
            const Gap(20),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
            trailing: data.amount != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currency.symbol} ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: typeColor.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        data.amount == data.amount!.truncateToDouble()
                            ? data.amount!.toInt().toString()
                            : data.amount!.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Not detected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textLightColor(
                        context,
                      ).withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
          _buildPreviewDivider(context),

          // Type row
          _buildPreviewRow(
            context,
            icon: _typeIcon(data.type),
            iconColor: typeColor,
            label: 'Type',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _typeLabel(data.type),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
            ),
          ),
          _buildPreviewDivider(context),

          // Category row
          _buildPreviewRow(
            context,
            icon: data.category != null
                ? IconUtils.getIcon(data.category!.iconCodePoint)
                : Icons.category_rounded,
            iconColor: data.category?.color,
            label: 'Category',
            trailing: data.category != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Not detected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textLightColor(
                        context,
                      ).withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),

          // Note row (only if note is present)
          if (data.note.isNotEmpty) ...[
            _buildPreviewDivider(context),
            _buildPreviewRow(
              context,
              icon: Icons.sticky_note_2_rounded,
              label: 'Note',
              trailing: Flexible(
                child: Text(
                  data.note,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ),
          ],
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.textLightColor(context)).withValues(
                alpha: 0.1,
              ),
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
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textLightColor(context),
            ),
          ),
          const Spacer(),
          trailing,
        ],
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
