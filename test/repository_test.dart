import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';

void main() {
  group('Drift Repositories (Deck & Card)', () {
    late AppDatabase db;
    late DeckRepository deckRepo;
    late CardRepository cardRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      deckRepo = DriftDeckRepository(db);
      cardRepo = DriftCardRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('DeckRepository CRUD and hierarchy operations', () async {
      // 1. Create root deck
      final deckId = await deckRepo.createDeck(
        title: 'Kosakata Dasar',
        sourceLang: 'id',
        targetLang: 'en',
        color: 0xFF2196F3,
      );
      expect(deckId, greaterThan(0));

      // 2. Read
      final deck = await deckRepo.getDeckById(deckId);
      expect(deck, isNotNull);
      expect(deck!.title, 'Kosakata Dasar');
      expect(deck.targetLang, 'en');
      expect(deck.color, 0xFF2196F3);
      expect(deck.deletedAt, isNull);

      // 3. Create sub-deck
      final subDeckId = await deckRepo.createDeck(
        title: 'Kata Kerja',
        parentId: deckId,
      );
      final subDecks = await deckRepo.getSubDecks(deckId);
      expect(subDecks.length, 1);
      expect(subDecks.first.id, subDeckId);
      expect(subDecks.first.parentId, deckId);

      // 4. Update
      final updated = await deckRepo.updateDeckData(
        id: deckId,
        title: 'Kosakata Dasar Lengkap',
      );
      expect(updated, isTrue);

      final updatedDeck = await deckRepo.getDeckById(deckId);
      expect(updatedDeck!.title, 'Kosakata Dasar Lengkap');

      // 5. List all active decks
      final allDecks = await deckRepo.getAllDecks();
      expect(allDecks.length, 2);
    });

    test('DeckRepository soft delete, trash query, and restore', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Sementara');

      // Soft delete
      final affected = await deckRepo.softDeleteDeck(deckId);
      expect(affected, 1);

      // Should not appear in active decks
      final activeDecks = await deckRepo.getAllDecks();
      expect(activeDecks.any((d) => d.id == deckId), isFalse);

      // Should appear in trash
      final trashDecks = await deckRepo.getTrashDecks();
      expect(trashDecks.any((d) => d.id == deckId), isTrue);

      // Restore
      final restoredAffected = await deckRepo.restoreDeck(deckId);
      expect(restoredAffected, 1);

      // Should appear in active decks again
      final activeDecksAfter = await deckRepo.getAllDecks();
      expect(activeDecksAfter.any((d) => d.id == deckId), isTrue);

      // Should no longer appear in trash
      final trashAfter = await deckRepo.getTrashDecks();
      expect(trashAfter.any((d) => d.id == deckId), isFalse);
    });

    test('DeckRepository hard delete', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Hapus Permanen');

      final deleteCount = await deckRepo.hardDeleteDeck(deckId);
      expect(deleteCount, 1);

      final deck = await deckRepo.getDeckById(deckId);
      expect(deck, isNull);
    });

    test('CardRepository CRUD, SRS defaults, and queries by deck', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Belajar');

      // 1. Create card
      final cardId = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Apel',
        backText: 'Apple',
        frontAudioPath: '/audio/apel.m4a',
        backAudioPath: '/audio/apple.m4a',
        frontImagePath: '/images/apel.png',
        backImagePath: '/images/apple.png',
      );
      expect(cardId, greaterThan(0));

      // 2. Read card and verify default SRS fields
      final card = await cardRepo.getCardById(cardId);
      expect(card, isNotNull);
      expect(card!.deckId, deckId);
      expect(card.frontText, 'Apel');
      expect(card.backText, 'Apple');
      expect(card.frontAudioPath, '/audio/apel.m4a');
      expect(card.difficulty, 0); // 0 = unrated
      expect(card.ease, 2.5); // Default ease
      expect(card.intervalDays, 0); // Default interval
      expect(card.deletedAt, isNull);

      // 3. Update card data
      final updated = await cardRepo.updateCardData(
        id: cardId,
        difficulty: 2, // Medium
        intervalDays: 3,
        ease: 2.6,
      );
      expect(updated, isTrue);

      final updatedCard = await cardRepo.getCardById(cardId);
      expect(updatedCard!.difficulty, 2);
      expect(updatedCard.intervalDays, 3);
      expect(updatedCard.ease, 2.6);

      // 4. Query cards by deck
      final cards = await cardRepo.getCardsByDeck(deckId);
      expect(cards.length, 1);
      expect(cards.first.id, cardId);
    });

    test('CardRepository soft delete, trash, restore, and card counts', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Berhitung');

      final card1 = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Satu',
        backText: 'One',
      );
      final card2 = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Dua',
        backText: 'Two',
      );

      // Verify initial count
      expect(await deckRepo.getCardCount(deckId), 2);
      expect(await cardRepo.countCardsByDeck(deckId), 2);

      // Soft delete card1
      await cardRepo.softDeleteCard(card1);

      // Active count should be 1
      expect(await deckRepo.getCardCount(deckId), 1);
      expect(await cardRepo.countCardsByDeck(deckId), 1);

      // Total count including deleted should be 2
      expect(await deckRepo.getCardCount(deckId, includeDeleted: true), 2);
      expect(await cardRepo.countCardsByDeck(deckId, includeDeleted: true), 2);

      // Trash cards should contain card1
      final trash = await cardRepo.getTrashCards();
      expect(trash.any((c) => c.id == card1), isTrue);
      expect(trash.any((c) => c.id == card2), isFalse);

      // Restore card1
      await cardRepo.restoreCard(card1);
      expect(await deckRepo.getCardCount(deckId), 2);

      // Hard delete card2
      await cardRepo.hardDeleteCard(card2);
      expect(await deckRepo.getCardCount(deckId, includeDeleted: true), 1);
    });

    test('Data persistence across database restarts (simulated app restart)', () async {
      final tempDir = await Directory.systemTemp.createTemp('flashcard_test_');
      final dbFile = File('${tempDir.path}/test_flashcards.sqlite');

      try {
        // Session 1: Create DB, insert deck and card, then close
        final firstDb = AppDatabase(NativeDatabase(dbFile));
        final firstDeckRepo = DriftDeckRepository(firstDb);
        final firstCardRepo = DriftCardRepository(firstDb);

        final deckId = await firstDeckRepo.createDeck(
          title: 'Deck Persisten',
          sourceLang: 'id',
          targetLang: 'en',
        );
        final cardId = await firstCardRepo.createCard(
          deckId: deckId,
          frontText: 'Kucing',
          backText: 'Cat',
        );

        await firstDb.close();

        // Session 2: Reopen same database file (simulating app restart)
        final reopenedDb = AppDatabase(NativeDatabase(dbFile));
        final reopenedDeckRepo = DriftDeckRepository(reopenedDb);
        final reopenedCardRepo = DriftCardRepository(reopenedDb);

        final persistedDeck = await reopenedDeckRepo.getDeckById(deckId);
        expect(persistedDeck, isNotNull);
        expect(persistedDeck!.title, 'Deck Persisten');

        final persistedCard = await reopenedCardRepo.getCardById(cardId);
        expect(persistedCard, isNotNull);
        expect(persistedCard!.frontText, 'Kucing');
        expect(persistedCard.backText, 'Cat');

        final count = await reopenedDeckRepo.getCardCount(deckId);
        expect(count, 1);

        await reopenedDb.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
