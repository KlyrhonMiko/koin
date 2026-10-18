import 'package:flutter/material.dart';

import 'dart:collection';

import 'package:flutter_animate/flutter_animate.dart';

abstract final class KoinMotion {
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
  Animate koinEntrance(BuildContext context) =>
      koinAnimate(
            context,
            autoPlay: !MediaQuery.disableAnimationsOf(context),
            onInit: KoinMotion.onInit(context),
          )
          .fade(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          )
          .scale(
            begin: const Offset(0.95, 0.95),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
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
      final animation = Animate(
        key: child.key == null ? null : ValueKey(child.key),
        autoPlay: !reduced && (autoPlay ?? true),
        value: reduced ? 1 : null,
        onInit: onInit,
        delay: reduced
            ? Duration.zero
            : (delay ?? Duration.zero) + (interval ?? Duration.zero) * i,
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
