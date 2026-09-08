// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TanksTable extends Tanks with TableInfo<$TanksTable, Tank> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TanksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedOnMeta = const VerificationMeta(
    'startedOn',
  );
  @override
  late final GeneratedColumn<String> startedOn = GeneratedColumn<String>(
    'started_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeLitersMeta = const VerificationMeta(
    'volumeLiters',
  );
  @override
  late final GeneratedColumn<double> volumeLiters = GeneratedColumn<double>(
    'volume_liters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    notes,
    startedOn,
    volumeLiters,
    isArchived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tanks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tank> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('started_on')) {
      context.handle(
        _startedOnMeta,
        startedOn.isAcceptableOrUnknown(data['started_on']!, _startedOnMeta),
      );
    }
    if (data.containsKey('volume_liters')) {
      context.handle(
        _volumeLitersMeta,
        volumeLiters.isAcceptableOrUnknown(
          data['volume_liters']!,
          _volumeLitersMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tank map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tank(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_on'],
      ),
      volumeLiters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume_liters'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TanksTable createAlias(String alias) {
    return $TanksTable(attachedDatabase, alias);
  }
}

class Tank extends DataClass implements Insertable<Tank> {
  final String id;
  final String name;
  final String? notes;
  final String? startedOn;
  final double? volumeLiters;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Tank({
    required this.id,
    required this.name,
    this.notes,
    this.startedOn,
    this.volumeLiters,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || startedOn != null) {
      map['started_on'] = Variable<String>(startedOn);
    }
    if (!nullToAbsent || volumeLiters != null) {
      map['volume_liters'] = Variable<double>(volumeLiters);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TanksCompanion toCompanion(bool nullToAbsent) {
    return TanksCompanion(
      id: Value(id),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startedOn: startedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(startedOn),
      volumeLiters: volumeLiters == null && nullToAbsent
          ? const Value.absent()
          : Value(volumeLiters),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Tank.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tank(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      startedOn: serializer.fromJson<String?>(json['startedOn']),
      volumeLiters: serializer.fromJson<double?>(json['volumeLiters']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'startedOn': serializer.toJson<String?>(startedOn),
      'volumeLiters': serializer.toJson<double?>(volumeLiters),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Tank copyWith({
    String? id,
    String? name,
    Value<String?> notes = const Value.absent(),
    Value<String?> startedOn = const Value.absent(),
    Value<double?> volumeLiters = const Value.absent(),
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Tank(
    id: id ?? this.id,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    startedOn: startedOn.present ? startedOn.value : this.startedOn,
    volumeLiters: volumeLiters.present ? volumeLiters.value : this.volumeLiters,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Tank copyWithCompanion(TanksCompanion data) {
    return Tank(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      volumeLiters: data.volumeLiters.present
          ? data.volumeLiters.value
          : this.volumeLiters,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tank(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('startedOn: $startedOn, ')
          ..write('volumeLiters: $volumeLiters, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    notes,
    startedOn,
    volumeLiters,
    isArchived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tank &&
          other.id == this.id &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.startedOn == this.startedOn &&
          other.volumeLiters == this.volumeLiters &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TanksCompanion extends UpdateCompanion<Tank> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> notes;
  final Value<String?> startedOn;
  final Value<double?> volumeLiters;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TanksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.volumeLiters = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TanksCompanion.insert({
    required String id,
    required String name,
    this.notes = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.volumeLiters = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Tank> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<String>? startedOn,
    Expression<double>? volumeLiters,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (startedOn != null) 'started_on': startedOn,
      if (volumeLiters != null) 'volume_liters': volumeLiters,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TanksCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? notes,
    Value<String?>? startedOn,
    Value<double?>? volumeLiters,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TanksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      startedOn: startedOn ?? this.startedOn,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startedOn.present) {
      map['started_on'] = Variable<String>(startedOn.value);
    }
    if (volumeLiters.present) {
      map['volume_liters'] = Variable<double>(volumeLiters.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TanksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('startedOn: $startedOn, ')
          ..write('volumeLiters: $volumeLiters, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WaterParametersTable extends WaterParameters
    with TableInfo<$WaterParametersTable, WaterParameter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterParametersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
  );
  static const VerificationMeta _photoSupportedMeta = const VerificationMeta(
    'photoSupported',
  );
  @override
  late final GeneratedColumn<bool> photoSupported = GeneratedColumn<bool>(
    'photo_supported',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("photo_supported" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    displayName,
    unit,
    isBuiltIn,
    photoSupported,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_parameters';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterParameter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    } else if (isInserting) {
      context.missing(_isBuiltInMeta);
    }
    if (data.containsKey('photo_supported')) {
      context.handle(
        _photoSupportedMeta,
        photoSupported.isAcceptableOrUnknown(
          data['photo_supported']!,
          _photoSupportedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WaterParameter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterParameter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      photoSupported: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}photo_supported'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WaterParametersTable createAlias(String alias) {
    return $WaterParametersTable(attachedDatabase, alias);
  }
}

class WaterParameter extends DataClass implements Insertable<WaterParameter> {
  final String id;
  final String code;
  final String displayName;
  final String unit;
  final bool isBuiltIn;
  final bool photoSupported;
  final DateTime createdAt;
  const WaterParameter({
    required this.id,
    required this.code,
    required this.displayName,
    required this.unit,
    required this.isBuiltIn,
    required this.photoSupported,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['display_name'] = Variable<String>(displayName);
    map['unit'] = Variable<String>(unit);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    map['photo_supported'] = Variable<bool>(photoSupported);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WaterParametersCompanion toCompanion(bool nullToAbsent) {
    return WaterParametersCompanion(
      id: Value(id),
      code: Value(code),
      displayName: Value(displayName),
      unit: Value(unit),
      isBuiltIn: Value(isBuiltIn),
      photoSupported: Value(photoSupported),
      createdAt: Value(createdAt),
    );
  }

  factory WaterParameter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterParameter(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      displayName: serializer.fromJson<String>(json['displayName']),
      unit: serializer.fromJson<String>(json['unit']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      photoSupported: serializer.fromJson<bool>(json['photoSupported']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'displayName': serializer.toJson<String>(displayName),
      'unit': serializer.toJson<String>(unit),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'photoSupported': serializer.toJson<bool>(photoSupported),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WaterParameter copyWith({
    String? id,
    String? code,
    String? displayName,
    String? unit,
    bool? isBuiltIn,
    bool? photoSupported,
    DateTime? createdAt,
  }) => WaterParameter(
    id: id ?? this.id,
    code: code ?? this.code,
    displayName: displayName ?? this.displayName,
    unit: unit ?? this.unit,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    photoSupported: photoSupported ?? this.photoSupported,
    createdAt: createdAt ?? this.createdAt,
  );
  WaterParameter copyWithCompanion(WaterParametersCompanion data) {
    return WaterParameter(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      unit: data.unit.present ? data.unit.value : this.unit,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      photoSupported: data.photoSupported.present
          ? data.photoSupported.value
          : this.photoSupported,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterParameter(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('unit: $unit, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('photoSupported: $photoSupported, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    displayName,
    unit,
    isBuiltIn,
    photoSupported,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterParameter &&
          other.id == this.id &&
          other.code == this.code &&
          other.displayName == this.displayName &&
          other.unit == this.unit &&
          other.isBuiltIn == this.isBuiltIn &&
          other.photoSupported == this.photoSupported &&
          other.createdAt == this.createdAt);
}

class WaterParametersCompanion extends UpdateCompanion<WaterParameter> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> displayName;
  final Value<String> unit;
  final Value<bool> isBuiltIn;
  final Value<bool> photoSupported;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WaterParametersCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.displayName = const Value.absent(),
    this.unit = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.photoSupported = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WaterParametersCompanion.insert({
    required String id,
    required String code,
    required String displayName,
    required String unit,
    required bool isBuiltIn,
    this.photoSupported = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       displayName = Value(displayName),
       unit = Value(unit),
       isBuiltIn = Value(isBuiltIn),
       createdAt = Value(createdAt);
  static Insertable<WaterParameter> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? displayName,
    Expression<String>? unit,
    Expression<bool>? isBuiltIn,
    Expression<bool>? photoSupported,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (displayName != null) 'display_name': displayName,
      if (unit != null) 'unit': unit,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (photoSupported != null) 'photo_supported': photoSupported,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WaterParametersCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? displayName,
    Value<String>? unit,
    Value<bool>? isBuiltIn,
    Value<bool>? photoSupported,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WaterParametersCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      displayName: displayName ?? this.displayName,
      unit: unit ?? this.unit,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      photoSupported: photoSupported ?? this.photoSupported,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (photoSupported.present) {
      map['photo_supported'] = Variable<bool>(photoSupported.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterParametersCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('unit: $unit, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('photoSupported: $photoSupported, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TankParametersTable extends TankParameters
    with TableInfo<$TankParametersTable, TankParameter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TankParametersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tankId,
    parameterId,
    isEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tank_parameters';
  @override
  VerificationContext validateIntegrity(
    Insertable<TankParameter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tankId, parameterId};
  @override
  TankParameter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TankParameter(
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TankParametersTable createAlias(String alias) {
    return $TankParametersTable(attachedDatabase, alias);
  }
}

class TankParameter extends DataClass implements Insertable<TankParameter> {
  final String tankId;
  final String parameterId;
  final bool isEnabled;
  final DateTime updatedAt;
  const TankParameter({
    required this.tankId,
    required this.parameterId,
    required this.isEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tank_id'] = Variable<String>(tankId);
    map['parameter_id'] = Variable<String>(parameterId);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TankParametersCompanion toCompanion(bool nullToAbsent) {
    return TankParametersCompanion(
      tankId: Value(tankId),
      parameterId: Value(parameterId),
      isEnabled: Value(isEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory TankParameter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TankParameter(
      tankId: serializer.fromJson<String>(json['tankId']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tankId': serializer.toJson<String>(tankId),
      'parameterId': serializer.toJson<String>(parameterId),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TankParameter copyWith({
    String? tankId,
    String? parameterId,
    bool? isEnabled,
    DateTime? updatedAt,
  }) => TankParameter(
    tankId: tankId ?? this.tankId,
    parameterId: parameterId ?? this.parameterId,
    isEnabled: isEnabled ?? this.isEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TankParameter copyWithCompanion(TankParametersCompanion data) {
    return TankParameter(
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TankParameter(')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tankId, parameterId, isEnabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TankParameter &&
          other.tankId == this.tankId &&
          other.parameterId == this.parameterId &&
          other.isEnabled == this.isEnabled &&
          other.updatedAt == this.updatedAt);
}

class TankParametersCompanion extends UpdateCompanion<TankParameter> {
  final Value<String> tankId;
  final Value<String> parameterId;
  final Value<bool> isEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TankParametersCompanion({
    this.tankId = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TankParametersCompanion.insert({
    required String tankId,
    required String parameterId,
    this.isEnabled = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : tankId = Value(tankId),
       parameterId = Value(parameterId),
       updatedAt = Value(updatedAt);
  static Insertable<TankParameter> custom({
    Expression<String>? tankId,
    Expression<String>? parameterId,
    Expression<bool>? isEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tankId != null) 'tank_id': tankId,
      if (parameterId != null) 'parameter_id': parameterId,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TankParametersCompanion copyWith({
    Value<String>? tankId,
    Value<String>? parameterId,
    Value<bool>? isEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TankParametersCompanion(
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TankParametersCompanion(')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WaterQualityTargetsTable extends WaterQualityTargets
    with TableInfo<$WaterQualityTargetsTable, WaterQualityTarget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterQualityTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _minValueMeta = const VerificationMeta(
    'minValue',
  );
  @override
  late final GeneratedColumn<double> minValue = GeneratedColumn<double>(
    'min_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxValueMeta = const VerificationMeta(
    'maxValue',
  );
  @override
  late final GeneratedColumn<double> maxValue = GeneratedColumn<double>(
    'max_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    parameterId,
    minValue,
    maxValue,
    unit,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_quality_targets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterQualityTarget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('min_value')) {
      context.handle(
        _minValueMeta,
        minValue.isAcceptableOrUnknown(data['min_value']!, _minValueMeta),
      );
    }
    if (data.containsKey('max_value')) {
      context.handle(
        _maxValueMeta,
        maxValue.isAcceptableOrUnknown(data['max_value']!, _maxValueMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tankId, parameterId},
  ];
  @override
  WaterQualityTarget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterQualityTarget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      minValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_value'],
      ),
      maxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_value'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WaterQualityTargetsTable createAlias(String alias) {
    return $WaterQualityTargetsTable(attachedDatabase, alias);
  }
}

class WaterQualityTarget extends DataClass
    implements Insertable<WaterQualityTarget> {
  final String id;
  final String tankId;
  final String parameterId;
  final double? minValue;
  final double? maxValue;
  final String unit;
  final DateTime updatedAt;
  const WaterQualityTarget({
    required this.id,
    required this.tankId,
    required this.parameterId,
    this.minValue,
    this.maxValue,
    required this.unit,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tank_id'] = Variable<String>(tankId);
    map['parameter_id'] = Variable<String>(parameterId);
    if (!nullToAbsent || minValue != null) {
      map['min_value'] = Variable<double>(minValue);
    }
    if (!nullToAbsent || maxValue != null) {
      map['max_value'] = Variable<double>(maxValue);
    }
    map['unit'] = Variable<String>(unit);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WaterQualityTargetsCompanion toCompanion(bool nullToAbsent) {
    return WaterQualityTargetsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      parameterId: Value(parameterId),
      minValue: minValue == null && nullToAbsent
          ? const Value.absent()
          : Value(minValue),
      maxValue: maxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(maxValue),
      unit: Value(unit),
      updatedAt: Value(updatedAt),
    );
  }

  factory WaterQualityTarget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterQualityTarget(
      id: serializer.fromJson<String>(json['id']),
      tankId: serializer.fromJson<String>(json['tankId']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      minValue: serializer.fromJson<double?>(json['minValue']),
      maxValue: serializer.fromJson<double?>(json['maxValue']),
      unit: serializer.fromJson<String>(json['unit']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tankId': serializer.toJson<String>(tankId),
      'parameterId': serializer.toJson<String>(parameterId),
      'minValue': serializer.toJson<double?>(minValue),
      'maxValue': serializer.toJson<double?>(maxValue),
      'unit': serializer.toJson<String>(unit),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WaterQualityTarget copyWith({
    String? id,
    String? tankId,
    String? parameterId,
    Value<double?> minValue = const Value.absent(),
    Value<double?> maxValue = const Value.absent(),
    String? unit,
    DateTime? updatedAt,
  }) => WaterQualityTarget(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    parameterId: parameterId ?? this.parameterId,
    minValue: minValue.present ? minValue.value : this.minValue,
    maxValue: maxValue.present ? maxValue.value : this.maxValue,
    unit: unit ?? this.unit,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WaterQualityTarget copyWithCompanion(WaterQualityTargetsCompanion data) {
    return WaterQualityTarget(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      minValue: data.minValue.present ? data.minValue.value : this.minValue,
      maxValue: data.maxValue.present ? data.maxValue.value : this.maxValue,
      unit: data.unit.present ? data.unit.value : this.unit,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterQualityTarget(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('minValue: $minValue, ')
          ..write('maxValue: $maxValue, ')
          ..write('unit: $unit, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tankId, parameterId, minValue, maxValue, unit, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterQualityTarget &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.parameterId == this.parameterId &&
          other.minValue == this.minValue &&
          other.maxValue == this.maxValue &&
          other.unit == this.unit &&
          other.updatedAt == this.updatedAt);
}

class WaterQualityTargetsCompanion extends UpdateCompanion<WaterQualityTarget> {
  final Value<String> id;
  final Value<String> tankId;
  final Value<String> parameterId;
  final Value<double?> minValue;
  final Value<double?> maxValue;
  final Value<String> unit;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WaterQualityTargetsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.minValue = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WaterQualityTargetsCompanion.insert({
    required String id,
    required String tankId,
    required String parameterId,
    this.minValue = const Value.absent(),
    this.maxValue = const Value.absent(),
    required String unit,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tankId = Value(tankId),
       parameterId = Value(parameterId),
       unit = Value(unit),
       updatedAt = Value(updatedAt);
  static Insertable<WaterQualityTarget> custom({
    Expression<String>? id,
    Expression<String>? tankId,
    Expression<String>? parameterId,
    Expression<double>? minValue,
    Expression<double>? maxValue,
    Expression<String>? unit,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (parameterId != null) 'parameter_id': parameterId,
      if (minValue != null) 'min_value': minValue,
      if (maxValue != null) 'max_value': maxValue,
      if (unit != null) 'unit': unit,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WaterQualityTargetsCompanion copyWith({
    Value<String>? id,
    Value<String>? tankId,
    Value<String>? parameterId,
    Value<double?>? minValue,
    Value<double?>? maxValue,
    Value<String>? unit,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WaterQualityTargetsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      unit: unit ?? this.unit,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (minValue.present) {
      map['min_value'] = Variable<double>(minValue.value);
    }
    if (maxValue.present) {
      map['max_value'] = Variable<double>(maxValue.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterQualityTargetsCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('minValue: $minValue, ')
          ..write('maxValue: $maxValue, ')
          ..write('unit: $unit, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReagentProfilesTable extends ReagentProfiles
    with TableInfo<$ReagentProfilesTable, ReagentProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReagentProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorLevelsJsonMeta = const VerificationMeta(
    'colorLevelsJson',
  );
  @override
  late final GeneratedColumn<String> colorLevelsJson = GeneratedColumn<String>(
    'color_levels_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultDevelopmentSecondsMeta =
      const VerificationMeta('defaultDevelopmentSeconds');
  @override
  late final GeneratedColumn<int> defaultDevelopmentSeconds =
      GeneratedColumn<int>(
        'default_development_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _cardVersionMeta = const VerificationMeta(
    'cardVersion',
  );
  @override
  late final GeneratedColumn<String> cardVersion = GeneratedColumn<String>(
    'card_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    brand,
    parameterId,
    unit,
    colorLevelsJson,
    defaultDevelopmentSeconds,
    cardVersion,
    isEnabled,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reagent_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReagentProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(
        _brandMeta,
        brand.isAcceptableOrUnknown(data['brand']!, _brandMeta),
      );
    } else if (isInserting) {
      context.missing(_brandMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('color_levels_json')) {
      context.handle(
        _colorLevelsJsonMeta,
        colorLevelsJson.isAcceptableOrUnknown(
          data['color_levels_json']!,
          _colorLevelsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_colorLevelsJsonMeta);
    }
    if (data.containsKey('default_development_seconds')) {
      context.handle(
        _defaultDevelopmentSecondsMeta,
        defaultDevelopmentSeconds.isAcceptableOrUnknown(
          data['default_development_seconds']!,
          _defaultDevelopmentSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultDevelopmentSecondsMeta);
    }
    if (data.containsKey('card_version')) {
      context.handle(
        _cardVersionMeta,
        cardVersion.isAcceptableOrUnknown(
          data['card_version']!,
          _cardVersionMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReagentProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReagentProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      brand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}brand'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      colorLevelsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_levels_json'],
      )!,
      defaultDevelopmentSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_development_seconds'],
      )!,
      cardVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_version'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReagentProfilesTable createAlias(String alias) {
    return $ReagentProfilesTable(attachedDatabase, alias);
  }
}

class ReagentProfile extends DataClass implements Insertable<ReagentProfile> {
  final String id;
  final String brand;
  final String parameterId;
  final String unit;
  final String colorLevelsJson;
  final int defaultDevelopmentSeconds;
  final String? cardVersion;
  final bool isEnabled;
  final DateTime updatedAt;
  const ReagentProfile({
    required this.id,
    required this.brand,
    required this.parameterId,
    required this.unit,
    required this.colorLevelsJson,
    required this.defaultDevelopmentSeconds,
    this.cardVersion,
    required this.isEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['brand'] = Variable<String>(brand);
    map['parameter_id'] = Variable<String>(parameterId);
    map['unit'] = Variable<String>(unit);
    map['color_levels_json'] = Variable<String>(colorLevelsJson);
    map['default_development_seconds'] = Variable<int>(
      defaultDevelopmentSeconds,
    );
    if (!nullToAbsent || cardVersion != null) {
      map['card_version'] = Variable<String>(cardVersion);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReagentProfilesCompanion toCompanion(bool nullToAbsent) {
    return ReagentProfilesCompanion(
      id: Value(id),
      brand: Value(brand),
      parameterId: Value(parameterId),
      unit: Value(unit),
      colorLevelsJson: Value(colorLevelsJson),
      defaultDevelopmentSeconds: Value(defaultDevelopmentSeconds),
      cardVersion: cardVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(cardVersion),
      isEnabled: Value(isEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReagentProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReagentProfile(
      id: serializer.fromJson<String>(json['id']),
      brand: serializer.fromJson<String>(json['brand']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      unit: serializer.fromJson<String>(json['unit']),
      colorLevelsJson: serializer.fromJson<String>(json['colorLevelsJson']),
      defaultDevelopmentSeconds: serializer.fromJson<int>(
        json['defaultDevelopmentSeconds'],
      ),
      cardVersion: serializer.fromJson<String?>(json['cardVersion']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'brand': serializer.toJson<String>(brand),
      'parameterId': serializer.toJson<String>(parameterId),
      'unit': serializer.toJson<String>(unit),
      'colorLevelsJson': serializer.toJson<String>(colorLevelsJson),
      'defaultDevelopmentSeconds': serializer.toJson<int>(
        defaultDevelopmentSeconds,
      ),
      'cardVersion': serializer.toJson<String?>(cardVersion),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReagentProfile copyWith({
    String? id,
    String? brand,
    String? parameterId,
    String? unit,
    String? colorLevelsJson,
    int? defaultDevelopmentSeconds,
    Value<String?> cardVersion = const Value.absent(),
    bool? isEnabled,
    DateTime? updatedAt,
  }) => ReagentProfile(
    id: id ?? this.id,
    brand: brand ?? this.brand,
    parameterId: parameterId ?? this.parameterId,
    unit: unit ?? this.unit,
    colorLevelsJson: colorLevelsJson ?? this.colorLevelsJson,
    defaultDevelopmentSeconds:
        defaultDevelopmentSeconds ?? this.defaultDevelopmentSeconds,
    cardVersion: cardVersion.present ? cardVersion.value : this.cardVersion,
    isEnabled: isEnabled ?? this.isEnabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReagentProfile copyWithCompanion(ReagentProfilesCompanion data) {
    return ReagentProfile(
      id: data.id.present ? data.id.value : this.id,
      brand: data.brand.present ? data.brand.value : this.brand,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      unit: data.unit.present ? data.unit.value : this.unit,
      colorLevelsJson: data.colorLevelsJson.present
          ? data.colorLevelsJson.value
          : this.colorLevelsJson,
      defaultDevelopmentSeconds: data.defaultDevelopmentSeconds.present
          ? data.defaultDevelopmentSeconds.value
          : this.defaultDevelopmentSeconds,
      cardVersion: data.cardVersion.present
          ? data.cardVersion.value
          : this.cardVersion,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReagentProfile(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('parameterId: $parameterId, ')
          ..write('unit: $unit, ')
          ..write('colorLevelsJson: $colorLevelsJson, ')
          ..write('defaultDevelopmentSeconds: $defaultDevelopmentSeconds, ')
          ..write('cardVersion: $cardVersion, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    parameterId,
    unit,
    colorLevelsJson,
    defaultDevelopmentSeconds,
    cardVersion,
    isEnabled,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReagentProfile &&
          other.id == this.id &&
          other.brand == this.brand &&
          other.parameterId == this.parameterId &&
          other.unit == this.unit &&
          other.colorLevelsJson == this.colorLevelsJson &&
          other.defaultDevelopmentSeconds == this.defaultDevelopmentSeconds &&
          other.cardVersion == this.cardVersion &&
          other.isEnabled == this.isEnabled &&
          other.updatedAt == this.updatedAt);
}

class ReagentProfilesCompanion extends UpdateCompanion<ReagentProfile> {
  final Value<String> id;
  final Value<String> brand;
  final Value<String> parameterId;
  final Value<String> unit;
  final Value<String> colorLevelsJson;
  final Value<int> defaultDevelopmentSeconds;
  final Value<String?> cardVersion;
  final Value<bool> isEnabled;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReagentProfilesCompanion({
    this.id = const Value.absent(),
    this.brand = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.unit = const Value.absent(),
    this.colorLevelsJson = const Value.absent(),
    this.defaultDevelopmentSeconds = const Value.absent(),
    this.cardVersion = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReagentProfilesCompanion.insert({
    required String id,
    required String brand,
    required String parameterId,
    required String unit,
    required String colorLevelsJson,
    required int defaultDevelopmentSeconds,
    this.cardVersion = const Value.absent(),
    this.isEnabled = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       brand = Value(brand),
       parameterId = Value(parameterId),
       unit = Value(unit),
       colorLevelsJson = Value(colorLevelsJson),
       defaultDevelopmentSeconds = Value(defaultDevelopmentSeconds),
       updatedAt = Value(updatedAt);
  static Insertable<ReagentProfile> custom({
    Expression<String>? id,
    Expression<String>? brand,
    Expression<String>? parameterId,
    Expression<String>? unit,
    Expression<String>? colorLevelsJson,
    Expression<int>? defaultDevelopmentSeconds,
    Expression<String>? cardVersion,
    Expression<bool>? isEnabled,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (brand != null) 'brand': brand,
      if (parameterId != null) 'parameter_id': parameterId,
      if (unit != null) 'unit': unit,
      if (colorLevelsJson != null) 'color_levels_json': colorLevelsJson,
      if (defaultDevelopmentSeconds != null)
        'default_development_seconds': defaultDevelopmentSeconds,
      if (cardVersion != null) 'card_version': cardVersion,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReagentProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? brand,
    Value<String>? parameterId,
    Value<String>? unit,
    Value<String>? colorLevelsJson,
    Value<int>? defaultDevelopmentSeconds,
    Value<String?>? cardVersion,
    Value<bool>? isEnabled,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReagentProfilesCompanion(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      parameterId: parameterId ?? this.parameterId,
      unit: unit ?? this.unit,
      colorLevelsJson: colorLevelsJson ?? this.colorLevelsJson,
      defaultDevelopmentSeconds:
          defaultDevelopmentSeconds ?? this.defaultDevelopmentSeconds,
      cardVersion: cardVersion ?? this.cardVersion,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (colorLevelsJson.present) {
      map['color_levels_json'] = Variable<String>(colorLevelsJson.value);
    }
    if (defaultDevelopmentSeconds.present) {
      map['default_development_seconds'] = Variable<int>(
        defaultDevelopmentSeconds.value,
      );
    }
    if (cardVersion.present) {
      map['card_version'] = Variable<String>(cardVersion.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReagentProfilesCompanion(')
          ..write('id: $id, ')
          ..write('brand: $brand, ')
          ..write('parameterId: $parameterId, ')
          ..write('unit: $unit, ')
          ..write('colorLevelsJson: $colorLevelsJson, ')
          ..write('defaultDevelopmentSeconds: $defaultDevelopmentSeconds, ')
          ..write('cardVersion: $cardVersion, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentTankIdMeta = const VerificationMeta(
    'currentTankId',
  );
  @override
  late final GeneratedColumn<String> currentTankId = GeneratedColumn<String>(
    'current_tank_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _maintenanceNotificationsEnabledMeta =
      const VerificationMeta('maintenanceNotificationsEnabled');
  @override
  late final GeneratedColumn<bool> maintenanceNotificationsEnabled =
      GeneratedColumn<bool>(
        'maintenance_notifications_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("maintenance_notifications_enabled" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _fishStockJsonMeta = const VerificationMeta(
    'fishStockJson',
  );
  @override
  late final GeneratedColumn<String> fishStockJson = GeneratedColumn<String>(
    'fish_stock_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _khTargetDefaultsAppliedMeta =
      const VerificationMeta('khTargetDefaultsApplied');
  @override
  late final GeneratedColumn<bool> khTargetDefaultsApplied =
      GeneratedColumn<bool>(
        'kh_target_defaults_applied',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("kh_target_defaults_applied" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currentTankId,
    themeMode,
    maintenanceNotificationsEnabled,
    fishStockJson,
    khTargetDefaultsApplied,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_tank_id')) {
      context.handle(
        _currentTankIdMeta,
        currentTankId.isAcceptableOrUnknown(
          data['current_tank_id']!,
          _currentTankIdMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('maintenance_notifications_enabled')) {
      context.handle(
        _maintenanceNotificationsEnabledMeta,
        maintenanceNotificationsEnabled.isAcceptableOrUnknown(
          data['maintenance_notifications_enabled']!,
          _maintenanceNotificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('fish_stock_json')) {
      context.handle(
        _fishStockJsonMeta,
        fishStockJson.isAcceptableOrUnknown(
          data['fish_stock_json']!,
          _fishStockJsonMeta,
        ),
      );
    }
    if (data.containsKey('kh_target_defaults_applied')) {
      context.handle(
        _khTargetDefaultsAppliedMeta,
        khTargetDefaultsApplied.isAcceptableOrUnknown(
          data['kh_target_defaults_applied']!,
          _khTargetDefaultsAppliedMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreference(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentTankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_tank_id'],
      ),
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      maintenanceNotificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}maintenance_notifications_enabled'],
      )!,
      fishStockJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fish_stock_json'],
      )!,
      khTargetDefaultsApplied: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kh_target_defaults_applied'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreference extends DataClass implements Insertable<AppPreference> {
  final int id;
  final String? currentTankId;
  final String themeMode;
  final bool maintenanceNotificationsEnabled;
  final String fishStockJson;
  final bool khTargetDefaultsApplied;
  final DateTime updatedAt;
  const AppPreference({
    required this.id,
    this.currentTankId,
    required this.themeMode,
    required this.maintenanceNotificationsEnabled,
    required this.fishStockJson,
    required this.khTargetDefaultsApplied,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || currentTankId != null) {
      map['current_tank_id'] = Variable<String>(currentTankId);
    }
    map['theme_mode'] = Variable<String>(themeMode);
    map['maintenance_notifications_enabled'] = Variable<bool>(
      maintenanceNotificationsEnabled,
    );
    map['fish_stock_json'] = Variable<String>(fishStockJson);
    map['kh_target_defaults_applied'] = Variable<bool>(khTargetDefaultsApplied);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(
      id: Value(id),
      currentTankId: currentTankId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentTankId),
      themeMode: Value(themeMode),
      maintenanceNotificationsEnabled: Value(maintenanceNotificationsEnabled),
      fishStockJson: Value(fishStockJson),
      khTargetDefaultsApplied: Value(khTargetDefaultsApplied),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreference(
      id: serializer.fromJson<int>(json['id']),
      currentTankId: serializer.fromJson<String?>(json['currentTankId']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      maintenanceNotificationsEnabled: serializer.fromJson<bool>(
        json['maintenanceNotificationsEnabled'],
      ),
      fishStockJson: serializer.fromJson<String>(json['fishStockJson']),
      khTargetDefaultsApplied: serializer.fromJson<bool>(
        json['khTargetDefaultsApplied'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentTankId': serializer.toJson<String?>(currentTankId),
      'themeMode': serializer.toJson<String>(themeMode),
      'maintenanceNotificationsEnabled': serializer.toJson<bool>(
        maintenanceNotificationsEnabled,
      ),
      'fishStockJson': serializer.toJson<String>(fishStockJson),
      'khTargetDefaultsApplied': serializer.toJson<bool>(
        khTargetDefaultsApplied,
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppPreference copyWith({
    int? id,
    Value<String?> currentTankId = const Value.absent(),
    String? themeMode,
    bool? maintenanceNotificationsEnabled,
    String? fishStockJson,
    bool? khTargetDefaultsApplied,
    DateTime? updatedAt,
  }) => AppPreference(
    id: id ?? this.id,
    currentTankId: currentTankId.present
        ? currentTankId.value
        : this.currentTankId,
    themeMode: themeMode ?? this.themeMode,
    maintenanceNotificationsEnabled:
        maintenanceNotificationsEnabled ?? this.maintenanceNotificationsEnabled,
    fishStockJson: fishStockJson ?? this.fishStockJson,
    khTargetDefaultsApplied:
        khTargetDefaultsApplied ?? this.khTargetDefaultsApplied,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppPreference copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreference(
      id: data.id.present ? data.id.value : this.id,
      currentTankId: data.currentTankId.present
          ? data.currentTankId.value
          : this.currentTankId,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      maintenanceNotificationsEnabled:
          data.maintenanceNotificationsEnabled.present
          ? data.maintenanceNotificationsEnabled.value
          : this.maintenanceNotificationsEnabled,
      fishStockJson: data.fishStockJson.present
          ? data.fishStockJson.value
          : this.fishStockJson,
      khTargetDefaultsApplied: data.khTargetDefaultsApplied.present
          ? data.khTargetDefaultsApplied.value
          : this.khTargetDefaultsApplied,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreference(')
          ..write('id: $id, ')
          ..write('currentTankId: $currentTankId, ')
          ..write('themeMode: $themeMode, ')
          ..write(
            'maintenanceNotificationsEnabled: $maintenanceNotificationsEnabled, ',
          )
          ..write('fishStockJson: $fishStockJson, ')
          ..write('khTargetDefaultsApplied: $khTargetDefaultsApplied, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    currentTankId,
    themeMode,
    maintenanceNotificationsEnabled,
    fishStockJson,
    khTargetDefaultsApplied,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreference &&
          other.id == this.id &&
          other.currentTankId == this.currentTankId &&
          other.themeMode == this.themeMode &&
          other.maintenanceNotificationsEnabled ==
              this.maintenanceNotificationsEnabled &&
          other.fishStockJson == this.fishStockJson &&
          other.khTargetDefaultsApplied == this.khTargetDefaultsApplied &&
          other.updatedAt == this.updatedAt);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreference> {
  final Value<int> id;
  final Value<String?> currentTankId;
  final Value<String> themeMode;
  final Value<bool> maintenanceNotificationsEnabled;
  final Value<String> fishStockJson;
  final Value<bool> khTargetDefaultsApplied;
  final Value<DateTime> updatedAt;
  const AppPreferencesCompanion({
    this.id = const Value.absent(),
    this.currentTankId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.maintenanceNotificationsEnabled = const Value.absent(),
    this.fishStockJson = const Value.absent(),
    this.khTargetDefaultsApplied = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.currentTankId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.maintenanceNotificationsEnabled = const Value.absent(),
    this.fishStockJson = const Value.absent(),
    this.khTargetDefaultsApplied = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<AppPreference> custom({
    Expression<int>? id,
    Expression<String>? currentTankId,
    Expression<String>? themeMode,
    Expression<bool>? maintenanceNotificationsEnabled,
    Expression<String>? fishStockJson,
    Expression<bool>? khTargetDefaultsApplied,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentTankId != null) 'current_tank_id': currentTankId,
      if (themeMode != null) 'theme_mode': themeMode,
      if (maintenanceNotificationsEnabled != null)
        'maintenance_notifications_enabled': maintenanceNotificationsEnabled,
      if (fishStockJson != null) 'fish_stock_json': fishStockJson,
      if (khTargetDefaultsApplied != null)
        'kh_target_defaults_applied': khTargetDefaultsApplied,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<int>? id,
    Value<String?>? currentTankId,
    Value<String>? themeMode,
    Value<bool>? maintenanceNotificationsEnabled,
    Value<String>? fishStockJson,
    Value<bool>? khTargetDefaultsApplied,
    Value<DateTime>? updatedAt,
  }) {
    return AppPreferencesCompanion(
      id: id ?? this.id,
      currentTankId: currentTankId ?? this.currentTankId,
      themeMode: themeMode ?? this.themeMode,
      maintenanceNotificationsEnabled:
          maintenanceNotificationsEnabled ??
          this.maintenanceNotificationsEnabled,
      fishStockJson: fishStockJson ?? this.fishStockJson,
      khTargetDefaultsApplied:
          khTargetDefaultsApplied ?? this.khTargetDefaultsApplied,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentTankId.present) {
      map['current_tank_id'] = Variable<String>(currentTankId.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (maintenanceNotificationsEnabled.present) {
      map['maintenance_notifications_enabled'] = Variable<bool>(
        maintenanceNotificationsEnabled.value,
      );
    }
    if (fishStockJson.present) {
      map['fish_stock_json'] = Variable<String>(fishStockJson.value);
    }
    if (khTargetDefaultsApplied.present) {
      map['kh_target_defaults_applied'] = Variable<bool>(
        khTargetDefaultsApplied.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('currentTankId: $currentTankId, ')
          ..write('themeMode: $themeMode, ')
          ..write(
            'maintenanceNotificationsEnabled: $maintenanceNotificationsEnabled, ',
          )
          ..write('fishStockJson: $fishStockJson, ')
          ..write('khTargetDefaultsApplied: $khTargetDefaultsApplied, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TestRecordsTable extends TestRecords
    with TableInfo<$TestRecordsTable, TestRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _reagentProfileIdMeta = const VerificationMeta(
    'reagentProfileId',
  );
  @override
  late final GeneratedColumn<String> reagentProfileId = GeneratedColumn<String>(
    'reagent_profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reagent_profiles (id)',
    ),
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedMinValueMeta = const VerificationMeta(
    'estimatedMinValue',
  );
  @override
  late final GeneratedColumn<double> estimatedMinValue =
      GeneratedColumn<double>(
        'estimated_min_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estimatedMaxValueMeta = const VerificationMeta(
    'estimatedMaxValue',
  );
  @override
  late final GeneratedColumn<double> estimatedMaxValue =
      GeneratedColumn<double>(
        'estimated_max_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estimationMethodMeta = const VerificationMeta(
    'estimationMethod',
  );
  @override
  late final GeneratedColumn<String> estimationMethod = GeneratedColumn<String>(
    'estimation_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimationVersionMeta = const VerificationMeta(
    'estimationVersion',
  );
  @override
  late final GeneratedColumn<String> estimationVersion =
      GeneratedColumn<String>(
        'estimation_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _qualityScoreMeta = const VerificationMeta(
    'qualityScore',
  );
  @override
  late final GeneratedColumn<double> qualityScore = GeneratedColumn<double>(
    'quality_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _khTitrationJsonMeta = const VerificationMeta(
    'khTitrationJson',
  );
  @override
  late final GeneratedColumn<String> khTitrationJson = GeneratedColumn<String>(
    'kh_titration_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confirmedMinValueMeta = const VerificationMeta(
    'confirmedMinValue',
  );
  @override
  late final GeneratedColumn<double> confirmedMinValue =
      GeneratedColumn<double>(
        'confirmed_min_value',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _confirmedInterpolationMeta =
      const VerificationMeta('confirmedInterpolation');
  @override
  late final GeneratedColumn<double> confirmedInterpolation =
      GeneratedColumn<double>(
        'confirmed_interpolation',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estimatedInterpolationMeta =
      const VerificationMeta('estimatedInterpolation');
  @override
  late final GeneratedColumn<double> estimatedInterpolation =
      GeneratedColumn<double>(
        'estimated_interpolation',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _confirmedMaxValueMeta = const VerificationMeta(
    'confirmedMaxValue',
  );
  @override
  late final GeneratedColumn<double> confirmedMaxValue =
      GeneratedColumn<double>(
        'confirmed_max_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _measuredAtMeta = const VerificationMeta(
    'measuredAt',
  );
  @override
  late final GeneratedColumn<DateTime> measuredAt = GeneratedColumn<DateTime>(
    'measured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedAtMeta = const VerificationMeta(
    'confirmedAt',
  );
  @override
  late final GeneratedColumn<DateTime> confirmedAt = GeneratedColumn<DateTime>(
    'confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wasManuallyEditedMeta = const VerificationMeta(
    'wasManuallyEdited',
  );
  @override
  late final GeneratedColumn<bool> wasManuallyEdited = GeneratedColumn<bool>(
    'was_manually_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_manually_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    parameterId,
    reagentProfileId,
    capturedAt,
    estimatedMinValue,
    estimatedMaxValue,
    estimationMethod,
    estimationVersion,
    qualityScore,
    confidence,
    failureReason,
    khTitrationJson,
    confirmedMinValue,
    confirmedInterpolation,
    estimatedInterpolation,
    confirmedMaxValue,
    unit,
    measuredAt,
    confirmedAt,
    notes,
    photoPath,
    wasManuallyEdited,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('reagent_profile_id')) {
      context.handle(
        _reagentProfileIdMeta,
        reagentProfileId.isAcceptableOrUnknown(
          data['reagent_profile_id']!,
          _reagentProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    }
    if (data.containsKey('estimated_min_value')) {
      context.handle(
        _estimatedMinValueMeta,
        estimatedMinValue.isAcceptableOrUnknown(
          data['estimated_min_value']!,
          _estimatedMinValueMeta,
        ),
      );
    }
    if (data.containsKey('estimated_max_value')) {
      context.handle(
        _estimatedMaxValueMeta,
        estimatedMaxValue.isAcceptableOrUnknown(
          data['estimated_max_value']!,
          _estimatedMaxValueMeta,
        ),
      );
    }
    if (data.containsKey('estimation_method')) {
      context.handle(
        _estimationMethodMeta,
        estimationMethod.isAcceptableOrUnknown(
          data['estimation_method']!,
          _estimationMethodMeta,
        ),
      );
    }
    if (data.containsKey('estimation_version')) {
      context.handle(
        _estimationVersionMeta,
        estimationVersion.isAcceptableOrUnknown(
          data['estimation_version']!,
          _estimationVersionMeta,
        ),
      );
    }
    if (data.containsKey('quality_score')) {
      context.handle(
        _qualityScoreMeta,
        qualityScore.isAcceptableOrUnknown(
          data['quality_score']!,
          _qualityScoreMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('kh_titration_json')) {
      context.handle(
        _khTitrationJsonMeta,
        khTitrationJson.isAcceptableOrUnknown(
          data['kh_titration_json']!,
          _khTitrationJsonMeta,
        ),
      );
    }
    if (data.containsKey('confirmed_min_value')) {
      context.handle(
        _confirmedMinValueMeta,
        confirmedMinValue.isAcceptableOrUnknown(
          data['confirmed_min_value']!,
          _confirmedMinValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmedMinValueMeta);
    }
    if (data.containsKey('confirmed_interpolation')) {
      context.handle(
        _confirmedInterpolationMeta,
        confirmedInterpolation.isAcceptableOrUnknown(
          data['confirmed_interpolation']!,
          _confirmedInterpolationMeta,
        ),
      );
    }
    if (data.containsKey('estimated_interpolation')) {
      context.handle(
        _estimatedInterpolationMeta,
        estimatedInterpolation.isAcceptableOrUnknown(
          data['estimated_interpolation']!,
          _estimatedInterpolationMeta,
        ),
      );
    }
    if (data.containsKey('confirmed_max_value')) {
      context.handle(
        _confirmedMaxValueMeta,
        confirmedMaxValue.isAcceptableOrUnknown(
          data['confirmed_max_value']!,
          _confirmedMaxValueMeta,
        ),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('measured_at')) {
      context.handle(
        _measuredAtMeta,
        measuredAt.isAcceptableOrUnknown(data['measured_at']!, _measuredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredAtMeta);
    }
    if (data.containsKey('confirmed_at')) {
      context.handle(
        _confirmedAtMeta,
        confirmedAt.isAcceptableOrUnknown(
          data['confirmed_at']!,
          _confirmedAtMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('was_manually_edited')) {
      context.handle(
        _wasManuallyEditedMeta,
        wasManuallyEdited.isAcceptableOrUnknown(
          data['was_manually_edited']!,
          _wasManuallyEditedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TestRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      reagentProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reagent_profile_id'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      ),
      estimatedMinValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_min_value'],
      ),
      estimatedMaxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_max_value'],
      ),
      estimationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimation_method'],
      ),
      estimationVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estimation_version'],
      ),
      qualityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quality_score'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      ),
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      khTitrationJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kh_titration_json'],
      ),
      confirmedMinValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confirmed_min_value'],
      )!,
      confirmedInterpolation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confirmed_interpolation'],
      ),
      estimatedInterpolation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimated_interpolation'],
      ),
      confirmedMaxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confirmed_max_value'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      measuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_at'],
      )!,
      confirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}confirmed_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      wasManuallyEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_manually_edited'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TestRecordsTable createAlias(String alias) {
    return $TestRecordsTable(attachedDatabase, alias);
  }
}

class TestRecord extends DataClass implements Insertable<TestRecord> {
  final String id;
  final String tankId;
  final String parameterId;
  final String? reagentProfileId;
  final DateTime? capturedAt;
  final double? estimatedMinValue;
  final double? estimatedMaxValue;
  final String? estimationMethod;
  final String? estimationVersion;
  final double? qualityScore;
  final String? confidence;
  final String? failureReason;
  final String? khTitrationJson;
  final double confirmedMinValue;
  final double? confirmedInterpolation;
  final double? estimatedInterpolation;
  final double? confirmedMaxValue;
  final String unit;
  final DateTime measuredAt;
  final DateTime? confirmedAt;
  final String? notes;
  final String? photoPath;
  final bool wasManuallyEdited;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TestRecord({
    required this.id,
    required this.tankId,
    required this.parameterId,
    this.reagentProfileId,
    this.capturedAt,
    this.estimatedMinValue,
    this.estimatedMaxValue,
    this.estimationMethod,
    this.estimationVersion,
    this.qualityScore,
    this.confidence,
    this.failureReason,
    this.khTitrationJson,
    required this.confirmedMinValue,
    this.confirmedInterpolation,
    this.estimatedInterpolation,
    this.confirmedMaxValue,
    required this.unit,
    required this.measuredAt,
    this.confirmedAt,
    this.notes,
    this.photoPath,
    required this.wasManuallyEdited,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tank_id'] = Variable<String>(tankId);
    map['parameter_id'] = Variable<String>(parameterId);
    if (!nullToAbsent || reagentProfileId != null) {
      map['reagent_profile_id'] = Variable<String>(reagentProfileId);
    }
    if (!nullToAbsent || capturedAt != null) {
      map['captured_at'] = Variable<DateTime>(capturedAt);
    }
    if (!nullToAbsent || estimatedMinValue != null) {
      map['estimated_min_value'] = Variable<double>(estimatedMinValue);
    }
    if (!nullToAbsent || estimatedMaxValue != null) {
      map['estimated_max_value'] = Variable<double>(estimatedMaxValue);
    }
    if (!nullToAbsent || estimationMethod != null) {
      map['estimation_method'] = Variable<String>(estimationMethod);
    }
    if (!nullToAbsent || estimationVersion != null) {
      map['estimation_version'] = Variable<String>(estimationVersion);
    }
    if (!nullToAbsent || qualityScore != null) {
      map['quality_score'] = Variable<double>(qualityScore);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<String>(confidence);
    }
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    if (!nullToAbsent || khTitrationJson != null) {
      map['kh_titration_json'] = Variable<String>(khTitrationJson);
    }
    map['confirmed_min_value'] = Variable<double>(confirmedMinValue);
    if (!nullToAbsent || confirmedInterpolation != null) {
      map['confirmed_interpolation'] = Variable<double>(confirmedInterpolation);
    }
    if (!nullToAbsent || estimatedInterpolation != null) {
      map['estimated_interpolation'] = Variable<double>(estimatedInterpolation);
    }
    if (!nullToAbsent || confirmedMaxValue != null) {
      map['confirmed_max_value'] = Variable<double>(confirmedMaxValue);
    }
    map['unit'] = Variable<String>(unit);
    map['measured_at'] = Variable<DateTime>(measuredAt);
    if (!nullToAbsent || confirmedAt != null) {
      map['confirmed_at'] = Variable<DateTime>(confirmedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['was_manually_edited'] = Variable<bool>(wasManuallyEdited);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TestRecordsCompanion toCompanion(bool nullToAbsent) {
    return TestRecordsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      parameterId: Value(parameterId),
      reagentProfileId: reagentProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(reagentProfileId),
      capturedAt: capturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAt),
      estimatedMinValue: estimatedMinValue == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedMinValue),
      estimatedMaxValue: estimatedMaxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedMaxValue),
      estimationMethod: estimationMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(estimationMethod),
      estimationVersion: estimationVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(estimationVersion),
      qualityScore: qualityScore == null && nullToAbsent
          ? const Value.absent()
          : Value(qualityScore),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      khTitrationJson: khTitrationJson == null && nullToAbsent
          ? const Value.absent()
          : Value(khTitrationJson),
      confirmedMinValue: Value(confirmedMinValue),
      confirmedInterpolation: confirmedInterpolation == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedInterpolation),
      estimatedInterpolation: estimatedInterpolation == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedInterpolation),
      confirmedMaxValue: confirmedMaxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedMaxValue),
      unit: Value(unit),
      measuredAt: Value(measuredAt),
      confirmedAt: confirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      wasManuallyEdited: Value(wasManuallyEdited),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TestRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestRecord(
      id: serializer.fromJson<String>(json['id']),
      tankId: serializer.fromJson<String>(json['tankId']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      reagentProfileId: serializer.fromJson<String?>(json['reagentProfileId']),
      capturedAt: serializer.fromJson<DateTime?>(json['capturedAt']),
      estimatedMinValue: serializer.fromJson<double?>(
        json['estimatedMinValue'],
      ),
      estimatedMaxValue: serializer.fromJson<double?>(
        json['estimatedMaxValue'],
      ),
      estimationMethod: serializer.fromJson<String?>(json['estimationMethod']),
      estimationVersion: serializer.fromJson<String?>(
        json['estimationVersion'],
      ),
      qualityScore: serializer.fromJson<double?>(json['qualityScore']),
      confidence: serializer.fromJson<String?>(json['confidence']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      khTitrationJson: serializer.fromJson<String?>(json['khTitrationJson']),
      confirmedMinValue: serializer.fromJson<double>(json['confirmedMinValue']),
      confirmedInterpolation: serializer.fromJson<double?>(
        json['confirmedInterpolation'],
      ),
      estimatedInterpolation: serializer.fromJson<double?>(
        json['estimatedInterpolation'],
      ),
      confirmedMaxValue: serializer.fromJson<double?>(
        json['confirmedMaxValue'],
      ),
      unit: serializer.fromJson<String>(json['unit']),
      measuredAt: serializer.fromJson<DateTime>(json['measuredAt']),
      confirmedAt: serializer.fromJson<DateTime?>(json['confirmedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      wasManuallyEdited: serializer.fromJson<bool>(json['wasManuallyEdited']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tankId': serializer.toJson<String>(tankId),
      'parameterId': serializer.toJson<String>(parameterId),
      'reagentProfileId': serializer.toJson<String?>(reagentProfileId),
      'capturedAt': serializer.toJson<DateTime?>(capturedAt),
      'estimatedMinValue': serializer.toJson<double?>(estimatedMinValue),
      'estimatedMaxValue': serializer.toJson<double?>(estimatedMaxValue),
      'estimationMethod': serializer.toJson<String?>(estimationMethod),
      'estimationVersion': serializer.toJson<String?>(estimationVersion),
      'qualityScore': serializer.toJson<double?>(qualityScore),
      'confidence': serializer.toJson<String?>(confidence),
      'failureReason': serializer.toJson<String?>(failureReason),
      'khTitrationJson': serializer.toJson<String?>(khTitrationJson),
      'confirmedMinValue': serializer.toJson<double>(confirmedMinValue),
      'confirmedInterpolation': serializer.toJson<double?>(
        confirmedInterpolation,
      ),
      'estimatedInterpolation': serializer.toJson<double?>(
        estimatedInterpolation,
      ),
      'confirmedMaxValue': serializer.toJson<double?>(confirmedMaxValue),
      'unit': serializer.toJson<String>(unit),
      'measuredAt': serializer.toJson<DateTime>(measuredAt),
      'confirmedAt': serializer.toJson<DateTime?>(confirmedAt),
      'notes': serializer.toJson<String?>(notes),
      'photoPath': serializer.toJson<String?>(photoPath),
      'wasManuallyEdited': serializer.toJson<bool>(wasManuallyEdited),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TestRecord copyWith({
    String? id,
    String? tankId,
    String? parameterId,
    Value<String?> reagentProfileId = const Value.absent(),
    Value<DateTime?> capturedAt = const Value.absent(),
    Value<double?> estimatedMinValue = const Value.absent(),
    Value<double?> estimatedMaxValue = const Value.absent(),
    Value<String?> estimationMethod = const Value.absent(),
    Value<String?> estimationVersion = const Value.absent(),
    Value<double?> qualityScore = const Value.absent(),
    Value<String?> confidence = const Value.absent(),
    Value<String?> failureReason = const Value.absent(),
    Value<String?> khTitrationJson = const Value.absent(),
    double? confirmedMinValue,
    Value<double?> confirmedInterpolation = const Value.absent(),
    Value<double?> estimatedInterpolation = const Value.absent(),
    Value<double?> confirmedMaxValue = const Value.absent(),
    String? unit,
    DateTime? measuredAt,
    Value<DateTime?> confirmedAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
    bool? wasManuallyEdited,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TestRecord(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    parameterId: parameterId ?? this.parameterId,
    reagentProfileId: reagentProfileId.present
        ? reagentProfileId.value
        : this.reagentProfileId,
    capturedAt: capturedAt.present ? capturedAt.value : this.capturedAt,
    estimatedMinValue: estimatedMinValue.present
        ? estimatedMinValue.value
        : this.estimatedMinValue,
    estimatedMaxValue: estimatedMaxValue.present
        ? estimatedMaxValue.value
        : this.estimatedMaxValue,
    estimationMethod: estimationMethod.present
        ? estimationMethod.value
        : this.estimationMethod,
    estimationVersion: estimationVersion.present
        ? estimationVersion.value
        : this.estimationVersion,
    qualityScore: qualityScore.present ? qualityScore.value : this.qualityScore,
    confidence: confidence.present ? confidence.value : this.confidence,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    khTitrationJson: khTitrationJson.present
        ? khTitrationJson.value
        : this.khTitrationJson,
    confirmedMinValue: confirmedMinValue ?? this.confirmedMinValue,
    confirmedInterpolation: confirmedInterpolation.present
        ? confirmedInterpolation.value
        : this.confirmedInterpolation,
    estimatedInterpolation: estimatedInterpolation.present
        ? estimatedInterpolation.value
        : this.estimatedInterpolation,
    confirmedMaxValue: confirmedMaxValue.present
        ? confirmedMaxValue.value
        : this.confirmedMaxValue,
    unit: unit ?? this.unit,
    measuredAt: measuredAt ?? this.measuredAt,
    confirmedAt: confirmedAt.present ? confirmedAt.value : this.confirmedAt,
    notes: notes.present ? notes.value : this.notes,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    wasManuallyEdited: wasManuallyEdited ?? this.wasManuallyEdited,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TestRecord copyWithCompanion(TestRecordsCompanion data) {
    return TestRecord(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      reagentProfileId: data.reagentProfileId.present
          ? data.reagentProfileId.value
          : this.reagentProfileId,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      estimatedMinValue: data.estimatedMinValue.present
          ? data.estimatedMinValue.value
          : this.estimatedMinValue,
      estimatedMaxValue: data.estimatedMaxValue.present
          ? data.estimatedMaxValue.value
          : this.estimatedMaxValue,
      estimationMethod: data.estimationMethod.present
          ? data.estimationMethod.value
          : this.estimationMethod,
      estimationVersion: data.estimationVersion.present
          ? data.estimationVersion.value
          : this.estimationVersion,
      qualityScore: data.qualityScore.present
          ? data.qualityScore.value
          : this.qualityScore,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      khTitrationJson: data.khTitrationJson.present
          ? data.khTitrationJson.value
          : this.khTitrationJson,
      confirmedMinValue: data.confirmedMinValue.present
          ? data.confirmedMinValue.value
          : this.confirmedMinValue,
      confirmedInterpolation: data.confirmedInterpolation.present
          ? data.confirmedInterpolation.value
          : this.confirmedInterpolation,
      estimatedInterpolation: data.estimatedInterpolation.present
          ? data.estimatedInterpolation.value
          : this.estimatedInterpolation,
      confirmedMaxValue: data.confirmedMaxValue.present
          ? data.confirmedMaxValue.value
          : this.confirmedMaxValue,
      unit: data.unit.present ? data.unit.value : this.unit,
      measuredAt: data.measuredAt.present
          ? data.measuredAt.value
          : this.measuredAt,
      confirmedAt: data.confirmedAt.present
          ? data.confirmedAt.value
          : this.confirmedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      wasManuallyEdited: data.wasManuallyEdited.present
          ? data.wasManuallyEdited.value
          : this.wasManuallyEdited,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestRecord(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('reagentProfileId: $reagentProfileId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('estimatedMinValue: $estimatedMinValue, ')
          ..write('estimatedMaxValue: $estimatedMaxValue, ')
          ..write('estimationMethod: $estimationMethod, ')
          ..write('estimationVersion: $estimationVersion, ')
          ..write('qualityScore: $qualityScore, ')
          ..write('confidence: $confidence, ')
          ..write('failureReason: $failureReason, ')
          ..write('khTitrationJson: $khTitrationJson, ')
          ..write('confirmedMinValue: $confirmedMinValue, ')
          ..write('confirmedInterpolation: $confirmedInterpolation, ')
          ..write('estimatedInterpolation: $estimatedInterpolation, ')
          ..write('confirmedMaxValue: $confirmedMaxValue, ')
          ..write('unit: $unit, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('notes: $notes, ')
          ..write('photoPath: $photoPath, ')
          ..write('wasManuallyEdited: $wasManuallyEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tankId,
    parameterId,
    reagentProfileId,
    capturedAt,
    estimatedMinValue,
    estimatedMaxValue,
    estimationMethod,
    estimationVersion,
    qualityScore,
    confidence,
    failureReason,
    khTitrationJson,
    confirmedMinValue,
    confirmedInterpolation,
    estimatedInterpolation,
    confirmedMaxValue,
    unit,
    measuredAt,
    confirmedAt,
    notes,
    photoPath,
    wasManuallyEdited,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestRecord &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.parameterId == this.parameterId &&
          other.reagentProfileId == this.reagentProfileId &&
          other.capturedAt == this.capturedAt &&
          other.estimatedMinValue == this.estimatedMinValue &&
          other.estimatedMaxValue == this.estimatedMaxValue &&
          other.estimationMethod == this.estimationMethod &&
          other.estimationVersion == this.estimationVersion &&
          other.qualityScore == this.qualityScore &&
          other.confidence == this.confidence &&
          other.failureReason == this.failureReason &&
          other.khTitrationJson == this.khTitrationJson &&
          other.confirmedMinValue == this.confirmedMinValue &&
          other.confirmedInterpolation == this.confirmedInterpolation &&
          other.estimatedInterpolation == this.estimatedInterpolation &&
          other.confirmedMaxValue == this.confirmedMaxValue &&
          other.unit == this.unit &&
          other.measuredAt == this.measuredAt &&
          other.confirmedAt == this.confirmedAt &&
          other.notes == this.notes &&
          other.photoPath == this.photoPath &&
          other.wasManuallyEdited == this.wasManuallyEdited &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TestRecordsCompanion extends UpdateCompanion<TestRecord> {
  final Value<String> id;
  final Value<String> tankId;
  final Value<String> parameterId;
  final Value<String?> reagentProfileId;
  final Value<DateTime?> capturedAt;
  final Value<double?> estimatedMinValue;
  final Value<double?> estimatedMaxValue;
  final Value<String?> estimationMethod;
  final Value<String?> estimationVersion;
  final Value<double?> qualityScore;
  final Value<String?> confidence;
  final Value<String?> failureReason;
  final Value<String?> khTitrationJson;
  final Value<double> confirmedMinValue;
  final Value<double?> confirmedInterpolation;
  final Value<double?> estimatedInterpolation;
  final Value<double?> confirmedMaxValue;
  final Value<String> unit;
  final Value<DateTime> measuredAt;
  final Value<DateTime?> confirmedAt;
  final Value<String?> notes;
  final Value<String?> photoPath;
  final Value<bool> wasManuallyEdited;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TestRecordsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.reagentProfileId = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.estimatedMinValue = const Value.absent(),
    this.estimatedMaxValue = const Value.absent(),
    this.estimationMethod = const Value.absent(),
    this.estimationVersion = const Value.absent(),
    this.qualityScore = const Value.absent(),
    this.confidence = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.khTitrationJson = const Value.absent(),
    this.confirmedMinValue = const Value.absent(),
    this.confirmedInterpolation = const Value.absent(),
    this.estimatedInterpolation = const Value.absent(),
    this.confirmedMaxValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.measuredAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.wasManuallyEdited = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestRecordsCompanion.insert({
    required String id,
    required String tankId,
    required String parameterId,
    this.reagentProfileId = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.estimatedMinValue = const Value.absent(),
    this.estimatedMaxValue = const Value.absent(),
    this.estimationMethod = const Value.absent(),
    this.estimationVersion = const Value.absent(),
    this.qualityScore = const Value.absent(),
    this.confidence = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.khTitrationJson = const Value.absent(),
    required double confirmedMinValue,
    this.confirmedInterpolation = const Value.absent(),
    this.estimatedInterpolation = const Value.absent(),
    this.confirmedMaxValue = const Value.absent(),
    required String unit,
    required DateTime measuredAt,
    this.confirmedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.wasManuallyEdited = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tankId = Value(tankId),
       parameterId = Value(parameterId),
       confirmedMinValue = Value(confirmedMinValue),
       unit = Value(unit),
       measuredAt = Value(measuredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TestRecord> custom({
    Expression<String>? id,
    Expression<String>? tankId,
    Expression<String>? parameterId,
    Expression<String>? reagentProfileId,
    Expression<DateTime>? capturedAt,
    Expression<double>? estimatedMinValue,
    Expression<double>? estimatedMaxValue,
    Expression<String>? estimationMethod,
    Expression<String>? estimationVersion,
    Expression<double>? qualityScore,
    Expression<String>? confidence,
    Expression<String>? failureReason,
    Expression<String>? khTitrationJson,
    Expression<double>? confirmedMinValue,
    Expression<double>? confirmedInterpolation,
    Expression<double>? estimatedInterpolation,
    Expression<double>? confirmedMaxValue,
    Expression<String>? unit,
    Expression<DateTime>? measuredAt,
    Expression<DateTime>? confirmedAt,
    Expression<String>? notes,
    Expression<String>? photoPath,
    Expression<bool>? wasManuallyEdited,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (parameterId != null) 'parameter_id': parameterId,
      if (reagentProfileId != null) 'reagent_profile_id': reagentProfileId,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (estimatedMinValue != null) 'estimated_min_value': estimatedMinValue,
      if (estimatedMaxValue != null) 'estimated_max_value': estimatedMaxValue,
      if (estimationMethod != null) 'estimation_method': estimationMethod,
      if (estimationVersion != null) 'estimation_version': estimationVersion,
      if (qualityScore != null) 'quality_score': qualityScore,
      if (confidence != null) 'confidence': confidence,
      if (failureReason != null) 'failure_reason': failureReason,
      if (khTitrationJson != null) 'kh_titration_json': khTitrationJson,
      if (confirmedMinValue != null) 'confirmed_min_value': confirmedMinValue,
      if (confirmedInterpolation != null)
        'confirmed_interpolation': confirmedInterpolation,
      if (estimatedInterpolation != null)
        'estimated_interpolation': estimatedInterpolation,
      if (confirmedMaxValue != null) 'confirmed_max_value': confirmedMaxValue,
      if (unit != null) 'unit': unit,
      if (measuredAt != null) 'measured_at': measuredAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (notes != null) 'notes': notes,
      if (photoPath != null) 'photo_path': photoPath,
      if (wasManuallyEdited != null) 'was_manually_edited': wasManuallyEdited,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? tankId,
    Value<String>? parameterId,
    Value<String?>? reagentProfileId,
    Value<DateTime?>? capturedAt,
    Value<double?>? estimatedMinValue,
    Value<double?>? estimatedMaxValue,
    Value<String?>? estimationMethod,
    Value<String?>? estimationVersion,
    Value<double?>? qualityScore,
    Value<String?>? confidence,
    Value<String?>? failureReason,
    Value<String?>? khTitrationJson,
    Value<double>? confirmedMinValue,
    Value<double?>? confirmedInterpolation,
    Value<double?>? estimatedInterpolation,
    Value<double?>? confirmedMaxValue,
    Value<String>? unit,
    Value<DateTime>? measuredAt,
    Value<DateTime?>? confirmedAt,
    Value<String?>? notes,
    Value<String?>? photoPath,
    Value<bool>? wasManuallyEdited,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TestRecordsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      reagentProfileId: reagentProfileId ?? this.reagentProfileId,
      capturedAt: capturedAt ?? this.capturedAt,
      estimatedMinValue: estimatedMinValue ?? this.estimatedMinValue,
      estimatedMaxValue: estimatedMaxValue ?? this.estimatedMaxValue,
      estimationMethod: estimationMethod ?? this.estimationMethod,
      estimationVersion: estimationVersion ?? this.estimationVersion,
      qualityScore: qualityScore ?? this.qualityScore,
      confidence: confidence ?? this.confidence,
      failureReason: failureReason ?? this.failureReason,
      khTitrationJson: khTitrationJson ?? this.khTitrationJson,
      confirmedMinValue: confirmedMinValue ?? this.confirmedMinValue,
      confirmedInterpolation:
          confirmedInterpolation ?? this.confirmedInterpolation,
      estimatedInterpolation:
          estimatedInterpolation ?? this.estimatedInterpolation,
      confirmedMaxValue: confirmedMaxValue ?? this.confirmedMaxValue,
      unit: unit ?? this.unit,
      measuredAt: measuredAt ?? this.measuredAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      wasManuallyEdited: wasManuallyEdited ?? this.wasManuallyEdited,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (reagentProfileId.present) {
      map['reagent_profile_id'] = Variable<String>(reagentProfileId.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (estimatedMinValue.present) {
      map['estimated_min_value'] = Variable<double>(estimatedMinValue.value);
    }
    if (estimatedMaxValue.present) {
      map['estimated_max_value'] = Variable<double>(estimatedMaxValue.value);
    }
    if (estimationMethod.present) {
      map['estimation_method'] = Variable<String>(estimationMethod.value);
    }
    if (estimationVersion.present) {
      map['estimation_version'] = Variable<String>(estimationVersion.value);
    }
    if (qualityScore.present) {
      map['quality_score'] = Variable<double>(qualityScore.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (khTitrationJson.present) {
      map['kh_titration_json'] = Variable<String>(khTitrationJson.value);
    }
    if (confirmedMinValue.present) {
      map['confirmed_min_value'] = Variable<double>(confirmedMinValue.value);
    }
    if (confirmedInterpolation.present) {
      map['confirmed_interpolation'] = Variable<double>(
        confirmedInterpolation.value,
      );
    }
    if (estimatedInterpolation.present) {
      map['estimated_interpolation'] = Variable<double>(
        estimatedInterpolation.value,
      );
    }
    if (confirmedMaxValue.present) {
      map['confirmed_max_value'] = Variable<double>(confirmedMaxValue.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (measuredAt.present) {
      map['measured_at'] = Variable<DateTime>(measuredAt.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<DateTime>(confirmedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (wasManuallyEdited.present) {
      map['was_manually_edited'] = Variable<bool>(wasManuallyEdited.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestRecordsCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('reagentProfileId: $reagentProfileId, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('estimatedMinValue: $estimatedMinValue, ')
          ..write('estimatedMaxValue: $estimatedMaxValue, ')
          ..write('estimationMethod: $estimationMethod, ')
          ..write('estimationVersion: $estimationVersion, ')
          ..write('qualityScore: $qualityScore, ')
          ..write('confidence: $confidence, ')
          ..write('failureReason: $failureReason, ')
          ..write('khTitrationJson: $khTitrationJson, ')
          ..write('confirmedMinValue: $confirmedMinValue, ')
          ..write('confirmedInterpolation: $confirmedInterpolation, ')
          ..write('estimatedInterpolation: $estimatedInterpolation, ')
          ..write('confirmedMaxValue: $confirmedMaxValue, ')
          ..write('unit: $unit, ')
          ..write('measuredAt: $measuredAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('notes: $notes, ')
          ..write('photoPath: $photoPath, ')
          ..write('wasManuallyEdited: $wasManuallyEdited, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceTasksTable extends MaintenanceTasks
    with TableInfo<$MaintenanceTasksTable, MaintenanceTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intervalAmountMeta = const VerificationMeta(
    'intervalAmount',
  );
  @override
  late final GeneratedColumn<int> intervalAmount = GeneratedColumn<int>(
    'interval_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalUnitMeta = const VerificationMeta(
    'intervalUnit',
  );
  @override
  late final GeneratedColumn<String> intervalUnit = GeneratedColumn<String>(
    'interval_unit',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preferredReminderTimeMeta =
      const VerificationMeta('preferredReminderTime');
  @override
  late final GeneratedColumn<String> preferredReminderTime =
      GeneratedColumn<String>(
        'preferred_reminder_time',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 5,
          maxTextLength: 5,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('09:00'),
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('enabled'),
  );
  static const VerificationMeta _isOneOffMeta = const VerificationMeta(
    'isOneOff',
  );
  @override
  late final GeneratedColumn<bool> isOneOff = GeneratedColumn<bool>(
    'is_one_off',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_one_off" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planDayIndexMeta = const VerificationMeta(
    'planDayIndex',
  );
  @override
  late final GeneratedColumn<int> planDayIndex = GeneratedColumn<int>(
    'plan_day_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planTotalDaysMeta = const VerificationMeta(
    'planTotalDays',
  );
  @override
  late final GeneratedColumn<int> planTotalDays = GeneratedColumn<int>(
    'plan_total_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurrenceJsonMeta = const VerificationMeta(
    'recurrenceJson',
  );
  @override
  late final GeneratedColumn<String> recurrenceJson = GeneratedColumn<String>(
    'recurrence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rollingJsonMeta = const VerificationMeta(
    'rollingJson',
  );
  @override
  late final GeneratedColumn<String> rollingJson = GeneratedColumn<String>(
    'rolling_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    title,
    notes,
    intervalAmount,
    intervalUnit,
    dueAt,
    preferredReminderTime,
    status,
    isOneOff,
    source,
    planId,
    planDayIndex,
    planTotalDays,
    recurrenceJson,
    rollingJson,
    notificationId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('interval_amount')) {
      context.handle(
        _intervalAmountMeta,
        intervalAmount.isAcceptableOrUnknown(
          data['interval_amount']!,
          _intervalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intervalAmountMeta);
    }
    if (data.containsKey('interval_unit')) {
      context.handle(
        _intervalUnitMeta,
        intervalUnit.isAcceptableOrUnknown(
          data['interval_unit']!,
          _intervalUnitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_intervalUnitMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('preferred_reminder_time')) {
      context.handle(
        _preferredReminderTimeMeta,
        preferredReminderTime.isAcceptableOrUnknown(
          data['preferred_reminder_time']!,
          _preferredReminderTimeMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_one_off')) {
      context.handle(
        _isOneOffMeta,
        isOneOff.isAcceptableOrUnknown(data['is_one_off']!, _isOneOffMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('plan_day_index')) {
      context.handle(
        _planDayIndexMeta,
        planDayIndex.isAcceptableOrUnknown(
          data['plan_day_index']!,
          _planDayIndexMeta,
        ),
      );
    }
    if (data.containsKey('plan_total_days')) {
      context.handle(
        _planTotalDaysMeta,
        planTotalDays.isAcceptableOrUnknown(
          data['plan_total_days']!,
          _planTotalDaysMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_json')) {
      context.handle(
        _recurrenceJsonMeta,
        recurrenceJson.isAcceptableOrUnknown(
          data['recurrence_json']!,
          _recurrenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('rolling_json')) {
      context.handle(
        _rollingJsonMeta,
        rollingJson.isAcceptableOrUnknown(
          data['rolling_json']!,
          _rollingJsonMeta,
        ),
      );
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      intervalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_amount'],
      )!,
      intervalUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interval_unit'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      preferredReminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_reminder_time'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isOneOff: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_one_off'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      ),
      planDayIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_day_index'],
      ),
      planTotalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plan_total_days'],
      ),
      recurrenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_json'],
      ),
      rollingJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rolling_json'],
      ),
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MaintenanceTasksTable createAlias(String alias) {
    return $MaintenanceTasksTable(attachedDatabase, alias);
  }
}

class MaintenanceTask extends DataClass implements Insertable<MaintenanceTask> {
  final String id;
  final String tankId;
  final String title;
  final String? notes;
  final int intervalAmount;
  final String intervalUnit;
  final DateTime dueAt;
  final String preferredReminderTime;
  final String status;
  final bool isOneOff;
  final String? source;
  final String? planId;
  final int? planDayIndex;
  final int? planTotalDays;
  final String? recurrenceJson;
  final String? rollingJson;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MaintenanceTask({
    required this.id,
    required this.tankId,
    required this.title,
    this.notes,
    required this.intervalAmount,
    required this.intervalUnit,
    required this.dueAt,
    required this.preferredReminderTime,
    required this.status,
    required this.isOneOff,
    this.source,
    this.planId,
    this.planDayIndex,
    this.planTotalDays,
    this.recurrenceJson,
    this.rollingJson,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tank_id'] = Variable<String>(tankId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['interval_amount'] = Variable<int>(intervalAmount);
    map['interval_unit'] = Variable<String>(intervalUnit);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['preferred_reminder_time'] = Variable<String>(preferredReminderTime);
    map['status'] = Variable<String>(status);
    map['is_one_off'] = Variable<bool>(isOneOff);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    if (!nullToAbsent || planDayIndex != null) {
      map['plan_day_index'] = Variable<int>(planDayIndex);
    }
    if (!nullToAbsent || planTotalDays != null) {
      map['plan_total_days'] = Variable<int>(planTotalDays);
    }
    if (!nullToAbsent || recurrenceJson != null) {
      map['recurrence_json'] = Variable<String>(recurrenceJson);
    }
    if (!nullToAbsent || rollingJson != null) {
      map['rolling_json'] = Variable<String>(rollingJson);
    }
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MaintenanceTasksCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceTasksCompanion(
      id: Value(id),
      tankId: Value(tankId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      intervalAmount: Value(intervalAmount),
      intervalUnit: Value(intervalUnit),
      dueAt: Value(dueAt),
      preferredReminderTime: Value(preferredReminderTime),
      status: Value(status),
      isOneOff: Value(isOneOff),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      planId: planId == null && nullToAbsent
          ? const Value.absent()
          : Value(planId),
      planDayIndex: planDayIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(planDayIndex),
      planTotalDays: planTotalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(planTotalDays),
      recurrenceJson: recurrenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceJson),
      rollingJson: rollingJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rollingJson),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MaintenanceTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceTask(
      id: serializer.fromJson<String>(json['id']),
      tankId: serializer.fromJson<String>(json['tankId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      intervalAmount: serializer.fromJson<int>(json['intervalAmount']),
      intervalUnit: serializer.fromJson<String>(json['intervalUnit']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      preferredReminderTime: serializer.fromJson<String>(
        json['preferredReminderTime'],
      ),
      status: serializer.fromJson<String>(json['status']),
      isOneOff: serializer.fromJson<bool>(json['isOneOff']),
      source: serializer.fromJson<String?>(json['source']),
      planId: serializer.fromJson<String?>(json['planId']),
      planDayIndex: serializer.fromJson<int?>(json['planDayIndex']),
      planTotalDays: serializer.fromJson<int?>(json['planTotalDays']),
      recurrenceJson: serializer.fromJson<String?>(json['recurrenceJson']),
      rollingJson: serializer.fromJson<String?>(json['rollingJson']),
      notificationId: serializer.fromJson<int?>(json['notificationId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tankId': serializer.toJson<String>(tankId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'intervalAmount': serializer.toJson<int>(intervalAmount),
      'intervalUnit': serializer.toJson<String>(intervalUnit),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'preferredReminderTime': serializer.toJson<String>(preferredReminderTime),
      'status': serializer.toJson<String>(status),
      'isOneOff': serializer.toJson<bool>(isOneOff),
      'source': serializer.toJson<String?>(source),
      'planId': serializer.toJson<String?>(planId),
      'planDayIndex': serializer.toJson<int?>(planDayIndex),
      'planTotalDays': serializer.toJson<int?>(planTotalDays),
      'recurrenceJson': serializer.toJson<String?>(recurrenceJson),
      'rollingJson': serializer.toJson<String?>(rollingJson),
      'notificationId': serializer.toJson<int?>(notificationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MaintenanceTask copyWith({
    String? id,
    String? tankId,
    String? title,
    Value<String?> notes = const Value.absent(),
    int? intervalAmount,
    String? intervalUnit,
    DateTime? dueAt,
    String? preferredReminderTime,
    String? status,
    bool? isOneOff,
    Value<String?> source = const Value.absent(),
    Value<String?> planId = const Value.absent(),
    Value<int?> planDayIndex = const Value.absent(),
    Value<int?> planTotalDays = const Value.absent(),
    Value<String?> recurrenceJson = const Value.absent(),
    Value<String?> rollingJson = const Value.absent(),
    Value<int?> notificationId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MaintenanceTask(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    intervalAmount: intervalAmount ?? this.intervalAmount,
    intervalUnit: intervalUnit ?? this.intervalUnit,
    dueAt: dueAt ?? this.dueAt,
    preferredReminderTime: preferredReminderTime ?? this.preferredReminderTime,
    status: status ?? this.status,
    isOneOff: isOneOff ?? this.isOneOff,
    source: source.present ? source.value : this.source,
    planId: planId.present ? planId.value : this.planId,
    planDayIndex: planDayIndex.present ? planDayIndex.value : this.planDayIndex,
    planTotalDays: planTotalDays.present
        ? planTotalDays.value
        : this.planTotalDays,
    recurrenceJson: recurrenceJson.present
        ? recurrenceJson.value
        : this.recurrenceJson,
    rollingJson: rollingJson.present ? rollingJson.value : this.rollingJson,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MaintenanceTask copyWithCompanion(MaintenanceTasksCompanion data) {
    return MaintenanceTask(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      intervalAmount: data.intervalAmount.present
          ? data.intervalAmount.value
          : this.intervalAmount,
      intervalUnit: data.intervalUnit.present
          ? data.intervalUnit.value
          : this.intervalUnit,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      preferredReminderTime: data.preferredReminderTime.present
          ? data.preferredReminderTime.value
          : this.preferredReminderTime,
      status: data.status.present ? data.status.value : this.status,
      isOneOff: data.isOneOff.present ? data.isOneOff.value : this.isOneOff,
      source: data.source.present ? data.source.value : this.source,
      planId: data.planId.present ? data.planId.value : this.planId,
      planDayIndex: data.planDayIndex.present
          ? data.planDayIndex.value
          : this.planDayIndex,
      planTotalDays: data.planTotalDays.present
          ? data.planTotalDays.value
          : this.planTotalDays,
      recurrenceJson: data.recurrenceJson.present
          ? data.recurrenceJson.value
          : this.recurrenceJson,
      rollingJson: data.rollingJson.present
          ? data.rollingJson.value
          : this.rollingJson,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceTask(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('intervalAmount: $intervalAmount, ')
          ..write('intervalUnit: $intervalUnit, ')
          ..write('dueAt: $dueAt, ')
          ..write('preferredReminderTime: $preferredReminderTime, ')
          ..write('status: $status, ')
          ..write('isOneOff: $isOneOff, ')
          ..write('source: $source, ')
          ..write('planId: $planId, ')
          ..write('planDayIndex: $planDayIndex, ')
          ..write('planTotalDays: $planTotalDays, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('rollingJson: $rollingJson, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tankId,
    title,
    notes,
    intervalAmount,
    intervalUnit,
    dueAt,
    preferredReminderTime,
    status,
    isOneOff,
    source,
    planId,
    planDayIndex,
    planTotalDays,
    recurrenceJson,
    rollingJson,
    notificationId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceTask &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.intervalAmount == this.intervalAmount &&
          other.intervalUnit == this.intervalUnit &&
          other.dueAt == this.dueAt &&
          other.preferredReminderTime == this.preferredReminderTime &&
          other.status == this.status &&
          other.isOneOff == this.isOneOff &&
          other.source == this.source &&
          other.planId == this.planId &&
          other.planDayIndex == this.planDayIndex &&
          other.planTotalDays == this.planTotalDays &&
          other.recurrenceJson == this.recurrenceJson &&
          other.rollingJson == this.rollingJson &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MaintenanceTasksCompanion extends UpdateCompanion<MaintenanceTask> {
  final Value<String> id;
  final Value<String> tankId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<int> intervalAmount;
  final Value<String> intervalUnit;
  final Value<DateTime> dueAt;
  final Value<String> preferredReminderTime;
  final Value<String> status;
  final Value<bool> isOneOff;
  final Value<String?> source;
  final Value<String?> planId;
  final Value<int?> planDayIndex;
  final Value<int?> planTotalDays;
  final Value<String?> recurrenceJson;
  final Value<String?> rollingJson;
  final Value<int?> notificationId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MaintenanceTasksCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.intervalAmount = const Value.absent(),
    this.intervalUnit = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.preferredReminderTime = const Value.absent(),
    this.status = const Value.absent(),
    this.isOneOff = const Value.absent(),
    this.source = const Value.absent(),
    this.planId = const Value.absent(),
    this.planDayIndex = const Value.absent(),
    this.planTotalDays = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.rollingJson = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaintenanceTasksCompanion.insert({
    required String id,
    required String tankId,
    required String title,
    this.notes = const Value.absent(),
    required int intervalAmount,
    required String intervalUnit,
    required DateTime dueAt,
    this.preferredReminderTime = const Value.absent(),
    this.status = const Value.absent(),
    this.isOneOff = const Value.absent(),
    this.source = const Value.absent(),
    this.planId = const Value.absent(),
    this.planDayIndex = const Value.absent(),
    this.planTotalDays = const Value.absent(),
    this.recurrenceJson = const Value.absent(),
    this.rollingJson = const Value.absent(),
    this.notificationId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tankId = Value(tankId),
       title = Value(title),
       intervalAmount = Value(intervalAmount),
       intervalUnit = Value(intervalUnit),
       dueAt = Value(dueAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MaintenanceTask> custom({
    Expression<String>? id,
    Expression<String>? tankId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<int>? intervalAmount,
    Expression<String>? intervalUnit,
    Expression<DateTime>? dueAt,
    Expression<String>? preferredReminderTime,
    Expression<String>? status,
    Expression<bool>? isOneOff,
    Expression<String>? source,
    Expression<String>? planId,
    Expression<int>? planDayIndex,
    Expression<int>? planTotalDays,
    Expression<String>? recurrenceJson,
    Expression<String>? rollingJson,
    Expression<int>? notificationId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (intervalAmount != null) 'interval_amount': intervalAmount,
      if (intervalUnit != null) 'interval_unit': intervalUnit,
      if (dueAt != null) 'due_at': dueAt,
      if (preferredReminderTime != null)
        'preferred_reminder_time': preferredReminderTime,
      if (status != null) 'status': status,
      if (isOneOff != null) 'is_one_off': isOneOff,
      if (source != null) 'source': source,
      if (planId != null) 'plan_id': planId,
      if (planDayIndex != null) 'plan_day_index': planDayIndex,
      if (planTotalDays != null) 'plan_total_days': planTotalDays,
      if (recurrenceJson != null) 'recurrence_json': recurrenceJson,
      if (rollingJson != null) 'rolling_json': rollingJson,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaintenanceTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? tankId,
    Value<String>? title,
    Value<String?>? notes,
    Value<int>? intervalAmount,
    Value<String>? intervalUnit,
    Value<DateTime>? dueAt,
    Value<String>? preferredReminderTime,
    Value<String>? status,
    Value<bool>? isOneOff,
    Value<String?>? source,
    Value<String?>? planId,
    Value<int?>? planDayIndex,
    Value<int?>? planTotalDays,
    Value<String?>? recurrenceJson,
    Value<String?>? rollingJson,
    Value<int?>? notificationId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MaintenanceTasksCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      intervalAmount: intervalAmount ?? this.intervalAmount,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      dueAt: dueAt ?? this.dueAt,
      preferredReminderTime:
          preferredReminderTime ?? this.preferredReminderTime,
      status: status ?? this.status,
      isOneOff: isOneOff ?? this.isOneOff,
      source: source ?? this.source,
      planId: planId ?? this.planId,
      planDayIndex: planDayIndex ?? this.planDayIndex,
      planTotalDays: planTotalDays ?? this.planTotalDays,
      recurrenceJson: recurrenceJson ?? this.recurrenceJson,
      rollingJson: rollingJson ?? this.rollingJson,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (intervalAmount.present) {
      map['interval_amount'] = Variable<int>(intervalAmount.value);
    }
    if (intervalUnit.present) {
      map['interval_unit'] = Variable<String>(intervalUnit.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (preferredReminderTime.present) {
      map['preferred_reminder_time'] = Variable<String>(
        preferredReminderTime.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isOneOff.present) {
      map['is_one_off'] = Variable<bool>(isOneOff.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (planDayIndex.present) {
      map['plan_day_index'] = Variable<int>(planDayIndex.value);
    }
    if (planTotalDays.present) {
      map['plan_total_days'] = Variable<int>(planTotalDays.value);
    }
    if (recurrenceJson.present) {
      map['recurrence_json'] = Variable<String>(recurrenceJson.value);
    }
    if (rollingJson.present) {
      map['rolling_json'] = Variable<String>(rollingJson.value);
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceTasksCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('intervalAmount: $intervalAmount, ')
          ..write('intervalUnit: $intervalUnit, ')
          ..write('dueAt: $dueAt, ')
          ..write('preferredReminderTime: $preferredReminderTime, ')
          ..write('status: $status, ')
          ..write('isOneOff: $isOneOff, ')
          ..write('source: $source, ')
          ..write('planId: $planId, ')
          ..write('planDayIndex: $planDayIndex, ')
          ..write('planTotalDays: $planTotalDays, ')
          ..write('recurrenceJson: $recurrenceJson, ')
          ..write('rollingJson: $rollingJson, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MaintenanceCyclesTable extends MaintenanceCycles
    with TableInfo<$MaintenanceCyclesTable, MaintenanceCycleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MaintenanceCyclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _chemicalMeta = const VerificationMeta(
    'chemical',
  );
  @override
  late final GeneratedColumn<String> chemical = GeneratedColumn<String>(
    'chemical',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refillDateMeta = const VerificationMeta(
    'refillDate',
  );
  @override
  late final GeneratedColumn<String> refillDate = GeneratedColumn<String>(
    'refill_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _solutionMlMeta = const VerificationMeta(
    'solutionMl',
  );
  @override
  late final GeneratedColumn<double> solutionMl = GeneratedColumn<double>(
    'solution_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dailyLiquidMlMeta = const VerificationMeta(
    'dailyLiquidMl',
  );
  @override
  late final GeneratedColumn<double> dailyLiquidMl = GeneratedColumn<double>(
    'daily_liquid_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectPerMlMeta = const VerificationMeta(
    'effectPerMl',
  );
  @override
  late final GeneratedColumn<double> effectPerMl = GeneratedColumn<double>(
    'effect_per_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retainedMlMeta = const VerificationMeta(
    'retainedMl',
  );
  @override
  late final GeneratedColumn<double> retainedMl = GeneratedColumn<double>(
    'retained_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedStockMlMeta = const VerificationMeta(
    'addedStockMl',
  );
  @override
  late final GeneratedColumn<double> addedStockMl = GeneratedColumn<double>(
    'added_stock_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedWaterMlMeta = const VerificationMeta(
    'addedWaterMl',
  );
  @override
  late final GeneratedColumn<double> addedWaterMl = GeneratedColumn<double>(
    'added_water_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputJsonMeta = const VerificationMeta(
    'inputJson',
  );
  @override
  late final GeneratedColumn<String> inputJson = GeneratedColumn<String>(
    'input_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousCycleIdMeta = const VerificationMeta(
    'previousCycleId',
  );
  @override
  late final GeneratedColumn<String> previousCycleId = GeneratedColumn<String>(
    'previous_cycle_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedOnDateMeta = const VerificationMeta(
    'closedOnDate',
  );
  @override
  late final GeneratedColumn<String> closedOnDate = GeneratedColumn<String>(
    'closed_on_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refillDeferredUntilMeta =
      const VerificationMeta('refillDeferredUntil');
  @override
  late final GeneratedColumn<String> refillDeferredUntil =
      GeneratedColumn<String>(
        'refill_deferred_until',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _notificationIdMeta = const VerificationMeta(
    'notificationId',
  );
  @override
  late final GeneratedColumn<int> notificationId = GeneratedColumn<int>(
    'notification_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    chemical,
    startDate,
    refillDate,
    solutionMl,
    dailyLiquidMl,
    effectPerMl,
    retainedMl,
    addedStockMl,
    addedWaterMl,
    inputJson,
    previousCycleId,
    closedOnDate,
    refillDeferredUntil,
    notificationId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'maintenance_cycles';
  @override
  VerificationContext validateIntegrity(
    Insertable<MaintenanceCycleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('chemical')) {
      context.handle(
        _chemicalMeta,
        chemical.isAcceptableOrUnknown(data['chemical']!, _chemicalMeta),
      );
    } else if (isInserting) {
      context.missing(_chemicalMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('refill_date')) {
      context.handle(
        _refillDateMeta,
        refillDate.isAcceptableOrUnknown(data['refill_date']!, _refillDateMeta),
      );
    } else if (isInserting) {
      context.missing(_refillDateMeta);
    }
    if (data.containsKey('solution_ml')) {
      context.handle(
        _solutionMlMeta,
        solutionMl.isAcceptableOrUnknown(data['solution_ml']!, _solutionMlMeta),
      );
    } else if (isInserting) {
      context.missing(_solutionMlMeta);
    }
    if (data.containsKey('daily_liquid_ml')) {
      context.handle(
        _dailyLiquidMlMeta,
        dailyLiquidMl.isAcceptableOrUnknown(
          data['daily_liquid_ml']!,
          _dailyLiquidMlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyLiquidMlMeta);
    }
    if (data.containsKey('effect_per_ml')) {
      context.handle(
        _effectPerMlMeta,
        effectPerMl.isAcceptableOrUnknown(
          data['effect_per_ml']!,
          _effectPerMlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectPerMlMeta);
    }
    if (data.containsKey('retained_ml')) {
      context.handle(
        _retainedMlMeta,
        retainedMl.isAcceptableOrUnknown(data['retained_ml']!, _retainedMlMeta),
      );
    } else if (isInserting) {
      context.missing(_retainedMlMeta);
    }
    if (data.containsKey('added_stock_ml')) {
      context.handle(
        _addedStockMlMeta,
        addedStockMl.isAcceptableOrUnknown(
          data['added_stock_ml']!,
          _addedStockMlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedStockMlMeta);
    }
    if (data.containsKey('added_water_ml')) {
      context.handle(
        _addedWaterMlMeta,
        addedWaterMl.isAcceptableOrUnknown(
          data['added_water_ml']!,
          _addedWaterMlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedWaterMlMeta);
    }
    if (data.containsKey('input_json')) {
      context.handle(
        _inputJsonMeta,
        inputJson.isAcceptableOrUnknown(data['input_json']!, _inputJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_inputJsonMeta);
    }
    if (data.containsKey('previous_cycle_id')) {
      context.handle(
        _previousCycleIdMeta,
        previousCycleId.isAcceptableOrUnknown(
          data['previous_cycle_id']!,
          _previousCycleIdMeta,
        ),
      );
    }
    if (data.containsKey('closed_on_date')) {
      context.handle(
        _closedOnDateMeta,
        closedOnDate.isAcceptableOrUnknown(
          data['closed_on_date']!,
          _closedOnDateMeta,
        ),
      );
    }
    if (data.containsKey('refill_deferred_until')) {
      context.handle(
        _refillDeferredUntilMeta,
        refillDeferredUntil.isAcceptableOrUnknown(
          data['refill_deferred_until']!,
          _refillDeferredUntilMeta,
        ),
      );
    }
    if (data.containsKey('notification_id')) {
      context.handle(
        _notificationIdMeta,
        notificationId.isAcceptableOrUnknown(
          data['notification_id']!,
          _notificationIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MaintenanceCycleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MaintenanceCycleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      chemical: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chemical'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      refillDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refill_date'],
      )!,
      solutionMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}solution_ml'],
      )!,
      dailyLiquidMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}daily_liquid_ml'],
      )!,
      effectPerMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}effect_per_ml'],
      )!,
      retainedMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}retained_ml'],
      )!,
      addedStockMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}added_stock_ml'],
      )!,
      addedWaterMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}added_water_ml'],
      )!,
      inputJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_json'],
      )!,
      previousCycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_cycle_id'],
      ),
      closedOnDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_on_date'],
      ),
      refillDeferredUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refill_deferred_until'],
      ),
      notificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MaintenanceCyclesTable createAlias(String alias) {
    return $MaintenanceCyclesTable(attachedDatabase, alias);
  }
}

class MaintenanceCycleRow extends DataClass
    implements Insertable<MaintenanceCycleRow> {
  final String id;
  final String tankId;
  final String chemical;
  final String startDate;
  final String refillDate;
  final double solutionMl;
  final double dailyLiquidMl;
  final double effectPerMl;
  final double retainedMl;
  final double addedStockMl;
  final double addedWaterMl;
  final String inputJson;
  final String? previousCycleId;
  final String? closedOnDate;
  final String? refillDeferredUntil;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MaintenanceCycleRow({
    required this.id,
    required this.tankId,
    required this.chemical,
    required this.startDate,
    required this.refillDate,
    required this.solutionMl,
    required this.dailyLiquidMl,
    required this.effectPerMl,
    required this.retainedMl,
    required this.addedStockMl,
    required this.addedWaterMl,
    required this.inputJson,
    this.previousCycleId,
    this.closedOnDate,
    this.refillDeferredUntil,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tank_id'] = Variable<String>(tankId);
    map['chemical'] = Variable<String>(chemical);
    map['start_date'] = Variable<String>(startDate);
    map['refill_date'] = Variable<String>(refillDate);
    map['solution_ml'] = Variable<double>(solutionMl);
    map['daily_liquid_ml'] = Variable<double>(dailyLiquidMl);
    map['effect_per_ml'] = Variable<double>(effectPerMl);
    map['retained_ml'] = Variable<double>(retainedMl);
    map['added_stock_ml'] = Variable<double>(addedStockMl);
    map['added_water_ml'] = Variable<double>(addedWaterMl);
    map['input_json'] = Variable<String>(inputJson);
    if (!nullToAbsent || previousCycleId != null) {
      map['previous_cycle_id'] = Variable<String>(previousCycleId);
    }
    if (!nullToAbsent || closedOnDate != null) {
      map['closed_on_date'] = Variable<String>(closedOnDate);
    }
    if (!nullToAbsent || refillDeferredUntil != null) {
      map['refill_deferred_until'] = Variable<String>(refillDeferredUntil);
    }
    if (!nullToAbsent || notificationId != null) {
      map['notification_id'] = Variable<int>(notificationId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MaintenanceCyclesCompanion toCompanion(bool nullToAbsent) {
    return MaintenanceCyclesCompanion(
      id: Value(id),
      tankId: Value(tankId),
      chemical: Value(chemical),
      startDate: Value(startDate),
      refillDate: Value(refillDate),
      solutionMl: Value(solutionMl),
      dailyLiquidMl: Value(dailyLiquidMl),
      effectPerMl: Value(effectPerMl),
      retainedMl: Value(retainedMl),
      addedStockMl: Value(addedStockMl),
      addedWaterMl: Value(addedWaterMl),
      inputJson: Value(inputJson),
      previousCycleId: previousCycleId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousCycleId),
      closedOnDate: closedOnDate == null && nullToAbsent
          ? const Value.absent()
          : Value(closedOnDate),
      refillDeferredUntil: refillDeferredUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(refillDeferredUntil),
      notificationId: notificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(notificationId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MaintenanceCycleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MaintenanceCycleRow(
      id: serializer.fromJson<String>(json['id']),
      tankId: serializer.fromJson<String>(json['tankId']),
      chemical: serializer.fromJson<String>(json['chemical']),
      startDate: serializer.fromJson<String>(json['startDate']),
      refillDate: serializer.fromJson<String>(json['refillDate']),
      solutionMl: serializer.fromJson<double>(json['solutionMl']),
      dailyLiquidMl: serializer.fromJson<double>(json['dailyLiquidMl']),
      effectPerMl: serializer.fromJson<double>(json['effectPerMl']),
      retainedMl: serializer.fromJson<double>(json['retainedMl']),
      addedStockMl: serializer.fromJson<double>(json['addedStockMl']),
      addedWaterMl: serializer.fromJson<double>(json['addedWaterMl']),
      inputJson: serializer.fromJson<String>(json['inputJson']),
      previousCycleId: serializer.fromJson<String?>(json['previousCycleId']),
      closedOnDate: serializer.fromJson<String?>(json['closedOnDate']),
      refillDeferredUntil: serializer.fromJson<String?>(
        json['refillDeferredUntil'],
      ),
      notificationId: serializer.fromJson<int?>(json['notificationId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tankId': serializer.toJson<String>(tankId),
      'chemical': serializer.toJson<String>(chemical),
      'startDate': serializer.toJson<String>(startDate),
      'refillDate': serializer.toJson<String>(refillDate),
      'solutionMl': serializer.toJson<double>(solutionMl),
      'dailyLiquidMl': serializer.toJson<double>(dailyLiquidMl),
      'effectPerMl': serializer.toJson<double>(effectPerMl),
      'retainedMl': serializer.toJson<double>(retainedMl),
      'addedStockMl': serializer.toJson<double>(addedStockMl),
      'addedWaterMl': serializer.toJson<double>(addedWaterMl),
      'inputJson': serializer.toJson<String>(inputJson),
      'previousCycleId': serializer.toJson<String?>(previousCycleId),
      'closedOnDate': serializer.toJson<String?>(closedOnDate),
      'refillDeferredUntil': serializer.toJson<String?>(refillDeferredUntil),
      'notificationId': serializer.toJson<int?>(notificationId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MaintenanceCycleRow copyWith({
    String? id,
    String? tankId,
    String? chemical,
    String? startDate,
    String? refillDate,
    double? solutionMl,
    double? dailyLiquidMl,
    double? effectPerMl,
    double? retainedMl,
    double? addedStockMl,
    double? addedWaterMl,
    String? inputJson,
    Value<String?> previousCycleId = const Value.absent(),
    Value<String?> closedOnDate = const Value.absent(),
    Value<String?> refillDeferredUntil = const Value.absent(),
    Value<int?> notificationId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MaintenanceCycleRow(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    chemical: chemical ?? this.chemical,
    startDate: startDate ?? this.startDate,
    refillDate: refillDate ?? this.refillDate,
    solutionMl: solutionMl ?? this.solutionMl,
    dailyLiquidMl: dailyLiquidMl ?? this.dailyLiquidMl,
    effectPerMl: effectPerMl ?? this.effectPerMl,
    retainedMl: retainedMl ?? this.retainedMl,
    addedStockMl: addedStockMl ?? this.addedStockMl,
    addedWaterMl: addedWaterMl ?? this.addedWaterMl,
    inputJson: inputJson ?? this.inputJson,
    previousCycleId: previousCycleId.present
        ? previousCycleId.value
        : this.previousCycleId,
    closedOnDate: closedOnDate.present ? closedOnDate.value : this.closedOnDate,
    refillDeferredUntil: refillDeferredUntil.present
        ? refillDeferredUntil.value
        : this.refillDeferredUntil,
    notificationId: notificationId.present
        ? notificationId.value
        : this.notificationId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MaintenanceCycleRow copyWithCompanion(MaintenanceCyclesCompanion data) {
    return MaintenanceCycleRow(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      chemical: data.chemical.present ? data.chemical.value : this.chemical,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      refillDate: data.refillDate.present
          ? data.refillDate.value
          : this.refillDate,
      solutionMl: data.solutionMl.present
          ? data.solutionMl.value
          : this.solutionMl,
      dailyLiquidMl: data.dailyLiquidMl.present
          ? data.dailyLiquidMl.value
          : this.dailyLiquidMl,
      effectPerMl: data.effectPerMl.present
          ? data.effectPerMl.value
          : this.effectPerMl,
      retainedMl: data.retainedMl.present
          ? data.retainedMl.value
          : this.retainedMl,
      addedStockMl: data.addedStockMl.present
          ? data.addedStockMl.value
          : this.addedStockMl,
      addedWaterMl: data.addedWaterMl.present
          ? data.addedWaterMl.value
          : this.addedWaterMl,
      inputJson: data.inputJson.present ? data.inputJson.value : this.inputJson,
      previousCycleId: data.previousCycleId.present
          ? data.previousCycleId.value
          : this.previousCycleId,
      closedOnDate: data.closedOnDate.present
          ? data.closedOnDate.value
          : this.closedOnDate,
      refillDeferredUntil: data.refillDeferredUntil.present
          ? data.refillDeferredUntil.value
          : this.refillDeferredUntil,
      notificationId: data.notificationId.present
          ? data.notificationId.value
          : this.notificationId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceCycleRow(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('chemical: $chemical, ')
          ..write('startDate: $startDate, ')
          ..write('refillDate: $refillDate, ')
          ..write('solutionMl: $solutionMl, ')
          ..write('dailyLiquidMl: $dailyLiquidMl, ')
          ..write('effectPerMl: $effectPerMl, ')
          ..write('retainedMl: $retainedMl, ')
          ..write('addedStockMl: $addedStockMl, ')
          ..write('addedWaterMl: $addedWaterMl, ')
          ..write('inputJson: $inputJson, ')
          ..write('previousCycleId: $previousCycleId, ')
          ..write('closedOnDate: $closedOnDate, ')
          ..write('refillDeferredUntil: $refillDeferredUntil, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tankId,
    chemical,
    startDate,
    refillDate,
    solutionMl,
    dailyLiquidMl,
    effectPerMl,
    retainedMl,
    addedStockMl,
    addedWaterMl,
    inputJson,
    previousCycleId,
    closedOnDate,
    refillDeferredUntil,
    notificationId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MaintenanceCycleRow &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.chemical == this.chemical &&
          other.startDate == this.startDate &&
          other.refillDate == this.refillDate &&
          other.solutionMl == this.solutionMl &&
          other.dailyLiquidMl == this.dailyLiquidMl &&
          other.effectPerMl == this.effectPerMl &&
          other.retainedMl == this.retainedMl &&
          other.addedStockMl == this.addedStockMl &&
          other.addedWaterMl == this.addedWaterMl &&
          other.inputJson == this.inputJson &&
          other.previousCycleId == this.previousCycleId &&
          other.closedOnDate == this.closedOnDate &&
          other.refillDeferredUntil == this.refillDeferredUntil &&
          other.notificationId == this.notificationId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MaintenanceCyclesCompanion extends UpdateCompanion<MaintenanceCycleRow> {
  final Value<String> id;
  final Value<String> tankId;
  final Value<String> chemical;
  final Value<String> startDate;
  final Value<String> refillDate;
  final Value<double> solutionMl;
  final Value<double> dailyLiquidMl;
  final Value<double> effectPerMl;
  final Value<double> retainedMl;
  final Value<double> addedStockMl;
  final Value<double> addedWaterMl;
  final Value<String> inputJson;
  final Value<String?> previousCycleId;
  final Value<String?> closedOnDate;
  final Value<String?> refillDeferredUntil;
  final Value<int?> notificationId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MaintenanceCyclesCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.chemical = const Value.absent(),
    this.startDate = const Value.absent(),
    this.refillDate = const Value.absent(),
    this.solutionMl = const Value.absent(),
    this.dailyLiquidMl = const Value.absent(),
    this.effectPerMl = const Value.absent(),
    this.retainedMl = const Value.absent(),
    this.addedStockMl = const Value.absent(),
    this.addedWaterMl = const Value.absent(),
    this.inputJson = const Value.absent(),
    this.previousCycleId = const Value.absent(),
    this.closedOnDate = const Value.absent(),
    this.refillDeferredUntil = const Value.absent(),
    this.notificationId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MaintenanceCyclesCompanion.insert({
    required String id,
    required String tankId,
    required String chemical,
    required String startDate,
    required String refillDate,
    required double solutionMl,
    required double dailyLiquidMl,
    required double effectPerMl,
    required double retainedMl,
    required double addedStockMl,
    required double addedWaterMl,
    required String inputJson,
    this.previousCycleId = const Value.absent(),
    this.closedOnDate = const Value.absent(),
    this.refillDeferredUntil = const Value.absent(),
    this.notificationId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tankId = Value(tankId),
       chemical = Value(chemical),
       startDate = Value(startDate),
       refillDate = Value(refillDate),
       solutionMl = Value(solutionMl),
       dailyLiquidMl = Value(dailyLiquidMl),
       effectPerMl = Value(effectPerMl),
       retainedMl = Value(retainedMl),
       addedStockMl = Value(addedStockMl),
       addedWaterMl = Value(addedWaterMl),
       inputJson = Value(inputJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MaintenanceCycleRow> custom({
    Expression<String>? id,
    Expression<String>? tankId,
    Expression<String>? chemical,
    Expression<String>? startDate,
    Expression<String>? refillDate,
    Expression<double>? solutionMl,
    Expression<double>? dailyLiquidMl,
    Expression<double>? effectPerMl,
    Expression<double>? retainedMl,
    Expression<double>? addedStockMl,
    Expression<double>? addedWaterMl,
    Expression<String>? inputJson,
    Expression<String>? previousCycleId,
    Expression<String>? closedOnDate,
    Expression<String>? refillDeferredUntil,
    Expression<int>? notificationId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (chemical != null) 'chemical': chemical,
      if (startDate != null) 'start_date': startDate,
      if (refillDate != null) 'refill_date': refillDate,
      if (solutionMl != null) 'solution_ml': solutionMl,
      if (dailyLiquidMl != null) 'daily_liquid_ml': dailyLiquidMl,
      if (effectPerMl != null) 'effect_per_ml': effectPerMl,
      if (retainedMl != null) 'retained_ml': retainedMl,
      if (addedStockMl != null) 'added_stock_ml': addedStockMl,
      if (addedWaterMl != null) 'added_water_ml': addedWaterMl,
      if (inputJson != null) 'input_json': inputJson,
      if (previousCycleId != null) 'previous_cycle_id': previousCycleId,
      if (closedOnDate != null) 'closed_on_date': closedOnDate,
      if (refillDeferredUntil != null)
        'refill_deferred_until': refillDeferredUntil,
      if (notificationId != null) 'notification_id': notificationId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MaintenanceCyclesCompanion copyWith({
    Value<String>? id,
    Value<String>? tankId,
    Value<String>? chemical,
    Value<String>? startDate,
    Value<String>? refillDate,
    Value<double>? solutionMl,
    Value<double>? dailyLiquidMl,
    Value<double>? effectPerMl,
    Value<double>? retainedMl,
    Value<double>? addedStockMl,
    Value<double>? addedWaterMl,
    Value<String>? inputJson,
    Value<String?>? previousCycleId,
    Value<String?>? closedOnDate,
    Value<String?>? refillDeferredUntil,
    Value<int?>? notificationId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MaintenanceCyclesCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      chemical: chemical ?? this.chemical,
      startDate: startDate ?? this.startDate,
      refillDate: refillDate ?? this.refillDate,
      solutionMl: solutionMl ?? this.solutionMl,
      dailyLiquidMl: dailyLiquidMl ?? this.dailyLiquidMl,
      effectPerMl: effectPerMl ?? this.effectPerMl,
      retainedMl: retainedMl ?? this.retainedMl,
      addedStockMl: addedStockMl ?? this.addedStockMl,
      addedWaterMl: addedWaterMl ?? this.addedWaterMl,
      inputJson: inputJson ?? this.inputJson,
      previousCycleId: previousCycleId ?? this.previousCycleId,
      closedOnDate: closedOnDate ?? this.closedOnDate,
      refillDeferredUntil: refillDeferredUntil ?? this.refillDeferredUntil,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (chemical.present) {
      map['chemical'] = Variable<String>(chemical.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (refillDate.present) {
      map['refill_date'] = Variable<String>(refillDate.value);
    }
    if (solutionMl.present) {
      map['solution_ml'] = Variable<double>(solutionMl.value);
    }
    if (dailyLiquidMl.present) {
      map['daily_liquid_ml'] = Variable<double>(dailyLiquidMl.value);
    }
    if (effectPerMl.present) {
      map['effect_per_ml'] = Variable<double>(effectPerMl.value);
    }
    if (retainedMl.present) {
      map['retained_ml'] = Variable<double>(retainedMl.value);
    }
    if (addedStockMl.present) {
      map['added_stock_ml'] = Variable<double>(addedStockMl.value);
    }
    if (addedWaterMl.present) {
      map['added_water_ml'] = Variable<double>(addedWaterMl.value);
    }
    if (inputJson.present) {
      map['input_json'] = Variable<String>(inputJson.value);
    }
    if (previousCycleId.present) {
      map['previous_cycle_id'] = Variable<String>(previousCycleId.value);
    }
    if (closedOnDate.present) {
      map['closed_on_date'] = Variable<String>(closedOnDate.value);
    }
    if (refillDeferredUntil.present) {
      map['refill_deferred_until'] = Variable<String>(
        refillDeferredUntil.value,
      );
    }
    if (notificationId.present) {
      map['notification_id'] = Variable<int>(notificationId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MaintenanceCyclesCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('chemical: $chemical, ')
          ..write('startDate: $startDate, ')
          ..write('refillDate: $refillDate, ')
          ..write('solutionMl: $solutionMl, ')
          ..write('dailyLiquidMl: $dailyLiquidMl, ')
          ..write('effectPerMl: $effectPerMl, ')
          ..write('retainedMl: $retainedMl, ')
          ..write('addedStockMl: $addedStockMl, ')
          ..write('addedWaterMl: $addedWaterMl, ')
          ..write('inputJson: $inputJson, ')
          ..write('previousCycleId: $previousCycleId, ')
          ..write('closedOnDate: $closedOnDate, ')
          ..write('refillDeferredUntil: $refillDeferredUntil, ')
          ..write('notificationId: $notificationId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskEventsTable extends TaskEvents
    with TableInfo<$TaskEventsTable, TaskEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES maintenance_tasks (id)',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    type,
    occurredAt,
    snoozedUntil,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $TaskEventsTable createAlias(String alias) {
    return $TaskEventsTable(attachedDatabase, alias);
  }
}

class TaskEvent extends DataClass implements Insertable<TaskEvent> {
  final String id;
  final String taskId;
  final String type;
  final DateTime occurredAt;
  final DateTime? snoozedUntil;
  final String? note;
  const TaskEvent({
    required this.id,
    required this.taskId,
    required this.type,
    required this.occurredAt,
    this.snoozedUntil,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['type'] = Variable<String>(type);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  TaskEventsCompanion toCompanion(bool nullToAbsent) {
    return TaskEventsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      type: Value(type),
      occurredAt: Value(occurredAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory TaskEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskEvent(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      type: serializer.fromJson<String>(json['type']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'type': serializer.toJson<String>(type),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'note': serializer.toJson<String?>(note),
    };
  }

  TaskEvent copyWith({
    String? id,
    String? taskId,
    String? type,
    DateTime? occurredAt,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => TaskEvent(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    type: type ?? this.type,
    occurredAt: occurredAt ?? this.occurredAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    note: note.present ? note.value : this.note,
  );
  TaskEvent copyWithCompanion(TaskEventsCompanion data) {
    return TaskEvent(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      type: data.type.present ? data.type.value : this.type,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskEvent(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, taskId, type, occurredAt, snoozedUntil, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskEvent &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.type == this.type &&
          other.occurredAt == this.occurredAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.note == this.note);
}

class TaskEventsCompanion extends UpdateCompanion<TaskEvent> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> type;
  final Value<DateTime> occurredAt;
  final Value<DateTime?> snoozedUntil;
  final Value<String?> note;
  final Value<int> rowid;
  const TaskEventsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.type = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskEventsCompanion.insert({
    required String id,
    required String taskId,
    required String type,
    required DateTime occurredAt,
    this.snoozedUntil = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       type = Value(type),
       occurredAt = Value(occurredAt);
  static Insertable<TaskEvent> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? type,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? snoozedUntil,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (type != null) 'type': type,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? type,
    Value<DateTime>? occurredAt,
    Value<DateTime?>? snoozedUntil,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return TaskEventsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskEventsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TestTimerDefaultsTable extends TestTimerDefaults
    with TableInfo<$TestTimerDefaultsTable, TestTimerDefault> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TestTimerDefaultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tankId,
    parameterId,
    durationSeconds,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'test_timer_defaults';
  @override
  VerificationContext validateIntegrity(
    Insertable<TestTimerDefault> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tankId, parameterId};
  @override
  TestTimerDefault map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TestTimerDefault(
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TestTimerDefaultsTable createAlias(String alias) {
    return $TestTimerDefaultsTable(attachedDatabase, alias);
  }
}

class TestTimerDefault extends DataClass
    implements Insertable<TestTimerDefault> {
  final String tankId;
  final String parameterId;
  final int durationSeconds;
  final DateTime updatedAt;
  const TestTimerDefault({
    required this.tankId,
    required this.parameterId,
    required this.durationSeconds,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tank_id'] = Variable<String>(tankId);
    map['parameter_id'] = Variable<String>(parameterId);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TestTimerDefaultsCompanion toCompanion(bool nullToAbsent) {
    return TestTimerDefaultsCompanion(
      tankId: Value(tankId),
      parameterId: Value(parameterId),
      durationSeconds: Value(durationSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory TestTimerDefault.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TestTimerDefault(
      tankId: serializer.fromJson<String>(json['tankId']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tankId': serializer.toJson<String>(tankId),
      'parameterId': serializer.toJson<String>(parameterId),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TestTimerDefault copyWith({
    String? tankId,
    String? parameterId,
    int? durationSeconds,
    DateTime? updatedAt,
  }) => TestTimerDefault(
    tankId: tankId ?? this.tankId,
    parameterId: parameterId ?? this.parameterId,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TestTimerDefault copyWithCompanion(TestTimerDefaultsCompanion data) {
    return TestTimerDefault(
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TestTimerDefault(')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(tankId, parameterId, durationSeconds, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TestTimerDefault &&
          other.tankId == this.tankId &&
          other.parameterId == this.parameterId &&
          other.durationSeconds == this.durationSeconds &&
          other.updatedAt == this.updatedAt);
}

class TestTimerDefaultsCompanion extends UpdateCompanion<TestTimerDefault> {
  final Value<String> tankId;
  final Value<String> parameterId;
  final Value<int> durationSeconds;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TestTimerDefaultsCompanion({
    this.tankId = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TestTimerDefaultsCompanion.insert({
    required String tankId,
    required String parameterId,
    required int durationSeconds,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : tankId = Value(tankId),
       parameterId = Value(parameterId),
       durationSeconds = Value(durationSeconds),
       updatedAt = Value(updatedAt);
  static Insertable<TestTimerDefault> custom({
    Expression<String>? tankId,
    Expression<String>? parameterId,
    Expression<int>? durationSeconds,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tankId != null) 'tank_id': tankId,
      if (parameterId != null) 'parameter_id': parameterId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TestTimerDefaultsCompanion copyWith({
    Value<String>? tankId,
    Value<String>? parameterId,
    Value<int>? durationSeconds,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TestTimerDefaultsCompanion(
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TestTimerDefaultsCompanion(')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveTestSessionsTable extends ActiveTestSessions
    with TableInfo<$ActiveTestSessionsTable, ActiveTestSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveTestSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tankIdMeta = const VerificationMeta('tankId');
  @override
  late final GeneratedColumn<String> tankId = GeneratedColumn<String>(
    'tank_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tanks (id)',
    ),
  );
  static const VerificationMeta _parameterIdMeta = const VerificationMeta(
    'parameterId',
  );
  @override
  late final GeneratedColumn<String> parameterId = GeneratedColumn<String>(
    'parameter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES water_parameters (id)',
    ),
  );
  static const VerificationMeta _reagentProfileIdMeta = const VerificationMeta(
    'reagentProfileId',
  );
  @override
  late final GeneratedColumn<String> reagentProfileId = GeneratedColumn<String>(
    'reagent_profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reagent_profiles (id)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timerDurationSecondsMeta =
      const VerificationMeta('timerDurationSeconds');
  @override
  late final GeneratedColumn<int> timerDurationSeconds = GeneratedColumn<int>(
    'timer_duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timerEndsAtMeta = const VerificationMeta(
    'timerEndsAt',
  );
  @override
  late final GeneratedColumn<DateTime> timerEndsAt = GeneratedColumn<DateTime>(
    'timer_ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedRemainingSecondsMeta =
      const VerificationMeta('pausedRemainingSeconds');
  @override
  late final GeneratedColumn<int> pausedRemainingSeconds = GeneratedColumn<int>(
    'paused_remaining_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _draftPhotoPathMeta = const VerificationMeta(
    'draftPhotoPath',
  );
  @override
  late final GeneratedColumn<String> draftPhotoPath = GeneratedColumn<String>(
    'draft_photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _draftCapturedAtMeta = const VerificationMeta(
    'draftCapturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> draftCapturedAt =
      GeneratedColumn<DateTime>(
        'draft_captured_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftEstimatedMinValueMeta =
      const VerificationMeta('draftEstimatedMinValue');
  @override
  late final GeneratedColumn<double> draftEstimatedMinValue =
      GeneratedColumn<double>(
        'draft_estimated_min_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftEstimatedMaxValueMeta =
      const VerificationMeta('draftEstimatedMaxValue');
  @override
  late final GeneratedColumn<double> draftEstimatedMaxValue =
      GeneratedColumn<double>(
        'draft_estimated_max_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftEstimationMethodMeta =
      const VerificationMeta('draftEstimationMethod');
  @override
  late final GeneratedColumn<String> draftEstimationMethod =
      GeneratedColumn<String>(
        'draft_estimation_method',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftEstimationVersionMeta =
      const VerificationMeta('draftEstimationVersion');
  @override
  late final GeneratedColumn<String> draftEstimationVersion =
      GeneratedColumn<String>(
        'draft_estimation_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftQualityScoreMeta = const VerificationMeta(
    'draftQualityScore',
  );
  @override
  late final GeneratedColumn<double> draftQualityScore =
      GeneratedColumn<double>(
        'draft_quality_score',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftConfidenceMeta = const VerificationMeta(
    'draftConfidence',
  );
  @override
  late final GeneratedColumn<String> draftConfidence = GeneratedColumn<String>(
    'draft_confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _draftFailureReasonMeta =
      const VerificationMeta('draftFailureReason');
  @override
  late final GeneratedColumn<String> draftFailureReason =
      GeneratedColumn<String>(
        'draft_failure_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftConfirmedMinValueMeta =
      const VerificationMeta('draftConfirmedMinValue');
  @override
  late final GeneratedColumn<double> draftConfirmedMinValue =
      GeneratedColumn<double>(
        'draft_confirmed_min_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftConfirmedInterpolationMeta =
      const VerificationMeta('draftConfirmedInterpolation');
  @override
  late final GeneratedColumn<double> draftConfirmedInterpolation =
      GeneratedColumn<double>(
        'draft_confirmed_interpolation',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftEstimatedInterpolationMeta =
      const VerificationMeta('draftEstimatedInterpolation');
  @override
  late final GeneratedColumn<double> draftEstimatedInterpolation =
      GeneratedColumn<double>(
        'draft_estimated_interpolation',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftConfirmedMaxValueMeta =
      const VerificationMeta('draftConfirmedMaxValue');
  @override
  late final GeneratedColumn<double> draftConfirmedMaxValue =
      GeneratedColumn<double>(
        'draft_confirmed_max_value',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftConfirmedAtMeta = const VerificationMeta(
    'draftConfirmedAt',
  );
  @override
  late final GeneratedColumn<DateTime> draftConfirmedAt =
      GeneratedColumn<DateTime>(
        'draft_confirmed_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _draftNotesMeta = const VerificationMeta(
    'draftNotes',
  );
  @override
  late final GeneratedColumn<String> draftNotes = GeneratedColumn<String>(
    'draft_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tankId,
    parameterId,
    reagentProfileId,
    startedAt,
    timerDurationSeconds,
    timerEndsAt,
    pausedRemainingSeconds,
    draftPhotoPath,
    draftCapturedAt,
    draftEstimatedMinValue,
    draftEstimatedMaxValue,
    draftEstimationMethod,
    draftEstimationVersion,
    draftQualityScore,
    draftConfidence,
    draftFailureReason,
    draftConfirmedMinValue,
    draftConfirmedInterpolation,
    draftEstimatedInterpolation,
    draftConfirmedMaxValue,
    draftConfirmedAt,
    draftNotes,
    stage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_test_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveTestSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tank_id')) {
      context.handle(
        _tankIdMeta,
        tankId.isAcceptableOrUnknown(data['tank_id']!, _tankIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tankIdMeta);
    }
    if (data.containsKey('parameter_id')) {
      context.handle(
        _parameterIdMeta,
        parameterId.isAcceptableOrUnknown(
          data['parameter_id']!,
          _parameterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_parameterIdMeta);
    }
    if (data.containsKey('reagent_profile_id')) {
      context.handle(
        _reagentProfileIdMeta,
        reagentProfileId.isAcceptableOrUnknown(
          data['reagent_profile_id']!,
          _reagentProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('timer_duration_seconds')) {
      context.handle(
        _timerDurationSecondsMeta,
        timerDurationSeconds.isAcceptableOrUnknown(
          data['timer_duration_seconds']!,
          _timerDurationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timerDurationSecondsMeta);
    }
    if (data.containsKey('timer_ends_at')) {
      context.handle(
        _timerEndsAtMeta,
        timerEndsAt.isAcceptableOrUnknown(
          data['timer_ends_at']!,
          _timerEndsAtMeta,
        ),
      );
    }
    if (data.containsKey('paused_remaining_seconds')) {
      context.handle(
        _pausedRemainingSecondsMeta,
        pausedRemainingSeconds.isAcceptableOrUnknown(
          data['paused_remaining_seconds']!,
          _pausedRemainingSecondsMeta,
        ),
      );
    }
    if (data.containsKey('draft_photo_path')) {
      context.handle(
        _draftPhotoPathMeta,
        draftPhotoPath.isAcceptableOrUnknown(
          data['draft_photo_path']!,
          _draftPhotoPathMeta,
        ),
      );
    }
    if (data.containsKey('draft_captured_at')) {
      context.handle(
        _draftCapturedAtMeta,
        draftCapturedAt.isAcceptableOrUnknown(
          data['draft_captured_at']!,
          _draftCapturedAtMeta,
        ),
      );
    }
    if (data.containsKey('draft_estimated_min_value')) {
      context.handle(
        _draftEstimatedMinValueMeta,
        draftEstimatedMinValue.isAcceptableOrUnknown(
          data['draft_estimated_min_value']!,
          _draftEstimatedMinValueMeta,
        ),
      );
    }
    if (data.containsKey('draft_estimated_max_value')) {
      context.handle(
        _draftEstimatedMaxValueMeta,
        draftEstimatedMaxValue.isAcceptableOrUnknown(
          data['draft_estimated_max_value']!,
          _draftEstimatedMaxValueMeta,
        ),
      );
    }
    if (data.containsKey('draft_estimation_method')) {
      context.handle(
        _draftEstimationMethodMeta,
        draftEstimationMethod.isAcceptableOrUnknown(
          data['draft_estimation_method']!,
          _draftEstimationMethodMeta,
        ),
      );
    }
    if (data.containsKey('draft_estimation_version')) {
      context.handle(
        _draftEstimationVersionMeta,
        draftEstimationVersion.isAcceptableOrUnknown(
          data['draft_estimation_version']!,
          _draftEstimationVersionMeta,
        ),
      );
    }
    if (data.containsKey('draft_quality_score')) {
      context.handle(
        _draftQualityScoreMeta,
        draftQualityScore.isAcceptableOrUnknown(
          data['draft_quality_score']!,
          _draftQualityScoreMeta,
        ),
      );
    }
    if (data.containsKey('draft_confidence')) {
      context.handle(
        _draftConfidenceMeta,
        draftConfidence.isAcceptableOrUnknown(
          data['draft_confidence']!,
          _draftConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('draft_failure_reason')) {
      context.handle(
        _draftFailureReasonMeta,
        draftFailureReason.isAcceptableOrUnknown(
          data['draft_failure_reason']!,
          _draftFailureReasonMeta,
        ),
      );
    }
    if (data.containsKey('draft_confirmed_min_value')) {
      context.handle(
        _draftConfirmedMinValueMeta,
        draftConfirmedMinValue.isAcceptableOrUnknown(
          data['draft_confirmed_min_value']!,
          _draftConfirmedMinValueMeta,
        ),
      );
    }
    if (data.containsKey('draft_confirmed_interpolation')) {
      context.handle(
        _draftConfirmedInterpolationMeta,
        draftConfirmedInterpolation.isAcceptableOrUnknown(
          data['draft_confirmed_interpolation']!,
          _draftConfirmedInterpolationMeta,
        ),
      );
    }
    if (data.containsKey('draft_estimated_interpolation')) {
      context.handle(
        _draftEstimatedInterpolationMeta,
        draftEstimatedInterpolation.isAcceptableOrUnknown(
          data['draft_estimated_interpolation']!,
          _draftEstimatedInterpolationMeta,
        ),
      );
    }
    if (data.containsKey('draft_confirmed_max_value')) {
      context.handle(
        _draftConfirmedMaxValueMeta,
        draftConfirmedMaxValue.isAcceptableOrUnknown(
          data['draft_confirmed_max_value']!,
          _draftConfirmedMaxValueMeta,
        ),
      );
    }
    if (data.containsKey('draft_confirmed_at')) {
      context.handle(
        _draftConfirmedAtMeta,
        draftConfirmedAt.isAcceptableOrUnknown(
          data['draft_confirmed_at']!,
          _draftConfirmedAtMeta,
        ),
      );
    }
    if (data.containsKey('draft_notes')) {
      context.handle(
        _draftNotesMeta,
        draftNotes.isAcceptableOrUnknown(data['draft_notes']!, _draftNotesMeta),
      );
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tankId, parameterId},
  ];
  @override
  ActiveTestSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveTestSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tankId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tank_id'],
      )!,
      parameterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parameter_id'],
      )!,
      reagentProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reagent_profile_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      timerDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timer_duration_seconds'],
      )!,
      timerEndsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timer_ends_at'],
      ),
      pausedRemainingSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_remaining_seconds'],
      ),
      draftPhotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_photo_path'],
      ),
      draftCapturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}draft_captured_at'],
      ),
      draftEstimatedMinValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_estimated_min_value'],
      ),
      draftEstimatedMaxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_estimated_max_value'],
      ),
      draftEstimationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_estimation_method'],
      ),
      draftEstimationVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_estimation_version'],
      ),
      draftQualityScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_quality_score'],
      ),
      draftConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_confidence'],
      ),
      draftFailureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_failure_reason'],
      ),
      draftConfirmedMinValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_confirmed_min_value'],
      ),
      draftConfirmedInterpolation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_confirmed_interpolation'],
      ),
      draftEstimatedInterpolation: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_estimated_interpolation'],
      ),
      draftConfirmedMaxValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}draft_confirmed_max_value'],
      ),
      draftConfirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}draft_confirmed_at'],
      ),
      draftNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_notes'],
      ),
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ActiveTestSessionsTable createAlias(String alias) {
    return $ActiveTestSessionsTable(attachedDatabase, alias);
  }
}

class ActiveTestSession extends DataClass
    implements Insertable<ActiveTestSession> {
  final String id;
  final String tankId;
  final String parameterId;
  final String? reagentProfileId;
  final DateTime startedAt;
  final int timerDurationSeconds;
  final DateTime? timerEndsAt;
  final int? pausedRemainingSeconds;
  final String? draftPhotoPath;
  final DateTime? draftCapturedAt;
  final double? draftEstimatedMinValue;
  final double? draftEstimatedMaxValue;
  final String? draftEstimationMethod;
  final String? draftEstimationVersion;
  final double? draftQualityScore;
  final String? draftConfidence;
  final String? draftFailureReason;
  final double? draftConfirmedMinValue;
  final double? draftConfirmedInterpolation;
  final double? draftEstimatedInterpolation;
  final double? draftConfirmedMaxValue;
  final DateTime? draftConfirmedAt;
  final String? draftNotes;
  final String stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ActiveTestSession({
    required this.id,
    required this.tankId,
    required this.parameterId,
    this.reagentProfileId,
    required this.startedAt,
    required this.timerDurationSeconds,
    this.timerEndsAt,
    this.pausedRemainingSeconds,
    this.draftPhotoPath,
    this.draftCapturedAt,
    this.draftEstimatedMinValue,
    this.draftEstimatedMaxValue,
    this.draftEstimationMethod,
    this.draftEstimationVersion,
    this.draftQualityScore,
    this.draftConfidence,
    this.draftFailureReason,
    this.draftConfirmedMinValue,
    this.draftConfirmedInterpolation,
    this.draftEstimatedInterpolation,
    this.draftConfirmedMaxValue,
    this.draftConfirmedAt,
    this.draftNotes,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tank_id'] = Variable<String>(tankId);
    map['parameter_id'] = Variable<String>(parameterId);
    if (!nullToAbsent || reagentProfileId != null) {
      map['reagent_profile_id'] = Variable<String>(reagentProfileId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['timer_duration_seconds'] = Variable<int>(timerDurationSeconds);
    if (!nullToAbsent || timerEndsAt != null) {
      map['timer_ends_at'] = Variable<DateTime>(timerEndsAt);
    }
    if (!nullToAbsent || pausedRemainingSeconds != null) {
      map['paused_remaining_seconds'] = Variable<int>(pausedRemainingSeconds);
    }
    if (!nullToAbsent || draftPhotoPath != null) {
      map['draft_photo_path'] = Variable<String>(draftPhotoPath);
    }
    if (!nullToAbsent || draftCapturedAt != null) {
      map['draft_captured_at'] = Variable<DateTime>(draftCapturedAt);
    }
    if (!nullToAbsent || draftEstimatedMinValue != null) {
      map['draft_estimated_min_value'] = Variable<double>(
        draftEstimatedMinValue,
      );
    }
    if (!nullToAbsent || draftEstimatedMaxValue != null) {
      map['draft_estimated_max_value'] = Variable<double>(
        draftEstimatedMaxValue,
      );
    }
    if (!nullToAbsent || draftEstimationMethod != null) {
      map['draft_estimation_method'] = Variable<String>(draftEstimationMethod);
    }
    if (!nullToAbsent || draftEstimationVersion != null) {
      map['draft_estimation_version'] = Variable<String>(
        draftEstimationVersion,
      );
    }
    if (!nullToAbsent || draftQualityScore != null) {
      map['draft_quality_score'] = Variable<double>(draftQualityScore);
    }
    if (!nullToAbsent || draftConfidence != null) {
      map['draft_confidence'] = Variable<String>(draftConfidence);
    }
    if (!nullToAbsent || draftFailureReason != null) {
      map['draft_failure_reason'] = Variable<String>(draftFailureReason);
    }
    if (!nullToAbsent || draftConfirmedMinValue != null) {
      map['draft_confirmed_min_value'] = Variable<double>(
        draftConfirmedMinValue,
      );
    }
    if (!nullToAbsent || draftConfirmedInterpolation != null) {
      map['draft_confirmed_interpolation'] = Variable<double>(
        draftConfirmedInterpolation,
      );
    }
    if (!nullToAbsent || draftEstimatedInterpolation != null) {
      map['draft_estimated_interpolation'] = Variable<double>(
        draftEstimatedInterpolation,
      );
    }
    if (!nullToAbsent || draftConfirmedMaxValue != null) {
      map['draft_confirmed_max_value'] = Variable<double>(
        draftConfirmedMaxValue,
      );
    }
    if (!nullToAbsent || draftConfirmedAt != null) {
      map['draft_confirmed_at'] = Variable<DateTime>(draftConfirmedAt);
    }
    if (!nullToAbsent || draftNotes != null) {
      map['draft_notes'] = Variable<String>(draftNotes);
    }
    map['stage'] = Variable<String>(stage);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ActiveTestSessionsCompanion toCompanion(bool nullToAbsent) {
    return ActiveTestSessionsCompanion(
      id: Value(id),
      tankId: Value(tankId),
      parameterId: Value(parameterId),
      reagentProfileId: reagentProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(reagentProfileId),
      startedAt: Value(startedAt),
      timerDurationSeconds: Value(timerDurationSeconds),
      timerEndsAt: timerEndsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(timerEndsAt),
      pausedRemainingSeconds: pausedRemainingSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedRemainingSeconds),
      draftPhotoPath: draftPhotoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(draftPhotoPath),
      draftCapturedAt: draftCapturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(draftCapturedAt),
      draftEstimatedMinValue: draftEstimatedMinValue == null && nullToAbsent
          ? const Value.absent()
          : Value(draftEstimatedMinValue),
      draftEstimatedMaxValue: draftEstimatedMaxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(draftEstimatedMaxValue),
      draftEstimationMethod: draftEstimationMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(draftEstimationMethod),
      draftEstimationVersion: draftEstimationVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(draftEstimationVersion),
      draftQualityScore: draftQualityScore == null && nullToAbsent
          ? const Value.absent()
          : Value(draftQualityScore),
      draftConfidence: draftConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(draftConfidence),
      draftFailureReason: draftFailureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(draftFailureReason),
      draftConfirmedMinValue: draftConfirmedMinValue == null && nullToAbsent
          ? const Value.absent()
          : Value(draftConfirmedMinValue),
      draftConfirmedInterpolation:
          draftConfirmedInterpolation == null && nullToAbsent
          ? const Value.absent()
          : Value(draftConfirmedInterpolation),
      draftEstimatedInterpolation:
          draftEstimatedInterpolation == null && nullToAbsent
          ? const Value.absent()
          : Value(draftEstimatedInterpolation),
      draftConfirmedMaxValue: draftConfirmedMaxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(draftConfirmedMaxValue),
      draftConfirmedAt: draftConfirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(draftConfirmedAt),
      draftNotes: draftNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(draftNotes),
      stage: Value(stage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ActiveTestSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveTestSession(
      id: serializer.fromJson<String>(json['id']),
      tankId: serializer.fromJson<String>(json['tankId']),
      parameterId: serializer.fromJson<String>(json['parameterId']),
      reagentProfileId: serializer.fromJson<String?>(json['reagentProfileId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      timerDurationSeconds: serializer.fromJson<int>(
        json['timerDurationSeconds'],
      ),
      timerEndsAt: serializer.fromJson<DateTime?>(json['timerEndsAt']),
      pausedRemainingSeconds: serializer.fromJson<int?>(
        json['pausedRemainingSeconds'],
      ),
      draftPhotoPath: serializer.fromJson<String?>(json['draftPhotoPath']),
      draftCapturedAt: serializer.fromJson<DateTime?>(json['draftCapturedAt']),
      draftEstimatedMinValue: serializer.fromJson<double?>(
        json['draftEstimatedMinValue'],
      ),
      draftEstimatedMaxValue: serializer.fromJson<double?>(
        json['draftEstimatedMaxValue'],
      ),
      draftEstimationMethod: serializer.fromJson<String?>(
        json['draftEstimationMethod'],
      ),
      draftEstimationVersion: serializer.fromJson<String?>(
        json['draftEstimationVersion'],
      ),
      draftQualityScore: serializer.fromJson<double?>(
        json['draftQualityScore'],
      ),
      draftConfidence: serializer.fromJson<String?>(json['draftConfidence']),
      draftFailureReason: serializer.fromJson<String?>(
        json['draftFailureReason'],
      ),
      draftConfirmedMinValue: serializer.fromJson<double?>(
        json['draftConfirmedMinValue'],
      ),
      draftConfirmedInterpolation: serializer.fromJson<double?>(
        json['draftConfirmedInterpolation'],
      ),
      draftEstimatedInterpolation: serializer.fromJson<double?>(
        json['draftEstimatedInterpolation'],
      ),
      draftConfirmedMaxValue: serializer.fromJson<double?>(
        json['draftConfirmedMaxValue'],
      ),
      draftConfirmedAt: serializer.fromJson<DateTime?>(
        json['draftConfirmedAt'],
      ),
      draftNotes: serializer.fromJson<String?>(json['draftNotes']),
      stage: serializer.fromJson<String>(json['stage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tankId': serializer.toJson<String>(tankId),
      'parameterId': serializer.toJson<String>(parameterId),
      'reagentProfileId': serializer.toJson<String?>(reagentProfileId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'timerDurationSeconds': serializer.toJson<int>(timerDurationSeconds),
      'timerEndsAt': serializer.toJson<DateTime?>(timerEndsAt),
      'pausedRemainingSeconds': serializer.toJson<int?>(pausedRemainingSeconds),
      'draftPhotoPath': serializer.toJson<String?>(draftPhotoPath),
      'draftCapturedAt': serializer.toJson<DateTime?>(draftCapturedAt),
      'draftEstimatedMinValue': serializer.toJson<double?>(
        draftEstimatedMinValue,
      ),
      'draftEstimatedMaxValue': serializer.toJson<double?>(
        draftEstimatedMaxValue,
      ),
      'draftEstimationMethod': serializer.toJson<String?>(
        draftEstimationMethod,
      ),
      'draftEstimationVersion': serializer.toJson<String?>(
        draftEstimationVersion,
      ),
      'draftQualityScore': serializer.toJson<double?>(draftQualityScore),
      'draftConfidence': serializer.toJson<String?>(draftConfidence),
      'draftFailureReason': serializer.toJson<String?>(draftFailureReason),
      'draftConfirmedMinValue': serializer.toJson<double?>(
        draftConfirmedMinValue,
      ),
      'draftConfirmedInterpolation': serializer.toJson<double?>(
        draftConfirmedInterpolation,
      ),
      'draftEstimatedInterpolation': serializer.toJson<double?>(
        draftEstimatedInterpolation,
      ),
      'draftConfirmedMaxValue': serializer.toJson<double?>(
        draftConfirmedMaxValue,
      ),
      'draftConfirmedAt': serializer.toJson<DateTime?>(draftConfirmedAt),
      'draftNotes': serializer.toJson<String?>(draftNotes),
      'stage': serializer.toJson<String>(stage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ActiveTestSession copyWith({
    String? id,
    String? tankId,
    String? parameterId,
    Value<String?> reagentProfileId = const Value.absent(),
    DateTime? startedAt,
    int? timerDurationSeconds,
    Value<DateTime?> timerEndsAt = const Value.absent(),
    Value<int?> pausedRemainingSeconds = const Value.absent(),
    Value<String?> draftPhotoPath = const Value.absent(),
    Value<DateTime?> draftCapturedAt = const Value.absent(),
    Value<double?> draftEstimatedMinValue = const Value.absent(),
    Value<double?> draftEstimatedMaxValue = const Value.absent(),
    Value<String?> draftEstimationMethod = const Value.absent(),
    Value<String?> draftEstimationVersion = const Value.absent(),
    Value<double?> draftQualityScore = const Value.absent(),
    Value<String?> draftConfidence = const Value.absent(),
    Value<String?> draftFailureReason = const Value.absent(),
    Value<double?> draftConfirmedMinValue = const Value.absent(),
    Value<double?> draftConfirmedInterpolation = const Value.absent(),
    Value<double?> draftEstimatedInterpolation = const Value.absent(),
    Value<double?> draftConfirmedMaxValue = const Value.absent(),
    Value<DateTime?> draftConfirmedAt = const Value.absent(),
    Value<String?> draftNotes = const Value.absent(),
    String? stage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ActiveTestSession(
    id: id ?? this.id,
    tankId: tankId ?? this.tankId,
    parameterId: parameterId ?? this.parameterId,
    reagentProfileId: reagentProfileId.present
        ? reagentProfileId.value
        : this.reagentProfileId,
    startedAt: startedAt ?? this.startedAt,
    timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
    timerEndsAt: timerEndsAt.present ? timerEndsAt.value : this.timerEndsAt,
    pausedRemainingSeconds: pausedRemainingSeconds.present
        ? pausedRemainingSeconds.value
        : this.pausedRemainingSeconds,
    draftPhotoPath: draftPhotoPath.present
        ? draftPhotoPath.value
        : this.draftPhotoPath,
    draftCapturedAt: draftCapturedAt.present
        ? draftCapturedAt.value
        : this.draftCapturedAt,
    draftEstimatedMinValue: draftEstimatedMinValue.present
        ? draftEstimatedMinValue.value
        : this.draftEstimatedMinValue,
    draftEstimatedMaxValue: draftEstimatedMaxValue.present
        ? draftEstimatedMaxValue.value
        : this.draftEstimatedMaxValue,
    draftEstimationMethod: draftEstimationMethod.present
        ? draftEstimationMethod.value
        : this.draftEstimationMethod,
    draftEstimationVersion: draftEstimationVersion.present
        ? draftEstimationVersion.value
        : this.draftEstimationVersion,
    draftQualityScore: draftQualityScore.present
        ? draftQualityScore.value
        : this.draftQualityScore,
    draftConfidence: draftConfidence.present
        ? draftConfidence.value
        : this.draftConfidence,
    draftFailureReason: draftFailureReason.present
        ? draftFailureReason.value
        : this.draftFailureReason,
    draftConfirmedMinValue: draftConfirmedMinValue.present
        ? draftConfirmedMinValue.value
        : this.draftConfirmedMinValue,
    draftConfirmedInterpolation: draftConfirmedInterpolation.present
        ? draftConfirmedInterpolation.value
        : this.draftConfirmedInterpolation,
    draftEstimatedInterpolation: draftEstimatedInterpolation.present
        ? draftEstimatedInterpolation.value
        : this.draftEstimatedInterpolation,
    draftConfirmedMaxValue: draftConfirmedMaxValue.present
        ? draftConfirmedMaxValue.value
        : this.draftConfirmedMaxValue,
    draftConfirmedAt: draftConfirmedAt.present
        ? draftConfirmedAt.value
        : this.draftConfirmedAt,
    draftNotes: draftNotes.present ? draftNotes.value : this.draftNotes,
    stage: stage ?? this.stage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ActiveTestSession copyWithCompanion(ActiveTestSessionsCompanion data) {
    return ActiveTestSession(
      id: data.id.present ? data.id.value : this.id,
      tankId: data.tankId.present ? data.tankId.value : this.tankId,
      parameterId: data.parameterId.present
          ? data.parameterId.value
          : this.parameterId,
      reagentProfileId: data.reagentProfileId.present
          ? data.reagentProfileId.value
          : this.reagentProfileId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      timerDurationSeconds: data.timerDurationSeconds.present
          ? data.timerDurationSeconds.value
          : this.timerDurationSeconds,
      timerEndsAt: data.timerEndsAt.present
          ? data.timerEndsAt.value
          : this.timerEndsAt,
      pausedRemainingSeconds: data.pausedRemainingSeconds.present
          ? data.pausedRemainingSeconds.value
          : this.pausedRemainingSeconds,
      draftPhotoPath: data.draftPhotoPath.present
          ? data.draftPhotoPath.value
          : this.draftPhotoPath,
      draftCapturedAt: data.draftCapturedAt.present
          ? data.draftCapturedAt.value
          : this.draftCapturedAt,
      draftEstimatedMinValue: data.draftEstimatedMinValue.present
          ? data.draftEstimatedMinValue.value
          : this.draftEstimatedMinValue,
      draftEstimatedMaxValue: data.draftEstimatedMaxValue.present
          ? data.draftEstimatedMaxValue.value
          : this.draftEstimatedMaxValue,
      draftEstimationMethod: data.draftEstimationMethod.present
          ? data.draftEstimationMethod.value
          : this.draftEstimationMethod,
      draftEstimationVersion: data.draftEstimationVersion.present
          ? data.draftEstimationVersion.value
          : this.draftEstimationVersion,
      draftQualityScore: data.draftQualityScore.present
          ? data.draftQualityScore.value
          : this.draftQualityScore,
      draftConfidence: data.draftConfidence.present
          ? data.draftConfidence.value
          : this.draftConfidence,
      draftFailureReason: data.draftFailureReason.present
          ? data.draftFailureReason.value
          : this.draftFailureReason,
      draftConfirmedMinValue: data.draftConfirmedMinValue.present
          ? data.draftConfirmedMinValue.value
          : this.draftConfirmedMinValue,
      draftConfirmedInterpolation: data.draftConfirmedInterpolation.present
          ? data.draftConfirmedInterpolation.value
          : this.draftConfirmedInterpolation,
      draftEstimatedInterpolation: data.draftEstimatedInterpolation.present
          ? data.draftEstimatedInterpolation.value
          : this.draftEstimatedInterpolation,
      draftConfirmedMaxValue: data.draftConfirmedMaxValue.present
          ? data.draftConfirmedMaxValue.value
          : this.draftConfirmedMaxValue,
      draftConfirmedAt: data.draftConfirmedAt.present
          ? data.draftConfirmedAt.value
          : this.draftConfirmedAt,
      draftNotes: data.draftNotes.present
          ? data.draftNotes.value
          : this.draftNotes,
      stage: data.stage.present ? data.stage.value : this.stage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveTestSession(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('reagentProfileId: $reagentProfileId, ')
          ..write('startedAt: $startedAt, ')
          ..write('timerDurationSeconds: $timerDurationSeconds, ')
          ..write('timerEndsAt: $timerEndsAt, ')
          ..write('pausedRemainingSeconds: $pausedRemainingSeconds, ')
          ..write('draftPhotoPath: $draftPhotoPath, ')
          ..write('draftCapturedAt: $draftCapturedAt, ')
          ..write('draftEstimatedMinValue: $draftEstimatedMinValue, ')
          ..write('draftEstimatedMaxValue: $draftEstimatedMaxValue, ')
          ..write('draftEstimationMethod: $draftEstimationMethod, ')
          ..write('draftEstimationVersion: $draftEstimationVersion, ')
          ..write('draftQualityScore: $draftQualityScore, ')
          ..write('draftConfidence: $draftConfidence, ')
          ..write('draftFailureReason: $draftFailureReason, ')
          ..write('draftConfirmedMinValue: $draftConfirmedMinValue, ')
          ..write('draftConfirmedInterpolation: $draftConfirmedInterpolation, ')
          ..write('draftEstimatedInterpolation: $draftEstimatedInterpolation, ')
          ..write('draftConfirmedMaxValue: $draftConfirmedMaxValue, ')
          ..write('draftConfirmedAt: $draftConfirmedAt, ')
          ..write('draftNotes: $draftNotes, ')
          ..write('stage: $stage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tankId,
    parameterId,
    reagentProfileId,
    startedAt,
    timerDurationSeconds,
    timerEndsAt,
    pausedRemainingSeconds,
    draftPhotoPath,
    draftCapturedAt,
    draftEstimatedMinValue,
    draftEstimatedMaxValue,
    draftEstimationMethod,
    draftEstimationVersion,
    draftQualityScore,
    draftConfidence,
    draftFailureReason,
    draftConfirmedMinValue,
    draftConfirmedInterpolation,
    draftEstimatedInterpolation,
    draftConfirmedMaxValue,
    draftConfirmedAt,
    draftNotes,
    stage,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveTestSession &&
          other.id == this.id &&
          other.tankId == this.tankId &&
          other.parameterId == this.parameterId &&
          other.reagentProfileId == this.reagentProfileId &&
          other.startedAt == this.startedAt &&
          other.timerDurationSeconds == this.timerDurationSeconds &&
          other.timerEndsAt == this.timerEndsAt &&
          other.pausedRemainingSeconds == this.pausedRemainingSeconds &&
          other.draftPhotoPath == this.draftPhotoPath &&
          other.draftCapturedAt == this.draftCapturedAt &&
          other.draftEstimatedMinValue == this.draftEstimatedMinValue &&
          other.draftEstimatedMaxValue == this.draftEstimatedMaxValue &&
          other.draftEstimationMethod == this.draftEstimationMethod &&
          other.draftEstimationVersion == this.draftEstimationVersion &&
          other.draftQualityScore == this.draftQualityScore &&
          other.draftConfidence == this.draftConfidence &&
          other.draftFailureReason == this.draftFailureReason &&
          other.draftConfirmedMinValue == this.draftConfirmedMinValue &&
          other.draftConfirmedInterpolation ==
              this.draftConfirmedInterpolation &&
          other.draftEstimatedInterpolation ==
              this.draftEstimatedInterpolation &&
          other.draftConfirmedMaxValue == this.draftConfirmedMaxValue &&
          other.draftConfirmedAt == this.draftConfirmedAt &&
          other.draftNotes == this.draftNotes &&
          other.stage == this.stage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ActiveTestSessionsCompanion extends UpdateCompanion<ActiveTestSession> {
  final Value<String> id;
  final Value<String> tankId;
  final Value<String> parameterId;
  final Value<String?> reagentProfileId;
  final Value<DateTime> startedAt;
  final Value<int> timerDurationSeconds;
  final Value<DateTime?> timerEndsAt;
  final Value<int?> pausedRemainingSeconds;
  final Value<String?> draftPhotoPath;
  final Value<DateTime?> draftCapturedAt;
  final Value<double?> draftEstimatedMinValue;
  final Value<double?> draftEstimatedMaxValue;
  final Value<String?> draftEstimationMethod;
  final Value<String?> draftEstimationVersion;
  final Value<double?> draftQualityScore;
  final Value<String?> draftConfidence;
  final Value<String?> draftFailureReason;
  final Value<double?> draftConfirmedMinValue;
  final Value<double?> draftConfirmedInterpolation;
  final Value<double?> draftEstimatedInterpolation;
  final Value<double?> draftConfirmedMaxValue;
  final Value<DateTime?> draftConfirmedAt;
  final Value<String?> draftNotes;
  final Value<String> stage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ActiveTestSessionsCompanion({
    this.id = const Value.absent(),
    this.tankId = const Value.absent(),
    this.parameterId = const Value.absent(),
    this.reagentProfileId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.timerDurationSeconds = const Value.absent(),
    this.timerEndsAt = const Value.absent(),
    this.pausedRemainingSeconds = const Value.absent(),
    this.draftPhotoPath = const Value.absent(),
    this.draftCapturedAt = const Value.absent(),
    this.draftEstimatedMinValue = const Value.absent(),
    this.draftEstimatedMaxValue = const Value.absent(),
    this.draftEstimationMethod = const Value.absent(),
    this.draftEstimationVersion = const Value.absent(),
    this.draftQualityScore = const Value.absent(),
    this.draftConfidence = const Value.absent(),
    this.draftFailureReason = const Value.absent(),
    this.draftConfirmedMinValue = const Value.absent(),
    this.draftConfirmedInterpolation = const Value.absent(),
    this.draftEstimatedInterpolation = const Value.absent(),
    this.draftConfirmedMaxValue = const Value.absent(),
    this.draftConfirmedAt = const Value.absent(),
    this.draftNotes = const Value.absent(),
    this.stage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveTestSessionsCompanion.insert({
    required String id,
    required String tankId,
    required String parameterId,
    this.reagentProfileId = const Value.absent(),
    required DateTime startedAt,
    required int timerDurationSeconds,
    this.timerEndsAt = const Value.absent(),
    this.pausedRemainingSeconds = const Value.absent(),
    this.draftPhotoPath = const Value.absent(),
    this.draftCapturedAt = const Value.absent(),
    this.draftEstimatedMinValue = const Value.absent(),
    this.draftEstimatedMaxValue = const Value.absent(),
    this.draftEstimationMethod = const Value.absent(),
    this.draftEstimationVersion = const Value.absent(),
    this.draftQualityScore = const Value.absent(),
    this.draftConfidence = const Value.absent(),
    this.draftFailureReason = const Value.absent(),
    this.draftConfirmedMinValue = const Value.absent(),
    this.draftConfirmedInterpolation = const Value.absent(),
    this.draftEstimatedInterpolation = const Value.absent(),
    this.draftConfirmedMaxValue = const Value.absent(),
    this.draftConfirmedAt = const Value.absent(),
    this.draftNotes = const Value.absent(),
    required String stage,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tankId = Value(tankId),
       parameterId = Value(parameterId),
       startedAt = Value(startedAt),
       timerDurationSeconds = Value(timerDurationSeconds),
       stage = Value(stage),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ActiveTestSession> custom({
    Expression<String>? id,
    Expression<String>? tankId,
    Expression<String>? parameterId,
    Expression<String>? reagentProfileId,
    Expression<DateTime>? startedAt,
    Expression<int>? timerDurationSeconds,
    Expression<DateTime>? timerEndsAt,
    Expression<int>? pausedRemainingSeconds,
    Expression<String>? draftPhotoPath,
    Expression<DateTime>? draftCapturedAt,
    Expression<double>? draftEstimatedMinValue,
    Expression<double>? draftEstimatedMaxValue,
    Expression<String>? draftEstimationMethod,
    Expression<String>? draftEstimationVersion,
    Expression<double>? draftQualityScore,
    Expression<String>? draftConfidence,
    Expression<String>? draftFailureReason,
    Expression<double>? draftConfirmedMinValue,
    Expression<double>? draftConfirmedInterpolation,
    Expression<double>? draftEstimatedInterpolation,
    Expression<double>? draftConfirmedMaxValue,
    Expression<DateTime>? draftConfirmedAt,
    Expression<String>? draftNotes,
    Expression<String>? stage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tankId != null) 'tank_id': tankId,
      if (parameterId != null) 'parameter_id': parameterId,
      if (reagentProfileId != null) 'reagent_profile_id': reagentProfileId,
      if (startedAt != null) 'started_at': startedAt,
      if (timerDurationSeconds != null)
        'timer_duration_seconds': timerDurationSeconds,
      if (timerEndsAt != null) 'timer_ends_at': timerEndsAt,
      if (pausedRemainingSeconds != null)
        'paused_remaining_seconds': pausedRemainingSeconds,
      if (draftPhotoPath != null) 'draft_photo_path': draftPhotoPath,
      if (draftCapturedAt != null) 'draft_captured_at': draftCapturedAt,
      if (draftEstimatedMinValue != null)
        'draft_estimated_min_value': draftEstimatedMinValue,
      if (draftEstimatedMaxValue != null)
        'draft_estimated_max_value': draftEstimatedMaxValue,
      if (draftEstimationMethod != null)
        'draft_estimation_method': draftEstimationMethod,
      if (draftEstimationVersion != null)
        'draft_estimation_version': draftEstimationVersion,
      if (draftQualityScore != null) 'draft_quality_score': draftQualityScore,
      if (draftConfidence != null) 'draft_confidence': draftConfidence,
      if (draftFailureReason != null)
        'draft_failure_reason': draftFailureReason,
      if (draftConfirmedMinValue != null)
        'draft_confirmed_min_value': draftConfirmedMinValue,
      if (draftConfirmedInterpolation != null)
        'draft_confirmed_interpolation': draftConfirmedInterpolation,
      if (draftEstimatedInterpolation != null)
        'draft_estimated_interpolation': draftEstimatedInterpolation,
      if (draftConfirmedMaxValue != null)
        'draft_confirmed_max_value': draftConfirmedMaxValue,
      if (draftConfirmedAt != null) 'draft_confirmed_at': draftConfirmedAt,
      if (draftNotes != null) 'draft_notes': draftNotes,
      if (stage != null) 'stage': stage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveTestSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? tankId,
    Value<String>? parameterId,
    Value<String?>? reagentProfileId,
    Value<DateTime>? startedAt,
    Value<int>? timerDurationSeconds,
    Value<DateTime?>? timerEndsAt,
    Value<int?>? pausedRemainingSeconds,
    Value<String?>? draftPhotoPath,
    Value<DateTime?>? draftCapturedAt,
    Value<double?>? draftEstimatedMinValue,
    Value<double?>? draftEstimatedMaxValue,
    Value<String?>? draftEstimationMethod,
    Value<String?>? draftEstimationVersion,
    Value<double?>? draftQualityScore,
    Value<String?>? draftConfidence,
    Value<String?>? draftFailureReason,
    Value<double?>? draftConfirmedMinValue,
    Value<double?>? draftConfirmedInterpolation,
    Value<double?>? draftEstimatedInterpolation,
    Value<double?>? draftConfirmedMaxValue,
    Value<DateTime?>? draftConfirmedAt,
    Value<String?>? draftNotes,
    Value<String>? stage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ActiveTestSessionsCompanion(
      id: id ?? this.id,
      tankId: tankId ?? this.tankId,
      parameterId: parameterId ?? this.parameterId,
      reagentProfileId: reagentProfileId ?? this.reagentProfileId,
      startedAt: startedAt ?? this.startedAt,
      timerDurationSeconds: timerDurationSeconds ?? this.timerDurationSeconds,
      timerEndsAt: timerEndsAt ?? this.timerEndsAt,
      pausedRemainingSeconds:
          pausedRemainingSeconds ?? this.pausedRemainingSeconds,
      draftPhotoPath: draftPhotoPath ?? this.draftPhotoPath,
      draftCapturedAt: draftCapturedAt ?? this.draftCapturedAt,
      draftEstimatedMinValue:
          draftEstimatedMinValue ?? this.draftEstimatedMinValue,
      draftEstimatedMaxValue:
          draftEstimatedMaxValue ?? this.draftEstimatedMaxValue,
      draftEstimationMethod:
          draftEstimationMethod ?? this.draftEstimationMethod,
      draftEstimationVersion:
          draftEstimationVersion ?? this.draftEstimationVersion,
      draftQualityScore: draftQualityScore ?? this.draftQualityScore,
      draftConfidence: draftConfidence ?? this.draftConfidence,
      draftFailureReason: draftFailureReason ?? this.draftFailureReason,
      draftConfirmedMinValue:
          draftConfirmedMinValue ?? this.draftConfirmedMinValue,
      draftConfirmedInterpolation:
          draftConfirmedInterpolation ?? this.draftConfirmedInterpolation,
      draftEstimatedInterpolation:
          draftEstimatedInterpolation ?? this.draftEstimatedInterpolation,
      draftConfirmedMaxValue:
          draftConfirmedMaxValue ?? this.draftConfirmedMaxValue,
      draftConfirmedAt: draftConfirmedAt ?? this.draftConfirmedAt,
      draftNotes: draftNotes ?? this.draftNotes,
      stage: stage ?? this.stage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tankId.present) {
      map['tank_id'] = Variable<String>(tankId.value);
    }
    if (parameterId.present) {
      map['parameter_id'] = Variable<String>(parameterId.value);
    }
    if (reagentProfileId.present) {
      map['reagent_profile_id'] = Variable<String>(reagentProfileId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (timerDurationSeconds.present) {
      map['timer_duration_seconds'] = Variable<int>(timerDurationSeconds.value);
    }
    if (timerEndsAt.present) {
      map['timer_ends_at'] = Variable<DateTime>(timerEndsAt.value);
    }
    if (pausedRemainingSeconds.present) {
      map['paused_remaining_seconds'] = Variable<int>(
        pausedRemainingSeconds.value,
      );
    }
    if (draftPhotoPath.present) {
      map['draft_photo_path'] = Variable<String>(draftPhotoPath.value);
    }
    if (draftCapturedAt.present) {
      map['draft_captured_at'] = Variable<DateTime>(draftCapturedAt.value);
    }
    if (draftEstimatedMinValue.present) {
      map['draft_estimated_min_value'] = Variable<double>(
        draftEstimatedMinValue.value,
      );
    }
    if (draftEstimatedMaxValue.present) {
      map['draft_estimated_max_value'] = Variable<double>(
        draftEstimatedMaxValue.value,
      );
    }
    if (draftEstimationMethod.present) {
      map['draft_estimation_method'] = Variable<String>(
        draftEstimationMethod.value,
      );
    }
    if (draftEstimationVersion.present) {
      map['draft_estimation_version'] = Variable<String>(
        draftEstimationVersion.value,
      );
    }
    if (draftQualityScore.present) {
      map['draft_quality_score'] = Variable<double>(draftQualityScore.value);
    }
    if (draftConfidence.present) {
      map['draft_confidence'] = Variable<String>(draftConfidence.value);
    }
    if (draftFailureReason.present) {
      map['draft_failure_reason'] = Variable<String>(draftFailureReason.value);
    }
    if (draftConfirmedMinValue.present) {
      map['draft_confirmed_min_value'] = Variable<double>(
        draftConfirmedMinValue.value,
      );
    }
    if (draftConfirmedInterpolation.present) {
      map['draft_confirmed_interpolation'] = Variable<double>(
        draftConfirmedInterpolation.value,
      );
    }
    if (draftEstimatedInterpolation.present) {
      map['draft_estimated_interpolation'] = Variable<double>(
        draftEstimatedInterpolation.value,
      );
    }
    if (draftConfirmedMaxValue.present) {
      map['draft_confirmed_max_value'] = Variable<double>(
        draftConfirmedMaxValue.value,
      );
    }
    if (draftConfirmedAt.present) {
      map['draft_confirmed_at'] = Variable<DateTime>(draftConfirmedAt.value);
    }
    if (draftNotes.present) {
      map['draft_notes'] = Variable<String>(draftNotes.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveTestSessionsCompanion(')
          ..write('id: $id, ')
          ..write('tankId: $tankId, ')
          ..write('parameterId: $parameterId, ')
          ..write('reagentProfileId: $reagentProfileId, ')
          ..write('startedAt: $startedAt, ')
          ..write('timerDurationSeconds: $timerDurationSeconds, ')
          ..write('timerEndsAt: $timerEndsAt, ')
          ..write('pausedRemainingSeconds: $pausedRemainingSeconds, ')
          ..write('draftPhotoPath: $draftPhotoPath, ')
          ..write('draftCapturedAt: $draftCapturedAt, ')
          ..write('draftEstimatedMinValue: $draftEstimatedMinValue, ')
          ..write('draftEstimatedMaxValue: $draftEstimatedMaxValue, ')
          ..write('draftEstimationMethod: $draftEstimationMethod, ')
          ..write('draftEstimationVersion: $draftEstimationVersion, ')
          ..write('draftQualityScore: $draftQualityScore, ')
          ..write('draftConfidence: $draftConfidence, ')
          ..write('draftFailureReason: $draftFailureReason, ')
          ..write('draftConfirmedMinValue: $draftConfirmedMinValue, ')
          ..write('draftConfirmedInterpolation: $draftConfirmedInterpolation, ')
          ..write('draftEstimatedInterpolation: $draftEstimatedInterpolation, ')
          ..write('draftConfirmedMaxValue: $draftConfirmedMaxValue, ')
          ..write('draftConfirmedAt: $draftConfirmedAt, ')
          ..write('draftNotes: $draftNotes, ')
          ..write('stage: $stage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TanksTable tanks = $TanksTable(this);
  late final $WaterParametersTable waterParameters = $WaterParametersTable(
    this,
  );
  late final $TankParametersTable tankParameters = $TankParametersTable(this);
  late final $WaterQualityTargetsTable waterQualityTargets =
      $WaterQualityTargetsTable(this);
  late final $ReagentProfilesTable reagentProfiles = $ReagentProfilesTable(
    this,
  );
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $TestRecordsTable testRecords = $TestRecordsTable(this);
  late final $MaintenanceTasksTable maintenanceTasks = $MaintenanceTasksTable(
    this,
  );
  late final $MaintenanceCyclesTable maintenanceCycles =
      $MaintenanceCyclesTable(this);
  late final $TaskEventsTable taskEvents = $TaskEventsTable(this);
  late final $TestTimerDefaultsTable testTimerDefaults =
      $TestTimerDefaultsTable(this);
  late final $ActiveTestSessionsTable activeTestSessions =
      $ActiveTestSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tanks,
    waterParameters,
    tankParameters,
    waterQualityTargets,
    reagentProfiles,
    appPreferences,
    testRecords,
    maintenanceTasks,
    maintenanceCycles,
    taskEvents,
    testTimerDefaults,
    activeTestSessions,
  ];
}

typedef $$TanksTableCreateCompanionBuilder =
    TanksCompanion Function({
      required String id,
      required String name,
      Value<String?> notes,
      Value<String?> startedOn,
      Value<double?> volumeLiters,
      Value<bool> isArchived,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TanksTableUpdateCompanionBuilder =
    TanksCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> notes,
      Value<String?> startedOn,
      Value<double?> volumeLiters,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TanksTableReferences
    extends BaseReferences<_$AppDatabase, $TanksTable, Tank> {
  $$TanksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TankParametersTable, List<TankParameter>>
  _tankParametersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tankParameters,
    aliasName: 'tanks__id__tank_parameters__tank_id',
  );

  $$TankParametersTableProcessedTableManager get tankParametersRefs {
    final manager = $$TankParametersTableTableManager(
      $_db,
      $_db.tankParameters,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tankParametersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WaterQualityTargetsTable,
    List<WaterQualityTarget>
  >
  _waterQualityTargetsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.waterQualityTargets,
        aliasName: 'tanks__id__water_quality_targets__tank_id',
      );

  $$WaterQualityTargetsTableProcessedTableManager get waterQualityTargetsRefs {
    final manager = $$WaterQualityTargetsTableTableManager(
      $_db,
      $_db.waterQualityTargets,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _waterQualityTargetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AppPreferencesTable, List<AppPreference>>
  _appPreferencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.appPreferences,
    aliasName: 'tanks__id__app_preferences__current_tank_id',
  );

  $$AppPreferencesTableProcessedTableManager get appPreferencesRefs {
    final manager = $$AppPreferencesTableTableManager(
      $_db,
      $_db.appPreferences,
    ).filter((f) => f.currentTankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_appPreferencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TestRecordsTable, List<TestRecord>>
  _testRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.testRecords,
    aliasName: 'tanks__id__test_records__tank_id',
  );

  $$TestRecordsTableProcessedTableManager get testRecordsRefs {
    final manager = $$TestRecordsTableTableManager(
      $_db,
      $_db.testRecords,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_testRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaintenanceTasksTable, List<MaintenanceTask>>
  _maintenanceTasksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.maintenanceTasks,
    aliasName: 'tanks__id__maintenance_tasks__tank_id',
  );

  $$MaintenanceTasksTableProcessedTableManager get maintenanceTasksRefs {
    final manager = $$MaintenanceTasksTableTableManager(
      $_db,
      $_db.maintenanceTasks,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceTasksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MaintenanceCyclesTable, List<MaintenanceCycleRow>>
  _maintenanceCyclesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.maintenanceCycles,
        aliasName: 'tanks__id__maintenance_cycles__tank_id',
      );

  $$MaintenanceCyclesTableProcessedTableManager get maintenanceCyclesRefs {
    final manager = $$MaintenanceCyclesTableTableManager(
      $_db,
      $_db.maintenanceCycles,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _maintenanceCyclesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TestTimerDefaultsTable, List<TestTimerDefault>>
  _testTimerDefaultsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.testTimerDefaults,
        aliasName: 'tanks__id__test_timer_defaults__tank_id',
      );

  $$TestTimerDefaultsTableProcessedTableManager get testTimerDefaultsRefs {
    final manager = $$TestTimerDefaultsTableTableManager(
      $_db,
      $_db.testTimerDefaults,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _testTimerDefaultsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActiveTestSessionsTable, List<ActiveTestSession>>
  _activeTestSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.activeTestSessions,
        aliasName: 'tanks__id__active_test_sessions__tank_id',
      );

  $$ActiveTestSessionsTableProcessedTableManager get activeTestSessionsRefs {
    final manager = $$ActiveTestSessionsTableTableManager(
      $_db,
      $_db.activeTestSessions,
    ).filter((f) => f.tankId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _activeTestSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TanksTableFilterComposer extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tankParametersRefs(
    Expression<bool> Function($$TankParametersTableFilterComposer f) f,
  ) {
    final $$TankParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tankParameters,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TankParametersTableFilterComposer(
            $db: $db,
            $table: $db.tankParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> waterQualityTargetsRefs(
    Expression<bool> Function($$WaterQualityTargetsTableFilterComposer f) f,
  ) {
    final $$WaterQualityTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.waterQualityTargets,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterQualityTargetsTableFilterComposer(
            $db: $db,
            $table: $db.waterQualityTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> appPreferencesRefs(
    Expression<bool> Function($$AppPreferencesTableFilterComposer f) f,
  ) {
    final $$AppPreferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appPreferences,
      getReferencedColumn: (t) => t.currentTankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppPreferencesTableFilterComposer(
            $db: $db,
            $table: $db.appPreferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> testRecordsRefs(
    Expression<bool> Function($$TestRecordsTableFilterComposer f) f,
  ) {
    final $$TestRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableFilterComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceTasksRefs(
    Expression<bool> Function($$MaintenanceTasksTableFilterComposer f) f,
  ) {
    final $$MaintenanceTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceTasks,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceTasksTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> maintenanceCyclesRefs(
    Expression<bool> Function($$MaintenanceCyclesTableFilterComposer f) f,
  ) {
    final $$MaintenanceCyclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceCycles,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceCyclesTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceCycles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> testTimerDefaultsRefs(
    Expression<bool> Function($$TestTimerDefaultsTableFilterComposer f) f,
  ) {
    final $$TestTimerDefaultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testTimerDefaults,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestTimerDefaultsTableFilterComposer(
            $db: $db,
            $table: $db.testTimerDefaults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activeTestSessionsRefs(
    Expression<bool> Function($$ActiveTestSessionsTableFilterComposer f) f,
  ) {
    final $$ActiveTestSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activeTestSessions,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActiveTestSessionsTableFilterComposer(
            $db: $db,
            $table: $db.activeTestSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TanksTableOrderingComposer
    extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TanksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TanksTable> {
  $$TanksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumn<double> get volumeLiters => $composableBuilder(
    column: $table.volumeLiters,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tankParametersRefs<T extends Object>(
    Expression<T> Function($$TankParametersTableAnnotationComposer a) f,
  ) {
    final $$TankParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tankParameters,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TankParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.tankParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> waterQualityTargetsRefs<T extends Object>(
    Expression<T> Function($$WaterQualityTargetsTableAnnotationComposer a) f,
  ) {
    final $$WaterQualityTargetsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.waterQualityTargets,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WaterQualityTargetsTableAnnotationComposer(
                $db: $db,
                $table: $db.waterQualityTargets,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> appPreferencesRefs<T extends Object>(
    Expression<T> Function($$AppPreferencesTableAnnotationComposer a) f,
  ) {
    final $$AppPreferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.appPreferences,
      getReferencedColumn: (t) => t.currentTankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AppPreferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.appPreferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> testRecordsRefs<T extends Object>(
    Expression<T> Function($$TestRecordsTableAnnotationComposer a) f,
  ) {
    final $$TestRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> maintenanceTasksRefs<T extends Object>(
    Expression<T> Function($$MaintenanceTasksTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.maintenanceTasks,
      getReferencedColumn: (t) => t.tankId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.maintenanceTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> maintenanceCyclesRefs<T extends Object>(
    Expression<T> Function($$MaintenanceCyclesTableAnnotationComposer a) f,
  ) {
    final $$MaintenanceCyclesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.maintenanceCycles,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MaintenanceCyclesTableAnnotationComposer(
                $db: $db,
                $table: $db.maintenanceCycles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> testTimerDefaultsRefs<T extends Object>(
    Expression<T> Function($$TestTimerDefaultsTableAnnotationComposer a) f,
  ) {
    final $$TestTimerDefaultsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.testTimerDefaults,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TestTimerDefaultsTableAnnotationComposer(
                $db: $db,
                $table: $db.testTimerDefaults,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> activeTestSessionsRefs<T extends Object>(
    Expression<T> Function($$ActiveTestSessionsTableAnnotationComposer a) f,
  ) {
    final $$ActiveTestSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.activeTestSessions,
          getReferencedColumn: (t) => t.tankId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ActiveTestSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.activeTestSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TanksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TanksTable,
          Tank,
          $$TanksTableFilterComposer,
          $$TanksTableOrderingComposer,
          $$TanksTableAnnotationComposer,
          $$TanksTableCreateCompanionBuilder,
          $$TanksTableUpdateCompanionBuilder,
          (Tank, $$TanksTableReferences),
          Tank,
          PrefetchHooks Function({
            bool tankParametersRefs,
            bool waterQualityTargetsRefs,
            bool appPreferencesRefs,
            bool testRecordsRefs,
            bool maintenanceTasksRefs,
            bool maintenanceCyclesRefs,
            bool testTimerDefaultsRefs,
            bool activeTestSessionsRefs,
          })
        > {
  $$TanksTableTableManager(_$AppDatabase db, $TanksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TanksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TanksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TanksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> startedOn = const Value.absent(),
                Value<double?> volumeLiters = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TanksCompanion(
                id: id,
                name: name,
                notes: notes,
                startedOn: startedOn,
                volumeLiters: volumeLiters,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<String?> startedOn = const Value.absent(),
                Value<double?> volumeLiters = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TanksCompanion.insert(
                id: id,
                name: name,
                notes: notes,
                startedOn: startedOn,
                volumeLiters: volumeLiters,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TanksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tankParametersRefs = false,
                waterQualityTargetsRefs = false,
                appPreferencesRefs = false,
                testRecordsRefs = false,
                maintenanceTasksRefs = false,
                maintenanceCyclesRefs = false,
                testTimerDefaultsRefs = false,
                activeTestSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tankParametersRefs) db.tankParameters,
                    if (waterQualityTargetsRefs) db.waterQualityTargets,
                    if (appPreferencesRefs) db.appPreferences,
                    if (testRecordsRefs) db.testRecords,
                    if (maintenanceTasksRefs) db.maintenanceTasks,
                    if (maintenanceCyclesRefs) db.maintenanceCycles,
                    if (testTimerDefaultsRefs) db.testTimerDefaults,
                    if (activeTestSessionsRefs) db.activeTestSessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tankParametersRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          TankParameter
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._tankParametersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).tankParametersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (waterQualityTargetsRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          WaterQualityTarget
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._waterQualityTargetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).waterQualityTargetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (appPreferencesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          AppPreference
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._appPreferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).appPreferencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.currentTankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (testRecordsRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          TestRecord
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._testRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).testRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceTasksRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          MaintenanceTask
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._maintenanceTasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceTasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (maintenanceCyclesRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          MaintenanceCycleRow
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._maintenanceCyclesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).maintenanceCyclesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (testTimerDefaultsRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          TestTimerDefault
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._testTimerDefaultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).testTimerDefaultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activeTestSessionsRefs)
                        await $_getPrefetchedData<
                          Tank,
                          $TanksTable,
                          ActiveTestSession
                        >(
                          currentTable: table,
                          referencedTable: $$TanksTableReferences
                              ._activeTestSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TanksTableReferences(
                                db,
                                table,
                                p0,
                              ).activeTestSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.tankId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TanksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TanksTable,
      Tank,
      $$TanksTableFilterComposer,
      $$TanksTableOrderingComposer,
      $$TanksTableAnnotationComposer,
      $$TanksTableCreateCompanionBuilder,
      $$TanksTableUpdateCompanionBuilder,
      (Tank, $$TanksTableReferences),
      Tank,
      PrefetchHooks Function({
        bool tankParametersRefs,
        bool waterQualityTargetsRefs,
        bool appPreferencesRefs,
        bool testRecordsRefs,
        bool maintenanceTasksRefs,
        bool maintenanceCyclesRefs,
        bool testTimerDefaultsRefs,
        bool activeTestSessionsRefs,
      })
    >;
typedef $$WaterParametersTableCreateCompanionBuilder =
    WaterParametersCompanion Function({
      required String id,
      required String code,
      required String displayName,
      required String unit,
      required bool isBuiltIn,
      Value<bool> photoSupported,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WaterParametersTableUpdateCompanionBuilder =
    WaterParametersCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> displayName,
      Value<String> unit,
      Value<bool> isBuiltIn,
      Value<bool> photoSupported,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$WaterParametersTableReferences
    extends
        BaseReferences<_$AppDatabase, $WaterParametersTable, WaterParameter> {
  $$WaterParametersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TankParametersTable, List<TankParameter>>
  _tankParametersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tankParameters,
    aliasName: 'water_parameters__id__tank_parameters__parameter_id',
  );

  $$TankParametersTableProcessedTableManager get tankParametersRefs {
    final manager = $$TankParametersTableTableManager(
      $_db,
      $_db.tankParameters,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tankParametersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WaterQualityTargetsTable,
    List<WaterQualityTarget>
  >
  _waterQualityTargetsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.waterQualityTargets,
        aliasName: 'water_parameters__id__water_quality_targets__parameter_id',
      );

  $$WaterQualityTargetsTableProcessedTableManager get waterQualityTargetsRefs {
    final manager = $$WaterQualityTargetsTableTableManager(
      $_db,
      $_db.waterQualityTargets,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _waterQualityTargetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReagentProfilesTable, List<ReagentProfile>>
  _reagentProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reagentProfiles,
    aliasName: 'water_parameters__id__reagent_profiles__parameter_id',
  );

  $$ReagentProfilesTableProcessedTableManager get reagentProfilesRefs {
    final manager = $$ReagentProfilesTableTableManager(
      $_db,
      $_db.reagentProfiles,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _reagentProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TestRecordsTable, List<TestRecord>>
  _testRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.testRecords,
    aliasName: 'water_parameters__id__test_records__parameter_id',
  );

  $$TestRecordsTableProcessedTableManager get testRecordsRefs {
    final manager = $$TestRecordsTableTableManager(
      $_db,
      $_db.testRecords,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_testRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TestTimerDefaultsTable, List<TestTimerDefault>>
  _testTimerDefaultsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.testTimerDefaults,
        aliasName: 'water_parameters__id__test_timer_defaults__parameter_id',
      );

  $$TestTimerDefaultsTableProcessedTableManager get testTimerDefaultsRefs {
    final manager = $$TestTimerDefaultsTableTableManager(
      $_db,
      $_db.testTimerDefaults,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _testTimerDefaultsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActiveTestSessionsTable, List<ActiveTestSession>>
  _activeTestSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.activeTestSessions,
        aliasName: 'water_parameters__id__active_test_sessions__parameter_id',
      );

  $$ActiveTestSessionsTableProcessedTableManager get activeTestSessionsRefs {
    final manager = $$ActiveTestSessionsTableTableManager(
      $_db,
      $_db.activeTestSessions,
    ).filter((f) => f.parameterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _activeTestSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WaterParametersTableFilterComposer
    extends Composer<_$AppDatabase, $WaterParametersTable> {
  $$WaterParametersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get photoSupported => $composableBuilder(
    column: $table.photoSupported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tankParametersRefs(
    Expression<bool> Function($$TankParametersTableFilterComposer f) f,
  ) {
    final $$TankParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tankParameters,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TankParametersTableFilterComposer(
            $db: $db,
            $table: $db.tankParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> waterQualityTargetsRefs(
    Expression<bool> Function($$WaterQualityTargetsTableFilterComposer f) f,
  ) {
    final $$WaterQualityTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.waterQualityTargets,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterQualityTargetsTableFilterComposer(
            $db: $db,
            $table: $db.waterQualityTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> reagentProfilesRefs(
    Expression<bool> Function($$ReagentProfilesTableFilterComposer f) f,
  ) {
    final $$ReagentProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableFilterComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> testRecordsRefs(
    Expression<bool> Function($$TestRecordsTableFilterComposer f) f,
  ) {
    final $$TestRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableFilterComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> testTimerDefaultsRefs(
    Expression<bool> Function($$TestTimerDefaultsTableFilterComposer f) f,
  ) {
    final $$TestTimerDefaultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testTimerDefaults,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestTimerDefaultsTableFilterComposer(
            $db: $db,
            $table: $db.testTimerDefaults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activeTestSessionsRefs(
    Expression<bool> Function($$ActiveTestSessionsTableFilterComposer f) f,
  ) {
    final $$ActiveTestSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activeTestSessions,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActiveTestSessionsTableFilterComposer(
            $db: $db,
            $table: $db.activeTestSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WaterParametersTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterParametersTable> {
  $$WaterParametersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get photoSupported => $composableBuilder(
    column: $table.photoSupported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaterParametersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterParametersTable> {
  $$WaterParametersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<bool> get photoSupported => $composableBuilder(
    column: $table.photoSupported,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> tankParametersRefs<T extends Object>(
    Expression<T> Function($$TankParametersTableAnnotationComposer a) f,
  ) {
    final $$TankParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tankParameters,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TankParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.tankParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> waterQualityTargetsRefs<T extends Object>(
    Expression<T> Function($$WaterQualityTargetsTableAnnotationComposer a) f,
  ) {
    final $$WaterQualityTargetsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.waterQualityTargets,
          getReferencedColumn: (t) => t.parameterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WaterQualityTargetsTableAnnotationComposer(
                $db: $db,
                $table: $db.waterQualityTargets,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> reagentProfilesRefs<T extends Object>(
    Expression<T> Function($$ReagentProfilesTableAnnotationComposer a) f,
  ) {
    final $$ReagentProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> testRecordsRefs<T extends Object>(
    Expression<T> Function($$TestRecordsTableAnnotationComposer a) f,
  ) {
    final $$TestRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.parameterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> testTimerDefaultsRefs<T extends Object>(
    Expression<T> Function($$TestTimerDefaultsTableAnnotationComposer a) f,
  ) {
    final $$TestTimerDefaultsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.testTimerDefaults,
          getReferencedColumn: (t) => t.parameterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TestTimerDefaultsTableAnnotationComposer(
                $db: $db,
                $table: $db.testTimerDefaults,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> activeTestSessionsRefs<T extends Object>(
    Expression<T> Function($$ActiveTestSessionsTableAnnotationComposer a) f,
  ) {
    final $$ActiveTestSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.activeTestSessions,
          getReferencedColumn: (t) => t.parameterId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ActiveTestSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.activeTestSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WaterParametersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterParametersTable,
          WaterParameter,
          $$WaterParametersTableFilterComposer,
          $$WaterParametersTableOrderingComposer,
          $$WaterParametersTableAnnotationComposer,
          $$WaterParametersTableCreateCompanionBuilder,
          $$WaterParametersTableUpdateCompanionBuilder,
          (WaterParameter, $$WaterParametersTableReferences),
          WaterParameter,
          PrefetchHooks Function({
            bool tankParametersRefs,
            bool waterQualityTargetsRefs,
            bool reagentProfilesRefs,
            bool testRecordsRefs,
            bool testTimerDefaultsRefs,
            bool activeTestSessionsRefs,
          })
        > {
  $$WaterParametersTableTableManager(
    _$AppDatabase db,
    $WaterParametersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterParametersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterParametersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterParametersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<bool> photoSupported = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WaterParametersCompanion(
                id: id,
                code: code,
                displayName: displayName,
                unit: unit,
                isBuiltIn: isBuiltIn,
                photoSupported: photoSupported,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String displayName,
                required String unit,
                required bool isBuiltIn,
                Value<bool> photoSupported = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WaterParametersCompanion.insert(
                id: id,
                code: code,
                displayName: displayName,
                unit: unit,
                isBuiltIn: isBuiltIn,
                photoSupported: photoSupported,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WaterParametersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tankParametersRefs = false,
                waterQualityTargetsRefs = false,
                reagentProfilesRefs = false,
                testRecordsRefs = false,
                testTimerDefaultsRefs = false,
                activeTestSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tankParametersRefs) db.tankParameters,
                    if (waterQualityTargetsRefs) db.waterQualityTargets,
                    if (reagentProfilesRefs) db.reagentProfiles,
                    if (testRecordsRefs) db.testRecords,
                    if (testTimerDefaultsRefs) db.testTimerDefaults,
                    if (activeTestSessionsRefs) db.activeTestSessions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tankParametersRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          TankParameter
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._tankParametersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).tankParametersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (waterQualityTargetsRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          WaterQualityTarget
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._waterQualityTargetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).waterQualityTargetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (reagentProfilesRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          ReagentProfile
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._reagentProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).reagentProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (testRecordsRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          TestRecord
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._testRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).testRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (testTimerDefaultsRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          TestTimerDefault
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._testTimerDefaultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).testTimerDefaultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activeTestSessionsRefs)
                        await $_getPrefetchedData<
                          WaterParameter,
                          $WaterParametersTable,
                          ActiveTestSession
                        >(
                          currentTable: table,
                          referencedTable: $$WaterParametersTableReferences
                              ._activeTestSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WaterParametersTableReferences(
                                db,
                                table,
                                p0,
                              ).activeTestSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.parameterId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WaterParametersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterParametersTable,
      WaterParameter,
      $$WaterParametersTableFilterComposer,
      $$WaterParametersTableOrderingComposer,
      $$WaterParametersTableAnnotationComposer,
      $$WaterParametersTableCreateCompanionBuilder,
      $$WaterParametersTableUpdateCompanionBuilder,
      (WaterParameter, $$WaterParametersTableReferences),
      WaterParameter,
      PrefetchHooks Function({
        bool tankParametersRefs,
        bool waterQualityTargetsRefs,
        bool reagentProfilesRefs,
        bool testRecordsRefs,
        bool testTimerDefaultsRefs,
        bool activeTestSessionsRefs,
      })
    >;
typedef $$TankParametersTableCreateCompanionBuilder =
    TankParametersCompanion Function({
      required String tankId,
      required String parameterId,
      Value<bool> isEnabled,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TankParametersTableUpdateCompanionBuilder =
    TankParametersCompanion Function({
      Value<String> tankId,
      Value<String> parameterId,
      Value<bool> isEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TankParametersTableReferences
    extends BaseReferences<_$AppDatabase, $TankParametersTable, TankParameter> {
  $$TankParametersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('tank_parameters__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('tank_parameters__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TankParametersTableFilterComposer
    extends Composer<_$AppDatabase, $TankParametersTable> {
  $$TankParametersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TankParametersTableOrderingComposer
    extends Composer<_$AppDatabase, $TankParametersTable> {
  $$TankParametersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TankParametersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TankParametersTable> {
  $$TankParametersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TankParametersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TankParametersTable,
          TankParameter,
          $$TankParametersTableFilterComposer,
          $$TankParametersTableOrderingComposer,
          $$TankParametersTableAnnotationComposer,
          $$TankParametersTableCreateCompanionBuilder,
          $$TankParametersTableUpdateCompanionBuilder,
          (TankParameter, $$TankParametersTableReferences),
          TankParameter,
          PrefetchHooks Function({bool tankId, bool parameterId})
        > {
  $$TankParametersTableTableManager(
    _$AppDatabase db,
    $TankParametersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TankParametersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TankParametersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TankParametersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tankId = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TankParametersCompanion(
                tankId: tankId,
                parameterId: parameterId,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tankId,
                required String parameterId,
                Value<bool> isEnabled = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TankParametersCompanion.insert(
                tankId: tankId,
                parameterId: parameterId,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TankParametersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false, parameterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable: $$TankParametersTableReferences
                                    ._tankIdTable(db),
                                referencedColumn:
                                    $$TankParametersTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (parameterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parameterId,
                                referencedTable: $$TankParametersTableReferences
                                    ._parameterIdTable(db),
                                referencedColumn:
                                    $$TankParametersTableReferences
                                        ._parameterIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TankParametersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TankParametersTable,
      TankParameter,
      $$TankParametersTableFilterComposer,
      $$TankParametersTableOrderingComposer,
      $$TankParametersTableAnnotationComposer,
      $$TankParametersTableCreateCompanionBuilder,
      $$TankParametersTableUpdateCompanionBuilder,
      (TankParameter, $$TankParametersTableReferences),
      TankParameter,
      PrefetchHooks Function({bool tankId, bool parameterId})
    >;
typedef $$WaterQualityTargetsTableCreateCompanionBuilder =
    WaterQualityTargetsCompanion Function({
      required String id,
      required String tankId,
      required String parameterId,
      Value<double?> minValue,
      Value<double?> maxValue,
      required String unit,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WaterQualityTargetsTableUpdateCompanionBuilder =
    WaterQualityTargetsCompanion Function({
      Value<String> id,
      Value<String> tankId,
      Value<String> parameterId,
      Value<double?> minValue,
      Value<double?> maxValue,
      Value<String> unit,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WaterQualityTargetsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WaterQualityTargetsTable,
          WaterQualityTarget
        > {
  $$WaterQualityTargetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('water_quality_targets__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('water_quality_targets__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WaterQualityTargetsTableFilterComposer
    extends Composer<_$AppDatabase, $WaterQualityTargetsTable> {
  $$WaterQualityTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minValue => $composableBuilder(
    column: $table.minValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxValue => $composableBuilder(
    column: $table.maxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WaterQualityTargetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterQualityTargetsTable> {
  $$WaterQualityTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minValue => $composableBuilder(
    column: $table.minValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxValue => $composableBuilder(
    column: $table.maxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WaterQualityTargetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterQualityTargetsTable> {
  $$WaterQualityTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get minValue =>
      $composableBuilder(column: $table.minValue, builder: (column) => column);

  GeneratedColumn<double> get maxValue =>
      $composableBuilder(column: $table.maxValue, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WaterQualityTargetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterQualityTargetsTable,
          WaterQualityTarget,
          $$WaterQualityTargetsTableFilterComposer,
          $$WaterQualityTargetsTableOrderingComposer,
          $$WaterQualityTargetsTableAnnotationComposer,
          $$WaterQualityTargetsTableCreateCompanionBuilder,
          $$WaterQualityTargetsTableUpdateCompanionBuilder,
          (WaterQualityTarget, $$WaterQualityTargetsTableReferences),
          WaterQualityTarget,
          PrefetchHooks Function({bool tankId, bool parameterId})
        > {
  $$WaterQualityTargetsTableTableManager(
    _$AppDatabase db,
    $WaterQualityTargetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterQualityTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterQualityTargetsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WaterQualityTargetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tankId = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<double?> minValue = const Value.absent(),
                Value<double?> maxValue = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WaterQualityTargetsCompanion(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                minValue: minValue,
                maxValue: maxValue,
                unit: unit,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tankId,
                required String parameterId,
                Value<double?> minValue = const Value.absent(),
                Value<double?> maxValue = const Value.absent(),
                required String unit,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WaterQualityTargetsCompanion.insert(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                minValue: minValue,
                maxValue: maxValue,
                unit: unit,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WaterQualityTargetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false, parameterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable:
                                    $$WaterQualityTargetsTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$WaterQualityTargetsTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (parameterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parameterId,
                                referencedTable:
                                    $$WaterQualityTargetsTableReferences
                                        ._parameterIdTable(db),
                                referencedColumn:
                                    $$WaterQualityTargetsTableReferences
                                        ._parameterIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WaterQualityTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterQualityTargetsTable,
      WaterQualityTarget,
      $$WaterQualityTargetsTableFilterComposer,
      $$WaterQualityTargetsTableOrderingComposer,
      $$WaterQualityTargetsTableAnnotationComposer,
      $$WaterQualityTargetsTableCreateCompanionBuilder,
      $$WaterQualityTargetsTableUpdateCompanionBuilder,
      (WaterQualityTarget, $$WaterQualityTargetsTableReferences),
      WaterQualityTarget,
      PrefetchHooks Function({bool tankId, bool parameterId})
    >;
typedef $$ReagentProfilesTableCreateCompanionBuilder =
    ReagentProfilesCompanion Function({
      required String id,
      required String brand,
      required String parameterId,
      required String unit,
      required String colorLevelsJson,
      required int defaultDevelopmentSeconds,
      Value<String?> cardVersion,
      Value<bool> isEnabled,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReagentProfilesTableUpdateCompanionBuilder =
    ReagentProfilesCompanion Function({
      Value<String> id,
      Value<String> brand,
      Value<String> parameterId,
      Value<String> unit,
      Value<String> colorLevelsJson,
      Value<int> defaultDevelopmentSeconds,
      Value<String?> cardVersion,
      Value<bool> isEnabled,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ReagentProfilesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReagentProfilesTable, ReagentProfile> {
  $$ReagentProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('reagent_profiles__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TestRecordsTable, List<TestRecord>>
  _testRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.testRecords,
    aliasName: 'reagent_profiles__id__test_records__reagent_profile_id',
  );

  $$TestRecordsTableProcessedTableManager get testRecordsRefs {
    final manager = $$TestRecordsTableTableManager($_db, $_db.testRecords)
        .filter(
          (f) => f.reagentProfileId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_testRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActiveTestSessionsTable, List<ActiveTestSession>>
  _activeTestSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.activeTestSessions,
        aliasName:
            'reagent_profiles__id__active_test_sessions__reagent_profile_id',
      );

  $$ActiveTestSessionsTableProcessedTableManager get activeTestSessionsRefs {
    final manager =
        $$ActiveTestSessionsTableTableManager(
          $_db,
          $_db.activeTestSessions,
        ).filter(
          (f) => f.reagentProfileId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _activeTestSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReagentProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ReagentProfilesTable> {
  $$ReagentProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorLevelsJson => $composableBuilder(
    column: $table.colorLevelsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultDevelopmentSeconds => $composableBuilder(
    column: $table.defaultDevelopmentSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardVersion => $composableBuilder(
    column: $table.cardVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> testRecordsRefs(
    Expression<bool> Function($$TestRecordsTableFilterComposer f) f,
  ) {
    final $$TestRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.reagentProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableFilterComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activeTestSessionsRefs(
    Expression<bool> Function($$ActiveTestSessionsTableFilterComposer f) f,
  ) {
    final $$ActiveTestSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activeTestSessions,
      getReferencedColumn: (t) => t.reagentProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActiveTestSessionsTableFilterComposer(
            $db: $db,
            $table: $db.activeTestSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReagentProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReagentProfilesTable> {
  $$ReagentProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get brand => $composableBuilder(
    column: $table.brand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorLevelsJson => $composableBuilder(
    column: $table.colorLevelsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultDevelopmentSeconds => $composableBuilder(
    column: $table.defaultDevelopmentSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardVersion => $composableBuilder(
    column: $table.cardVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReagentProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReagentProfilesTable> {
  $$ReagentProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get colorLevelsJson => $composableBuilder(
    column: $table.colorLevelsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultDevelopmentSeconds => $composableBuilder(
    column: $table.defaultDevelopmentSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardVersion => $composableBuilder(
    column: $table.cardVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> testRecordsRefs<T extends Object>(
    Expression<T> Function($$TestRecordsTableAnnotationComposer a) f,
  ) {
    final $$TestRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.testRecords,
      getReferencedColumn: (t) => t.reagentProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TestRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.testRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activeTestSessionsRefs<T extends Object>(
    Expression<T> Function($$ActiveTestSessionsTableAnnotationComposer a) f,
  ) {
    final $$ActiveTestSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.activeTestSessions,
          getReferencedColumn: (t) => t.reagentProfileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ActiveTestSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.activeTestSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ReagentProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReagentProfilesTable,
          ReagentProfile,
          $$ReagentProfilesTableFilterComposer,
          $$ReagentProfilesTableOrderingComposer,
          $$ReagentProfilesTableAnnotationComposer,
          $$ReagentProfilesTableCreateCompanionBuilder,
          $$ReagentProfilesTableUpdateCompanionBuilder,
          (ReagentProfile, $$ReagentProfilesTableReferences),
          ReagentProfile,
          PrefetchHooks Function({
            bool parameterId,
            bool testRecordsRefs,
            bool activeTestSessionsRefs,
          })
        > {
  $$ReagentProfilesTableTableManager(
    _$AppDatabase db,
    $ReagentProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReagentProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReagentProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReagentProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> brand = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> colorLevelsJson = const Value.absent(),
                Value<int> defaultDevelopmentSeconds = const Value.absent(),
                Value<String?> cardVersion = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReagentProfilesCompanion(
                id: id,
                brand: brand,
                parameterId: parameterId,
                unit: unit,
                colorLevelsJson: colorLevelsJson,
                defaultDevelopmentSeconds: defaultDevelopmentSeconds,
                cardVersion: cardVersion,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String brand,
                required String parameterId,
                required String unit,
                required String colorLevelsJson,
                required int defaultDevelopmentSeconds,
                Value<String?> cardVersion = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReagentProfilesCompanion.insert(
                id: id,
                brand: brand,
                parameterId: parameterId,
                unit: unit,
                colorLevelsJson: colorLevelsJson,
                defaultDevelopmentSeconds: defaultDevelopmentSeconds,
                cardVersion: cardVersion,
                isEnabled: isEnabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReagentProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parameterId = false,
                testRecordsRefs = false,
                activeTestSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (testRecordsRefs) db.testRecords,
                    if (activeTestSessionsRefs) db.activeTestSessions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parameterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parameterId,
                                    referencedTable:
                                        $$ReagentProfilesTableReferences
                                            ._parameterIdTable(db),
                                    referencedColumn:
                                        $$ReagentProfilesTableReferences
                                            ._parameterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (testRecordsRefs)
                        await $_getPrefetchedData<
                          ReagentProfile,
                          $ReagentProfilesTable,
                          TestRecord
                        >(
                          currentTable: table,
                          referencedTable: $$ReagentProfilesTableReferences
                              ._testRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReagentProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).testRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.reagentProfileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (activeTestSessionsRefs)
                        await $_getPrefetchedData<
                          ReagentProfile,
                          $ReagentProfilesTable,
                          ActiveTestSession
                        >(
                          currentTable: table,
                          referencedTable: $$ReagentProfilesTableReferences
                              ._activeTestSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReagentProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).activeTestSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.reagentProfileId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReagentProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReagentProfilesTable,
      ReagentProfile,
      $$ReagentProfilesTableFilterComposer,
      $$ReagentProfilesTableOrderingComposer,
      $$ReagentProfilesTableAnnotationComposer,
      $$ReagentProfilesTableCreateCompanionBuilder,
      $$ReagentProfilesTableUpdateCompanionBuilder,
      (ReagentProfile, $$ReagentProfilesTableReferences),
      ReagentProfile,
      PrefetchHooks Function({
        bool parameterId,
        bool testRecordsRefs,
        bool activeTestSessionsRefs,
      })
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<int> id,
      Value<String?> currentTankId,
      Value<String> themeMode,
      Value<bool> maintenanceNotificationsEnabled,
      Value<String> fishStockJson,
      Value<bool> khTargetDefaultsApplied,
      required DateTime updatedAt,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<int> id,
      Value<String?> currentTankId,
      Value<String> themeMode,
      Value<bool> maintenanceNotificationsEnabled,
      Value<String> fishStockJson,
      Value<bool> khTargetDefaultsApplied,
      Value<DateTime> updatedAt,
    });

final class $$AppPreferencesTableReferences
    extends BaseReferences<_$AppDatabase, $AppPreferencesTable, AppPreference> {
  $$AppPreferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _currentTankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('app_preferences__current_tank_id__tanks__id');

  $$TanksTableProcessedTableManager? get currentTankId {
    final $_column = $_itemColumn<String>('current_tank_id');
    if ($_column == null) return null;
    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currentTankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AppPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get maintenanceNotificationsEnabled => $composableBuilder(
    column: $table.maintenanceNotificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fishStockJson => $composableBuilder(
    column: $table.fishStockJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get khTargetDefaultsApplied => $composableBuilder(
    column: $table.khTargetDefaultsApplied,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get currentTankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentTankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get maintenanceNotificationsEnabled =>
      $composableBuilder(
        column: $table.maintenanceNotificationsEnabled,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<String> get fishStockJson => $composableBuilder(
    column: $table.fishStockJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get khTargetDefaultsApplied => $composableBuilder(
    column: $table.khTargetDefaultsApplied,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get currentTankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentTankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<bool> get maintenanceNotificationsEnabled =>
      $composableBuilder(
        column: $table.maintenanceNotificationsEnabled,
        builder: (column) => column,
      );

  GeneratedColumn<String> get fishStockJson => $composableBuilder(
    column: $table.fishStockJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get khTargetDefaultsApplied => $composableBuilder(
    column: $table.khTargetDefaultsApplied,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get currentTankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentTankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppPreferencesTable,
          AppPreference,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (AppPreference, $$AppPreferencesTableReferences),
          AppPreference,
          PrefetchHooks Function({bool currentTankId})
        > {
  $$AppPreferencesTableTableManager(
    _$AppDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentTankId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> maintenanceNotificationsEnabled =
                    const Value.absent(),
                Value<String> fishStockJson = const Value.absent(),
                Value<bool> khTargetDefaultsApplied = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppPreferencesCompanion(
                id: id,
                currentTankId: currentTankId,
                themeMode: themeMode,
                maintenanceNotificationsEnabled:
                    maintenanceNotificationsEnabled,
                fishStockJson: fishStockJson,
                khTargetDefaultsApplied: khTargetDefaultsApplied,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> currentTankId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<bool> maintenanceNotificationsEnabled =
                    const Value.absent(),
                Value<String> fishStockJson = const Value.absent(),
                Value<bool> khTargetDefaultsApplied = const Value.absent(),
                required DateTime updatedAt,
              }) => AppPreferencesCompanion.insert(
                id: id,
                currentTankId: currentTankId,
                themeMode: themeMode,
                maintenanceNotificationsEnabled:
                    maintenanceNotificationsEnabled,
                fishStockJson: fishStockJson,
                khTargetDefaultsApplied: khTargetDefaultsApplied,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AppPreferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({currentTankId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (currentTankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.currentTankId,
                                referencedTable: $$AppPreferencesTableReferences
                                    ._currentTankIdTable(db),
                                referencedColumn:
                                    $$AppPreferencesTableReferences
                                        ._currentTankIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppPreferencesTable,
      AppPreference,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (AppPreference, $$AppPreferencesTableReferences),
      AppPreference,
      PrefetchHooks Function({bool currentTankId})
    >;
typedef $$TestRecordsTableCreateCompanionBuilder =
    TestRecordsCompanion Function({
      required String id,
      required String tankId,
      required String parameterId,
      Value<String?> reagentProfileId,
      Value<DateTime?> capturedAt,
      Value<double?> estimatedMinValue,
      Value<double?> estimatedMaxValue,
      Value<String?> estimationMethod,
      Value<String?> estimationVersion,
      Value<double?> qualityScore,
      Value<String?> confidence,
      Value<String?> failureReason,
      Value<String?> khTitrationJson,
      required double confirmedMinValue,
      Value<double?> confirmedInterpolation,
      Value<double?> estimatedInterpolation,
      Value<double?> confirmedMaxValue,
      required String unit,
      required DateTime measuredAt,
      Value<DateTime?> confirmedAt,
      Value<String?> notes,
      Value<String?> photoPath,
      Value<bool> wasManuallyEdited,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TestRecordsTableUpdateCompanionBuilder =
    TestRecordsCompanion Function({
      Value<String> id,
      Value<String> tankId,
      Value<String> parameterId,
      Value<String?> reagentProfileId,
      Value<DateTime?> capturedAt,
      Value<double?> estimatedMinValue,
      Value<double?> estimatedMaxValue,
      Value<String?> estimationMethod,
      Value<String?> estimationVersion,
      Value<double?> qualityScore,
      Value<String?> confidence,
      Value<String?> failureReason,
      Value<String?> khTitrationJson,
      Value<double> confirmedMinValue,
      Value<double?> confirmedInterpolation,
      Value<double?> estimatedInterpolation,
      Value<double?> confirmedMaxValue,
      Value<String> unit,
      Value<DateTime> measuredAt,
      Value<DateTime?> confirmedAt,
      Value<String?> notes,
      Value<String?> photoPath,
      Value<bool> wasManuallyEdited,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TestRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $TestRecordsTable, TestRecord> {
  $$TestRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('test_records__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('test_records__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReagentProfilesTable _reagentProfileIdTable(_$AppDatabase db) => db
      .reagentProfiles
      .createAlias('test_records__reagent_profile_id__reagent_profiles__id');

  $$ReagentProfilesTableProcessedTableManager? get reagentProfileId {
    final $_column = $_itemColumn<String>('reagent_profile_id');
    if ($_column == null) return null;
    final manager = $$ReagentProfilesTableTableManager(
      $_db,
      $_db.reagentProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reagentProfileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TestRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $TestRecordsTable> {
  $$TestRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimatedMinValue => $composableBuilder(
    column: $table.estimatedMinValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimatedMaxValue => $composableBuilder(
    column: $table.estimatedMaxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimationMethod => $composableBuilder(
    column: $table.estimationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estimationVersion => $composableBuilder(
    column: $table.estimationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qualityScore => $composableBuilder(
    column: $table.qualityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get khTitrationJson => $composableBuilder(
    column: $table.khTitrationJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confirmedMinValue => $composableBuilder(
    column: $table.confirmedMinValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confirmedInterpolation => $composableBuilder(
    column: $table.confirmedInterpolation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimatedInterpolation => $composableBuilder(
    column: $table.estimatedInterpolation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confirmedMaxValue => $composableBuilder(
    column: $table.confirmedMaxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasManuallyEdited => $composableBuilder(
    column: $table.wasManuallyEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableFilterComposer get reagentProfileId {
    final $$ReagentProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableFilterComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestRecordsTable> {
  $$TestRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedMinValue => $composableBuilder(
    column: $table.estimatedMinValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedMaxValue => $composableBuilder(
    column: $table.estimatedMaxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimationMethod => $composableBuilder(
    column: $table.estimationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estimationVersion => $composableBuilder(
    column: $table.estimationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qualityScore => $composableBuilder(
    column: $table.qualityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get khTitrationJson => $composableBuilder(
    column: $table.khTitrationJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confirmedMinValue => $composableBuilder(
    column: $table.confirmedMinValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confirmedInterpolation => $composableBuilder(
    column: $table.confirmedInterpolation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimatedInterpolation => $composableBuilder(
    column: $table.estimatedInterpolation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confirmedMaxValue => $composableBuilder(
    column: $table.confirmedMaxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasManuallyEdited => $composableBuilder(
    column: $table.wasManuallyEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableOrderingComposer get reagentProfileId {
    final $$ReagentProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestRecordsTable> {
  $$TestRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estimatedMinValue => $composableBuilder(
    column: $table.estimatedMinValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estimatedMaxValue => $composableBuilder(
    column: $table.estimatedMaxValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estimationMethod => $composableBuilder(
    column: $table.estimationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estimationVersion => $composableBuilder(
    column: $table.estimationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get qualityScore => $composableBuilder(
    column: $table.qualityScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get khTitrationJson => $composableBuilder(
    column: $table.khTitrationJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confirmedMinValue => $composableBuilder(
    column: $table.confirmedMinValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confirmedInterpolation => $composableBuilder(
    column: $table.confirmedInterpolation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estimatedInterpolation => $composableBuilder(
    column: $table.estimatedInterpolation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confirmedMaxValue => $composableBuilder(
    column: $table.confirmedMaxValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get measuredAt => $composableBuilder(
    column: $table.measuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<bool> get wasManuallyEdited => $composableBuilder(
    column: $table.wasManuallyEdited,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableAnnotationComposer get reagentProfileId {
    final $$ReagentProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TestRecordsTable,
          TestRecord,
          $$TestRecordsTableFilterComposer,
          $$TestRecordsTableOrderingComposer,
          $$TestRecordsTableAnnotationComposer,
          $$TestRecordsTableCreateCompanionBuilder,
          $$TestRecordsTableUpdateCompanionBuilder,
          (TestRecord, $$TestRecordsTableReferences),
          TestRecord,
          PrefetchHooks Function({
            bool tankId,
            bool parameterId,
            bool reagentProfileId,
          })
        > {
  $$TestRecordsTableTableManager(_$AppDatabase db, $TestRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tankId = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<String?> reagentProfileId = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<double?> estimatedMinValue = const Value.absent(),
                Value<double?> estimatedMaxValue = const Value.absent(),
                Value<String?> estimationMethod = const Value.absent(),
                Value<String?> estimationVersion = const Value.absent(),
                Value<double?> qualityScore = const Value.absent(),
                Value<String?> confidence = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<String?> khTitrationJson = const Value.absent(),
                Value<double> confirmedMinValue = const Value.absent(),
                Value<double?> confirmedInterpolation = const Value.absent(),
                Value<double?> estimatedInterpolation = const Value.absent(),
                Value<double?> confirmedMaxValue = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime> measuredAt = const Value.absent(),
                Value<DateTime?> confirmedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> wasManuallyEdited = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TestRecordsCompanion(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                reagentProfileId: reagentProfileId,
                capturedAt: capturedAt,
                estimatedMinValue: estimatedMinValue,
                estimatedMaxValue: estimatedMaxValue,
                estimationMethod: estimationMethod,
                estimationVersion: estimationVersion,
                qualityScore: qualityScore,
                confidence: confidence,
                failureReason: failureReason,
                khTitrationJson: khTitrationJson,
                confirmedMinValue: confirmedMinValue,
                confirmedInterpolation: confirmedInterpolation,
                estimatedInterpolation: estimatedInterpolation,
                confirmedMaxValue: confirmedMaxValue,
                unit: unit,
                measuredAt: measuredAt,
                confirmedAt: confirmedAt,
                notes: notes,
                photoPath: photoPath,
                wasManuallyEdited: wasManuallyEdited,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tankId,
                required String parameterId,
                Value<String?> reagentProfileId = const Value.absent(),
                Value<DateTime?> capturedAt = const Value.absent(),
                Value<double?> estimatedMinValue = const Value.absent(),
                Value<double?> estimatedMaxValue = const Value.absent(),
                Value<String?> estimationMethod = const Value.absent(),
                Value<String?> estimationVersion = const Value.absent(),
                Value<double?> qualityScore = const Value.absent(),
                Value<String?> confidence = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<String?> khTitrationJson = const Value.absent(),
                required double confirmedMinValue,
                Value<double?> confirmedInterpolation = const Value.absent(),
                Value<double?> estimatedInterpolation = const Value.absent(),
                Value<double?> confirmedMaxValue = const Value.absent(),
                required String unit,
                required DateTime measuredAt,
                Value<DateTime?> confirmedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> wasManuallyEdited = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TestRecordsCompanion.insert(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                reagentProfileId: reagentProfileId,
                capturedAt: capturedAt,
                estimatedMinValue: estimatedMinValue,
                estimatedMaxValue: estimatedMaxValue,
                estimationMethod: estimationMethod,
                estimationVersion: estimationVersion,
                qualityScore: qualityScore,
                confidence: confidence,
                failureReason: failureReason,
                khTitrationJson: khTitrationJson,
                confirmedMinValue: confirmedMinValue,
                confirmedInterpolation: confirmedInterpolation,
                estimatedInterpolation: estimatedInterpolation,
                confirmedMaxValue: confirmedMaxValue,
                unit: unit,
                measuredAt: measuredAt,
                confirmedAt: confirmedAt,
                notes: notes,
                photoPath: photoPath,
                wasManuallyEdited: wasManuallyEdited,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TestRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tankId = false,
                parameterId = false,
                reagentProfileId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (tankId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tankId,
                                    referencedTable:
                                        $$TestRecordsTableReferences
                                            ._tankIdTable(db),
                                    referencedColumn:
                                        $$TestRecordsTableReferences
                                            ._tankIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (parameterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parameterId,
                                    referencedTable:
                                        $$TestRecordsTableReferences
                                            ._parameterIdTable(db),
                                    referencedColumn:
                                        $$TestRecordsTableReferences
                                            ._parameterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (reagentProfileId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.reagentProfileId,
                                    referencedTable:
                                        $$TestRecordsTableReferences
                                            ._reagentProfileIdTable(db),
                                    referencedColumn:
                                        $$TestRecordsTableReferences
                                            ._reagentProfileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$TestRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TestRecordsTable,
      TestRecord,
      $$TestRecordsTableFilterComposer,
      $$TestRecordsTableOrderingComposer,
      $$TestRecordsTableAnnotationComposer,
      $$TestRecordsTableCreateCompanionBuilder,
      $$TestRecordsTableUpdateCompanionBuilder,
      (TestRecord, $$TestRecordsTableReferences),
      TestRecord,
      PrefetchHooks Function({
        bool tankId,
        bool parameterId,
        bool reagentProfileId,
      })
    >;
typedef $$MaintenanceTasksTableCreateCompanionBuilder =
    MaintenanceTasksCompanion Function({
      required String id,
      required String tankId,
      required String title,
      Value<String?> notes,
      required int intervalAmount,
      required String intervalUnit,
      required DateTime dueAt,
      Value<String> preferredReminderTime,
      Value<String> status,
      Value<bool> isOneOff,
      Value<String?> source,
      Value<String?> planId,
      Value<int?> planDayIndex,
      Value<int?> planTotalDays,
      Value<String?> recurrenceJson,
      Value<String?> rollingJson,
      Value<int?> notificationId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MaintenanceTasksTableUpdateCompanionBuilder =
    MaintenanceTasksCompanion Function({
      Value<String> id,
      Value<String> tankId,
      Value<String> title,
      Value<String?> notes,
      Value<int> intervalAmount,
      Value<String> intervalUnit,
      Value<DateTime> dueAt,
      Value<String> preferredReminderTime,
      Value<String> status,
      Value<bool> isOneOff,
      Value<String?> source,
      Value<String?> planId,
      Value<int?> planDayIndex,
      Value<int?> planTotalDays,
      Value<String?> recurrenceJson,
      Value<String?> rollingJson,
      Value<int?> notificationId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MaintenanceTasksTableReferences
    extends
        BaseReferences<_$AppDatabase, $MaintenanceTasksTable, MaintenanceTask> {
  $$MaintenanceTasksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('maintenance_tasks__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskEventsTable, List<TaskEvent>>
  _taskEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskEvents,
    aliasName: 'maintenance_tasks__id__task_events__task_id',
  );

  $$TaskEventsTableProcessedTableManager get taskEventsRefs {
    final manager = $$TaskEventsTableTableManager(
      $_db,
      $_db.taskEvents,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MaintenanceTasksTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceTasksTable> {
  $$MaintenanceTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalAmount => $composableBuilder(
    column: $table.intervalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intervalUnit => $composableBuilder(
    column: $table.intervalUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredReminderTime => $composableBuilder(
    column: $table.preferredReminderTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOneOff => $composableBuilder(
    column: $table.isOneOff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planDayIndex => $composableBuilder(
    column: $table.planDayIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get planTotalDays => $composableBuilder(
    column: $table.planTotalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rollingJson => $composableBuilder(
    column: $table.rollingJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskEventsRefs(
    Expression<bool> Function($$TaskEventsTableFilterComposer f) f,
  ) {
    final $$TaskEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskEvents,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskEventsTableFilterComposer(
            $db: $db,
            $table: $db.taskEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MaintenanceTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceTasksTable> {
  $$MaintenanceTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalAmount => $composableBuilder(
    column: $table.intervalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intervalUnit => $composableBuilder(
    column: $table.intervalUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredReminderTime => $composableBuilder(
    column: $table.preferredReminderTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOneOff => $composableBuilder(
    column: $table.isOneOff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planDayIndex => $composableBuilder(
    column: $table.planDayIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get planTotalDays => $composableBuilder(
    column: $table.planTotalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rollingJson => $composableBuilder(
    column: $table.rollingJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceTasksTable> {
  $$MaintenanceTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get intervalAmount => $composableBuilder(
    column: $table.intervalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get intervalUnit => $composableBuilder(
    column: $table.intervalUnit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<String> get preferredReminderTime => $composableBuilder(
    column: $table.preferredReminderTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isOneOff =>
      $composableBuilder(column: $table.isOneOff, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<int> get planDayIndex => $composableBuilder(
    column: $table.planDayIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get planTotalDays => $composableBuilder(
    column: $table.planTotalDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceJson => $composableBuilder(
    column: $table.recurrenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rollingJson => $composableBuilder(
    column: $table.rollingJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskEventsRefs<T extends Object>(
    Expression<T> Function($$TaskEventsTableAnnotationComposer a) f,
  ) {
    final $$TaskEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskEvents,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MaintenanceTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceTasksTable,
          MaintenanceTask,
          $$MaintenanceTasksTableFilterComposer,
          $$MaintenanceTasksTableOrderingComposer,
          $$MaintenanceTasksTableAnnotationComposer,
          $$MaintenanceTasksTableCreateCompanionBuilder,
          $$MaintenanceTasksTableUpdateCompanionBuilder,
          (MaintenanceTask, $$MaintenanceTasksTableReferences),
          MaintenanceTask,
          PrefetchHooks Function({bool tankId, bool taskEventsRefs})
        > {
  $$MaintenanceTasksTableTableManager(
    _$AppDatabase db,
    $MaintenanceTasksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tankId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> intervalAmount = const Value.absent(),
                Value<String> intervalUnit = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<String> preferredReminderTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isOneOff = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<int?> planDayIndex = const Value.absent(),
                Value<int?> planTotalDays = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> rollingJson = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceTasksCompanion(
                id: id,
                tankId: tankId,
                title: title,
                notes: notes,
                intervalAmount: intervalAmount,
                intervalUnit: intervalUnit,
                dueAt: dueAt,
                preferredReminderTime: preferredReminderTime,
                status: status,
                isOneOff: isOneOff,
                source: source,
                planId: planId,
                planDayIndex: planDayIndex,
                planTotalDays: planTotalDays,
                recurrenceJson: recurrenceJson,
                rollingJson: rollingJson,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tankId,
                required String title,
                Value<String?> notes = const Value.absent(),
                required int intervalAmount,
                required String intervalUnit,
                required DateTime dueAt,
                Value<String> preferredReminderTime = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isOneOff = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<int?> planDayIndex = const Value.absent(),
                Value<int?> planTotalDays = const Value.absent(),
                Value<String?> recurrenceJson = const Value.absent(),
                Value<String?> rollingJson = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceTasksCompanion.insert(
                id: id,
                tankId: tankId,
                title: title,
                notes: notes,
                intervalAmount: intervalAmount,
                intervalUnit: intervalUnit,
                dueAt: dueAt,
                preferredReminderTime: preferredReminderTime,
                status: status,
                isOneOff: isOneOff,
                source: source,
                planId: planId,
                planDayIndex: planDayIndex,
                planTotalDays: planTotalDays,
                recurrenceJson: recurrenceJson,
                rollingJson: rollingJson,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false, taskEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskEventsRefs) db.taskEvents],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable:
                                    $$MaintenanceTasksTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$MaintenanceTasksTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskEventsRefs)
                    await $_getPrefetchedData<
                      MaintenanceTask,
                      $MaintenanceTasksTable,
                      TaskEvent
                    >(
                      currentTable: table,
                      referencedTable: $$MaintenanceTasksTableReferences
                          ._taskEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MaintenanceTasksTableReferences(
                            db,
                            table,
                            p0,
                          ).taskEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MaintenanceTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceTasksTable,
      MaintenanceTask,
      $$MaintenanceTasksTableFilterComposer,
      $$MaintenanceTasksTableOrderingComposer,
      $$MaintenanceTasksTableAnnotationComposer,
      $$MaintenanceTasksTableCreateCompanionBuilder,
      $$MaintenanceTasksTableUpdateCompanionBuilder,
      (MaintenanceTask, $$MaintenanceTasksTableReferences),
      MaintenanceTask,
      PrefetchHooks Function({bool tankId, bool taskEventsRefs})
    >;
typedef $$MaintenanceCyclesTableCreateCompanionBuilder =
    MaintenanceCyclesCompanion Function({
      required String id,
      required String tankId,
      required String chemical,
      required String startDate,
      required String refillDate,
      required double solutionMl,
      required double dailyLiquidMl,
      required double effectPerMl,
      required double retainedMl,
      required double addedStockMl,
      required double addedWaterMl,
      required String inputJson,
      Value<String?> previousCycleId,
      Value<String?> closedOnDate,
      Value<String?> refillDeferredUntil,
      Value<int?> notificationId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MaintenanceCyclesTableUpdateCompanionBuilder =
    MaintenanceCyclesCompanion Function({
      Value<String> id,
      Value<String> tankId,
      Value<String> chemical,
      Value<String> startDate,
      Value<String> refillDate,
      Value<double> solutionMl,
      Value<double> dailyLiquidMl,
      Value<double> effectPerMl,
      Value<double> retainedMl,
      Value<double> addedStockMl,
      Value<double> addedWaterMl,
      Value<String> inputJson,
      Value<String?> previousCycleId,
      Value<String?> closedOnDate,
      Value<String?> refillDeferredUntil,
      Value<int?> notificationId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MaintenanceCyclesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MaintenanceCyclesTable,
          MaintenanceCycleRow
        > {
  $$MaintenanceCyclesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('maintenance_cycles__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MaintenanceCyclesTableFilterComposer
    extends Composer<_$AppDatabase, $MaintenanceCyclesTable> {
  $$MaintenanceCyclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chemical => $composableBuilder(
    column: $table.chemical,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refillDate => $composableBuilder(
    column: $table.refillDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get solutionMl => $composableBuilder(
    column: $table.solutionMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dailyLiquidMl => $composableBuilder(
    column: $table.dailyLiquidMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get effectPerMl => $composableBuilder(
    column: $table.effectPerMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retainedMl => $composableBuilder(
    column: $table.retainedMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get addedStockMl => $composableBuilder(
    column: $table.addedStockMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get addedWaterMl => $composableBuilder(
    column: $table.addedWaterMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousCycleId => $composableBuilder(
    column: $table.previousCycleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedOnDate => $composableBuilder(
    column: $table.closedOnDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refillDeferredUntil => $composableBuilder(
    column: $table.refillDeferredUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceCyclesTableOrderingComposer
    extends Composer<_$AppDatabase, $MaintenanceCyclesTable> {
  $$MaintenanceCyclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chemical => $composableBuilder(
    column: $table.chemical,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refillDate => $composableBuilder(
    column: $table.refillDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get solutionMl => $composableBuilder(
    column: $table.solutionMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dailyLiquidMl => $composableBuilder(
    column: $table.dailyLiquidMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get effectPerMl => $composableBuilder(
    column: $table.effectPerMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retainedMl => $composableBuilder(
    column: $table.retainedMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get addedStockMl => $composableBuilder(
    column: $table.addedStockMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get addedWaterMl => $composableBuilder(
    column: $table.addedWaterMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputJson => $composableBuilder(
    column: $table.inputJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousCycleId => $composableBuilder(
    column: $table.previousCycleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedOnDate => $composableBuilder(
    column: $table.closedOnDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refillDeferredUntil => $composableBuilder(
    column: $table.refillDeferredUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceCyclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MaintenanceCyclesTable> {
  $$MaintenanceCyclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get chemical =>
      $composableBuilder(column: $table.chemical, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get refillDate => $composableBuilder(
    column: $table.refillDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get solutionMl => $composableBuilder(
    column: $table.solutionMl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get dailyLiquidMl => $composableBuilder(
    column: $table.dailyLiquidMl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get effectPerMl => $composableBuilder(
    column: $table.effectPerMl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retainedMl => $composableBuilder(
    column: $table.retainedMl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get addedStockMl => $composableBuilder(
    column: $table.addedStockMl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get addedWaterMl => $composableBuilder(
    column: $table.addedWaterMl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inputJson =>
      $composableBuilder(column: $table.inputJson, builder: (column) => column);

  GeneratedColumn<String> get previousCycleId => $composableBuilder(
    column: $table.previousCycleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedOnDate => $composableBuilder(
    column: $table.closedOnDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refillDeferredUntil => $composableBuilder(
    column: $table.refillDeferredUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationId => $composableBuilder(
    column: $table.notificationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MaintenanceCyclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MaintenanceCyclesTable,
          MaintenanceCycleRow,
          $$MaintenanceCyclesTableFilterComposer,
          $$MaintenanceCyclesTableOrderingComposer,
          $$MaintenanceCyclesTableAnnotationComposer,
          $$MaintenanceCyclesTableCreateCompanionBuilder,
          $$MaintenanceCyclesTableUpdateCompanionBuilder,
          (MaintenanceCycleRow, $$MaintenanceCyclesTableReferences),
          MaintenanceCycleRow,
          PrefetchHooks Function({bool tankId})
        > {
  $$MaintenanceCyclesTableTableManager(
    _$AppDatabase db,
    $MaintenanceCyclesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MaintenanceCyclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MaintenanceCyclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MaintenanceCyclesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tankId = const Value.absent(),
                Value<String> chemical = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<String> refillDate = const Value.absent(),
                Value<double> solutionMl = const Value.absent(),
                Value<double> dailyLiquidMl = const Value.absent(),
                Value<double> effectPerMl = const Value.absent(),
                Value<double> retainedMl = const Value.absent(),
                Value<double> addedStockMl = const Value.absent(),
                Value<double> addedWaterMl = const Value.absent(),
                Value<String> inputJson = const Value.absent(),
                Value<String?> previousCycleId = const Value.absent(),
                Value<String?> closedOnDate = const Value.absent(),
                Value<String?> refillDeferredUntil = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceCyclesCompanion(
                id: id,
                tankId: tankId,
                chemical: chemical,
                startDate: startDate,
                refillDate: refillDate,
                solutionMl: solutionMl,
                dailyLiquidMl: dailyLiquidMl,
                effectPerMl: effectPerMl,
                retainedMl: retainedMl,
                addedStockMl: addedStockMl,
                addedWaterMl: addedWaterMl,
                inputJson: inputJson,
                previousCycleId: previousCycleId,
                closedOnDate: closedOnDate,
                refillDeferredUntil: refillDeferredUntil,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tankId,
                required String chemical,
                required String startDate,
                required String refillDate,
                required double solutionMl,
                required double dailyLiquidMl,
                required double effectPerMl,
                required double retainedMl,
                required double addedStockMl,
                required double addedWaterMl,
                required String inputJson,
                Value<String?> previousCycleId = const Value.absent(),
                Value<String?> closedOnDate = const Value.absent(),
                Value<String?> refillDeferredUntil = const Value.absent(),
                Value<int?> notificationId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MaintenanceCyclesCompanion.insert(
                id: id,
                tankId: tankId,
                chemical: chemical,
                startDate: startDate,
                refillDate: refillDate,
                solutionMl: solutionMl,
                dailyLiquidMl: dailyLiquidMl,
                effectPerMl: effectPerMl,
                retainedMl: retainedMl,
                addedStockMl: addedStockMl,
                addedWaterMl: addedWaterMl,
                inputJson: inputJson,
                previousCycleId: previousCycleId,
                closedOnDate: closedOnDate,
                refillDeferredUntil: refillDeferredUntil,
                notificationId: notificationId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MaintenanceCyclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable:
                                    $$MaintenanceCyclesTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$MaintenanceCyclesTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MaintenanceCyclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MaintenanceCyclesTable,
      MaintenanceCycleRow,
      $$MaintenanceCyclesTableFilterComposer,
      $$MaintenanceCyclesTableOrderingComposer,
      $$MaintenanceCyclesTableAnnotationComposer,
      $$MaintenanceCyclesTableCreateCompanionBuilder,
      $$MaintenanceCyclesTableUpdateCompanionBuilder,
      (MaintenanceCycleRow, $$MaintenanceCyclesTableReferences),
      MaintenanceCycleRow,
      PrefetchHooks Function({bool tankId})
    >;
typedef $$TaskEventsTableCreateCompanionBuilder =
    TaskEventsCompanion Function({
      required String id,
      required String taskId,
      required String type,
      required DateTime occurredAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$TaskEventsTableUpdateCompanionBuilder =
    TaskEventsCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> type,
      Value<DateTime> occurredAt,
      Value<DateTime?> snoozedUntil,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$TaskEventsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskEventsTable, TaskEvent> {
  $$TaskEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MaintenanceTasksTable _taskIdTable(_$AppDatabase db) => db
      .maintenanceTasks
      .createAlias('task_events__task_id__maintenance_tasks__id');

  $$MaintenanceTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$MaintenanceTasksTableTableManager(
      $_db,
      $_db.maintenanceTasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskEventsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskEventsTable> {
  $$TaskEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$MaintenanceTasksTableFilterComposer get taskId {
    final $$MaintenanceTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.maintenanceTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceTasksTableFilterComposer(
            $db: $db,
            $table: $db.maintenanceTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskEventsTable> {
  $$TaskEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$MaintenanceTasksTableOrderingComposer get taskId {
    final $$MaintenanceTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.maintenanceTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceTasksTableOrderingComposer(
            $db: $db,
            $table: $db.maintenanceTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskEventsTable> {
  $$TaskEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$MaintenanceTasksTableAnnotationComposer get taskId {
    final $$MaintenanceTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.maintenanceTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MaintenanceTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.maintenanceTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskEventsTable,
          TaskEvent,
          $$TaskEventsTableFilterComposer,
          $$TaskEventsTableOrderingComposer,
          $$TaskEventsTableAnnotationComposer,
          $$TaskEventsTableCreateCompanionBuilder,
          $$TaskEventsTableUpdateCompanionBuilder,
          (TaskEvent, $$TaskEventsTableReferences),
          TaskEvent,
          PrefetchHooks Function({bool taskId})
        > {
  $$TaskEventsTableTableManager(_$AppDatabase db, $TaskEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskEventsCompanion(
                id: id,
                taskId: taskId,
                type: type,
                occurredAt: occurredAt,
                snoozedUntil: snoozedUntil,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String type,
                required DateTime occurredAt,
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskEventsCompanion.insert(
                id: id,
                taskId: taskId,
                type: type,
                occurredAt: occurredAt,
                snoozedUntil: snoozedUntil,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$TaskEventsTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$TaskEventsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskEventsTable,
      TaskEvent,
      $$TaskEventsTableFilterComposer,
      $$TaskEventsTableOrderingComposer,
      $$TaskEventsTableAnnotationComposer,
      $$TaskEventsTableCreateCompanionBuilder,
      $$TaskEventsTableUpdateCompanionBuilder,
      (TaskEvent, $$TaskEventsTableReferences),
      TaskEvent,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$TestTimerDefaultsTableCreateCompanionBuilder =
    TestTimerDefaultsCompanion Function({
      required String tankId,
      required String parameterId,
      required int durationSeconds,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TestTimerDefaultsTableUpdateCompanionBuilder =
    TestTimerDefaultsCompanion Function({
      Value<String> tankId,
      Value<String> parameterId,
      Value<int> durationSeconds,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TestTimerDefaultsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TestTimerDefaultsTable,
          TestTimerDefault
        > {
  $$TestTimerDefaultsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('test_timer_defaults__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('test_timer_defaults__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TestTimerDefaultsTableFilterComposer
    extends Composer<_$AppDatabase, $TestTimerDefaultsTable> {
  $$TestTimerDefaultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestTimerDefaultsTableOrderingComposer
    extends Composer<_$AppDatabase, $TestTimerDefaultsTable> {
  $$TestTimerDefaultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestTimerDefaultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TestTimerDefaultsTable> {
  $$TestTimerDefaultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TestTimerDefaultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TestTimerDefaultsTable,
          TestTimerDefault,
          $$TestTimerDefaultsTableFilterComposer,
          $$TestTimerDefaultsTableOrderingComposer,
          $$TestTimerDefaultsTableAnnotationComposer,
          $$TestTimerDefaultsTableCreateCompanionBuilder,
          $$TestTimerDefaultsTableUpdateCompanionBuilder,
          (TestTimerDefault, $$TestTimerDefaultsTableReferences),
          TestTimerDefault,
          PrefetchHooks Function({bool tankId, bool parameterId})
        > {
  $$TestTimerDefaultsTableTableManager(
    _$AppDatabase db,
    $TestTimerDefaultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TestTimerDefaultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TestTimerDefaultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TestTimerDefaultsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> tankId = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TestTimerDefaultsCompanion(
                tankId: tankId,
                parameterId: parameterId,
                durationSeconds: durationSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tankId,
                required String parameterId,
                required int durationSeconds,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TestTimerDefaultsCompanion.insert(
                tankId: tankId,
                parameterId: parameterId,
                durationSeconds: durationSeconds,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TestTimerDefaultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tankId = false, parameterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tankId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tankId,
                                referencedTable:
                                    $$TestTimerDefaultsTableReferences
                                        ._tankIdTable(db),
                                referencedColumn:
                                    $$TestTimerDefaultsTableReferences
                                        ._tankIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (parameterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parameterId,
                                referencedTable:
                                    $$TestTimerDefaultsTableReferences
                                        ._parameterIdTable(db),
                                referencedColumn:
                                    $$TestTimerDefaultsTableReferences
                                        ._parameterIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TestTimerDefaultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TestTimerDefaultsTable,
      TestTimerDefault,
      $$TestTimerDefaultsTableFilterComposer,
      $$TestTimerDefaultsTableOrderingComposer,
      $$TestTimerDefaultsTableAnnotationComposer,
      $$TestTimerDefaultsTableCreateCompanionBuilder,
      $$TestTimerDefaultsTableUpdateCompanionBuilder,
      (TestTimerDefault, $$TestTimerDefaultsTableReferences),
      TestTimerDefault,
      PrefetchHooks Function({bool tankId, bool parameterId})
    >;
typedef $$ActiveTestSessionsTableCreateCompanionBuilder =
    ActiveTestSessionsCompanion Function({
      required String id,
      required String tankId,
      required String parameterId,
      Value<String?> reagentProfileId,
      required DateTime startedAt,
      required int timerDurationSeconds,
      Value<DateTime?> timerEndsAt,
      Value<int?> pausedRemainingSeconds,
      Value<String?> draftPhotoPath,
      Value<DateTime?> draftCapturedAt,
      Value<double?> draftEstimatedMinValue,
      Value<double?> draftEstimatedMaxValue,
      Value<String?> draftEstimationMethod,
      Value<String?> draftEstimationVersion,
      Value<double?> draftQualityScore,
      Value<String?> draftConfidence,
      Value<String?> draftFailureReason,
      Value<double?> draftConfirmedMinValue,
      Value<double?> draftConfirmedInterpolation,
      Value<double?> draftEstimatedInterpolation,
      Value<double?> draftConfirmedMaxValue,
      Value<DateTime?> draftConfirmedAt,
      Value<String?> draftNotes,
      required String stage,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ActiveTestSessionsTableUpdateCompanionBuilder =
    ActiveTestSessionsCompanion Function({
      Value<String> id,
      Value<String> tankId,
      Value<String> parameterId,
      Value<String?> reagentProfileId,
      Value<DateTime> startedAt,
      Value<int> timerDurationSeconds,
      Value<DateTime?> timerEndsAt,
      Value<int?> pausedRemainingSeconds,
      Value<String?> draftPhotoPath,
      Value<DateTime?> draftCapturedAt,
      Value<double?> draftEstimatedMinValue,
      Value<double?> draftEstimatedMaxValue,
      Value<String?> draftEstimationMethod,
      Value<String?> draftEstimationVersion,
      Value<double?> draftQualityScore,
      Value<String?> draftConfidence,
      Value<String?> draftFailureReason,
      Value<double?> draftConfirmedMinValue,
      Value<double?> draftConfirmedInterpolation,
      Value<double?> draftEstimatedInterpolation,
      Value<double?> draftConfirmedMaxValue,
      Value<DateTime?> draftConfirmedAt,
      Value<String?> draftNotes,
      Value<String> stage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ActiveTestSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ActiveTestSessionsTable,
          ActiveTestSession
        > {
  $$ActiveTestSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TanksTable _tankIdTable(_$AppDatabase db) =>
      db.tanks.createAlias('active_test_sessions__tank_id__tanks__id');

  $$TanksTableProcessedTableManager get tankId {
    final $_column = $_itemColumn<String>('tank_id')!;

    final manager = $$TanksTableTableManager(
      $_db,
      $_db.tanks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tankIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WaterParametersTable _parameterIdTable(_$AppDatabase db) => db
      .waterParameters
      .createAlias('active_test_sessions__parameter_id__water_parameters__id');

  $$WaterParametersTableProcessedTableManager get parameterId {
    final $_column = $_itemColumn<String>('parameter_id')!;

    final manager = $$WaterParametersTableTableManager(
      $_db,
      $_db.waterParameters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parameterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ReagentProfilesTable _reagentProfileIdTable(_$AppDatabase db) =>
      db.reagentProfiles.createAlias(
        'active_test_sessions__reagent_profile_id__reagent_profiles__id',
      );

  $$ReagentProfilesTableProcessedTableManager? get reagentProfileId {
    final $_column = $_itemColumn<String>('reagent_profile_id');
    if ($_column == null) return null;
    final manager = $$ReagentProfilesTableTableManager(
      $_db,
      $_db.reagentProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reagentProfileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActiveTestSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveTestSessionsTable> {
  $$ActiveTestSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timerDurationSeconds => $composableBuilder(
    column: $table.timerDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timerEndsAt => $composableBuilder(
    column: $table.timerEndsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedRemainingSeconds => $composableBuilder(
    column: $table.pausedRemainingSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftPhotoPath => $composableBuilder(
    column: $table.draftPhotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get draftCapturedAt => $composableBuilder(
    column: $table.draftCapturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftEstimatedMinValue => $composableBuilder(
    column: $table.draftEstimatedMinValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftEstimatedMaxValue => $composableBuilder(
    column: $table.draftEstimatedMaxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftEstimationMethod => $composableBuilder(
    column: $table.draftEstimationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftEstimationVersion => $composableBuilder(
    column: $table.draftEstimationVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftQualityScore => $composableBuilder(
    column: $table.draftQualityScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftConfidence => $composableBuilder(
    column: $table.draftConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftFailureReason => $composableBuilder(
    column: $table.draftFailureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftConfirmedMinValue => $composableBuilder(
    column: $table.draftConfirmedMinValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftConfirmedInterpolation => $composableBuilder(
    column: $table.draftConfirmedInterpolation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftEstimatedInterpolation => $composableBuilder(
    column: $table.draftEstimatedInterpolation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get draftConfirmedMaxValue => $composableBuilder(
    column: $table.draftConfirmedMaxValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get draftConfirmedAt => $composableBuilder(
    column: $table.draftConfirmedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftNotes => $composableBuilder(
    column: $table.draftNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TanksTableFilterComposer get tankId {
    final $$TanksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableFilterComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableFilterComposer get parameterId {
    final $$WaterParametersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableFilterComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableFilterComposer get reagentProfileId {
    final $$ReagentProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableFilterComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveTestSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveTestSessionsTable> {
  $$ActiveTestSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timerDurationSeconds => $composableBuilder(
    column: $table.timerDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timerEndsAt => $composableBuilder(
    column: $table.timerEndsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedRemainingSeconds => $composableBuilder(
    column: $table.pausedRemainingSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftPhotoPath => $composableBuilder(
    column: $table.draftPhotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get draftCapturedAt => $composableBuilder(
    column: $table.draftCapturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftEstimatedMinValue => $composableBuilder(
    column: $table.draftEstimatedMinValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftEstimatedMaxValue => $composableBuilder(
    column: $table.draftEstimatedMaxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftEstimationMethod => $composableBuilder(
    column: $table.draftEstimationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftEstimationVersion => $composableBuilder(
    column: $table.draftEstimationVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftQualityScore => $composableBuilder(
    column: $table.draftQualityScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftConfidence => $composableBuilder(
    column: $table.draftConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftFailureReason => $composableBuilder(
    column: $table.draftFailureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftConfirmedMinValue => $composableBuilder(
    column: $table.draftConfirmedMinValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftConfirmedInterpolation => $composableBuilder(
    column: $table.draftConfirmedInterpolation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftEstimatedInterpolation => $composableBuilder(
    column: $table.draftEstimatedInterpolation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get draftConfirmedMaxValue => $composableBuilder(
    column: $table.draftConfirmedMaxValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get draftConfirmedAt => $composableBuilder(
    column: $table.draftConfirmedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftNotes => $composableBuilder(
    column: $table.draftNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TanksTableOrderingComposer get tankId {
    final $$TanksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableOrderingComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableOrderingComposer get parameterId {
    final $$WaterParametersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableOrderingComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableOrderingComposer get reagentProfileId {
    final $$ReagentProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveTestSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveTestSessionsTable> {
  $$ActiveTestSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get timerDurationSeconds => $composableBuilder(
    column: $table.timerDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timerEndsAt => $composableBuilder(
    column: $table.timerEndsAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedRemainingSeconds => $composableBuilder(
    column: $table.pausedRemainingSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftPhotoPath => $composableBuilder(
    column: $table.draftPhotoPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get draftCapturedAt => $composableBuilder(
    column: $table.draftCapturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftEstimatedMinValue => $composableBuilder(
    column: $table.draftEstimatedMinValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftEstimatedMaxValue => $composableBuilder(
    column: $table.draftEstimatedMaxValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftEstimationMethod => $composableBuilder(
    column: $table.draftEstimationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftEstimationVersion => $composableBuilder(
    column: $table.draftEstimationVersion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftQualityScore => $composableBuilder(
    column: $table.draftQualityScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftConfidence => $composableBuilder(
    column: $table.draftConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftFailureReason => $composableBuilder(
    column: $table.draftFailureReason,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftConfirmedMinValue => $composableBuilder(
    column: $table.draftConfirmedMinValue,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftConfirmedInterpolation => $composableBuilder(
    column: $table.draftConfirmedInterpolation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftEstimatedInterpolation => $composableBuilder(
    column: $table.draftEstimatedInterpolation,
    builder: (column) => column,
  );

  GeneratedColumn<double> get draftConfirmedMaxValue => $composableBuilder(
    column: $table.draftConfirmedMaxValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get draftConfirmedAt => $composableBuilder(
    column: $table.draftConfirmedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get draftNotes => $composableBuilder(
    column: $table.draftNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TanksTableAnnotationComposer get tankId {
    final $$TanksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tankId,
      referencedTable: $db.tanks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TanksTableAnnotationComposer(
            $db: $db,
            $table: $db.tanks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WaterParametersTableAnnotationComposer get parameterId {
    final $$WaterParametersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parameterId,
      referencedTable: $db.waterParameters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WaterParametersTableAnnotationComposer(
            $db: $db,
            $table: $db.waterParameters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ReagentProfilesTableAnnotationComposer get reagentProfileId {
    final $$ReagentProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reagentProfileId,
      referencedTable: $db.reagentProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReagentProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.reagentProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActiveTestSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveTestSessionsTable,
          ActiveTestSession,
          $$ActiveTestSessionsTableFilterComposer,
          $$ActiveTestSessionsTableOrderingComposer,
          $$ActiveTestSessionsTableAnnotationComposer,
          $$ActiveTestSessionsTableCreateCompanionBuilder,
          $$ActiveTestSessionsTableUpdateCompanionBuilder,
          (ActiveTestSession, $$ActiveTestSessionsTableReferences),
          ActiveTestSession,
          PrefetchHooks Function({
            bool tankId,
            bool parameterId,
            bool reagentProfileId,
          })
        > {
  $$ActiveTestSessionsTableTableManager(
    _$AppDatabase db,
    $ActiveTestSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveTestSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveTestSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveTestSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tankId = const Value.absent(),
                Value<String> parameterId = const Value.absent(),
                Value<String?> reagentProfileId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> timerDurationSeconds = const Value.absent(),
                Value<DateTime?> timerEndsAt = const Value.absent(),
                Value<int?> pausedRemainingSeconds = const Value.absent(),
                Value<String?> draftPhotoPath = const Value.absent(),
                Value<DateTime?> draftCapturedAt = const Value.absent(),
                Value<double?> draftEstimatedMinValue = const Value.absent(),
                Value<double?> draftEstimatedMaxValue = const Value.absent(),
                Value<String?> draftEstimationMethod = const Value.absent(),
                Value<String?> draftEstimationVersion = const Value.absent(),
                Value<double?> draftQualityScore = const Value.absent(),
                Value<String?> draftConfidence = const Value.absent(),
                Value<String?> draftFailureReason = const Value.absent(),
                Value<double?> draftConfirmedMinValue = const Value.absent(),
                Value<double?> draftConfirmedInterpolation =
                    const Value.absent(),
                Value<double?> draftEstimatedInterpolation =
                    const Value.absent(),
                Value<double?> draftConfirmedMaxValue = const Value.absent(),
                Value<DateTime?> draftConfirmedAt = const Value.absent(),
                Value<String?> draftNotes = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveTestSessionsCompanion(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                reagentProfileId: reagentProfileId,
                startedAt: startedAt,
                timerDurationSeconds: timerDurationSeconds,
                timerEndsAt: timerEndsAt,
                pausedRemainingSeconds: pausedRemainingSeconds,
                draftPhotoPath: draftPhotoPath,
                draftCapturedAt: draftCapturedAt,
                draftEstimatedMinValue: draftEstimatedMinValue,
                draftEstimatedMaxValue: draftEstimatedMaxValue,
                draftEstimationMethod: draftEstimationMethod,
                draftEstimationVersion: draftEstimationVersion,
                draftQualityScore: draftQualityScore,
                draftConfidence: draftConfidence,
                draftFailureReason: draftFailureReason,
                draftConfirmedMinValue: draftConfirmedMinValue,
                draftConfirmedInterpolation: draftConfirmedInterpolation,
                draftEstimatedInterpolation: draftEstimatedInterpolation,
                draftConfirmedMaxValue: draftConfirmedMaxValue,
                draftConfirmedAt: draftConfirmedAt,
                draftNotes: draftNotes,
                stage: stage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tankId,
                required String parameterId,
                Value<String?> reagentProfileId = const Value.absent(),
                required DateTime startedAt,
                required int timerDurationSeconds,
                Value<DateTime?> timerEndsAt = const Value.absent(),
                Value<int?> pausedRemainingSeconds = const Value.absent(),
                Value<String?> draftPhotoPath = const Value.absent(),
                Value<DateTime?> draftCapturedAt = const Value.absent(),
                Value<double?> draftEstimatedMinValue = const Value.absent(),
                Value<double?> draftEstimatedMaxValue = const Value.absent(),
                Value<String?> draftEstimationMethod = const Value.absent(),
                Value<String?> draftEstimationVersion = const Value.absent(),
                Value<double?> draftQualityScore = const Value.absent(),
                Value<String?> draftConfidence = const Value.absent(),
                Value<String?> draftFailureReason = const Value.absent(),
                Value<double?> draftConfirmedMinValue = const Value.absent(),
                Value<double?> draftConfirmedInterpolation =
                    const Value.absent(),
                Value<double?> draftEstimatedInterpolation =
                    const Value.absent(),
                Value<double?> draftConfirmedMaxValue = const Value.absent(),
                Value<DateTime?> draftConfirmedAt = const Value.absent(),
                Value<String?> draftNotes = const Value.absent(),
                required String stage,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ActiveTestSessionsCompanion.insert(
                id: id,
                tankId: tankId,
                parameterId: parameterId,
                reagentProfileId: reagentProfileId,
                startedAt: startedAt,
                timerDurationSeconds: timerDurationSeconds,
                timerEndsAt: timerEndsAt,
                pausedRemainingSeconds: pausedRemainingSeconds,
                draftPhotoPath: draftPhotoPath,
                draftCapturedAt: draftCapturedAt,
                draftEstimatedMinValue: draftEstimatedMinValue,
                draftEstimatedMaxValue: draftEstimatedMaxValue,
                draftEstimationMethod: draftEstimationMethod,
                draftEstimationVersion: draftEstimationVersion,
                draftQualityScore: draftQualityScore,
                draftConfidence: draftConfidence,
                draftFailureReason: draftFailureReason,
                draftConfirmedMinValue: draftConfirmedMinValue,
                draftConfirmedInterpolation: draftConfirmedInterpolation,
                draftEstimatedInterpolation: draftEstimatedInterpolation,
                draftConfirmedMaxValue: draftConfirmedMaxValue,
                draftConfirmedAt: draftConfirmedAt,
                draftNotes: draftNotes,
                stage: stage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ActiveTestSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tankId = false,
                parameterId = false,
                reagentProfileId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (tankId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tankId,
                                    referencedTable:
                                        $$ActiveTestSessionsTableReferences
                                            ._tankIdTable(db),
                                    referencedColumn:
                                        $$ActiveTestSessionsTableReferences
                                            ._tankIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (parameterId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parameterId,
                                    referencedTable:
                                        $$ActiveTestSessionsTableReferences
                                            ._parameterIdTable(db),
                                    referencedColumn:
                                        $$ActiveTestSessionsTableReferences
                                            ._parameterIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (reagentProfileId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.reagentProfileId,
                                    referencedTable:
                                        $$ActiveTestSessionsTableReferences
                                            ._reagentProfileIdTable(db),
                                    referencedColumn:
                                        $$ActiveTestSessionsTableReferences
                                            ._reagentProfileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$ActiveTestSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveTestSessionsTable,
      ActiveTestSession,
      $$ActiveTestSessionsTableFilterComposer,
      $$ActiveTestSessionsTableOrderingComposer,
      $$ActiveTestSessionsTableAnnotationComposer,
      $$ActiveTestSessionsTableCreateCompanionBuilder,
      $$ActiveTestSessionsTableUpdateCompanionBuilder,
      (ActiveTestSession, $$ActiveTestSessionsTableReferences),
      ActiveTestSession,
      PrefetchHooks Function({
        bool tankId,
        bool parameterId,
        bool reagentProfileId,
      })
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TanksTableTableManager get tanks =>
      $$TanksTableTableManager(_db, _db.tanks);
  $$WaterParametersTableTableManager get waterParameters =>
      $$WaterParametersTableTableManager(_db, _db.waterParameters);
  $$TankParametersTableTableManager get tankParameters =>
      $$TankParametersTableTableManager(_db, _db.tankParameters);
  $$WaterQualityTargetsTableTableManager get waterQualityTargets =>
      $$WaterQualityTargetsTableTableManager(_db, _db.waterQualityTargets);
  $$ReagentProfilesTableTableManager get reagentProfiles =>
      $$ReagentProfilesTableTableManager(_db, _db.reagentProfiles);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$TestRecordsTableTableManager get testRecords =>
      $$TestRecordsTableTableManager(_db, _db.testRecords);
  $$MaintenanceTasksTableTableManager get maintenanceTasks =>
      $$MaintenanceTasksTableTableManager(_db, _db.maintenanceTasks);
  $$MaintenanceCyclesTableTableManager get maintenanceCycles =>
      $$MaintenanceCyclesTableTableManager(_db, _db.maintenanceCycles);
  $$TaskEventsTableTableManager get taskEvents =>
      $$TaskEventsTableTableManager(_db, _db.taskEvents);
  $$TestTimerDefaultsTableTableManager get testTimerDefaults =>
      $$TestTimerDefaultsTableTableManager(_db, _db.testTimerDefaults);
  $$ActiveTestSessionsTableTableManager get activeTestSessions =>
      $$ActiveTestSessionsTableTableManager(_db, _db.activeTestSessions);
}
