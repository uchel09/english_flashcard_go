import 'dart:math';

import 'package:flutter/material.dart' hide Card;
import 'package:get/get.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/repositories/study_log_repository.dart';
import '../../../data/services/audio_service.dart';

enum QuizDirection {
  frontToBack, // Depan -> Belakang
  backToFront, // Belakang -> Depan
}

class QuizOption {
  final String text;
  final bool isCorrect;
  final Card card;

  QuizOption({
    required this.text,
    required this.isCorrect,
    required this.card,
  });
}

class QuizQuestion {
  final Card card;
  final String promptText;
  final String correctText;
  final List<QuizOption> options;

  QuizQuestion({
    required this.card,
    required this.promptText,
    required this.correctText,
    required this.options,
  });
}

class QuizController extends GetxController {
  final CardRepository _cardRepository;
  final DeckRepository _deckRepository;
  final AudioService _audioService;
  final StudyLogRepository? _studyLogRepository;

  QuizController({
    CardRepository? cardRepository,
    DeckRepository? deckRepository,
    AudioService? audioService,
    StudyLogRepository? studyLogRepository,
  })  : _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _audioService = audioService ?? Get.find<AudioService>(),
        _studyLogRepository = studyLogRepository ??
            (Get.isRegistered<StudyLogRepository>()
                ? Get.find<StudyLogRepository>()
                : null);

  final Rx<Deck?> deck = Rx<Deck?>(null);
  final RxList<Card> allCards = <Card>[].obs;
  final RxList<QuizQuestion> questions = <QuizQuestion>[].obs;

  final Rx<QuizDirection> direction = QuizDirection.frontToBack.obs;
  final RxInt currentIndex = 0.obs;
  final Rxn<QuizOption> selectedOption = Rxn<QuizOption>();
  final RxBool hasAnswered = false.obs;
  final RxBool isCompleted = false.obs;
  final RxBool isLoading = false.obs;

  final RxList<QuizQuestion> correctQuestions = <QuizQuestion>[].obs;
  final RxList<QuizQuestion> wrongQuestions = <QuizQuestion>[].obs;

  QuizQuestion? get currentQuestion =>
      questions.isNotEmpty && currentIndex.value < questions.length
          ? questions[currentIndex.value]
          : null;

  int get score => correctQuestions.length;
  int get totalQuestions => questions.length;
  double get scorePercentage =>
      totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Deck) {
      deck.value = args;
      loadDeckAndStartQuiz(args);
    } else if (args is int) {
      _loadDeckById(args);
    }
  }

  @override
  void onClose() {
    _audioService.stop();
    super.onClose();
  }

  Future<void> _loadDeckById(int id) async {
    isLoading.value = true;
    final found = await _deckRepository.getDeckById(id);
    if (found != null) {
      deck.value = found;
      await loadDeckAndStartQuiz(found);
    }
    isLoading.value = false;
  }

  Future<void> loadDeckAndStartQuiz(Deck currentDeck) async {
    isLoading.value = true;
    try {
      final loadedCards = await _cardRepository.getCardsByDeck(currentDeck.id);
      allCards.assignAll(loadedCards);
      buildQuestions(cardsToUse: loadedCards);
    } catch (e) {
      debugPrint('Error loading cards for quiz: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleDirection() {
    direction.value = direction.value == QuizDirection.frontToBack
        ? QuizDirection.backToFront
        : QuizDirection.frontToBack;
    buildQuestions(cardsToUse: allCards);
  }

  void buildQuestions({List<Card>? cardsToUse}) {
    final pool = cardsToUse ?? allCards;
    if (pool.isEmpty) {
      questions.clear();
      isCompleted.value = false;
      currentIndex.value = 0;
      return;
    }

    final Random rng = Random();
    final List<QuizQuestion> list = [];

    // Shuffle card order for the quiz
    final shuffledCards = List<Card>.from(pool)..shuffle(rng);

    for (final card in shuffledCards) {
      final isFrontToBack = direction.value == QuizDirection.frontToBack;

      final prompt = isFrontToBack ? card.frontText : card.backText;
      final correct = isFrontToBack ? card.backText : card.frontText;

      final correctOption = QuizOption(
        text: correct.isEmpty ? '(Kosong)' : correct,
        isCorrect: true,
        card: card,
      );

      // Collect distractors from other cards in the entire deck
      final otherCards = allCards.where((c) => c.id != card.id).toList()
        ..shuffle(rng);

      // Prefer distractors with distinct text from correct answer and other options
      final List<QuizOption> distractors = [];
      final Set<String> usedTexts = {correct.trim().toLowerCase()};

      for (final other in otherCards) {
        if (distractors.length >= 3) break;
        final distText = isFrontToBack ? other.backText : other.frontText;
        final normalized = distText.trim().toLowerCase();
        if (!usedTexts.contains(normalized)) {
          usedTexts.add(normalized);
          distractors.add(
            QuizOption(
              text: distText.isEmpty ? '(Kosong)' : distText,
              isCorrect: false,
              card: other,
            ),
          );
        }
      }

      // If distinct texts were fewer than min(3, otherCards.length), fill up
      if (distractors.length < min(3, otherCards.length)) {
        for (final other in otherCards) {
          if (distractors.length >= min(3, otherCards.length)) break;
          if (!distractors.any((d) => d.card.id == other.id)) {
            final distText = isFrontToBack ? other.backText : other.frontText;
            distractors.add(
              QuizOption(
                text: distText.isEmpty ? '(Kosong)' : distText,
                isCorrect: false,
                card: other,
              ),
            );
          }
        }
      }

      final options = [correctOption, ...distractors]..shuffle(rng);

      list.add(
        QuizQuestion(
          card: card,
          promptText: prompt.isEmpty ? '(Kosong)' : prompt,
          correctText: correct.isEmpty ? '(Kosong)' : correct,
          options: options,
        ),
      );
    }

    questions.assignAll(list);
    currentIndex.value = 0;
    hasAnswered.value = false;
    selectedOption.value = null;
    isCompleted.value = false;
    correctQuestions.clear();
    wrongQuestions.clear();
  }

  void selectOption(QuizOption option) {
    if (hasAnswered.value || currentQuestion == null) return;

    hasAnswered.value = true;
    selectedOption.value = option;

    final question = currentQuestion!;
    if (option.isCorrect) {
      correctQuestions.add(question);
    } else {
      wrongQuestions.add(question);
    }

    if (_studyLogRepository != null && deck.value != null) {
      _studyLogRepository.recordLog(
        cardId: question.card.id,
        deckId: deck.value!.id,
        isQuiz: true,
        isCorrect: option.isCorrect,
      );
    }
  }

  void nextQuestion() {
    _audioService.stop();
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
      hasAnswered.value = false;
      selectedOption.value = null;
    } else {
      isCompleted.value = true;
    }
  }

  void retryWrongQuestions() {
    if (wrongQuestions.isEmpty) return;
    final wrongCards = wrongQuestions.map((q) => q.card).toList();
    buildQuestions(cardsToUse: wrongCards);
  }

  void restartQuiz() {
    buildQuestions(cardsToUse: allCards);
  }

  Future<void> playPromptAudio() async {
    final question = currentQuestion;
    if (question == null) return;

    final isFront = direction.value == QuizDirection.frontToBack;
    final sourceLang = deck.value?.sourceLang ?? 'id';

    await _audioService.playCardSide(
      card: question.card,
      side: isFront ? CardSide.front : CardSide.back,
      sourceLang: sourceLang,
    );
  }
}
