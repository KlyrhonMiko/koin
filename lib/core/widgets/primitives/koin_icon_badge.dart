import 'package:flutter/material.dart';

/// Decorative entity icon. Interaction and semantics belong to the parent row.
class KoinIconBadge extends StatelessWidget {
  const KoinIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 20,
    this.radius,
    this.opacity = 0.1,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double? radius;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: opacity),
      shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: radius == null ? null : BorderRadius.circular(radius!),
    ),
    child: Icon(icon, color: color, size: iconSize),
  );
}
