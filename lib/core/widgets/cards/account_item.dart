import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/animation_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/primitives/animated_counter.dart';
import 'package:koin/core/widgets/cards/card_background_shapes.dart';
import 'package:koin/core/widgets/primitives/pressable_scale.dart';
import 'portfolio_card_style.dart';

class AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final double savingsAmount;
  final String currencySymbol;
  final Currency? currency;
  final VoidCallback onTap;
  final VoidCallback? onPrivateToggle;
  final Widget? trailing;
  final bool isPreview;
  final bool isSelected;
  final String? animationSessionKey;
  final bool animateBalance;

  const AccountItem({
    super.key,
    required this.account,
    required this.balance,
    this.savingsAmount = 0,
    required this.currencySymbol,
    this.currency,
    required this.onTap,
    this.onPrivateToggle,
    this.trailing,
    this.isPreview = false,
    this.isSelected = false,
    this.animationSessionKey,
    this.animateBalance = true,
  });

  /// Whether the card has a coloured (non-default) background.
  bool get _hasColoredBackground =>
      account.cardColor != null || account.logoAsset != null;

  BoxDecoration _cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasColoredBackground) {
      final baseColor = account.cardColor ?? account.color;
      return BoxDecoration(
        borderRadius: BorderRadius.circular(PortfolioCardStyle.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.95),
            baseColor.withValues(alpha: 0.8),
          ],
          stops: const [0.2, 1.0],
        ),
        boxShadow: isDark
            ? null
            : [
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
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          width: isSelected ? 2.5 : 0.5,
        ),
      );
    }

    return PortfolioCardStyle.decoration(context).copyWith(
      border: Border.all(
        color: isSelected
            ? AppTheme.primaryColor(context)
            : AppTheme.dividerColor(context).withValues(alpha: 0.6),
        width: isSelected ? 2.5 : 1,
      ),
    );
  }

  List<Widget> _buildBackgroundShapes(bool colored) {
    if (!colored) return const [];

    final shapeType = account.cardShapeType ?? (account.id.hashCode.abs() % 8);
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
    final money =
        (currency ??
                Currency(code: 'USD', symbol: currencySymbol, name: 'Currency'))
            .formatter;
    final isPrivate = account.excludeFromTotal;
    if (isPrivate && animationSessionKey != null) {
      AnimationTracker.updateValue(
        'acc_bal_${account.id}_$animationSessionKey',
        0.0,
      );
    }
    final colored = _hasColoredBackground;
    final foreground = account.cardForeground;

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
                padding: PortfolioCardStyle.padding,
                child: Row(
                  children: [
                    // ── Account Icon / Logo ──
                    Container(
                      width: PortfolioCardStyle.iconSize,
                      height: PortfolioCardStyle.iconSize,
                      decoration: BoxDecoration(
                        color: account.logoAsset == null
                            ? (colored
                                  ? (foreground ?? Colors.white).withValues(
                                      alpha: 0.15,
                                    )
                                  : account.color.withValues(alpha: 0.1))
                            : null,
                        border: account.logoAsset == null
                            ? Border.all(
                                color: colored
                                    ? (foreground ?? Colors.white).withValues(
                                        alpha: 0.25,
                                      )
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
                                color: colored
                                    ? (foreground ?? Colors.white)
                                    : account.color,
                                size: 24,
                              ),
                            ),
                    ),
                    const Gap(16),

                    // ── Name + Balance ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: PortfolioCardStyle.label(
                              context,
                              colored: colored,
                              foreground: foreground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(KoinSpacing.labelGap),
                          isPrivate
                              ? Text(
                                  '••••••',
                                  style: TextStyle(
                                    color: colored
                                        ? (foreground ?? Colors.white)
                                        : AppTheme.textColor(context),
                                    fontWeight: KoinTypography.titleWeight,
                                    fontSize: KoinTypography.itemAmount,
                                    letterSpacing: 2,
                                  ),
                                )
                              : !animateBalance
                              ? Text(
                                  money.format(balance),
                                  style: PortfolioCardStyle.amount(
                                    context,
                                    colored: colored,
                                    foreground: foreground,
                                  ),
                                )
                              : AnimatedCounter(
                                  value: balance,
                                  lastValueToken: animationSessionKey != null
                                      ? 'acc_bal_${account.id}_$animationSessionKey'
                                      : null,
                                  formatter: money.format,
                                  duration: const Duration(milliseconds: 600),
                                  style: PortfolioCardStyle.amount(
                                    context,
                                    colored: colored,
                                    foreground: foreground,
                                  ),
                                ),
                          if (savingsAmount > 0 && !isPrivate) ...[
                            const Gap(2),
                            Text(
                              '${money.format(savingsAmount)} in savings',
                              style: TextStyle(
                                fontSize: KoinTypography.small,
                                height: 1.1,
                                color: colored
                                    ? (foreground ?? Colors.white).withValues(
                                        alpha: 0.7,
                                      )
                                    : AppTheme.textLightColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Privacy Toggle ──
                    if (onPrivateToggle != null) ...[
                      Tooltip(
                        excludeFromSemantics: true,
                        message: isPrivate
                            ? 'Show balance and include in totals'
                            : 'Hide balance and exclude from totals',
                        child: PressableScale(
                          semanticLabel: isPrivate
                              ? 'Show balance and include in totals'
                              : 'Hide balance and exclude from totals',
                          onTap: onPrivateToggle!,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              isPrivate
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: colored
                                  ? (foreground ?? Colors.white).withValues(
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
                      ),
                    ],

                    // ── Trailing (drag handle etc.) ──
                    if (trailing != null) ...[
                      const Gap(8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          iconTheme: IconThemeData(
                            color: colored
                                ? (foreground ?? Colors.white).withValues(
                                    alpha: 0.5,
                                  )
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
