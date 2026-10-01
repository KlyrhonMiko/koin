import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for querying historical variable cashflows and unexcluded schedules for forecasting.
abstract class ForecastRepository {
  Future<List<double>> getHistoricalVariableInflows();
  Future<List<double>> getHistoricalVariableOutflows();
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments();
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteForecastAdapter implements ForecastRepository {
  final DatabaseHelper _dbHelper;

  SqliteForecastAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<double>> getHistoricalVariableInflows() =>
      _dbHelper.getHistoricalVariableInflows();

  @override
  Future<List<double>> getHistoricalVariableOutflows() =>
      _dbHelper.getHistoricalVariableOutflows();

  @override
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments() =>
      _dbHelper.getUnexcludedPlannedPayments();
}

/// In-Memory Test Adapter: provides deterministic forecasting data for testing.
class InMemoryForecastAdapter implements ForecastRepository {
  final List<double> inflows;
  final List<double> outflows;
  final List<PlannedPayment> plannedPayments;

  InMemoryForecastAdapter({
    this.inflows = const [],
    this.outflows = const [],
    this.plannedPayments = const [],
  });

  @override
  Future<List<double>> getHistoricalVariableInflows() async => List.unmodifiable(inflows);

  @override
  Future<List<double>> getHistoricalVariableOutflows() async => List.unmodifiable(outflows);

  @override
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments() async =>
      List.unmodifiable(plannedPayments);
}

/// Riverpod provider exposing the ForecastRepository seam.
final forecastRepositoryProvider = Provider<ForecastRepository>((ref) {
  return SqliteForecastAdapter();
});
