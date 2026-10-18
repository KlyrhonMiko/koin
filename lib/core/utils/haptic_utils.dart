import 'dart:async';

import 'package:flutter/services.dart';

enum HapticLevel { light, medium, heavy, selection, success, error }

/// Centralized service for haptic feedback across the application.
/// Provides different levels of feedback for various user interactions.
class HapticService {
  static bool enabled = true;
  static bool _ordinaryFeedbackSent = false;
  static Future<void> _ordinary(Future<void> Function() send) {
    if (!enabled || _ordinaryFeedbackSent) return Future.value();
    _ordinaryFeedbackSent = true;
    scheduleMicrotask(() => _ordinaryFeedbackSent = false);
    return send();
  }

  /// Very subtle feedback for minor interactions like selecting an icon or color.
  static Future<void> light() async {
    await _ordinary(HapticFeedback.lightImpact);
  }

  /// Standard feedback for button presses, toggles, and general clicks.
  static Future<void> medium() async {
    await _ordinary(HapticFeedback.mediumImpact);
  }

  /// Stronger feedback for significant actions like deletions or "Save" buttons.
  static Future<void> heavy() async {
    await _ordinary(HapticFeedback.heavyImpact);
  }

  /// Specific feedback for selection changes (e.g., tab switching).
  static Future<void> selection() async {
    await _ordinary(HapticFeedback.selectionClick);
  }

  /// Feedback for successful completion of an action.
  static Future<void> success() async {
    if (!enabled) return;
    // Distinct from light tap acknowledgement; only after a committed write.
    await HapticFeedback.mediumImpact();
  }

  /// Feedback for failed actions, errors, or warnings.
  static Future<void> error() async {
    if (!enabled) return;
    // A bounded impact instead of the platform's general-purpose vibration.
    await HapticFeedback.heavyImpact();
  }
}
