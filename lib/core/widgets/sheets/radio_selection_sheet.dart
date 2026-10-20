import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// A compact, typed choice list. Only a tap returns a value; dismissal is null.
Future<T?> showRadioSelectionSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required T selected,
  required String Function(T) label,
  Color? accentColor,
  Key? contentKey,
  Key Function(T)? itemKey,
  bool showCheckmark = false,
  bool compact = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppTheme.surfaceColor(context),
  builder: (sheetContext) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              key: contentKey,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 8 : 12),
                  child: Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          fontSize: compact ? KoinTypography.sectionTitle : 22,
                          fontWeight: compact
                              ? KoinTypography.titleWeight
                              : KoinTypography.headingWeight,
                        ),
                  ),
                ),
                for (final option in options)
                  Semantics(
                    selected: option == selected,
                    inMutuallyExclusiveGroup: true,
                    child: ListTile(
                      key: itemKey?.call(option),
                      selected: option == selected,
                      selectedColor: AppTheme.textColor(sheetContext),
                      selectedTileColor: showCheckmark && !compact
                          ? AppTheme.primaryColor(sheetContext)
                                .withValues(alpha: 0.08)
                          : null,
                      shape: showCheckmark
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            )
                          : null,
                      minTileHeight: compact ? 48 : 64,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label(option),
                              style: Theme.of(sheetContext).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontSize: compact
                                        ? KoinTypography.body
                                        : null,
                                    fontWeight: option == selected
                                        ? compact
                                              ? KoinTypography.titleWeight
                                              : FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ),
                          if (compact && showCheckmark && option == selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                Icons.check_rounded,
                                size: 20,
                                color:
                                    accentColor ??
                                    AppTheme.primaryColor(sheetContext),
                              ),
                            ),
                        ],
                      ),
                      trailing: compact && showCheckmark
                          ? null
                          : showCheckmark
                          ? option == selected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: AppTheme.primaryColor(sheetContext),
                                  )
                                : null
                          : Icon(
                              option == selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: option == selected
                                  ? accentColor ??
                                        AppTheme.primaryColor(sheetContext)
                                  : AppTheme.textLightColor(sheetContext),
                              size: 24,
                            ),
                      onTap: () {
                        HapticService.selection();
                        Navigator.pop(sheetContext, option);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
