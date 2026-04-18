import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/animation_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/animated_counter.dart';
import 'package:koin/core/widgets/card_background_shapes.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final String currencySymbol;
  final VoidCallback onTap;
  final VoidCallback? onPrivateToggle;
  final Widget? trailing;
  final bool isPreview;
  final bool isSelected;
  final String? animationSessionKey;

  const AccountItem({
    super.key,
    required this.account,
    required this.balance,
    required this.currencySymbol,
    required this.onTap,
    this.onPrivateToggle,
    this.trailing,
    this.isPreview = false,
    this.isSelected = false,
    this.animationSessionKey,
  });

  /// Whether the card has a coloured (non-default) background.
  bool get _hasColoredBackground =>
      account.cardColor != null || account.logoAsset != null;

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasColoredBackground) {
      final baseColor = account.cardColor ?? account.color;
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
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          width: isSelected ? 2.5 : 0.5,
        ),
      );
    }

    final surfaceColor = AppTheme.surfaceColor(context);
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isSelected
            ? AppTheme.primaryColor(context)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : AppTheme.dividerColor(context).withValues(alpha: 0.6)),
        width: isSelected ? 2.5 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  List<Widget> _buildBackgroundShapes(bool colored) {
    if (!colored) return const [];

    final shapeType = account.cardShapeType ?? (account.id.hashCode.abs() % 4);
    final opacityMultiplier = isPreview ? 3.0 : 1.0;

    return [
      Positioned.fill(
        child: CardBackgroundShapes(
          shapeType: shapeType,
          opacityMultiplier: opacityMultiplier,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = account.excludeFromTotal;
    if (isPrivate && animationSessionKey != null) {
      AnimationTracker.updateValue(
        'acc_bal_${account.id}_$animationSessionKey',
        0.0,
      );
    }
    final colored = _hasColoredBackground;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        decoration: _cardDecoration(context),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            ..._buildBackgroundShapes(colored),
            if (isPreview)
              const SizedBox.shrink()
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // ── Account Icon / Logo ──
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: account.logoAsset == null
                            ? (colored
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : account.color.withValues(alpha: 0.1))
                            : null,
                        border: account.logoAsset == null
                            ? Border.all(
                                color: colored
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : account.color.withValues(alpha: 0.15),
                                width: 1,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: account.logoAsset != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                account.logoAsset!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Icon(
                                IconUtils.getIcon(account.iconCodePoint),
                                color: colored ? Colors.white : account.color,
                                size: 24,
                              ),
                            ),
                    ),
                    const Gap(16),

                    // ── Name + Balance (two lines) ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: TextStyle(
                              color: colored
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppTheme.textLightColor(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(2),
                          isPrivate
                              ? Text(
                                  '••••••',
                                  style: TextStyle(
                                    color: colored
                                        ? Colors.white
                                        : AppTheme.textColor(context),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    letterSpacing: 2,
                                  ),
                                )
                              : AnimatedCounter(
                                  value: balance,
                                  lastValueToken: animationSessionKey != null
                                      ? 'acc_bal_${account.id}_$animationSessionKey'
                                      : null,
                                  formatter: (v) => NumberFormat.currency(
                                    symbol: currencySymbol,
                                  ).format(v),
                                  duration: const Duration(milliseconds: 600),
                                  style: TextStyle(
                                    color: colored
                                        ? Colors.white
                                        : AppTheme.textColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                        ],
                      ),
                    ),

                    // ── Privacy Toggle ──
                    if (onPrivateToggle != null) ...[
                      GestureDetector(
                        onTap: onPrivateToggle,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Icon(
                            isPrivate
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: colored
                                ? Colors.white.withValues(
                                    alpha: isPrivate ? 0.5 : 0.8,
                                  )
                                : (isPrivate
                                      ? AppTheme.textLightColor(
                                          context,
                                        ).withValues(alpha: 0.4)
                                      : AppTheme.primaryColor(
                                          context,
                                        ).withValues(alpha: 0.6)),
                          ),
                        ),
                      ),
                    ],

                    // ── Trailing (drag handle etc.) ──
                    if (trailing != null) ...[
                      const Gap(8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: IconThemeData(
                            color: colored
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppTheme.textLightColor(
                                    context,
                                  ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: trailing!,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
