import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class KoinSegmentItem {
  final String label;
  final IconData? icon;

  const KoinSegmentItem({required this.label, this.icon});
}

class KoinSegmentedControl extends StatelessWidget {
  final TabController controller;
  final List<KoinSegmentItem> segments;

  KoinSegmentedControl({
    super.key,
    required this.controller,
    required String leftLabel,
    required String rightLabel,
  }) : segments = [
         KoinSegmentItem(label: leftLabel),
         KoinSegmentItem(label: rightLabel),
       ];

  const KoinSegmentedControl.custom({
    super.key,
    required this.controller,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        return Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.dividerColor(context).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabCount = segments.length;
                    final tabWidth = constraints.maxWidth / tabCount;
                    final animationValue = controller.animation!.value;

                    return Stack(
                      children: [
                        // Sliding Indicator
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: animationValue * tabWidth,
                          width: tabWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor(context),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor(
                                    context,
                                  ).withValues(alpha: 0.1),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tab Labels
                        Row(
                          children: List.generate(tabCount, (i) {
                            return _buildTabItem(context, i, segments[i]);
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(BuildContext context, int index, KoinSegmentItem item) {
    final animationValue = controller.animation!.value;
    // Calculate distance from this index to current animation value
    final distance = (index - animationValue).abs();
    // Clamp to 0..1 range (1 = fully active, 0 = fully inactive)
    final value = (1.0 - distance).clamp(0.0, 1.0);
    final isActive = value > 0.5;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticService.selection();
          controller.animateTo(index);
        },
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 18,
                  color: Color.lerp(
                    AppTheme.textLightColor(context),
                    AppTheme.textColor(context),
                    value,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                item.label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: Color.lerp(
                    AppTheme.textLightColor(context),
                    AppTheme.textColor(context),
                    value,
                  ),
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
