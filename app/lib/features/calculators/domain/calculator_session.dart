import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'alkalinity_calculator.dart';

/// In-memory, per-tank successful KH calculations, like the web session.
/// Not persisted or reconstructed from historical dosing tasks.
final calculatorSessionProvider = Provider((ref) => CalculatorSession());

class CalculatorSession {
  final _khPlans = <String, AlkalinityPlan>{};
  AlkalinityPlan? khPlanFor(String tankId) => _khPlans[tankId];
  void rememberKh(String tankId, AlkalinityPlan plan) =>
      _khPlans[tankId] = plan;
}
