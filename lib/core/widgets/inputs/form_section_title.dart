import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';

/// Consolidated section header title for form inputs, bottom sheets, and cards.
/// Provides standardized typography, uppercase subhead styling, and optional icon/trailing widgets.
class FormSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final bool uppercase;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;

  const FormSectionTitle({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.padding,
    this.uppercase = false,
    this.fontSize,
    this.fontWeight,
    this.color,
  });

  /// Uppercase subtle section title used in entity forms (11pt bold letter-spaced)
  const FormSectionTitle.subhead({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.padding,
    this.fontSize = KoinTypography.overline,
    this.fontWeight = KoinTypography.titleWeight,
    this.color,
  }) : uppercase = true;

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = uppercase ? title.toUpperCase() : title;

    TextStyle textStyle;
    if (uppercase) {
      textStyle = TextStyle(
        fontSize: fontSize ?? KoinTypography.overline,
        fontWeight: fontWeight ?? KoinTypography.titleWeight,
        color: color ?? AppTheme.textLightColor(context),
        letterSpacing: KoinTypography.overlineTracking,
      );
    } else if (icon != null) {
      textStyle = TextStyle(
        fontSize: fontSize ?? KoinTypography.compact,
        fontWeight: fontWeight ?? KoinTypography.titleWeight,
        color: color ?? AppTheme.textColor(context),
      );
    } else {
      textStyle = TextStyle(
        fontSize: fontSize ?? KoinTypography.sectionTitle,
        fontWeight: fontWeight ?? KoinTypography.headingWeight,
        color: color ?? AppTheme.textColor(context),
        letterSpacing: KoinTypography.headingTracking,
      );
    }

    Widget child;
    if (icon != null) {
      child = Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor(context)),
          const Gap(8),
          Text(effectiveTitle, style: textStyle),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      );
    } else if (trailing != null) {
      child = Row(
        children: [
          Text(effectiveTitle, style: textStyle),
          const Spacer(),
          trailing!,
        ],
      );
    } else {
      child = Text(effectiveTitle, style: textStyle);
    }

    if (padding != null) {
      return Padding(padding: padding!, child: child);
    }
    return child;
  }
}
