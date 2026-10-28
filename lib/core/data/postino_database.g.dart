// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'postino_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts
    with TableInfo<$AccountsTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ProviderKind, String> provider =
      GeneratedColumn<String>(
        'provider',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ProviderKind>($AccountsTable.$converterprovider);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountStatus>($AccountsTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    address,
    provider,
    color,
    position,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
      provider: $AccountsTable.$converterprovider.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}provider'],
        )!,
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      status: $AccountsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ProviderKind, String, String> $converterprovider =
      const EnumNameConverter<ProviderKind>(ProviderKind.values);
  static JsonTypeConverter2<AccountStatus, String, String> $converterstatus =
      const EnumNameConverter<AccountStatus>(AccountStatus.values);
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  final String id;
  final String address;
  final ProviderKind provider;
  final int color;
  final int position;
  final AccountStatus status;
  const AccountRow({
    required this.id,
    required this.address,
    required this.provider,
    required this.color,
    required this.position,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['address'] = Variable<String>(address);
    {
      map['provider'] = Variable<String>(
        $AccountsTable.$converterprovider.toSql(provider),
      );
    }
    map['color'] = Variable<int>(color);
    map['position'] = Variable<int>(position);
    {
      map['status'] = Variable<String>(
        $AccountsTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      address: Value(address),
      provider: Value(provider),
      color: Value(color),
      position: Value(position),
      status: Value(status),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      address: serializer.fromJson<String>(json['address']),
      provider: $AccountsTable.$converterprovider.fromJson(
        serializer.fromJson<String>(json['provider']),
      ),
      color: serializer.fromJson<int>(json['color']),
      position: serializer.fromJson<int>(json['position']),
      status: $AccountsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'address': serializer.toJson<String>(address),
      'provider': serializer.toJson<String>(
        $AccountsTable.$converterprovider.toJson(provider),
      ),
      'color': serializer.toJson<int>(color),
      'position': serializer.toJson<int>(position),
      'status': serializer.toJson<String>(
        $AccountsTable.$converterstatus.toJson(status),
      ),
    };
  }

  AccountRow copyWith({
    String? id,
    String? address,
    ProviderKind? provider,
    int? color,
    int? position,
    AccountStatus? status,
  }) => AccountRow(
    id: id ?? this.id,
    address: address ?? this.address,
    provider: provider ?? this.provider,
    color: color ?? this.color,
    position: position ?? this.position,
    status: status ?? this.status,
  );
  AccountRow copyWithCompanion(AccountsCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      address: data.address.present ? data.address.value : this.address,
      provider: data.provider.present ? data.provider.value : this.provider,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('provider: $provider, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, address, provider, color, position, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.address == this.address &&
          other.provider == this.provider &&
          other.color == this.color &&
          other.position == this.position &&
          other.status == this.status);
}

class AccountsCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> address;
  final Value<ProviderKind> provider;
  final Value<int> color;
  final Value<int> position;
  final Value<AccountStatus> status;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.address = const Value.absent(),
    this.provider = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String address,
    required ProviderKind provider,
    required int color,
    required int position,
    required AccountStatus status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       address = Value(address),
       provider = Value(provider),
       color = Value(color),
       position = Value(position),
       status = Value(status);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? address,
    Expression<String>? provider,
    Expression<int>? color,
    Expression<int>? position,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (address != null) 'address': address,
      if (provider != null) 'provider': provider,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? address,
    Value<ProviderKind>? provider,
    Value<int>? color,
    Value<int>? position,
    Value<AccountStatus>? status,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      address: address ?? this.address,
      provider: provider ?? this.provider,
      color: color ?? this.color,
      position: position ?? this.position,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(
        $AccountsTable.$converterprovider.toSql(provider.value),
      );
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $AccountsTable.$converterstatus.toSql(status.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('provider: $provider, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LabelsTable extends Labels with TableInfo<$LabelsTable, LabelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  @override
  late final GeneratedColumnWithTypeConverter<LabelKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LabelKind>($LabelsTable.$converterkind);
  @override
  List<GeneratedColumn> get $columns => [accountId, id, name, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<LabelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  LabelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LabelRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: $LabelsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
    );
  }

  @override
  $LabelsTable createAlias(String alias) {
    return $LabelsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LabelKind, String, String> $converterkind =
      const EnumNameConverter<LabelKind>(LabelKind.values);
}

class LabelRow extends DataClass implements Insertable<LabelRow> {
  final String accountId;
  final String id;
  final String name;
  final LabelKind kind;
  const LabelRow({
    required this.accountId,
    required this.id,
    required this.name,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['kind'] = Variable<String>($LabelsTable.$converterkind.toSql(kind));
    }
    return map;
  }

  LabelsCompanion toCompanion(bool nullToAbsent) {
    return LabelsCompanion(
      accountId: Value(accountId),
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
    );
  }

  factory LabelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LabelRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: $LabelsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(
        $LabelsTable.$converterkind.toJson(kind),
      ),
    };
  }

  LabelRow copyWith({
    String? accountId,
    String? id,
    String? name,
    LabelKind? kind,
  }) => LabelRow(
    accountId: accountId ?? this.accountId,
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
  );
  LabelRow copyWithCompanion(LabelsCompanion data) {
    return LabelRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LabelRow(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, id, name, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LabelRow &&
          other.accountId == this.accountId &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind);
}

class LabelsCompanion extends UpdateCompanion<LabelRow> {
  final Value<String> accountId;
  final Value<String> id;
  final Value<String> name;
  final Value<LabelKind> kind;
  final Value<int> rowid;
  const LabelsCompanion({
    this.accountId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LabelsCompanion.insert({
    required String accountId,
    required String id,
    required String name,
    required LabelKind kind,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       id = Value(id),
       name = Value(name),
       kind = Value(kind);
  static Insertable<LabelRow> custom({
    Expression<String>? accountId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LabelsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? id,
    Value<String>? name,
    Value<LabelKind>? kind,
    Value<int>? rowid,
  }) {
    return LabelsCompanion(
      accountId: accountId ?? this.accountId,
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $LabelsTable.$converterkind.toSql(kind.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LabelsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientsMeta = const VerificationMeta(
    'recipients',
  );
  @override
  late final GeneratedColumn<String> recipients = GeneratedColumn<String>(
    'recipients',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<int> date = GeneratedColumn<int>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isStarredMeta = const VerificationMeta(
    'isStarred',
  );
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
    'is_starred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_starred" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    id,
    messageId,
    conversationId,
    sender,
    recipients,
    subject,
    snippet,
    date,
    isRead,
    isStarred,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    } else if (isInserting) {
      context.missing(_senderMeta);
    }
    if (data.containsKey('recipients')) {
      context.handle(
        _recipientsMeta,
        recipients.isAcceptableOrUnknown(data['recipients']!, _recipientsMeta),
      );
    } else if (isInserting) {
      context.missing(_recipientsMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    } else if (isInserting) {
      context.missing(_snippetMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    } else if (isInserting) {
      context.missing(_isReadMeta);
    }
    if (data.containsKey('is_starred')) {
      context.handle(
        _isStarredMeta,
        isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta),
      );
    } else if (isInserting) {
      context.missing(_isStarredMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      )!,
      recipients: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      snippet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snippet'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      isStarred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_starred'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String accountId;
  final String id;
  final String messageId;
  final String conversationId;
  final String sender;
  final String recipients;
  final String subject;
  final String snippet;

  /// Milliseconds since epoch, UTC.
  final int date;
  final bool isRead;
  final bool isStarred;
  const MessageRow({
    required this.accountId,
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.sender,
    required this.recipients,
    required this.subject,
    required this.snippet,
    required this.date,
    required this.isRead,
    required this.isStarred,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['id'] = Variable<String>(id);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender'] = Variable<String>(sender);
    map['recipients'] = Variable<String>(recipients);
    map['subject'] = Variable<String>(subject);
    map['snippet'] = Variable<String>(snippet);
    map['date'] = Variable<int>(date);
    map['is_read'] = Variable<bool>(isRead);
    map['is_starred'] = Variable<bool>(isStarred);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      accountId: Value(accountId),
      id: Value(id),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      sender: Value(sender),
      recipients: Value(recipients),
      subject: Value(subject),
      snippet: Value(snippet),
      date: Value(date),
      isRead: Value(isRead),
      isStarred: Value(isStarred),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      id: serializer.fromJson<String>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sender: serializer.fromJson<String>(json['sender']),
      recipients: serializer.fromJson<String>(json['recipients']),
      subject: serializer.fromJson<String>(json['subject']),
      snippet: serializer.fromJson<String>(json['snippet']),
      date: serializer.fromJson<int>(json['date']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'id': serializer.toJson<String>(id),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'sender': serializer.toJson<String>(sender),
      'recipients': serializer.toJson<String>(recipients),
      'subject': serializer.toJson<String>(subject),
      'snippet': serializer.toJson<String>(snippet),
      'date': serializer.toJson<int>(date),
      'isRead': serializer.toJson<bool>(isRead),
      'isStarred': serializer.toJson<bool>(isStarred),
    };
  }

  MessageRow copyWith({
    String? accountId,
    String? id,
    String? messageId,
    String? conversationId,
    String? sender,
    String? recipients,
    String? subject,
    String? snippet,
    int? date,
    bool? isRead,
    bool? isStarred,
  }) => MessageRow(
    accountId: accountId ?? this.accountId,
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    sender: sender ?? this.sender,
    recipients: recipients ?? this.recipients,
    subject: subject ?? this.subject,
    snippet: snippet ?? this.snippet,
    date: date ?? this.date,
    isRead: isRead ?? this.isRead,
    isStarred: isStarred ?? this.isStarred,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sender: data.sender.present ? data.sender.value : this.sender,
      recipients: data.recipients.present
          ? data.recipients.value
          : this.recipients,
      subject: data.subject.present ? data.subject.value : this.subject,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      date: data.date.present ? data.date.value : this.date,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sender: $sender, ')
          ..write('recipients: $recipients, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('date: $date, ')
          ..write('isRead: $isRead, ')
          ..write('isStarred: $isStarred')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    id,
    messageId,
    conversationId,
    sender,
    recipients,
    subject,
    snippet,
    date,
    isRead,
    isStarred,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.accountId == this.accountId &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.sender == this.sender &&
          other.recipients == this.recipients &&
          other.subject == this.subject &&
          other.snippet == this.snippet &&
          other.date == this.date &&
          other.isRead == this.isRead &&
          other.isStarred == this.isStarred);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> accountId;
  final Value<String> id;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> sender;
  final Value<String> recipients;
  final Value<String> subject;
  final Value<String> snippet;
  final Value<int> date;
  final Value<bool> isRead;
  final Value<bool> isStarred;
  final Value<int> rowid;
  const MessagesCompanion({
    this.accountId = const Value.absent(),
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.sender = const Value.absent(),
    this.recipients = const Value.absent(),
    this.subject = const Value.absent(),
    this.snippet = const Value.absent(),
    this.date = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String accountId,
    required String id,
    required String messageId,
    required String conversationId,
    required String sender,
    required String recipients,
    required String subject,
    required String snippet,
    required int date,
    required bool isRead,
    required bool isStarred,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       id = Value(id),
       messageId = Value(messageId),
       conversationId = Value(conversationId),
       sender = Value(sender),
       recipients = Value(recipients),
       subject = Value(subject),
       snippet = Value(snippet),
       date = Value(date),
       isRead = Value(isRead),
       isStarred = Value(isStarred);
  static Insertable<MessageRow> custom({
    Expression<String>? accountId,
    Expression<String>? id,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? sender,
    Expression<String>? recipients,
    Expression<String>? subject,
    Expression<String>? snippet,
    Expression<int>? date,
    Expression<bool>? isRead,
    Expression<bool>? isStarred,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (sender != null) 'sender': sender,
      if (recipients != null) 'recipients': recipients,
      if (subject != null) 'subject': subject,
      if (snippet != null) 'snippet': snippet,
      if (date != null) 'date': date,
      if (isRead != null) 'is_read': isRead,
      if (isStarred != null) 'is_starred': isStarred,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? id,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? sender,
    Value<String>? recipients,
    Value<String>? subject,
    Value<String>? snippet,
    Value<int>? date,
    Value<bool>? isRead,
    Value<bool>? isStarred,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      accountId: accountId ?? this.accountId,
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      sender: sender ?? this.sender,
      recipients: recipients ?? this.recipients,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (recipients.present) {
      map['recipients'] = Variable<String>(recipients.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (date.present) {
      map['date'] = Variable<int>(date.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sender: $sender, ')
          ..write('recipients: $recipients, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('date: $date, ')
          ..write('isRead: $isRead, ')
          ..write('isStarred: $isStarred, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageLabelsTable extends MessageLabels
    with TableInfo<$MessageLabelsTable, MessageLabelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelIdMeta = const VerificationMeta(
    'labelId',
  );
  @override
  late final GeneratedColumn<String> labelId = GeneratedColumn<String>(
    'label_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, messageId, labelId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_labels';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageLabelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('label_id')) {
      context.handle(
        _labelIdMeta,
        labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_labelIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, messageId, labelId};
  @override
  MessageLabelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageLabelRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      labelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label_id'],
      )!,
    );
  }

  @override
  $MessageLabelsTable createAlias(String alias) {
    return $MessageLabelsTable(attachedDatabase, alias);
  }
}

class MessageLabelRow extends DataClass implements Insertable<MessageLabelRow> {
  final String accountId;
  final String messageId;
  final String labelId;
  const MessageLabelRow({
    required this.accountId,
    required this.messageId,
    required this.labelId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['message_id'] = Variable<String>(messageId);
    map['label_id'] = Variable<String>(labelId);
    return map;
  }

  MessageLabelsCompanion toCompanion(bool nullToAbsent) {
    return MessageLabelsCompanion(
      accountId: Value(accountId),
      messageId: Value(messageId),
      labelId: Value(labelId),
    );
  }

  factory MessageLabelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageLabelRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      labelId: serializer.fromJson<String>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'messageId': serializer.toJson<String>(messageId),
      'labelId': serializer.toJson<String>(labelId),
    };
  }

  MessageLabelRow copyWith({
    String? accountId,
    String? messageId,
    String? labelId,
  }) => MessageLabelRow(
    accountId: accountId ?? this.accountId,
    messageId: messageId ?? this.messageId,
    labelId: labelId ?? this.labelId,
  );
  MessageLabelRow copyWithCompanion(MessageLabelsCompanion data) {
    return MessageLabelRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageLabelRow(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, messageId, labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageLabelRow &&
          other.accountId == this.accountId &&
          other.messageId == this.messageId &&
          other.labelId == this.labelId);
}

class MessageLabelsCompanion extends UpdateCompanion<MessageLabelRow> {
  final Value<String> accountId;
  final Value<String> messageId;
  final Value<String> labelId;
  final Value<int> rowid;
  const MessageLabelsCompanion({
    this.accountId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageLabelsCompanion.insert({
    required String accountId,
    required String messageId,
    required String labelId,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       messageId = Value(messageId),
       labelId = Value(labelId);
  static Insertable<MessageLabelRow> custom({
    Expression<String>? accountId,
    Expression<String>? messageId,
    Expression<String>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (messageId != null) 'message_id': messageId,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageLabelsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? messageId,
    Value<String>? labelId,
    Value<int>? rowid,
  }) {
    return MessageLabelsCompanion(
      accountId: accountId ?? this.accountId,
      messageId: messageId ?? this.messageId,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<String>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageLabelsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PostinoDatabase extends GeneratedDatabase {
  _$PostinoDatabase(QueryExecutor e) : super(e);
  $PostinoDatabaseManager get managers => $PostinoDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $LabelsTable labels = $LabelsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $MessageLabelsTable messageLabels = $MessageLabelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    labels,
    messages,
    messageLabels,
  ];
}

typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  required String id,
  required String address,
  required ProviderKind provider,
  required int color,
  required int position,
  required AccountStatus status,
  Value<int> rowid,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<String> id,
  Value<String> address,
  Value<ProviderKind> provider,
  Value<int> color,
  Value<int> position,
  Value<AccountStatus> status,
  Value<int> rowid,
});

class $$AccountsTableFilterComposer
    extends Composer<_$PostinoDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ProviderKind, ProviderKind, String>
  get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountStatus, AccountStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ProviderKind, String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $AccountsTable,
          AccountRow,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (
            AccountRow,
            BaseReferences<_$PostinoDatabase, $AccountsTable, AccountRow>,
          ),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$PostinoDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> address = const Value.absent(),
                Value<ProviderKind> provider = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<AccountStatus> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                address: address,
                provider: provider,
                color: color,
                position: position,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String address,
                required ProviderKind provider,
                required int color,
                required int position,
                required AccountStatus status,
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                address: address,
                provider: provider,
                color: color,
                position: position,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, AccountRow>(table),
                  BaseReferences<_$PostinoDatabase, $AccountsTable, AccountRow>(
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

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $AccountsTable,
      AccountRow,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (
        AccountRow,
        BaseReferences<_$PostinoDatabase, $AccountsTable, AccountRow>,
      ),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$LabelsTableCreateCompanionBuilder = LabelsCompanion Function({
  required String accountId,
  required String id,
  required String name,
  required LabelKind kind,
  Value<int> rowid,
});
typedef $$LabelsTableUpdateCompanionBuilder = LabelsCompanion Function({
  Value<String> accountId,
  Value<String> id,
  Value<String> name,
  Value<LabelKind> kind,
  Value<int> rowid,
});

class $$LabelsTableFilterComposer
    extends Composer<_$PostinoDatabase, $LabelsTable> {
  $$LabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LabelKind, LabelKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$LabelsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $LabelsTable> {
  $$LabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LabelsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $LabelsTable> {
  $$LabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LabelKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);
}

class $$LabelsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $LabelsTable,
          LabelRow,
          $$LabelsTableFilterComposer,
          $$LabelsTableOrderingComposer,
          $$LabelsTableAnnotationComposer,
          $$LabelsTableCreateCompanionBuilder,
          $$LabelsTableUpdateCompanionBuilder,
          (LabelRow, BaseReferences<_$PostinoDatabase, $LabelsTable, LabelRow>),
          LabelRow,
          PrefetchHooks Function()
        > {
  $$LabelsTableTableManager(_$PostinoDatabase db, $LabelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<LabelKind> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion(
                accountId: accountId,
                id: id,
                name: name,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String id,
                required String name,
                required LabelKind kind,
                Value<int> rowid = const Value.absent(),
              }) => LabelsCompanion.insert(
                accountId: accountId,
                id: id,
                name: name,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LabelsTable, LabelRow>(table),
                  BaseReferences<_$PostinoDatabase, $LabelsTable, LabelRow>(
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

typedef $$LabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $LabelsTable,
      LabelRow,
      $$LabelsTableFilterComposer,
      $$LabelsTableOrderingComposer,
      $$LabelsTableAnnotationComposer,
      $$LabelsTableCreateCompanionBuilder,
      $$LabelsTableUpdateCompanionBuilder,
      (LabelRow, BaseReferences<_$PostinoDatabase, $LabelsTable, LabelRow>),
      LabelRow,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  required String accountId,
  required String id,
  required String messageId,
  required String conversationId,
  required String sender,
  required String recipients,
  required String subject,
  required String snippet,
  required int date,
  required bool isRead,
  required bool isStarred,
  Value<int> rowid,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<String> accountId,
  Value<String> id,
  Value<String> messageId,
  Value<String> conversationId,
  Value<String> sender,
  Value<String> recipients,
  Value<String> subject,
  Value<String> snippet,
  Value<int> date,
  Value<bool> isRead,
  Value<bool> isStarred,
  Value<int> rowid,
});

class $$MessagesTableFilterComposer
    extends Composer<_$PostinoDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$PostinoDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isStarred => $composableBuilder(
    column: $table.isStarred,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<int> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$PostinoDatabase, $MessagesTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$PostinoDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> sender = const Value.absent(),
                Value<String> recipients = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> snippet = const Value.absent(),
                Value<int> date = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<bool> isStarred = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                accountId: accountId,
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                sender: sender,
                recipients: recipients,
                subject: subject,
                snippet: snippet,
                date: date,
                isRead: isRead,
                isStarred: isStarred,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String id,
                required String messageId,
                required String conversationId,
                required String sender,
                required String recipients,
                required String subject,
                required String snippet,
                required int date,
                required bool isRead,
                required bool isStarred,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                accountId: accountId,
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                sender: sender,
                recipients: recipients,
                subject: subject,
                snippet: snippet,
                date: date,
                isRead: isRead,
                isStarred: isStarred,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, MessageRow>(table),
                  BaseReferences<_$PostinoDatabase, $MessagesTable, MessageRow>(
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

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (
        MessageRow,
        BaseReferences<_$PostinoDatabase, $MessagesTable, MessageRow>,
      ),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$MessageLabelsTableCreateCompanionBuilder =
    MessageLabelsCompanion Function({
      required String accountId,
      required String messageId,
      required String labelId,
      Value<int> rowid,
    });
typedef $$MessageLabelsTableUpdateCompanionBuilder =
    MessageLabelsCompanion Function({
      Value<String> accountId,
      Value<String> messageId,
      Value<String> labelId,
      Value<int> rowid,
    });

class $$MessageLabelsTableFilterComposer
    extends Composer<_$PostinoDatabase, $MessageLabelsTable> {
  $$MessageLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get labelId => $composableBuilder(
    column: $table.labelId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageLabelsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $MessageLabelsTable> {
  $$MessageLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get labelId => $composableBuilder(
    column: $table.labelId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageLabelsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $MessageLabelsTable> {
  $$MessageLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get labelId =>
      $composableBuilder(column: $table.labelId, builder: (column) => column);
}

class $$MessageLabelsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $MessageLabelsTable,
          MessageLabelRow,
          $$MessageLabelsTableFilterComposer,
          $$MessageLabelsTableOrderingComposer,
          $$MessageLabelsTableAnnotationComposer,
          $$MessageLabelsTableCreateCompanionBuilder,
          $$MessageLabelsTableUpdateCompanionBuilder,
          (
            MessageLabelRow,
            BaseReferences<
              _$PostinoDatabase,
              $MessageLabelsTable,
              MessageLabelRow
            >,
          ),
          MessageLabelRow,
          PrefetchHooks Function()
        > {
  $$MessageLabelsTableTableManager(
    _$PostinoDatabase db,
    $MessageLabelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> labelId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageLabelsCompanion(
                accountId: accountId,
                messageId: messageId,
                labelId: labelId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String messageId,
                required String labelId,
                Value<int> rowid = const Value.absent(),
              }) => MessageLabelsCompanion.insert(
                accountId: accountId,
                messageId: messageId,
                labelId: labelId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessageLabelsTable, MessageLabelRow>(table),
                  BaseReferences<
                    _$PostinoDatabase,
                    $MessageLabelsTable,
                    MessageLabelRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageLabelsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $MessageLabelsTable,
      MessageLabelRow,
      $$MessageLabelsTableFilterComposer,
      $$MessageLabelsTableOrderingComposer,
      $$MessageLabelsTableAnnotationComposer,
      $$MessageLabelsTableCreateCompanionBuilder,
      $$MessageLabelsTableUpdateCompanionBuilder,
      (
        MessageLabelRow,
        BaseReferences<_$PostinoDatabase, $MessageLabelsTable, MessageLabelRow>,
      ),
      MessageLabelRow,
      PrefetchHooks Function()
    >;

class $PostinoDatabaseManager {
  final _$PostinoDatabase _db;
  $PostinoDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$LabelsTableTableManager get labels =>
      $$LabelsTableTableManager(_db, _db.labels);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$MessageLabelsTableTableManager get messageLabels =>
      $$MessageLabelsTableTableManager(_db, _db.messageLabels);
}
