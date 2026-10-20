import 'package:flutter/material.dart';
import 'package:koin/core/utils/icon_utils.dart';

/// Account identity shared by cards, selectors and inline linked-account labels.
class KoinAccountAvatar extends StatelessWidget {
  const KoinAccountAvatar({
    super.key,
    required this.iconCodePoint,
    required this.color,
    this.logoAsset,
    this.size = 24,
    this.iconSize,
    this.radius = 4,
  });
  final int iconCodePoint;
  final Color color;
  final String? logoAsset;
  final double size;
  final double? iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      IconUtils.getIcon(iconCodePoint),
      size: iconSize ?? size,
      color: color,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: logoAsset == null
            ? fallback
            : Image.asset(
                logoAsset!,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
