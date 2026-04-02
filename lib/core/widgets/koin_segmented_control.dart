import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class KoinSegmentedControl extends StatelessWidget {
  final TabController controller;
  final String leftLabel;
  final String rightLabel;

  const KoinSegmentedControl({
    super.key,
    required this.controller,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        return Container(
          height: 56, // Taller for a premium feel
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
                    final tabWidth = constraints.maxWidth / 2;
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
                          children: [
                            _buildTabItem(context, 0, leftLabel),
                            _buildTabItem(context, 1, rightLabel),
                          ],
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

  Widget _buildTabItem(BuildContext context, int index, String label) {
    // Calculate precise color fraction based on animation for smooth color transition
    final animationValue = controller.animation!.value;
    final value = index == 0 ? 1.0 - animationValue : animationValue;
    final clampedValue = value.clamp(0.0, 1.0);
    final isActive = value > 0.5;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticService.selection();
          controller.animateTo(index);
        },
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: Color.lerp(
                AppTheme.textLightColor(context),
                AppTheme.textColor(context),
                clampedValue,
              ),
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
