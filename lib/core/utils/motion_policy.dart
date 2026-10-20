import 'package:flutter/material.dart';

import 'dart:collection';

import 'package:flutter_animate/flutter_animate.dart';

import 'animation_utils.dart';

abstract final class KoinMotion {
  static const entrance = Duration(milliseconds: 250);
  static const feedback = Duration(milliseconds: 160);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static void Function(AnimationController) onInit(BuildContext context) =>
      (controller) {
        if (MediaQuery.disableAnimationsOf(context)) {
          controller.stop();
          controller.value = 1;
        }
      };
}

extension KoinWidgetMotion on Widget {
  /// Standard entrance used by cards, actions and report sections.
  Widget koinEntrance(
    BuildContext context, {
    String? token,
    bool enabled = true,
  }) => _KoinEntrance(
    key: token == null ? null : ValueKey(token),
    token: token,
    enabled: enabled,
    child: this,
  );

  Animate koinAnimate(
    BuildContext context, {
    Key? key,
    bool? autoPlay,
    AnimateCallback? onInit,
    Duration? delay,
    double? target,
  }) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Animate(
      key: key,
      autoPlay: !reduced && (autoPlay ?? true),
      value: reduced ? 1 : null,
      target: reduced ? null : target,
      delay: reduced ? Duration.zero : delay,
      onInit: onInit,
      child: this,
    );
  }
}

/// Keep the transition tree mounted during refreshes and preference changes.
/// A token suppresses replays when a lazily built row returns to the viewport.
class _KoinEntrance extends StatefulWidget {
  const _KoinEntrance({
    super.key,
    required this.child,
    this.token,
    required this.enabled,
  });

  final Widget child;
  final String? token;
  final bool enabled;

  @override
  State<_KoinEntrance> createState() => _KoinEntranceState();
}

class _KoinEntranceState extends State<_KoinEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: KoinMotion.entrance,
  );
  late final Animation<double> _progress = _controller.drive(
    CurveTween(curve: KoinMotion.curve),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !widget.enabled) {
      _controller.stop();
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      if (widget.token != null && AnimationTracker.hasSeen(widget.token!)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _KoinEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _progress,
    child: ScaleTransition(
      scale: _progress.drive(Tween<double>(begin: 0.95, end: 1)),
      child: widget.child,
    ),
  );
}

extension KoinListMotion on List<Widget> {
  KoinMotionList koinAnimate(
    BuildContext context, {
    bool? autoPlay,
    AnimateCallback? onInit,
    Duration? delay,
    Duration? interval,
  }) => KoinMotionList(
    this,
    context,
    autoPlay: autoPlay,
    onInit: onInit,
    delay: delay,
    interval: interval,
  );
}

/// The playback value follows the motion preference, so changing the preference
/// finishes a running or delayed effect without replacing its child state.
class KoinMotionList extends ListBase<Widget>
    with AnimateManager<KoinMotionList> {
  final List<Widget> _widgets = [];
  final List<Animate> _animations = [];

  KoinMotionList(
    List<Widget> children,
    BuildContext context, {
    bool? autoPlay,
    AnimateCallback? onInit,
    Duration? delay,
    Duration? interval,
  }) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is Spacer) {
        _widgets.add(child);
        continue;
      }
      final stagger = (interval ?? Duration.zero) * i;
      const maxStagger = Duration(milliseconds: 120);
      final animation = Animate(
        key: child.key == null ? null : ValueKey(child.key),
        autoPlay: !reduced && (autoPlay ?? true),
        value: reduced ? 1 : null,
        onInit: onInit,
        delay: reduced
            ? Duration.zero
            : (delay ?? Duration.zero) +
                  (stagger > maxStagger ? maxStagger : stagger),
        child: child,
      );
      _animations.add(animation);
      _widgets.add(animation);
    }
  }

  @override
  KoinMotionList addEffect(Effect effect) {
    for (final animation in _animations) {
      animation.addEffect(effect);
    }
    return this;
  }

  @override
  int get length => _widgets.length;
  @override
  set length(int value) => _widgets.length = value;
  @override
  Widget operator [](int index) => _widgets[index];
  @override
  void operator []=(int index, Widget value) => _widgets[index] = value;
}
