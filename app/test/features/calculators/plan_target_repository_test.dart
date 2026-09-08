import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/alkalinity_calculator.dart';
import 'package:lanjiao_water_quality/features/calculators/domain/lanthanum_calculator.dart';
import 'package:lanjiao_water_quality/features/maintenance/data/maintenance_repository.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  late AppDatabase db;
  late TankRepository tanks;
  late MaintenanceRepository repo;
  const tank = AppDatabase.defaultTankId;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tanks = TankRepository(db);
    repo = MaintenanceRepository(db);
    await db.select(db.tanks).get();
  });
  tearDown(() => db.close());
  LanthanumPlan po4(double target) => calculateLanthanumPlan(
    currentPo4MgL: 0.23,
    targetPo4MgL: target,
    netWaterVolumeL: 200,
    maxDailyPo4DropMgL: 0.1,
  );
  AlkalinityPlan kh(double target) =>
      calculateAlkalinityPlan(currentDkh: 6, targetDkh: target);
  Future<void> khRange() async {
    await tanks.setParameterEnabled(
      tankId: tank,
      parameterId: AppDatabase.khId,
      enabled: true,
    );
    await tanks.setTarget(
      tankId: tank,
      parameterId: AppDatabase.khId,
      minValue: 7,
      maxValue: 8,
    );
  }

  test(
    'PO4 changed target rejects replacement atomically and preserves original tasks/events',
    () async {
      final ids = await repo.createLanthanumPlanTasks(
        tankId: tank,
        plan: po4(0.03),
      );
      await repo.complete(tankId: tank, taskId: ids.first);
      final before = await db.select(db.maintenanceTasks).get();
      final events = await db.select(db.taskEvents).get();
      await tanks.setTarget(
        tankId: tank,
        parameterId: AppDatabase.po4Id,
        minValue: 0.05,
        maxValue: 0.1,
      );
      await expectLater(
        repo.createLanthanumPlanTasks(
          tankId: tank,
          plan: po4(0.03),
          replaceExisting: true,
        ),
        throwsFormatException,
      );
      expect(await db.select(db.maintenanceTasks).get(), before);
      expect(await db.select(db.taskEvents).get(), events);
    },
  );
  test(
    'KH rejects both sides of current user range without writing tasks',
    () async {
      await khRange();
      for (final target in [6.5, 9.0]) {
        await expectLater(
          repo.createAlkalinityPlanTasks(tankId: tank, plan: kh(target)),
          throwsFormatException,
        );
      }
      expect(await db.select(db.maintenanceTasks).get(), isEmpty);
    },
  );
  test(
    'range boundaries are inclusive; PO4 upper range is not an extra dosing constraint',
    () async {
      await khRange();
      for (final target in [7.0, 8.0]) {
        expect(
          await repo.createAlkalinityPlanTasks(
            tankId: tank,
            plan: kh(target),
            replaceExisting: true,
          ),
          isNotEmpty,
        );
      }
      await tanks.setTarget(
        tankId: tank,
        parameterId: AppDatabase.po4Id,
        minValue: .05,
        maxValue: .1,
      );
      for (final target in [.05, .12]) {
        expect(
          await repo.createLanthanumPlanTasks(
            tankId: tank,
            plan: po4(target),
            replaceExisting: true,
          ),
          isNotEmpty,
        );
      }
    },
  );
  test('other tank ranges do not block a tank with no targets', () async {
    await khRange();
    await tanks.setTarget(
      tankId: tank,
      parameterId: AppDatabase.po4Id,
      minValue: .05,
      maxValue: .1,
    );
    final other = await tanks.createTank(name: 'Other');
    expect(
      await repo.createLanthanumPlanTasks(tankId: other, plan: po4(.03)),
      isNotEmpty,
    );
    expect(
      await repo.createAlkalinityPlanTasks(tankId: other, plan: kh(9)),
      isNotEmpty,
    );
  });
}
