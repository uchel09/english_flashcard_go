import 'dart:async';
import 'package:flutter/material.dart' hide Card;
import 'package:get/get.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/sm2_service.dart';

class DeckDetailController extends GetxController {
  final CardRepository _cardRepository;
  final DeckRepository _deckRepository;
  final AudioService _audioService;

  DeckDetailController({
    CardRepository? cardRepository,
    DeckRepository? deckRepository,
    AudioService? audioService,
  })  : _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _audioService = audioService ?? Get.find<AudioService>();

  final Rx<Deck?> deck = Rx<Deck?>(null);
  final RxList<Card> cards = <Card>[].obs;
  final RxList<Card> filteredCards = <Card>[].obs;
  final RxInt dueCardCount = 0.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Search state
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;
  final TextEditingController searchController = TextEditingController();

  // Expand / Minimize states per card ID
  final RxSet<int> minimizedCardIds = <int>{}.obs;
  final RxSet<int> expandedFrontTextIds = <int>{}.obs;
  final RxSet<int> expandedBackTextIds = <int>{}.obs;

  StreamSubscription<List<Card>>? _cardsSubscription;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Deck) {
      deck.value = args;
      _initCardsListener(args.id);
      loadCards();
    } else if (args is int) {
      _loadDeckById(args);
    }
  }

  @override
  void onClose() {
    _cardsSubscription?.cancel();
    searchController.dispose();
    _audioService.stop();
    super.onClose();
  }

  Future<void> _loadDeckById(int id) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final found = await _deckRepository.getDeckById(id);
      if (found != null) {
        deck.value = found;
        _initCardsListener(found.id);
        await loadCards();
      } else {
        errorMessage.value = 'Deck tidak ditemukan.';
      }
    } catch (e) {
      errorMessage.value = 'Gagal memuat detail deck: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _initCardsListener(int deckId) {
    _cardsSubscription?.cancel();
    _cardsSubscription = _cardRepository.watchCardsByDeck(deckId).listen((data) async {
      cards.assignAll(data);
      _applySearchFilter();
      dueCardCount.value = await _cardRepository.countDueCardsByDeck(deckId);
    });
  }

  Future<void> loadCards() async {
    final current = deck.value;
    if (current == null) return;
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final loaded = await _cardRepository.getCardsByDeck(current.id);
      cards.assignAll(loaded);
      dueCardCount.value = await _cardRepository.countDueCardsByDeck(current.id);
      _applySearchFilter();
    } catch (e) {
      debugPrint('Error loading cards: $e');
      errorMessage.value = 'Gagal memuat kartu: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    _applySearchFilter();
  }

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
      searchController.clear();
      _applySearchFilter();
    }
  }

  void _applySearchFilter() {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      filteredCards.assignAll(cards);
    } else {
      filteredCards.assignAll(
        cards.where((card) {
          final frontMatch = card.frontText.toLowerCase().contains(query);
          final backMatch = card.backText.toLowerCase().contains(query);
          return frontMatch || backMatch;
        }),
      );
    }
  }

  void toggleCardMinimized(int cardId) {
    if (minimizedCardIds.contains(cardId)) {
      minimizedCardIds.remove(cardId);
    } else {
      minimizedCardIds.add(cardId);
    }
  }

  bool isCardMinimized(int cardId) => minimizedCardIds.contains(cardId);

  void toggleFrontTextExpanded(int cardId) {
    if (expandedFrontTextIds.contains(cardId)) {
      expandedFrontTextIds.remove(cardId);
    } else {
      expandedFrontTextIds.add(cardId);
    }
  }

  bool isFrontTextExpanded(int cardId) => expandedFrontTextIds.contains(cardId);

  void toggleBackTextExpanded(int cardId) {
    if (expandedBackTextIds.contains(cardId)) {
      expandedBackTextIds.remove(cardId);
    } else {
      expandedBackTextIds.add(cardId);
    }
  }

  bool isBackTextExpanded(int cardId) => expandedBackTextIds.contains(cardId);

  Future<void> setDifficulty(Card card, int difficulty) async {
    try {
      final initialEase = Sm2Service.getInitialEase(difficulty);
      await _cardRepository.updateCardData(
        id: card.id,
        difficulty: difficulty,
        ease: initialEase,
      );
      await loadCards();
    } catch (e) {
      debugPrint('Error updating difficulty: $e');
    }
  }

  Future<void> playAudio(Card card, CardSide side) async {
    final sourceLang = deck.value?.sourceLang ?? 'id';
    await _audioService.playCardSide(
      card: card,
      side: side,
      sourceLang: sourceLang,
    );
  }

  bool isPlaying(int cardId, CardSide side) {
    return _audioService.isCardSidePlaying(cardId, side);
  }

  Future<void> deleteCard(Card card) async {
    await _cardRepository.softDeleteCard(card.id);
    await loadCards();

    Get.showSnackbar(
      GetSnackBar(
        title: 'Kartu Dihapus',
        message: 'Kartu "${card.frontText}" dipindahkan ke tempat sampah.',
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () async {
            if (Get.isSnackbarOpen) {
              Get.closeCurrentSnackbar();
            }
            await _cardRepository.restoreCard(card.id);
            await loadCards();
          },
          child: const Text(
            'Urungkan',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
