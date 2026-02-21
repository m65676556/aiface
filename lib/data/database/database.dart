import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('New Chat'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get role => text()(); // user, assistant, system
  TextColumn get content => text()();
  TextColumn get imageBase64 => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Memories extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  TextColumn get category => text().withDefault(const Constant('fact'))();
  IntColumn get importance => integer().withDefault(const Constant(3))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages, Memories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Conversation queries
  Future<List<Conversation>> getAllConversations() =>
      (select(conversations)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<Conversation> getConversation(String id) =>
      (select(conversations)..where((t) => t.id.equals(id))).getSingle();

  Future<void> insertConversation(ConversationsCompanion entry) =>
      into(conversations).insert(entry);

  Future<void> updateConversationTimestamp(String id) =>
      (update(conversations)..where((t) => t.id.equals(id)))
          .write(ConversationsCompanion(updatedAt: Value(DateTime.now())));

  Future<void> deleteConversation(String id) async {
    await (delete(messages)..where((t) => t.conversationId.equals(id))).go();
    await (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  // Message queries
  Future<List<Message>> getMessages(String conversationId) =>
      (select(messages)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> insertMessage(MessagesCompanion entry) =>
      into(messages).insert(entry);

  Future<int> getMessageCount(String conversationId) async {
    final count = countAll();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.conversationId.equals(conversationId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // Memory queries
  Future<List<Memory>> getAllMemories() =>
      (select(memories)..orderBy([(t) => OrderingTerm.desc(t.importance)]))
          .get();

  Future<void> insertMemory(MemoriesCompanion entry) =>
      into(memories).insert(entry);

  Future<List<Memory>> getRecentMemories(int limit) =>
      (select(memories)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(limit))
          .get();
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'aiface',
    web: kIsWeb
        ? DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          )
        : null,
  );
}
