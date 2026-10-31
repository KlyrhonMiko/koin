import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/icon_utils.dart';

/// Consolidated, deep selection tile widget for form inputs (Category, Account, Frequency, etc.).
/// Encapsulates icon rendering, logo fallbacks, haptics, keyboard unfocusing, and styling.
class SelectionTile extends StatelessWidget {
  final IconData fallbackIcon;
  final String label;
  final String? selectedName;
  final Color? selectedColor;
  final int? selectedIconCodePoint;
  final String? selectedLogoAsset;
  final String placeholder;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? selectedNameDetail;
  final bool asCard;
  final double minHeight;
  final int? selectedNameMaxLines;
  final FocusNode? focusNode;
  final String? errorText;

  const SelectionTile({
    super.key,
    required this.fallbackIcon,
    required this.label,
    required this.selectedName,
    required this.selectedColor,
    required this.selectedIconCodePoint,
    this.selectedLogoAsset,
    required this.placeholder,
    required this.onTap,
    this.trailing,
    this.selectedNameDetail,
    this.asCard = true,
    this.minHeight = 0,
    this.selectedNameMaxLines = 1,
    this.focusNode,
    this.errorText,
  });

  bool get hasSelection =>
      selectedName != null &&
      selectedColor != null &&
      selectedIconCodePoint != null;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          focusNode: focusNode,
          onTap: onTap == null
              ? null
              : () async {
                  HapticService.light();
                  final keyboardVisible =
                      View.of(context).viewInsets.bottom > 0;
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (keyboardVisible) {
                    await Future.delayed(const Duration(milliseconds: 150));
                  }
                  if (context.mounted) onTap!();
                },
          borderRadius: BorderRadius.circular(asCard ? 16 : 18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: selectedNameDetail != null ? 8 : (asCard ? 14 : 12),
            ),
            child: Row(
              children: [
                _buildLeadingIcon(context),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: asCard
                              ? KoinTypography.small
                              : KoinTypography.overline,
                          fontWeight: KoinTypography.supportingWeight,
                          color: AppTheme.fieldHintColor(
                            context,
                            lightOpacity: asCard ? 0.7 : 0.65,
                          ),
                          letterSpacing: asCard ? null : 0.3,
                          height: selectedNameDetail != null ? 1.2 : null,
                        ),
                      ),
                      Gap(selectedNameDetail != null ? 0 : 2),
                      Text(
                        selectedName ?? placeholder,
                        style: TextStyle(
                          fontSize: asCard
                              ? KoinTypography.itemTitle
                              : KoinTypography.body,
                          fontWeight: hasSelection
                              ? KoinTypography.titleWeight
                              : KoinTypography.supportingWeight,
                          height: selectedNameDetail != null ? 1.25 : null,
                          color: hasSelection
                              ? AppTheme.textColor(context)
                              : AppTheme.fieldHintColor(
                                  context,
                                  lightOpacity: 0.5,
                                ),
                        ),
                        maxLines: selectedNameMaxLines,
                        overflow: selectedNameMaxLines == null
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                      if (selectedNameDetail != null) ...[
                        Text(
                          selectedNameDetail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: KoinTypography.small,
                            fontWeight: KoinTypography.supportingWeight,
                            height: 1.2,
                            color: AppTheme.textLightColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
                Icon(
                  KoinIcons.caretRight,
                  color: AppTheme.textLightColor(context)
                      .withValues(alpha: 0.4),
                  size: asCard ? 20 : 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (errorText != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                errorText!,
                style: TextStyle(
                  color: AppTheme.errorContentColor(context),
                  fontSize: KoinTypography.small,
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (asCard) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(KoinShape.field),
          border: Border.all(color: AppTheme.fieldBorderColor(context)),
          boxShadow: [
            AppTheme.boxShadow(
              context,
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildLeadingIcon(BuildContext context) {
    final size = asCard ? 44.0 : 36.0;
    final iconSize = asCard ? 22.0 : 17.0;
    final radius = asCard ? 12.0 : 10.0;

    if (hasSelection &&
        selectedLogoAsset != null &&
        selectedLogoAsset!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          selectedLogoAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _buildFallbackContainer(context, size, iconSize, radius),
        ),
      );
    }

    return _buildFallbackContainer(context, size, iconSize, radius);
  }

  Widget _buildFallbackContainer(
    BuildContext context,
    double size,
    double iconSize,
    double radius,
  ) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasSelection
            ? selectedColor!.withValues(
                alpha: AppTheme.hasEditorAppearance(context)
                    ? 0.08
                    : (asCard ? 0.15 : 0.12),
              )
            : AppTheme.surfaceLightColor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        hasSelection ? IconUtils.getIcon(selectedIconCodePoint!) : fallbackIcon,
        color: hasSelection ? selectedColor! : AppTheme.textLightColor(context),
        size: iconSize,
      ),
    );
  }
}
