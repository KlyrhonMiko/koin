import 'package:flutter/material.dart';
import 'package:koin/core/core.dart';

/// Feature-local controls shared by goal and open-ended savings simulations.
class CoachAmountSlider extends StatefulWidget {
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
  State<CoachAmountSlider> createState() => _CoachAmountSliderState();
}

class _CoachAmountSliderState extends State<CoachAmountSlider> {
  double? _startValue;
  int? _lastStep;

  @override
  Widget build(BuildContext context) => SliderTheme(
    data: SliderThemeData(
      activeTrackColor: AppTheme.primaryColor(context),
      inactiveTrackColor: AppTheme.primaryColor(context).withValues(alpha: 0.1),
      thumbColor: AppTheme.primaryColor(context),
      trackHeight: 8,
    ),
    child: Slider(
      value: widget.value,
      min: 0,
      max: widget.max,
      divisions: widget.divisions,
      onChangeStart: (value) {
        _startValue = value;
        _lastStep = _step(value);
      },
      onChanged: (value) {
        final step = _step(value);
        if (step != null && step != _lastStep) {
          HapticService.selection();
          _lastStep = step;
        }
        widget.onChanged(value);
      },
      onChangeEnd: (value) {
        if (widget.divisions == null &&
            _startValue != null &&
            (value - _startValue!).abs() > 0.000001) {
          HapticService.selection();
        }
        _startValue = null;
        _lastStep = null;
      },
    ),
  );

  int? _step(double value) => widget.divisions == null || widget.max <= 0
      ? null
      : (value / widget.max * widget.divisions!).round();
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
        icon: const Icon(KoinIcons.minusCircle),
        color: AppTheme.textLightColor(context),
      ),
      Expanded(child: child),
      IconButton(
        tooltip: 'Increase',
        onPressed: onIncrease,
        icon: const Icon(KoinIcons.plusCircle),
        color: AppTheme.textLightColor(context),
      ),
    ],
  );
}
