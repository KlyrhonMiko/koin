import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class DateRangeSelector extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final Function(DateTimeRange?) onChanged;
  final bool showClearButton;

  const DateRangeSelector({
    super.key,
    this.initialDateRange,
    required this.onChanged,
    this.showClearButton = false,
  });

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  late DateTimeRange? _dateRange;
  int? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _updateSelectedPreset();
  }

  void _updateSelectedPreset() {
    if (_dateRange == null) {
      _selectedPreset = null;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
    );

    final diffDays = end.difference(start).inDays;

    if (end.isAtSameMomentAs(today) || end.isAfter(today)) {
      if (diffDays == 7) {
        _selectedPreset = 0;
      } else if (diffDays == 30) {
        _selectedPreset = 1;
      } else if (diffDays == 90) {
        _selectedPreset = 2;
      } else if (start.isAtSameMomentAs(DateTime(now.year, 1, 1)) &&
          end.isAtSameMomentAs(today)) {
        _selectedPreset = 3;
      } else {
        _selectedPreset = 4; // Custom
      }
    } else {
      _selectedPreset = 4; // Custom
    }
  }

  void _applyPreset(int index) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = index;
      switch (index) {
        case 0:
          _dateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          );
          break;
        case 1:
          _dateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
          break;
        case 2:
          _dateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 90)),
            end: now,
          );
          break;
        case 3:
          _dateRange = DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
          break;
      }
    });
    widget.onChanged(_dateRange);
    HapticService.selection();
  }

  Future<void> _openDatePicker(BuildContext context) async {
    HapticService.light();
    final primary = AppTheme.primaryColor(context);
    final surface = AppTheme.surfaceColor(context);
    final bg = AppTheme.backgroundColor(context);
    final textColor = AppTheme.textColor(context);
    final textLight = AppTheme.textLightColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: primary,
                    onPrimary: Colors.white,
                    secondary: primary,
                    onSecondary: Colors.white,
                    surface: surface,
                    onSurface: textColor,
                    primaryContainer: primary.withValues(alpha: 0.15),
                    onPrimaryContainer: textColor,
                    secondaryContainer: primary.withValues(alpha: 0.15),
                    onSecondaryContainer: textColor,
                    surfaceContainerHigh: bg,
                  )
                : ColorScheme.light(
                    primary: primary,
                    onPrimary: Colors.white,
                    secondary: primary,
                    onSecondary: Colors.white,
                    surface: surface,
                    onSurface: textColor,
                    primaryContainer: primary.withValues(alpha: 0.12),
                    onPrimaryContainer: textColor,
                    secondaryContainer: primary.withValues(alpha: 0.12),
                    onSecondaryContainer: textColor,
                    surfaceContainerHigh: bg,
                  ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: bg,
              headerBackgroundColor: surface,
              headerForegroundColor: textColor,
              surfaceTintColor: Colors.transparent,
              dayForegroundColor: WidgetStatePropertyAll(textColor),
              yearForegroundColor: WidgetStatePropertyAll(textColor),
              rangePickerHeaderForegroundColor: textColor,
              rangePickerBackgroundColor: bg,
              rangePickerSurfaceTintColor: Colors.transparent,
              rangeSelectionBackgroundColor: primary.withValues(alpha: 0.15),
              rangePickerHeaderBackgroundColor: surface,
              dayOverlayColor: WidgetStatePropertyAll(
                primary.withValues(alpha: 0.1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            scaffoldBackgroundColor: bg,
            appBarTheme: AppBarTheme(
              backgroundColor: surface,
              foregroundColor: textColor,
              elevation: 0,
              iconTheme: IconThemeData(color: textLight),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _selectedPreset = 4;
      });
      widget.onChanged(_dateRange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDateSelector(context),
        const Gap(12),
        _buildDatePresets(context),
      ],
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final hasRange = _dateRange != null;
    final label = hasRange
        ? '${DateFormat('MMM d').format(_dateRange!.start)} — ${DateFormat('MMM d, yyyy').format(_dateRange!.end)}'
        : 'Select Date Range';

    return PressableScale(
      onTap: () => _openDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primaryColor(context),
                size: 18,
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time Period',
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    label,
                    style: TextStyle(
                      color: hasRange
                          ? AppTheme.textColor(context)
                          : AppTheme.textLightColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (hasRange) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_dateRange!.duration.inDays}d',
                  style: TextStyle(
                    color: AppTheme.primaryColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.showClearButton) ...[
                const Gap(8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _dateRange = null;
                      _selectedPreset = null;
                    });
                    widget.onChanged(null);
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: AppTheme.textLightColor(context),
                    size: 20,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePresets(BuildContext context) {
    final presets = ['7d', '30d', '90d', 'Year', 'Custom'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(presets.length, (index) {
          final isSelected = _selectedPreset == index;
          return Padding(
            padding: EdgeInsets.only(right: index < presets.length - 1 ? 8 : 0),
            child: PressableScale(
              enableHaptic: false,
              onTap: () {
                if (index == 4) {
                  _openDatePicker(context);
                } else {
                  _applyPreset(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor(context)
                      : AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(
                          color: AppTheme.dividerColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  presets[index],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textLightColor(context),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
