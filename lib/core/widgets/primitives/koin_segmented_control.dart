import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class KoinSegmentItem {
  final String label;
  final IconData? icon;

  const KoinSegmentItem({required this.label, this.icon});
}

/// Pill-shaped segmented control driven by a [TabController].
///
/// Visual language matches the rest of the app: a solid, borderless surface
/// track (same as content cards) with a primary-tinted indicator (same as
/// accent icon buttons and the active nav item).
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

  static const double _height = 52;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dark: surface track + primary-tinted pill.
    // Light: recessed grey track + raised white pill (tinted mint on white
    // lacks contrast, and a white track disappears on the light background).
    final trackColor = isDark
        ? AppTheme.surfaceColor(context)
        : AppTheme.surfaceLightColor(context);
    final indicatorColor = isDark
        ? primary.withValues(alpha: 0.16)
        : AppTheme.surfaceColor(context);
    final activeTextColor = isDark ? primary : AppTheme.textColor(context);

    return Container(
      height: _height,
      width: double.infinity,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabCount = segments.length;
          final tabWidth = constraints.maxWidth / tabCount;

          return AnimatedBuilder(
            animation: controller.animation!,
            builder: (context, _) {
              final animationValue = controller.animation!.value;

              return Stack(
                children: [
                  // Sliding indicator — tinted, borderless, no shadow.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: animationValue * tabWidth,
                    width: tabWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: BorderRadius.circular(
                          (_height - _inset * 2) / 2,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(tabCount, (i) {
                      return Expanded(
                        child: _SegmentTab(
                          item: segments[i],
                          activeColor: activeTextColor,
                          activeness: (1.0 - (i - animationValue).abs())
                              .clamp(0.0, 1.0),
                          onTap: () {
                            if (controller.index == i) return;
                            HapticService.selection();
                            controller.animateTo(
                              i,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SegmentTab extends StatefulWidget {
  final KoinSegmentItem item;

  /// 1.0 = fully selected, 0.0 = fully unselected (interpolated during swipe).
  final double activeness;
  final VoidCallback onTap;
  final Color activeColor;

  const _SegmentTab({
    required this.item,
    required this.activeColor,
    required this.activeness,
    required this.onTap,
  });

  @override
  State<_SegmentTab> createState() => _SegmentTabState();
}

class _SegmentTabState extends State<_SegmentTab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppTheme.textLightColor(context),
      widget.activeColor,
      widget.activeness,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item.icon != null) ...[
                Icon(widget.item.icon, size: 18, color: color),
                const SizedBox(width: 8),
              ],
              Text(
                widget.item.label,
                style: TextStyle(
                  fontWeight: widget.activeness > 0.5
                      ? KoinTypography.titleWeight
                      : KoinTypography.labelWeight,
                  color: color,
                  fontSize: KoinTypography.body,
                  letterSpacing: KoinTypography.itemTracking,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
