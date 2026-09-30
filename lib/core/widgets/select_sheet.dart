import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:koin/core/widgets/koin_bottom_sheet_handle.dart';

class SelectSheetItem extends StatelessWidget {
  const SelectSheetItem({
    super.key,
    required this.name,
    required this.accentColor,
    required this.iconCodePoint,
    required this.selected,
    required this.onTap,
    this.balance,
    this.isPrivate = false,
    this.currencySymbol,
    this.onPrivateToggle,
  });

  final String name;
  final Color accentColor;
  final int iconCodePoint;
  final bool selected;
  final VoidCallback onTap;
  final double? balance;
  final bool isPrivate;
  final String? currencySymbol;
  final VoidCallback? onPrivateToggle;

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService.selection();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
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
                    BoxShadow(
                      color: primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // ── Icon ──
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
                    IconUtils.getIcon(iconCodePoint),
                    color: accentColor,
                    size: 22,
                  ),
                ),
              ),
              const Gap(14),

              // ── Name + Balance ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
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
                                color: AppTheme.textLightColor(
                                  context,
                                ).withValues(alpha: 0.45),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 2,
                              ),
                            )
                          : Text(
                              NumberFormat.currency(
                                symbol: currencySymbol ?? '',
                              ).format(balance),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
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
                      isPrivate
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: isPrivate
                          ? AppTheme.textLightColor(
                              context,
                            ).withValues(alpha: 0.35)
                          : AppTheme.primaryColor(
                              context,
                            ).withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],

              // ── Selection Indicator ──
              const Gap(8),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 24)
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
                          color: AppTheme.textLightColor(
                            context,
                          ).withValues(alpha: 0.2),
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
    );
  }
}

Future<T?> showSelectSheet<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required int itemCount,
  required Widget Function(BuildContext context, int index) itemBuilder,
  String? emptyMessage,
}) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(sheetContext).padding.top + 12,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(sheetContext),
                border: Border.all(color: AppTheme.dividerColor(sheetContext)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KoinBottomSheetHandle(
                    padding: EdgeInsets.only(top: 10),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppTheme.textColor(sheetContext),
                          ),
                        ),
                        const Gap(4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                            color: AppTheme.textLightColor(sheetContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (emptyMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 24,
                      ),
                      child: Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textLightColor(sheetContext),
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                      itemCount: itemCount,
                      separatorBuilder: (context, index) => const Gap(10),
                      itemBuilder: itemBuilder,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
