import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

class KoinSegmentItem {
  final String label;
  final IconData? icon;
  const KoinSegmentItem({required this.label, this.icon});
}

/// Joined, outlined segments for tabs; forms use [KoinChoiceControl].
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller.animation!,
    builder: (context, _) => _SegmentTrack(
      segments: segments,
      position: controller.animation!.value,
      selectedIndex: controller.index,
      onChanged: (index) {
        if (controller.index == index) return;
        HapticService.selection();
        controller.animateTo(
          index,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      },
    ),
  );
}

/// The same joined-segment appearance for mutually exclusive form choices.
/// Indices map to [segments]; callers retain ownership of the field value.
class KoinChoiceControl extends StatelessWidget {
  final List<KoinSegmentItem> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const KoinChoiceControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(segments.length > 0),
       assert(selectedIndex >= 0 && selectedIndex < segments.length);

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(
      begin: selectedIndex.toDouble(),
      end: selectedIndex.toDouble(),
    ),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    builder: (context, position, _) => _SegmentTrack(
      segments: segments,
      position: position,
      selectedIndex: selectedIndex,
      onChanged: (index) {
        if (index == selectedIndex) return;
        HapticService.selection();
        onChanged(index);
      },
    ),
  );
}

class _SegmentTrack extends StatelessWidget {
  final List<KoinSegmentItem> segments;
  final double position;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTrack({
    required this.segments,
    required this.position,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    final scaler = MediaQuery.textScalerOf(context);
    final height = math.max(
      48.0,
      scaler.scale(KoinTypography.itemTitle) * 2 + 16,
    );
    final borderColor = AppTheme.fieldBorderColor(context);
    final color = AppTheme.textColor(context);
    const radius = BorderRadius.all(Radius.circular(KoinShape.field));

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var index = 0; index < segments.length; index++) ...[
            if (index > 0)
              SizedBox(
                width: 1,
                height: double.infinity,
                child: ColoredBox(color: borderColor),
              ),
            Expanded(
              child: Semantics(
                selected: index == selectedIndex,
                inMutuallyExclusiveGroup: true,
                child: TextButton(
                  onPressed: () => onChanged(index),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    backgroundColor: primary.withValues(
                      alpha:
                          0.14 *
                          (1.0 - (index - position).abs()).clamp(0.0, 1.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size(0, height),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (segments[index].icon != null &&
                          scaler.scale(16) <= 20) ...[
                        Icon(segments[index].icon, size: 20, color: color),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          segments[index].label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                            color: color,
                            fontSize: KoinTypography.itemTitle,
                            fontWeight: KoinTypography.titleWeight,
                            letterSpacing: KoinTypography.itemTracking,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
