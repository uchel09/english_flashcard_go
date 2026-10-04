import 'package:drift/drift.dart';

import '../database/app_database.dart';

abstract class CardRepository {
  Future<int> createCard({
    required int deckId,
    required String frontText,
    required String backText,
    String? frontAudioPath,
    String? backAudioPath,
    String? frontImagePath,
    String? backImagePath,
    int difficulty = 0,
    DateTime? nextReviewAt,
    double ease = 2.5,
    int intervalDays = 0,
  });

  Future<int> insertCard(CardsCompanion card);

  Future<Card?> getCardById(int id);

  Future<List<Card>> getCardsByDeck(int deckId, {bool includeDeleted = false});

  Stream<List<Card>> watchCardsByDeck(int deckId, {bool includeDeleted = false});

  Future<List<Card>> getDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  });

  Stream<List<Card>> watchDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  });

  Future<int> countDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  });

  Future<bool> updateCard(CardsCompanion card);

  Future<bool> updateCardData({
    required int id,
    String? frontText,
    String? backText,
    String? frontAudioPath,
    String? backAudioPath,
    String? frontImagePath,
    String? backImagePath,
    int? difficulty,
    DateTime? nextReviewAt,
    double? ease,
    int? intervalDays,
  });

  Future<int> softDeleteCard(int id);

  Future<int> restoreCard(int id);

  Future<int> hardDeleteCard(int id);

  Future<List<Card>> getTrashCards();

  Stream<List<Card>> watchTrashCards();

  Future<int> countCardsByDeck(int deckId, {bool includeDeleted = false});
  Future<bool> isMediaUsed(String relativePath);
}

class DriftCardRepository implements CardRepository {
  final AppDatabase _db;

  DriftCardRepository(this._db);

  @override
  Future<int> createCard({
    required int deckId,
    required String frontText,
    required String backText,
    String? frontAudioPath,
    String? backAudioPath,
    String? frontImagePath,
    String? backImagePath,
    int difficulty = 0,
    DateTime? nextReviewAt,
    double ease = 2.5,
    int intervalDays = 0,
  }) {
    final companion = CardsCompanion(
      deckId: Value(deckId),
      frontText: Value(frontText),
      backText: Value(backText),
      frontAudioPath: Value(frontAudioPath),
      backAudioPath: Value(backAudioPath),
      frontImagePath: Value(frontImagePath),
      backImagePath: Value(backImagePath),
      difficulty: Value(difficulty),
      nextReviewAt: Value(nextReviewAt),
      ease: Value(ease),
      intervalDays: Value(intervalDays),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
    return insertCard(companion);
  }

  @override
  Future<int> insertCard(CardsCompanion card) {
    return _db.into(_db.cards).insert(card);
  }

  @override
  Future<Card?> getCardById(int id) {
    return (_db.select(_db.cards)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Card>> getCardsByDeck(int deckId, {bool includeDeleted = false}) {
    final query = _db.select(_db.cards)
      ..where((tbl) => tbl.deckId.equals(deckId));
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.get();
  }

  @override
  Stream<List<Card>> watchCardsByDeck(int deckId, {bool includeDeleted = false}) {
    final query = _db.select(_db.cards)
      ..where((tbl) => tbl.deckId.equals(deckId));
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.watch();
  }

  @override
  Future<List<Card>> getDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  }) {
    final cutoff = asOf ?? DateTime.now();
    final query = _db.select(_db.cards)
      ..where((tbl) => tbl.deckId.equals(deckId))
      ..where(
        (tbl) =>
            tbl.nextReviewAt.isNull() |
            tbl.nextReviewAt.isSmallerOrEqualValue(cutoff),
      );
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    query.orderBy([
      (tbl) => OrderingTerm.asc(tbl.nextReviewAt),
      (tbl) => OrderingTerm.asc(tbl.id),
    ]);
    return query.get();
  }

  @override
  Stream<List<Card>> watchDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  }) {
    final cutoff = asOf ?? DateTime.now();
    final query = _db.select(_db.cards)
      ..where((tbl) => tbl.deckId.equals(deckId))
      ..where(
        (tbl) =>
            tbl.nextReviewAt.isNull() |
            tbl.nextReviewAt.isSmallerOrEqualValue(cutoff),
      );
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    query.orderBy([
      (tbl) => OrderingTerm.asc(tbl.nextReviewAt),
      (tbl) => OrderingTerm.asc(tbl.id),
    ]);
    return query.watch();
  }

  @override
  Future<int> countDueCardsByDeck(
    int deckId, {
    DateTime? asOf,
    bool includeDeleted = false,
  }) async {
    final cutoff = asOf ?? DateTime.now();
    final countExpr = _db.cards.id.count();
    final query = _db.selectOnly(_db.cards)
      ..addColumns([countExpr])
      ..where(_db.cards.deckId.equals(deckId))
      ..where(
        _db.cards.nextReviewAt.isNull() |
        _db.cards.nextReviewAt.isSmallerOrEqualValue(cutoff),
      );

    if (!includeDeleted) {
      query.where(_db.cards.deletedAt.isNull());
    }

    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  @override
  Future<bool> updateCard(CardsCompanion card) {
    final withUpdatedAt = card.copyWith(updatedAt: Value(DateTime.now()));
    return _db.update(_db.cards).replace(withUpdatedAt);
  }

  @override
  Future<bool> updateCardData({
    required int id,
    String? frontText,
    String? backText,
    String? frontAudioPath,
    String? backAudioPath,
    String? frontImagePath,
    String? backImagePath,
    int? difficulty,
    DateTime? nextReviewAt,
    double? ease,
    int? intervalDays,
  }) async {
    final companion = CardsCompanion(
      id: Value(id),
      frontText: frontText != null ? Value(frontText) : const Value.absent(),
      backText: backText != null ? Value(backText) : const Value.absent(),
      frontAudioPath: frontAudioPath != null ? Value(frontAudioPath) : const Value.absent(),
      backAudioPath: backAudioPath != null ? Value(backAudioPath) : const Value.absent(),
      frontImagePath: frontImagePath != null ? Value(frontImagePath) : const Value.absent(),
      backImagePath: backImagePath != null ? Value(backImagePath) : const Value.absent(),
      difficulty: difficulty != null ? Value(difficulty) : const Value.absent(),
      nextReviewAt: nextReviewAt != null ? Value(nextReviewAt) : const Value.absent(),
      ease: ease != null ? Value(ease) : const Value.absent(),
      intervalDays: intervalDays != null ? Value(intervalDays) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    final count = await (_db.update(_db.cards)..where((tbl) => tbl.id.equals(id)))
        .write(companion);
    return count > 0;
  }

  @override
  Future<int> softDeleteCard(int id) {
    return (_db.update(_db.cards)..where((tbl) => tbl.id.equals(id))).write(
      CardsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<int> restoreCard(int id) {
    return (_db.update(_db.cards)..where((tbl) => tbl.id.equals(id))).write(
      CardsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<int> hardDeleteCard(int id) {
    return (_db.delete(_db.cards)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<List<Card>> getTrashCards() {
    return (_db.select(_db.cards)..where((tbl) => tbl.deletedAt.isNotNull()))
        .get();
  }

  @override
  Stream<List<Card>> watchTrashCards() {
    return (_db.select(_db.cards)..where((tbl) => tbl.deletedAt.isNotNull()))
        .watch();
  }

  @override
  Future<int> countCardsByDeck(int deckId, {bool includeDeleted = false}) async {
    final countExpr = _db.cards.id.count();
    final query = _db.selectOnly(_db.cards)
      ..addColumns([countExpr])
      ..where(_db.cards.deckId.equals(deckId));

    if (!includeDeleted) {
      query.where(_db.cards.deletedAt.isNull());
    }

    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  @override
  Future<bool> isMediaUsed(String relativePath) async {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) return false;

    final countExpr = _db.cards.id.count();
    final query = _db.selectOnly(_db.cards)
      ..addColumns([countExpr])
      ..where(
        _db.cards.frontAudioPath.equals(trimmed) |
        _db.cards.backAudioPath.equals(trimmed) |
        _db.cards.frontImagePath.equals(trimmed) |
        _db.cards.backImagePath.equals(trimmed),
      );

    final row = await query.getSingle();
    return (row.read(countExpr) ?? 0) > 0;
  }
}
