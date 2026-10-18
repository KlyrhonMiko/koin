import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';

/// Feature-local controls shared by goal and open-ended savings simulations.
class CoachAmountSlider extends StatelessWidget {
  const CoachAmountSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.divisions,
  });
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderThemeData(
      activeTrackColor: AppTheme.primaryColor(context),
      inactiveTrackColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
      thumbColor: AppTheme.primaryColor(context),
      trackHeight: 8,
    ),
    child: Slider(
      value: value,
      min: 0,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      onChangeEnd: (_) => HapticService.selection(),
    ),
  );
}

class CoachStepper extends StatelessWidget {
  const CoachStepper({
    super.key,
    required this.child,
    required this.onDecrease,
    required this.onIncrease,
  });
  final Widget child;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Decrease',
        onPressed: onDecrease,
        icon: const Icon(Icons.remove_circle_outline),
        color: AppTheme.textLightColor(context),
      ),
      Expanded(child: child),
      IconButton(
        tooltip: 'Increase',
        onPressed: onIncrease,
        icon: const Icon(Icons.add_circle_outline),
        color: AppTheme.textLightColor(context),
      ),
    ],
  );
}
