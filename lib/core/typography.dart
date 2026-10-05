import 'package:flutter/material.dart';

/// The type scale and spacing used by the Goals screens.
/// Keep compact supporting text and let headings and amounts carry emphasis.
abstract final class KoinTypography {
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

  static const headingWeight = FontWeight.w800;
  static const titleWeight = FontWeight.w700;
  static const labelWeight = FontWeight.w600;
  static const supportingWeight = FontWeight.w500;
  static const headingTracking = -0.5;
  static const amountTracking = -1.0;
  static const itemTracking = -0.2;
  static const overlineTracking = 1.2;
  static const amountHeight = 1.1;
}

abstract final class KoinSpacing {
  static const screenInset = 20.0;
  static const sectionGap = 32.0;
  static const sectionTitleGap = 16.0;
  static const cardGap = 12.0;
  static const labelGap = 4.0;
  static const summaryInset = 28.0;
}
