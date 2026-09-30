import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

/// Shows a themed date picker dialog with haptics and keyboard unfocus handling.
Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  Color? primaryColor,
}) async {
  final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
  FocusManager.instance.primaryFocus?.unfocus();
  if (hadFocus) {
    await Future.delayed(const Duration(milliseconds: 150));
  }
  if (!context.mounted) return null;
  HapticService.light();

  final effectivePrimary = primaryColor ?? AppTheme.primaryColor(context);

  return await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? DateTime(2100),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: effectivePrimary,
            onPrimary: Colors.white,
            surface: AppTheme.surfaceColor(context),
            onSurface: AppTheme.textColor(context),
          ),
        ),
        child: child!,
      );
    },
  );
}

/// Consolidated, deep DateSelectorTile component.
/// Encapsulates keyboard unfocus timing, haptic feedback, date formatting,
/// container styling, and optionally invokes [showThemedDatePicker].
class DateSelectorTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final IconData icon;
  final VoidCallback? onTap;
  final ValueChanged<DateTime>? onDateSelected;
  final DateFormat? dateFormat;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final Color? primaryColor;

  const DateSelectorTile({
    super.key,
    required this.label,
    required this.date,
    this.icon = Icons.calendar_today_rounded,
    this.onTap,
    this.onDateSelected,
    this.dateFormat,
    this.firstDate,
    this.lastDate,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () async {
        final hadFocus = FocusManager.instance.primaryFocus?.hasFocus ?? false;
        FocusManager.instance.primaryFocus?.unfocus();
        if (hadFocus) {
          await Future.delayed(const Duration(milliseconds: 150));
        }

        if (onTap != null) {
          onTap!();
          return;
        }

        if (onDateSelected != null && context.mounted) {
          final picked = await showThemedDatePicker(
            context: context,
            initialDate: date,
            firstDate: firstDate,
            lastDate: lastDate,
            primaryColor: primaryColor,
          );
          if (picked != null) {
            onDateSelected!(picked);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: AppTheme.textLightColor(
                    context,
                  ).withValues(alpha: 0.6),
                ),
                const Gap(6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLightColor(
                      context,
                    ).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              (dateFormat ?? DateFormat.yMMMd()).format(date),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
