import 'package:flutter/material.dart';

/// The type scale and spacing used by the Goals screens.
/// Keep compact supporting text and let headings and amounts carry emphasis.
abstract final class KoinTypography {
  /// Bundled as one family so inherited styles select the real requested weight.
  static const fontFamily = 'Outfit';

  static const screenTitle = 24.0;
  static const formTitle = 28.0;
  static const sectionTitle = 18.0;
  static const summaryAmount = 38.0;
  static const inputAmount = 48.0;
  static const itemAmount = 17.0;
  static const cardAmount = 20.0;
  static const itemTitle = 16.0;
  static const body = 15.0;
  static const compact = 14.0;
  static const caption = 13.0;
  static const small = 12.0;
  static const overline = 11.0;

  static const headingWeight = FontWeight.w700;
  static const titleWeight = FontWeight.w600;
  static const labelWeight = FontWeight.w500;
  static const supportingWeight = FontWeight.w400;
  static const headingTracking = -0.5;
  static const amountTracking = -1.0;
  static const itemTracking = -0.2;
  static const overlineTracking = 1.2;
  static const amountHeight = 1.1;
  static const inputTracking = -2.0;
  static const chartLabel = overline;
  static const badgeLabel = overline;

  static const choiceLabelStyle = TextStyle(
    fontFamily: fontFamily,
    fontSize: compact,
    fontWeight: labelWeight,
    letterSpacing: 0,
    height: 1.2,
  );
  static const entityNameStyle = TextStyle(
    fontSize: formTitle,
    fontWeight: FontWeight.w800,
    letterSpacing: headingTracking,
  );
  static const inputAmountStyle = TextStyle(
    fontSize: inputAmount,
    fontWeight: headingWeight,
    letterSpacing: inputTracking,
    height: amountHeight,
  );
  static const summaryLabelStyle = TextStyle(
    color: Color(0xCCFFFFFF),
    fontSize: caption,
    fontWeight: labelWeight,
    letterSpacing: 0.5,
  );
  static const summaryAmountStyle = TextStyle(
    color: Colors.white,
    fontSize: summaryAmount,
    fontWeight: headingWeight,
    letterSpacing: amountTracking,
    height: amountHeight,
  );
}

/// Shapes describe component roles rather than individual screens.
abstract final class KoinShape {
  static const field = 16.0;
  static const sheet = 28.0;
  static const summary = 28.0;
}

abstract final class KoinSpacing {
  static const screenInset = 20.0;
  static const sectionGap = 20.0;
  static const sectionTitleGap = 8.0;
  static const cardGap = 12.0;
  static const labelGap = 4.0;
  static const summaryInset = 28.0;

  /// Scaffold supplies the rendered navigation height when its body extends.
  static double bottomClearance(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 12;
}
