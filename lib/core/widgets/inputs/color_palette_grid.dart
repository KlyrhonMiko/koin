import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// Consolidated color palette selector module for Categories, Accounts,
/// and Tags.
/// Encapsulates color swatch rendering, scale animations, active checkmark badges,
/// and tactile haptic feedback.
class ColorPaletteGrid extends StatelessWidget {
  final List<String>? hexColors;
  final List<Color>? colors;
  final String? selectedHex;
  final Color? selectedColor;
  final ValueChanged<String>? onHexSelected;
  final ValueChanged<Color>? onColorSelected;
  final int crossAxisCount;
  final bool isScrollableRow;
  final BoxShape shape;
  final double itemSize;
  final ScrollController? scrollController;

  const ColorPaletteGrid({
    super.key,
    this.hexColors,
    this.colors,
    this.selectedHex,
    this.selectedColor,
    this.onHexSelected,
    this.onColorSelected,
    this.crossAxisCount = 6,
    this.isScrollableRow = false,
    this.shape = BoxShape.rectangle,
    this.itemSize = 44,
    this.scrollController,
  }) : assert(hexColors != null || colors != null, 'Either hexColors or colors must be provided');

  List<Color> _resolvedColors() {
    if (colors != null) return colors!;
    return hexColors!
        .map((hex) => Color(int.parse(hex.replaceFirst('#', '0xFF'))))
        .toList();
  }

  bool _isIndexSelected(int index, Color color) {
    if (selectedHex != null && hexColors != null && index < hexColors!.length) {
      return hexColors![index].toLowerCase() == selectedHex!.toLowerCase();
    }
    if (selectedColor != null) {
      return selectedColor!.toARGB32() == color.toARGB32();
    }
    return false;
  }

  void _handleTap(int index, Color color) {
    HapticService.light();
    if (onHexSelected != null && hexColors != null && index < hexColors!.length) {
      onHexSelected!(hexColors![index]);
    }
    if (onColorSelected != null) {
      onColorSelected!(color);
    }
  }

  Widget _buildItem(BuildContext context, int index, Color color) {
    final isSelected = _isIndexSelected(index, color);

    return GestureDetector(
      onTap: () => _handleTap(index, color),
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            color: color,
            shape: shape,
            borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: shape == BoxShape.circle ? 3 : 2.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedColors();

    if (isScrollableRow) {
      return SizedBox(
        height: itemSize + 8,
        child: ListView.builder(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: resolved.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildItem(context, index, resolved[index]),
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: resolved.length,
        itemBuilder: (context, index) {
          return _buildItem(context, index, resolved[index]);
        },
      ),
    );
  }
}
