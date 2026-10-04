import 'package:drift/drift.dart';

import '../database/app_database.dart';

abstract class DeckRepository {
  Future<int> createDeck({
    required String title,
    int? parentId,
    bool isPremium = false,
    String sourceLang = 'id',
    String targetLang = 'en',
    int? color,
  });

  Future<int> insertDeck(DecksCompanion deck);

  Future<Deck?> getDeckById(int id);

  Future<List<Deck>> getAllDecks({bool includeDeleted = false});

  Stream<List<Deck>> watchAllDecks({bool includeDeleted = false});

  Future<List<Deck>> getRootDecks({bool includeDeleted = false});

  Stream<List<Deck>> watchRootDecks({bool includeDeleted = false});

  Future<List<Deck>> getSubDecks(int parentId, {bool includeDeleted = false});

  Stream<List<Deck>> watchSubDecks(int parentId, {bool includeDeleted = false});

  Future<bool> updateDeck(DecksCompanion deck);

  Future<bool> updateDeckData({
    required int id,
    String? title,
    int? parentId,
    bool? isPremium,
    String? sourceLang,
    String? targetLang,
    int? color,
  });

  Future<int> softDeleteDeck(int id);

  Future<int> restoreDeck(int id);

  Future<int> hardDeleteDeck(int id);

  Future<List<Deck>> getTrashDecks();

  Stream<List<Deck>> watchTrashDecks();

  Future<int> getCardCount(int deckId, {bool includeDeleted = false});
  Future<int> getDueCardCount(int deckId, {DateTime? asOf, bool includeDeleted = false});
}

class DriftDeckRepository implements DeckRepository {
  final AppDatabase _db;

  DriftDeckRepository(this._db);

  @override
  Future<int> createDeck({
    required String title,
    int? parentId,
    bool isPremium = false,
    String sourceLang = 'id',
    String targetLang = 'en',
    int? color,
  }) {
    final companion = DecksCompanion(
      title: Value(title),
      parentId: Value(parentId),
      isPremium: Value(isPremium),
      sourceLang: Value(sourceLang),
      targetLang: Value(targetLang),
      color: Value(color),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );
    return insertDeck(companion);
  }

  @override
  Future<int> insertDeck(DecksCompanion deck) {
    return _db.into(_db.decks).insert(deck);
  }

  @override
  Future<Deck?> getDeckById(int id) {
    return (_db.select(_db.decks)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<Deck>> getAllDecks({bool includeDeleted = false}) {
    final query = _db.select(_db.decks);
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.get();
  }

  @override
  Stream<List<Deck>> watchAllDecks({bool includeDeleted = false}) {
    final query = _db.select(_db.decks);
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.watch();
  }

  @override
  Future<List<Deck>> getRootDecks({bool includeDeleted = false}) {
    final query = _db.select(_db.decks)..where((tbl) => tbl.parentId.isNull());
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.get();
  }

  @override
  Stream<List<Deck>> watchRootDecks({bool includeDeleted = false}) {
    final query = _db.select(_db.decks)..where((tbl) => tbl.parentId.isNull());
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.watch();
  }

  @override
  Future<List<Deck>> getSubDecks(int parentId, {bool includeDeleted = false}) {
    final query = _db.select(_db.decks)
      ..where((tbl) => tbl.parentId.equals(parentId));
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.get();
  }

  @override
  Stream<List<Deck>> watchSubDecks(int parentId, {bool includeDeleted = false}) {
    final query = _db.select(_db.decks)
      ..where((tbl) => tbl.parentId.equals(parentId));
    if (!includeDeleted) {
      query.where((tbl) => tbl.deletedAt.isNull());
    }
    return query.watch();
  }

  @override
  Future<bool> updateDeck(DecksCompanion deck) {
    final withUpdatedAt = deck.copyWith(updatedAt: Value(DateTime.now()));
    return _db.update(_db.decks).replace(withUpdatedAt);
  }

  @override
  Future<bool> updateDeckData({
    required int id,
    String? title,
    int? parentId,
    bool? isPremium,
    String? sourceLang,
    String? targetLang,
    int? color,
  }) async {
    final companion = DecksCompanion(
      id: Value(id),
      title: title != null ? Value(title) : const Value.absent(),
      parentId: parentId != null ? Value(parentId) : const Value.absent(),
      isPremium: isPremium != null ? Value(isPremium) : const Value.absent(),
      sourceLang: sourceLang != null ? Value(sourceLang) : const Value.absent(),
      targetLang: targetLang != null ? Value(targetLang) : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    final count = await (_db.update(_db.decks)..where((tbl) => tbl.id.equals(id)))
        .write(companion);
    return count > 0;
  }

  @override
  Future<int> softDeleteDeck(int id) async {
    final now = DateTime.now();
    final count = await (_db.update(_db.decks)..where((tbl) => tbl.id.equals(id))).write(
      DecksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    // Soft delete subdeck milik deck ini
    await (_db.update(_db.decks)..where((tbl) => tbl.parentId.equals(id))).write(
      DecksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    return count;
  }

  @override
  Future<int> restoreDeck(int id) async {
    final now = DateTime.now();
    final count = await (_db.update(_db.decks)..where((tbl) => tbl.id.equals(id))).write(
      DecksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );

    // Restore subdeck milik deck ini
    await (_db.update(_db.decks)..where((tbl) => tbl.parentId.equals(id))).write(
      DecksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );

    return count;
  }

  @override
  Future<int> hardDeleteDeck(int id) {
    return (_db.delete(_db.decks)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<List<Deck>> getTrashDecks() {
    return (_db.select(_db.decks)..where((tbl) => tbl.deletedAt.isNotNull()))
        .get();
  }

  @override
  Stream<List<Deck>> watchTrashDecks() {
    return (_db.select(_db.decks)..where((tbl) => tbl.deletedAt.isNotNull()))
        .watch();
  }

  @override
  Future<int> getCardCount(int deckId, {bool includeDeleted = false}) async {
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
  Future<int> getDueCardCount(int deckId, {DateTime? asOf, bool includeDeleted = false}) async {
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
}
