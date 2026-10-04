import 'package:drift/drift.dart';

@TableIndex(name: 'decks_parent_id_idx', columns: {#parentId})
@TableIndex(name: 'decks_deleted_at_idx', columns: {#deletedAt})
class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get parentId => integer().nullable().references(
    Decks,
    #id,
    onDelete: KeyAction.cascade,
  )();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  TextColumn get sourceLang => text().withDefault(const Constant('id'))();
  TextColumn get targetLang => text().withDefault(const Constant('en'))();
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
