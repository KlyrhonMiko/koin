import 'package:flutter/material.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// A reusable widget that scales down on press for tactile feedback.
///
/// Provides a premium, native-feeling press interaction with optional
/// haptic feedback. Use this to wrap interactive cards, buttons, and
/// other tappable elements throughout the app.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  /// The scale factor when pressed down. Values closer to 1.0 are subtler.
  final double pressedScale;

  /// If true, triggers [HapticService.light] on tap.
  final bool enableHaptic;
  final HapticLevel hapticLevel;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.enableHaptic = true,
    this.hapticLevel = HapticLevel.light,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enableHaptic) {
      switch (widget.hapticLevel) {
        case HapticLevel.light:
          HapticService.light();
          break;
        case HapticLevel.medium:
          HapticService.medium();
          break;
        case HapticLevel.heavy:
          HapticService.heavy();
          break;
        case HapticLevel.selection:
          HapticService.selection();
          break;
        case HapticLevel.success:
          HapticService.success();
          break;
        case HapticLevel.error:
          HapticService.error();
          break;
      }
    }
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}
