import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../../features/aquarium/domain/fish_stock.dart';
import '../../features/maintenance/domain/recurrence.dart';

const _backupValueSerializer = _UtcBackupValueSerializer();

class LocalBackupService {
  LocalBackupService(this._database, {String Function()? idGenerator})
    : _idGenerator = idGenerator ?? (() => const Uuid().v4());

  final AppDatabase _database;
  final String Function() _idGenerator;

  static const formatVersion = 10;

  Future<File> exportToPrivateFile() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'backups'));
    await directory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File(p.join(directory.path, 'lanjiao-backup-$timestamp.json'));
    return file.writeAsString(await exportJson(), flush: true);
  }

  Future<File?> latestPrivateBackup() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'backups'));
    if (!await directory.exists()) return null;
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.first;
  }

  Future<void> restoreLatestPrivateBackupMerge() async {
    final file = await latestPrivateBackup();
    if (file == null) throw StateError('尚无本地备份');
    await restoreMerge(await file.readAsString());
  }

  /// All tables belong to one read snapshot, including concurrent app writes.
  Future<String> exportJson() => _database.transaction(_exportSnapshotJson);

  Future<String> _exportSnapshotJson() async {
    final tanks = await _database.select(_database.tanks).get();
    final parameters = await _database.select(_database.waterParameters).get();
    final tankParameters = await _database
        .select(_database.tankParameters)
        .get();
    final targets = await _database.select(_database.waterQualityTargets).get();
    final reagents = await _database.select(_database.reagentProfiles).get();
    final preferences = await _database.select(_database.appPreferences).get();
    final records = await _database.select(_database.testRecords).get();
    final maintenanceTasks = await _database
        .select(_database.maintenanceTasks)
        .get();
    final taskEvents = await _database.select(_database.taskEvents).get();
    final testTimerDefaults = await _database
        .select(_database.testTimerDefaults)
        .get();
    final activeTestSessions = await _database
        .select(_database.activeTestSessions)
        .get();
    return jsonEncode({
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tanks': [
        for (final item in tanks)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'waterParameters': [
        for (final item in parameters)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'tankParameters': [
        for (final item in tankParameters)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'waterQualityTargets': [
        for (final item in targets)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'reagentProfiles': [
        for (final item in reagents)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'appPreferences': [
        for (final item in preferences)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'testRecords': [
        for (final item in records)
          item
              .copyWith(photoPath: const Value(null))
              .toJson(serializer: _backupValueSerializer),
      ],
      'maintenanceTasks': [
        for (final item in maintenanceTasks)
          item
              .copyWith(notificationId: const Value(null))
              .toJson(serializer: _backupValueSerializer),
      ],
      'taskEvents': [
        for (final item in taskEvents)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'testTimerDefaults': [
        for (final item in testTimerDefaults)
          item.toJson(serializer: _backupValueSerializer),
      ],
      'activeTestSessions': [
        for (final item in activeTestSessions)
          item
              .copyWith(draftPhotoPath: const Value(null))
              .toJson(serializer: _backupValueSerializer),
      ],
    });
  }

  /// Fully parses and validates a JSON backup without mutating the database.
  ///
  /// Complete archive restore uses this as its final preflight check after
  /// validating the ZIP manifest and every file digest.
  Future<void> validateJson(String source) async {
    _decodeAndValidateBackup(source);
  }

  Future<void> restoreMerge(String source) async {
    final plan = await prepareMerge(source);
    await restorePreparedMerge(plan);
  }

  /// Replaces the complete persisted business state with one validated
  /// backup snapshot. This is the mode used when moving to another device:
  /// settings and scoped configuration must match the source instead of being
  /// skipped because a fresh installation already contains seeded rows.
  Future<LocalBackupRestoreResult> restoreReplace(String source) async {
    final backup = _decodeAndValidateBackup(source);
    await _database.transaction(() async {
      // Delete dependants before their referenced rows while foreign-key
      // enforcement remains enabled for the entire transaction.
      await _database.delete(_database.taskEvents).go();
      await _database.delete(_database.activeTestSessions).go();
      await _database.delete(_database.testRecords).go();
      await _database.delete(_database.maintenanceTasks).go();
      await _database.delete(_database.testTimerDefaults).go();
      await _database.delete(_database.waterQualityTargets).go();
      await _database.delete(_database.tankParameters).go();
      await _database.delete(_database.appPreferences).go();
      await _database.delete(_database.reagentProfiles).go();
      await _database.delete(_database.waterParameters).go();
      await _database.delete(_database.tanks).go();

      await _database.batch((batch) {
        if (backup.tanks.isNotEmpty) {
          batch.insertAll(_database.tanks, backup.tanks);
        }
        if (backup.parameters.isNotEmpty) {
          batch.insertAll(_database.waterParameters, backup.parameters);
        }
        if (backup.tankParameters.isNotEmpty) {
          batch.insertAll(_database.tankParameters, backup.tankParameters);
        }
        if (backup.targets.isNotEmpty) {
          batch.insertAll(_database.waterQualityTargets, backup.targets);
        }
        if (backup.reagents.isNotEmpty) {
          batch.insertAll(_database.reagentProfiles, backup.reagents);
        }
        if (backup.preferences.isNotEmpty) {
          batch.insertAll(_database.appPreferences, backup.preferences);
        }
        if (backup.records.isNotEmpty) {
          batch.insertAll(_database.testRecords, backup.records);
        }
        if (backup.maintenanceTasks.isNotEmpty) {
          batch.insertAll(_database.maintenanceTasks, backup.maintenanceTasks);
        }
        if (backup.taskEvents.isNotEmpty) {
          batch.insertAll(_database.taskEvents, backup.taskEvents);
        }
        if (backup.testTimerDefaults.isNotEmpty) {
          batch.insertAll(
            _database.testTimerDefaults,
            backup.testTimerDefaults,
          );
        }
        if (backup.activeTestSessions.isNotEmpty) {
          batch.insertAll(
            _database.activeTestSessions,
            backup.activeTestSessions,
          );
        }
      });
    });
    return LocalBackupRestoreResult(
      insertedTankCount: backup.tanks.length,
      insertedRecordCount: backup.records.length,
      insertedTaskCount: backup.maintenanceTasks.length,
      photoTransfers: const [],
    );
  }

  /// Builds a conflict-safe, immutable merge plan without writing data.
  ///
  /// Existing rows are reused only when their meaningful content matches.
  /// Conflicting string primary keys are remapped and every dependent foreign
  /// key is rewritten before any insert is attempted. Local preferences and
  /// existing unique-scope settings remain authoritative during a merge.
  Future<LocalBackupMergePlan> prepareMerge(String source) async {
    final backup = _decodeAndValidateBackup(source);
    final existingTanks = await _database.select(_database.tanks).get();
    final existingParameters = await _database
        .select(_database.waterParameters)
        .get();
    final existingTankParameters = await _database
        .select(_database.tankParameters)
        .get();
    final existingTargets = await _database
        .select(_database.waterQualityTargets)
        .get();
    final existingReagents = await _database
        .select(_database.reagentProfiles)
        .get();
    final existingRecords = await _database.select(_database.testRecords).get();
    final existingTasks = await _database
        .select(_database.maintenanceTasks)
        .get();
    final existingEvents = await _database.select(_database.taskEvents).get();
    final existingTimerDefaults = await _database
        .select(_database.testTimerDefaults)
        .get();
    final existingSessions = await _database
        .select(_database.activeTestSessions)
        .get();

    final tanks = <Tank>[];
    final tankIdMap = <String, String>{};
    final tankIds = <String>{
      ...existingTanks.map((item) => item.id),
      ...backup.tanks.map((item) => item.id),
    };
    final existingTanksById = {for (final item in existingTanks) item.id: item};
    for (final incoming in backup.tanks) {
      final existing = existingTanksById[incoming.id];
      if (existing == null) {
        tanks.add(incoming);
        tankIdMap[incoming.id] = incoming.id;
      } else if (_sameTankContent(existing, incoming)) {
        tankIdMap[incoming.id] = existing.id;
      } else {
        final id = _nextUniqueId(tankIds);
        tanks.add(incoming.copyWith(id: id));
        tankIdMap[incoming.id] = id;
      }
    }

    final parameters = <WaterParameter>[];
    final parameterIdMap = <String, String>{};
    final parameterIds = <String>{
      ...existingParameters.map((item) => item.id),
      ...backup.parameters.map((item) => item.id),
    };
    final existingParametersById = {
      for (final item in existingParameters) item.id: item,
    };
    final parametersByCode = <String, WaterParameter>{
      for (final item in existingParameters) item.code.toUpperCase(): item,
    };
    final usedCodes = <String>{
      ...existingParameters.map((item) => item.code.toUpperCase()),
      ...backup.parameters.map((item) => item.code.toUpperCase()),
    };
    for (final incoming in backup.parameters) {
      final sameId = existingParametersById[incoming.id];
      final sameCode = parametersByCode[incoming.code.toUpperCase()];
      if (sameId != null && _sameParameterContent(sameId, incoming)) {
        parameterIdMap[incoming.id] = sameId.id;
        continue;
      }
      if (sameCode != null && _sameParameterContent(sameCode, incoming)) {
        parameterIdMap[incoming.id] = sameCode.id;
        continue;
      }
      final id = sameId == null ? incoming.id : _nextUniqueId(parameterIds);
      final code = sameCode == null
          ? incoming.code
          : _nextUniqueParameterCode(incoming.code, usedCodes);
      final mapped = incoming.copyWith(id: id, code: code);
      parameters.add(mapped);
      parameterIdMap[incoming.id] = id;
      parametersByCode[code.toUpperCase()] = mapped;
      parameterIds.add(id);
      usedCodes.add(code.toUpperCase());
    }

    final tankParameters = <TankParameter>[];
    final tankParameterScopes = <String>{
      ...existingTankParameters.map(
        (item) => _scopeKey(item.tankId, item.parameterId),
      ),
    };
    for (final incoming in backup.tankParameters) {
      final mapped = incoming.copyWith(
        tankId: tankIdMap[incoming.tankId],
        parameterId: parameterIdMap[incoming.parameterId],
      );
      if (tankParameterScopes.add(
        _scopeKey(mapped.tankId, mapped.parameterId),
      )) {
        tankParameters.add(mapped);
      }
    }

    final targets = <WaterQualityTarget>[];
    final targetIds = <String>{
      ...existingTargets.map((item) => item.id),
      ...backup.targets.map((item) => item.id),
    };
    final targetScopes = <String>{
      ...existingTargets.map(
        (item) => _scopeKey(item.tankId, item.parameterId),
      ),
    };
    final existingTargetsById = {
      for (final item in existingTargets) item.id: item,
    };
    for (final incoming in backup.targets) {
      final mappedTankId = tankIdMap[incoming.tankId]!;
      final mappedParameterId = parameterIdMap[incoming.parameterId]!;
      if (!targetScopes.add(_scopeKey(mappedTankId, mappedParameterId))) {
        continue;
      }
      final id = existingTargetsById.containsKey(incoming.id)
          ? _nextUniqueId(targetIds)
          : incoming.id;
      targets.add(
        incoming.copyWith(
          id: id,
          tankId: mappedTankId,
          parameterId: mappedParameterId,
        ),
      );
      targetIds.add(id);
    }

    final reagents = <ReagentProfile>[];
    final reagentIdMap = <String, String>{};
    final reagentIds = <String>{
      ...existingReagents.map((item) => item.id),
      ...backup.reagents.map((item) => item.id),
    };
    final existingReagentsById = {
      for (final item in existingReagents) item.id: item,
    };
    for (final incoming in backup.reagents) {
      final mapped = incoming.copyWith(
        parameterId: parameterIdMap[incoming.parameterId],
      );
      final existing = existingReagentsById[incoming.id];
      if (existing == null) {
        reagents.add(mapped);
        reagentIdMap[incoming.id] = incoming.id;
      } else if (_sameReagentContent(existing, mapped)) {
        reagentIdMap[incoming.id] = existing.id;
      } else {
        final id = _nextUniqueId(reagentIds);
        reagents.add(mapped.copyWith(id: id));
        reagentIdMap[incoming.id] = id;
      }
    }

    final records = <TestRecord>[];
    final recordPhotoSources = <String, String>{};
    final recordIds = <String>{
      ...existingRecords.map((item) => item.id),
      ...backup.records.map((item) => item.id),
    };
    final existingRecordsById = {
      for (final item in existingRecords) item.id: item,
    };
    for (final incoming in backup.records) {
      final mapped = incoming.copyWith(
        tankId: tankIdMap[incoming.tankId],
        parameterId: parameterIdMap[incoming.parameterId],
        reagentProfileId: Value(
          incoming.reagentProfileId == null
              ? null
              : reagentIdMap[incoming.reagentProfileId],
        ),
      );
      final existing = existingRecordsById[incoming.id];
      if (existing != null && _sameRecordContent(existing, mapped)) continue;
      final id = existing == null ? incoming.id : _nextUniqueId(recordIds);
      final inserted = mapped.copyWith(id: id);
      records.add(inserted);
      recordIds.add(id);
      if (incoming.photoPath != null) {
        recordPhotoSources[id] = incoming.photoPath!;
      }
    }

    final tasks = <MaintenanceTask>[];
    final taskIdMap = <String, String>{};
    final taskIds = <String>{
      ...existingTasks.map((item) => item.id),
      ...backup.maintenanceTasks.map((item) => item.id),
    };
    final existingTasksById = {for (final item in existingTasks) item.id: item};
    for (final incoming in backup.maintenanceTasks) {
      final mapped = incoming.copyWith(tankId: tankIdMap[incoming.tankId]);
      final existing = existingTasksById[incoming.id];
      if (existing != null && existing == mapped) {
        taskIdMap[incoming.id] = existing.id;
        continue;
      }
      final id = existing == null ? incoming.id : _nextUniqueId(taskIds);
      tasks.add(mapped.copyWith(id: id));
      taskIdMap[incoming.id] = id;
      taskIds.add(id);
    }

    final events = <TaskEvent>[];
    final eventIds = <String>{
      ...existingEvents.map((item) => item.id),
      ...backup.taskEvents.map((item) => item.id),
    };
    final existingEventsById = {
      for (final item in existingEvents) item.id: item,
    };
    for (final incoming in backup.taskEvents) {
      final mapped = incoming.copyWith(taskId: taskIdMap[incoming.taskId]);
      final existing = existingEventsById[incoming.id];
      if (existing != null && existing == mapped) continue;
      final id = existing == null ? incoming.id : _nextUniqueId(eventIds);
      events.add(mapped.copyWith(id: id));
      eventIds.add(id);
    }

    final timerDefaults = <TestTimerDefault>[];
    final timerScopes = <String>{
      ...existingTimerDefaults.map(
        (item) => _scopeKey(item.tankId, item.parameterId),
      ),
    };
    for (final incoming in backup.testTimerDefaults) {
      final mapped = incoming.copyWith(
        tankId: tankIdMap[incoming.tankId],
        parameterId: parameterIdMap[incoming.parameterId],
      );
      if (timerScopes.add(_scopeKey(mapped.tankId, mapped.parameterId))) {
        timerDefaults.add(mapped);
      }
    }

    final sessions = <ActiveTestSession>[];
    final sessionPhotoSources = <String, String>{};
    final sessionIds = <String>{
      ...existingSessions.map((item) => item.id),
      ...backup.activeTestSessions.map((item) => item.id),
    };
    final sessionScopes = <String>{
      ...existingSessions.map(
        (item) => _scopeKey(item.tankId, item.parameterId),
      ),
    };
    final existingSessionsById = {
      for (final item in existingSessions) item.id: item,
    };
    for (final incoming in backup.activeTestSessions) {
      final mappedTankId = tankIdMap[incoming.tankId]!;
      final mappedParameterId = parameterIdMap[incoming.parameterId]!;
      if (!sessionScopes.add(_scopeKey(mappedTankId, mappedParameterId))) {
        continue;
      }
      final mapped = incoming.copyWith(
        tankId: mappedTankId,
        parameterId: mappedParameterId,
        reagentProfileId: Value(
          incoming.reagentProfileId == null
              ? null
              : reagentIdMap[incoming.reagentProfileId],
        ),
      );
      final existing = existingSessionsById[incoming.id];
      final id = existing == null ? incoming.id : _nextUniqueId(sessionIds);
      final inserted = mapped.copyWith(id: id);
      sessions.add(inserted);
      sessionIds.add(id);
      if (incoming.draftPhotoPath != null) {
        sessionPhotoSources[id] = incoming.draftPhotoPath!;
      }
    }

    return LocalBackupMergePlan._(
      tanks: tanks,
      parameters: parameters,
      tankParameters: tankParameters,
      targets: targets,
      reagents: reagents,
      records: records,
      tasks: tasks,
      events: events,
      timerDefaults: timerDefaults,
      sessions: sessions,
      recordPhotoSources: recordPhotoSources,
      sessionPhotoSources: sessionPhotoSources,
      photoDestinationsBySource: {
        for (final path in {
          ...recordPhotoSources.values,
          ...sessionPhotoSources.values,
        })
          path: path,
      },
    );
  }

  /// Commits a previously prepared plan using strict inserts in one database
  /// transaction. A concurrent conflict fails the whole transaction.
  Future<LocalBackupRestoreResult> restorePreparedMerge(
    LocalBackupMergePlan plan,
  ) async {
    await _database.transaction(() async {
      await _database.batch((batch) {
        if (plan._tanks.isNotEmpty) {
          batch.insertAll(_database.tanks, plan._tanks);
        }
        if (plan._parameters.isNotEmpty) {
          batch.insertAll(_database.waterParameters, plan._parameters);
        }
        if (plan._tankParameters.isNotEmpty) {
          batch.insertAll(_database.tankParameters, plan._tankParameters);
        }
        if (plan._targets.isNotEmpty) {
          batch.insertAll(_database.waterQualityTargets, plan._targets);
        }
        if (plan._reagents.isNotEmpty) {
          batch.insertAll(_database.reagentProfiles, plan._reagents);
        }
        if (plan._records.isNotEmpty) {
          batch.insertAll(_database.testRecords, plan._records);
        }
        if (plan._tasks.isNotEmpty) {
          batch.insertAll(_database.maintenanceTasks, plan._tasks);
        }
        if (plan._events.isNotEmpty) {
          batch.insertAll(_database.taskEvents, plan._events);
        }
        if (plan._timerDefaults.isNotEmpty) {
          batch.insertAll(_database.testTimerDefaults, plan._timerDefaults);
        }
        if (plan._sessions.isNotEmpty) {
          batch.insertAll(_database.activeTestSessions, plan._sessions);
        }
      });
    });
    return LocalBackupRestoreResult(
      insertedTankCount: plan._tanks.length,
      insertedRecordCount: plan._records.length,
      insertedTaskCount: plan._tasks.length,
      photoTransfers: plan.photoTransfers,
    );
  }

  String _nextUniqueId(Set<String> used) {
    for (var attempt = 0; attempt < 100; attempt++) {
      final candidate = _idGenerator().trim();
      if (candidate.isNotEmpty && used.add(candidate)) return candidate;
    }
    throw StateError('无法生成不冲突的恢复 ID');
  }

  String _nextUniqueParameterCode(String source, Set<String> used) {
    for (var suffix = 1; suffix <= 9999; suffix++) {
      final candidate = '${source}_RESTORED_$suffix';
      if (!used.contains(candidate.toUpperCase())) return candidate;
    }
    throw StateError('无法生成不冲突的参数简称');
  }
}

class LocalBackupPhotoTransfer {
  const LocalBackupPhotoTransfer({
    required this.sourcePath,
    required this.destinationPath,
  });

  final String sourcePath;
  final String destinationPath;
}

class LocalBackupRestoreResult {
  const LocalBackupRestoreResult({
    required this.insertedTankCount,
    required this.insertedRecordCount,
    required this.insertedTaskCount,
    required this.photoTransfers,
  });

  final int insertedTankCount;
  final int insertedRecordCount;
  final int insertedTaskCount;
  final List<LocalBackupPhotoTransfer> photoTransfers;
}

class LocalBackupMergePlan {
  LocalBackupMergePlan._({
    required List<Tank> tanks,
    required List<WaterParameter> parameters,
    required List<TankParameter> tankParameters,
    required List<WaterQualityTarget> targets,
    required List<ReagentProfile> reagents,
    required List<TestRecord> records,
    required List<MaintenanceTask> tasks,
    required List<TaskEvent> events,
    required List<TestTimerDefault> timerDefaults,
    required List<ActiveTestSession> sessions,
    required Map<String, String> recordPhotoSources,
    required Map<String, String> sessionPhotoSources,
    required Map<String, String?> photoDestinationsBySource,
  }) : _tanks = List.unmodifiable(tanks),
       _parameters = List.unmodifiable(parameters),
       _tankParameters = List.unmodifiable(tankParameters),
       _targets = List.unmodifiable(targets),
       _reagents = List.unmodifiable(reagents),
       _records = List.unmodifiable(records),
       _tasks = List.unmodifiable(tasks),
       _events = List.unmodifiable(events),
       _timerDefaults = List.unmodifiable(timerDefaults),
       _sessions = List.unmodifiable(sessions),
       _recordPhotoSources = Map.unmodifiable(recordPhotoSources),
       _sessionPhotoSources = Map.unmodifiable(sessionPhotoSources),
       _photoDestinationsBySource = Map.unmodifiable(photoDestinationsBySource);

  final List<Tank> _tanks;
  final List<WaterParameter> _parameters;
  final List<TankParameter> _tankParameters;
  final List<WaterQualityTarget> _targets;
  final List<ReagentProfile> _reagents;
  final List<TestRecord> _records;
  final List<MaintenanceTask> _tasks;
  final List<TaskEvent> _events;
  final List<TestTimerDefault> _timerDefaults;
  final List<ActiveTestSession> _sessions;
  final Map<String, String> _recordPhotoSources;
  final Map<String, String> _sessionPhotoSources;
  final Map<String, String?> _photoDestinationsBySource;

  List<LocalBackupPhotoTransfer> get photoTransfers {
    return [
      for (final entry in _photoDestinationsBySource.entries)
        if (entry.value != null)
          LocalBackupPhotoTransfer(
            sourcePath: entry.key,
            destinationPath: entry.value!,
          ),
    ];
  }

  /// Rewrites photo references for the rows that this plan will actually
  /// insert. A null destination intentionally restores the numeric draft or
  /// record without a photo (for an explicitly omitted backup photo).
  LocalBackupMergePlan withPhotoDestinations(
    Map<String, String?> destinations,
  ) {
    final sources = _photoDestinationsBySource.keys.toSet();
    if (destinations.keys.any((path) => !sources.contains(path))) {
      throw ArgumentError('照片映射包含未导入的源路径');
    }
    final merged = <String, String?>{
      ..._photoDestinationsBySource,
      ...destinations,
    };
    final nonNullDestinations = merged.values.whereType<String>().toList();
    if (nonNullDestinations.any((path) => !_validManagedPhotoPath(path)) ||
        nonNullDestinations.toSet().length != nonNullDestinations.length) {
      throw ArgumentError('照片目标路径无效或重复');
    }
    final records = [
      for (final record in _records)
        _recordWithMappedPhoto(record, _recordPhotoSources[record.id], merged),
    ];
    final sessions = [
      for (final session in _sessions)
        _sessionWithMappedPhoto(
          session,
          _sessionPhotoSources[session.id],
          merged,
        ),
    ];
    return LocalBackupMergePlan._(
      tanks: _tanks,
      parameters: _parameters,
      tankParameters: _tankParameters,
      targets: _targets,
      reagents: _reagents,
      records: records,
      tasks: _tasks,
      events: _events,
      timerDefaults: _timerDefaults,
      sessions: sessions,
      recordPhotoSources: _recordPhotoSources,
      sessionPhotoSources: _sessionPhotoSources,
      photoDestinationsBySource: merged,
    );
  }
}

TestRecord _recordWithMappedPhoto(
  TestRecord record,
  String? source,
  Map<String, String?> destinations,
) {
  return source == null
      ? record
      : record.copyWith(photoPath: Value(destinations[source]));
}

ActiveTestSession _sessionWithMappedPhoto(
  ActiveTestSession session,
  String? source,
  Map<String, String?> destinations,
) {
  return source == null
      ? session
      : session.copyWith(draftPhotoPath: Value(destinations[source]));
}

bool _sameTankContent(Tank first, Tank second) {
  return first.name == second.name &&
      first.notes == second.notes &&
      first.isArchived == second.isArchived;
}

bool _sameParameterContent(WaterParameter first, WaterParameter second) {
  return first.code.toUpperCase() == second.code.toUpperCase() &&
      first.displayName == second.displayName &&
      first.unit == second.unit &&
      first.isBuiltIn == second.isBuiltIn &&
      first.photoSupported == second.photoSupported;
}

bool _sameReagentContent(ReagentProfile first, ReagentProfile second) {
  return first.brand == second.brand &&
      first.parameterId == second.parameterId &&
      first.unit == second.unit &&
      first.colorLevelsJson == second.colorLevelsJson &&
      first.defaultDevelopmentSeconds == second.defaultDevelopmentSeconds &&
      first.cardVersion == second.cardVersion &&
      first.isEnabled == second.isEnabled;
}

bool _sameRecordContent(TestRecord first, TestRecord second) {
  // Drift may materialize the same instant with a different `isUtc` flag.
  // Compare the canonical backup representation so an idempotent restore
  // does not manufacture a second record (and copy its photo again).
  return jsonEncode(first.toJson(serializer: _backupValueSerializer)) ==
      jsonEncode(second.toJson(serializer: _backupValueSerializer));
}

_DecodedLocalBackup _decodeAndValidateBackup(String source) {
  final decodedValue = jsonDecode(source);
  if (decodedValue is! Map) throw const FormatException('不支持的备份格式');
  final decoded = Map<String, dynamic>.from(decodedValue);
  final sourceVersion = decoded['formatVersion'];
  if (sourceVersion is! int || sourceVersion < 1 || sourceVersion > 10) {
    throw const FormatException('不支持的备份格式');
  }
  late final List<Tank> tanks;
  late final List<WaterParameter> parameters;
  late final List<TankParameter> tankParameters;
  late final List<WaterQualityTarget> targets;
  late final List<ReagentProfile> reagents;
  late final List<AppPreference> preferences;
  late final List<TestRecord> records;
  late final List<MaintenanceTask> maintenanceTasks;
  late final List<TaskEvent> taskEvents;
  late final List<TestTimerDefault> testTimerDefaults;
  late final List<ActiveTestSession> activeTestSessions;
  try {
    tanks = _list(decoded, 'tanks')
        .map((item) => Tank.fromJson(item, serializer: _backupValueSerializer))
        .toList();
    parameters = _list(decoded, 'waterParameters')
        .map(
          (item) =>
              WaterParameter.fromJson(
                item,
                serializer: _backupValueSerializer,
              ).copyWith(
                photoSupported:
                    item['code'] == 'PO4' && item['isBuiltIn'] == true
                    ? true
                    : item['photoSupported'] as bool?,
              ),
        )
        .toList();
    tankParameters = _list(decoded, 'tankParameters')
        .map(
          (item) =>
              TankParameter.fromJson(item, serializer: _backupValueSerializer),
        )
        .toList();
    targets = _list(decoded, 'waterQualityTargets')
        .map(
          (item) => WaterQualityTarget.fromJson(
            item,
            serializer: _backupValueSerializer,
          ),
        )
        .toList();
    reagents = _list(decoded, 'reagentProfiles')
        .map(
          (item) =>
              ReagentProfile.fromJson(item, serializer: _backupValueSerializer),
        )
        .toList();
    preferences = _list(decoded, 'appPreferences')
        .map(
          (item) => AppPreference.fromJson(
            _upgradeLegacyPreference(item, sourceVersion),
            serializer: _backupValueSerializer,
          ),
        )
        .toList();
    records = sourceVersion == 1
        ? <TestRecord>[]
        : _list(decoded, 'testRecords')
              .map(
                (item) => TestRecord.fromJson(
                  sourceVersion < 4 ? _upgradeLegacyTestRecord(item) : item,
                  serializer: _backupValueSerializer,
                ),
              )
              .toList();
    maintenanceTasks = sourceVersion >= 3
        ? _list(decoded, 'maintenanceTasks')
              .map(
                (item) => MaintenanceTask.fromJson(
                  sourceVersion < 7
                      ? _upgradeLegacyMaintenanceTask(item)
                      : item,
                  serializer: _backupValueSerializer,
                ),
              )
              .toList()
        : <MaintenanceTask>[];
    taskEvents = sourceVersion >= 3
        ? _list(decoded, 'taskEvents')
              .map(
                (item) => TaskEvent.fromJson(
                  item,
                  serializer: _backupValueSerializer,
                ),
              )
              .toList()
        : <TaskEvent>[];
    testTimerDefaults = sourceVersion >= 4
        ? _list(decoded, 'testTimerDefaults')
              .map(
                (item) => TestTimerDefault.fromJson(
                  item,
                  serializer: _backupValueSerializer,
                ),
              )
              .toList()
        : <TestTimerDefault>[];
    activeTestSessions = sourceVersion >= 4
        ? _list(decoded, 'activeTestSessions')
              .map(
                (item) => ActiveTestSession.fromJson(
                  sourceVersion < 5
                      ? _upgradeLegacyActiveTestSession(item)
                      : item,
                  serializer: _backupValueSerializer,
                ),
              )
              .toList()
        : <ActiveTestSession>[];
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('备份字段类型或必填字段无效');
  }

  late final List<FishStockItem> fishStock;
  try {
    if (preferences.length != 1) {
      throw const FormatException('鱼类档案缺少应用偏好');
    }
    fishStock = FishStockCodec.decode(preferences.single.fishStockJson);
  } on FormatException {
    rethrow;
  } on Object {
    throw const FormatException('鱼类档案格式无效');
  }

  final tankIds = tanks.map((item) => item.id).toSet();
  final activeTankIds = tanks
      .where((item) => !item.isArchived)
      .map((item) => item.id)
      .toSet();
  final parameterIds = parameters.map((item) => item.id).toSet();
  final parametersById = {for (final item in parameters) item.id: item};
  final tankParameterScopes = {
    for (final item in tankParameters) _scopeKey(item.tankId, item.parameterId),
  };
  final reagentsById = {for (final item in reagents) item.id: item};
  final taskIds = maintenanceTasks.map((item) => item.id).toSet();
  if (activeTankIds.isEmpty ||
      parameterIds.isEmpty ||
      preferences.length != 1 ||
      preferences.single.id != 1 ||
      preferences.single.currentTankId == null ||
      !activeTankIds.contains(preferences.single.currentTankId) ||
      !_hasUniqueIds(tanks.map((item) => item.id)) ||
      !_hasUniqueIds(parameters.map((item) => item.id)) ||
      !_hasUniqueIds(
        parameters.map((item) => item.code.trim().toUpperCase()),
      ) ||
      !_hasUniqueIds(targets.map((item) => item.id)) ||
      !_hasUniqueIds(reagents.map((item) => item.id)) ||
      !_hasUniqueIds(records.map((item) => item.id)) ||
      !_hasUniqueIds(maintenanceTasks.map((item) => item.id)) ||
      !_hasUniqueIds(taskEvents.map((item) => item.id)) ||
      !_hasUniqueIds(activeTestSessions.map((item) => item.id)) ||
      !_hasUniqueIds(preferences.map((item) => item.id.toString())) ||
      tankParameterScopes.length != tankParameters.length ||
      _hasDuplicateTargetScopes(targets) ||
      !_hasUniqueIds(reagents.map((item) => item.id)) ||
      !_validUtcTimestamps(
        tanks: tanks,
        parameters: parameters,
        tankParameters: tankParameters,
        targets: targets,
        reagents: reagents,
        preferences: preferences,
        records: records,
        maintenanceTasks: maintenanceTasks,
        taskEvents: taskEvents,
        testTimerDefaults: testTimerDefaults,
        activeTestSessions: activeTestSessions,
      ) ||
      tankParameters.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            !parameterIds.contains(item.parameterId),
      ) ||
      activeTankIds.any(
        (tankId) => !tankParameters.any(
          (item) => item.tankId == tankId && item.isEnabled,
        ),
      ) ||
      targets.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            !parameterIds.contains(item.parameterId) ||
            !_validRequiredRange(item.minValue, item.maxValue) ||
            item.unit.trim().isEmpty ||
            item.unit != parametersById[item.parameterId]?.unit,
      ) ||
      reagents.any(
        (item) =>
            !parameterIds.contains(item.parameterId) ||
            item.defaultDevelopmentSeconds < 10 ||
            item.defaultDevelopmentSeconds > 3600 ||
            item.unit != parametersById[item.parameterId]?.unit,
      ) ||
      preferences.any(
        (item) =>
            (item.currentTankId != null &&
                !tankIds.contains(item.currentTankId)) ||
            !const {'system', 'light', 'dark'}.contains(item.themeMode),
      ) ||
      fishStock.any((item) => !tankIds.contains(item.tankId)) ||
      records.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            !parameterIds.contains(item.parameterId) ||
            !tankParameterScopes.contains(
              _scopeKey(item.tankId, item.parameterId),
            ) ||
            !_reagentMatchesParameter(
              item.reagentProfileId,
              item.parameterId,
              reagentsById,
            ) ||
            !_validRequiredRange(
              item.confirmedMinValue,
              item.confirmedMaxValue,
            ) ||
            !_validOptionalRange(
              item.estimatedMinValue,
              item.estimatedMaxValue,
            ) ||
            (item.confirmedInterpolation != null &&
                (!item.confirmedInterpolation!.isFinite ||
                    item.confirmedInterpolation! < item.confirmedMinValue ||
                    item.confirmedInterpolation! >
                        (item.confirmedMaxValue ?? item.confirmedMinValue))) ||
            (item.estimatedInterpolation != null &&
                (!item.estimatedInterpolation!.isFinite ||
                    item.estimatedMinValue == null ||
                    item.estimatedInterpolation! < item.estimatedMinValue! ||
                    item.estimatedInterpolation! >
                        (item.estimatedMaxValue ?? item.estimatedMinValue!))) ||
            (item.qualityScore != null &&
                (!item.qualityScore!.isFinite ||
                    item.qualityScore! < 0 ||
                    item.qualityScore! > 1)) ||
            item.unit != parametersById[item.parameterId]?.unit ||
            !_validManagedPhotoPath(item.photoPath),
      ) ||
      maintenanceTasks.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            item.intervalAmount <= 0 ||
            !const {'day', 'week', 'month'}.contains(item.intervalUnit) ||
            !const {
              'enabled',
              'disabled',
              'archived',
              'completed',
              'skipped',
            }.contains(item.status) ||
            ({'lanthanum-plan', 'alkalinity-plan'}.contains(item.source) &&
                (!item.isOneOff ||
                    item.planId == null ||
                    item.planId!.trim().isEmpty ||
                    item.planDayIndex == null ||
                    item.planDayIndex! <= 0 ||
                    item.planTotalDays == null ||
                    item.planTotalDays! < item.planDayIndex!)) ||
            !validRecurrence(item.recurrenceJson) ||
            (item.isOneOff && item.recurrenceJson != null) ||
            !_validReminderTime(item.preferredReminderTime),
      ) ||
      taskEvents.any(
        (item) =>
            !taskIds.contains(item.taskId) ||
            !const {'completed', 'skipped', 'snoozed'}.contains(item.type) ||
            (item.type == 'snoozed'
                ? item.snoozedUntil == null ||
                      !item.snoozedUntil!.isAfter(item.occurredAt)
                : item.snoozedUntil != null),
      ) ||
      testTimerDefaults.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            !parameterIds.contains(item.parameterId) ||
            !tankParameterScopes.contains(
              _scopeKey(item.tankId, item.parameterId),
            ) ||
            item.durationSeconds < 10 ||
            item.durationSeconds > 3600,
      ) ||
      activeTestSessions.any(
        (item) =>
            !tankIds.contains(item.tankId) ||
            !parameterIds.contains(item.parameterId) ||
            !tankParameterScopes.contains(
              _scopeKey(item.tankId, item.parameterId),
            ) ||
            !_reagentMatchesParameter(
              item.reagentProfileId,
              item.parameterId,
              reagentsById,
            ) ||
            item.timerDurationSeconds < 10 ||
            item.timerDurationSeconds > 3600 ||
            (item.pausedRemainingSeconds != null &&
                (item.pausedRemainingSeconds! < 0 ||
                    item.pausedRemainingSeconds! >
                        item.timerDurationSeconds)) ||
            !_validManagedPhotoPath(item.draftPhotoPath) ||
            !_validActiveSession(item),
      ) ||
      _hasDuplicateTimerDefaultScopes(testTimerDefaults) ||
      _hasDuplicateSessionScopes(activeTestSessions)) {
    throw const FormatException('备份内存在无效关联');
  }

  return _DecodedLocalBackup(
    tanks: tanks,
    parameters: parameters,
    tankParameters: tankParameters,
    targets: targets,
    reagents: reagents,
    preferences: preferences,
    records: [
      for (final record in records)
        record.copyWith(photoPath: const Value(null)),
    ],
    maintenanceTasks: [
      for (final task in maintenanceTasks)
        task.copyWith(notificationId: const Value(null)),
    ],
    taskEvents: taskEvents,
    testTimerDefaults: testTimerDefaults,
    activeTestSessions: [
      for (final session in activeTestSessions)
        session.copyWith(draftPhotoPath: const Value(null)),
    ],
  );
}

class _DecodedLocalBackup {
  const _DecodedLocalBackup({
    required this.tanks,
    required this.parameters,
    required this.tankParameters,
    required this.targets,
    required this.reagents,
    required this.preferences,
    required this.records,
    required this.maintenanceTasks,
    required this.taskEvents,
    required this.testTimerDefaults,
    required this.activeTestSessions,
  });

  final List<Tank> tanks;
  final List<WaterParameter> parameters;
  final List<TankParameter> tankParameters;
  final List<WaterQualityTarget> targets;
  final List<ReagentProfile> reagents;
  final List<AppPreference> preferences;
  final List<TestRecord> records;
  final List<MaintenanceTask> maintenanceTasks;
  final List<TaskEvent> taskEvents;
  final List<TestTimerDefault> testTimerDefaults;
  final List<ActiveTestSession> activeTestSessions;
}

Map<String, dynamic> _upgradeLegacyPreference(
  Map<String, dynamic> source,
  int sourceVersion,
) => <String, dynamic>{
  ...source,
  if (sourceVersion < 6) 'themeMode': 'system',
  if (sourceVersion < 7) 'maintenanceNotificationsEnabled': true,
  if (sourceVersion < 8) 'fishStockJson': '[]',
};

Map<String, dynamic> _upgradeLegacyMaintenanceTask(
  Map<String, dynamic> source,
) => <String, dynamic>{
  ...source,
  'isOneOff': false,
  'source': null,
  'planId': null,
  'planDayIndex': null,
  'planTotalDays': null,
};

Map<String, dynamic> _upgradeLegacyTestRecord(Map<String, dynamic> source) {
  return {
    ...source,
    'reagentProfileId': null,
    'capturedAt': null,
    'confirmedAt': source['measuredAt'],
    'qualityScore': null,
    'confidence': null,
    'failureReason': null,
    'wasManuallyEdited': false,
  };
}

Map<String, dynamic> _upgradeLegacyActiveTestSession(
  Map<String, dynamic> source,
) {
  return {...source, 'draftConfirmedAt': null};
}

bool _reagentMatchesParameter(
  String? reagentProfileId,
  String parameterId,
  Map<String, ReagentProfile> reagentsById,
) {
  if (reagentProfileId == null) return true;
  return reagentsById[reagentProfileId]?.parameterId == parameterId;
}

bool _hasDuplicateSessionScopes(List<ActiveTestSession> sessions) {
  final scopes = <String>{};
  for (final session in sessions) {
    if (!scopes.add(_scopeKey(session.tankId, session.parameterId))) {
      return true;
    }
  }
  return false;
}

bool _hasDuplicateTimerDefaultScopes(List<TestTimerDefault> defaults) {
  final scopes = <String>{};
  for (final item in defaults) {
    if (!scopes.add(_scopeKey(item.tankId, item.parameterId))) return true;
  }
  return false;
}

bool _hasDuplicateTargetScopes(List<WaterQualityTarget> targets) {
  final scopes = <String>{};
  for (final item in targets) {
    if (!scopes.add(_scopeKey(item.tankId, item.parameterId))) return true;
  }
  return false;
}

bool _hasUniqueIds(Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (id.isEmpty || !seen.add(id)) return false;
  }
  return true;
}

bool _validReminderTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  final minute = int.tryParse(match?.group(2) ?? '');
  return hour != null && minute != null && hour < 24 && minute < 60;
}

bool _validManagedPhotoPath(String? value) {
  if (value == null) return true;
  return value.startsWith('water_quality_photos/') &&
      value.length <= 512 &&
      !value.startsWith('/') &&
      !value.startsWith('\\') &&
      !value.contains('\\') &&
      !value.contains('\u0000') &&
      !RegExp(r'^[A-Za-z]:').hasMatch(value) &&
      value
          .split('/')
          .every((part) => part.isNotEmpty && part != '.' && part != '..');
}

bool _validUtcTimestamps({
  required List<Tank> tanks,
  required List<WaterParameter> parameters,
  required List<TankParameter> tankParameters,
  required List<WaterQualityTarget> targets,
  required List<ReagentProfile> reagents,
  required List<AppPreference> preferences,
  required List<TestRecord> records,
  required List<MaintenanceTask> maintenanceTasks,
  required List<TaskEvent> taskEvents,
  required List<TestTimerDefault> testTimerDefaults,
  required List<ActiveTestSession> activeTestSessions,
}) {
  bool utc(DateTime value) => value.isUtc;
  return tanks.every((item) => utc(item.createdAt) && utc(item.updatedAt)) &&
      parameters.every((item) => utc(item.createdAt)) &&
      tankParameters.every((item) => utc(item.updatedAt)) &&
      targets.every((item) => utc(item.updatedAt)) &&
      reagents.every((item) => utc(item.updatedAt)) &&
      preferences.every((item) => utc(item.updatedAt)) &&
      records.every(
        (item) =>
            utc(item.measuredAt) &&
            (item.capturedAt == null || utc(item.capturedAt!)) &&
            (item.confirmedAt == null || utc(item.confirmedAt!)) &&
            utc(item.createdAt) &&
            utc(item.updatedAt),
      ) &&
      maintenanceTasks.every(
        (item) => utc(item.dueAt) && utc(item.createdAt) && utc(item.updatedAt),
      ) &&
      taskEvents.every(
        (item) =>
            utc(item.occurredAt) &&
            (item.snoozedUntil == null || utc(item.snoozedUntil!)),
      ) &&
      testTimerDefaults.every((item) => utc(item.updatedAt)) &&
      activeTestSessions.every(
        (item) =>
            utc(item.startedAt) &&
            (item.timerEndsAt == null || utc(item.timerEndsAt!)) &&
            (item.draftCapturedAt == null || utc(item.draftCapturedAt!)) &&
            (item.draftConfirmedAt == null || utc(item.draftConfirmedAt!)) &&
            utc(item.createdAt) &&
            utc(item.updatedAt),
      );
}

bool _validActiveSession(ActiveTestSession session) {
  const stages = {
    'preparation',
    'timerRunning',
    'timerPaused',
    'timerCompleted',
    'photoReady',
    'review',
  };
  if (!stages.contains(session.stage) ||
      !_validOptionalRange(
        session.draftEstimatedMinValue,
        session.draftEstimatedMaxValue,
      ) ||
      !_validOptionalRange(
        session.draftConfirmedMinValue,
        session.draftConfirmedMaxValue,
      ) ||
      !_validPoint(
        session.draftConfirmedMinValue,
        session.draftConfirmedMaxValue,
        session.draftConfirmedInterpolation,
      ) ||
      !_validPoint(
        session.draftEstimatedMinValue,
        session.draftEstimatedMaxValue,
        session.draftEstimatedInterpolation,
      ) ||
      (session.draftQualityScore != null &&
          (!session.draftQualityScore!.isFinite ||
              session.draftQualityScore! < 0 ||
              session.draftQualityScore! > 1)) ||
      (session.draftConfidence != null &&
          !const {'low', 'medium', 'high'}.contains(session.draftConfidence))) {
    return false;
  }
  return switch (session.stage) {
    'timerRunning' =>
      session.timerEndsAt != null && session.pausedRemainingSeconds == null,
    'timerPaused' =>
      session.timerEndsAt == null &&
          session.pausedRemainingSeconds != null &&
          session.pausedRemainingSeconds! > 0,
    'timerCompleted' =>
      session.timerEndsAt == null && session.pausedRemainingSeconds == null,
    _ => session.timerEndsAt == null || session.pausedRemainingSeconds == null,
  };
}

bool _validOptionalRange(double? min, double? max) {
  if (min == null) return max == null;
  return min.isFinite &&
      min >= 0 &&
      (max == null || (max.isFinite && max >= min));
}

bool _validRequiredRange(double min, double? max) {
  return min.isFinite &&
      min >= 0 &&
      (max == null || (max.isFinite && max >= min));
}

String _scopeKey(String tankId, String parameterId) =>
    '$tankId\u0000$parameterId';

List<Map<String, dynamic>> _list(Map<String, dynamic> source, String key) {
  final value = source[key];
  if (value is! List) throw FormatException('备份缺少 $key');
  return value.map((item) {
    if (item is! Map<String, dynamic>) throw FormatException('$key 数据无效');
    return item;
  }).toList();
}

/// Drift's default JSON serializer writes [DateTime] values as Unix
/// milliseconds, but reads those integers back as local-time `DateTime`s.
/// Backup timestamps are absolute instants and must remain UTC so that the
/// strict validation below can distinguish them from ambiguous ISO strings
/// without a timezone. Keeping this serializer private also avoids changing
/// Drift serialization behavior elsewhere in the app.
class _UtcBackupValueSerializer extends ValueSerializer {
  const _UtcBackupValueSerializer();

  @override
  T fromJson<T>(dynamic json) {
    if (json == null) return null as T;
    final typeList = <T>[];
    if (typeList is List<DateTime?>) {
      if (json is int) {
        return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true) as T;
      }
      if (json is String) {
        final parsed = DateTime.tryParse(json);
        if (parsed != null && parsed.isUtc) return parsed as T;
      }
      throw const FormatException('备份时间必须包含时区');
    }
    if (typeList is List<double?> && json is int) return json.toDouble() as T;
    return json as T;
  }

  @override
  dynamic toJson<T>(T value) {
    if (value is DateTime) return value.toUtc().millisecondsSinceEpoch;
    return value;
  }
}

bool _validPoint(double? min, double? max, double? point) =>
    point == null ||
    (min != null && point.isFinite && point >= min && point <= (max ?? min));
