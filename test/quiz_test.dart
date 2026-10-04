import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/modules/quiz/controllers/quiz_controller.dart';

class MockAudioService extends AudioService {
  bool stopCalled = false;
  Card? lastPlayedCard;
  CardSide? lastPlayedSide;
  String? lastSourceLang;

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
    lastPlayedCard = card;
    lastPlayedSide = side;
    lastSourceLang = sourceLang;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late MockAudioService audioService;

  setUp(() {
    Get.reset();
    db = AppDatabase(NativeDatabase.memory());
    deckRepo = DriftDeckRepository(db);
    cardRepo = DriftCardRepository(db);
    audioService = MockAudioService();

    Get.put<DeckRepository>(deckRepo);
    Get.put<CardRepository>(cardRepo);
    Get.put<AudioService>(audioService);
  });

  tearDown(() async {
    await db.close();
    Get.reset();
  });

  group('QuizController Tests', () {
    test('Deck dengan 1 kartu menghasilkan 1 soal dengan tepat 1 opsi (jawaban benar)', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck 1 Kartu',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'kucing',
        backText: 'cat',
      );

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      expect(controller.allCards.length, 1);
      expect(controller.totalQuestions, 1);

      final question = controller.currentQuestion;
      expect(question, isNotNull);
      expect(question!.promptText, 'kucing');
      expect(question.correctText, 'cat');

      // Karena hanya ada 1 kartu, hanya ada 1 opsi (opsi yang benar)
      expect(question.options.length, 1);
      expect(question.options.first.text, 'cat');
      expect(question.options.first.isCorrect, isTrue);
    });

    test('Deck dengan 3 kartu menghasilkan 3 soal, tiap soal 3 opsi (1 benar, 2 pengecoh)', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck 3 Kartu',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      final words = [
        ('kucing', 'cat'),
        ('anjing', 'dog'),
        ('burung', 'bird'),
      ];

      for (final w in words) {
        await cardRepo.createCard(
          deckId: deckId,
          frontText: w.$1,
          backText: w.$2,
        );
      }

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      expect(controller.allCards.length, 3);
      expect(controller.totalQuestions, 3);

      for (final question in controller.questions) {
        expect(question.options.length, 3);

        final correctOptions = question.options.where((o) => o.isCorrect).toList();
        final distractorOptions = question.options.where((o) => !o.isCorrect).toList();

        expect(correctOptions.length, 1);
        expect(distractorOptions.length, 2);
        expect(correctOptions.first.text, question.correctText);
      }
    });

    test('Deck dengan 20 kartu menghasilkan 20 soal, tiap soal 4 opsi (1 benar, 3 pengecoh)', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck 20 Kartu',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      for (int i = 1; i <= 20; i++) {
        await cardRepo.createCard(
          deckId: deckId,
          frontText: 'kata_$i',
          backText: 'word_$i',
        );
      }

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      expect(controller.allCards.length, 20);
      expect(controller.totalQuestions, 20);

      for (final question in controller.questions) {
        // Tepat 4 opsi untuk deck >= 4 kartu
        expect(question.options.length, 4);

        final correctOptions = question.options.where((o) => o.isCorrect).toList();
        final distractorOptions = question.options.where((o) => !o.isCorrect).toList();

        expect(correctOptions.length, 1);
        expect(distractorOptions.length, 3);
        expect(correctOptions.first.text, question.correctText);

        // Pastikan pengecoh bukan kartu yang sama
        for (final distractor in distractorOptions) {
          expect(distractor.card.id, isNot(equals(question.card.id)));
        }
      }
    });

    test('Toggle arah kuis (frontToBack vs backToFront)', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck Bahasa',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'buku',
        backText: 'book',
      );
      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'meja',
        backText: 'table',
      );

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      // Default: frontToBack (ID -> EN)
      expect(controller.direction.value, QuizDirection.frontToBack);
      final qFront = controller.questions.firstWhere((q) => q.card.frontText == 'buku');
      expect(qFront.promptText, 'buku');
      expect(qFront.correctText, 'book');

      // Toggle to backToFront (EN -> ID)
      controller.toggleDirection();
      expect(controller.direction.value, QuizDirection.backToFront);

      final qBack = controller.questions.firstWhere((q) => q.card.frontText == 'buku');
      expect(qBack.promptText, 'book');
      expect(qBack.correctText, 'buku');
    });

    test('Skoring, alur menjawab, ringkasan, dan ulangi yang salah', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck Latihan',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'apel',
        backText: 'apple',
      );
      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'pisang',
        backText: 'banana',
      );

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      // Jawab soal 1 dengan benar
      final q1CorrectOption = controller.questions[0].options.firstWhere((o) => o.isCorrect);
      controller.selectOption(q1CorrectOption);
      expect(controller.hasAnswered.value, isTrue);
      expect(controller.score, 1);
      expect(controller.correctQuestions.length, 1);
      expect(controller.wrongQuestions.length, 0);

      // Lanjut ke soal 2
      controller.nextQuestion();
      expect(controller.currentIndex.value, 1);
      expect(controller.hasAnswered.value, isFalse);

      // Jawab soal 2 dengan salah (pilih opsi yang isCorrect == false)
      final q2WrongOption = controller.questions[1].options.firstWhere((o) => !o.isCorrect);
      controller.selectOption(q2WrongOption);
      expect(controller.score, 1);
      expect(controller.wrongQuestions.length, 1);

      // Selesaikan kuis
      controller.nextQuestion();
      expect(controller.isCompleted.value, isTrue);
      expect(controller.scorePercentage, 50.0);

      // Uji "Ulangi yang salah"
      final wrongCardId = controller.wrongQuestions.first.card.id;
      controller.retryWrongQuestions();
      expect(controller.isCompleted.value, isFalse);
      expect(controller.totalQuestions, 1);
      expect(controller.questions.first.card.id, wrongCardId);
    });

    test('Audio prompt dipanggil sesuai arah soal dan sourceLang deck', () async {
      final deckId = await deckRepo.createDeck(
        title: 'Deck Audio Test',
        sourceLang: 'id',
        isPremium: false,
      );
      final currentDeck = (await deckRepo.getDeckById(deckId))!;

      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'mobil',
        backText: 'car',
      );

      final controller = QuizController(
        cardRepository: cardRepo,
        deckRepository: deckRepo,
        audioService: audioService,
      );

      await controller.loadDeckAndStartQuiz(currentDeck);

      // Putar audio prompt untuk arah default (frontToBack: sisi depan, sourceLang 'id')
      await controller.playPromptAudio();
      expect(audioService.isPlaying.value, isTrue);
      expect(audioService.lastPlayedSide, CardSide.front);
      expect(audioService.lastSourceLang, 'id');

      // Ganti arah ke backToFront
      controller.toggleDirection();
      await controller.playPromptAudio();
      expect(audioService.lastPlayedSide, CardSide.back);
    });
  });
}
