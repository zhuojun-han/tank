import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class TestRecordCsvExportService {
  TestRecordCsvExportService(
    this._database, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final AppDatabase _database;
  final Future<Directory> Function() _supportDirectory;

  static const headers = <String>[
    'record_id',
    'tank_id',
    'tank_name',
    'parameter_id',
    'parameter_code',
    'parameter_name',
    'confirmed_result',
    'confirmed_min',
    'confirmed_max',
    'interpolation',
    'unit',
    'confirmed_at_utc',
    'notes',
  ];

  Future<Uint8List> exportBytesForTank(String tankId) async {
    final tank = await (_database.select(
      _database.tanks,
    )..where((row) => row.id.equals(tankId))).getSingleOrNull();
    if (tank == null) throw StateError('海缸不存在');

    final query =
        _database.select(_database.testRecords).join([
            innerJoin(
              _database.waterParameters,
              _database.waterParameters.id.equalsExp(
                _database.testRecords.parameterId,
              ),
            ),
          ])
          ..where(_database.testRecords.tankId.equals(tankId))
          ..orderBy([
            OrderingTerm.desc(_database.testRecords.measuredAt),
            OrderingTerm.desc(_database.testRecords.updatedAt),
          ]);
    final rows = await query.get();
    final buffer = StringBuffer()..writeln(headers.map(_csvCell).join(','));
    for (final row in rows) {
      final record = row.readTable(_database.testRecords);
      final parameter = row.readTable(_database.waterParameters);
      final confirmedAt = (record.confirmedAt ?? record.measuredAt).toUtc();
      final maximum = record.confirmedMaxValue;
      final result = maximum == null || maximum == record.confirmedMinValue
          ? _number(record.confirmedMinValue)
          : '${_number(record.confirmedMinValue)}–${_number(maximum)}';
      final values = <String>[
        record.id,
        record.tankId,
        tank.name,
        record.parameterId,
        parameter.code,
        parameter.displayName,
        result,
        _number(record.confirmedMinValue),
        maximum == null ? '' : _number(maximum),
        record.confirmedInterpolation == null
            ? ''
            : _number(record.confirmedInterpolation!),
        record.unit,
        confirmedAt.toIso8601String(),
        record.notes ?? '',
      ];
      buffer.writeln(values.map(_csvCell).join(','));
    }
    return Uint8List.fromList(<int>[
      0xef,
      0xbb,
      0xbf,
      ...utf8.encode(buffer.toString()),
    ]);
  }

  Future<File> exportToPrivateFile(String tankId) async {
    final bytes = await exportBytesForTank(tankId);
    final support = await _supportDirectory();
    final directory = Directory(p.join(support.path, 'exports'));
    await directory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File(
      p.join(directory.path, 'lanjiao-test-records-$timestamp.csv'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}

String _csvCell(String value) {
  final safeValue = _preventSpreadsheetFormula(value);
  return '"${safeValue.replaceAll('"', '""')}"';
}

String _preventSpreadsheetFormula(String value) {
  if (value.isEmpty) return value;
  final firstNonWhitespace = value.trimLeft();
  if (firstNonWhitespace.isEmpty) return value;
  final first = firstNonWhitespace[0];
  if (const {'=', '+', '-', '@'}.contains(first) ||
      value.startsWith('\t') ||
      value.startsWith('\r') ||
      value.startsWith('\n')) {
    // The leading apostrophe is data, not a CSV quoting character. Common
    // spreadsheet programs treat it as an explicit text marker, preventing a
    // restored user-controlled name or note from executing as a formula.
    return "'$value";
  }
  return value;
}

String _number(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString();
}
