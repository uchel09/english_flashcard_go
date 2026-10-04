import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/data/services/sm2_service.dart';
import 'package:english_flashcard_go/app/modules/card_viewer/controllers/card_viewer_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SM-2 Spaced Repetition & Ease Mapping Tests', () {
    test('Pemetaan warna kesulitan lama ke ease awal sesuai rancangan', () {
      expect(Sm2Service.getInitialEase(1), 2.7); // Hijau (Mudah) -> 2.7
      expect(Sm2Service.getInitialEase(2), 2.5); // Kuning (Sedang) -> 2.5
      expect(Sm2Service.getInitialEase(3), 2.0); // Merah (Sulit) -> 2.0
      expect(Sm2Service.getInitialEase(0), 2.5); // Belum dinilai -> 2.5
    });

    test('Kalkulasi SM-2 untuk rating Lagi (Again)', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final card = Card(
        id: 1,
        deckId: 1,
        frontText: 'Cat',
        backText: 'Kucing',
        difficulty: 2,
        ease: 2.5,
        intervalDays: 6,
        createdAt: now,
        updatedAt: now,
      );

      final result = Sm2Service.calculateReview(
        card: card,
        rating: ReviewRating.again,
        reviewedAt: now,
      );

      expect(result.intervalDays, 1);
      expect(result.ease, 2.30); // 2.5 - 0.20
      expect(result.difficulty, 3); // Sulit / Merah
      expect(result.nextReviewAt, now.add(const Duration(days: 1)));
    });

    test('Kalkulasi SM-2 untuk rating Sulit (Hard)', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final card = Card(
        id: 1,
        deckId: 1,
        frontText: 'Cat',
        backText: 'Kucing',
        difficulty: 2,
        ease: 2.5,
        intervalDays: 5,
        createdAt: now,
        updatedAt: now,
      );

      final result = Sm2Service.calculateReview(
        card: card,
        rating: ReviewRating.hard,
        reviewedAt: now,
      );

      expect(result.intervalDays, 6); // 5 * 1.2 = 6
      expect(result.ease, 2.35); // 2.5 - 0.15
      expect(result.difficulty, 3);
      expect(result.nextReviewAt, now.add(const Duration(days: 6)));
    });

    test('Kalkulasi SM-2 untuk rating Bagus (Good)', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final card = Card(
        id: 1,
        deckId: 1,
        frontText: 'Cat',
        backText: 'Kucing',
        difficulty: 2,
        ease: 2.5,
        intervalDays: 4,
        createdAt: now,
        updatedAt: now,
      );

      final result = Sm2Service.calculateReview(
        card: card,
        rating: ReviewRating.good,
        reviewedAt: now,
      );

      expect(result.intervalDays, 10); // 4 * 2.5 = 10
      expect(result.ease, 2.5); // Ease tetap
      expect(result.difficulty, 2);
      expect(result.nextReviewAt, now.add(const Duration(days: 10)));
    });

    test('Kalkulasi SM-2 untuk rating Mudah (Easy)', () {
      final now = DateTime(2026, 10, 3, 12, 0);
      final card = Card(
        id: 1,
        deckId: 1,
        frontText: 'Cat',
        backText: 'Kucing',
        difficulty: 2,
        ease: 2.5,
        intervalDays: 4,
        createdAt: now,
        updatedAt: now,
      );

      final result = Sm2Service.calculateReview(
        card: card,
        rating: ReviewRating.easy,
        reviewedAt: now,
      );

      // ease: 2.5 + 0.15 = 2.65
      // interval: (4 * 2.65 * 1.3) = 13.78 -> 14
      expect(result.ease, 2.65);
      expect(result.intervalDays, 14);
      expect(result.difficulty, 1);
      expect(result.nextReviewAt, now.add(const Duration(days: 14)));
    });

    test(
      'Kartu baru belum pernah direview menggunakan ease dari kesulitan lama',
      () {
        final now = DateTime(2026, 10, 3, 12, 0);
        // Kartu lama dengan difficulty = 1 (Mudah / Hijau), intervalDays = 0, default ease 2.5
        final card = Card(
          id: 1,
          deckId: 1,
          frontText: 'Book',
          backText: 'Buku',
          difficulty: 1,
          ease: 2.5,
          intervalDays: 0,
          createdAt: now,
          updatedAt: now,
        );

        final result = Sm2Service.calculateReview(
          card: card,
          rating: ReviewRating.good,
          reviewedAt: now,
        );

        // Harusnya memakai base ease 2.7 dari difficulty 1
        expect(result.ease, 2.7);
        expect(result.intervalDays, 1);
        expect(result.nextReviewAt, now.add(const Duration(days: 1)));
      },
    );
  });

  group('Due Cards Query & Repository Tests', () {
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

    test(
      'getDueCardsByDeck menyertakan kartu baru dan kartu jatuh tempo',
      () async {
        final now = DateTime(2026, 10, 3, 12, 0);
        final deckId = await deckRepo.createDeck(title: 'Deck Bahasa');

        // 1. Kartu baru (nextReviewAt == null) -> Harus masuk
        final cardNewId = await cardRepo.createCard(
          deckId: deckId,
          frontText: 'Kartu Baru',
          backText: 'New Card',
          nextReviewAt: null,
        );

        // 2. Kartu jatuh tempo (nextReviewAt <= now) -> Harus masuk
        final cardDueId = await cardRepo.createCard(
          deckId: deckId,
          frontText: 'Kartu Jatuh Tempo',
          backText: 'Overdue Card',
          nextReviewAt: now.subtract(const Duration(hours: 2)),
        );

        // 3. Kartu masa depan (nextReviewAt > now) -> Tidak boleh masuk
        await cardRepo.createCard(
          deckId: deckId,
          frontText: 'Kartu Masa Depan',
          backText: 'Future Card',
          nextReviewAt: now.add(const Duration(days: 3)),
        );

        // 4. Kartu terhapus -> Tidak boleh masuk
        final deletedCardId = await cardRepo.createCard(
          deckId: deckId,
          frontText: 'Kartu Dihapus',
          backText: 'Deleted Card',
          nextReviewAt: now.subtract(const Duration(hours: 1)),
        );
        await cardRepo.softDeleteCard(deletedCardId);

        final dueCards = await cardRepo.getDueCardsByDeck(deckId, asOf: now);
        expect(dueCards.length, 2);
        expect(dueCards.map((c) => c.id).toSet(), {cardNewId, cardDueId});

        final dueCount = await cardRepo.countDueCardsByDeck(deckId, asOf: now);
        expect(dueCount, 2);

        final deckDueCount = await deckRepo.getDueCardCount(deckId, asOf: now);
        expect(deckDueCount, 2);
      },
    );
  });

  group('CardViewerController Study Mode Tests', () {
    late AppDatabase db;
    late CardRepository cardRepo;
    late DeckRepository deckRepo;
    late Directory tempDir;

    setUp(() async {
      Get.reset();
      tempDir = await Directory.systemTemp.createTemp('study_mode_test_');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async => tempDir.path,
          );

      db = AppDatabase(NativeDatabase.memory());
      deckRepo = DriftDeckRepository(db);
      cardRepo = DriftCardRepository(db);

      Get.put<AppDatabase>(db);
      Get.put<DeckRepository>(deckRepo);
      Get.put<CardRepository>(cardRepo);
      Get.put<AudioService>(AudioService());
    });

    tearDown(() async {
      await db.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      Get.reset();
    });

    test(
      'Alur Belajar Hari Ini: Balik kartu, beri rating SM-2, dan simpan ke DB',
      () async {
        final deckId = await deckRepo.createDeck(title: 'Deck Latihan');
        final deck = (await deckRepo.getDeckById(deckId))!;

        // Tambahkan 2 kartu jatuh tempo
        await cardRepo.createCard(
          deckId: deckId,
          frontText: 'House',
          backText: 'Rumah',
          nextReviewAt: null,
        );
        await cardRepo.createCard(
          deckId: deckId,
          frontText: 'Water',
          backText: 'Air',
          nextReviewAt: null,
        );

        final controller = CardViewerController(
          cardRepository: cardRepo,
          audioService: Get.find<AudioService>(),
        );

        controller.deck.value = deck;
        controller.isStudyMode.value = true;
        await controller.loadDueCards(deckId);

        expect(controller.cards.length, 2);
        expect(controller.currentIndex.value, 0);
        expect(controller.isFlipped.value, false);
        expect(controller.isFinished.value, false);

        // Balik kartu pertama
        controller.flipCard();
        expect(controller.isFlipped.value, true);

        // Pengguna menilai 'Bagus'
        await controller.rateCard(ReviewRating.good);

        // Kartu pertama harus tersimpan di DB dengan data SM-2 baru
        final updatedFirstCard = await cardRepo.getCardById(
          controller.cards[0].id,
        );
        expect(updatedFirstCard!.nextReviewAt, isNotNull);
        expect(updatedFirstCard.intervalDays, greaterThan(0));
        expect(updatedFirstCard.ease, 2.5);

        // Harus otomatis berpindah ke kartu kedua
        expect(controller.currentIndex.value, 1);
        expect(controller.isFlipped.value, false);
        expect(controller.studiedCount.value, 1);
        expect(controller.isFinished.value, false);

        // Balik kartu kedua dan beri rating 'Mudah'
        controller.flipCard();
        await controller.rateCard(ReviewRating.easy);

        final updatedSecondCard = await cardRepo.getCardById(
          controller.cards[1].id,
        );
        expect(updatedSecondCard!.nextReviewAt, isNotNull);
        expect(updatedSecondCard.intervalDays, greaterThanOrEqualTo(3));
        expect(updatedSecondCard.ease, 2.65);

        // Semua kartu selesai
        expect(controller.studiedCount.value, 2);
        expect(controller.isFinished.value, true);
      },
    );
  });
}
