import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Shared sheet chrome. Each flow retains its scrolling, keyboard and safe-area
/// policy so keypad sheets and content sheets can size differently.
class KoinSheetSurface extends StatelessWidget {
  const KoinSheetSurface({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.shadows,
    this.constraints,
    this.height,
    this.scrollable = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BoxConstraints? constraints;
  final double? height;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    constraints: constraints,
    height: height,
    decoration: BoxDecoration(
      color: color ?? AppTheme.surfaceColor(context),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(KoinShape.sheet),
      ),
      boxShadow: shadows,
    ),
    child: scrollable ? SingleChildScrollView(child: child) : child,
  );
}
