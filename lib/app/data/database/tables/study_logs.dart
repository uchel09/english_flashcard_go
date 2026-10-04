import 'package:drift/drift.dart';

import 'cards.dart';

@TableIndex(name: 'study_logs_card_id_idx', columns: {#cardId})
@TableIndex(name: 'study_logs_created_at_idx', columns: {#createdAt})
class StudyLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get deckId => integer()();
  // 0: again, 1: hard, 2: good, 3: easy, 4: quiz_correct, 5: quiz_incorrect
  IntColumn get rating => integer().withDefault(const Constant(0))();
  BoolColumn get isQuiz => boolean().withDefault(const Constant(false))();
  BoolColumn get isCorrect => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
