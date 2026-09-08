import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanjiao_water_quality/data/backup/test_record_csv_export_service.dart';
import 'package:lanjiao_water_quality/data/database/app_database.dart';
import 'package:lanjiao_water_quality/features/tanks/data/tank_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('CSV 含 UTF-8 BOM、当前保存单位、UTC、范围与正确引号转义', () async {
    final time = DateTime.utc(2026, 8, 12, 3, 4, 5);
    await database
        .into(database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: 'record-1',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 10,
            confirmedMaxValue: const Value(25),
            unit: 'mg/L',
            measuredAt: time,
            confirmedAt: Value(time),
            notes: const Value('复测,"阴影"\n第二行'),
            createdAt: time,
            updatedAt: time,
          ),
        );

    final bytes = await TestRecordCsvExportService(
      database,
    ).exportBytesForTank(AppDatabase.defaultTankId);
    expect(bytes.take(3), <int>[0xef, 0xbb, 0xbf]);
    final csv = utf8.decode(bytes.sublist(3));
    expect(csv, contains('"10–25"'));
    expect(csv, contains('"10","25","","mg/L"'));
    expect(csv, contains('"2026-08-12T03:04:05.000Z"'));
    expect(csv, contains('"复测,""阴影""\n第二行"'));
  });

  test('CSV 严格按海缸隔离', () async {
    final repository = TankRepository(database);
    final secondTank = await repository.createTank(name: '办公室缸');
    final time = DateTime.utc(2026, 8, 12);
    await database.batch((batch) {
      batch.insertAll(database.testRecords, <TestRecord>[
        TestRecord(
          id: 'first',
          tankId: AppDatabase.defaultTankId,
          parameterId: AppDatabase.no3Id,
          reagentProfileId: null,
          capturedAt: null,
          estimatedMinValue: null,
          estimatedMaxValue: null,
          estimationMethod: null,
          estimationVersion: null,
          qualityScore: null,
          confidence: null,
          failureReason: null,
          confirmedMinValue: 1,
          confirmedMaxValue: null,
          unit: 'mg/L',
          measuredAt: time,
          confirmedAt: time,
          notes: null,
          photoPath: null,
          wasManuallyEdited: false,
          createdAt: time,
          updatedAt: time,
        ),
        TestRecord(
          id: 'second',
          tankId: secondTank,
          parameterId: AppDatabase.no3Id,
          reagentProfileId: null,
          capturedAt: null,
          estimatedMinValue: null,
          estimatedMaxValue: null,
          estimationMethod: null,
          estimationVersion: null,
          qualityScore: null,
          confidence: null,
          failureReason: null,
          confirmedMinValue: 2,
          confirmedMaxValue: null,
          unit: 'mg/L',
          measuredAt: time,
          confirmedAt: time,
          notes: null,
          photoPath: null,
          wasManuallyEdited: false,
          createdAt: time,
          updatedAt: time,
        ),
      ]);
    });

    final bytes = await TestRecordCsvExportService(
      database,
    ).exportBytesForTank(secondTank);
    final csv = utf8.decode(bytes.sublist(3));
    expect(csv, contains('"second"'));
    expect(csv, contains('"办公室缸"'));
    expect(csv, isNot(contains('"first"')));
  });

  test('CSV 对用户文本中的电子表格公式前缀进行文本化', () async {
    final time = DateTime.utc(2026, 8, 13);
    await database
        .into(database.testRecords)
        .insert(
          TestRecordsCompanion.insert(
            id: '=HYPERLINK("https://invalid.example")',
            tankId: AppDatabase.defaultTankId,
            parameterId: AppDatabase.no3Id,
            confirmedMinValue: 5,
            unit: 'mg/L',
            measuredAt: time,
            confirmedAt: Value(time),
            notes: const Value('  +SUM(1,1)'),
            createdAt: time,
            updatedAt: time,
          ),
        );

    final bytes = await TestRecordCsvExportService(
      database,
    ).exportBytesForTank(AppDatabase.defaultTankId);
    final csv = utf8.decode(bytes.sublist(3));
    expect(csv, contains('"\'=HYPERLINK(""https://invalid.example"")"'));
    expect(csv, contains('"\'  +SUM(1,1)"'));
    expect(csv, isNot(contains('\n"=HYPERLINK')));
  });
}
