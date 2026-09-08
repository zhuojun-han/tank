import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';
import 'package:lanjiao_water_quality/features/test_records/data/test_record_repository.dart';
import 'package:lanjiao_water_quality/features/test_timer/data/test_session_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;
  late TankRepository tanks;
  late DateTime clock;
  late TestSessionRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    tanks = TankRepository(database);
    clock = DateTime.utc(2026, 8, 12, 1);
    repository = TestSessionRepository(database, now: () => clock);
  });

  tearDown(() => database.close());

  test('计时默认值初始 300 秒、校验 10..3600 并按缸参数隔离', () async {
    final secondTankId = await tanks.createTank(name: '计时隔离缸');

    expect(
      await repository.readDefaultDurationSeconds(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
      ),
      300,
    );
    await repository.setDefaultDurationSeconds(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      durationSeconds: 600,
    );
    expect(
      await repository
          .watchDefaultDurationSeconds(
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
          )
          .first,
      600,
    );
    expect(
      await repository.readDefaultDurationSeconds(
        tankId: secondTankId,
        parameterId: AppDatabase.no3Id,
      ),
      300,
    );
    expect(
      await repository.readDefaultDurationSeconds(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.po4Id,
      ),
      300,
    );

    await expectLater(
      repository.setDefaultDurationSeconds(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
        durationSeconds: 9,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.setDefaultDurationSeconds(
        tankId: secondTankId,
        parameterId: AppDatabase.khId,
        durationSeconds: 300,
      ),
      throwsStateError,
    );
  });

  test('草稿复制默认时长且后续配置变化不影响进行中的检测', () async {
    await repository.setDefaultDurationSeconds(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      durationSeconds: 600,
    );
    final draftStartedAt = DateTime(2026, 8, 12, 9);
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
      startedAt: draftStartedAt,
    );
    await repository.setDefaultDurationSeconds(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      durationSeconds: 180,
    );

    var draft = await repository.readDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    expect(draft?.id, sessionId);
    expect(draft?.timerDurationSeconds, 600);
    expect(draft?.startedAt.isAtSameMomentAs(draftStartedAt.toUtc()), isTrue);
    expect(draft?.stage, ActiveTestStage.preparation.name);
    expect(await repository.readDraftById(sessionId), isNotNull);
    expect(await repository.watchDraftById(sessionId).first, isNotNull);
    expect(await repository.readDraftById(''), isNull);

    final timerStartedAt = DateTime.utc(2026, 8, 12, 2);
    await repository.updateTimer(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      startedAt: timerStartedAt,
      timerEndsAt: timerStartedAt.add(const Duration(minutes: 10)),
      stage: ActiveTestStage.timerRunning,
    );
    await repository.updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/no3.jpg',
    );
    draft = await repository.readDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    expect(draft?.timerDurationSeconds, 600);
    expect(
      draft?.timerEndsAt?.isAtSameMomentAs(DateTime.utc(2026, 8, 12, 2, 10)),
      isTrue,
    );
    expect(draft?.draftPhotoPath, 'water_quality_photos/no3.jpg');
    expect(draft?.stage, ActiveTestStage.timerRunning.name);

    await expectLater(
      repository.createDraft(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
      ),
      throwsStateError,
    );
    await expectLater(
      repository.updatePhoto(
        tankId: AppDatabase.defaultTankId,
        sessionId: sessionId,
        photoPath: '../outside.jpg',
      ),
      throwsArgumentError,
    );
  });

  test('草稿读取、更新和放弃严格校验海缸归属', () async {
    final secondTankId = await tanks.createTank(name: '另一海缸');
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );

    expect(
      await repository.readDraft(
        tankId: secondTankId,
        parameterId: AppDatabase.no3Id,
      ),
      isNull,
    );
    await expectLater(
      repository.updateStage(
        tankId: secondTankId,
        sessionId: sessionId,
        stage: ActiveTestStage.review,
      ),
      throwsStateError,
    );
    await expectLater(
      repository.discardDraft(tankId: secondTankId, sessionId: sessionId),
      throwsStateError,
    );
    expect(
      await repository.readDraft(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.no3Id,
      ),
      isNotNull,
    );

    await repository.discardDraft(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
    );
    expect(await database.select(database.activeTestSessions).get(), isEmpty);
  });

  test('事务保存生成完整记录并删除草稿', () async {
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
    );
    await repository.updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/captured.jpg',
    );
    final capturedAt = DateTime.utc(2026, 8, 12, 1, 4);
    final confirmedAt = DateTime.utc(2026, 8, 12, 1, 5);
    await repository.updateReviewDraft(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 10,
      confirmedMaxValue: 25,
      confirmedAt: confirmedAt,
      capturedAt: capturedAt,
      notes: '  人工确认范围  ',
      estimatedMinValue: 10,
      estimatedMaxValue: 25,
      estimationMethod: 'lab-color-distance',
      estimationVersion: 'no3-prototype-v1',
      qualityScore: 0.72,
      confidence: 'medium',
    );
    final resumableDraft = await repository.readDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    expect(resumableDraft?.draftConfirmedMinValue, 10);
    expect(resumableDraft?.draftConfirmedMaxValue, 25);
    expect(
      resumableDraft?.draftConfirmedAt?.isAtSameMomentAs(confirmedAt),
      isTrue,
    );
    expect(
      resumableDraft?.draftCapturedAt?.isAtSameMomentAs(capturedAt),
      isTrue,
    );
    expect(resumableDraft?.draftEstimationVersion, 'no3-prototype-v1');
    expect(resumableDraft?.draftNotes, '人工确认范围');
    expect(resumableDraft?.stage, ActiveTestStage.review.name);
    final recordId = await repository.saveDraftAsRecord(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 10,
      confirmedMaxValue: 25,
    );

    expect(await database.select(database.activeTestSessions).get(), isEmpty);
    final record = await database.select(database.testRecords).getSingle();
    expect(record.id, recordId);
    expect(record.tankId, AppDatabase.defaultTankId);
    expect(record.parameterId, AppDatabase.no3Id);
    expect(record.reagentProfileId, AppDatabase.ealNo3ReagentId);
    expect(record.capturedAt?.isAtSameMomentAs(capturedAt), isTrue);
    expect(record.confirmedAt?.isAtSameMomentAs(confirmedAt), isTrue);
    expect(record.measuredAt.isAtSameMomentAs(confirmedAt), isTrue);
    expect(record.photoPath, isNull);
    expect(record.estimationVersion, 'no3-prototype-v1');
    expect(record.qualityScore, 0.72);
    expect(record.confidence, 'medium');
    expect(record.notes, '人工确认范围');
    expect(record.wasManuallyEdited, isFalse);
  });

  test('记录编辑可换缸参数并保留原始算法字段；删除照片只清路径', () async {
    final secondTankId = await tanks.createTank(name: '记录目标缸');
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
      reagentProfileId: AppDatabase.ealNo3ReagentId,
    );
    await repository.updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/original.jpg',
    );
    final recordId = await repository.saveDraftAsRecord(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 10,
      confirmedAt: clock,
      capturedAt: clock.subtract(const Duration(minutes: 1)),
      estimatedMinValue: 10,
      estimationMethod: 'lab-color-distance',
      estimationVersion: 'immutable-version',
      qualityScore: 0.8,
      confidence: 'high',
    );
    final original = await database.select(database.testRecords).getSingle();
    final records = TestRecordRepository(database);

    clock = DateTime.utc(2026, 8, 13, 2);
    await records.editRecord(
      id: recordId,
      sourceTankId: AppDatabase.defaultTankId,
      targetTankId: secondTankId,
      parameterId: AppDatabase.po4Id,
      confirmedMinValue: 0.03,
      confirmedAt: clock,
      notes: 'PO4 人工复核',
    );
    var edited = await database.select(database.testRecords).getSingle();
    expect(edited.tankId, secondTankId);
    expect(edited.parameterId, AppDatabase.po4Id);
    expect(edited.unit, 'mg/L');
    expect(edited.confirmedMinValue, 0.03);
    expect(edited.confirmedAt?.isAtSameMomentAs(clock), isTrue);
    expect(edited.wasManuallyEdited, isTrue);
    expect(edited.capturedAt?.isAtSameMomentAs(original.capturedAt!), isTrue);
    expect(edited.estimatedMinValue, original.estimatedMinValue);
    expect(edited.estimationMethod, original.estimationMethod);
    expect(edited.estimationVersion, original.estimationVersion);
    expect(edited.qualityScore, original.qualityScore);
    expect(edited.confidence, original.confidence);
    expect(edited.photoPath, original.photoPath);

    await expectLater(
      records.clearPhoto(id: recordId, tankId: AppDatabase.defaultTankId),
      throwsStateError,
    );
    await records.clearPhoto(id: recordId, tankId: secondTankId);
    edited = await database.select(database.testRecords).getSingle();
    expect(edited.photoPath, isNull);
    expect(edited.confirmedMinValue, 0.03);
    expect(edited.estimationVersion, 'immutable-version');
  });

  test('删除记录严格校验海缸并在成功后返回照片路径', () async {
    final secondTankId = await tanks.createTank(name: '删除隔离缸');
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await repository.updatePhoto(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      photoPath: 'water_quality_photos/to-delete.jpg',
    );
    final recordId = await repository.saveDraftAsRecord(
      tankId: AppDatabase.defaultTankId,
      sessionId: sessionId,
      confirmedMinValue: 5,
      confirmedAt: clock,
    );
    final records = TestRecordRepository(database);

    await expectLater(
      records.deleteRecord(id: recordId, tankId: secondTankId),
      throwsStateError,
    );
    expect(await database.select(database.testRecords).get(), hasLength(1));

    final deleted = await records.deleteRecord(
      id: recordId,
      tankId: AppDatabase.defaultTankId,
    );
    expect(deleted.photoPath, isNull);
    expect(await database.select(database.testRecords).get(), isEmpty);
  });

  test('试剂必须匹配参数，保存校验失败时草稿仍保留', () async {
    await expectLater(
      repository.createDraft(
        tankId: AppDatabase.defaultTankId,
        parameterId: AppDatabase.po4Id,
        reagentProfileId: AppDatabase.ealNo3ReagentId,
      ),
      throwsStateError,
    );
    final sessionId = await repository.createDraft(
      tankId: AppDatabase.defaultTankId,
      parameterId: AppDatabase.no3Id,
    );
    await expectLater(
      repository.saveDraftAsRecord(
        tankId: AppDatabase.defaultTankId,
        sessionId: sessionId,
        confirmedMinValue: 25,
        confirmedMaxValue: 10,
        confirmedAt: clock,
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.testRecords).get(), isEmpty);
    expect(
      await database.select(database.activeTestSessions).get(),
      hasLength(1),
    );
  });
}
