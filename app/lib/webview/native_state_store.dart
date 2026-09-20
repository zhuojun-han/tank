import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../features/aquarium/domain/fish_stock.dart';
import '../features/tanks/domain/tank_age.dart';
import '../features/test_records/data/test_record_repository.dart';
import '../features/test_timer/domain/kh_titration.dart';
import 'native_state_tasks.dart';
import 'native_state_cycles.dart';

typedef NativeUiPreferencesReader = Future<Map<String, dynamic>> Function();

/// Maps the shared Web UI onto the existing relational database. Unexposed
/// native columns are deliberately absent from every UPDATE companion.
class NativeStateStore {
  NativeStateStore(this.database, {this.readUiPreferences});

  final AppDatabase database;
  final NativeUiPreferencesReader? readUiPreferences;

  Future<Map<String, dynamic>> readState() => database.transaction(_readState);

  Future<Map<String, dynamic>> _readState() async {
    final tanks = await database.select(database.tanks).get();
    final activeTankIds = tanks
        .where((t) => !t.isArchived)
        .map((t) => t.id)
        .toSet();
    final parameters = await database.select(database.waterParameters).get();
    final parameterIds = {for (final p in parameters) p.id: webParameterId(p)};
    final associations = await database.select(database.tankParameters).get();
    final targets = await database.select(database.waterQualityTargets).get();
    final targetByKey = {
      for (final t in targets) '${t.tankId}:${t.parameterId}': t,
    };
    final records = await database.select(database.testRecords).get();
    records.sort((a, b) {
      final date = (b.confirmedAt ?? b.measuredAt).compareTo(
        a.confirmedAt ?? a.measuredAt,
      );
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    final tasks = await database.select(database.maintenanceTasks).get();
    final cycles = await database.select(database.maintenanceCycles).get();
    final events = await database.select(database.taskEvents).get();
    final eventsByTask = <String, List<TaskEvent>>{};
    for (final event in events) {
      eventsByTask.putIfAbsent(event.taskId, () => []).add(event);
    }
    final timers = await database.select(database.testTimerDefaults).get();
    final prefs = await (database.select(
      database.appPreferences,
    )..where((p) => p.id.equals(1))).getSingle();
    final fish = FishStockCodec.decode(prefs.fishStockJson);
    final state = <String, dynamic>{
      'schemaVersion': 1,
      'khTargetDefaultsApplied': true,
      'tanks': [
        for (final t in tanks)
          if (!t.isArchived)
            {
              'id': t.id,
              'name': t.name,
              'volume': t.volumeLiters == null
                  ? ''
                  : '${_formatNumber(t.volumeLiters!)} L',
              if (t.startedOn != null) 'startedOn': t.startedOn,
            },
      ],
      'tankId': activeTankIds.contains(prefs.currentTankId)
          ? prefs.currentTankId
          : activeTankIds.firstOrNull ?? '',
      'parameters': [
        for (final p in parameters)
          {
            'id': webParameterId(p),
            'name': p.code,
            'label': p.displayName,
            'unit': p.unit,
            'builtIn': p.isBuiltIn,
            'photoSupported': p.photoSupported,
          },
      ],
      'targets': [
        for (final a in associations)
          if (a.isEnabled && activeTankIds.contains(a.tankId))
            {
              'tankId': a.tankId,
              'parameterId': parameterIds[a.parameterId],
              'min': targetByKey['${a.tankId}:${a.parameterId}']?.minValue,
              'max': targetByKey['${a.tankId}:${a.parameterId}']?.maxValue,
            },
      ],
      'records': [
        for (final r in records)
          if (activeTankIds.contains(r.tankId))
            {
              'id': r.id,
              'tankId': r.tankId,
              'parameterId': parameterIds[r.parameterId],
              'low': r.confirmedMinValue,
              'high': r.confirmedMaxValue ?? r.confirmedMinValue,
              'interpolation': r.confirmedInterpolation,
              'date': (r.confirmedAt ?? r.measuredAt).toUtc().toIso8601String(),
              'note': r.notes ?? '',
              'edited': r.wasManuallyEdited,
              if (r.khTitrationJson != null)
                'khTitration': jsonDecode(r.khTitrationJson!),
              if (r.estimatedMinValue != null && r.estimatedMaxValue != null)
                'photoEstimate': {
                  'parameterId': parameterIds[r.parameterId],
                  'low': r.estimatedMinValue,
                  'high': r.estimatedMaxValue,
                  'interpolation': r.estimatedInterpolation,
                  'source': r.estimationMethod ?? '',
                  'algorithmVersion': r.estimationVersion ?? '',
                },
            },
      ],
      'tasks': [
        for (final t in tasks)
          if (activeTankIds.contains(t.tankId) && t.status != 'archived')
            nativeTaskToWeb(t, eventsByTask[t.id] ?? []),
      ],
      'maintenanceCycles': [
        for (final c in cycles)
          if (activeTankIds.contains(c.tankId)) nativeCycleToWeb(c),
      ],
      'fishStock': [
        for (final f in fish)
          if (activeTankIds.contains(f.tankId)) _fishToWeb(f),
      ],
      'timerDefaults': {
        for (final t in timers)
          if (activeTankIds.contains(t.tankId))
            '${t.tankId}:${parameterIds[t.parameterId]}': t.durationSeconds,
      },
      'notificationEnabled': prefs.maintenanceNotificationsEnabled,
      'reminderDismissedDate': '',
      'reminderSnoozedUntil': <String, dynamic>{},
      ...?await readUiPreferences?.call(),
    };
    // Include hidden compatibility data so a backup restore or another native
    // writer invalidates an old UI snapshot even if visible values match.
    final source = [
      [for (final row in tanks) row.toJson()],
      [for (final row in parameters) row.toJson()],
      [for (final row in associations) row.toJson()],
      [for (final row in targets) row.toJson()],
      [for (final row in records) row.toJson()],
      [for (final row in tasks) _notificationIndependent(row.toJson())],
      [for (final row in cycles) _notificationIndependent(row.toJson())],
      [for (final row in events) row.toJson()],
      [for (final row in timers) row.toJson()],
      prefs.toJson(),
    ];
    // Feed JSON directly into SHA rather than retaining both a complete JSON
    // string and its UTF-8 copy alongside records and custom fish artwork.
    late Digest hash;
    final output = ChunkedConversionSink<Digest>.withCallback(
      (digests) => hash = digests.single,
    );
    final input = JsonUtf8Encoder().startChunkedConversion(
      sha256.startChunkedConversion(output),
    );
    input.add(source);
    input.close();
    final digest = hash.bytes;
    var revision = 0;
    for (final byte in digest.take(6)) {
      revision = revision * 256 + byte;
    }
    return {'revision': revision, 'state': state};
  }

  Future<Map<String, dynamic>> saveState(
    Map<String, dynamic> snapshot, {
    required int expectedRevision,
  }) => database.transaction(() async {
    await _writeState(snapshot, expectedRevision: expectedRevision);
    return _readState();
  });

  /// The bridge refreshes after reconciling notifications. Avoid building a
  /// second full snapshot that the caller would immediately discard.
  Future<void> commitState(
    Map<String, dynamic> snapshot, {
    required int expectedRevision,
  }) => database.transaction(
    () => _writeState(snapshot, expectedRevision: expectedRevision),
  );

  Future<void> _writeState(
    Map<String, dynamic> snapshot, {
    required int expectedRevision,
  }) async {
    final before = await _readState();
    if (before['revision'] != expectedRevision) {
      throw const NativeStateConflict('数据已更新，请重新载入后保存。');
    }
    final prior = before['state'] as Map<String, dynamic>;
    for (final key in [
      'tanks',
      'parameters',
      'targets',
      'records',
      'tasks',
      'maintenanceCycles',
      'fishStock',
    ]) {
      stateRows(snapshot, key);
    }
    final tankIds = stateRows(
      snapshot,
      'tanks',
    ).map((t) => stateId(t['id'])).toSet();
    final existingTanks = {
      for (final t in await database.select(database.tanks).get()) t.id: t,
    };
    final priorTanks = _indexed(prior, 'tanks');
    final currentTankId = snapshot['tankId'];
    if (!(currentTankId is String &&
        (tankIds.contains(currentTankId) ||
            tankIds.isEmpty && currentTankId.isEmpty))) {
      throw const FormatException('当前海缸无效。');
    }
    for (final row in stateRows(snapshot, 'tanks')) {
      final id = stateId(row['id']), old = existingTanks[id];
      if (old?.isArchived == true) {
        throw const FormatException('不能通过页面快照恢复已归档海缸。');
      }
      final previous = priorTanks[id];
      if (_same(row, previous)) continue;
      final name = stateText(row['name'], 80), volume = _volume(row['volume']);
      final startedOn = previous?['startedOn'] == row['startedOn']
          ? old?.startedOn
          : validateTankStartDate(row['startedOn'] as String?, DateTime.now());
      final now = DateTime.now().toUtc();
      if (old == null) {
        await database
            .into(database.tanks)
            .insert(
              TanksCompanion.insert(
                id: id,
                name: name,
                startedOn: Value(startedOn),
                volumeLiters: Value(volume),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (database.update(
          database.tanks,
        )..where((t) => t.id.equals(id))).write(
          TanksCompanion(
            name: Value(name),
            startedOn: Value(startedOn),
            volumeLiters: Value(volume),
            updatedAt: Value(now),
          ),
        );
      }
    }
    // Omission must not erase a tank and all of its invisible historical data.
    for (final row in stateRows(prior, 'tanks')) {
      if (!tankIds.contains(row['id'])) {
        throw const FormatException('请使用海缸归档操作，不可通过快照删除海缸。');
      }
    }
    final params = await _saveParameters(snapshot, prior);
    await _saveTargets(snapshot, prior, tankIds, params);
    await _saveRecords(snapshot, prior, tankIds, params);
    await saveNativeTasks(database, snapshot, prior, tankIds);
    await saveNativeCycles(database, snapshot, prior, tankIds);
    await _saveFish(snapshot, prior, tankIds);
    await _saveTimers(snapshot, tankIds, params);
    if (snapshot['notificationEnabled'] is! bool) {
      throw const FormatException('提醒设置无效。');
    }
    if (prior['tankId'] != currentTankId ||
        prior['notificationEnabled'] != snapshot['notificationEnabled']) {
      await (database.update(
        database.appPreferences,
      )..where((p) => p.id.equals(1))).write(
        AppPreferencesCompanion(
          currentTankId: Value(currentTankId.isEmpty ? null : currentTankId),
          maintenanceNotificationsEnabled: Value(
            snapshot['notificationEnabled'] as bool,
          ),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  Future<Map<String, WaterParameter>> _saveParameters(
    Map<String, dynamic> state,
    Map<String, dynamic> prior,
  ) async {
    final existing = {
      for (final p in await database.select(database.waterParameters).get())
        webParameterId(p): p,
    };
    final rows = stateRows(state, 'parameters');
    final priorParameters = _indexed(prior, 'parameters');
    for (final p in rows) {
      final key = stateId(p['id']), old = existing[key];
      if (_same(p, priorParameters[key])) continue;
      if (old?.isBuiltIn == true) throw const FormatException('内置指标定义不可修改。');
      final code = stateText(p['name'], 40),
          label = stateText(p['label'], 40),
          unit = stateText(p['unit'], 20);
      if (p['builtIn'] != false || p['photoSupported'] != false) {
        throw const FormatException('自定义指标不支持拍照估算。');
      }
      if (old == null) {
        await database
            .into(database.waterParameters)
            .insert(
              WaterParametersCompanion.insert(
                id: key,
                code: code,
                displayName: label,
                unit: unit,
                isBuiltIn: false,
                createdAt: DateTime.now().toUtc(),
              ),
            );
      } else {
        // Units belong to historical records too; editing the definition does
        // not retroactively change record units or reagent profiles.
        await (database.update(
          database.waterParameters,
        )..where((p) => p.id.equals(old.id))).write(
          WaterParametersCompanion(
            code: Value(code),
            displayName: Value(label),
            unit: Value(unit),
          ),
        );
      }
    }
    if (existing.keys.any((id) => !rows.any((r) => r['id'] == id))) {
      throw const FormatException('停用指标不会删除指标定义。');
    }
    return {
      for (final p in await database.select(database.waterParameters).get())
        webParameterId(p): p,
    };
  }

  Future<void> _saveTargets(
    Map<String, dynamic> state,
    Map<String, dynamic> prior,
    Set<String> tanks,
    Map<String, WaterParameter> parameters,
  ) async {
    final rows = stateRows(state, 'targets'),
        oldRows = stateRows(prior, 'targets');
    final seen = <String>{};
    for (final r in rows) {
      final tank = stateId(r['tankId']),
          parameter = parameters[stateId(r['parameterId'])];
      if (!tanks.contains(tank) || parameter == null) {
        throw const FormatException('指标与海缸不匹配。');
      }
      if (!seen.add('$tank:${parameter.id}')) {
        throw const FormatException('目标范围重复。');
      }
      final min = stateNumber(r['min'], nullable: true),
          max = stateNumber(r['max'], nullable: true);
      if (min != null && max != null && min > max) {
        throw const FormatException('目标下限不能大于上限。');
      }
      if (_same(
        r,
        oldRows
            .where(
              (o) =>
                  o['tankId'] == tank && o['parameterId'] == r['parameterId'],
            )
            .firstOrNull,
      )) {
        continue;
      }
      final now = DateTime.now().toUtc();
      final target =
          await (database.select(database.waterQualityTargets)..where(
                (t) =>
                    t.tankId.equals(tank) & t.parameterId.equals(parameter.id),
              ))
              .getSingleOrNull();
      await database
          .into(database.tankParameters)
          .insertOnConflictUpdate(
            TankParametersCompanion.insert(
              tankId: tank,
              parameterId: parameter.id,
              isEnabled: const Value(true),
              updatedAt: now,
            ),
          );
      if (target == null) {
        await database
            .into(database.waterQualityTargets)
            .insert(
              WaterQualityTargetsCompanion.insert(
                id: const Uuid().v4(),
                tankId: tank,
                parameterId: parameter.id,
                minValue: Value(min),
                maxValue: Value(max),
                unit: parameter.unit,
                updatedAt: now,
              ),
            );
      } else {
        await (database.update(
          database.waterQualityTargets,
        )..where((t) => t.id.equals(target.id))).write(
          WaterQualityTargetsCompanion(
            minValue: Value(min),
            maxValue: Value(max),
            updatedAt: Value(now),
          ),
        );
      }
    }
    for (final old in oldRows) {
      if (rows.any(
        (r) =>
            r['tankId'] == old['tankId'] &&
            r['parameterId'] == old['parameterId'],
      )) {
        continue;
      }
      final parameter = parameters[old['parameterId']]!;
      await (database.update(database.tankParameters)..where(
            (t) =>
                t.tankId.equals(old['tankId'] as String) &
                t.parameterId.equals(parameter.id),
          ))
          .write(
            TankParametersCompanion(
              isEnabled: const Value(false),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
    }
  }

  Future<void> _saveRecords(
    Map<String, dynamic> state,
    Map<String, dynamic> prior,
    Set<String> tanks,
    Map<String, WaterParameter> parameters,
  ) async {
    final existing = {
      for (final r in await database.select(database.testRecords).get())
        r.id: r,
    };
    final rows = stateRows(state, 'records');
    final priorRecords = _indexed(prior, 'records');
    for (final r in rows) {
      final id = stateId(r['id']),
          old = existing[id],
          previous = priorRecords[id];
      if (_same(r, previous)) continue;
      final tank = stateId(r['tankId']),
          parameter = parameters[stateId(r['parameterId'])];
      if (!tanks.contains(tank) ||
          parameter == null ||
          old != null &&
              (old.tankId != tank || old.parameterId != parameter.id)) {
        throw const FormatException('检测记录归属不匹配，请重新打开对应海缸。');
      }
      final low = stateNumber(r['low'])!,
          high = stateNumber(r['high'])!,
          interpolation = stateNumber(r['interpolation'], nullable: true);
      if (high < low) throw const FormatException('检测下限不能大于上限。');
      validateInterpolation(low, high == low ? null : high, interpolation);
      final date = DateTime.tryParse(
        r['date'] is String ? r['date'] as String : '',
      );
      if (date == null) throw const FormatException('检测时间无效。');
      final note = r['note'];
      if (note is! String || note.length > 100000) {
        throw const FormatException('检测备注无效。');
      }
      final now = DateTime.now().toUtc();
      if (old == null) {
        final enabled =
            await (database.select(database.tankParameters)..where(
                  (t) =>
                      t.tankId.equals(tank) &
                      t.parameterId.equals(parameter.id) &
                      t.isEnabled.equals(true),
                ))
                .getSingleOrNull();
        if (enabled == null) throw const FormatException('请先启用检测指标。');
        final photo = r['photoEstimate'] == null
            ? null
            : stateMap(r['photoEstimate']);
        if (r['khTitration'] != null) {
          if (parameter.id != AppDatabase.khId) {
            throw const FormatException('KH 滴定元数据与指标不匹配。');
          }
          validateKhTitrationJson(jsonEncode(r['khTitration']));
        }
        final estimatedLow = photo == null ? null : stateNumber(photo['low']);
        final estimatedHigh = photo == null ? null : stateNumber(photo['high']);
        final estimatedInterpolation = photo == null
            ? null
            : stateNumber(photo['interpolation'], nullable: true);
        if (photo != null) {
          if (!parameter.photoSupported || estimatedLow! > estimatedHigh!) {
            throw const FormatException('拍照估值无效。');
          }
          validateInterpolation(
            estimatedLow,
            estimatedHigh,
            estimatedInterpolation,
          );
        }
        await database
            .into(database.testRecords)
            .insert(
              TestRecordsCompanion.insert(
                id: id,
                tankId: tank,
                parameterId: parameter.id,
                confirmedMinValue: low,
                confirmedMaxValue: Value(high == low ? null : high),
                confirmedInterpolation: Value(interpolation),
                estimatedMinValue: Value(estimatedLow),
                estimatedMaxValue: Value(estimatedHigh),
                estimatedInterpolation: Value(estimatedInterpolation),
                estimationMethod: Value(photo?['source'] as String?),
                estimationVersion: Value(photo?['algorithmVersion'] as String?),
                khTitrationJson: Value(
                  r['khTitration'] == null
                      ? null
                      : jsonEncode(r['khTitration']),
                ),
                unit: parameter.unit,
                measuredAt: date.toUtc(),
                confirmedAt: Value(date.toUtc()),
                notes: Value(note.isEmpty ? null : note),
                wasManuallyEdited: Value(r['edited'] == true),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (database.update(
          database.testRecords,
        )..where((r) => r.id.equals(id))).write(
          TestRecordsCompanion(
            confirmedMinValue: Value(low),
            confirmedMaxValue: Value(high == low ? null : high),
            confirmedInterpolation: Value(interpolation),
            measuredAt: Value(date.toUtc()),
            confirmedAt: Value(date.toUtc()),
            notes: Value(note.isEmpty ? null : note),
            wasManuallyEdited: const Value(true),
            updatedAt: Value(now),
          ),
        );
      }
    }
    final savedRecordIds = rows.map((r) => r['id']).toSet();
    if (priorRecords.keys.any((id) => !savedRecordIds.contains(id))) {
      throw const FormatException('删除记录须使用明确的删除操作。');
    }
  }

  Future<void> _saveFish(
    Map<String, dynamic> state,
    Map<String, dynamic> prior,
    Set<String> tanks,
  ) async {
    if (_same(state['fishStock'], prior['fishStock'])) return;
    final prefs = await (database.select(
      database.appPreferences,
    )..where((p) => p.id.equals(1))).getSingle();
    final existing = FishStockCodec.decode(prefs.fishStockJson);
    final result = [
      for (final f in existing)
        if (!tanks.contains(f.tankId)) f,
    ];
    for (final row in stateRows(state, 'fishStock')) {
      final id = stateId(row['id']), tank = stateId(row['tankId']);
      final old = existing.where((f) => f.id == id).firstOrNull;
      if (!tanks.contains(tank) || old != null && old.tankId != tank) {
        throw const FormatException('鱼类档案与海缸不匹配。');
      }
      final artwork = row['artwork'] == null
          ? {'source': 'builtin', 'id': 'clownfish'}
          : stateMap(row['artwork']);
      final builtinId = artwork['id'];
      final builtin = builtinFishCatalog
          .where((s) => _fishAssetId(s.asset) == builtinId)
          .firstOrNull;
      final custom = artwork['source'] == 'custom';
      if (!custom && builtin == null) throw const FormatException('内置鱼类立绘不存在。');
      final dataUrl = custom ? artwork['dataUrl'] as String? : null;
      final match = dataUrl == null
          ? null
          : RegExp(
              r'^data:(image/(?:png|jpeg|webp));base64,([A-Za-z0-9+/=]+)$',
            ).firstMatch(dataUrl);
      if (custom && match == null) throw const FormatException('鱼类立绘格式无效。');
      result.add(
        FishStockItem(
          id: id,
          tankId: tank,
          species: stateText(row['species'], 24),
          quantity: row['quantity'] as int,
          introducedOn: DateTime.parse(
            '${stateDate(row['introducedOn'])}T00:00:00Z',
          ),
          artworkKind: custom ? FishArtworkKind.custom : builtin!.kind,
          artworkMimeType: match?.group(1),
          artworkBase64: match?.group(2),
        ),
      );
    }
    await (database.update(
      database.appPreferences,
    )..where((p) => p.id.equals(1))).write(
      AppPreferencesCompanion(
        fishStockJson: Value(FishStockCodec.encode(result)),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _saveTimers(
    Map<String, dynamic> state,
    Set<String> tanks,
    Map<String, WaterParameter> parameters,
  ) async {
    final existing = await database.select(database.testTimerDefaults).get();
    final timers = stateMap(state['timerDefaults']);
    for (final entry in timers.entries) {
      final split = entry.key.lastIndexOf(':');
      if (split <= 0) throw const FormatException('计时设置归属无效。');
      final tank = entry.key.substring(0, split),
          parameter = parameters[entry.key.substring(split + 1)],
          duration = entry.value;
      if (!tanks.contains(tank) ||
          parameter == null ||
          duration is! int ||
          duration < 10 ||
          duration > 3600) {
        throw const FormatException('计时设置无效。');
      }
      if (existing.any(
        (t) =>
            t.tankId == tank &&
            t.parameterId == parameter.id &&
            t.durationSeconds == duration,
      )) {
        continue;
      }
      await database
          .into(database.testTimerDefaults)
          .insertOnConflictUpdate(
            TestTimerDefaultsCompanion.insert(
              tankId: tank,
              parameterId: parameter.id,
              durationSeconds: duration,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    }
  }
}

class NativeStateConflict implements Exception {
  const NativeStateConflict(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _notificationIndependent(Map<String, dynamic> row) =>
    Map<String, dynamic>.from(row)
      ..remove('notificationId')
      // The existing notification coordinator also touches this timestamp.
      // Actual scheduling changes alter status, rollingJson or inputJson.
      ..remove('updatedAt');

String webParameterId(WaterParameter p) =>
    p.isBuiltIn ? p.code.toLowerCase() : p.id;
String stateId(Object? value) => stateText(value, 80);
String stateText(Object? value, int maximum) {
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw const FormatException('文本或标识无效。');
  }
  return value.trim();
}

Map<String, dynamic> stateMap(Object? value) {
  if (value is! Map) throw const FormatException('对象格式无效。');
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> stateRows(
  Map<String, dynamic> snapshot,
  String key,
) {
  final value = snapshot[key];
  if (value is! List) throw FormatException('$key 列表缺失。');
  final rows = value.map(stateMap).toList();
  if (key != 'targets') {
    final ids = rows.map((r) => stateId(r['id'])).toSet();
    if (ids.length != rows.length) throw FormatException('$key 标识重复。');
  }
  return rows;
}

double? stateNumber(Object? value, {bool nullable = false}) {
  if (nullable && value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('数值必须为有限非负数。');
  }
  return value.toDouble();
}

String stateDate(Object? value) {
  final text = stateText(value, 10), date = DateTime.tryParse(text);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
      date == null ||
      date.year < 1 ||
      date.toIso8601String().substring(0, 10) != text) {
    throw const FormatException('日期无效。');
  }
  return text;
}

bool nativeStateEqual(Object? a, Object? b) => _same(a, b);
bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_same(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

Map<String, Map<String, dynamic>> _indexed(
  Map<String, dynamic> snapshot,
  String key,
) => {for (final row in stateRows(snapshot, key)) row['id'] as String: row};
String _formatNumber(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();
double? _volume(Object? value) {
  if (value is! String) throw const FormatException('水体积无效。');
  if (value.trim().isEmpty) return null;
  final parsed = double.tryParse(
    value.replaceFirst(RegExp(r'\s*[lL]\s*$'), '').trim(),
  );
  if (parsed == null || !parsed.isFinite || parsed <= 0) {
    throw const FormatException('水体积须为正数。');
  }
  return parsed;
}

String _fishAssetId(String asset) => asset.split('/').last.split('.').first;
Map<String, dynamic> _fishToWeb(FishStockItem f) => {
  'id': f.id,
  'tankId': f.tankId,
  'species': f.species,
  'quantity': f.quantity,
  'introducedOn': f.introducedOn.toUtc().toIso8601String().substring(0, 10),
  'artwork': f.artworkKind == FishArtworkKind.custom
      ? {
          'source': 'custom',
          'dataUrl': 'data:${f.artworkMimeType};base64,${f.artworkBase64}',
        }
      : {
          'source': 'builtin',
          'id': _fishAssetId(builtinFishSpeciesFor(f.artworkKind).asset),
        },
};
