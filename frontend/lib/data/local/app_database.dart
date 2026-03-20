import 'package:drift/drift.dart';
import 'connection/connection.dart' as conn;

part 'app_database.g.dart';

// 1. Tables Definition
class Stories extends Table {
  TextColumn get id => text()(); // UUID from backend
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get narrativeType => text().withDefault(const Constant('hero'))();
  IntColumn get totalScenes => integer().withDefault(const Constant(0))();
  TextColumn get coverImageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get userId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Characters extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get personalityTraits => text().nullable()(); // JSON string or comma-separated
  TextColumn get appearanceDescription => text().nullable()();
  TextColumn get backgroundStory => text().nullable()();
  TextColumn get userId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StoryCharacters extends Table {
  TextColumn get storyId => text().references(Stories, #id, onDelete: KeyAction.cascade)();
  TextColumn get characterId => text().references(Characters, #id, onDelete: KeyAction.cascade)();
  TextColumn get roleInStory => text().nullable()(); // protagonist, etc.

  @override
  Set<Column> get primaryKey => {storyId, characterId};
}

class Scenes extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get storyId => text().references(Stories, #id, onDelete: KeyAction.cascade)();
  IntColumn get sequence => integer()();
  TextColumn get content => text()();
  TextColumn get sceneType => text().withDefault(const Constant('narrative'))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get bgmUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Database Class
@DriftDatabase(tables: [Stories, Characters, StoryCharacters, Scenes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(conn.openConnection());

  @override
  int get schemaVersion => 1;
}
