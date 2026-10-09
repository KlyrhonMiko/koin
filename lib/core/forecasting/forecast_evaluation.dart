import 'dart:math' as math;

enum VariableForecastMethod { movingAverage, historicalMean, lastMonth }

/// Rolling monthly evaluation. Each prediction uses only preceding samples.
/// At least three training months and three held-out months are required to
/// choose a method; short histories retain the existing moving-average baseline.
class ForecastEvaluation {
  final VariableForecastMethod method;
  final double monthlyEstimate;
  final double? meanAbsoluteError;
  final int evaluatedMonths;

  const ForecastEvaluation({
    required this.method,
    required this.monthlyEstimate,
    required this.meanAbsoluteError,
    required this.evaluatedMonths,
  });

  static double estimate(List<double> data, VariableForecastMethod method) {
    if (data.isEmpty) return 0;
    switch (method) {
      case VariableForecastMethod.lastMonth:
        return data.last;
      case VariableForecastMethod.historicalMean:
        return data.reduce((a, b) => a + b) / data.length;
      case VariableForecastMethod.movingAverage:
        return data
            .skip(1)
            .fold(data.first, (ema, value) => value * 0.5 + ema * 0.5);
    }
  }

  static ForecastEvaluation select(List<double> data) {
    var method = VariableForecastMethod.movingAverage;
    double? bestError;
    final count = math.max(0, data.length - 3);
    if (count >= 3) {
      for (final candidate in VariableForecastMethod.values) {
        var absoluteError = 0.0;
        for (var i = 3; i < data.length; i++) {
          absoluteError += (data[i] - estimate(data.sublist(0, i), candidate))
              .abs();
        }
        final error = absoluteError / count;
        if (bestError == null || error < bestError) {
          bestError = error;
          method = candidate;
        }
      }
    }
    return ForecastEvaluation(
      method: method,
      monthlyEstimate: estimate(data, method),
      meanAbsoluteError: bestError,
      evaluatedMonths: count >= 3 ? count : 0,
    );
  }

  /// Signed net errors from adaptive forecasts made at historical cutoffs.
  /// Selection itself is repeated on each prefix to avoid leaking future data.
  static List<double> netErrors(List<double> inflows, List<double> outflows) {
    if (inflows.length != outflows.length) return const [];
    return [
      for (var i = 3; i < inflows.length; i++)
        inflows[i] -
            outflows[i] -
            (select(inflows.sublist(0, i)).monthlyEstimate -
                select(outflows.sublist(0, i)).monthlyEstimate),
    ];
  }

  static double quantile(List<double> values, double fraction) {
    final sorted = [...values]..sort();
    final index = (sorted.length - 1) * fraction;
    final lower = index.floor();
    final upper = index.ceil();
    return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - lower);
  }
}
