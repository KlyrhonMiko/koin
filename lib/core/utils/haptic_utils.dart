import 'package:flutter/services.dart';

/// Centralized service for haptic feedback across the application.
/// Provides different levels of feedback for various user interactions.
class HapticService {
  /// Very subtle feedback for minor interactions like selecting an icon or color.
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  /// Standard feedback for button presses, toggles, and general clicks.
  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  /// Stronger feedback for significant actions like deletions or "Save" buttons.
  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  /// Specific feedback for selection changes (e.g., tab switching).
  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  /// Feedback for successful completion of an action.
  static Future<void> success() async {
    // Combination of impacts to simulate success if needed, 
    // but selectionClick is often used for positive confirmation.
    await HapticFeedback.mediumImpact();
  }

  /// Feedback for failed actions, errors, or warnings.
  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }
}
