// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
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
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final String id;
  final String name;
  final DateTime createdAt;
  const ProfileRow({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProfileRow copyWith({String? id, String? name, DateTime? createdAt}) =>
      ProfileRow(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
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
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesStatesTable extends SeriesStates
    with TableInfo<$SeriesStatesTable, SeriesStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
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
    profileId,
    seriesKey,
    status,
    rating,
    favorite,
    notes,
    startedAt,
    finishedAt,
    lastOpenedAt,
    muted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
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
  Set<GeneratedColumn> get $primaryKey => {profileId, seriesKey};
  @override
  SeriesStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesStateRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SeriesStatesTable createAlias(String alias) {
    return $SeriesStatesTable(attachedDatabase, alias);
  }
}

class SeriesStateRow extends DataClass implements Insertable<SeriesStateRow> {
  final String profileId;
  final String seriesKey;
  final String status;
  final int? rating;
  final bool favorite;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? lastOpenedAt;

  /// Niente notifiche per i capitoli nuovi di questa serie. Il pallino sulla
  /// copertina resta: silenziare è non essere disturbati, non smettere di
  /// sapere.
  final bool muted;
  final DateTime updatedAt;
  const SeriesStateRow({
    required this.profileId,
    required this.seriesKey,
    required this.status,
    this.rating,
    required this.favorite,
    this.notes,
    this.startedAt,
    this.finishedAt,
    this.lastOpenedAt,
    required this.muted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    map['favorite'] = Variable<bool>(favorite);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    map['muted'] = Variable<bool>(muted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SeriesStatesCompanion toCompanion(bool nullToAbsent) {
    return SeriesStatesCompanion(
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      status: Value(status),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      favorite: Value(favorite),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      muted: Value(muted),
      updatedAt: Value(updatedAt),
    );
  }

  factory SeriesStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesStateRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      status: serializer.fromJson<String>(json['status']),
      rating: serializer.fromJson<int?>(json['rating']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      notes: serializer.fromJson<String?>(json['notes']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      muted: serializer.fromJson<bool>(json['muted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'status': serializer.toJson<String>(status),
      'rating': serializer.toJson<int?>(rating),
      'favorite': serializer.toJson<bool>(favorite),
      'notes': serializer.toJson<String?>(notes),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'muted': serializer.toJson<bool>(muted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SeriesStateRow copyWith({
    String? profileId,
    String? seriesKey,
    String? status,
    Value<int?> rating = const Value.absent(),
    bool? favorite,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    bool? muted,
    DateTime? updatedAt,
  }) => SeriesStateRow(
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    status: status ?? this.status,
    rating: rating.present ? rating.value : this.rating,
    favorite: favorite ?? this.favorite,
    notes: notes.present ? notes.value : this.notes,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    muted: muted ?? this.muted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SeriesStateRow copyWithCompanion(SeriesStatesCompanion data) {
    return SeriesStateRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      status: data.status.present ? data.status.value : this.status,
      rating: data.rating.present ? data.rating.value : this.rating,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      notes: data.notes.present ? data.notes.value : this.notes,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      muted: data.muted.present ? data.muted.value : this.muted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesStateRow(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('favorite: $favorite, ')
          ..write('notes: $notes, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('muted: $muted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    seriesKey,
    status,
    rating,
    favorite,
    notes,
    startedAt,
    finishedAt,
    lastOpenedAt,
    muted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesStateRow &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.status == this.status &&
          other.rating == this.rating &&
          other.favorite == this.favorite &&
          other.notes == this.notes &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.muted == this.muted &&
          other.updatedAt == this.updatedAt);
}

class SeriesStatesCompanion extends UpdateCompanion<SeriesStateRow> {
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> status;
  final Value<int?> rating;
  final Value<bool> favorite;
  final Value<String?> notes;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<bool> muted;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SeriesStatesCompanion({
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.favorite = const Value.absent(),
    this.notes = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.muted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesStatesCompanion.insert({
    required String profileId,
    required String seriesKey,
    this.status = const Value.absent(),
    this.rating = const Value.absent(),
    this.favorite = const Value.absent(),
    this.notes = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.muted = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       updatedAt = Value(updatedAt);
  static Insertable<SeriesStateRow> custom({
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? status,
    Expression<int>? rating,
    Expression<bool>? favorite,
    Expression<String>? notes,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<bool>? muted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (status != null) 'status': status,
      if (rating != null) 'rating': rating,
      if (favorite != null) 'favorite': favorite,
      if (notes != null) 'notes': notes,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (muted != null) 'muted': muted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesStatesCompanion copyWith({
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? status,
    Value<int?>? rating,
    Value<bool>? favorite,
    Value<String?>? notes,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<bool>? muted,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SeriesStatesCompanion(
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      favorite: favorite ?? this.favorite,
      notes: notes ?? this.notes,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      muted: muted ?? this.muted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
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
    return (StringBuffer('SeriesStatesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('status: $status, ')
          ..write('rating: $rating, ')
          ..write('favorite: $favorite, ')
          ..write('notes: $notes, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('muted: $muted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterReadsTable extends ChapterReads
    with TableInfo<$ChapterReadsTable, ChapterReadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterReadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedMeta = const VerificationMeta(
    'estimated',
  );
  @override
  late final GeneratedColumn<bool> estimated = GeneratedColumn<bool>(
    'estimated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("estimated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    seriesKey,
    chapterId,
    readAt,
    estimated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_reads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterReadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    if (data.containsKey('estimated')) {
      context.handle(
        _estimatedMeta,
        estimated.isAcceptableOrUnknown(data['estimated']!, _estimatedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, seriesKey, chapterId};
  @override
  ChapterReadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterReadRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      )!,
      estimated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}estimated'],
      )!,
    );
  }

  @override
  $ChapterReadsTable createAlias(String alias) {
    return $ChapterReadsTable(attachedDatabase, alias);
  }
}

class ChapterReadRow extends DataClass implements Insertable<ChapterReadRow> {
  final String profileId;
  final String seriesKey;
  final String chapterId;
  final DateTime readAt;
  final bool estimated;
  const ChapterReadRow({
    required this.profileId,
    required this.seriesKey,
    required this.chapterId,
    required this.readAt,
    required this.estimated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['chapter_id'] = Variable<String>(chapterId);
    map['read_at'] = Variable<DateTime>(readAt);
    map['estimated'] = Variable<bool>(estimated);
    return map;
  }

  ChapterReadsCompanion toCompanion(bool nullToAbsent) {
    return ChapterReadsCompanion(
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      chapterId: Value(chapterId),
      readAt: Value(readAt),
      estimated: Value(estimated),
    );
  }

  factory ChapterReadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterReadRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
      estimated: serializer.fromJson<bool>(json['estimated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'chapterId': serializer.toJson<String>(chapterId),
      'readAt': serializer.toJson<DateTime>(readAt),
      'estimated': serializer.toJson<bool>(estimated),
    };
  }

  ChapterReadRow copyWith({
    String? profileId,
    String? seriesKey,
    String? chapterId,
    DateTime? readAt,
    bool? estimated,
  }) => ChapterReadRow(
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    chapterId: chapterId ?? this.chapterId,
    readAt: readAt ?? this.readAt,
    estimated: estimated ?? this.estimated,
  );
  ChapterReadRow copyWithCompanion(ChapterReadsCompanion data) {
    return ChapterReadRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      estimated: data.estimated.present ? data.estimated.value : this.estimated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterReadRow(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('readAt: $readAt, ')
          ..write('estimated: $estimated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, seriesKey, chapterId, readAt, estimated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterReadRow &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.chapterId == this.chapterId &&
          other.readAt == this.readAt &&
          other.estimated == this.estimated);
}

class ChapterReadsCompanion extends UpdateCompanion<ChapterReadRow> {
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> chapterId;
  final Value<DateTime> readAt;
  final Value<bool> estimated;
  final Value<int> rowid;
  const ChapterReadsCompanion({
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.readAt = const Value.absent(),
    this.estimated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterReadsCompanion.insert({
    required String profileId,
    required String seriesKey,
    required String chapterId,
    required DateTime readAt,
    this.estimated = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       chapterId = Value(chapterId),
       readAt = Value(readAt);
  static Insertable<ChapterReadRow> custom({
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? chapterId,
    Expression<DateTime>? readAt,
    Expression<bool>? estimated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (chapterId != null) 'chapter_id': chapterId,
      if (readAt != null) 'read_at': readAt,
      if (estimated != null) 'estimated': estimated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterReadsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? chapterId,
    Value<DateTime>? readAt,
    Value<bool>? estimated,
    Value<int>? rowid,
  }) {
    return ChapterReadsCompanion(
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      chapterId: chapterId ?? this.chapterId,
      readAt: readAt ?? this.readAt,
      estimated: estimated ?? this.estimated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (estimated.present) {
      map['estimated'] = Variable<bool>(estimated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterReadsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('readAt: $readAt, ')
          ..write('estimated: $estimated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressesTable extends Progresses
    with TableInfo<$ProgressesTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMeta = const VerificationMeta('offset');
  @override
  late final GeneratedColumn<double> offset = GeneratedColumn<double>(
    'offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    profileId,
    seriesKey,
    chapterId,
    page,
    pageCount,
    offset,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('offset')) {
      context.handle(
        _offsetMeta,
        offset.isAcceptableOrUnknown(data['offset']!, _offsetMeta),
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
  Set<GeneratedColumn> get $primaryKey => {profileId, seriesKey, chapterId};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      offset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}offset'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProgressesTable createAlias(String alias) {
    return $ProgressesTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final String profileId;
  final String seriesKey;
  final String chapterId;
  final int page;
  final int pageCount;

  /// Quanto si è già scorso della tavola, da 0 a 1: su un webtoon una tavola
  /// è dieci schermate, e la pagina da sola non è una posizione.
  final double offset;
  final DateTime updatedAt;
  const ProgressRow({
    required this.profileId,
    required this.seriesKey,
    required this.chapterId,
    required this.page,
    required this.pageCount,
    required this.offset,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['chapter_id'] = Variable<String>(chapterId);
    map['page'] = Variable<int>(page);
    map['page_count'] = Variable<int>(pageCount);
    map['offset'] = Variable<double>(offset);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProgressesCompanion toCompanion(bool nullToAbsent) {
    return ProgressesCompanion(
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      chapterId: Value(chapterId),
      page: Value(page),
      pageCount: Value(pageCount),
      offset: Value(offset),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      page: serializer.fromJson<int>(json['page']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      offset: serializer.fromJson<double>(json['offset']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'chapterId': serializer.toJson<String>(chapterId),
      'page': serializer.toJson<int>(page),
      'pageCount': serializer.toJson<int>(pageCount),
      'offset': serializer.toJson<double>(offset),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProgressRow copyWith({
    String? profileId,
    String? seriesKey,
    String? chapterId,
    int? page,
    int? pageCount,
    double? offset,
    DateTime? updatedAt,
  }) => ProgressRow(
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    chapterId: chapterId ?? this.chapterId,
    page: page ?? this.page,
    pageCount: pageCount ?? this.pageCount,
    offset: offset ?? this.offset,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProgressRow copyWithCompanion(ProgressesCompanion data) {
    return ProgressRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      page: data.page.present ? data.page.value : this.page,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      offset: data.offset.present ? data.offset.value : this.offset,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('page: $page, ')
          ..write('pageCount: $pageCount, ')
          ..write('offset: $offset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    seriesKey,
    chapterId,
    page,
    pageCount,
    offset,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.chapterId == this.chapterId &&
          other.page == this.page &&
          other.pageCount == this.pageCount &&
          other.offset == this.offset &&
          other.updatedAt == this.updatedAt);
}

class ProgressesCompanion extends UpdateCompanion<ProgressRow> {
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> chapterId;
  final Value<int> page;
  final Value<int> pageCount;
  final Value<double> offset;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProgressesCompanion({
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.page = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.offset = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressesCompanion.insert({
    required String profileId,
    required String seriesKey,
    required String chapterId,
    required int page,
    required int pageCount,
    this.offset = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       chapterId = Value(chapterId),
       page = Value(page),
       pageCount = Value(pageCount),
       updatedAt = Value(updatedAt);
  static Insertable<ProgressRow> custom({
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? chapterId,
    Expression<int>? page,
    Expression<int>? pageCount,
    Expression<double>? offset,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (chapterId != null) 'chapter_id': chapterId,
      if (page != null) 'page': page,
      if (pageCount != null) 'page_count': pageCount,
      if (offset != null) 'offset': offset,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressesCompanion copyWith({
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? chapterId,
    Value<int>? page,
    Value<int>? pageCount,
    Value<double>? offset,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProgressesCompanion(
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      chapterId: chapterId ?? this.chapterId,
      page: page ?? this.page,
      pageCount: pageCount ?? this.pageCount,
      offset: offset ?? this.offset,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (offset.present) {
      map['offset'] = Variable<double>(offset.value);
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
    return (StringBuffer('ProgressesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('page: $page, ')
          ..write('pageCount: $pageCount, ')
          ..write('offset: $offset, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions
    with TableInfo<$ReadingSessionsTable, ReadingSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pagesReadMeta = const VerificationMeta(
    'pagesRead',
  );
  @override
  late final GeneratedColumn<int> pagesRead = GeneratedColumn<int>(
    'pages_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    seriesKey,
    chapterId,
    startedAt,
    endedAt,
    pagesRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('pages_read')) {
      context.handle(
        _pagesReadMeta,
        pagesRead.isAcceptableOrUnknown(data['pages_read']!, _pagesReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      pagesRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_read'],
      )!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSessionRow extends DataClass
    implements Insertable<ReadingSessionRow> {
  final int id;
  final String profileId;
  final String seriesKey;
  final String chapterId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int pagesRead;
  const ReadingSessionRow({
    required this.id,
    required this.profileId,
    required this.seriesKey,
    required this.chapterId,
    required this.startedAt,
    required this.endedAt,
    required this.pagesRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['chapter_id'] = Variable<String>(chapterId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['pages_read'] = Variable<int>(pagesRead);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      chapterId: Value(chapterId),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      pagesRead: Value(pagesRead),
    );
  }

  factory ReadingSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSessionRow(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      pagesRead: serializer.fromJson<int>(json['pagesRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'chapterId': serializer.toJson<String>(chapterId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'pagesRead': serializer.toJson<int>(pagesRead),
    };
  }

  ReadingSessionRow copyWith({
    int? id,
    String? profileId,
    String? seriesKey,
    String? chapterId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? pagesRead,
  }) => ReadingSessionRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    chapterId: chapterId ?? this.chapterId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    pagesRead: pagesRead ?? this.pagesRead,
  );
  ReadingSessionRow copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSessionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pagesRead: data.pagesRead.present ? data.pagesRead.value : this.pagesRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pagesRead: $pagesRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    seriesKey,
    chapterId,
    startedAt,
    endedAt,
    pagesRead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSessionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.chapterId == this.chapterId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pagesRead == this.pagesRead);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSessionRow> {
  final Value<int> id;
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> chapterId;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> pagesRead;
  const ReadingSessionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pagesRead = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String profileId,
    required String seriesKey,
    required String chapterId,
    required DateTime startedAt,
    required DateTime endedAt,
    this.pagesRead = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       chapterId = Value(chapterId),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt);
  static Insertable<ReadingSessionRow> custom({
    Expression<int>? id,
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? chapterId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? pagesRead,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (chapterId != null) 'chapter_id': chapterId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pagesRead != null) 'pages_read': pagesRead,
    });
  }

  ReadingSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? chapterId,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? pagesRead,
  }) {
    return ReadingSessionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      chapterId: chapterId ?? this.chapterId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pagesRead: pagesRead ?? this.pagesRead,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (pagesRead.present) {
      map['pages_read'] = Variable<int>(pagesRead.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pagesRead: $pagesRead')
          ..write(')'))
        .toString();
  }
}

class $CollectionRowsTable extends CollectionRows
    with TableInfo<$CollectionRowsTable, CollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    profileId,
    name,
    color,
    position,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
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
  CollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CollectionRowsTable createAlias(String alias) {
    return $CollectionRowsTable(attachedDatabase, alias);
  }
}

class CollectionRow extends DataClass implements Insertable<CollectionRow> {
  final String id;
  final String profileId;
  final String name;
  final int? color;
  final int position;
  final DateTime updatedAt;
  const CollectionRow({
    required this.id,
    required this.profileId,
    required this.name,
    this.color,
    required this.position,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['position'] = Variable<int>(position);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CollectionRowsCompanion toCompanion(bool nullToAbsent) {
    return CollectionRowsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      position: Value(position),
      updatedAt: Value(updatedAt),
    );
  }

  factory CollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CollectionRow copyWith({
    String? id,
    String? profileId,
    String? name,
    Value<int?> color = const Value.absent(),
    int? position,
    DateTime? updatedAt,
  }) => CollectionRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CollectionRow copyWithCompanion(CollectionRowsCompanion data) {
    return CollectionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, name, color, position, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.name == this.name &&
          other.color == this.color &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt);
}

class CollectionRowsCompanion extends UpdateCompanion<CollectionRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> name;
  final Value<int?> color;
  final Value<int> position;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CollectionRowsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionRowsCompanion.insert({
    required String id,
    required String profileId,
    required String name,
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<CollectionRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? position,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? name,
    Value<int?>? color,
    Value<int>? position,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CollectionRowsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
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
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
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
    return (StringBuffer('CollectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionItemsTable extends CollectionItems
    with TableInfo<$CollectionItemsTable, CollectionItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _collectionIdMeta = const VerificationMeta(
    'collectionId',
  );
  @override
  late final GeneratedColumn<String> collectionId = GeneratedColumn<String>(
    'collection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES collection_rows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [collectionId, seriesKey, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('collection_id')) {
      context.handle(
        _collectionIdMeta,
        collectionId.isAcceptableOrUnknown(
          data['collection_id']!,
          _collectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {collectionId, seriesKey};
  @override
  CollectionItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionItemRow(
      collectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $CollectionItemsTable createAlias(String alias) {
    return $CollectionItemsTable(attachedDatabase, alias);
  }
}

class CollectionItemRow extends DataClass
    implements Insertable<CollectionItemRow> {
  final String collectionId;
  final String seriesKey;
  final int position;
  const CollectionItemRow({
    required this.collectionId,
    required this.seriesKey,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['collection_id'] = Variable<String>(collectionId);
    map['series_key'] = Variable<String>(seriesKey);
    map['position'] = Variable<int>(position);
    return map;
  }

  CollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return CollectionItemsCompanion(
      collectionId: Value(collectionId),
      seriesKey: Value(seriesKey),
      position: Value(position),
    );
  }

  factory CollectionItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionItemRow(
      collectionId: serializer.fromJson<String>(json['collectionId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'collectionId': serializer.toJson<String>(collectionId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'position': serializer.toJson<int>(position),
    };
  }

  CollectionItemRow copyWith({
    String? collectionId,
    String? seriesKey,
    int? position,
  }) => CollectionItemRow(
    collectionId: collectionId ?? this.collectionId,
    seriesKey: seriesKey ?? this.seriesKey,
    position: position ?? this.position,
  );
  CollectionItemRow copyWithCompanion(CollectionItemsCompanion data) {
    return CollectionItemRow(
      collectionId: data.collectionId.present
          ? data.collectionId.value
          : this.collectionId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemRow(')
          ..write('collectionId: $collectionId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(collectionId, seriesKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionItemRow &&
          other.collectionId == this.collectionId &&
          other.seriesKey == this.seriesKey &&
          other.position == this.position);
}

class CollectionItemsCompanion extends UpdateCompanion<CollectionItemRow> {
  final Value<String> collectionId;
  final Value<String> seriesKey;
  final Value<int> position;
  final Value<int> rowid;
  const CollectionItemsCompanion({
    this.collectionId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectionItemsCompanion.insert({
    required String collectionId,
    required String seriesKey,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : collectionId = Value(collectionId),
       seriesKey = Value(seriesKey);
  static Insertable<CollectionItemRow> custom({
    Expression<String>? collectionId,
    Expression<String>? seriesKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (collectionId != null) 'collection_id': collectionId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectionItemsCompanion copyWith({
    Value<String>? collectionId,
    Value<String>? seriesKey,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return CollectionItemsCompanion(
      collectionId: collectionId ?? this.collectionId,
      seriesKey: seriesKey ?? this.seriesKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (collectionId.present) {
      map['collection_id'] = Variable<String>(collectionId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemsCompanion(')
          ..write('collectionId: $collectionId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageMeta = const VerificationMeta('page');
  @override
  late final GeneratedColumn<int> page = GeneratedColumn<int>(
    'page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    profileId,
    seriesKey,
    chapterId,
    page,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('page')) {
      context.handle(
        _pageMeta,
        page.isAcceptableOrUnknown(data['page']!, _pageMeta),
      );
    } else if (isInserting) {
      context.missing(_pageMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
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
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      )!,
      page: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  final int id;
  final String profileId;
  final String seriesKey;
  final String chapterId;
  final int page;
  final String? note;
  final DateTime createdAt;
  const BookmarkRow({
    required this.id,
    required this.profileId,
    required this.seriesKey,
    required this.chapterId,
    required this.page,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['chapter_id'] = Variable<String>(chapterId);
    map['page'] = Variable<int>(page);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      chapterId: Value(chapterId),
      page: Value(page),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<int>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      page: serializer.fromJson<int>(json['page']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'chapterId': serializer.toJson<String>(chapterId),
      'page': serializer.toJson<int>(page),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarkRow copyWith({
    int? id,
    String? profileId,
    String? seriesKey,
    String? chapterId,
    int? page,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
  }) => BookmarkRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    chapterId: chapterId ?? this.chapterId,
    page: page ?? this.page,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      page: data.page.present ? data.page.value : this.page,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('page: $page, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, profileId, seriesKey, chapterId, page, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.chapterId == this.chapterId &&
          other.page == this.page &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<int> id;
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> chapterId;
  final Value<int> page;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.page = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String profileId,
    required String seriesKey,
    required String chapterId,
    required int page,
    this.note = const Value.absent(),
    required DateTime createdAt,
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       chapterId = Value(chapterId),
       page = Value(page),
       createdAt = Value(createdAt);
  static Insertable<BookmarkRow> custom({
    Expression<int>? id,
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? chapterId,
    Expression<int>? page,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (chapterId != null) 'chapter_id': chapterId,
      if (page != null) 'page': page,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? chapterId,
    Value<int>? page,
    Value<String?>? note,
    Value<DateTime>? createdAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      chapterId: chapterId ?? this.chapterId,
      page: page ?? this.page,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (page.present) {
      map['page'] = Variable<int>(page.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('chapterId: $chapterId, ')
          ..write('page: $page, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReaderSettingsRowsTable extends ReaderSettingsRows
    with TableInfo<$ReaderSettingsRowsTable, ReaderSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReaderSettingsRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fitMeta = const VerificationMeta('fit');
  @override
  late final GeneratedColumn<String> fit = GeneratedColumn<String>(
    'fit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundMeta = const VerificationMeta(
    'background',
  );
  @override
  late final GeneratedColumn<String> background = GeneratedColumn<String>(
    'background',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _brightnessMeta = const VerificationMeta(
    'brightness',
  );
  @override
  late final GeneratedColumn<double> brightness = GeneratedColumn<double>(
    'brightness',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _keepAwakeMeta = const VerificationMeta(
    'keepAwake',
  );
  @override
  late final GeneratedColumn<bool> keepAwake = GeneratedColumn<bool>(
    'keep_awake',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("keep_awake" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _doublePageMeta = const VerificationMeta(
    'doublePage',
  );
  @override
  late final GeneratedColumn<bool> doublePage = GeneratedColumn<bool>(
    'double_page',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("double_page" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _showPageNumberMeta = const VerificationMeta(
    'showPageNumber',
  );
  @override
  late final GeneratedColumn<bool> showPageNumber = GeneratedColumn<bool>(
    'show_page_number',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_page_number" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showProgressMeta = const VerificationMeta(
    'showProgress',
  );
  @override
  late final GeneratedColumn<bool> showProgress = GeneratedColumn<bool>(
    'show_progress',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_progress" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _showScrollTopMeta = const VerificationMeta(
    'showScrollTop',
  );
  @override
  late final GeneratedColumn<bool> showScrollTop = GeneratedColumn<bool>(
    'show_scroll_top',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("show_scroll_top" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _autoScrollMeta = const VerificationMeta(
    'autoScroll',
  );
  @override
  late final GeneratedColumn<double> autoScroll = GeneratedColumn<double>(
    'auto_scroll',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    seriesKey,
    mode,
    direction,
    fit,
    background,
    brightness,
    keepAwake,
    doublePage,
    showPageNumber,
    showProgress,
    showScrollTop,
    autoScroll,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reader_settings_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReaderSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('fit')) {
      context.handle(
        _fitMeta,
        fit.isAcceptableOrUnknown(data['fit']!, _fitMeta),
      );
    } else if (isInserting) {
      context.missing(_fitMeta);
    }
    if (data.containsKey('background')) {
      context.handle(
        _backgroundMeta,
        background.isAcceptableOrUnknown(data['background']!, _backgroundMeta),
      );
    } else if (isInserting) {
      context.missing(_backgroundMeta);
    }
    if (data.containsKey('brightness')) {
      context.handle(
        _brightnessMeta,
        brightness.isAcceptableOrUnknown(data['brightness']!, _brightnessMeta),
      );
    }
    if (data.containsKey('keep_awake')) {
      context.handle(
        _keepAwakeMeta,
        keepAwake.isAcceptableOrUnknown(data['keep_awake']!, _keepAwakeMeta),
      );
    }
    if (data.containsKey('double_page')) {
      context.handle(
        _doublePageMeta,
        doublePage.isAcceptableOrUnknown(data['double_page']!, _doublePageMeta),
      );
    }
    if (data.containsKey('show_page_number')) {
      context.handle(
        _showPageNumberMeta,
        showPageNumber.isAcceptableOrUnknown(
          data['show_page_number']!,
          _showPageNumberMeta,
        ),
      );
    }
    if (data.containsKey('show_progress')) {
      context.handle(
        _showProgressMeta,
        showProgress.isAcceptableOrUnknown(
          data['show_progress']!,
          _showProgressMeta,
        ),
      );
    }
    if (data.containsKey('show_scroll_top')) {
      context.handle(
        _showScrollTopMeta,
        showScrollTop.isAcceptableOrUnknown(
          data['show_scroll_top']!,
          _showScrollTopMeta,
        ),
      );
    }
    if (data.containsKey('auto_scroll')) {
      context.handle(
        _autoScrollMeta,
        autoScroll.isAcceptableOrUnknown(data['auto_scroll']!, _autoScrollMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, seriesKey};
  @override
  ReaderSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReaderSettingsRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      fit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fit'],
      )!,
      background: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background'],
      )!,
      brightness: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}brightness'],
      )!,
      keepAwake: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}keep_awake'],
      )!,
      doublePage: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}double_page'],
      )!,
      showPageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_page_number'],
      )!,
      showProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_progress'],
      )!,
      showScrollTop: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}show_scroll_top'],
      )!,
      autoScroll: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}auto_scroll'],
      )!,
    );
  }

  @override
  $ReaderSettingsRowsTable createAlias(String alias) {
    return $ReaderSettingsRowsTable(attachedDatabase, alias);
  }
}

class ReaderSettingsRow extends DataClass
    implements Insertable<ReaderSettingsRow> {
  final String profileId;
  final String seriesKey;
  final String mode;
  final String direction;
  final String fit;
  final String background;
  final double brightness;
  final bool keepAwake;
  final bool doublePage;
  final bool showPageNumber;

  /// La barra di avanzamento del capitolo e il pulsante che riporta in cima:
  /// utili su una striscia lunga, di troppo su un capitolo di venti tavole.
  final bool showProgress;
  final bool showScrollTop;

  /// Tavole al minuto dello scorrimento automatico, 0 se spento: è il modo in
  /// cui si legge un webtoon senza tenere il dito sullo schermo.
  final double autoScroll;
  const ReaderSettingsRow({
    required this.profileId,
    required this.seriesKey,
    required this.mode,
    required this.direction,
    required this.fit,
    required this.background,
    required this.brightness,
    required this.keepAwake,
    required this.doublePage,
    required this.showPageNumber,
    required this.showProgress,
    required this.showScrollTop,
    required this.autoScroll,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['mode'] = Variable<String>(mode);
    map['direction'] = Variable<String>(direction);
    map['fit'] = Variable<String>(fit);
    map['background'] = Variable<String>(background);
    map['brightness'] = Variable<double>(brightness);
    map['keep_awake'] = Variable<bool>(keepAwake);
    map['double_page'] = Variable<bool>(doublePage);
    map['show_page_number'] = Variable<bool>(showPageNumber);
    map['show_progress'] = Variable<bool>(showProgress);
    map['show_scroll_top'] = Variable<bool>(showScrollTop);
    map['auto_scroll'] = Variable<double>(autoScroll);
    return map;
  }

  ReaderSettingsRowsCompanion toCompanion(bool nullToAbsent) {
    return ReaderSettingsRowsCompanion(
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      mode: Value(mode),
      direction: Value(direction),
      fit: Value(fit),
      background: Value(background),
      brightness: Value(brightness),
      keepAwake: Value(keepAwake),
      doublePage: Value(doublePage),
      showPageNumber: Value(showPageNumber),
      showProgress: Value(showProgress),
      showScrollTop: Value(showScrollTop),
      autoScroll: Value(autoScroll),
    );
  }

  factory ReaderSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReaderSettingsRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      mode: serializer.fromJson<String>(json['mode']),
      direction: serializer.fromJson<String>(json['direction']),
      fit: serializer.fromJson<String>(json['fit']),
      background: serializer.fromJson<String>(json['background']),
      brightness: serializer.fromJson<double>(json['brightness']),
      keepAwake: serializer.fromJson<bool>(json['keepAwake']),
      doublePage: serializer.fromJson<bool>(json['doublePage']),
      showPageNumber: serializer.fromJson<bool>(json['showPageNumber']),
      showProgress: serializer.fromJson<bool>(json['showProgress']),
      showScrollTop: serializer.fromJson<bool>(json['showScrollTop']),
      autoScroll: serializer.fromJson<double>(json['autoScroll']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'mode': serializer.toJson<String>(mode),
      'direction': serializer.toJson<String>(direction),
      'fit': serializer.toJson<String>(fit),
      'background': serializer.toJson<String>(background),
      'brightness': serializer.toJson<double>(brightness),
      'keepAwake': serializer.toJson<bool>(keepAwake),
      'doublePage': serializer.toJson<bool>(doublePage),
      'showPageNumber': serializer.toJson<bool>(showPageNumber),
      'showProgress': serializer.toJson<bool>(showProgress),
      'showScrollTop': serializer.toJson<bool>(showScrollTop),
      'autoScroll': serializer.toJson<double>(autoScroll),
    };
  }

  ReaderSettingsRow copyWith({
    String? profileId,
    String? seriesKey,
    String? mode,
    String? direction,
    String? fit,
    String? background,
    double? brightness,
    bool? keepAwake,
    bool? doublePage,
    bool? showPageNumber,
    bool? showProgress,
    bool? showScrollTop,
    double? autoScroll,
  }) => ReaderSettingsRow(
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    mode: mode ?? this.mode,
    direction: direction ?? this.direction,
    fit: fit ?? this.fit,
    background: background ?? this.background,
    brightness: brightness ?? this.brightness,
    keepAwake: keepAwake ?? this.keepAwake,
    doublePage: doublePage ?? this.doublePage,
    showPageNumber: showPageNumber ?? this.showPageNumber,
    showProgress: showProgress ?? this.showProgress,
    showScrollTop: showScrollTop ?? this.showScrollTop,
    autoScroll: autoScroll ?? this.autoScroll,
  );
  ReaderSettingsRow copyWithCompanion(ReaderSettingsRowsCompanion data) {
    return ReaderSettingsRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      mode: data.mode.present ? data.mode.value : this.mode,
      direction: data.direction.present ? data.direction.value : this.direction,
      fit: data.fit.present ? data.fit.value : this.fit,
      background: data.background.present
          ? data.background.value
          : this.background,
      brightness: data.brightness.present
          ? data.brightness.value
          : this.brightness,
      keepAwake: data.keepAwake.present ? data.keepAwake.value : this.keepAwake,
      doublePage: data.doublePage.present
          ? data.doublePage.value
          : this.doublePage,
      showPageNumber: data.showPageNumber.present
          ? data.showPageNumber.value
          : this.showPageNumber,
      showProgress: data.showProgress.present
          ? data.showProgress.value
          : this.showProgress,
      showScrollTop: data.showScrollTop.present
          ? data.showScrollTop.value
          : this.showScrollTop,
      autoScroll: data.autoScroll.present
          ? data.autoScroll.value
          : this.autoScroll,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReaderSettingsRow(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('mode: $mode, ')
          ..write('direction: $direction, ')
          ..write('fit: $fit, ')
          ..write('background: $background, ')
          ..write('brightness: $brightness, ')
          ..write('keepAwake: $keepAwake, ')
          ..write('doublePage: $doublePage, ')
          ..write('showPageNumber: $showPageNumber, ')
          ..write('showProgress: $showProgress, ')
          ..write('showScrollTop: $showScrollTop, ')
          ..write('autoScroll: $autoScroll')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    seriesKey,
    mode,
    direction,
    fit,
    background,
    brightness,
    keepAwake,
    doublePage,
    showPageNumber,
    showProgress,
    showScrollTop,
    autoScroll,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReaderSettingsRow &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.mode == this.mode &&
          other.direction == this.direction &&
          other.fit == this.fit &&
          other.background == this.background &&
          other.brightness == this.brightness &&
          other.keepAwake == this.keepAwake &&
          other.doublePage == this.doublePage &&
          other.showPageNumber == this.showPageNumber &&
          other.showProgress == this.showProgress &&
          other.showScrollTop == this.showScrollTop &&
          other.autoScroll == this.autoScroll);
}

class ReaderSettingsRowsCompanion extends UpdateCompanion<ReaderSettingsRow> {
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<String> mode;
  final Value<String> direction;
  final Value<String> fit;
  final Value<String> background;
  final Value<double> brightness;
  final Value<bool> keepAwake;
  final Value<bool> doublePage;
  final Value<bool> showPageNumber;
  final Value<bool> showProgress;
  final Value<bool> showScrollTop;
  final Value<double> autoScroll;
  final Value<int> rowid;
  const ReaderSettingsRowsCompanion({
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.mode = const Value.absent(),
    this.direction = const Value.absent(),
    this.fit = const Value.absent(),
    this.background = const Value.absent(),
    this.brightness = const Value.absent(),
    this.keepAwake = const Value.absent(),
    this.doublePage = const Value.absent(),
    this.showPageNumber = const Value.absent(),
    this.showProgress = const Value.absent(),
    this.showScrollTop = const Value.absent(),
    this.autoScroll = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReaderSettingsRowsCompanion.insert({
    required String profileId,
    required String seriesKey,
    required String mode,
    required String direction,
    required String fit,
    required String background,
    this.brightness = const Value.absent(),
    this.keepAwake = const Value.absent(),
    this.doublePage = const Value.absent(),
    this.showPageNumber = const Value.absent(),
    this.showProgress = const Value.absent(),
    this.showScrollTop = const Value.absent(),
    this.autoScroll = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       mode = Value(mode),
       direction = Value(direction),
       fit = Value(fit),
       background = Value(background);
  static Insertable<ReaderSettingsRow> custom({
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<String>? mode,
    Expression<String>? direction,
    Expression<String>? fit,
    Expression<String>? background,
    Expression<double>? brightness,
    Expression<bool>? keepAwake,
    Expression<bool>? doublePage,
    Expression<bool>? showPageNumber,
    Expression<bool>? showProgress,
    Expression<bool>? showScrollTop,
    Expression<double>? autoScroll,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (mode != null) 'mode': mode,
      if (direction != null) 'direction': direction,
      if (fit != null) 'fit': fit,
      if (background != null) 'background': background,
      if (brightness != null) 'brightness': brightness,
      if (keepAwake != null) 'keep_awake': keepAwake,
      if (doublePage != null) 'double_page': doublePage,
      if (showPageNumber != null) 'show_page_number': showPageNumber,
      if (showProgress != null) 'show_progress': showProgress,
      if (showScrollTop != null) 'show_scroll_top': showScrollTop,
      if (autoScroll != null) 'auto_scroll': autoScroll,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReaderSettingsRowsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<String>? mode,
    Value<String>? direction,
    Value<String>? fit,
    Value<String>? background,
    Value<double>? brightness,
    Value<bool>? keepAwake,
    Value<bool>? doublePage,
    Value<bool>? showPageNumber,
    Value<bool>? showProgress,
    Value<bool>? showScrollTop,
    Value<double>? autoScroll,
    Value<int>? rowid,
  }) {
    return ReaderSettingsRowsCompanion(
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      mode: mode ?? this.mode,
      direction: direction ?? this.direction,
      fit: fit ?? this.fit,
      background: background ?? this.background,
      brightness: brightness ?? this.brightness,
      keepAwake: keepAwake ?? this.keepAwake,
      doublePage: doublePage ?? this.doublePage,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      showProgress: showProgress ?? this.showProgress,
      showScrollTop: showScrollTop ?? this.showScrollTop,
      autoScroll: autoScroll ?? this.autoScroll,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (fit.present) {
      map['fit'] = Variable<String>(fit.value);
    }
    if (background.present) {
      map['background'] = Variable<String>(background.value);
    }
    if (brightness.present) {
      map['brightness'] = Variable<double>(brightness.value);
    }
    if (keepAwake.present) {
      map['keep_awake'] = Variable<bool>(keepAwake.value);
    }
    if (doublePage.present) {
      map['double_page'] = Variable<bool>(doublePage.value);
    }
    if (showPageNumber.present) {
      map['show_page_number'] = Variable<bool>(showPageNumber.value);
    }
    if (showProgress.present) {
      map['show_progress'] = Variable<bool>(showProgress.value);
    }
    if (showScrollTop.present) {
      map['show_scroll_top'] = Variable<bool>(showScrollTop.value);
    }
    if (autoScroll.present) {
      map['auto_scroll'] = Variable<double>(autoScroll.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReaderSettingsRowsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('mode: $mode, ')
          ..write('direction: $direction, ')
          ..write('fit: $fit, ')
          ..write('background: $background, ')
          ..write('brightness: $brightness, ')
          ..write('keepAwake: $keepAwake, ')
          ..write('doublePage: $doublePage, ')
          ..write('showPageNumber: $showPageNumber, ')
          ..write('showProgress: $showProgress, ')
          ..write('showScrollTop: $showScrollTop, ')
          ..write('autoScroll: $autoScroll, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
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
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String value;

  /// Quando è stata scritta: fondendo due copie vince la più recente. Senza,
  /// la sincronizzazione d'avvio rimetteva sopra una scelta appena fatta —
  /// la cartella di Drive — il valore vecchio rimasto in rete.
  final DateTime? updatedAt;
  const AppSettingRow({required this.key, required this.value, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  AppSettingRow copyWith({
    String? key,
    String? value,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => AppSettingRow(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesArrivalsTable extends SeriesArrivals
    with TableInfo<$SeriesArrivalsTable, SeriesArrivalRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesArrivalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seriesKeyMeta = const VerificationMeta(
    'seriesKey',
  );
  @override
  late final GeneratedColumn<String> seriesKey = GeneratedColumn<String>(
    'series_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenChaptersMeta = const VerificationMeta(
    'seenChapters',
  );
  @override
  late final GeneratedColumn<int> seenChapters = GeneratedColumn<int>(
    'seen_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notifiedChaptersMeta = const VerificationMeta(
    'notifiedChapters',
  );
  @override
  late final GeneratedColumn<int> notifiedChapters = GeneratedColumn<int>(
    'notified_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    seriesKey,
    seenChapters,
    notifiedChapters,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_arrivals';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesArrivalRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('series_key')) {
      context.handle(
        _seriesKeyMeta,
        seriesKey.isAcceptableOrUnknown(data['series_key']!, _seriesKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_seriesKeyMeta);
    }
    if (data.containsKey('seen_chapters')) {
      context.handle(
        _seenChaptersMeta,
        seenChapters.isAcceptableOrUnknown(
          data['seen_chapters']!,
          _seenChaptersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seenChaptersMeta);
    }
    if (data.containsKey('notified_chapters')) {
      context.handle(
        _notifiedChaptersMeta,
        notifiedChapters.isAcceptableOrUnknown(
          data['notified_chapters']!,
          _notifiedChaptersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_notifiedChaptersMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, seriesKey};
  @override
  SeriesArrivalRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesArrivalRow(
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      seriesKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_key'],
      )!,
      seenChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seen_chapters'],
      )!,
      notifiedChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notified_chapters'],
      )!,
    );
  }

  @override
  $SeriesArrivalsTable createAlias(String alias) {
    return $SeriesArrivalsTable(attachedDatabase, alias);
  }
}

class SeriesArrivalRow extends DataClass
    implements Insertable<SeriesArrivalRow> {
  final String profileId;
  final String seriesKey;

  /// Capitoli archiviati all'ultima apertura della scheda: quelli oltre sono
  /// i nuovi.
  final int seenChapters;

  /// Capitoli archiviati all'ultima notifica: una notifica per arrivo, non
  /// una a ogni rilettura della libreria.
  final int notifiedChapters;
  const SeriesArrivalRow({
    required this.profileId,
    required this.seriesKey,
    required this.seenChapters,
    required this.notifiedChapters,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['series_key'] = Variable<String>(seriesKey);
    map['seen_chapters'] = Variable<int>(seenChapters);
    map['notified_chapters'] = Variable<int>(notifiedChapters);
    return map;
  }

  SeriesArrivalsCompanion toCompanion(bool nullToAbsent) {
    return SeriesArrivalsCompanion(
      profileId: Value(profileId),
      seriesKey: Value(seriesKey),
      seenChapters: Value(seenChapters),
      notifiedChapters: Value(notifiedChapters),
    );
  }

  factory SeriesArrivalRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesArrivalRow(
      profileId: serializer.fromJson<String>(json['profileId']),
      seriesKey: serializer.fromJson<String>(json['seriesKey']),
      seenChapters: serializer.fromJson<int>(json['seenChapters']),
      notifiedChapters: serializer.fromJson<int>(json['notifiedChapters']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'seriesKey': serializer.toJson<String>(seriesKey),
      'seenChapters': serializer.toJson<int>(seenChapters),
      'notifiedChapters': serializer.toJson<int>(notifiedChapters),
    };
  }

  SeriesArrivalRow copyWith({
    String? profileId,
    String? seriesKey,
    int? seenChapters,
    int? notifiedChapters,
  }) => SeriesArrivalRow(
    profileId: profileId ?? this.profileId,
    seriesKey: seriesKey ?? this.seriesKey,
    seenChapters: seenChapters ?? this.seenChapters,
    notifiedChapters: notifiedChapters ?? this.notifiedChapters,
  );
  SeriesArrivalRow copyWithCompanion(SeriesArrivalsCompanion data) {
    return SeriesArrivalRow(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      seriesKey: data.seriesKey.present ? data.seriesKey.value : this.seriesKey,
      seenChapters: data.seenChapters.present
          ? data.seenChapters.value
          : this.seenChapters,
      notifiedChapters: data.notifiedChapters.present
          ? data.notifiedChapters.value
          : this.notifiedChapters,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesArrivalRow(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('seenChapters: $seenChapters, ')
          ..write('notifiedChapters: $notifiedChapters')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(profileId, seriesKey, seenChapters, notifiedChapters);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesArrivalRow &&
          other.profileId == this.profileId &&
          other.seriesKey == this.seriesKey &&
          other.seenChapters == this.seenChapters &&
          other.notifiedChapters == this.notifiedChapters);
}

class SeriesArrivalsCompanion extends UpdateCompanion<SeriesArrivalRow> {
  final Value<String> profileId;
  final Value<String> seriesKey;
  final Value<int> seenChapters;
  final Value<int> notifiedChapters;
  final Value<int> rowid;
  const SeriesArrivalsCompanion({
    this.profileId = const Value.absent(),
    this.seriesKey = const Value.absent(),
    this.seenChapters = const Value.absent(),
    this.notifiedChapters = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesArrivalsCompanion.insert({
    required String profileId,
    required String seriesKey,
    required int seenChapters,
    required int notifiedChapters,
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       seriesKey = Value(seriesKey),
       seenChapters = Value(seenChapters),
       notifiedChapters = Value(notifiedChapters);
  static Insertable<SeriesArrivalRow> custom({
    Expression<String>? profileId,
    Expression<String>? seriesKey,
    Expression<int>? seenChapters,
    Expression<int>? notifiedChapters,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (seriesKey != null) 'series_key': seriesKey,
      if (seenChapters != null) 'seen_chapters': seenChapters,
      if (notifiedChapters != null) 'notified_chapters': notifiedChapters,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesArrivalsCompanion copyWith({
    Value<String>? profileId,
    Value<String>? seriesKey,
    Value<int>? seenChapters,
    Value<int>? notifiedChapters,
    Value<int>? rowid,
  }) {
    return SeriesArrivalsCompanion(
      profileId: profileId ?? this.profileId,
      seriesKey: seriesKey ?? this.seriesKey,
      seenChapters: seenChapters ?? this.seenChapters,
      notifiedChapters: notifiedChapters ?? this.notifiedChapters,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (seriesKey.present) {
      map['series_key'] = Variable<String>(seriesKey.value);
    }
    if (seenChapters.present) {
      map['seen_chapters'] = Variable<int>(seenChapters.value);
    }
    if (notifiedChapters.present) {
      map['notified_chapters'] = Variable<int>(notifiedChapters.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesArrivalsCompanion(')
          ..write('profileId: $profileId, ')
          ..write('seriesKey: $seriesKey, ')
          ..write('seenChapters: $seenChapters, ')
          ..write('notifiedChapters: $notifiedChapters, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KagamiDatabase extends GeneratedDatabase {
  _$KagamiDatabase(QueryExecutor e) : super(e);
  $KagamiDatabaseManager get managers => $KagamiDatabaseManager(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $SeriesStatesTable seriesStates = $SeriesStatesTable(this);
  late final $ChapterReadsTable chapterReads = $ChapterReadsTable(this);
  late final $ProgressesTable progresses = $ProgressesTable(this);
  late final $ReadingSessionsTable readingSessions = $ReadingSessionsTable(
    this,
  );
  late final $CollectionRowsTable collectionRows = $CollectionRowsTable(this);
  late final $CollectionItemsTable collectionItems = $CollectionItemsTable(
    this,
  );
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReaderSettingsRowsTable readerSettingsRows =
      $ReaderSettingsRowsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SeriesArrivalsTable seriesArrivals = $SeriesArrivalsTable(this);
  late final Index chapterReadsReadAt = Index(
    'chapter_reads_read_at',
    'CREATE INDEX chapter_reads_read_at ON chapter_reads (read_at)',
  );
  late final Index chapterReadsSeries = Index(
    'chapter_reads_series',
    'CREATE INDEX chapter_reads_series ON chapter_reads (profile_id, series_key)',
  );
  late final Index readingSessionsStarted = Index(
    'reading_sessions_started',
    'CREATE INDEX reading_sessions_started ON reading_sessions (started_at)',
  );
  late final Index readingSessionsUnique = Index(
    'reading_sessions_unique',
    'CREATE UNIQUE INDEX reading_sessions_unique ON reading_sessions (profile_id, series_key, started_at)',
  );
  late final Index bookmarksUnique = Index(
    'bookmarks_unique',
    'CREATE UNIQUE INDEX bookmarks_unique ON bookmarks (profile_id, series_key, chapter_id, page, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    seriesStates,
    chapterReads,
    progresses,
    readingSessions,
    collectionRows,
    collectionItems,
    bookmarks,
    readerSettingsRows,
    appSettings,
    seriesArrivals,
    chapterReadsReadAt,
    chapterReadsSeries,
    readingSessionsStarted,
    readingSessionsUnique,
    bookmarksUnique,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'collection_rows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('collection_items', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$KagamiDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
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

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$KagamiDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
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

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
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

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$KagamiDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$KagamiDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  BaseReferences<_$KagamiDatabase, $ProfilesTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (
        ProfileRow,
        BaseReferences<_$KagamiDatabase, $ProfilesTable, ProfileRow>,
      ),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$SeriesStatesTableCreateCompanionBuilder =
    SeriesStatesCompanion Function({
      required String profileId,
      required String seriesKey,
      Value<String> status,
      Value<int?> rating,
      Value<bool> favorite,
      Value<String?> notes,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<DateTime?> lastOpenedAt,
      Value<bool> muted,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SeriesStatesTableUpdateCompanionBuilder =
    SeriesStatesCompanion Function({
      Value<String> profileId,
      Value<String> seriesKey,
      Value<String> status,
      Value<int?> rating,
      Value<bool> favorite,
      Value<String?> notes,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<DateTime?> lastOpenedAt,
      Value<bool> muted,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SeriesStatesTableFilterComposer
    extends Composer<_$KagamiDatabase, $SeriesStatesTable> {
  $$SeriesStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeriesStatesTableOrderingComposer
    extends Composer<_$KagamiDatabase, $SeriesStatesTable> {
  $$SeriesStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesStatesTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $SeriesStatesTable> {
  $$SeriesStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SeriesStatesTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $SeriesStatesTable,
          SeriesStateRow,
          $$SeriesStatesTableFilterComposer,
          $$SeriesStatesTableOrderingComposer,
          $$SeriesStatesTableAnnotationComposer,
          $$SeriesStatesTableCreateCompanionBuilder,
          $$SeriesStatesTableUpdateCompanionBuilder,
          (
            SeriesStateRow,
            BaseReferences<
              _$KagamiDatabase,
              $SeriesStatesTable,
              SeriesStateRow
            >,
          ),
          SeriesStateRow,
          PrefetchHooks Function()
        > {
  $$SeriesStatesTableTableManager(_$KagamiDatabase db, $SeriesStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesStatesCompanion(
                profileId: profileId,
                seriesKey: seriesKey,
                status: status,
                rating: rating,
                favorite: favorite,
                notes: notes,
                startedAt: startedAt,
                finishedAt: finishedAt,
                lastOpenedAt: lastOpenedAt,
                muted: muted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String seriesKey,
                Value<String> status = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SeriesStatesCompanion.insert(
                profileId: profileId,
                seriesKey: seriesKey,
                status: status,
                rating: rating,
                favorite: favorite,
                notes: notes,
                startedAt: startedAt,
                finishedAt: finishedAt,
                lastOpenedAt: lastOpenedAt,
                muted: muted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesStatesTable, SeriesStateRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $SeriesStatesTable,
                    SeriesStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $SeriesStatesTable,
      SeriesStateRow,
      $$SeriesStatesTableFilterComposer,
      $$SeriesStatesTableOrderingComposer,
      $$SeriesStatesTableAnnotationComposer,
      $$SeriesStatesTableCreateCompanionBuilder,
      $$SeriesStatesTableUpdateCompanionBuilder,
      (
        SeriesStateRow,
        BaseReferences<_$KagamiDatabase, $SeriesStatesTable, SeriesStateRow>,
      ),
      SeriesStateRow,
      PrefetchHooks Function()
    >;
typedef $$ChapterReadsTableCreateCompanionBuilder =
    ChapterReadsCompanion Function({
      required String profileId,
      required String seriesKey,
      required String chapterId,
      required DateTime readAt,
      Value<bool> estimated,
      Value<int> rowid,
    });
typedef $$ChapterReadsTableUpdateCompanionBuilder =
    ChapterReadsCompanion Function({
      Value<String> profileId,
      Value<String> seriesKey,
      Value<String> chapterId,
      Value<DateTime> readAt,
      Value<bool> estimated,
      Value<int> rowid,
    });

class $$ChapterReadsTableFilterComposer
    extends Composer<_$KagamiDatabase, $ChapterReadsTable> {
  $$ChapterReadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChapterReadsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $ChapterReadsTable> {
  $$ChapterReadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChapterReadsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $ChapterReadsTable> {
  $$ChapterReadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<bool> get estimated =>
      $composableBuilder(column: $table.estimated, builder: (column) => column);
}

class $$ChapterReadsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $ChapterReadsTable,
          ChapterReadRow,
          $$ChapterReadsTableFilterComposer,
          $$ChapterReadsTableOrderingComposer,
          $$ChapterReadsTableAnnotationComposer,
          $$ChapterReadsTableCreateCompanionBuilder,
          $$ChapterReadsTableUpdateCompanionBuilder,
          (
            ChapterReadRow,
            BaseReferences<
              _$KagamiDatabase,
              $ChapterReadsTable,
              ChapterReadRow
            >,
          ),
          ChapterReadRow,
          PrefetchHooks Function()
        > {
  $$ChapterReadsTableTableManager(_$KagamiDatabase db, $ChapterReadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChapterReadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChapterReadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChapterReadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<DateTime> readAt = const Value.absent(),
                Value<bool> estimated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterReadsCompanion(
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                readAt: readAt,
                estimated: estimated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String seriesKey,
                required String chapterId,
                required DateTime readAt,
                Value<bool> estimated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterReadsCompanion.insert(
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                readAt: readAt,
                estimated: estimated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChapterReadsTable, ChapterReadRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $ChapterReadsTable,
                    ChapterReadRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChapterReadsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $ChapterReadsTable,
      ChapterReadRow,
      $$ChapterReadsTableFilterComposer,
      $$ChapterReadsTableOrderingComposer,
      $$ChapterReadsTableAnnotationComposer,
      $$ChapterReadsTableCreateCompanionBuilder,
      $$ChapterReadsTableUpdateCompanionBuilder,
      (
        ChapterReadRow,
        BaseReferences<_$KagamiDatabase, $ChapterReadsTable, ChapterReadRow>,
      ),
      ChapterReadRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressesTableCreateCompanionBuilder = ProgressesCompanion Function({
  required String profileId,
  required String seriesKey,
  required String chapterId,
  required int page,
  required int pageCount,
  Value<double> offset,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$ProgressesTableUpdateCompanionBuilder = ProgressesCompanion Function({
  Value<String> profileId,
  Value<String> seriesKey,
  Value<String> chapterId,
  Value<int> page,
  Value<int> pageCount,
  Value<double> offset,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$ProgressesTableFilterComposer
    extends Composer<_$KagamiDatabase, $ProgressesTable> {
  $$ProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressesTableOrderingComposer
    extends Composer<_$KagamiDatabase, $ProgressesTable> {
  $$ProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressesTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $ProgressesTable> {
  $$ProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<double> get offset =>
      $composableBuilder(column: $table.offset, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProgressesTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $ProgressesTable,
          ProgressRow,
          $$ProgressesTableFilterComposer,
          $$ProgressesTableOrderingComposer,
          $$ProgressesTableAnnotationComposer,
          $$ProgressesTableCreateCompanionBuilder,
          $$ProgressesTableUpdateCompanionBuilder,
          (
            ProgressRow,
            BaseReferences<_$KagamiDatabase, $ProgressesTable, ProgressRow>,
          ),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $$ProgressesTableTableManager(_$KagamiDatabase db, $ProgressesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<double> offset = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressesCompanion(
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                page: page,
                pageCount: pageCount,
                offset: offset,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String seriesKey,
                required String chapterId,
                required int page,
                required int pageCount,
                Value<double> offset = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgressesCompanion.insert(
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                page: page,
                pageCount: pageCount,
                offset: offset,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProgressesTable, ProgressRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $ProgressesTable,
                    ProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $ProgressesTable,
      ProgressRow,
      $$ProgressesTableFilterComposer,
      $$ProgressesTableOrderingComposer,
      $$ProgressesTableAnnotationComposer,
      $$ProgressesTableCreateCompanionBuilder,
      $$ProgressesTableUpdateCompanionBuilder,
      (
        ProgressRow,
        BaseReferences<_$KagamiDatabase, $ProgressesTable, ProgressRow>,
      ),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingSessionsTableCreateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      required String profileId,
      required String seriesKey,
      required String chapterId,
      required DateTime startedAt,
      required DateTime endedAt,
      Value<int> pagesRead,
    });
typedef $$ReadingSessionsTableUpdateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<int> id,
      Value<String> profileId,
      Value<String> seriesKey,
      Value<String> chapterId,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> pagesRead,
    });

class $$ReadingSessionsTableFilterComposer
    extends Composer<_$KagamiDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingSessionsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingSessionsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get pagesRead =>
      $composableBuilder(column: $table.pagesRead, builder: (column) => column);
}

class $$ReadingSessionsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $ReadingSessionsTable,
          ReadingSessionRow,
          $$ReadingSessionsTableFilterComposer,
          $$ReadingSessionsTableOrderingComposer,
          $$ReadingSessionsTableAnnotationComposer,
          $$ReadingSessionsTableCreateCompanionBuilder,
          $$ReadingSessionsTableUpdateCompanionBuilder,
          (
            ReadingSessionRow,
            BaseReferences<
              _$KagamiDatabase,
              $ReadingSessionsTable,
              ReadingSessionRow
            >,
          ),
          ReadingSessionRow,
          PrefetchHooks Function()
        > {
  $$ReadingSessionsTableTableManager(
    _$KagamiDatabase db,
    $ReadingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
              }) => ReadingSessionsCompanion(
                id: id,
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                startedAt: startedAt,
                endedAt: endedAt,
                pagesRead: pagesRead,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String profileId,
                required String seriesKey,
                required String chapterId,
                required DateTime startedAt,
                required DateTime endedAt,
                Value<int> pagesRead = const Value.absent(),
              }) => ReadingSessionsCompanion.insert(
                id: id,
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                startedAt: startedAt,
                endedAt: endedAt,
                pagesRead: pagesRead,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingSessionsTable, ReadingSessionRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $ReadingSessionsTable,
                    ReadingSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $ReadingSessionsTable,
      ReadingSessionRow,
      $$ReadingSessionsTableFilterComposer,
      $$ReadingSessionsTableOrderingComposer,
      $$ReadingSessionsTableAnnotationComposer,
      $$ReadingSessionsTableCreateCompanionBuilder,
      $$ReadingSessionsTableUpdateCompanionBuilder,
      (
        ReadingSessionRow,
        BaseReferences<
          _$KagamiDatabase,
          $ReadingSessionsTable,
          ReadingSessionRow
        >,
      ),
      ReadingSessionRow,
      PrefetchHooks Function()
    >;
typedef $$CollectionRowsTableCreateCompanionBuilder =
    CollectionRowsCompanion Function({
      required String id,
      required String profileId,
      required String name,
      Value<int?> color,
      Value<int> position,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CollectionRowsTableUpdateCompanionBuilder =
    CollectionRowsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> name,
      Value<int?> color,
      Value<int> position,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$CollectionRowsTableReferences
    extends
        BaseReferences<_$KagamiDatabase, $CollectionRowsTable, CollectionRow> {
  $$CollectionRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$CollectionItemsTable, List<CollectionItemRow>>
  _collectionItemsRefsTable(_$KagamiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.collectionItems,
        aliasName: 'collection_rows__id__collection_items__collection_id',
      );

  $$CollectionItemsTableProcessedTableManager get collectionItemsRefs {
    final manager = $$CollectionItemsTableTableManager(
      $_db,
      $_db.collectionItems,
    ).filter((f) => f.collectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CollectionRowsTableFilterComposer
    extends Composer<_$KagamiDatabase, $CollectionRowsTable> {
  $$CollectionRowsTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionItemsRefs(
    Expression<bool> Function($$CollectionItemsTableFilterComposer f) f,
  ) {
    final $$CollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionRowsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $CollectionRowsTable> {
  $$CollectionRowsTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CollectionRowsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $CollectionRowsTable> {
  $$CollectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> collectionItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.collectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CollectionRowsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $CollectionRowsTable,
          CollectionRow,
          $$CollectionRowsTableFilterComposer,
          $$CollectionRowsTableOrderingComposer,
          $$CollectionRowsTableAnnotationComposer,
          $$CollectionRowsTableCreateCompanionBuilder,
          $$CollectionRowsTableUpdateCompanionBuilder,
          (CollectionRow, $$CollectionRowsTableReferences),
          CollectionRow,
          PrefetchHooks Function({bool collectionItemsRefs})
        > {
  $$CollectionRowsTableTableManager(
    _$KagamiDatabase db,
    $CollectionRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionRowsCompanion(
                id: id,
                profileId: profileId,
                name: name,
                color: color,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String name,
                Value<int?> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CollectionRowsCompanion.insert(
                id: id,
                profileId: profileId,
                name: name,
                color: color,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionRowsTable, CollectionRow>(table),
                  $$CollectionRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (collectionItemsRefs) db.collectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (collectionItemsRefs)
                    await $_getPrefetchedData<
                      CollectionRow,
                      $CollectionRowsTable,
                      CollectionItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$CollectionRowsTableReferences
                          ._collectionItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CollectionRowsTableReferences(
                            db,
                            table,
                            p0,
                          ).collectionItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.collectionId == item.id,
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

typedef $$CollectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $CollectionRowsTable,
      CollectionRow,
      $$CollectionRowsTableFilterComposer,
      $$CollectionRowsTableOrderingComposer,
      $$CollectionRowsTableAnnotationComposer,
      $$CollectionRowsTableCreateCompanionBuilder,
      $$CollectionRowsTableUpdateCompanionBuilder,
      (CollectionRow, $$CollectionRowsTableReferences),
      CollectionRow,
      PrefetchHooks Function({bool collectionItemsRefs})
    >;
typedef $$CollectionItemsTableCreateCompanionBuilder =
    CollectionItemsCompanion Function({
      required String collectionId,
      required String seriesKey,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$CollectionItemsTableUpdateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<String> collectionId,
      Value<String> seriesKey,
      Value<int> position,
      Value<int> rowid,
    });

final class $$CollectionItemsTableReferences
    extends
        BaseReferences<
          _$KagamiDatabase,
          $CollectionItemsTable,
          CollectionItemRow
        > {
  $$CollectionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CollectionRowsTable _collectionIdTable(_$KagamiDatabase db) => db
      .collectionRows
      .createAlias('collection_items__collection_id__collection_rows__id');

  $$CollectionRowsTableProcessedTableManager get collectionId {
    final $_column = $_itemColumn<String>('collection_id')!;

    final manager = $$CollectionRowsTableTableManager(
      $_db,
      $_db.collectionRows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_collectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CollectionItemsTableFilterComposer
    extends Composer<_$KagamiDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$CollectionRowsTableFilterComposer get collectionId {
    final $$CollectionRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionRowsTableFilterComposer(
            $db: $db,
            $table: $db.collectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$CollectionRowsTableOrderingComposer get collectionId {
    final $$CollectionRowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionRowsTableOrderingComposer(
            $db: $db,
            $table: $db.collectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$CollectionRowsTableAnnotationComposer get collectionId {
    final $$CollectionRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.collectionId,
      referencedTable: $db.collectionRows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $CollectionItemsTable,
          CollectionItemRow,
          $$CollectionItemsTableFilterComposer,
          $$CollectionItemsTableOrderingComposer,
          $$CollectionItemsTableAnnotationComposer,
          $$CollectionItemsTableCreateCompanionBuilder,
          $$CollectionItemsTableUpdateCompanionBuilder,
          (CollectionItemRow, $$CollectionItemsTableReferences),
          CollectionItemRow,
          PrefetchHooks Function({bool collectionId})
        > {
  $$CollectionItemsTableTableManager(
    _$KagamiDatabase db,
    $CollectionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> collectionId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionItemsCompanion(
                collectionId: collectionId,
                seriesKey: seriesKey,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String collectionId,
                required String seriesKey,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CollectionItemsCompanion.insert(
                collectionId: collectionId,
                seriesKey: seriesKey,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionItemsTable, CollectionItemRow>(table),
                  $$CollectionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionId = false}) {
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
                    if (collectionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.collectionId,
                        referencedTable: $$CollectionItemsTableReferences
                            ._collectionIdTable(db),
                        referencedColumn: $$CollectionItemsTableReferences
                            ._collectionIdTable(db)
                            .id,
                      ) as T;
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

typedef $$CollectionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $CollectionItemsTable,
      CollectionItemRow,
      $$CollectionItemsTableFilterComposer,
      $$CollectionItemsTableOrderingComposer,
      $$CollectionItemsTableAnnotationComposer,
      $$CollectionItemsTableCreateCompanionBuilder,
      $$CollectionItemsTableUpdateCompanionBuilder,
      (CollectionItemRow, $$CollectionItemsTableReferences),
      CollectionItemRow,
      PrefetchHooks Function({bool collectionId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  required String profileId,
  required String seriesKey,
  required String chapterId,
  required int page,
  Value<String?> note,
  required DateTime createdAt,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  Value<String> profileId,
  Value<String> seriesKey,
  Value<String> chapterId,
  Value<int> page,
  Value<String?> note,
  Value<DateTime> createdAt,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$KagamiDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$KagamiDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get page => $composableBuilder(
    column: $table.page,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get page =>
      $composableBuilder(column: $table.page, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$KagamiDatabase, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$KagamiDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> page = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                page: page,
                note: note,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String profileId,
                required String seriesKey,
                required String chapterId,
                required int page,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
              }) => BookmarksCompanion.insert(
                id: id,
                profileId: profileId,
                seriesKey: seriesKey,
                chapterId: chapterId,
                page: page,
                note: note,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, BookmarkRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $BookmarksTable,
                    BookmarkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$KagamiDatabase, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;
typedef $$ReaderSettingsRowsTableCreateCompanionBuilder =
    ReaderSettingsRowsCompanion Function({
      required String profileId,
      required String seriesKey,
      required String mode,
      required String direction,
      required String fit,
      required String background,
      Value<double> brightness,
      Value<bool> keepAwake,
      Value<bool> doublePage,
      Value<bool> showPageNumber,
      Value<bool> showProgress,
      Value<bool> showScrollTop,
      Value<double> autoScroll,
      Value<int> rowid,
    });
typedef $$ReaderSettingsRowsTableUpdateCompanionBuilder =
    ReaderSettingsRowsCompanion Function({
      Value<String> profileId,
      Value<String> seriesKey,
      Value<String> mode,
      Value<String> direction,
      Value<String> fit,
      Value<String> background,
      Value<double> brightness,
      Value<bool> keepAwake,
      Value<bool> doublePage,
      Value<bool> showPageNumber,
      Value<bool> showProgress,
      Value<bool> showScrollTop,
      Value<double> autoScroll,
      Value<int> rowid,
    });

class $$ReaderSettingsRowsTableFilterComposer
    extends Composer<_$KagamiDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fit => $composableBuilder(
    column: $table.fit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get brightness => $composableBuilder(
    column: $table.brightness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get keepAwake => $composableBuilder(
    column: $table.keepAwake,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get doublePage => $composableBuilder(
    column: $table.doublePage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showPageNumber => $composableBuilder(
    column: $table.showPageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showProgress => $composableBuilder(
    column: $table.showProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get showScrollTop => $composableBuilder(
    column: $table.showScrollTop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get autoScroll => $composableBuilder(
    column: $table.autoScroll,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReaderSettingsRowsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fit => $composableBuilder(
    column: $table.fit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get brightness => $composableBuilder(
    column: $table.brightness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get keepAwake => $composableBuilder(
    column: $table.keepAwake,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get doublePage => $composableBuilder(
    column: $table.doublePage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showPageNumber => $composableBuilder(
    column: $table.showPageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showProgress => $composableBuilder(
    column: $table.showProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get showScrollTop => $composableBuilder(
    column: $table.showScrollTop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get autoScroll => $composableBuilder(
    column: $table.autoScroll,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReaderSettingsRowsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $ReaderSettingsRowsTable> {
  $$ReaderSettingsRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get fit =>
      $composableBuilder(column: $table.fit, builder: (column) => column);

  GeneratedColumn<String> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => column,
  );

  GeneratedColumn<double> get brightness => $composableBuilder(
    column: $table.brightness,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get keepAwake =>
      $composableBuilder(column: $table.keepAwake, builder: (column) => column);

  GeneratedColumn<bool> get doublePage => $composableBuilder(
    column: $table.doublePage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showPageNumber => $composableBuilder(
    column: $table.showPageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showProgress => $composableBuilder(
    column: $table.showProgress,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get showScrollTop => $composableBuilder(
    column: $table.showScrollTop,
    builder: (column) => column,
  );

  GeneratedColumn<double> get autoScroll => $composableBuilder(
    column: $table.autoScroll,
    builder: (column) => column,
  );
}

class $$ReaderSettingsRowsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $ReaderSettingsRowsTable,
          ReaderSettingsRow,
          $$ReaderSettingsRowsTableFilterComposer,
          $$ReaderSettingsRowsTableOrderingComposer,
          $$ReaderSettingsRowsTableAnnotationComposer,
          $$ReaderSettingsRowsTableCreateCompanionBuilder,
          $$ReaderSettingsRowsTableUpdateCompanionBuilder,
          (
            ReaderSettingsRow,
            BaseReferences<
              _$KagamiDatabase,
              $ReaderSettingsRowsTable,
              ReaderSettingsRow
            >,
          ),
          ReaderSettingsRow,
          PrefetchHooks Function()
        > {
  $$ReaderSettingsRowsTableTableManager(
    _$KagamiDatabase db,
    $ReaderSettingsRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReaderSettingsRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReaderSettingsRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReaderSettingsRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> fit = const Value.absent(),
                Value<String> background = const Value.absent(),
                Value<double> brightness = const Value.absent(),
                Value<bool> keepAwake = const Value.absent(),
                Value<bool> doublePage = const Value.absent(),
                Value<bool> showPageNumber = const Value.absent(),
                Value<bool> showProgress = const Value.absent(),
                Value<bool> showScrollTop = const Value.absent(),
                Value<double> autoScroll = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderSettingsRowsCompanion(
                profileId: profileId,
                seriesKey: seriesKey,
                mode: mode,
                direction: direction,
                fit: fit,
                background: background,
                brightness: brightness,
                keepAwake: keepAwake,
                doublePage: doublePage,
                showPageNumber: showPageNumber,
                showProgress: showProgress,
                showScrollTop: showScrollTop,
                autoScroll: autoScroll,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String seriesKey,
                required String mode,
                required String direction,
                required String fit,
                required String background,
                Value<double> brightness = const Value.absent(),
                Value<bool> keepAwake = const Value.absent(),
                Value<bool> doublePage = const Value.absent(),
                Value<bool> showPageNumber = const Value.absent(),
                Value<bool> showProgress = const Value.absent(),
                Value<bool> showScrollTop = const Value.absent(),
                Value<double> autoScroll = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReaderSettingsRowsCompanion.insert(
                profileId: profileId,
                seriesKey: seriesKey,
                mode: mode,
                direction: direction,
                fit: fit,
                background: background,
                brightness: brightness,
                keepAwake: keepAwake,
                doublePage: doublePage,
                showPageNumber: showPageNumber,
                showProgress: showProgress,
                showScrollTop: showScrollTop,
                autoScroll: autoScroll,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReaderSettingsRowsTable, ReaderSettingsRow>(
                    table,
                  ),
                  BaseReferences<
                    _$KagamiDatabase,
                    $ReaderSettingsRowsTable,
                    ReaderSettingsRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReaderSettingsRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $ReaderSettingsRowsTable,
      ReaderSettingsRow,
      $$ReaderSettingsRowsTableFilterComposer,
      $$ReaderSettingsRowsTableOrderingComposer,
      $$ReaderSettingsRowsTableAnnotationComposer,
      $$ReaderSettingsRowsTableCreateCompanionBuilder,
      $$ReaderSettingsRowsTableUpdateCompanionBuilder,
      (
        ReaderSettingsRow,
        BaseReferences<
          _$KagamiDatabase,
          $ReaderSettingsRowsTable,
          ReaderSettingsRow
        >,
      ),
      ReaderSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$KagamiDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$KagamiDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$KagamiDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSettingRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $AppSettingsTable,
                    AppSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$KagamiDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$SeriesArrivalsTableCreateCompanionBuilder =
    SeriesArrivalsCompanion Function({
      required String profileId,
      required String seriesKey,
      required int seenChapters,
      required int notifiedChapters,
      Value<int> rowid,
    });
typedef $$SeriesArrivalsTableUpdateCompanionBuilder =
    SeriesArrivalsCompanion Function({
      Value<String> profileId,
      Value<String> seriesKey,
      Value<int> seenChapters,
      Value<int> notifiedChapters,
      Value<int> rowid,
    });

class $$SeriesArrivalsTableFilterComposer
    extends Composer<_$KagamiDatabase, $SeriesArrivalsTable> {
  $$SeriesArrivalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seenChapters => $composableBuilder(
    column: $table.seenChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notifiedChapters => $composableBuilder(
    column: $table.notifiedChapters,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeriesArrivalsTableOrderingComposer
    extends Composer<_$KagamiDatabase, $SeriesArrivalsTable> {
  $$SeriesArrivalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesKey => $composableBuilder(
    column: $table.seriesKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seenChapters => $composableBuilder(
    column: $table.seenChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notifiedChapters => $composableBuilder(
    column: $table.notifiedChapters,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesArrivalsTableAnnotationComposer
    extends Composer<_$KagamiDatabase, $SeriesArrivalsTable> {
  $$SeriesArrivalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get seriesKey =>
      $composableBuilder(column: $table.seriesKey, builder: (column) => column);

  GeneratedColumn<int> get seenChapters => $composableBuilder(
    column: $table.seenChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notifiedChapters => $composableBuilder(
    column: $table.notifiedChapters,
    builder: (column) => column,
  );
}

class $$SeriesArrivalsTableTableManager
    extends
        RootTableManager<
          _$KagamiDatabase,
          $SeriesArrivalsTable,
          SeriesArrivalRow,
          $$SeriesArrivalsTableFilterComposer,
          $$SeriesArrivalsTableOrderingComposer,
          $$SeriesArrivalsTableAnnotationComposer,
          $$SeriesArrivalsTableCreateCompanionBuilder,
          $$SeriesArrivalsTableUpdateCompanionBuilder,
          (
            SeriesArrivalRow,
            BaseReferences<
              _$KagamiDatabase,
              $SeriesArrivalsTable,
              SeriesArrivalRow
            >,
          ),
          SeriesArrivalRow,
          PrefetchHooks Function()
        > {
  $$SeriesArrivalsTableTableManager(
    _$KagamiDatabase db,
    $SeriesArrivalsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesArrivalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesArrivalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesArrivalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> seriesKey = const Value.absent(),
                Value<int> seenChapters = const Value.absent(),
                Value<int> notifiedChapters = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesArrivalsCompanion(
                profileId: profileId,
                seriesKey: seriesKey,
                seenChapters: seenChapters,
                notifiedChapters: notifiedChapters,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String seriesKey,
                required int seenChapters,
                required int notifiedChapters,
                Value<int> rowid = const Value.absent(),
              }) => SeriesArrivalsCompanion.insert(
                profileId: profileId,
                seriesKey: seriesKey,
                seenChapters: seenChapters,
                notifiedChapters: notifiedChapters,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesArrivalsTable, SeriesArrivalRow>(table),
                  BaseReferences<
                    _$KagamiDatabase,
                    $SeriesArrivalsTable,
                    SeriesArrivalRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesArrivalsTableProcessedTableManager =
    ProcessedTableManager<
      _$KagamiDatabase,
      $SeriesArrivalsTable,
      SeriesArrivalRow,
      $$SeriesArrivalsTableFilterComposer,
      $$SeriesArrivalsTableOrderingComposer,
      $$SeriesArrivalsTableAnnotationComposer,
      $$SeriesArrivalsTableCreateCompanionBuilder,
      $$SeriesArrivalsTableUpdateCompanionBuilder,
      (
        SeriesArrivalRow,
        BaseReferences<
          _$KagamiDatabase,
          $SeriesArrivalsTable,
          SeriesArrivalRow
        >,
      ),
      SeriesArrivalRow,
      PrefetchHooks Function()
    >;

class $KagamiDatabaseManager {
  final _$KagamiDatabase _db;
  $KagamiDatabaseManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$SeriesStatesTableTableManager get seriesStates =>
      $$SeriesStatesTableTableManager(_db, _db.seriesStates);
  $$ChapterReadsTableTableManager get chapterReads =>
      $$ChapterReadsTableTableManager(_db, _db.chapterReads);
  $$ProgressesTableTableManager get progresses =>
      $$ProgressesTableTableManager(_db, _db.progresses);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
  $$CollectionRowsTableTableManager get collectionRows =>
      $$CollectionRowsTableTableManager(_db, _db.collectionRows);
  $$CollectionItemsTableTableManager get collectionItems =>
      $$CollectionItemsTableTableManager(_db, _db.collectionItems);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReaderSettingsRowsTableTableManager get readerSettingsRows =>
      $$ReaderSettingsRowsTableTableManager(_db, _db.readerSettingsRows);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SeriesArrivalsTableTableManager get seriesArrivals =>
      $$SeriesArrivalsTableTableManager(_db, _db.seriesArrivals);
}
