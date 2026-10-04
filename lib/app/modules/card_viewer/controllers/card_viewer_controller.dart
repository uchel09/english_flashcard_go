import 'package:get/get.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/study_log_repository.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/sm2_service.dart';

class CardViewerController extends GetxController {
  final CardRepository _cardRepository;
  final AudioService _audioService;
  final StudyLogRepository? _studyLogRepository;

  CardViewerController({
    CardRepository? cardRepository,
    AudioService? audioService,
    StudyLogRepository? studyLogRepository,
  })  : _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _audioService = audioService ?? Get.find<AudioService>(),
        _studyLogRepository = studyLogRepository ??
            (Get.isRegistered<StudyLogRepository>()
                ? Get.find<StudyLogRepository>()
                : null);

  final Rx<Deck?> deck = Rx<Deck?>(null);
  final RxList<Card> cards = <Card>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxBool isFlipped = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Study mode (Belajar Hari Ini - SM-2)
  final RxBool isStudyMode = false.obs;
  final RxInt studiedCount = 0.obs;
  final RxBool isFinished = false.obs;
  final RxBool isSavingRating = false.obs;

  Card? get currentCard => cards.isNotEmpty && currentIndex.value < cards.length
      ? cards[currentIndex.value]
      : null;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      if (args['isStudyMode'] == true) {
        isStudyMode.value = true;
      }
      if (args['deck'] is Deck) deck.value = args['deck'] as Deck;
      if (args['cards'] is List<Card>) {
        cards.assignAll(args['cards'] as List<Card>);
      }
      if (args['card'] is Card) {
        final targetCard = args['card'] as Card;
        final idx = cards.indexWhere((c) => c.id == targetCard.id);
        if (idx != -1) currentIndex.value = idx;
      }

      if (isStudyMode.value && deck.value != null && cards.isEmpty) {
        loadDueCards(deck.value!.id);
      }
    } else if (args is Deck) {
      deck.value = args;
      loadCards(args.id);
    }
  }

  @override
  void onClose() {
    _audioService.stop();
    super.onClose();
  }

  Future<void> loadCards(int deckId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loaded = await _cardRepository.getCardsByDeck(deckId);
      cards.assignAll(loaded);
    } catch (e) {
      errorMessage.value = 'Gagal memuat kartu: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadDueCards(int deckId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loaded = await _cardRepository.getDueCardsByDeck(deckId);
      cards.assignAll(loaded);
      currentIndex.value = 0;
      isFlipped.value = false;
      isFinished.value = false;
      studiedCount.value = 0;
    } catch (e) {
      errorMessage.value = 'Gagal memuat kartu jatuh tempo: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void flipCard() {
    isFlipped.value = !isFlipped.value;
  }

  void nextCard() {
    if (currentIndex.value < cards.length - 1) {
      currentIndex.value++;
      isFlipped.value = false;
      _audioService.stop();
    }
  }

  void previousCard() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      isFlipped.value = false;
      _audioService.stop();
    }
  }

  Future<void> rateCard(ReviewRating rating) async {
    final card = currentCard;
    if (card == null || isSavingRating.value) return;

    try {
      isSavingRating.value = true;
      _audioService.stop();

      final result = Sm2Service.calculateReview(card: card, rating: rating);

      await _cardRepository.updateCardData(
        id: card.id,
        ease: result.ease,
        intervalDays: result.intervalDays,
        nextReviewAt: result.nextReviewAt,
        difficulty: result.difficulty,
      );

      if (_studyLogRepository != null) {
        await _studyLogRepository.recordLog(
          cardId: card.id,
          deckId: card.deckId,
          rating: rating.index,
          isQuiz: false,
          isCorrect: rating != ReviewRating.again,
        );
      }

      studiedCount.value++;

      if (currentIndex.value < cards.length - 1) {
        currentIndex.value++;
        isFlipped.value = false;
      } else {
        isFinished.value = true;
      }
    } catch (e) {
      errorMessage.value = 'Gagal menyimpan hasil penilaian: $e';
    } finally {
      isSavingRating.value = false;
    }
  }

  void restartSession() {
    final d = deck.value;
    if (d == null) return;
    if (isStudyMode.value) {
      loadDueCards(d.id);
    } else {
      loadCards(d.id);
    }
  }

  Future<void> playAudio(CardSide side) async {
    final card = currentCard;
    if (card == null) return;
    final sourceLang = deck.value?.sourceLang ?? 'id';
    await _audioService.playCardSide(
      card: card,
      side: side,
      sourceLang: sourceLang,
    );
  }

  bool isPlaying(CardSide side) {
    final card = currentCard;
    if (card == null) return false;
    return _audioService.isCardSidePlaying(card.id, side);
  }
}
