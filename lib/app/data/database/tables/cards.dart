import 'package:drift/drift.dart';

import 'decks.dart';

@TableIndex(name: 'cards_deck_id_idx', columns: {#deckId})
@TableIndex(name: 'cards_deleted_at_idx', columns: {#deletedAt})
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deckId =>
      integer().references(Decks, #id, onDelete: KeyAction.cascade)();
  TextColumn get frontText => text()();
  TextColumn get backText => text()();
  TextColumn get frontAudioPath => text().nullable()();
  TextColumn get backAudioPath => text().nullable()();
  TextColumn get frontImagePath => text().nullable()();
  TextColumn get backImagePath => text().nullable()();
  IntColumn get difficulty => integer().withDefault(
    const Constant(0),
  )(); // 0: unrated, 1: easy, 2: medium, 3: hard
  DateTimeColumn get nextReviewAt => dateTime().nullable()();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}
