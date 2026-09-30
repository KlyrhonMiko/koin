import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Consolidated proxy decorator for all [ReorderableListView] widgets.
/// Encapsulates smooth drag-elevation, scale transform (1.03x), and
/// primaryColor theme shadow.
Widget koinReorderProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final elevation = Curves.easeOut.transform(animation.value) * 16;
      final scale = 1.0 + (Curves.easeOut.transform(animation.value) * 0.03);
      return Transform.scale(
        scale: scale,
        child: Material(
          elevation: elevation,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          shadowColor: AppTheme.primaryColor(
            context,
          ).withValues(alpha: 0.3),
          child: child,
        ),
      );
    },
    child: child,
  );
}
