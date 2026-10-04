import 'package:drift/drift.dart';

import '../database/app_database.dart';

class HardestCardModel {
  final Card card;
  final String deckTitle;
  final int failCount;
  final double ease;

  HardestCardModel({
    required this.card,
    required this.deckTitle,
    required this.failCount,
    required this.ease,
  });
}

abstract class StudyLogRepository {
  Future<int> recordLog({
    required int cardId,
    required int deckId,
    int rating = 0,
    bool isQuiz = false,
    bool isCorrect = false,
    DateTime? createdAt,
  });

  Future<int> getCardsStudiedTodayCount();
  Future<int> getTotalReviewsTodayCount();
  Future<int> getDailyStreak();
  Future<double> getQuizAccuracy();
  Future<int> getTotalQuizAnswered();
  Future<int> getTotalQuizCorrect();
  Future<List<HardestCardModel>> getHardestCards({int limit = 5});
  Stream<List<StudyLog>> watchAllLogs();
}

class DriftStudyLogRepository implements StudyLogRepository {
  final AppDatabase _db;

  DriftStudyLogRepository(this._db);

  @override
  Future<int> recordLog({
    required int cardId,
    required int deckId,
    int rating = 0,
    bool isQuiz = false,
    bool isCorrect = false,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return _db
        .into(_db.studyLogs)
        .insert(
          StudyLogsCompanion.insert(
            cardId: cardId,
            deckId: deckId,
            rating: Value(rating),
            isQuiz: Value(isQuiz),
            isCorrect: Value(isCorrect),
            createdAt: Value(now),
          ),
        );
  }

  @override
  Future<int> getCardsStudiedTodayCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final query = _db.selectOnly(_db.studyLogs, distinct: true)
      ..addColumns([_db.studyLogs.cardId])
      ..where(
        _db.studyLogs.createdAt.isBiggerOrEqualValue(startOfDay) &
            _db.studyLogs.createdAt.isSmallerOrEqualValue(endOfDay),
      );

    final rows = await query.get();
    return rows.length;
  }

  @override
  Future<int> getTotalReviewsTodayCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final countExpr = _db.studyLogs.id.count();

    final query = _db.selectOnly(_db.studyLogs)
      ..addColumns([countExpr])
      ..where(_db.studyLogs.createdAt.isBiggerOrEqualValue(startOfDay));

    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  @override
  Future<int> getDailyStreak() async {
    final query = _db.selectOnly(_db.studyLogs)
      ..addColumns([_db.studyLogs.createdAt])
      ..orderBy([OrderingTerm.desc(_db.studyLogs.createdAt)]);

    final rows = await query.get();
    if (rows.isEmpty) return 0;

    final Set<String> activeDates = {};
    for (final r in rows) {
      final dt = r.read(_db.studyLogs.createdAt);
      if (dt != null) {
        final key =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        activeDates.add(key);
      }
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    int streak = 0;
    DateTime checkDate;

    if (activeDates.contains(todayStr)) {
      streak = 1;
      checkDate = yesterday;
    } else if (activeDates.contains(yesterdayStr)) {
      streak = 1;
      checkDate = yesterday.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    while (true) {
      final str =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (activeDates.contains(str)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  @override
  Future<double> getQuizAccuracy() async {
    final total = await getTotalQuizAnswered();
    if (total == 0) return 0.0;
    final correct = await getTotalQuizCorrect();
    final accuracy = (correct / total) * 100;
    return double.parse(accuracy.toStringAsFixed(1));
  }

  @override
  Future<int> getTotalQuizAnswered() async {
    final countExpr = _db.studyLogs.id.count();
    final query = _db.selectOnly(_db.studyLogs)
      ..addColumns([countExpr])
      ..where(_db.studyLogs.isQuiz.equals(true));

    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  @override
  Future<int> getTotalQuizCorrect() async {
    final countExpr = _db.studyLogs.id.count();
    final query = _db.selectOnly(_db.studyLogs)
      ..addColumns([countExpr])
      ..where(
        _db.studyLogs.isQuiz.equals(true) &
            _db.studyLogs.isCorrect.equals(true),
      );

    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  @override
  Future<List<HardestCardModel>> getHardestCards({int limit = 5}) async {
    // Ambil kartu yang tidak dihapus dengan ease terendah atau difficulty tertinggi
    final cardsQuery = _db.select(_db.cards)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([
        (tbl) => OrderingTerm.asc(tbl.ease),
        (tbl) => OrderingTerm.desc(tbl.difficulty),
        (tbl) => OrderingTerm.desc(tbl.updatedAt),
      ])
      ..limit(limit);

    final cards = await cardsQuery.get();
    final List<HardestCardModel> result = [];

    for (final c in cards) {
      final deck = await (_db.select(
        _db.decks,
      )..where((tbl) => tbl.id.equals(c.deckId))).getSingleOrNull();

      final countExpr = _db.studyLogs.id.count();
      final failQuery = _db.selectOnly(_db.studyLogs)
        ..addColumns([countExpr])
        ..where(
          _db.studyLogs.cardId.equals(c.id) &
              _db.studyLogs.isCorrect.equals(false),
        );

      final failRow = await failQuery.getSingle();
      final failCount = failRow.read(countExpr) ?? 0;

      result.add(
        HardestCardModel(
          card: c,
          deckTitle: deck?.title ?? 'Deck',
          failCount: failCount,
          ease: c.ease,
        ),
      );
    }

    return result;
  }

  @override
  Stream<List<StudyLog>> watchAllLogs() {
    return _db.select(_db.studyLogs).watch();
  }
}
