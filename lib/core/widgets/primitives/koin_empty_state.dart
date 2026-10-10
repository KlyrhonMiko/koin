import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';

/// Consolidated, deep EmptyState module for screen tabs and detail pages.
/// Uses a muted circular icon and centered typography,
/// and optional CTA actions in both box and sliver layouts.
class KoinEmptyState extends StatelessWidget {
  final Key? contentKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final double iconSize;
  final EdgeInsetsGeometry circlePadding;
  final Widget? action;
  final Alignment alignment;
  final bool asSliver;
  final bool fullScreen;

  const KoinEmptyState({
    super.key,
    this.contentKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize = 36,
    this.circlePadding = const EdgeInsets.all(24),
    this.action,
    this.alignment = Alignment.center,
    this.asSliver = false,
    this.fullScreen = false,
  });

  /// Factory constructor to render as a complete pull-to-refresh scrollable view
  const KoinEmptyState.sliver({
    super.key,
    this.contentKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize = 36,
    this.circlePadding = const EdgeInsets.all(24),
    this.action,
    this.alignment = Alignment.center,
    this.fullScreen = true,
  }) : asSliver = true;

  Widget _buildContent(BuildContext context) {
    return Column(
      key: contentKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: fullScreen ? const EdgeInsets.all(28) : circlePadding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: fullScreen ? 48 : iconSize,
            color: AppTheme.textLightColor(context).withValues(alpha: 0.35),
          ),
        ),
        Gap(fullScreen ? 24 : 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textColor(context),
            fontSize: fullScreen
                ? KoinTypography.sectionTitle
                : KoinTypography.itemTitle,
            fontWeight: KoinTypography.titleWeight,
          ),
        ),
        const Gap(6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
            fontSize: fullScreen
                ? KoinTypography.compact
                : KoinTypography.caption,
            height: 1.4,
          ),
        ),
        if (action != null) ...[const Gap(24), action!],
      ],
    );
  }

  Widget _buildPaddedContent(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: fullScreen ? 32 : 16,
      vertical: 24,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fullScreen ? 320 : double.infinity),
      child: _buildContent(context),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (asSliver) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.only(bottom: fullScreen ? 96 : 0),
                child: Align(
                  alignment: alignment,
                  child: _buildPaddedContent(context),
                ),
              ),
            ),
          );
        },
      );
    }

    return Center(child: _buildPaddedContent(context));
  }
}
