import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';

class BillMonthSelector extends StatelessWidget {
  final String label;
  final DateTime date;
  final Color primaryColor;
  final ValueChanged<DateTime> onMonthSelected;

  const BillMonthSelector({
    super.key,
    required this.label,
    required this.date,
    required this.primaryColor,
    required this.onMonthSelected,
  });

  @override
  Widget build(BuildContext context) => DateSelectorTile(
    label: label,
    date: date,
    dateFormat: DateFormat.yMMMM(),
    primaryColor: primaryColor,
    onDateSelected: onMonthSelected,
    onTap: () async {
      final month = await showDialog<DateTime>(
        context: context,
        builder: (_) =>
            _MonthDialog(title: label, date: date, primaryColor: primaryColor),
      );
      if (context.mounted && month != null) onMonthSelected(month);
    },
  );
}

class BillingDaySelector extends StatelessWidget {
  final int day;
  final Color primaryColor;
  final ValueChanged<int> onDaySelected;

  const BillingDaySelector({
    super.key,
    required this.day,
    required this.primaryColor,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) => DateSelectorTile(
    label: 'Monthly due day',
    date: DateTime(2000, 1, day),
    dateFormat: DateFormat("'${_ordinal(day)} of every month'"),
    primaryColor: primaryColor,
    onTap: () async {
      var selected = day;
      final result = await showDialog<int>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) => _ScheduleDialog(
            title: 'Monthly due day',
            primaryColor: primaryColor,
            onDone: () => Navigator.pop(context, selected),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelectionGrid(
                  count: 31,
                  columns: 7,
                  circular: true,
                  selected: selected - 1,
                  primaryColor: primaryColor,
                  label: (index) => '${index + 1}',
                  semanticLabel: (index) =>
                      '${_ordinal(index + 1)} of every month',
                  onSelected: (index) => setState(() => selected = index + 1),
                ),
                const SizedBox(height: 16),
                Text(
                  'Uses the last day in shorter months.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
      if (context.mounted && result != null) onDaySelected(result);
    },
  );
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}

class _MonthDialog extends StatefulWidget {
  final String title;
  final DateTime date;
  final Color primaryColor;
  const _MonthDialog({
    required this.title,
    required this.date,
    required this.primaryColor,
  });
  @override
  State<_MonthDialog> createState() => _MonthDialogState();
}

class _MonthDialogState extends State<_MonthDialog> {
  late var _selected = DateTime(widget.date.year, widget.date.month);
  late var _year = widget.date.year;
  var _choosingYear = false;

  @override
  Widget build(BuildContext context) => _ScheduleDialog(
    title: widget.title,
    primaryColor: widget.primaryColor,
    onDone: () => Navigator.pop(context, _selected),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous year',
              onPressed: _year > 2000 && !_choosingYear
                  ? () => setState(() => _year--)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => setState(() => _choosingYear = !_choosingYear),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textColor(context),
                  minimumSize: const Size(48, 48),
                ),
                label: Text('$_year'),
                icon: Icon(
                  _choosingYear
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                iconAlignment: IconAlignment.end,
              ),
            ),
            IconButton(
              tooltip: 'Next year',
              onPressed: _year < 2100 && !_choosingYear
                  ? () => setState(() => _year++)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_choosingYear)
          SizedBox(
            height: 280,
            child: YearPicker(
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              selectedDate: DateTime(_year, _selected.month),
              onChanged: (date) => setState(() {
                _year = date.year;
                _choosingYear = false;
              }),
            ),
          )
        else
          _SelectionGrid(
            count: 12,
            columns: 3,
            selected: _selected.year == _year ? _selected.month - 1 : -1,
            primaryColor: widget.primaryColor,
            label: (index) =>
                DateFormat.MMM().format(DateTime(_year, index + 1)),
            semanticLabel: (index) =>
                DateFormat.yMMMM().format(DateTime(_year, index + 1)),
            onSelected: (index) =>
                setState(() => _selected = DateTime(_year, index + 1)),
          ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            DateFormat.yMMMM().format(_selected),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

class _ScheduleDialog extends StatelessWidget {
  final String title;
  final Color primaryColor;
  final VoidCallback onDone;
  final Widget child;
  const _ScheduleDialog({
    required this.title,
    required this.primaryColor,
    required this.onDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = primaryColor.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: scheme.copyWith(
          primary: primaryColor,
          onPrimary: foreground,
        ),
      ),
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        actionsPadding: const EdgeInsets.all(16),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        title: Text(title),
        content: SizedBox(width: 360, child: child),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: foreground,
              minimumSize: const Size(80, 48),
            ),
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SelectionGrid extends StatelessWidget {
  final int count;
  final int columns;
  final int selected;
  final bool circular;
  final Color primaryColor;
  final String Function(int) label;
  final String Function(int) semanticLabel;
  final ValueChanged<int> onSelected;
  const _SelectionGrid({
    required this.count,
    required this.columns,
    required this.selected,
    required this.primaryColor,
    required this.label,
    required this.semanticLabel,
    required this.onSelected,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableWidth = math.min(
      360.0,
      media.size.width -
          media.padding.horizontal -
          media.viewInsets.horizontal -
          48,
    );
    final scaledText = MediaQuery.textScalerOf(context).scale(16);
    final spacing = circular ? 0.0 : 4.0;
    final minimumWidth = math.max(48.0, scaledText * (circular ? 2 : 4));
    final columnCount = math.min(
      columns,
      math.max(
        1,
        ((availableWidth + spacing) / (minimumWidth + spacing)).floor(),
      ),
    );
    final width = (availableWidth - (columnCount - 1) * spacing) / columnCount;
    final height = math.max(48.0, scaledText + 24);
    return Wrap(
      spacing: spacing,
      runSpacing: 4,
      children: [
        for (var index = 0; index < count; index++)
          SizedBox(
            width: width,
            height: circular ? math.max(width, height) : height,
            child: Semantics(
              selected: index == selected,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  foregroundColor: index == selected
                      ? (primaryColor.computeLuminance() > 0.179
                            ? Colors.black
                            : Colors.white)
                      : AppTheme.textColor(context),
                  backgroundColor: index == selected ? primaryColor : null,
                  shape: circular
                      ? const CircleBorder()
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: index == selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                onPressed: () => onSelected(index),
                child: Semantics(
                  label: semanticLabel(index),
                  excludeSemantics: true,
                  child: Text(label(index)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
