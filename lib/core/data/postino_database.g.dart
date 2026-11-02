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
  static const VerificationMeta _senderNameMeta = const VerificationMeta(
    'senderName',
  );
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
    'sender_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _ccMeta = const VerificationMeta('cc');
  @override
  late final GeneratedColumn<String> cc = GeneratedColumn<String>(
    'cc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bccMeta = const VerificationMeta('bcc');
  @override
  late final GeneratedColumn<String> bcc = GeneratedColumn<String>(
    'bcc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _replyToMeta = const VerificationMeta(
    'replyTo',
  );
  @override
  late final GeneratedColumn<String> replyTo = GeneratedColumn<String>(
    'reply_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referencesMeta = const VerificationMeta(
    'references',
  );
  @override
  late final GeneratedColumn<String> references = GeneratedColumn<String>(
    'references',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    senderName,
    recipients,
    cc,
    bcc,
    replyTo,
    references,
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
    if (data.containsKey('sender_name')) {
      context.handle(
        _senderNameMeta,
        senderName.isAcceptableOrUnknown(data['sender_name']!, _senderNameMeta),
      );
    }
    if (data.containsKey('recipients')) {
      context.handle(
        _recipientsMeta,
        recipients.isAcceptableOrUnknown(data['recipients']!, _recipientsMeta),
      );
    } else if (isInserting) {
      context.missing(_recipientsMeta);
    }
    if (data.containsKey('cc')) {
      context.handle(_ccMeta, cc.isAcceptableOrUnknown(data['cc']!, _ccMeta));
    }
    if (data.containsKey('bcc')) {
      context.handle(
        _bccMeta,
        bcc.isAcceptableOrUnknown(data['bcc']!, _bccMeta),
      );
    }
    if (data.containsKey('reply_to')) {
      context.handle(
        _replyToMeta,
        replyTo.isAcceptableOrUnknown(data['reply_to']!, _replyToMeta),
      );
    }
    if (data.containsKey('references')) {
      context.handle(
        _referencesMeta,
        references.isAcceptableOrUnknown(data['references']!, _referencesMeta),
      );
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
      senderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_name'],
      ),
      recipients: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients'],
      )!,
      cc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc'],
      )!,
      bcc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bcc'],
      )!,
      replyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to'],
      ),
      references: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}references'],
      ),
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

  /// The sender's address; [senderName] its display name, if the `From` header has one (v7).
  final String sender;
  final String? senderName;

  /// To and Cc, one `Name <address>` or bare address per line (v7: they were comma separated).
  final String recipients;
  final String cc;

  /// Bcc, as [cc]; only Bozze and sent messages have one (v10).
  final String bcc;

  /// The `Reply-To` mailbox and the `References` Message-IDs, one per line; null in rows cached before v11 (#37).
  final String? replyTo;
  final String? references;
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
    this.senderName,
    required this.recipients,
    required this.cc,
    required this.bcc,
    this.replyTo,
    this.references,
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
    if (!nullToAbsent || senderName != null) {
      map['sender_name'] = Variable<String>(senderName);
    }
    map['recipients'] = Variable<String>(recipients);
    map['cc'] = Variable<String>(cc);
    map['bcc'] = Variable<String>(bcc);
    if (!nullToAbsent || replyTo != null) {
      map['reply_to'] = Variable<String>(replyTo);
    }
    if (!nullToAbsent || references != null) {
      map['references'] = Variable<String>(references);
    }
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
      senderName: senderName == null && nullToAbsent
          ? const Value.absent()
          : Value(senderName),
      recipients: Value(recipients),
      cc: Value(cc),
      bcc: Value(bcc),
      replyTo: replyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(replyTo),
      references: references == null && nullToAbsent
          ? const Value.absent()
          : Value(references),
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
      senderName: serializer.fromJson<String?>(json['senderName']),
      recipients: serializer.fromJson<String>(json['recipients']),
      cc: serializer.fromJson<String>(json['cc']),
      bcc: serializer.fromJson<String>(json['bcc']),
      replyTo: serializer.fromJson<String?>(json['replyTo']),
      references: serializer.fromJson<String?>(json['references']),
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
      'senderName': serializer.toJson<String?>(senderName),
      'recipients': serializer.toJson<String>(recipients),
      'cc': serializer.toJson<String>(cc),
      'bcc': serializer.toJson<String>(bcc),
      'replyTo': serializer.toJson<String?>(replyTo),
      'references': serializer.toJson<String?>(references),
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
    Value<String?> senderName = const Value.absent(),
    String? recipients,
    String? cc,
    String? bcc,
    Value<String?> replyTo = const Value.absent(),
    Value<String?> references = const Value.absent(),
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
    senderName: senderName.present ? senderName.value : this.senderName,
    recipients: recipients ?? this.recipients,
    cc: cc ?? this.cc,
    bcc: bcc ?? this.bcc,
    replyTo: replyTo.present ? replyTo.value : this.replyTo,
    references: references.present ? references.value : this.references,
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
      senderName: data.senderName.present
          ? data.senderName.value
          : this.senderName,
      recipients: data.recipients.present
          ? data.recipients.value
          : this.recipients,
      cc: data.cc.present ? data.cc.value : this.cc,
      bcc: data.bcc.present ? data.bcc.value : this.bcc,
      replyTo: data.replyTo.present ? data.replyTo.value : this.replyTo,
      references: data.references.present
          ? data.references.value
          : this.references,
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
          ..write('senderName: $senderName, ')
          ..write('recipients: $recipients, ')
          ..write('cc: $cc, ')
          ..write('bcc: $bcc, ')
          ..write('replyTo: $replyTo, ')
          ..write('references: $references, ')
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
    senderName,
    recipients,
    cc,
    bcc,
    replyTo,
    references,
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
          other.senderName == this.senderName &&
          other.recipients == this.recipients &&
          other.cc == this.cc &&
          other.bcc == this.bcc &&
          other.replyTo == this.replyTo &&
          other.references == this.references &&
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
  final Value<String?> senderName;
  final Value<String> recipients;
  final Value<String> cc;
  final Value<String> bcc;
  final Value<String?> replyTo;
  final Value<String?> references;
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
    this.senderName = const Value.absent(),
    this.recipients = const Value.absent(),
    this.cc = const Value.absent(),
    this.bcc = const Value.absent(),
    this.replyTo = const Value.absent(),
    this.references = const Value.absent(),
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
    this.senderName = const Value.absent(),
    required String recipients,
    this.cc = const Value.absent(),
    this.bcc = const Value.absent(),
    this.replyTo = const Value.absent(),
    this.references = const Value.absent(),
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
    Expression<String>? senderName,
    Expression<String>? recipients,
    Expression<String>? cc,
    Expression<String>? bcc,
    Expression<String>? replyTo,
    Expression<String>? references,
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
      if (senderName != null) 'sender_name': senderName,
      if (recipients != null) 'recipients': recipients,
      if (cc != null) 'cc': cc,
      if (bcc != null) 'bcc': bcc,
      if (replyTo != null) 'reply_to': replyTo,
      if (references != null) 'references': references,
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
    Value<String?>? senderName,
    Value<String>? recipients,
    Value<String>? cc,
    Value<String>? bcc,
    Value<String?>? replyTo,
    Value<String?>? references,
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
      senderName: senderName ?? this.senderName,
      recipients: recipients ?? this.recipients,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      replyTo: replyTo ?? this.replyTo,
      references: references ?? this.references,
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
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (recipients.present) {
      map['recipients'] = Variable<String>(recipients.value);
    }
    if (cc.present) {
      map['cc'] = Variable<String>(cc.value);
    }
    if (bcc.present) {
      map['bcc'] = Variable<String>(bcc.value);
    }
    if (replyTo.present) {
      map['reply_to'] = Variable<String>(replyTo.value);
    }
    if (references.present) {
      map['references'] = Variable<String>(references.value);
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
          ..write('senderName: $senderName, ')
          ..write('recipients: $recipients, ')
          ..write('cc: $cc, ')
          ..write('bcc: $bcc, ')
          ..write('replyTo: $replyTo, ')
          ..write('references: $references, ')
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

class $BodiesTable extends Bodies with TableInfo<$BodiesTable, BodyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BodyKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(BodyKind.testo.name),
      ).withConverter<BodyKind>($BodiesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<List<Attachment>?, String>
  attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<Attachment>?>($BodiesTable.$converterattachmentsn);
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    messageId,
    body,
    kind,
    attachments,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bodies';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyRow> instance, {
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, messageId};
  @override
  BodyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      kind: $BodiesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      attachments: $BodiesTable.$converterattachmentsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}attachments'],
        ),
      ),
    );
  }

  @override
  $BodiesTable createAlias(String alias) {
    return $BodiesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BodyKind, String, String> $converterkind =
      const EnumNameConverter<BodyKind>(BodyKind.values);
  static TypeConverter<List<Attachment>, String> $converterattachments =
      const AttachmentsConverter();
  static TypeConverter<List<Attachment>?, String?> $converterattachmentsn =
      NullAwareTypeConverter.wrap($converterattachments);
}

class BodyRow extends DataClass implements Insertable<BodyRow> {
  final String accountId;
  final String messageId;
  final String body;

  /// HTML or plain text; the default only fills the rows of v1-v4, which the migration then sorts.
  final BodyKind kind;

  /// The attachments, as JSON `[{"id", "name", "size"}]` (v9); null in rows stored before, which did not know them.
  final List<Attachment>? attachments;
  const BodyRow({
    required this.accountId,
    required this.messageId,
    required this.body,
    required this.kind,
    this.attachments,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['message_id'] = Variable<String>(messageId);
    map['body'] = Variable<String>(body);
    {
      map['kind'] = Variable<String>($BodiesTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(
        $BodiesTable.$converterattachmentsn.toSql(attachments),
      );
    }
    return map;
  }

  BodiesCompanion toCompanion(bool nullToAbsent) {
    return BodiesCompanion(
      accountId: Value(accountId),
      messageId: Value(messageId),
      body: Value(body),
      kind: Value(kind),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
    );
  }

  factory BodyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      body: serializer.fromJson<String>(json['body']),
      kind: $BodiesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      attachments: serializer.fromJson<List<Attachment>?>(json['attachments']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'messageId': serializer.toJson<String>(messageId),
      'body': serializer.toJson<String>(body),
      'kind': serializer.toJson<String>(
        $BodiesTable.$converterkind.toJson(kind),
      ),
      'attachments': serializer.toJson<List<Attachment>?>(attachments),
    };
  }

  BodyRow copyWith({
    String? accountId,
    String? messageId,
    String? body,
    BodyKind? kind,
    Value<List<Attachment>?> attachments = const Value.absent(),
  }) => BodyRow(
    accountId: accountId ?? this.accountId,
    messageId: messageId ?? this.messageId,
    body: body ?? this.body,
    kind: kind ?? this.kind,
    attachments: attachments.present ? attachments.value : this.attachments,
  );
  BodyRow copyWithCompanion(BodiesCompanion data) {
    return BodyRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      body: data.body.present ? data.body.value : this.body,
      kind: data.kind.present ? data.kind.value : this.kind,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyRow(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('attachments: $attachments')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountId, messageId, body, kind, attachments);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyRow &&
          other.accountId == this.accountId &&
          other.messageId == this.messageId &&
          other.body == this.body &&
          other.kind == this.kind &&
          other.attachments == this.attachments);
}

class BodiesCompanion extends UpdateCompanion<BodyRow> {
  final Value<String> accountId;
  final Value<String> messageId;
  final Value<String> body;
  final Value<BodyKind> kind;
  final Value<List<Attachment>?> attachments;
  final Value<int> rowid;
  const BodiesCompanion({
    this.accountId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.body = const Value.absent(),
    this.kind = const Value.absent(),
    this.attachments = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodiesCompanion.insert({
    required String accountId,
    required String messageId,
    required String body,
    this.kind = const Value.absent(),
    this.attachments = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       messageId = Value(messageId),
       body = Value(body);
  static Insertable<BodyRow> custom({
    Expression<String>? accountId,
    Expression<String>? messageId,
    Expression<String>? body,
    Expression<String>? kind,
    Expression<String>? attachments,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (messageId != null) 'message_id': messageId,
      if (body != null) 'body': body,
      if (kind != null) 'kind': kind,
      if (attachments != null) 'attachments': attachments,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodiesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? messageId,
    Value<String>? body,
    Value<BodyKind>? kind,
    Value<List<Attachment>?>? attachments,
    Value<int>? rowid,
  }) {
    return BodiesCompanion(
      accountId: accountId ?? this.accountId,
      messageId: messageId ?? this.messageId,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      attachments: attachments ?? this.attachments,
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
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $BodiesTable.$converterkind.toSql(kind.value),
      );
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(
        $BodiesTable.$converterattachmentsn.toSql(attachments.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodiesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('attachments: $attachments, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, cursor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
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
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    } else if (isInserting) {
      context.missing(_cursorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  final String accountId;
  final String cursor;
  const SyncCursorRow({required this.accountId, required this.cursor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['cursor'] = Variable<String>(cursor);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      accountId: Value(accountId),
      cursor: Value(cursor),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      cursor: serializer.fromJson<String>(json['cursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'cursor': serializer.toJson<String>(cursor),
    };
  }

  SyncCursorRow copyWith({String? accountId, String? cursor}) => SyncCursorRow(
    accountId: accountId ?? this.accountId,
    cursor: cursor ?? this.cursor,
  );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('accountId: $accountId, ')
          ..write('cursor: $cursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, cursor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.accountId == this.accountId &&
          other.cursor == this.cursor);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> accountId;
  final Value<String> cursor;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.accountId = const Value.absent(),
    this.cursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String accountId,
    required String cursor,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       cursor = Value(cursor);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? accountId,
    Expression<String>? cursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (cursor != null) 'cursor': cursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? cursor,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      accountId: accountId ?? this.accountId,
      cursor: cursor ?? this.cursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('cursor: $cursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IntentsTable extends Intents with TableInfo<$IntentsTable, IntentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, messageId, isRead];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intents';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntentRow> instance, {
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
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, messageId};
  @override
  IntentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntentRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      ),
    );
  }

  @override
  $IntentsTable createAlias(String alias) {
    return $IntentsTable(attachedDatabase, alias);
  }
}

class IntentRow extends DataClass implements Insertable<IntentRow> {
  final String accountId;
  final String messageId;
  final bool? isRead;
  const IntentRow({
    required this.accountId,
    required this.messageId,
    this.isRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['message_id'] = Variable<String>(messageId);
    if (!nullToAbsent || isRead != null) {
      map['is_read'] = Variable<bool>(isRead);
    }
    return map;
  }

  IntentsCompanion toCompanion(bool nullToAbsent) {
    return IntentsCompanion(
      accountId: Value(accountId),
      messageId: Value(messageId),
      isRead: isRead == null && nullToAbsent
          ? const Value.absent()
          : Value(isRead),
    );
  }

  factory IntentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntentRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      isRead: serializer.fromJson<bool?>(json['isRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'messageId': serializer.toJson<String>(messageId),
      'isRead': serializer.toJson<bool?>(isRead),
    };
  }

  IntentRow copyWith({
    String? accountId,
    String? messageId,
    Value<bool?> isRead = const Value.absent(),
  }) => IntentRow(
    accountId: accountId ?? this.accountId,
    messageId: messageId ?? this.messageId,
    isRead: isRead.present ? isRead.value : this.isRead,
  );
  IntentRow copyWithCompanion(IntentsCompanion data) {
    return IntentRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntentRow(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('isRead: $isRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, messageId, isRead);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntentRow &&
          other.accountId == this.accountId &&
          other.messageId == this.messageId &&
          other.isRead == this.isRead);
}

class IntentsCompanion extends UpdateCompanion<IntentRow> {
  final Value<String> accountId;
  final Value<String> messageId;
  final Value<bool?> isRead;
  final Value<int> rowid;
  const IntentsCompanion({
    this.accountId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntentsCompanion.insert({
    required String accountId,
    required String messageId,
    this.isRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       messageId = Value(messageId);
  static Insertable<IntentRow> custom({
    Expression<String>? accountId,
    Expression<String>? messageId,
    Expression<bool>? isRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (messageId != null) 'message_id': messageId,
      if (isRead != null) 'is_read': isRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntentsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? messageId,
    Value<bool?>? isRead,
    Value<int>? rowid,
  }) {
    return IntentsCompanion(
      accountId: accountId ?? this.accountId,
      messageId: messageId ?? this.messageId,
      isRead: isRead ?? this.isRead,
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
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntentsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('isRead: $isRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrustedSendersTable extends TrustedSenders
    with TableInfo<$TrustedSendersTable, TrustedSenderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrustedSendersTable(this.attachedDatabase, [this._alias]);
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
  List<GeneratedColumn> get $columns => [address];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trusted_senders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrustedSenderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    } else if (isInserting) {
      context.missing(_addressMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {address};
  @override
  TrustedSenderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrustedSenderRow(
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      )!,
    );
  }

  @override
  $TrustedSendersTable createAlias(String alias) {
    return $TrustedSendersTable(attachedDatabase, alias);
  }
}

class TrustedSenderRow extends DataClass
    implements Insertable<TrustedSenderRow> {
  final String address;
  const TrustedSenderRow({required this.address});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address'] = Variable<String>(address);
    return map;
  }

  TrustedSendersCompanion toCompanion(bool nullToAbsent) {
    return TrustedSendersCompanion(address: Value(address));
  }

  factory TrustedSenderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrustedSenderRow(
      address: serializer.fromJson<String>(json['address']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'address': serializer.toJson<String>(address)};
  }

  TrustedSenderRow copyWith({String? address}) =>
      TrustedSenderRow(address: address ?? this.address);
  TrustedSenderRow copyWithCompanion(TrustedSendersCompanion data) {
    return TrustedSenderRow(
      address: data.address.present ? data.address.value : this.address,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrustedSenderRow(')
          ..write('address: $address')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => address.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrustedSenderRow && other.address == this.address);
}

class TrustedSendersCompanion extends UpdateCompanion<TrustedSenderRow> {
  final Value<String> address;
  final Value<int> rowid;
  const TrustedSendersCompanion({
    this.address = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrustedSendersCompanion.insert({
    required String address,
    this.rowid = const Value.absent(),
  }) : address = Value(address);
  static Insertable<TrustedSenderRow> custom({
    Expression<String>? address,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (address != null) 'address': address,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrustedSendersCompanion copyWith({
    Value<String>? address,
    Value<int>? rowid,
  }) {
    return TrustedSendersCompanion(
      address: address ?? this.address,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrustedSendersCompanion(')
          ..write('address: $address, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceSettingsTable extends DeviceSettings
    with TableInfo<$DeviceSettingsTable, DeviceSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSettingsTable(this.attachedDatabase, [this._alias]);
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
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceSettingRow> instance, {
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceSettingsTable createAlias(String alias) {
    return $DeviceSettingsTable(attachedDatabase, alias);
  }
}

class DeviceSettingRow extends DataClass
    implements Insertable<DeviceSettingRow> {
  final String key;
  final String value;
  const DeviceSettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DeviceSettingsCompanion toCompanion(bool nullToAbsent) {
    return DeviceSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DeviceSettingRow copyWith({String? key, String? value}) =>
      DeviceSettingRow(key: key ?? this.key, value: value ?? this.value);
  DeviceSettingRow copyWithCompanion(DeviceSettingsCompanion data) {
    return DeviceSettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceSettingsCompanion extends UpdateCompanion<DeviceSettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DeviceSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceSettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DeviceSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _ccMeta = const VerificationMeta('cc');
  @override
  late final GeneratedColumn<String> cc = GeneratedColumn<String>(
    'cc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bccMeta = const VerificationMeta('bcc');
  @override
  late final GeneratedColumn<String> bcc = GeneratedColumn<String>(
    'bcc',
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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inReplyToMeta = const VerificationMeta(
    'inReplyTo',
  );
  @override
  late final GeneratedColumn<String> inReplyTo = GeneratedColumn<String>(
    'in_reply_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referencesMeta = const VerificationMeta(
    'references',
  );
  @override
  late final GeneratedColumn<String> references = GeneratedColumn<String>(
    'references',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<
    List<ForwardedAttachment>?,
    String
  >
  attachments =
      GeneratedColumn<String>(
        'attachments',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<List<ForwardedAttachment>?>(
        $DraftsTable.$converterattachmentsn,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingMeta = const VerificationMeta(
    'pending',
  );
  @override
  late final GeneratedColumn<bool> pending = GeneratedColumn<bool>(
    'pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending" IN (0, 1))',
    ),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
  );
  static const VerificationMeta _remoteKnownMeta = const VerificationMeta(
    'remoteKnown',
  );
  @override
  late final GeneratedColumn<bool> remoteKnown = GeneratedColumn<bool>(
    'remote_known',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("remote_known" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    messageId,
    recipients,
    cc,
    bcc,
    subject,
    body,
    inReplyTo,
    references,
    conversationId,
    attachments,
    updatedAt,
    pending,
    synced,
    remoteKnown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
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
    if (data.containsKey('recipients')) {
      context.handle(
        _recipientsMeta,
        recipients.isAcceptableOrUnknown(data['recipients']!, _recipientsMeta),
      );
    } else if (isInserting) {
      context.missing(_recipientsMeta);
    }
    if (data.containsKey('cc')) {
      context.handle(_ccMeta, cc.isAcceptableOrUnknown(data['cc']!, _ccMeta));
    } else if (isInserting) {
      context.missing(_ccMeta);
    }
    if (data.containsKey('bcc')) {
      context.handle(
        _bccMeta,
        bcc.isAcceptableOrUnknown(data['bcc']!, _bccMeta),
      );
    } else if (isInserting) {
      context.missing(_bccMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('in_reply_to')) {
      context.handle(
        _inReplyToMeta,
        inReplyTo.isAcceptableOrUnknown(data['in_reply_to']!, _inReplyToMeta),
      );
    }
    if (data.containsKey('references')) {
      context.handle(
        _referencesMeta,
        references.isAcceptableOrUnknown(data['references']!, _referencesMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
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
    if (data.containsKey('pending')) {
      context.handle(
        _pendingMeta,
        pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta),
      );
    } else if (isInserting) {
      context.missing(_pendingMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    } else if (isInserting) {
      context.missing(_syncedMeta);
    }
    if (data.containsKey('remote_known')) {
      context.handle(
        _remoteKnownMeta,
        remoteKnown.isAcceptableOrUnknown(
          data['remote_known']!,
          _remoteKnownMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteKnownMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, messageId};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      recipients: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipients'],
      )!,
      cc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cc'],
      )!,
      bcc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bcc'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      inReplyTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}in_reply_to'],
      ),
      references: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}references'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      attachments: $DraftsTable.$converterattachmentsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}attachments'],
        ),
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      pending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      remoteKnown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}remote_known'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<ForwardedAttachment>, String>
  $converterattachments = const ForwardedAttachmentsConverter();
  static TypeConverter<List<ForwardedAttachment>?, String?>
  $converterattachmentsn = NullAwareTypeConverter.wrap($converterattachments);
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String accountId;

  /// RFC 5322 Message-ID header, the stable identity on every client.
  final String messageId;

  /// One address per line, as `messages.recipients`.
  final String recipients;
  final String cc;
  final String bcc;
  final String subject;

  /// HTML.
  final String body;

  /// A reply (#37, v11): In-Reply-To, the References one per line, the Provider's Conversazione id;
  /// a forward: the attachments taken over, as JSON. Null for a plain new message.
  final String? inReplyTo;
  final String? references;
  final String? conversationId;
  final List<ForwardedAttachment>? attachments;

  /// Milliseconds since epoch, UTC.
  final int updatedAt;
  final bool pending;
  final bool synced;
  final bool remoteKnown;
  const DraftRow({
    required this.accountId,
    required this.messageId,
    required this.recipients,
    required this.cc,
    required this.bcc,
    required this.subject,
    required this.body,
    this.inReplyTo,
    this.references,
    this.conversationId,
    this.attachments,
    required this.updatedAt,
    required this.pending,
    required this.synced,
    required this.remoteKnown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['message_id'] = Variable<String>(messageId);
    map['recipients'] = Variable<String>(recipients);
    map['cc'] = Variable<String>(cc);
    map['bcc'] = Variable<String>(bcc);
    map['subject'] = Variable<String>(subject);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || inReplyTo != null) {
      map['in_reply_to'] = Variable<String>(inReplyTo);
    }
    if (!nullToAbsent || references != null) {
      map['references'] = Variable<String>(references);
    }
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    if (!nullToAbsent || attachments != null) {
      map['attachments'] = Variable<String>(
        $DraftsTable.$converterattachmentsn.toSql(attachments),
      );
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['pending'] = Variable<bool>(pending);
    map['synced'] = Variable<bool>(synced);
    map['remote_known'] = Variable<bool>(remoteKnown);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      accountId: Value(accountId),
      messageId: Value(messageId),
      recipients: Value(recipients),
      cc: Value(cc),
      bcc: Value(bcc),
      subject: Value(subject),
      body: Value(body),
      inReplyTo: inReplyTo == null && nullToAbsent
          ? const Value.absent()
          : Value(inReplyTo),
      references: references == null && nullToAbsent
          ? const Value.absent()
          : Value(references),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      attachments: attachments == null && nullToAbsent
          ? const Value.absent()
          : Value(attachments),
      updatedAt: Value(updatedAt),
      pending: Value(pending),
      synced: Value(synced),
      remoteKnown: Value(remoteKnown),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      recipients: serializer.fromJson<String>(json['recipients']),
      cc: serializer.fromJson<String>(json['cc']),
      bcc: serializer.fromJson<String>(json['bcc']),
      subject: serializer.fromJson<String>(json['subject']),
      body: serializer.fromJson<String>(json['body']),
      inReplyTo: serializer.fromJson<String?>(json['inReplyTo']),
      references: serializer.fromJson<String?>(json['references']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      attachments: serializer.fromJson<List<ForwardedAttachment>?>(
        json['attachments'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      pending: serializer.fromJson<bool>(json['pending']),
      synced: serializer.fromJson<bool>(json['synced']),
      remoteKnown: serializer.fromJson<bool>(json['remoteKnown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'messageId': serializer.toJson<String>(messageId),
      'recipients': serializer.toJson<String>(recipients),
      'cc': serializer.toJson<String>(cc),
      'bcc': serializer.toJson<String>(bcc),
      'subject': serializer.toJson<String>(subject),
      'body': serializer.toJson<String>(body),
      'inReplyTo': serializer.toJson<String?>(inReplyTo),
      'references': serializer.toJson<String?>(references),
      'conversationId': serializer.toJson<String?>(conversationId),
      'attachments': serializer.toJson<List<ForwardedAttachment>?>(attachments),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'pending': serializer.toJson<bool>(pending),
      'synced': serializer.toJson<bool>(synced),
      'remoteKnown': serializer.toJson<bool>(remoteKnown),
    };
  }

  DraftRow copyWith({
    String? accountId,
    String? messageId,
    String? recipients,
    String? cc,
    String? bcc,
    String? subject,
    String? body,
    Value<String?> inReplyTo = const Value.absent(),
    Value<String?> references = const Value.absent(),
    Value<String?> conversationId = const Value.absent(),
    Value<List<ForwardedAttachment>?> attachments = const Value.absent(),
    int? updatedAt,
    bool? pending,
    bool? synced,
    bool? remoteKnown,
  }) => DraftRow(
    accountId: accountId ?? this.accountId,
    messageId: messageId ?? this.messageId,
    recipients: recipients ?? this.recipients,
    cc: cc ?? this.cc,
    bcc: bcc ?? this.bcc,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    inReplyTo: inReplyTo.present ? inReplyTo.value : this.inReplyTo,
    references: references.present ? references.value : this.references,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    attachments: attachments.present ? attachments.value : this.attachments,
    updatedAt: updatedAt ?? this.updatedAt,
    pending: pending ?? this.pending,
    synced: synced ?? this.synced,
    remoteKnown: remoteKnown ?? this.remoteKnown,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipients: data.recipients.present
          ? data.recipients.value
          : this.recipients,
      cc: data.cc.present ? data.cc.value : this.cc,
      bcc: data.bcc.present ? data.bcc.value : this.bcc,
      subject: data.subject.present ? data.subject.value : this.subject,
      body: data.body.present ? data.body.value : this.body,
      inReplyTo: data.inReplyTo.present ? data.inReplyTo.value : this.inReplyTo,
      references: data.references.present
          ? data.references.value
          : this.references,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pending: data.pending.present ? data.pending.value : this.pending,
      synced: data.synced.present ? data.synced.value : this.synced,
      remoteKnown: data.remoteKnown.present
          ? data.remoteKnown.value
          : this.remoteKnown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('recipients: $recipients, ')
          ..write('cc: $cc, ')
          ..write('bcc: $bcc, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('references: $references, ')
          ..write('conversationId: $conversationId, ')
          ..write('attachments: $attachments, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pending: $pending, ')
          ..write('synced: $synced, ')
          ..write('remoteKnown: $remoteKnown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    messageId,
    recipients,
    cc,
    bcc,
    subject,
    body,
    inReplyTo,
    references,
    conversationId,
    attachments,
    updatedAt,
    pending,
    synced,
    remoteKnown,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.accountId == this.accountId &&
          other.messageId == this.messageId &&
          other.recipients == this.recipients &&
          other.cc == this.cc &&
          other.bcc == this.bcc &&
          other.subject == this.subject &&
          other.body == this.body &&
          other.inReplyTo == this.inReplyTo &&
          other.references == this.references &&
          other.conversationId == this.conversationId &&
          other.attachments == this.attachments &&
          other.updatedAt == this.updatedAt &&
          other.pending == this.pending &&
          other.synced == this.synced &&
          other.remoteKnown == this.remoteKnown);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> accountId;
  final Value<String> messageId;
  final Value<String> recipients;
  final Value<String> cc;
  final Value<String> bcc;
  final Value<String> subject;
  final Value<String> body;
  final Value<String?> inReplyTo;
  final Value<String?> references;
  final Value<String?> conversationId;
  final Value<List<ForwardedAttachment>?> attachments;
  final Value<int> updatedAt;
  final Value<bool> pending;
  final Value<bool> synced;
  final Value<bool> remoteKnown;
  final Value<int> rowid;
  const DraftsCompanion({
    this.accountId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.recipients = const Value.absent(),
    this.cc = const Value.absent(),
    this.bcc = const Value.absent(),
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.inReplyTo = const Value.absent(),
    this.references = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.attachments = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pending = const Value.absent(),
    this.synced = const Value.absent(),
    this.remoteKnown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String accountId,
    required String messageId,
    required String recipients,
    required String cc,
    required String bcc,
    required String subject,
    required String body,
    this.inReplyTo = const Value.absent(),
    this.references = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.attachments = const Value.absent(),
    required int updatedAt,
    required bool pending,
    required bool synced,
    required bool remoteKnown,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       messageId = Value(messageId),
       recipients = Value(recipients),
       cc = Value(cc),
       bcc = Value(bcc),
       subject = Value(subject),
       body = Value(body),
       updatedAt = Value(updatedAt),
       pending = Value(pending),
       synced = Value(synced),
       remoteKnown = Value(remoteKnown);
  static Insertable<DraftRow> custom({
    Expression<String>? accountId,
    Expression<String>? messageId,
    Expression<String>? recipients,
    Expression<String>? cc,
    Expression<String>? bcc,
    Expression<String>? subject,
    Expression<String>? body,
    Expression<String>? inReplyTo,
    Expression<String>? references,
    Expression<String>? conversationId,
    Expression<String>? attachments,
    Expression<int>? updatedAt,
    Expression<bool>? pending,
    Expression<bool>? synced,
    Expression<bool>? remoteKnown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (messageId != null) 'message_id': messageId,
      if (recipients != null) 'recipients': recipients,
      if (cc != null) 'cc': cc,
      if (bcc != null) 'bcc': bcc,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (inReplyTo != null) 'in_reply_to': inReplyTo,
      if (references != null) 'references': references,
      if (conversationId != null) 'conversation_id': conversationId,
      if (attachments != null) 'attachments': attachments,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pending != null) 'pending': pending,
      if (synced != null) 'synced': synced,
      if (remoteKnown != null) 'remote_known': remoteKnown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? messageId,
    Value<String>? recipients,
    Value<String>? cc,
    Value<String>? bcc,
    Value<String>? subject,
    Value<String>? body,
    Value<String?>? inReplyTo,
    Value<String?>? references,
    Value<String?>? conversationId,
    Value<List<ForwardedAttachment>?>? attachments,
    Value<int>? updatedAt,
    Value<bool>? pending,
    Value<bool>? synced,
    Value<bool>? remoteKnown,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      accountId: accountId ?? this.accountId,
      messageId: messageId ?? this.messageId,
      recipients: recipients ?? this.recipients,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      references: references ?? this.references,
      conversationId: conversationId ?? this.conversationId,
      attachments: attachments ?? this.attachments,
      updatedAt: updatedAt ?? this.updatedAt,
      pending: pending ?? this.pending,
      synced: synced ?? this.synced,
      remoteKnown: remoteKnown ?? this.remoteKnown,
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
    if (recipients.present) {
      map['recipients'] = Variable<String>(recipients.value);
    }
    if (cc.present) {
      map['cc'] = Variable<String>(cc.value);
    }
    if (bcc.present) {
      map['bcc'] = Variable<String>(bcc.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (inReplyTo.present) {
      map['in_reply_to'] = Variable<String>(inReplyTo.value);
    }
    if (references.present) {
      map['references'] = Variable<String>(references.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(
        $DraftsTable.$converterattachmentsn.toSql(attachments.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (pending.present) {
      map['pending'] = Variable<bool>(pending.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (remoteKnown.present) {
      map['remote_known'] = Variable<bool>(remoteKnown.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('messageId: $messageId, ')
          ..write('recipients: $recipients, ')
          ..write('cc: $cc, ')
          ..write('bcc: $bcc, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('inReplyTo: $inReplyTo, ')
          ..write('references: $references, ')
          ..write('conversationId: $conversationId, ')
          ..write('attachments: $attachments, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pending: $pending, ')
          ..write('synced: $synced, ')
          ..write('remoteKnown: $remoteKnown, ')
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
  late final $BodiesTable bodies = $BodiesTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $IntentsTable intents = $IntentsTable(this);
  late final $TrustedSendersTable trustedSenders = $TrustedSendersTable(this);
  late final $DeviceSettingsTable deviceSettings = $DeviceSettingsTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final Index messagesConversation = Index(
    'messages_conversation',
    'CREATE INDEX messages_conversation ON messages (account_id, conversation_id)',
  );
  late final AccountsDao accountsDao = AccountsDao(this as PostinoDatabase);
  late final MessagesDao messagesDao = MessagesDao(this as PostinoDatabase);
  late final IntentsDao intentsDao = IntentsDao(this as PostinoDatabase);
  late final TrustedSendersDao trustedSendersDao = TrustedSendersDao(
    this as PostinoDatabase,
  );
  late final DeviceSettingsDao deviceSettingsDao = DeviceSettingsDao(
    this as PostinoDatabase,
  );
  late final DraftsDao draftsDao = DraftsDao(this as PostinoDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    labels,
    messages,
    messageLabels,
    bodies,
    syncCursors,
    intents,
    trustedSenders,
    deviceSettings,
    drafts,
    messagesConversation,
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
  Value<String?> senderName,
  required String recipients,
  Value<String> cc,
  Value<String> bcc,
  Value<String?> replyTo,
  Value<String?> references,
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
  Value<String?> senderName,
  Value<String> recipients,
  Value<String> cc,
  Value<String> bcc,
  Value<String?> replyTo,
  Value<String?> references,
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

  ColumnFilters<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cc => $composableBuilder(
    column: $table.cc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bcc => $composableBuilder(
    column: $table.bcc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get references => $composableBuilder(
    column: $table.references,
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

  ColumnOrderings<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cc => $composableBuilder(
    column: $table.cc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bcc => $composableBuilder(
    column: $table.bcc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyTo => $composableBuilder(
    column: $table.replyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get references => $composableBuilder(
    column: $table.references,
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

  GeneratedColumn<String> get senderName => $composableBuilder(
    column: $table.senderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cc =>
      $composableBuilder(column: $table.cc, builder: (column) => column);

  GeneratedColumn<String> get bcc =>
      $composableBuilder(column: $table.bcc, builder: (column) => column);

  GeneratedColumn<String> get replyTo =>
      $composableBuilder(column: $table.replyTo, builder: (column) => column);

  GeneratedColumn<String> get references => $composableBuilder(
    column: $table.references,
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
                Value<String?> senderName = const Value.absent(),
                Value<String> recipients = const Value.absent(),
                Value<String> cc = const Value.absent(),
                Value<String> bcc = const Value.absent(),
                Value<String?> replyTo = const Value.absent(),
                Value<String?> references = const Value.absent(),
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
                senderName: senderName,
                recipients: recipients,
                cc: cc,
                bcc: bcc,
                replyTo: replyTo,
                references: references,
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
                Value<String?> senderName = const Value.absent(),
                required String recipients,
                Value<String> cc = const Value.absent(),
                Value<String> bcc = const Value.absent(),
                Value<String?> replyTo = const Value.absent(),
                Value<String?> references = const Value.absent(),
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
                senderName: senderName,
                recipients: recipients,
                cc: cc,
                bcc: bcc,
                replyTo: replyTo,
                references: references,
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
typedef $$BodiesTableCreateCompanionBuilder = BodiesCompanion Function({
  required String accountId,
  required String messageId,
  required String body,
  Value<BodyKind> kind,
  Value<List<Attachment>?> attachments,
  Value<int> rowid,
});
typedef $$BodiesTableUpdateCompanionBuilder = BodiesCompanion Function({
  Value<String> accountId,
  Value<String> messageId,
  Value<String> body,
  Value<BodyKind> kind,
  Value<List<Attachment>?> attachments,
  Value<int> rowid,
});

class $$BodiesTableFilterComposer
    extends Composer<_$PostinoDatabase, $BodiesTable> {
  $$BodiesTableFilterComposer({
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BodyKind, BodyKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<List<Attachment>?, List<Attachment>, String>
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$BodiesTableOrderingComposer
    extends Composer<_$PostinoDatabase, $BodiesTable> {
  $$BodiesTableOrderingComposer({
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodiesTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $BodiesTable> {
  $$BodiesTableAnnotationComposer({
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

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BodyKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<Attachment>?, String> get attachments =>
      $composableBuilder(
        column: $table.attachments,
        builder: (column) => column,
      );
}

class $$BodiesTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $BodiesTable,
          BodyRow,
          $$BodiesTableFilterComposer,
          $$BodiesTableOrderingComposer,
          $$BodiesTableAnnotationComposer,
          $$BodiesTableCreateCompanionBuilder,
          $$BodiesTableUpdateCompanionBuilder,
          (BodyRow, BaseReferences<_$PostinoDatabase, $BodiesTable, BodyRow>),
          BodyRow,
          PrefetchHooks Function()
        > {
  $$BodiesTableTableManager(_$PostinoDatabase db, $BodiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<BodyKind> kind = const Value.absent(),
                Value<List<Attachment>?> attachments = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodiesCompanion(
                accountId: accountId,
                messageId: messageId,
                body: body,
                kind: kind,
                attachments: attachments,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String messageId,
                required String body,
                Value<BodyKind> kind = const Value.absent(),
                Value<List<Attachment>?> attachments = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodiesCompanion.insert(
                accountId: accountId,
                messageId: messageId,
                body: body,
                kind: kind,
                attachments: attachments,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BodiesTable, BodyRow>(table),
                  BaseReferences<_$PostinoDatabase, $BodiesTable, BodyRow>(
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

typedef $$BodiesTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $BodiesTable,
      BodyRow,
      $$BodiesTableFilterComposer,
      $$BodiesTableOrderingComposer,
      $$BodiesTableAnnotationComposer,
      $$BodiesTableCreateCompanionBuilder,
      $$BodiesTableUpdateCompanionBuilder,
      (BodyRow, BaseReferences<_$PostinoDatabase, $BodiesTable, BodyRow>),
      BodyRow,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String accountId,
      required String cursor,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> accountId,
      Value<String> cursor,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$PostinoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
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

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
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

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $SyncCursorsTable,
          SyncCursorRow,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<_$PostinoDatabase, $SyncCursorsTable, SyncCursorRow>,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$PostinoDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> cursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                accountId: accountId,
                cursor: cursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String cursor,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                accountId: accountId,
                cursor: cursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursorRow>(table),
                  BaseReferences<
                    _$PostinoDatabase,
                    $SyncCursorsTable,
                    SyncCursorRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $SyncCursorsTable,
      SyncCursorRow,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$PostinoDatabase, $SyncCursorsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;
typedef $$IntentsTableCreateCompanionBuilder = IntentsCompanion Function({
  required String accountId,
  required String messageId,
  Value<bool?> isRead,
  Value<int> rowid,
});
typedef $$IntentsTableUpdateCompanionBuilder = IntentsCompanion Function({
  Value<String> accountId,
  Value<String> messageId,
  Value<bool?> isRead,
  Value<int> rowid,
});

class $$IntentsTableFilterComposer
    extends Composer<_$PostinoDatabase, $IntentsTable> {
  $$IntentsTableFilterComposer({
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

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntentsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $IntentsTable> {
  $$IntentsTableOrderingComposer({
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

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntentsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $IntentsTable> {
  $$IntentsTableAnnotationComposer({
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

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);
}

class $$IntentsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $IntentsTable,
          IntentRow,
          $$IntentsTableFilterComposer,
          $$IntentsTableOrderingComposer,
          $$IntentsTableAnnotationComposer,
          $$IntentsTableCreateCompanionBuilder,
          $$IntentsTableUpdateCompanionBuilder,
          (
            IntentRow,
            BaseReferences<_$PostinoDatabase, $IntentsTable, IntentRow>,
          ),
          IntentRow,
          PrefetchHooks Function()
        > {
  $$IntentsTableTableManager(_$PostinoDatabase db, $IntentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<bool?> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntentsCompanion(
                accountId: accountId,
                messageId: messageId,
                isRead: isRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String messageId,
                Value<bool?> isRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntentsCompanion.insert(
                accountId: accountId,
                messageId: messageId,
                isRead: isRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IntentsTable, IntentRow>(table),
                  BaseReferences<_$PostinoDatabase, $IntentsTable, IntentRow>(
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

typedef $$IntentsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $IntentsTable,
      IntentRow,
      $$IntentsTableFilterComposer,
      $$IntentsTableOrderingComposer,
      $$IntentsTableAnnotationComposer,
      $$IntentsTableCreateCompanionBuilder,
      $$IntentsTableUpdateCompanionBuilder,
      (IntentRow, BaseReferences<_$PostinoDatabase, $IntentsTable, IntentRow>),
      IntentRow,
      PrefetchHooks Function()
    >;
typedef $$TrustedSendersTableCreateCompanionBuilder =
    TrustedSendersCompanion Function({
      required String address,
      Value<int> rowid,
    });
typedef $$TrustedSendersTableUpdateCompanionBuilder =
    TrustedSendersCompanion Function({Value<String> address, Value<int> rowid});

class $$TrustedSendersTableFilterComposer
    extends Composer<_$PostinoDatabase, $TrustedSendersTable> {
  $$TrustedSendersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrustedSendersTableOrderingComposer
    extends Composer<_$PostinoDatabase, $TrustedSendersTable> {
  $$TrustedSendersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrustedSendersTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $TrustedSendersTable> {
  $$TrustedSendersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);
}

class $$TrustedSendersTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $TrustedSendersTable,
          TrustedSenderRow,
          $$TrustedSendersTableFilterComposer,
          $$TrustedSendersTableOrderingComposer,
          $$TrustedSendersTableAnnotationComposer,
          $$TrustedSendersTableCreateCompanionBuilder,
          $$TrustedSendersTableUpdateCompanionBuilder,
          (
            TrustedSenderRow,
            BaseReferences<
              _$PostinoDatabase,
              $TrustedSendersTable,
              TrustedSenderRow
            >,
          ),
          TrustedSenderRow,
          PrefetchHooks Function()
        > {
  $$TrustedSendersTableTableManager(
    _$PostinoDatabase db,
    $TrustedSendersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrustedSendersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrustedSendersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrustedSendersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> address = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => TrustedSendersCompanion(address: address, rowid: rowid),
          createCompanionCallback: ({
            required String address,
            Value<int> rowid = const Value.absent(),
          }) => TrustedSendersCompanion.insert(address: address, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrustedSendersTable, TrustedSenderRow>(table),
                  BaseReferences<
                    _$PostinoDatabase,
                    $TrustedSendersTable,
                    TrustedSenderRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrustedSendersTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $TrustedSendersTable,
      TrustedSenderRow,
      $$TrustedSendersTableFilterComposer,
      $$TrustedSendersTableOrderingComposer,
      $$TrustedSendersTableAnnotationComposer,
      $$TrustedSendersTableCreateCompanionBuilder,
      $$TrustedSendersTableUpdateCompanionBuilder,
      (
        TrustedSenderRow,
        BaseReferences<
          _$PostinoDatabase,
          $TrustedSendersTable,
          TrustedSenderRow
        >,
      ),
      TrustedSenderRow,
      PrefetchHooks Function()
    >;
typedef $$DeviceSettingsTableCreateCompanionBuilder =
    DeviceSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DeviceSettingsTableUpdateCompanionBuilder =
    DeviceSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DeviceSettingsTableFilterComposer
    extends Composer<_$PostinoDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableFilterComposer({
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
}

class $$DeviceSettingsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableOrderingComposer({
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
}

class $$DeviceSettingsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $DeviceSettingsTable> {
  $$DeviceSettingsTableAnnotationComposer({
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
}

class $$DeviceSettingsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $DeviceSettingsTable,
          DeviceSettingRow,
          $$DeviceSettingsTableFilterComposer,
          $$DeviceSettingsTableOrderingComposer,
          $$DeviceSettingsTableAnnotationComposer,
          $$DeviceSettingsTableCreateCompanionBuilder,
          $$DeviceSettingsTableUpdateCompanionBuilder,
          (
            DeviceSettingRow,
            BaseReferences<
              _$PostinoDatabase,
              $DeviceSettingsTable,
              DeviceSettingRow
            >,
          ),
          DeviceSettingRow,
          PrefetchHooks Function()
        > {
  $$DeviceSettingsTableTableManager(
    _$PostinoDatabase db,
    $DeviceSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DeviceSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceSettingsTable, DeviceSettingRow>(table),
                  BaseReferences<
                    _$PostinoDatabase,
                    $DeviceSettingsTable,
                    DeviceSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $DeviceSettingsTable,
      DeviceSettingRow,
      $$DeviceSettingsTableFilterComposer,
      $$DeviceSettingsTableOrderingComposer,
      $$DeviceSettingsTableAnnotationComposer,
      $$DeviceSettingsTableCreateCompanionBuilder,
      $$DeviceSettingsTableUpdateCompanionBuilder,
      (
        DeviceSettingRow,
        BaseReferences<
          _$PostinoDatabase,
          $DeviceSettingsTable,
          DeviceSettingRow
        >,
      ),
      DeviceSettingRow,
      PrefetchHooks Function()
    >;
typedef $$DraftsTableCreateCompanionBuilder = DraftsCompanion Function({
  required String accountId,
  required String messageId,
  required String recipients,
  required String cc,
  required String bcc,
  required String subject,
  required String body,
  Value<String?> inReplyTo,
  Value<String?> references,
  Value<String?> conversationId,
  Value<List<ForwardedAttachment>?> attachments,
  required int updatedAt,
  required bool pending,
  required bool synced,
  required bool remoteKnown,
  Value<int> rowid,
});
typedef $$DraftsTableUpdateCompanionBuilder = DraftsCompanion Function({
  Value<String> accountId,
  Value<String> messageId,
  Value<String> recipients,
  Value<String> cc,
  Value<String> bcc,
  Value<String> subject,
  Value<String> body,
  Value<String?> inReplyTo,
  Value<String?> references,
  Value<String?> conversationId,
  Value<List<ForwardedAttachment>?> attachments,
  Value<int> updatedAt,
  Value<bool> pending,
  Value<bool> synced,
  Value<bool> remoteKnown,
  Value<int> rowid,
});

class $$DraftsTableFilterComposer
    extends Composer<_$PostinoDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
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

  ColumnFilters<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cc => $composableBuilder(
    column: $table.cc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bcc => $composableBuilder(
    column: $table.bcc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    List<ForwardedAttachment>?,
    List<ForwardedAttachment>,
    String
  >
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get remoteKnown => $composableBuilder(
    column: $table.remoteKnown,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftsTableOrderingComposer
    extends Composer<_$PostinoDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
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

  ColumnOrderings<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cc => $composableBuilder(
    column: $table.cc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bcc => $composableBuilder(
    column: $table.bcc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inReplyTo => $composableBuilder(
    column: $table.inReplyTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get remoteKnown => $composableBuilder(
    column: $table.remoteKnown,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$PostinoDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
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

  GeneratedColumn<String> get recipients => $composableBuilder(
    column: $table.recipients,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cc =>
      $composableBuilder(column: $table.cc, builder: (column) => column);

  GeneratedColumn<String> get bcc =>
      $composableBuilder(column: $table.bcc, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get inReplyTo =>
      $composableBuilder(column: $table.inReplyTo, builder: (column) => column);

  GeneratedColumn<String> get references => $composableBuilder(
    column: $table.references,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<ForwardedAttachment>?, String>
  get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<bool> get remoteKnown => $composableBuilder(
    column: $table.remoteKnown,
    builder: (column) => column,
  );
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$PostinoDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, BaseReferences<_$PostinoDatabase, $DraftsTable, DraftRow>),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftsTableTableManager(_$PostinoDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> recipients = const Value.absent(),
                Value<String> cc = const Value.absent(),
                Value<String> bcc = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> references = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<List<ForwardedAttachment>?> attachments =
                    const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> pending = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<bool> remoteKnown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                accountId: accountId,
                messageId: messageId,
                recipients: recipients,
                cc: cc,
                bcc: bcc,
                subject: subject,
                body: body,
                inReplyTo: inReplyTo,
                references: references,
                conversationId: conversationId,
                attachments: attachments,
                updatedAt: updatedAt,
                pending: pending,
                synced: synced,
                remoteKnown: remoteKnown,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String messageId,
                required String recipients,
                required String cc,
                required String bcc,
                required String subject,
                required String body,
                Value<String?> inReplyTo = const Value.absent(),
                Value<String?> references = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<List<ForwardedAttachment>?> attachments =
                    const Value.absent(),
                required int updatedAt,
                required bool pending,
                required bool synced,
                required bool remoteKnown,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                accountId: accountId,
                messageId: messageId,
                recipients: recipients,
                cc: cc,
                bcc: bcc,
                subject: subject,
                body: body,
                inReplyTo: inReplyTo,
                references: references,
                conversationId: conversationId,
                attachments: attachments,
                updatedAt: updatedAt,
                pending: pending,
                synced: synced,
                remoteKnown: remoteKnown,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DraftsTable, DraftRow>(table),
                  BaseReferences<_$PostinoDatabase, $DraftsTable, DraftRow>(
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

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$PostinoDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$PostinoDatabase, $DraftsTable, DraftRow>),
      DraftRow,
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
  $$BodiesTableTableManager get bodies =>
      $$BodiesTableTableManager(_db, _db.bodies);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$IntentsTableTableManager get intents =>
      $$IntentsTableTableManager(_db, _db.intents);
  $$TrustedSendersTableTableManager get trustedSenders =>
      $$TrustedSendersTableTableManager(_db, _db.trustedSenders);
  $$DeviceSettingsTableTableManager get deviceSettings =>
      $$DeviceSettingsTableTableManager(_db, _db.deviceSettings);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
}
