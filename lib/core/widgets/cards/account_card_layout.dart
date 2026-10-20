import 'package:flutter/material.dart';

import '../primitives/koin_account_avatar.dart';

import 'package:gap/gap.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';

import 'card_background_shapes.dart';

/// Dashboard account styling, also used by the portfolio and editable preview.
class AccountCardLayout extends StatelessWidget {
  /// Includes padding, both text rows, their gap, and the neutral card border.
  static double minimumHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return 34 +
        scaler.scale(KoinTypography.caption) * 2.5 +
        8 +
        scaler.scale(KoinTypography.sectionTitle) * 1.25;
  }

  const AccountCardLayout({
    super.key,
    required this.account,
    required this.name,
    required this.amount,
    this.footer,
    this.action,
    this.selected = false,
  });

  final Account account;
  final Widget name;
  final Widget amount;
  final Widget? footer;
  final Widget? action;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colored = account.cardColor != null || account.logoAsset != null;
    final baseColor = account.cardColor ?? account.color;
    final foreground = colored
        ? (account.cardForeground ?? Colors.white)
        : AppTheme.textColor(context);
    return Container(
      constraints: BoxConstraints(minHeight: minimumHeight(context)),
      decoration: BoxDecoration(
        color: colored ? null : AppTheme.surfaceColor(context),
        gradient: colored
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withValues(alpha: 0.95),
                  baseColor.withValues(alpha: 0.8),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(KoinShape.field),
        border: Border.all(
          color: selected
              ? (colored ? foreground : AppTheme.primaryColor(context))
              : colored
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.dividerColor(context).withValues(alpha: 0.6),
          width: selected ? 2.5 : (colored ? 0.5 : 1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (colored)
            Positioned.fill(
              child: CardBackgroundShapes(
                shapeType:
                    account.cardShapeType ?? (account.id.hashCode.abs() % 8),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height:
                      MediaQuery.textScalerOf(context)
                          .scale(KoinTypography.caption) *
                      2.5,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: account.logoAsset == null
                              ? (colored ? foreground : account.color)
                                    .withValues(alpha: 0.12)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: KoinAccountAvatar(
                          iconCodePoint: account.iconCodePoint,
                          logoAsset: account.logoAsset,
                          size: 24,
                          iconSize: 16,
                          radius: 8,
                          color: colored
                              ? foreground
                              : AppTheme.contentColor(context, account.color),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: action == null ? 0 : 36,
                          ),
                          child: name,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                amount,
                ?footer,
              ],
            ),
          ),
          if (action != null) Positioned(top: 4, right: 4, child: action!),
        ],
      ),
    );
  }
}
