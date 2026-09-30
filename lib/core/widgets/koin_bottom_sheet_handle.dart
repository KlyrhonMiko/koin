import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Standardized pill grab handle placed at the top of modal bottom sheets.
class KoinBottomSheetHandle extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const KoinBottomSheetHandle({
    super.key,
    this.width = 40.0,
    this.height = 4.0,
    this.borderRadius = 2.0,
    this.color,
    this.padding = const EdgeInsets.only(top: 8.0, bottom: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color ?? AppTheme.dividerColor(context),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
