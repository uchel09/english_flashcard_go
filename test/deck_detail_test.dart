import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/modules/deck_detail/controllers/deck_detail_controller.dart';

class MockAudioService extends AudioService {
  String? lastPlayedType; // 'recording' or 'tts'
  String? lastSpokenText;
  String? lastLocale;
  String? lastFilePath;
  bool stopCalled = false;

  @override
  Future<void> stop() async {
    stopCalled = true;
    isPlaying.value = false;
    activeCardId.value = null;
    activeSide.value = null;
  }

  @override
  Future<void> playCardSide({
    required Card card,
    required CardSide side,
    String sourceLang = 'id',
  }) async {
    await stop();

    isPlaying.value = true;
    activeCardId.value = card.id;
    activeSide.value = side;

    final recordingPath =
        side == CardSide.front ? card.frontAudioPath : card.backAudioPath;

    if (recordingPath != null &&
        recordingPath.isNotEmpty &&
        File(recordingPath).existsSync()) {
      lastPlayedType = 'recording';
      lastFilePath = recordingPath;
      return;
    }

    lastPlayedType = 'tts';
    if (side == CardSide.front) {
      lastLocale = sourceLang == 'id' ? 'id-ID' : 'en-US';
      lastSpokenText = card.frontText;
    } else {
      lastLocale = 'en-US';
      lastSpokenText = card.backText;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeckDetailController & AudioService rules', () {
    late AppDatabase db;
    late DeckRepository deckRepo;
    late CardRepository cardRepo;
    late MockAudioService mockAudio;
    late Deck testDeck;

    setUp(() async {
      Get.reset();
      db = AppDatabase(NativeDatabase.memory());
      deckRepo = DriftDeckRepository(db);
      cardRepo = DriftCardRepository(db);
      mockAudio = MockAudioService();

      Get.put<AppDatabase>(db, permanent: true);
      Get.put<DeckRepository>(deckRepo, permanent: true);
      Get.put<CardRepository>(cardRepo, permanent: true);
      Get.put<AudioService>(mockAudio, permanent: true);

      final deckId = await deckRepo.createDeck(
        title: 'Kosakata Alam',
        sourceLang: 'id',
        targetLang: 'en',
      );
      testDeck = (await deckRepo.getDeckById(deckId))!;
    });

    tearDown(() async {
      await db.close();
    });

    test('AudioService plays TTS when no recording exists, with correct locales',
        () async {
      final cardId = await cardRepo.createCard(
        deckId: testDeck.id,
        frontText: 'Pohon',
        backText: 'Tree',
      );
      final card = (await cardRepo.getCardById(cardId))!;

      // Play front side
      await mockAudio.playCardSide(
        card: card,
        side: CardSide.front,
        sourceLang: 'id',
      );
      expect(mockAudio.stopCalled, isTrue);
      expect(mockAudio.lastPlayedType, 'tts');
      expect(mockAudio.lastLocale, 'id-ID');
      expect(mockAudio.lastSpokenText, 'Pohon');

      // Play back side
      await mockAudio.playCardSide(
        card: card,
        side: CardSide.back,
        sourceLang: 'id',
      );
      expect(mockAudio.lastPlayedType, 'tts');
      expect(mockAudio.lastLocale, 'en-US');
      expect(mockAudio.lastSpokenText, 'Tree');
    });

    test('AudioService prioritizes recording when file exists', () async {
      final tempDir = await Directory.systemTemp.createTemp('audio_test_');
      final tempAudioFile = File('${tempDir.path}/test_recording.m4a');
      await tempAudioFile.writeAsString('fake audio content');

      try {
        final cardId = await cardRepo.createCard(
          deckId: testDeck.id,
          frontText: 'Sungai',
          backText: 'River',
          frontAudioPath: tempAudioFile.path,
        );
        final card = (await cardRepo.getCardById(cardId))!;

        // Play front (has recording)
        await mockAudio.playCardSide(
          card: card,
          side: CardSide.front,
          sourceLang: 'id',
        );
        expect(mockAudio.lastPlayedType, 'recording');
        expect(mockAudio.lastFilePath, tempAudioFile.path);

        // Play back (no recording, falls back to TTS)
        await mockAudio.playCardSide(
          card: card,
          side: CardSide.back,
          sourceLang: 'id',
        );
        expect(mockAudio.lastPlayedType, 'tts');
        expect(mockAudio.lastLocale, 'en-US');
        expect(mockAudio.lastSpokenText, 'River');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('Difficulty is updated and persisted in DB via CardRepository', () async {
      final cardId = await cardRepo.createCard(
        deckId: testDeck.id,
        frontText: 'Gunung',
        backText: 'Mountain',
        difficulty: 0,
      );

      final controller = DeckDetailController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: mockAudio,
      );
      controller.deck.value = testDeck;
      await controller.loadCards();

      final initialCard = controller.cards.first;
      expect(initialCard.difficulty, 0);

      // Set to Mudah (1)
      await controller.setDifficulty(initialCard, 1);
      final updated1 = await cardRepo.getCardById(cardId);
      expect(updated1!.difficulty, 1);

      // Set to Sedang (2)
      await controller.setDifficulty(initialCard, 2);
      final updated2 = await cardRepo.getCardById(cardId);
      expect(updated2!.difficulty, 2);

      // Set to Sulit (3)
      await controller.setDifficulty(initialCard, 3);
      final updated3 = await cardRepo.getCardById(cardId);
      expect(updated3!.difficulty, 3);
    });

    test('Search filtering filters cards by frontText and backText', () async {
      await cardRepo.createCard(
        deckId: testDeck.id,
        frontText: 'Laut',
        backText: 'Sea',
      );
      await cardRepo.createCard(
        deckId: testDeck.id,
        frontText: 'Danau',
        backText: 'Lake',
      );

      final controller = DeckDetailController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: mockAudio,
      );
      controller.deck.value = testDeck;
      await controller.loadCards();

      expect(controller.filteredCards.length, 2);

      // Search front text
      controller.onSearchChanged('Laut');
      expect(controller.filteredCards.length, 1);
      expect(controller.filteredCards.first.frontText, 'Laut');

      // Search back text
      controller.onSearchChanged('lake');
      expect(controller.filteredCards.length, 1);
      expect(controller.filteredCards.first.backText, 'Lake');

      // Clear search
      controller.onSearchChanged('');
      expect(controller.filteredCards.length, 2);
    });
  });
}
