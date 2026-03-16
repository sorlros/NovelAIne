// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $StoriesTable extends Stories with TableInfo<$StoriesTable, Story> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _totalScenesMeta = const VerificationMeta(
    'totalScenes',
  );
  @override
  late final GeneratedColumn<int> totalScenes = GeneratedColumn<int>(
    'total_scenes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _coverImageUrlMeta = const VerificationMeta(
    'coverImageUrl',
  );
  @override
  late final GeneratedColumn<String> coverImageUrl = GeneratedColumn<String>(
    'cover_image_url',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    genre,
    status,
    totalScenes,
    coverImageUrl,
    createdAt,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Story> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('total_scenes')) {
      context.handle(
        _totalScenesMeta,
        totalScenes.isAcceptableOrUnknown(
          data['total_scenes']!,
          _totalScenesMeta,
        ),
      );
    }
    if (data.containsKey('cover_image_url')) {
      context.handle(
        _coverImageUrlMeta,
        coverImageUrl.isAcceptableOrUnknown(
          data['cover_image_url']!,
          _coverImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Story map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Story(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      totalScenes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_scenes'],
      )!,
      coverImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_image_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
    );
  }

  @override
  $StoriesTable createAlias(String alias) {
    return $StoriesTable(attachedDatabase, alias);
  }
}

class Story extends DataClass implements Insertable<Story> {
  final String id;
  final String title;
  final String? description;
  final String? genre;
  final String status;
  final int totalScenes;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String? userId;
  const Story({
    required this.id,
    required this.title,
    this.description,
    this.genre,
    required this.status,
    required this.totalScenes,
    this.coverImageUrl,
    required this.createdAt,
    this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['status'] = Variable<String>(status);
    map['total_scenes'] = Variable<int>(totalScenes);
    if (!nullToAbsent || coverImageUrl != null) {
      map['cover_image_url'] = Variable<String>(coverImageUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    return map;
  }

  StoriesCompanion toCompanion(bool nullToAbsent) {
    return StoriesCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      status: Value(status),
      totalScenes: Value(totalScenes),
      coverImageUrl: coverImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverImageUrl),
      createdAt: Value(createdAt),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
    );
  }

  factory Story.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Story(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      genre: serializer.fromJson<String?>(json['genre']),
      status: serializer.fromJson<String>(json['status']),
      totalScenes: serializer.fromJson<int>(json['totalScenes']),
      coverImageUrl: serializer.fromJson<String?>(json['coverImageUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      userId: serializer.fromJson<String?>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'genre': serializer.toJson<String?>(genre),
      'status': serializer.toJson<String>(status),
      'totalScenes': serializer.toJson<int>(totalScenes),
      'coverImageUrl': serializer.toJson<String?>(coverImageUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'userId': serializer.toJson<String?>(userId),
    };
  }

  Story copyWith({
    String? id,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    String? status,
    int? totalScenes,
    Value<String?> coverImageUrl = const Value.absent(),
    DateTime? createdAt,
    Value<String?> userId = const Value.absent(),
  }) => Story(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    genre: genre.present ? genre.value : this.genre,
    status: status ?? this.status,
    totalScenes: totalScenes ?? this.totalScenes,
    coverImageUrl: coverImageUrl.present
        ? coverImageUrl.value
        : this.coverImageUrl,
    createdAt: createdAt ?? this.createdAt,
    userId: userId.present ? userId.value : this.userId,
  );
  Story copyWithCompanion(StoriesCompanion data) {
    return Story(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      genre: data.genre.present ? data.genre.value : this.genre,
      status: data.status.present ? data.status.value : this.status,
      totalScenes: data.totalScenes.present
          ? data.totalScenes.value
          : this.totalScenes,
      coverImageUrl: data.coverImageUrl.present
          ? data.coverImageUrl.value
          : this.coverImageUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Story(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genre: $genre, ')
          ..write('status: $status, ')
          ..write('totalScenes: $totalScenes, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    genre,
    status,
    totalScenes,
    coverImageUrl,
    createdAt,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Story &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.genre == this.genre &&
          other.status == this.status &&
          other.totalScenes == this.totalScenes &&
          other.coverImageUrl == this.coverImageUrl &&
          other.createdAt == this.createdAt &&
          other.userId == this.userId);
}

class StoriesCompanion extends UpdateCompanion<Story> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> genre;
  final Value<String> status;
  final Value<int> totalScenes;
  final Value<String?> coverImageUrl;
  final Value<DateTime> createdAt;
  final Value<String?> userId;
  final Value<int> rowid;
  const StoriesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.genre = const Value.absent(),
    this.status = const Value.absent(),
    this.totalScenes = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoriesCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.genre = const Value.absent(),
    this.status = const Value.absent(),
    this.totalScenes = const Value.absent(),
    this.coverImageUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<Story> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? genre,
    Expression<String>? status,
    Expression<int>? totalScenes,
    Expression<String>? coverImageUrl,
    Expression<DateTime>? createdAt,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (genre != null) 'genre': genre,
      if (status != null) 'status': status,
      if (totalScenes != null) 'total_scenes': totalScenes,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<String?>? genre,
    Value<String>? status,
    Value<int>? totalScenes,
    Value<String?>? coverImageUrl,
    Value<DateTime>? createdAt,
    Value<String?>? userId,
    Value<int>? rowid,
  }) {
    return StoriesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      status: status ?? this.status,
      totalScenes: totalScenes ?? this.totalScenes,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (totalScenes.present) {
      map['total_scenes'] = Variable<int>(totalScenes.value);
    }
    if (coverImageUrl.present) {
      map['cover_image_url'] = Variable<String>(coverImageUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoriesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('genre: $genre, ')
          ..write('status: $status, ')
          ..write('totalScenes: $totalScenes, ')
          ..write('coverImageUrl: $coverImageUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CharactersTable extends Characters
    with TableInfo<$CharactersTable, Character> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CharactersTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personalityTraitsMeta = const VerificationMeta(
    'personalityTraits',
  );
  @override
  late final GeneratedColumn<String> personalityTraits =
      GeneratedColumn<String>(
        'personality_traits',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _appearanceDescriptionMeta =
      const VerificationMeta('appearanceDescription');
  @override
  late final GeneratedColumn<String> appearanceDescription =
      GeneratedColumn<String>(
        'appearance_description',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _backgroundStoryMeta = const VerificationMeta(
    'backgroundStory',
  );
  @override
  late final GeneratedColumn<String> backgroundStory = GeneratedColumn<String>(
    'background_story',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    imageUrl,
    personalityTraits,
    appearanceDescription,
    backgroundStory,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Character> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('personality_traits')) {
      context.handle(
        _personalityTraitsMeta,
        personalityTraits.isAcceptableOrUnknown(
          data['personality_traits']!,
          _personalityTraitsMeta,
        ),
      );
    }
    if (data.containsKey('appearance_description')) {
      context.handle(
        _appearanceDescriptionMeta,
        appearanceDescription.isAcceptableOrUnknown(
          data['appearance_description']!,
          _appearanceDescriptionMeta,
        ),
      );
    }
    if (data.containsKey('background_story')) {
      context.handle(
        _backgroundStoryMeta,
        backgroundStory.isAcceptableOrUnknown(
          data['background_story']!,
          _backgroundStoryMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Character map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Character(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      personalityTraits: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personality_traits'],
      ),
      appearanceDescription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}appearance_description'],
      ),
      backgroundStory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_story'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
    );
  }

  @override
  $CharactersTable createAlias(String alias) {
    return $CharactersTable(attachedDatabase, alias);
  }
}

class Character extends DataClass implements Insertable<Character> {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? personalityTraits;
  final String? appearanceDescription;
  final String? backgroundStory;
  final String? userId;
  const Character({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.personalityTraits,
    this.appearanceDescription,
    this.backgroundStory,
    this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || personalityTraits != null) {
      map['personality_traits'] = Variable<String>(personalityTraits);
    }
    if (!nullToAbsent || appearanceDescription != null) {
      map['appearance_description'] = Variable<String>(appearanceDescription);
    }
    if (!nullToAbsent || backgroundStory != null) {
      map['background_story'] = Variable<String>(backgroundStory);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    return map;
  }

  CharactersCompanion toCompanion(bool nullToAbsent) {
    return CharactersCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      personalityTraits: personalityTraits == null && nullToAbsent
          ? const Value.absent()
          : Value(personalityTraits),
      appearanceDescription: appearanceDescription == null && nullToAbsent
          ? const Value.absent()
          : Value(appearanceDescription),
      backgroundStory: backgroundStory == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundStory),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
    );
  }

  factory Character.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Character(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      personalityTraits: serializer.fromJson<String?>(
        json['personalityTraits'],
      ),
      appearanceDescription: serializer.fromJson<String?>(
        json['appearanceDescription'],
      ),
      backgroundStory: serializer.fromJson<String?>(json['backgroundStory']),
      userId: serializer.fromJson<String?>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'personalityTraits': serializer.toJson<String?>(personalityTraits),
      'appearanceDescription': serializer.toJson<String?>(
        appearanceDescription,
      ),
      'backgroundStory': serializer.toJson<String?>(backgroundStory),
      'userId': serializer.toJson<String?>(userId),
    };
  }

  Character copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> personalityTraits = const Value.absent(),
    Value<String?> appearanceDescription = const Value.absent(),
    Value<String?> backgroundStory = const Value.absent(),
    Value<String?> userId = const Value.absent(),
  }) => Character(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    personalityTraits: personalityTraits.present
        ? personalityTraits.value
        : this.personalityTraits,
    appearanceDescription: appearanceDescription.present
        ? appearanceDescription.value
        : this.appearanceDescription,
    backgroundStory: backgroundStory.present
        ? backgroundStory.value
        : this.backgroundStory,
    userId: userId.present ? userId.value : this.userId,
  );
  Character copyWithCompanion(CharactersCompanion data) {
    return Character(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      personalityTraits: data.personalityTraits.present
          ? data.personalityTraits.value
          : this.personalityTraits,
      appearanceDescription: data.appearanceDescription.present
          ? data.appearanceDescription.value
          : this.appearanceDescription,
      backgroundStory: data.backgroundStory.present
          ? data.backgroundStory.value
          : this.backgroundStory,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Character(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('personalityTraits: $personalityTraits, ')
          ..write('appearanceDescription: $appearanceDescription, ')
          ..write('backgroundStory: $backgroundStory, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    imageUrl,
    personalityTraits,
    appearanceDescription,
    backgroundStory,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Character &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.imageUrl == this.imageUrl &&
          other.personalityTraits == this.personalityTraits &&
          other.appearanceDescription == this.appearanceDescription &&
          other.backgroundStory == this.backgroundStory &&
          other.userId == this.userId);
}

class CharactersCompanion extends UpdateCompanion<Character> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> imageUrl;
  final Value<String?> personalityTraits;
  final Value<String?> appearanceDescription;
  final Value<String?> backgroundStory;
  final Value<String?> userId;
  final Value<int> rowid;
  const CharactersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.personalityTraits = const Value.absent(),
    this.appearanceDescription = const Value.absent(),
    this.backgroundStory = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CharactersCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.personalityTraits = const Value.absent(),
    this.appearanceDescription = const Value.absent(),
    this.backgroundStory = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Character> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? imageUrl,
    Expression<String>? personalityTraits,
    Expression<String>? appearanceDescription,
    Expression<String>? backgroundStory,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (personalityTraits != null) 'personality_traits': personalityTraits,
      if (appearanceDescription != null)
        'appearance_description': appearanceDescription,
      if (backgroundStory != null) 'background_story': backgroundStory,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CharactersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? imageUrl,
    Value<String?>? personalityTraits,
    Value<String?>? appearanceDescription,
    Value<String?>? backgroundStory,
    Value<String?>? userId,
    Value<int>? rowid,
  }) {
    return CharactersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      personalityTraits: personalityTraits ?? this.personalityTraits,
      appearanceDescription:
          appearanceDescription ?? this.appearanceDescription,
      backgroundStory: backgroundStory ?? this.backgroundStory,
      userId: userId ?? this.userId,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (personalityTraits.present) {
      map['personality_traits'] = Variable<String>(personalityTraits.value);
    }
    if (appearanceDescription.present) {
      map['appearance_description'] = Variable<String>(
        appearanceDescription.value,
      );
    }
    if (backgroundStory.present) {
      map['background_story'] = Variable<String>(backgroundStory.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CharactersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('personalityTraits: $personalityTraits, ')
          ..write('appearanceDescription: $appearanceDescription, ')
          ..write('backgroundStory: $backgroundStory, ')
          ..write('userId: $userId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryCharactersTable extends StoryCharacters
    with TableInfo<$StoryCharactersTable, StoryCharacter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryCharactersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<String> storyId = GeneratedColumn<String>(
    'story_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _characterIdMeta = const VerificationMeta(
    'characterId',
  );
  @override
  late final GeneratedColumn<String> characterId = GeneratedColumn<String>(
    'character_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES characters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleInStoryMeta = const VerificationMeta(
    'roleInStory',
  );
  @override
  late final GeneratedColumn<String> roleInStory = GeneratedColumn<String>(
    'role_in_story',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [storyId, characterId, roleInStory];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_characters';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoryCharacter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storyIdMeta);
    }
    if (data.containsKey('character_id')) {
      context.handle(
        _characterIdMeta,
        characterId.isAcceptableOrUnknown(
          data['character_id']!,
          _characterIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_characterIdMeta);
    }
    if (data.containsKey('role_in_story')) {
      context.handle(
        _roleInStoryMeta,
        roleInStory.isAcceptableOrUnknown(
          data['role_in_story']!,
          _roleInStoryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storyId, characterId};
  @override
  StoryCharacter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryCharacter(
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_id'],
      )!,
      characterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}character_id'],
      )!,
      roleInStory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_in_story'],
      ),
    );
  }

  @override
  $StoryCharactersTable createAlias(String alias) {
    return $StoryCharactersTable(attachedDatabase, alias);
  }
}

class StoryCharacter extends DataClass implements Insertable<StoryCharacter> {
  final String storyId;
  final String characterId;
  final String? roleInStory;
  const StoryCharacter({
    required this.storyId,
    required this.characterId,
    this.roleInStory,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['story_id'] = Variable<String>(storyId);
    map['character_id'] = Variable<String>(characterId);
    if (!nullToAbsent || roleInStory != null) {
      map['role_in_story'] = Variable<String>(roleInStory);
    }
    return map;
  }

  StoryCharactersCompanion toCompanion(bool nullToAbsent) {
    return StoryCharactersCompanion(
      storyId: Value(storyId),
      characterId: Value(characterId),
      roleInStory: roleInStory == null && nullToAbsent
          ? const Value.absent()
          : Value(roleInStory),
    );
  }

  factory StoryCharacter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryCharacter(
      storyId: serializer.fromJson<String>(json['storyId']),
      characterId: serializer.fromJson<String>(json['characterId']),
      roleInStory: serializer.fromJson<String?>(json['roleInStory']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storyId': serializer.toJson<String>(storyId),
      'characterId': serializer.toJson<String>(characterId),
      'roleInStory': serializer.toJson<String?>(roleInStory),
    };
  }

  StoryCharacter copyWith({
    String? storyId,
    String? characterId,
    Value<String?> roleInStory = const Value.absent(),
  }) => StoryCharacter(
    storyId: storyId ?? this.storyId,
    characterId: characterId ?? this.characterId,
    roleInStory: roleInStory.present ? roleInStory.value : this.roleInStory,
  );
  StoryCharacter copyWithCompanion(StoryCharactersCompanion data) {
    return StoryCharacter(
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
      characterId: data.characterId.present
          ? data.characterId.value
          : this.characterId,
      roleInStory: data.roleInStory.present
          ? data.roleInStory.value
          : this.roleInStory,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryCharacter(')
          ..write('storyId: $storyId, ')
          ..write('characterId: $characterId, ')
          ..write('roleInStory: $roleInStory')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(storyId, characterId, roleInStory);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryCharacter &&
          other.storyId == this.storyId &&
          other.characterId == this.characterId &&
          other.roleInStory == this.roleInStory);
}

class StoryCharactersCompanion extends UpdateCompanion<StoryCharacter> {
  final Value<String> storyId;
  final Value<String> characterId;
  final Value<String?> roleInStory;
  final Value<int> rowid;
  const StoryCharactersCompanion({
    this.storyId = const Value.absent(),
    this.characterId = const Value.absent(),
    this.roleInStory = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryCharactersCompanion.insert({
    required String storyId,
    required String characterId,
    this.roleInStory = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : storyId = Value(storyId),
       characterId = Value(characterId);
  static Insertable<StoryCharacter> custom({
    Expression<String>? storyId,
    Expression<String>? characterId,
    Expression<String>? roleInStory,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storyId != null) 'story_id': storyId,
      if (characterId != null) 'character_id': characterId,
      if (roleInStory != null) 'role_in_story': roleInStory,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryCharactersCompanion copyWith({
    Value<String>? storyId,
    Value<String>? characterId,
    Value<String?>? roleInStory,
    Value<int>? rowid,
  }) {
    return StoryCharactersCompanion(
      storyId: storyId ?? this.storyId,
      characterId: characterId ?? this.characterId,
      roleInStory: roleInStory ?? this.roleInStory,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storyId.present) {
      map['story_id'] = Variable<String>(storyId.value);
    }
    if (characterId.present) {
      map['character_id'] = Variable<String>(characterId.value);
    }
    if (roleInStory.present) {
      map['role_in_story'] = Variable<String>(roleInStory.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryCharactersCompanion(')
          ..write('storyId: $storyId, ')
          ..write('characterId: $characterId, ')
          ..write('roleInStory: $roleInStory, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScenesTable extends Scenes with TableInfo<$ScenesTable, Scene> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScenesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storyIdMeta = const VerificationMeta(
    'storyId',
  );
  @override
  late final GeneratedColumn<String> storyId = GeneratedColumn<String>(
    'story_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stories (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sceneTypeMeta = const VerificationMeta(
    'sceneType',
  );
  @override
  late final GeneratedColumn<String> sceneType = GeneratedColumn<String>(
    'scene_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('narrative'),
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bgmUrlMeta = const VerificationMeta('bgmUrl');
  @override
  late final GeneratedColumn<String> bgmUrl = GeneratedColumn<String>(
    'bgm_url',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storyId,
    sequence,
    content,
    sceneType,
    imageUrl,
    bgmUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scenes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Scene> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('story_id')) {
      context.handle(
        _storyIdMeta,
        storyId.isAcceptableOrUnknown(data['story_id']!, _storyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_storyIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('scene_type')) {
      context.handle(
        _sceneTypeMeta,
        sceneType.isAcceptableOrUnknown(data['scene_type']!, _sceneTypeMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('bgm_url')) {
      context.handle(
        _bgmUrlMeta,
        bgmUrl.isAcceptableOrUnknown(data['bgm_url']!, _bgmUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Scene map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Scene(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      storyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}story_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sceneType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scene_type'],
      )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      bgmUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bgm_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ScenesTable createAlias(String alias) {
    return $ScenesTable(attachedDatabase, alias);
  }
}

class Scene extends DataClass implements Insertable<Scene> {
  final String id;
  final String storyId;
  final int sequence;
  final String content;
  final String sceneType;
  final String? imageUrl;
  final String? bgmUrl;
  final DateTime createdAt;
  const Scene({
    required this.id,
    required this.storyId,
    required this.sequence,
    required this.content,
    required this.sceneType,
    this.imageUrl,
    this.bgmUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['story_id'] = Variable<String>(storyId);
    map['sequence'] = Variable<int>(sequence);
    map['content'] = Variable<String>(content);
    map['scene_type'] = Variable<String>(sceneType);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || bgmUrl != null) {
      map['bgm_url'] = Variable<String>(bgmUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ScenesCompanion toCompanion(bool nullToAbsent) {
    return ScenesCompanion(
      id: Value(id),
      storyId: Value(storyId),
      sequence: Value(sequence),
      content: Value(content),
      sceneType: Value(sceneType),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      bgmUrl: bgmUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(bgmUrl),
      createdAt: Value(createdAt),
    );
  }

  factory Scene.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Scene(
      id: serializer.fromJson<String>(json['id']),
      storyId: serializer.fromJson<String>(json['storyId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      content: serializer.fromJson<String>(json['content']),
      sceneType: serializer.fromJson<String>(json['sceneType']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      bgmUrl: serializer.fromJson<String?>(json['bgmUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'storyId': serializer.toJson<String>(storyId),
      'sequence': serializer.toJson<int>(sequence),
      'content': serializer.toJson<String>(content),
      'sceneType': serializer.toJson<String>(sceneType),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'bgmUrl': serializer.toJson<String?>(bgmUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Scene copyWith({
    String? id,
    String? storyId,
    int? sequence,
    String? content,
    String? sceneType,
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> bgmUrl = const Value.absent(),
    DateTime? createdAt,
  }) => Scene(
    id: id ?? this.id,
    storyId: storyId ?? this.storyId,
    sequence: sequence ?? this.sequence,
    content: content ?? this.content,
    sceneType: sceneType ?? this.sceneType,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    bgmUrl: bgmUrl.present ? bgmUrl.value : this.bgmUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  Scene copyWithCompanion(ScenesCompanion data) {
    return Scene(
      id: data.id.present ? data.id.value : this.id,
      storyId: data.storyId.present ? data.storyId.value : this.storyId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      content: data.content.present ? data.content.value : this.content,
      sceneType: data.sceneType.present ? data.sceneType.value : this.sceneType,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      bgmUrl: data.bgmUrl.present ? data.bgmUrl.value : this.bgmUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Scene(')
          ..write('id: $id, ')
          ..write('storyId: $storyId, ')
          ..write('sequence: $sequence, ')
          ..write('content: $content, ')
          ..write('sceneType: $sceneType, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bgmUrl: $bgmUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storyId,
    sequence,
    content,
    sceneType,
    imageUrl,
    bgmUrl,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Scene &&
          other.id == this.id &&
          other.storyId == this.storyId &&
          other.sequence == this.sequence &&
          other.content == this.content &&
          other.sceneType == this.sceneType &&
          other.imageUrl == this.imageUrl &&
          other.bgmUrl == this.bgmUrl &&
          other.createdAt == this.createdAt);
}

class ScenesCompanion extends UpdateCompanion<Scene> {
  final Value<String> id;
  final Value<String> storyId;
  final Value<int> sequence;
  final Value<String> content;
  final Value<String> sceneType;
  final Value<String?> imageUrl;
  final Value<String?> bgmUrl;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ScenesCompanion({
    this.id = const Value.absent(),
    this.storyId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.content = const Value.absent(),
    this.sceneType = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.bgmUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScenesCompanion.insert({
    required String id,
    required String storyId,
    required int sequence,
    required String content,
    this.sceneType = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.bgmUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       storyId = Value(storyId),
       sequence = Value(sequence),
       content = Value(content);
  static Insertable<Scene> custom({
    Expression<String>? id,
    Expression<String>? storyId,
    Expression<int>? sequence,
    Expression<String>? content,
    Expression<String>? sceneType,
    Expression<String>? imageUrl,
    Expression<String>? bgmUrl,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storyId != null) 'story_id': storyId,
      if (sequence != null) 'sequence': sequence,
      if (content != null) 'content': content,
      if (sceneType != null) 'scene_type': sceneType,
      if (imageUrl != null) 'image_url': imageUrl,
      if (bgmUrl != null) 'bgm_url': bgmUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScenesCompanion copyWith({
    Value<String>? id,
    Value<String>? storyId,
    Value<int>? sequence,
    Value<String>? content,
    Value<String>? sceneType,
    Value<String?>? imageUrl,
    Value<String?>? bgmUrl,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ScenesCompanion(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      sequence: sequence ?? this.sequence,
      content: content ?? this.content,
      sceneType: sceneType ?? this.sceneType,
      imageUrl: imageUrl ?? this.imageUrl,
      bgmUrl: bgmUrl ?? this.bgmUrl,
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
    if (storyId.present) {
      map['story_id'] = Variable<String>(storyId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sceneType.present) {
      map['scene_type'] = Variable<String>(sceneType.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (bgmUrl.present) {
      map['bgm_url'] = Variable<String>(bgmUrl.value);
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
    return (StringBuffer('ScenesCompanion(')
          ..write('id: $id, ')
          ..write('storyId: $storyId, ')
          ..write('sequence: $sequence, ')
          ..write('content: $content, ')
          ..write('sceneType: $sceneType, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('bgmUrl: $bgmUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StoriesTable stories = $StoriesTable(this);
  late final $CharactersTable characters = $CharactersTable(this);
  late final $StoryCharactersTable storyCharacters = $StoryCharactersTable(
    this,
  );
  late final $ScenesTable scenes = $ScenesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stories,
    characters,
    storyCharacters,
    scenes,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('story_characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'characters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('story_characters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'stories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scenes', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$StoriesTableCreateCompanionBuilder =
    StoriesCompanion Function({
      required String id,
      required String title,
      Value<String?> description,
      Value<String?> genre,
      Value<String> status,
      Value<int> totalScenes,
      Value<String?> coverImageUrl,
      Value<DateTime> createdAt,
      Value<String?> userId,
      Value<int> rowid,
    });
typedef $$StoriesTableUpdateCompanionBuilder =
    StoriesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> description,
      Value<String?> genre,
      Value<String> status,
      Value<int> totalScenes,
      Value<String?> coverImageUrl,
      Value<DateTime> createdAt,
      Value<String?> userId,
      Value<int> rowid,
    });

final class $$StoriesTableReferences
    extends BaseReferences<_$AppDatabase, $StoriesTable, Story> {
  $$StoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StoryCharactersTable, List<StoryCharacter>>
  _storyCharactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.storyCharacters,
    aliasName: $_aliasNameGenerator(db.stories.id, db.storyCharacters.storyId),
  );

  $$StoryCharactersTableProcessedTableManager get storyCharactersRefs {
    final manager = $$StoryCharactersTableTableManager(
      $_db,
      $_db.storyCharacters,
    ).filter((f) => f.storyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _storyCharactersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ScenesTable, List<Scene>> _scenesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.scenes,
    aliasName: $_aliasNameGenerator(db.stories.id, db.scenes.storyId),
  );

  $$ScenesTableProcessedTableManager get scenesRefs {
    final manager = $$ScenesTableTableManager(
      $_db,
      $_db.scenes,
    ).filter((f) => f.storyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_scenesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StoriesTableFilterComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalScenes => $composableBuilder(
    column: $table.totalScenes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> storyCharactersRefs(
    Expression<bool> Function($$StoryCharactersTableFilterComposer f) f,
  ) {
    final $$StoryCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.storyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableFilterComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scenesRefs(
    Expression<bool> Function($$ScenesTableFilterComposer f) f,
  ) {
    final $$ScenesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.storyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableFilterComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalScenes => $composableBuilder(
    column: $table.totalScenes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoriesTable> {
  $$StoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get totalScenes => $composableBuilder(
    column: $table.totalScenes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverImageUrl => $composableBuilder(
    column: $table.coverImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  Expression<T> storyCharactersRefs<T extends Object>(
    Expression<T> Function($$StoryCharactersTableAnnotationComposer a) f,
  ) {
    final $$StoryCharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.storyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> scenesRefs<T extends Object>(
    Expression<T> Function($$ScenesTableAnnotationComposer a) f,
  ) {
    final $$ScenesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.scenes,
      getReferencedColumn: (t) => t.storyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScenesTableAnnotationComposer(
            $db: $db,
            $table: $db.scenes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoriesTable,
          Story,
          $$StoriesTableFilterComposer,
          $$StoriesTableOrderingComposer,
          $$StoriesTableAnnotationComposer,
          $$StoriesTableCreateCompanionBuilder,
          $$StoriesTableUpdateCompanionBuilder,
          (Story, $$StoriesTableReferences),
          Story,
          PrefetchHooks Function({bool storyCharactersRefs, bool scenesRefs})
        > {
  $$StoriesTableTableManager(_$AppDatabase db, $StoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalScenes = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoriesCompanion(
                id: id,
                title: title,
                description: description,
                genre: genre,
                status: status,
                totalScenes: totalScenes,
                coverImageUrl: coverImageUrl,
                createdAt: createdAt,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> totalScenes = const Value.absent(),
                Value<String?> coverImageUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoriesCompanion.insert(
                id: id,
                title: title,
                description: description,
                genre: genre,
                status: status,
                totalScenes: totalScenes,
                coverImageUrl: coverImageUrl,
                createdAt: createdAt,
                userId: userId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({storyCharactersRefs = false, scenesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (storyCharactersRefs) db.storyCharacters,
                    if (scenesRefs) db.scenes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (storyCharactersRefs)
                        await $_getPrefetchedData<
                          Story,
                          $StoriesTable,
                          StoryCharacter
                        >(
                          currentTable: table,
                          referencedTable: $$StoriesTableReferences
                              ._storyCharactersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).storyCharactersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.storyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (scenesRefs)
                        await $_getPrefetchedData<Story, $StoriesTable, Scene>(
                          currentTable: table,
                          referencedTable: $$StoriesTableReferences
                              ._scenesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).scenesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.storyId == item.id,
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

typedef $$StoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoriesTable,
      Story,
      $$StoriesTableFilterComposer,
      $$StoriesTableOrderingComposer,
      $$StoriesTableAnnotationComposer,
      $$StoriesTableCreateCompanionBuilder,
      $$StoriesTableUpdateCompanionBuilder,
      (Story, $$StoriesTableReferences),
      Story,
      PrefetchHooks Function({bool storyCharactersRefs, bool scenesRefs})
    >;
typedef $$CharactersTableCreateCompanionBuilder =
    CharactersCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      Value<String?> imageUrl,
      Value<String?> personalityTraits,
      Value<String?> appearanceDescription,
      Value<String?> backgroundStory,
      Value<String?> userId,
      Value<int> rowid,
    });
typedef $$CharactersTableUpdateCompanionBuilder =
    CharactersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> imageUrl,
      Value<String?> personalityTraits,
      Value<String?> appearanceDescription,
      Value<String?> backgroundStory,
      Value<String?> userId,
      Value<int> rowid,
    });

final class $$CharactersTableReferences
    extends BaseReferences<_$AppDatabase, $CharactersTable, Character> {
  $$CharactersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StoryCharactersTable, List<StoryCharacter>>
  _storyCharactersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.storyCharacters,
    aliasName: $_aliasNameGenerator(
      db.characters.id,
      db.storyCharacters.characterId,
    ),
  );

  $$StoryCharactersTableProcessedTableManager get storyCharactersRefs {
    final manager = $$StoryCharactersTableTableManager(
      $_db,
      $_db.storyCharacters,
    ).filter((f) => f.characterId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _storyCharactersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CharactersTableFilterComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personalityTraits => $composableBuilder(
    column: $table.personalityTraits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appearanceDescription => $composableBuilder(
    column: $table.appearanceDescription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundStory => $composableBuilder(
    column: $table.backgroundStory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> storyCharactersRefs(
    Expression<bool> Function($$StoryCharactersTableFilterComposer f) f,
  ) {
    final $$StoryCharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableFilterComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personalityTraits => $composableBuilder(
    column: $table.personalityTraits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appearanceDescription => $composableBuilder(
    column: $table.appearanceDescription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundStory => $composableBuilder(
    column: $table.backgroundStory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CharactersTable> {
  $$CharactersTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get personalityTraits => $composableBuilder(
    column: $table.personalityTraits,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appearanceDescription => $composableBuilder(
    column: $table.appearanceDescription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundStory => $composableBuilder(
    column: $table.backgroundStory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  Expression<T> storyCharactersRefs<T extends Object>(
    Expression<T> Function($$StoryCharactersTableAnnotationComposer a) f,
  ) {
    final $$StoryCharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.storyCharacters,
      getReferencedColumn: (t) => t.characterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoryCharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.storyCharacters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CharactersTable,
          Character,
          $$CharactersTableFilterComposer,
          $$CharactersTableOrderingComposer,
          $$CharactersTableAnnotationComposer,
          $$CharactersTableCreateCompanionBuilder,
          $$CharactersTableUpdateCompanionBuilder,
          (Character, $$CharactersTableReferences),
          Character,
          PrefetchHooks Function({bool storyCharactersRefs})
        > {
  $$CharactersTableTableManager(_$AppDatabase db, $CharactersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> personalityTraits = const Value.absent(),
                Value<String?> appearanceDescription = const Value.absent(),
                Value<String?> backgroundStory = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion(
                id: id,
                name: name,
                description: description,
                imageUrl: imageUrl,
                personalityTraits: personalityTraits,
                appearanceDescription: appearanceDescription,
                backgroundStory: backgroundStory,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> personalityTraits = const Value.absent(),
                Value<String?> appearanceDescription = const Value.absent(),
                Value<String?> backgroundStory = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CharactersCompanion.insert(
                id: id,
                name: name,
                description: description,
                imageUrl: imageUrl,
                personalityTraits: personalityTraits,
                appearanceDescription: appearanceDescription,
                backgroundStory: backgroundStory,
                userId: userId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({storyCharactersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (storyCharactersRefs) db.storyCharacters,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (storyCharactersRefs)
                    await $_getPrefetchedData<
                      Character,
                      $CharactersTable,
                      StoryCharacter
                    >(
                      currentTable: table,
                      referencedTable: $$CharactersTableReferences
                          ._storyCharactersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CharactersTableReferences(
                            db,
                            table,
                            p0,
                          ).storyCharactersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.characterId == item.id,
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

typedef $$CharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CharactersTable,
      Character,
      $$CharactersTableFilterComposer,
      $$CharactersTableOrderingComposer,
      $$CharactersTableAnnotationComposer,
      $$CharactersTableCreateCompanionBuilder,
      $$CharactersTableUpdateCompanionBuilder,
      (Character, $$CharactersTableReferences),
      Character,
      PrefetchHooks Function({bool storyCharactersRefs})
    >;
typedef $$StoryCharactersTableCreateCompanionBuilder =
    StoryCharactersCompanion Function({
      required String storyId,
      required String characterId,
      Value<String?> roleInStory,
      Value<int> rowid,
    });
typedef $$StoryCharactersTableUpdateCompanionBuilder =
    StoryCharactersCompanion Function({
      Value<String> storyId,
      Value<String> characterId,
      Value<String?> roleInStory,
      Value<int> rowid,
    });

final class $$StoryCharactersTableReferences
    extends
        BaseReferences<_$AppDatabase, $StoryCharactersTable, StoryCharacter> {
  $$StoryCharactersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StoriesTable _storyIdTable(_$AppDatabase db) =>
      db.stories.createAlias(
        $_aliasNameGenerator(db.storyCharacters.storyId, db.stories.id),
      );

  $$StoriesTableProcessedTableManager get storyId {
    final $_column = $_itemColumn<String>('story_id')!;

    final manager = $$StoriesTableTableManager(
      $_db,
      $_db.stories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_storyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CharactersTable _characterIdTable(_$AppDatabase db) =>
      db.characters.createAlias(
        $_aliasNameGenerator(db.storyCharacters.characterId, db.characters.id),
      );

  $$CharactersTableProcessedTableManager get characterId {
    final $_column = $_itemColumn<String>('character_id')!;

    final manager = $$CharactersTableTableManager(
      $_db,
      $_db.characters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_characterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StoryCharactersTableFilterComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get roleInStory => $composableBuilder(
    column: $table.roleInStory,
    builder: (column) => ColumnFilters(column),
  );

  $$StoriesTableFilterComposer get storyId {
    final $$StoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableFilterComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CharactersTableFilterComposer get characterId {
    final $$CharactersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableFilterComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableOrderingComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get roleInStory => $composableBuilder(
    column: $table.roleInStory,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoriesTableOrderingComposer get storyId {
    final $$StoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableOrderingComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CharactersTableOrderingComposer get characterId {
    final $$CharactersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableOrderingComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoryCharactersTable> {
  $$StoryCharactersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get roleInStory => $composableBuilder(
    column: $table.roleInStory,
    builder: (column) => column,
  );

  $$StoriesTableAnnotationComposer get storyId {
    final $$StoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CharactersTableAnnotationComposer get characterId {
    final $$CharactersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.characterId,
      referencedTable: $db.characters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CharactersTableAnnotationComposer(
            $db: $db,
            $table: $db.characters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StoryCharactersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoryCharactersTable,
          StoryCharacter,
          $$StoryCharactersTableFilterComposer,
          $$StoryCharactersTableOrderingComposer,
          $$StoryCharactersTableAnnotationComposer,
          $$StoryCharactersTableCreateCompanionBuilder,
          $$StoryCharactersTableUpdateCompanionBuilder,
          (StoryCharacter, $$StoryCharactersTableReferences),
          StoryCharacter,
          PrefetchHooks Function({bool storyId, bool characterId})
        > {
  $$StoryCharactersTableTableManager(
    _$AppDatabase db,
    $StoryCharactersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryCharactersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryCharactersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryCharactersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> storyId = const Value.absent(),
                Value<String> characterId = const Value.absent(),
                Value<String?> roleInStory = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryCharactersCompanion(
                storyId: storyId,
                characterId: characterId,
                roleInStory: roleInStory,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storyId,
                required String characterId,
                Value<String?> roleInStory = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoryCharactersCompanion.insert(
                storyId: storyId,
                characterId: characterId,
                roleInStory: roleInStory,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StoryCharactersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({storyId = false, characterId = false}) {
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
                    if (storyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.storyId,
                                referencedTable:
                                    $$StoryCharactersTableReferences
                                        ._storyIdTable(db),
                                referencedColumn:
                                    $$StoryCharactersTableReferences
                                        ._storyIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (characterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.characterId,
                                referencedTable:
                                    $$StoryCharactersTableReferences
                                        ._characterIdTable(db),
                                referencedColumn:
                                    $$StoryCharactersTableReferences
                                        ._characterIdTable(db)
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

typedef $$StoryCharactersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoryCharactersTable,
      StoryCharacter,
      $$StoryCharactersTableFilterComposer,
      $$StoryCharactersTableOrderingComposer,
      $$StoryCharactersTableAnnotationComposer,
      $$StoryCharactersTableCreateCompanionBuilder,
      $$StoryCharactersTableUpdateCompanionBuilder,
      (StoryCharacter, $$StoryCharactersTableReferences),
      StoryCharacter,
      PrefetchHooks Function({bool storyId, bool characterId})
    >;
typedef $$ScenesTableCreateCompanionBuilder =
    ScenesCompanion Function({
      required String id,
      required String storyId,
      required int sequence,
      required String content,
      Value<String> sceneType,
      Value<String?> imageUrl,
      Value<String?> bgmUrl,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ScenesTableUpdateCompanionBuilder =
    ScenesCompanion Function({
      Value<String> id,
      Value<String> storyId,
      Value<int> sequence,
      Value<String> content,
      Value<String> sceneType,
      Value<String?> imageUrl,
      Value<String?> bgmUrl,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ScenesTableReferences
    extends BaseReferences<_$AppDatabase, $ScenesTable, Scene> {
  $$ScenesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StoriesTable _storyIdTable(_$AppDatabase db) => db.stories
      .createAlias($_aliasNameGenerator(db.scenes.storyId, db.stories.id));

  $$StoriesTableProcessedTableManager get storyId {
    final $_column = $_itemColumn<String>('story_id')!;

    final manager = $$StoriesTableTableManager(
      $_db,
      $_db.stories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_storyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScenesTableFilterComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableFilterComposer({
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

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sceneType => $composableBuilder(
    column: $table.sceneType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bgmUrl => $composableBuilder(
    column: $table.bgmUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StoriesTableFilterComposer get storyId {
    final $$StoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableFilterComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScenesTableOrderingComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableOrderingComposer({
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

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sceneType => $composableBuilder(
    column: $table.sceneType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bgmUrl => $composableBuilder(
    column: $table.bgmUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoriesTableOrderingComposer get storyId {
    final $$StoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableOrderingComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScenesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScenesTable> {
  $$ScenesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sceneType =>
      $composableBuilder(column: $table.sceneType, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get bgmUrl =>
      $composableBuilder(column: $table.bgmUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$StoriesTableAnnotationComposer get storyId {
    final $$StoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storyId,
      referencedTable: $db.stories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.stories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScenesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScenesTable,
          Scene,
          $$ScenesTableFilterComposer,
          $$ScenesTableOrderingComposer,
          $$ScenesTableAnnotationComposer,
          $$ScenesTableCreateCompanionBuilder,
          $$ScenesTableUpdateCompanionBuilder,
          (Scene, $$ScenesTableReferences),
          Scene,
          PrefetchHooks Function({bool storyId})
        > {
  $$ScenesTableTableManager(_$AppDatabase db, $ScenesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScenesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScenesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScenesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> storyId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sceneType = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> bgmUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScenesCompanion(
                id: id,
                storyId: storyId,
                sequence: sequence,
                content: content,
                sceneType: sceneType,
                imageUrl: imageUrl,
                bgmUrl: bgmUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String storyId,
                required int sequence,
                required String content,
                Value<String> sceneType = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> bgmUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScenesCompanion.insert(
                id: id,
                storyId: storyId,
                sequence: sequence,
                content: content,
                sceneType: sceneType,
                imageUrl: imageUrl,
                bgmUrl: bgmUrl,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ScenesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({storyId = false}) {
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
                    if (storyId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.storyId,
                                referencedTable: $$ScenesTableReferences
                                    ._storyIdTable(db),
                                referencedColumn: $$ScenesTableReferences
                                    ._storyIdTable(db)
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

typedef $$ScenesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScenesTable,
      Scene,
      $$ScenesTableFilterComposer,
      $$ScenesTableOrderingComposer,
      $$ScenesTableAnnotationComposer,
      $$ScenesTableCreateCompanionBuilder,
      $$ScenesTableUpdateCompanionBuilder,
      (Scene, $$ScenesTableReferences),
      Scene,
      PrefetchHooks Function({bool storyId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StoriesTableTableManager get stories =>
      $$StoriesTableTableManager(_db, _db.stories);
  $$CharactersTableTableManager get characters =>
      $$CharactersTableTableManager(_db, _db.characters);
  $$StoryCharactersTableTableManager get storyCharacters =>
      $$StoryCharactersTableTableManager(_db, _db.storyCharacters);
  $$ScenesTableTableManager get scenes =>
      $$ScenesTableTableManager(_db, _db.scenes);
}
