import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../repositories/card_repository.dart';
import '../repositories/deck_repository.dart';

class SampleDeckService extends GetxService {
  static SampleDeckService get to => Get.find<SampleDeckService>();

  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;

  SampleDeckService({
    DeckRepository? deckRepository,
    CardRepository? cardRepository,
  }) : _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
       _cardRepository = cardRepository ?? Get.find<CardRepository>();

  /// Menyemai (seed) satu deck contoh bawaan jika basis data belum memiliki deck sama sekali.
  /// Deck ini merupakan deck reguler sehingga bebas diedit, dipelajari, maupun dihapus pengguna.
  Future<bool> seedSampleDeckIfNotExists() async {
    try {
      final existing = await _deckRepository.getAllDecks();
      if (existing.isNotEmpty) {
        return false;
      }

      final deckId = await _deckRepository.createDeck(
        title: 'Kosakata Dasar (Contoh)',
        sourceLang: 'id',
        targetLang: 'en',
        isPremium: false,
        color: Colors.indigo.toARGB32(),
      );

      final sampleCards = [
        {'front': 'Apple', 'back': 'Apel'},
        {'front': 'Book', 'back': 'Buku'},
        {'front': 'House', 'back': 'Rumah'},
        {'front': 'Water', 'back': 'Air'},
        {'front': 'Knowledge', 'back': 'Pengetahuan'},
        {'front': 'Opportunity', 'back': 'Peluang / Kesempatan'},
      ];

      for (final card in sampleCards) {
        await _cardRepository.createCard(
          deckId: deckId,
          frontText: card['front']!,
          backText: card['back']!,
        );
      }

      return true;
    } catch (e) {
      debugPrint('SampleDeckService: Gagal menyemai sample deck: $e');
      return false;
    }
  }
}
