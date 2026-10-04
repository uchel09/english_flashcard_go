import 'package:flutter/material.dart' hide Card;
import 'package:get/get.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/services/media_service.dart';

class TrashController extends GetxController {
  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;
  final MediaService _mediaService;

  TrashController({
    DeckRepository? deckRepository,
    CardRepository? cardRepository,
    MediaService? mediaService,
  })  : _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _mediaService = mediaService ?? Get.find<MediaService>();

  final RxList<Deck> trashDecks = <Deck>[].obs;
  final RxList<Card> trashCards = <Card>[].obs;
  final RxMap<int, int> deckCardCounts = <int, int>{}.obs;
  final RxMap<int, String> cardDeckTitles = <int, String>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadTrash();
  }

  Future<void> loadTrash() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final decks = await _deckRepository.getTrashDecks();
      final cards = await _cardRepository.getTrashCards();

      trashDecks.assignAll(decks);
      trashCards.assignAll(cards);

      // Hitung kartu per deck
      final Map<int, int> counts = {};
      for (final deck in decks) {
        counts[deck.id] = await _deckRepository.getCardCount(
          deck.id,
          includeDeleted: true,
        );
      }
      deckCardCounts.assignAll(counts);

      // Cari judul deck untuk tiap kartu terhapus
      final Map<int, String> titles = {};
      for (final card in cards) {
        if (!titles.containsKey(card.deckId)) {
          final deck = await _deckRepository.getDeckById(card.deckId);
          titles[card.deckId] = deck?.title ?? 'Deck Tidak Diketahui';
        }
      }
      cardDeckTitles.assignAll(titles);
    } catch (e) {
      debugPrint('Error loading trash: $e');
      errorMessage.value = 'Gagal memuat tempat sampah: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> restoreDeck(Deck deck) async {
    try {
      await _deckRepository.restoreDeck(deck.id);
      await loadTrash();

      _showFeedback(
        'Deck Dipulihkan',
        'Deck "${deck.title}" berhasil dipulihkan.',
        backgroundColor: Colors.green.shade700,
      );
    } catch (e) {
      _showErrorFeedback(
        'Gagal Memulihkan',
        'Terjadi kesalahan saat memulihkan deck: $e',
      );
    }
  }

  Future<void> hardDeleteDeck(Deck deck) async {
    try {
      // 1. Ambil subdeck dan kartu-kartu yang terkait untuk pembersihan media
      final subDecks =
          await _deckRepository.getSubDecks(deck.id, includeDeleted: true);
      final allCards = <Card>[];
      allCards.addAll(
        await _cardRepository.getCardsByDeck(deck.id, includeDeleted: true),
      );
      for (final sub in subDecks) {
        allCards.addAll(
          await _cardRepository.getCardsByDeck(sub.id, includeDeleted: true),
        );
      }

      final Set<String> mediaPaths = {};
      for (final card in allCards) {
        if (card.frontAudioPath != null && card.frontAudioPath!.isNotEmpty) {
          mediaPaths.add(card.frontAudioPath!);
        }
        if (card.backAudioPath != null && card.backAudioPath!.isNotEmpty) {
          mediaPaths.add(card.backAudioPath!);
        }
        if (card.frontImagePath != null && card.frontImagePath!.isNotEmpty) {
          mediaPaths.add(card.frontImagePath!);
        }
        if (card.backImagePath != null && card.backImagePath!.isNotEmpty) {
          mediaPaths.add(card.backImagePath!);
        }
      }

      // 2. Hapus permanen dari basis data (SQLite ON DELETE CASCADE menghapus subdeck & kartu)
      await _deckRepository.hardDeleteDeck(deck.id);

      // 3. Hapus berkas media fisik yang tidak lagi digunakan oleh kartu lain
      for (final path in mediaPaths) {
        final isUsed = await _cardRepository.isMediaUsed(path);
        if (!isUsed) {
          await _mediaService.deleteMediaFile(path);
        }
      }

      await loadTrash();

      _showFeedback(
        'Dihapus Permanen',
        'Deck "${deck.title}" dan media terkait telah dihapus permanen.',
      );
    } catch (e) {
      _showErrorFeedback(
        'Gagal Menghapus',
        'Terjadi kesalahan saat menghapus deck permanen: $e',
      );
    }
  }

  Future<void> restoreCard(Card card) async {
    try {
      await _cardRepository.restoreCard(card.id);
      await loadTrash();

      _showFeedback(
        'Kartu Dipulihkan',
        'Kartu "${card.frontText}" berhasil dipulihkan.',
        backgroundColor: Colors.green.shade700,
      );
    } catch (e) {
      _showErrorFeedback(
        'Gagal Memulihkan',
        'Terjadi kesalahan saat memulihkan kartu: $e',
      );
    }
  }

  Future<void> hardDeleteCard(Card card) async {
    try {
      final List<String> candidatePaths = [];
      if (card.frontAudioPath != null && card.frontAudioPath!.isNotEmpty) {
        candidatePaths.add(card.frontAudioPath!);
      }
      if (card.backAudioPath != null && card.backAudioPath!.isNotEmpty) {
        candidatePaths.add(card.backAudioPath!);
      }
      if (card.frontImagePath != null && card.frontImagePath!.isNotEmpty) {
        candidatePaths.add(card.frontImagePath!);
      }
      if (card.backImagePath != null && card.backImagePath!.isNotEmpty) {
        candidatePaths.add(card.backImagePath!);
      }

      // 1. Hapus dari database
      await _cardRepository.hardDeleteCard(card.id);

      // 2. Bersihkan file fisik jika tidak lagi dipakai kartu lain
      for (final path in candidatePaths) {
        final isUsed = await _cardRepository.isMediaUsed(path);
        if (!isUsed) {
          await _mediaService.deleteMediaFile(path);
        }
      }

      await loadTrash();

      _showFeedback(
        'Dihapus Permanen',
        'Kartu "${card.frontText}" telah dihapus permanen.',
      );
    } catch (e) {
      _showErrorFeedback(
        'Gagal Menghapus',
        'Terjadi kesalahan saat menghapus kartu permanen: $e',
      );
    }
  }

  Future<void> emptyTrash() async {
    try {
      // 1. Kumpulkan seluruh kartu dan media dari semua trash deck
      final Set<String> mediaPaths = {};

      for (final deck in trashDecks) {
        final subDecks =
            await _deckRepository.getSubDecks(deck.id, includeDeleted: true);
        final deckCards =
            await _cardRepository.getCardsByDeck(deck.id, includeDeleted: true);
        for (final c in deckCards) {
          _addMediaPaths(c, mediaPaths);
        }
        for (final sub in subDecks) {
          final subCards =
              await _cardRepository.getCardsByDeck(sub.id, includeDeleted: true);
          for (final c in subCards) {
            _addMediaPaths(c, mediaPaths);
          }
        }
      }

      // 2. Kumpulkan media dari kartu terhapus individual
      for (final card in trashCards) {
        _addMediaPaths(card, mediaPaths);
      }

      // 3. Hapus semua deck dari database
      for (final deck in trashDecks) {
        await _deckRepository.hardDeleteDeck(deck.id);
      }

      // 4. Hapus semua kartu dari database
      for (final card in trashCards) {
        await _cardRepository.hardDeleteCard(card.id);
      }

      // 5. Bersihkan berkas media fisik yang tidak lagi dipakai
      for (final path in mediaPaths) {
        final isUsed = await _cardRepository.isMediaUsed(path);
        if (!isUsed) {
          await _mediaService.deleteMediaFile(path);
        }
      }

      await loadTrash();

      _showFeedback(
        'Tempat Sampah Bersih',
        'Semua deck, kartu, dan berkas media terkait telah dihapus permanen.',
      );
    } catch (e) {
      _showErrorFeedback(
        'Gagal Mengosongkan',
        'Terjadi kesalahan saat mengosongkan tempat sampah: $e',
      );
    }
  }

  void _showFeedback(String title, String message, {Color? backgroundColor}) {
    if (Get.context != null) {
      Get.showSnackbar(
        GetSnackBar(
          title: title,
          message: message,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: backgroundColor ?? const Color(0xFF303030),
        ),
      );
    }
  }

  void _showErrorFeedback(String title, String message) {
    if (Get.context != null) {
      Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _addMediaPaths(Card card, Set<String> paths) {
    if (card.frontAudioPath != null && card.frontAudioPath!.isNotEmpty) {
      paths.add(card.frontAudioPath!);
    }
    if (card.backAudioPath != null && card.backAudioPath!.isNotEmpty) {
      paths.add(card.backAudioPath!);
    }
    if (card.frontImagePath != null && card.frontImagePath!.isNotEmpty) {
      paths.add(card.frontImagePath!);
    }
    if (card.backImagePath != null && card.backImagePath!.isNotEmpty) {
      paths.add(card.backImagePath!);
    }
  }
}
