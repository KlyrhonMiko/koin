import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/sheets/confirmation_sheet.dart';

/// Lets a surrounding pager yield horizontal gestures that start on a card.
class SwipeToDeletePointerNotification extends Notification {
  final int pointer;
  final bool isDown;

  const SwipeToDeletePointerNotification({
    required this.pointer,
    required this.isDown,
  });
}

/// Consolidated, deep swipe-to-delete Dismissible tile.
/// Encapsulates swipe physics, drag-threshold haptics, deletion backgrounds,
/// and automated ConfirmationSheet integration.
class SwipeToDeleteTile extends StatefulWidget {
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
  final bool fillRoundedCorners;

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
    this.fillRoundedCorners = false,
  });

  @override
  State<SwipeToDeleteTile> createState() => _SwipeToDeleteTileState();
}

class _SwipeToDeleteTileState extends State<SwipeToDeleteTile> {
  double _swipeProgress = 0;
  DismissDirection _swipeDirection = DismissDirection.endToStart;

  @override
  Widget build(BuildContext context) {
    final bgRadius = widget.borderRadius ?? BorderRadius.circular(22);
    final deleteBgColor =
        widget.backgroundColor ?? AppTheme.expenseColor(context);

    final dismissible = Dismissible(
      key: widget.key ?? ValueKey(this),
      direction: widget.direction,
      onUpdate: (details) {
        if (widget.fillRoundedCorners) {
          setState(() {
            _swipeProgress = details.progress;
            _swipeDirection = details.direction;
          });
        }
        if (details.reached && !details.previousReached) {
          HapticService.selection();
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: widget.margin,
        decoration: BoxDecoration(color: deleteBgColor, borderRadius: bgRadius),
        child: Icon(
          widget.icon,
          color: widget.iconColor ?? Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (dismissDirection) async {
        if (widget.confirmDismiss != null) {
          return await widget.confirmDismiss!(dismissDirection);
        }

        if (widget.confirmTitle != null) {
          HapticService.medium();
          final confirmed = await ConfirmationSheet.show(
            context: context,
            title: widget.confirmTitle!,
            description:
                widget.confirmDescription ?? 'This action cannot be undone.',
            confirmLabel: widget.confirmLabel,
            confirmColor: deleteBgColor.withValues(alpha: 1.0),
            icon: widget.icon,
            isDanger: true,
          );
          return confirmed ?? false;
        }

        return true;
      },
      onDismissed: (_) {
        widget.onDelete();
      },
      child: widget.child,
    );

    final content = !widget.fillRoundedCorners
        ? dismissible
        : Stack(
            children: [
              if (_swipeProgress > 0)
                Positioned.fill(
                  child: ClipPath(
                    clipper: _RoundedSwipeBackgroundClipper(
                      radius: bgRadius,
                      progress: _swipeProgress,
                      direction: _swipeDirection,
                      textDirection: Directionality.of(context),
                    ),
                    child: ColoredBox(color: deleteBgColor),
                  ),
                ),
              dismissible,
            ],
          );

    return Listener(
      onPointerDown: (event) => SwipeToDeletePointerNotification(
        pointer: event.pointer,
        isDown: true,
      ).dispatch(context),
      onPointerUp: (event) => SwipeToDeletePointerNotification(
        pointer: event.pointer,
        isDown: false,
      ).dispatch(context),
      onPointerCancel: (event) => SwipeToDeletePointerNotification(
        pointer: event.pointer,
        isDown: false,
      ).dispatch(context),
      child: content,
    );
  }
}

/// Paints behind the exposed rounded corners without tinting the card itself.
class _RoundedSwipeBackgroundClipper extends CustomClipper<Path> {
  const _RoundedSwipeBackgroundClipper({
    required this.radius,
    required this.progress,
    required this.direction,
    required this.textDirection,
  });

  final BorderRadius radius;
  final double progress;
  final DismissDirection direction;
  final TextDirection textDirection;

  @override
  Path getClip(Size size) {
    final movesRight = direction == DismissDirection.startToEnd
        ? textDirection == TextDirection.ltr
        : textDirection == TextDirection.rtl;
    final offset = Offset(size.width * progress * (movesRight ? 1 : -1), 0);
    final card = radius.toRRect(Offset.zero & size);
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(card),
      Path()..addRRect(card.shift(offset)),
    );
  }

  @override
  bool shouldReclip(_RoundedSwipeBackgroundClipper oldClipper) =>
      radius != oldClipper.radius ||
      progress != oldClipper.progress ||
      direction != oldClipper.direction ||
      textDirection != oldClipper.textDirection;
}
