import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koin/core/theme.dart';
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
  final String? semanticLabel;
  final bool? selected;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.enableHaptic = true,
    this.hapticLevel = HapticLevel.light,
    this.semanticLabel,
    this.selected,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  bool _focused = false;

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

  void _activate() {
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
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return FocusableActionDetector(
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        selected: widget.selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _focused
                ? Border.all(color: AppTheme.primaryColor(context))
                : null,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              if (!reduceMotion) _controller.forward();
            },
            onTapUp: (_) {
              _controller.reverse();
            },
            onTap: _activate,
            onTapCancel: () => _controller.reverse(),
            child: reduceMotion
                ? widget.child
                : ScaleTransition(scale: _scaleAnim, child: widget.child),
          ),
        ),
      ),
    );
  }
}
