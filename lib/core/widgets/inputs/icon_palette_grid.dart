import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';

/// Consolidated icon selector module for Categories, Accounts, and Tags.
/// Encapsulates icon rendering from code points or IconData, selection highlighting,
/// active color tinting, scale bounce animations, and tactile light haptics.
class IconPaletteGrid extends StatelessWidget {
  final List<IconData>? icons;
  final List<int>? iconCodes;
  final IconData? selectedIcon;
  final int? selectedCodePoint;
  final ValueChanged<IconData>? onIconSelected;
  final ValueChanged<int>? onCodePointSelected;
  final Color activeColor;
  final bool isScrollableRow;
  final int crossAxisCount;
  final double itemSize;
  final BoxShape shape;
  final ScrollController? scrollController;

  const IconPaletteGrid({
    super.key,
    this.icons,
    this.iconCodes,
    this.selectedIcon,
    this.selectedCodePoint,
    this.onIconSelected,
    this.onCodePointSelected,
    required this.activeColor,
    this.isScrollableRow = false,
    this.crossAxisCount = 6,
    this.itemSize = 44,
    this.shape = BoxShape.rectangle,
    this.scrollController,
  }) : assert(
         icons != null || iconCodes != null,
         'Either icons or iconCodes must be provided',
       );

  int get _itemCount => icons != null ? icons!.length : iconCodes!.length;

  (IconData, int) _resolveItem(int index) {
    if (icons != null) {
      final icon = icons![index];
      return (icon, icon.codePoint);
    } else {
      final code = iconCodes![index];
      return (IconUtils.getIcon(code), code);
    }
  }

  bool _isSelected(IconData icon, int code) {
    if (selectedCodePoint != null) {
      return selectedCodePoint == code;
    }
    if (selectedIcon != null) {
      return selectedIcon!.codePoint == code;
    }
    return false;
  }

  void _handleTap(IconData icon, int code) {
    HapticService.light();
    if (onCodePointSelected != null) {
      onCodePointSelected!(code);
    }
    if (onIconSelected != null) {
      onIconSelected!(icon);
    }
  }

  Widget _buildItem(BuildContext context, int index) {
    final (icon, code) = _resolveItem(index);
    final isSelected = _isSelected(icon, code);

    return GestureDetector(
      onTap: () => _handleTap(icon, code),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : shape == BoxShape.circle
                ? AppTheme.dividerColor(context).withValues(alpha: 0.1)
                : AppTheme.surfaceLightColor(context),
            shape: shape,
            borderRadius: shape == BoxShape.circle
                ? null
                : BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor : AppTheme.dividerColor(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected
                  ? activeColor
                  : AppTheme.textLightColor(context).withValues(alpha: 0.5),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _itemCount;

    if (isScrollableRow) {
      return SizedBox(
        height: itemSize + 8,
        child: ListView.builder(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: count,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildItem(context, index),
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
        itemCount: count,
        itemBuilder: (context, index) {
          return _buildItem(context, index);
        },
      ),
    );
  }
}
