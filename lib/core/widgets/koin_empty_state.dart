import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';

/// Consolidated, deep EmptyState module for screen tabs and detail pages.
/// Encapsulates circular glow shadow containers, standardized typography,
/// and optional CTA actions in both box and sliver layouts.
class KoinEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double iconSize;
  final EdgeInsetsGeometry circlePadding;
  final Widget? action;
  final Alignment alignment;
  final bool asSliver;

  const KoinEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize = 56,
    this.circlePadding = const EdgeInsets.all(36),
    this.action,
    this.alignment = const Alignment(0, -0.25),
    this.asSliver = false,
  });

  /// Factory constructor to render as a complete pull-to-refresh scrollable view
  const KoinEmptyState.sliver({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize = 56,
    this.circlePadding = const EdgeInsets.all(36),
    this.action,
    this.alignment = const Alignment(0, -0.25),
  }) : asSliver = true;

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: circlePadding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: AppTheme.primaryColor(context).withValues(alpha: 0.6),
          ),
        ),
        const Gap(24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textColor(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const Gap(8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textLightColor(context),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (action != null) ...[
          const Gap(24),
          action!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (asSliver) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _buildContent(context),
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: _buildContent(context),
      ),
    );
  }
}
