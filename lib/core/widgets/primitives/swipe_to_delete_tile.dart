import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/sheets/confirmation_sheet.dart';

/// Consolidated, deep swipe-to-delete Dismissible tile.
/// Encapsulates swipe physics, drag-threshold haptics, deletion backgrounds,
/// and automated ConfirmationSheet integration.
class SwipeToDeleteTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String? confirmTitle;
  final String? confirmDescription;
  final String confirmLabel;
  final Future<bool?> Function(DismissDirection)? confirmDismiss;
  final DismissDirection direction;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const SwipeToDeleteTile({
    super.key,
    required this.child,
    required this.onDelete,
    this.confirmTitle,
    this.confirmDescription,
    this.confirmLabel = 'Delete',
    this.confirmDismiss,
    this.direction = DismissDirection.endToStart,
    this.borderRadius,
    this.margin,
    this.icon = Icons.delete_outline_rounded,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgRadius = borderRadius ?? BorderRadius.circular(22);
    final deleteBgColor = backgroundColor ?? AppTheme.expenseColor(context);

    return Dismissible(
      key: key ?? UniqueKey(),
      direction: direction,
      onUpdate: (details) {
        if (details.reached && !details.previousReached) {
          HapticService.selection();
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: margin,
        decoration: BoxDecoration(
          color: deleteBgColor,
          borderRadius: bgRadius,
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (dismissDirection) async {
        if (confirmDismiss != null) {
          return await confirmDismiss!(dismissDirection);
        }

        if (confirmTitle != null) {
          HapticService.medium();
          final confirmed = await ConfirmationSheet.show(
            context: context,
            title: confirmTitle!,
            description: confirmDescription ?? 'This action cannot be undone.',
            confirmLabel: confirmLabel,
            confirmColor: deleteBgColor,
            icon: icon,
            isDanger: true,
          );
          return confirmed ?? false;
        }

        return true;
      },
      onDismissed: (_) {
        onDelete();
      },
      child: child,
    );
  }
}
