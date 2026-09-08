import 'dart:convert';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/data/backup/local_backup_service.dart';
import 'package:lanjiao_water_quality/features/calculators/data/maintenance_cycle_repository.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_cycle.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/maintenance_dosing.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source, target;
  setUp(() {
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  test(
    'old merge initializes incoming KH scopes but preserves local deliberate clear',
    () async {
      final local = TankRepository(target);
      await local.setParameterEnabled(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.khId,
        enabled: true,
      );
      await local.setTarget(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.khId,
        minValue: null,
        maxValue: null,
      );
      final incoming = TankRepository(source);
      final tankId = await incoming.createTank(name: '旧备份新增缸');
      await source
          .into(source.tankParameters)
          .insert(
            TankParametersCompanion.insert(
              tankId: tankId,
              parameterId: AppDatabase.khId,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      final old =
          jsonDecode(await LocalBackupService(source).exportJson())
              as Map<String, dynamic>;
      old['formatVersion'] = 10;
      old.remove('maintenanceCycles');
      old['appPreferences'][0].remove('khTargetDefaultsApplied');
      final backup = jsonEncode(old);
      await LocalBackupService(target).restoreMerge(backup);
      await LocalBackupService(target).restoreMerge(backup);
      final values = await target.select(target.waterQualityTargets).get();
      expect(values, hasLength(2));
      final preserved = values.singleWhere(
        (v) => v.tankId == AppDatabase.defaultTankId,
      );
      final initialized = values.singleWhere((v) => v.tankId == tankId);
      expect([preserved.minValue, preserved.maxValue], [null, null]);
      expect([initialized.minValue, initialized.maxValue], [7, 9]);
    },
  );

  test(
    'closed cycle chain remaps children after a conflicting parent',
    () async {
      final now = DateTime(2026, 9, 8);
      final cycles = MaintenanceCycleRepository(source, now: () => now);
      const input = MaintenanceDosingInput(
        dailyChange: .02,
        flow: 100,
        unit: PumpFlowUnit.mlPerMinute,
      );
      final a = prepareMaintenanceCycle(
        input: input,
        chemical: DosingChemical.po4,
        tankId: AppDatabase.defaultTankId,
        startDate: '2026-09-05',
        id: 'cycle-a',
      );
      await cycles.confirm(a);
      await cycles.delay(a.id, 2);
      final b = prepareMaintenanceCycle(
        input: input,
        chemical: DosingChemical.po4,
        tankId: AppDatabase.defaultTankId,
        startDate: '2026-09-07',
        id: 'cycle-b',
        previous: a,
      );
      await cycles.confirm(b);
      await (source.update(
        source.maintenanceCycles,
      )..where((r) => r.id.equals(b.id))).write(
        const MaintenanceCyclesCompanion(closedOnDate: Value('2026-09-08')),
      );
      final backup = await LocalBackupService(source).exportJson();
      await LocalBackupService(target).restoreReplace(backup);
      await (target.update(
        target.maintenanceCycles,
      )..where((r) => r.id.equals(a.id))).write(
        const MaintenanceCyclesCompanion(
          refillDeferredUntil: Value('2026-09-15'),
        ),
      );
      await LocalBackupService(target).restoreMerge(backup);
      final result = await target.select(target.maintenanceCycles).get();
      expect(result, hasLength(4));
      final newParent = result.singleWhere(
        (r) => r.previousCycleId == null && r.id != a.id,
      );
      final newChild = result.singleWhere(
        (r) => r.previousCycleId == newParent.id,
      );
      expect(newChild.id, isNot(b.id));
      expect(result.singleWhere((r) => r.id == b.id).previousCycleId, a.id);
      await LocalBackupService(
        target,
      ).validateJson(await LocalBackupService(target).exportJson());
    },
  );

  test(
    'device notification IDs do not duplicate doses; changed finite plan merge is atomic',
    () async {
      await target.select(target.tanks).get();
      for (var day = 1; day <= 2; day++) {
        final due = DateTime.utc(2026, 9, day);
        await target
            .into(target.maintenanceTasks)
            .insert(
              MaintenanceTasksCompanion.insert(
                id: 'dose-$day',
                tankId: AppDatabase.defaultTankId,
                title: '加药 $day',
                intervalAmount: 1,
                intervalUnit: 'day',
                dueAt: due,
                isOneOff: const Value(true),
                source: const Value('lanthanum-plan'),
                planId: const Value('plan'),
                planDayIndex: Value(day),
                planTotalDays: const Value(2),
                notificationId: Value(900 + day),
                createdAt: due,
                updatedAt: due,
              ),
            );
      }
      final backup = await LocalBackupService(target).exportJson();
      await LocalBackupService(target).restoreMerge(backup);
      expect(await target.select(target.maintenanceTasks).get(), hasLength(2));
      await (target.update(target.maintenanceTasks)
            ..where((t) => t.id.equals('dose-1')))
          .write(const MaintenanceTasksCompanion(status: Value('completed')));
      await expectLater(
        LocalBackupService(target).restoreMerge(backup),
        throwsFormatException,
      );
      final tasks = await target.select(target.maintenanceTasks).get();
      expect(tasks, hasLength(2));
      expect(tasks.singleWhere((t) => t.id == 'dose-1').status, 'completed');
    },
  );

  test(
    'closed child conflict cannot attach a second child to a reused parent',
    () async {
      final backup = await _closedChain(source);
      await LocalBackupService(target).restoreReplace(backup);
      await (target.update(
        target.maintenanceCycles,
      )..where((row) => row.id.equals('child'))).write(
        MaintenanceCyclesCompanion(updatedAt: Value(DateTime.utc(2026, 9, 9))),
      );
      await expectLater(
        LocalBackupService(target).restoreMerge(backup),
        throwsFormatException,
      );
      final rows = await target.select(target.maintenanceCycles).get();
      expect(rows, hasLength(2));
      expect(
        rows.where((row) => row.previousCycleId == 'parent'),
        hasLength(1),
      );
      expect(
        rows
            .singleWhere((row) => row.id == 'child')
            .updatedAt
            .isAtSameMomentAs(DateTime.utc(2026, 9, 9)),
        isTrue,
      );
      await LocalBackupService(
        target,
      ).validateJson(await LocalBackupService(target).exportJson());
    },
  );

  test(
    'prepared cycle merge rejects a changed parent or newly attached child atomically',
    () async {
      final backup = await _closedChain(source);
      final service = LocalBackupService(target);
      await service.restoreReplace(backup);
      await (target.delete(
        target.maintenanceCycles,
      )..where((row) => row.id.equals('child'))).go();
      final parentChangedPlan = await service.prepareMerge(backup);
      await (target.update(
        target.maintenanceCycles,
      )..where((row) => row.id.equals('parent'))).write(
        const MaintenanceCyclesCompanion(closedOnDate: Value('2026-09-08')),
      );
      await expectLater(
        service.restorePreparedMerge(parentChangedPlan),
        throwsStateError,
      );
      expect(await target.select(target.maintenanceCycles).get(), hasLength(1));
      expect(
        (await target.select(target.maintenanceCycles).getSingle())
            .closedOnDate,
        '2026-09-08',
      );

      await (target.update(
        target.maintenanceCycles,
      )..where((row) => row.id.equals('parent'))).write(
        const MaintenanceCyclesCompanion(closedOnDate: Value('2026-09-07')),
      );
      final childChangedPlan = await service.prepareMerge(backup);
      final incomingChild = await (source.select(
        source.maintenanceCycles,
      )..where((row) => row.id.equals('child'))).getSingle();
      await target
          .into(target.maintenanceCycles)
          .insert(incomingChild.copyWith(id: 'concurrent-child'));
      await expectLater(
        service.restorePreparedMerge(childChangedPlan),
        throwsStateError,
      );
      final rows = await target.select(target.maintenanceCycles).get();
      expect(rows, hasLength(2));
      expect(
        rows.map((row) => row.id),
        containsAll(['parent', 'concurrent-child']),
      );
      expect(rows.any((row) => row.id == 'child'), isFalse);
      await service.validateJson(await service.exportJson());
    },
  );
}

Future<String> _closedChain(AppDatabase database) async {
  final repository = MaintenanceCycleRepository(
    database,
    now: () => DateTime(2026, 9, 8),
  );
  const input = MaintenanceDosingInput(
    dailyChange: .02,
    flow: 100,
    unit: PumpFlowUnit.mlPerMinute,
  );
  final parent = prepareMaintenanceCycle(
    input: input,
    chemical: DosingChemical.po4,
    tankId: AppDatabase.defaultTankId,
    startDate: '2026-09-05',
    id: 'parent',
  );
  await repository.confirm(parent);
  final child = prepareMaintenanceCycle(
    input: input,
    chemical: DosingChemical.po4,
    tankId: AppDatabase.defaultTankId,
    startDate: '2026-09-07',
    id: 'child',
    previous: parent,
  );
  await repository.confirm(child);
  await (database.update(
    database.maintenanceCycles,
  )..where((row) => row.id.equals('child'))).write(
    const MaintenanceCyclesCompanion(closedOnDate: Value('2026-09-08')),
  );
  return LocalBackupService(database).exportJson();
}
