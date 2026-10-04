import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/import_service.dart';

class DeckItemModel {
  final Deck deck;
  final int cardCount;
  final int subDeckCount;
  final int dueCardCount;

  DeckItemModel({
    required this.deck,
    required this.cardCount,
    this.subDeckCount = 0,
    this.dueCardCount = 0,
  });
}

class HomeController extends GetxController {
  static HomeController get to => Get.find<HomeController>();

  final DeckRepository _deckRepository;
  final ExportService _exportService;
  final ImportService _importService;

  HomeController({
    DeckRepository? deckRepository,
    ExportService? exportService,
    ImportService? importService,
  })  : _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _exportService = exportService ??
            (Get.isRegistered<ExportService>()
                ? Get.find<ExportService>()
                : ExportService(
                    deckRepository: deckRepository ??
                        (Get.isRegistered<DeckRepository>()
                            ? Get.find<DeckRepository>()
                            : null),
                  )),
        _importService = importService ??
            (Get.isRegistered<ImportService>()
                ? Get.find<ImportService>()
                : ImportService(
                    deckRepository: deckRepository ??
                        (Get.isRegistered<DeckRepository>()
                            ? Get.find<DeckRepository>()
                            : null),
                  ));

  final RxList<DeckItemModel> regularDecks = <DeckItemModel>[].obs;
  final RxList<DeckItemModel> premiumDecks = <DeckItemModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  StreamSubscription<List<Deck>>? _decksSubscription;

  @override
  void onInit() {
    super.onInit();
    refreshDecks();
    _decksSubscription = _deckRepository.watchRootDecks().listen((_) {
      refreshDecks();
    });
  }

  @override
  void onClose() {
    _decksSubscription?.cancel();
    super.onClose();
  }

  Future<void> refreshDecks() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final rootDecks = await _deckRepository.getRootDecks();

      final List<DeckItemModel> regulars = [];
      final List<DeckItemModel> premiums = [];

      for (final deck in rootDecks) {
        final cardCount = await _deckRepository.getCardCount(deck.id);
        int subDeckCount = 0;
        int dueCardCount = 0;

        if (deck.isPremium) {
          final subDecks = await _deckRepository.getSubDecks(deck.id);
          subDeckCount = subDecks.length;
          dueCardCount = await _deckRepository.getDueCardCount(deck.id);
          for (final sub in subDecks) {
            dueCardCount += await _deckRepository.getDueCardCount(sub.id);
          }
        } else {
          dueCardCount = await _deckRepository.getDueCardCount(deck.id);
        }

        final item = DeckItemModel(
          deck: deck,
          cardCount: cardCount,
          subDeckCount: subDeckCount,
          dueCardCount: dueCardCount,
        );

        if (deck.isPremium) {
          premiums.add(item);
        } else {
          regulars.add(item);
        }
      }

      regularDecks.assignAll(regulars);
      premiumDecks.assignAll(premiums);
    } catch (e) {
      debugPrint('Error refreshing decks: $e');
      errorMessage.value = 'Gagal memuat daftar deck: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createDeck({
    required String title,
    required String sourceLang,
    required bool isPremium,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    await _deckRepository.createDeck(
      title: trimmed,
      sourceLang: sourceLang,
      targetLang: 'en',
      isPremium: isPremium,
    );
    await refreshDecks();
  }

  Future<void> renameDeck({
    required int id,
    required String newTitle,
  }) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;

    await _deckRepository.updateDeckData(id: id, title: trimmed);
    await refreshDecks();
  }

  Future<void> softDeleteDeck(Deck deck) async {
    await _deckRepository.softDeleteDeck(deck.id);
    await refreshDecks();

    Get.showSnackbar(
      GetSnackBar(
        title: 'Deck Dihapus',
        message: 'Deck "${deck.title}" dipindahkan ke tempat sampah.',
        duration: const Duration(seconds: 4),
        snackPosition: SnackPosition.BOTTOM,
        mainButton: TextButton(
          onPressed: () async {
            if (Get.isSnackbarOpen) {
              Get.closeCurrentSnackbar();
            }
            await restoreDeck(deck.id);
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

  Future<void> restoreDeck(int id) async {
    await _deckRepository.restoreDeck(id);
    await refreshDecks();
    Get.snackbar(
      'Dipulihkan',
      'Deck berhasil dikembalikan.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  Future<List<DeckItemModel>> getSubDecks(int parentId) async {
    final subDecks = await _deckRepository.getSubDecks(parentId);
    final List<DeckItemModel> list = [];
    for (final sub in subDecks) {
      final cardCount = await _deckRepository.getCardCount(sub.id);
      final dueCardCount = await _deckRepository.getDueCardCount(sub.id);
      list.add(
        DeckItemModel(
          deck: sub,
          cardCount: cardCount,
          dueCardCount: dueCardCount,
        ),
      );
    }
    return list;
  }

  Future<void> createSubDeck({
    required int parentId,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    await _deckRepository.createDeck(
      title: trimmed,
      parentId: parentId,
      isPremium: true,
      sourceLang: 'id',
      targetLang: 'en',
    );
    await refreshDecks();
  }

  Future<void> hardDeleteSubDeck(int subDeckId) async {
    await _deckRepository.hardDeleteDeck(subDeckId);
    await refreshDecks();
  }

  Future<void> exportDeck(Deck deck) async {
    try {
      Get.snackbar(
        'Mengekspor Deck',
        'Menyiapkan file .flashdeck untuk "${deck.title}"...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      final file = await _exportService.exportDeck(deck: deck, share: true);

      Get.snackbar(
        'Ekspor Berhasil',
        'File "${file.path.split(RegExp(r'[\\/]')).last}" siap dibagikan.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar(
        'Gagal Ekspor',
        'Terjadi kesalahan saat mengekspor: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> importDeck() async {
    try {
      final importedDeck = await _importService.pickAndImportDeck();
      if (importedDeck != null) {
        await refreshDecks();
        Get.snackbar(
          'Berhasil Impor',
          'Deck "${importedDeck.title}" berhasil diimpor dan siap digunakan.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Gagal Impor',
        e is ImportException
            ? e.message
            : 'Terjadi kesalahan saat mengimpor deck: $e',
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
