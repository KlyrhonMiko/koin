import 'package:flutter/material.dart';
import 'select_sheet.dart';

export 'select_sheet.dart';

/// Backward-compatible adapter for PremiumSelectionSheet delegating to unified select_sheet.
class PremiumSelectionSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    Color? indicatorColor,
    String? emptyMessage,
  }) {
    return showSelectSheet<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      emptyMessage: emptyMessage,
    );
  }
}

/// Unified typedef mapping PremiumSheetItem to SelectSheetItem
typedef PremiumSheetItem = SelectSheetItem;
