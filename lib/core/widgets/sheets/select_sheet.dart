import 'package:koin/core/icons.dart';
import 'package:koin/core/utils/motion_policy.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';

import '../primitives/koin_bottom_sheet_handle.dart';

class SelectSheetItem extends StatelessWidget {
  const SelectSheetItem({
    super.key,
    required this.name,
    required this.accentColor,
    this.iconCodePoint,
    required this.selected,
    required this.onTap,
    this.balance,
    this.isPrivate = false,
    this.currencySymbol,
    this.onPrivateToggle,
  });

  final String name;
  final Color accentColor;
  final int? iconCodePoint;
  final bool selected;
  final VoidCallback onTap;
  final double? balance;
  final bool isPrivate;
  final String? currencySymbol;
  final VoidCallback? onPrivateToggle;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticService.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: KoinMotion.duration(
              context,
              const Duration(milliseconds: 200),
            ),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.4)
                    : AppTheme.dividerColor(context).withValues(alpha: 0.3),
                width: selected ? 1.5 : 1,
              ),
              color: selected
                  ? primary.withValues(alpha: 0.08)
                  : AppTheme.surfaceColor(context),
              boxShadow: selected
                  ? [
                      AppTheme.boxShadow(
                        context,
                        color: primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      AppTheme.boxShadow(
                        context,
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                if (iconCodePoint != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.15),
                          accentColor.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Icon(
                        IconUtils.getIcon(iconCodePoint!),
                        color: accentColor,
                        size: 22,
                      ),
                    ),
                  ),
                  const Gap(14),
                ],

                // ── Name + Balance ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: KoinTypography.body,
                          fontWeight: KoinTypography.labelWeight,
                          letterSpacing: KoinTypography.itemTracking,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (balance != null) ...[
                        const Gap(3),
                        isPrivate
                            ? Text(
                                '••••••',
                                style: TextStyle(
                                  color: AppTheme.textLightColor(context)
                                      .withValues(alpha: 0.45),
                                  fontWeight: KoinTypography.headingWeight,
                                  fontSize: KoinTypography.caption,
                                  letterSpacing: 2,
                                ),
                              )
                            : Text(
                                NumberFormat.currency(
                                  symbol: currencySymbol ?? '',
                                ).format(balance),
                                style: TextStyle(
                                  fontSize: KoinTypography.caption,
                                  fontWeight: KoinTypography.supportingWeight,
                                  color: AppTheme.textLightColor(context),
                                ),
                              ),
                      ],
                    ],
                  ),
                ),

                // ── Privacy Toggle ──
                if (onPrivateToggle != null) ...[
                  GestureDetector(
                    onTap: () {
                      HapticService.selection();
                      onPrivateToggle!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        isPrivate ? KoinIcons.eyeSlash : KoinIcons.eye,
                        size: 18,
                        color: isPrivate
                            ? AppTheme.textLightColor(context)
                                  .withValues(alpha: 0.35)
                            : AppTheme.primaryColor(context)
                                  .withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],

                // ── Selection Indicator ──
                const Gap(8),
                if (selected)
                  Icon(KoinIcons.checkCircle, color: primary, size: 24)
                else
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.textLightColor(context)
                                .withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared live option list; callers supply loading/error and domain actions.
class SelectSheetOptions extends StatelessWidget {
  const SelectSheetOptions({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.labelForIndex,
    this.query = '',
    this.emptyMessage = 'No options available',
    this.emptyAction,
  });
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final String Function(int) labelForIndex;
  final String query;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final indices = [
      for (var i = 0; i < itemCount; i++)
        if (labelForIndex(i).toLowerCase().contains(query.trim().toLowerCase()))
          i,
    ];
    if (indices.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Text(
              query.isEmpty ? emptyMessage : 'No matching options',
              textAlign: TextAlign.center,
            ),
            if (query.isEmpty && emptyAction != null) ...[
              const SizedBox(height: 12),
              emptyAction!,
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
      itemCount: indices.length,
      separatorBuilder: (_, index) => const Gap(10),
      itemBuilder: (context, index) => itemBuilder(context, indices[index]),
    );
  }
}

Future<T?> showSelectSheet<T>({
  required BuildContext context,
  required String title,
  String subtitle = '',
  required int itemCount,
  required Widget Function(BuildContext, int) itemBuilder,
  String? emptyMessage,
  String Function(int)? labelForIndex,
  bool searchable = false,
  Widget Function(BuildContext, String)? optionsBuilder,
}) {
  var query = '';
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KoinShape.sheet),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KoinBottomSheetHandle(padding: EdgeInsets.only(top: 10)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle.isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (searchable) ...[
                      const Gap(12),
                      TextField(
                        decoration: InputDecoration(labelText: 'Search $title'),
                        onChanged: (text) => setState(() => query = text),
                      ),
                    ],
                  ],
                ),
              ),
              Flexible(
                child:
                    optionsBuilder?.call(context, query) ??
                    SelectSheetOptions(
                      itemCount: itemCount,
                      itemBuilder: itemBuilder,
                      labelForIndex: labelForIndex ?? (i) => '',
                      query: query,
                      emptyMessage: emptyMessage ?? 'No options available',
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
