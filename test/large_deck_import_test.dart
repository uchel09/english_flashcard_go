// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempAppDir;

  setUp(() async {
    Get.reset();
    tempAppDir = await Directory.systemTemp.createTemp('large_deck_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => tempAppDir.path,
        );
  });

  tearDown(() async {
    Get.reset();
    if (tempAppDir.existsSync()) {
      tempAppDir.deleteSync(recursive: true);
    }
  });

  test(
    'Ukur performa impor deck besar (1000 kartu) tetap lancar dan cepat',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final mediaService = MediaService();

      final importService = ImportService(
        database: db,
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      );

      // 1. Buat paket .flashdeck sintetis dengan 1000 kartu
      final archive = Archive();
      final List<Map<String, dynamic>> largeCardList = List.generate(
        1000,
        (index) => {
          'front_text': 'Kata Depan #$index',
          'back_text': 'Back Word #$index',
          'difficulty': index % 4,
          'ease': 2.5,
          'interval_days': index % 10,
        },
      );

      final Map<String, dynamic> manifest = {
        'version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'metadata': {
          'title': 'Deck Super Besar (1000 Kartu)',
          'source_lang': 'id',
          'target_lang': 'en',
          'is_premium': false,
          'color': null,
        },
        'cards': largeCardList,
      };

      final jsonBytes = utf8.encode(jsonEncode(manifest));
      archive.addFile(ArchiveFile('deck.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(archive);

      // 2. Ukur waktu eksekusi impor
      final stopwatch = Stopwatch()..start();
      final importedDeck = await importService.importDeckFromBytes(zipBytes);
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      print('=== HASIL PENGUKURAN IMPOR 1000 KARTU ===');
      print('Waktu impor: ${elapsedMs}ms');

      // 3. Verifikasi integritas data
      expect(importedDeck.title, 'Deck Super Besar (1000 Kartu)');

      final cardCount = await deckRepo.getCardCount(importedDeck.id);
      expect(cardCount, 1000);

      final sampleCards = await cardRepo.getCardsByDeck(importedDeck.id);
      expect(sampleCards.length, 1000);
      expect(sampleCards.first.frontText, 'Kata Depan #0');
      expect(sampleCards.last.frontText, 'Kata Depan #999');

      // Verifikasi performa: 1000 kartu harus terimpor dengan sangat cepat (jauh di bawah 5000ms)
      expect(
        elapsedMs,
        lessThan(5000),
        reason:
            'Impor 1000 kartu harus selesai dengan cepat dan lancar tanpa lag',
      );

      await db.close();
    },
  );
}
