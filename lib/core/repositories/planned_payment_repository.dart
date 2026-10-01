import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving planned payments / cashflow schedules.
abstract class PlannedPaymentRepository {
  Future<List<PlannedPayment>> getPlannedPayments();
  Future<PlannedPayment> insertPlannedPayment(PlannedPayment payment);
  Future<void> updatePlannedPayment(PlannedPayment payment);
  Future<void> deletePlannedPayment(String id);
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments();
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqlitePlannedPaymentAdapter implements PlannedPaymentRepository {
  final DatabaseHelper _dbHelper;

  SqlitePlannedPaymentAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<PlannedPayment>> getPlannedPayments() =>
      _dbHelper.getPlannedPayments();

  @override
  Future<PlannedPayment> insertPlannedPayment(PlannedPayment payment) =>
      _dbHelper.insertPlannedPayment(payment);

  @override
  Future<void> updatePlannedPayment(PlannedPayment payment) async {
    await _dbHelper.updatePlannedPayment(payment);
  }

  @override
  Future<void> deletePlannedPayment(String id) async {
    await _dbHelper.deletePlannedPayment(id);
  }

  @override
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments() =>
      _dbHelper.getUnexcludedPlannedPayments();
}

/// In-Memory Test Adapter: provides deterministic planned payment persistence for testing.
class InMemoryPlannedPaymentAdapter implements PlannedPaymentRepository {
  final Map<String, PlannedPayment> _payments = {};

  InMemoryPlannedPaymentAdapter({List<PlannedPayment> initial = const []}) {
    for (final p in initial) {
      _payments[p.id] = p;
    }
  }

  @override
  Future<List<PlannedPayment>> getPlannedPayments() async {
    final list = _payments.values.toList();
    list.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return list;
  }

  @override
  Future<PlannedPayment> insertPlannedPayment(PlannedPayment payment) async {
    _payments[payment.id] = payment;
    return payment;
  }

  @override
  Future<void> updatePlannedPayment(PlannedPayment payment) async {
    _payments[payment.id] = payment;
  }

  @override
  Future<void> deletePlannedPayment(String id) async {
    _payments.remove(id);
  }

  @override
  Future<List<PlannedPayment>> getUnexcludedPlannedPayments() async {
    return _payments.values.toList();
  }
}

/// Riverpod provider exposing the PlannedPaymentRepository seam.
final plannedPaymentRepositoryProvider = Provider<PlannedPaymentRepository>((ref) {
  return SqlitePlannedPaymentAdapter();
});
