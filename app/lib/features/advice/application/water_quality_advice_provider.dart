import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../tanks/application/tank_providers.dart';
import '../../test_records/application/test_record_providers.dart';
import '../domain/water_quality_advice.dart';

final waterQualityAdviceProvider =
    Provider.family<AsyncValue<List<WaterQualityAdvice>>, String>((
      ref,
      tankId,
    ) {
      final parameters = ref.watch(enabledParametersProvider(tankId));
      final records = ref.watch(latestTestRecordsProvider(tankId));
      final targets = ref.watch(waterQualityTargetsProvider(tankId));

      return parameters.when(
        data: (parameterItems) => records.when(
          data: (recordItems) => targets.when(
            data: (targetItems) => AsyncValue.data(
              buildWaterQualityAdvice(
                parameters: parameterItems,
                records: recordItems,
                targets: targetItems,
              ),
            ),
            error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
            loading: () => const AsyncValue.loading(),
          ),
          error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
          loading: () => const AsyncValue.loading(),
        ),
        error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
        loading: () => const AsyncValue.loading(),
      );
    });

List<WaterQualityAdvice> buildWaterQualityAdvice({
  required List<WaterParameter> parameters,
  required List<TestRecord> records,
  required List<WaterQualityTarget> targets,
}) {
  final targetByParameter = {
    for (final target in targets) target.parameterId: target,
  };
  final latestByParameter = <String, TestRecord>{};
  for (final record in records) {
    final current = latestByParameter[record.parameterId];
    if (current == null || _isLater(record, current)) {
      latestByParameter[record.parameterId] = record;
    }
  }

  return [
    for (final parameter in parameters)
      WaterQualityAdviceEngine.evaluate(
        WaterQualityAdviceInput(
          parameterId: parameter.id,
          parameterCode: parameter.code,
          parameterName: parameter.displayName,
          latestConfirmedRecord: _confirmedMeasurement(
            latestByParameter[parameter.id],
          ),
          userTarget: _targetRange(targetByParameter[parameter.id]),
        ),
      ),
  ];
}

bool _isLater(TestRecord candidate, TestRecord current) {
  final measuredComparison = candidate.measuredAt.compareTo(current.measuredAt);
  if (measuredComparison != 0) return measuredComparison > 0;
  return candidate.updatedAt.isAfter(current.updatedAt);
}

ConfirmedMeasurement? _confirmedMeasurement(TestRecord? record) {
  if (record == null) return null;
  return ConfirmedMeasurement(
    recordId: record.id,
    minValue: record.confirmedMinValue,
    maxValue: record.confirmedMaxValue,
    unit: record.unit,
    measuredAt: record.measuredAt,
  );
}

UserTargetRange? _targetRange(WaterQualityTarget? target) {
  if (target == null || target.minValue == null || target.maxValue == null) {
    return null;
  }
  return UserTargetRange(
    minValue: target.minValue!,
    maxValue: target.maxValue!,
    unit: target.unit,
  );
}
