import 'dart:math' as math;

/// The last installment receives the remainder, so every payment is payable
/// in the currency and the schedule sums exactly to the recorded principal.
abstract final class InstallmentAmounts {
  static int units(double amount, int digits) =>
      (amount * math.pow(10, digits)).round();

  static double at(double total, int count, int index, {int digits = 2}) {
    final n = math.max(1, count);
    final scale = math.pow(10, digits).toInt();
    final value = units(total, digits);
    final base = value ~/ n;
    return (index == n - 1 ? value - base * (n - 1) : base) / scale;
  }
}
