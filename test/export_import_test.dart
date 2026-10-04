import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/export_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempAppDirA;
  late Directory tempAppDirB;

  setUp(() async {
    Get.reset();
    tempAppDirA = await Directory.systemTemp.createTemp('device_a_');
    tempAppDirB = await Directory.systemTemp.createTemp('device_b_');
  });

  tearDown(() async {
    Get.reset();
    if (tempAppDirA.existsSync()) {
      tempAppDirA.deleteSync(recursive: true);
    }
    if (tempAppDirB.existsSync()) {
      tempAppDirB.deleteSync(recursive: true);
    }
  });

  group('ExportService and ImportService Round-trip & Error Handling', () {
    test('Round-trip export dan import: deck, subdeck, kartu, dan media identik di HP lain', () async {
      // --- DEVICE A (Export) ---
      // Mock path_provider ke folder Device A
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempAppDirA.path,
      );

      final dbA = AppDatabase(NativeDatabase.memory());
      final deckRepoA = DriftDeckRepository(dbA);
      final cardRepoA = DriftCardRepository(dbA);
      final mediaServiceA = MediaService();

      // Buat file media nyata di Device A
      final audioFileA = File(p.join(tempAppDirA.path, 'media', 'audios', 'rec_halo.m4a'));
      audioFileA.parent.createSync(recursive: true);
      await audioFileA.writeAsString('audio_bytes_halo_device_a');

      final imageFileA = File(p.join(tempAppDirA.path, 'media', 'images', 'img_halo.png'));
      imageFileA.parent.createSync(recursive: true);
      await imageFileA.writeAsString('image_bytes_halo_device_a');

      // Buat deck utama di Device A
      final deckIdA = await deckRepoA.createDeck(
        title: 'Bahasa Sehari-hari',
        sourceLang: 'id',
        targetLang: 'en',
        isPremium: true,
      );
      final deckA = (await deckRepoA.getDeckById(deckIdA))!;

      // Buat kartu 1 dengan media
      await cardRepoA.createCard(
        deckId: deckIdA,
        frontText: 'Halo',
        backText: 'Hello',
        frontAudioPath: 'media/audios/rec_halo.m4a',
        frontImagePath: 'media/images/img_halo.png',
        difficulty: 2,
        ease: 2.7,
        intervalDays: 3,
      );

      // Buat kartu 2 tanpa media
      await cardRepoA.createCard(
        deckId: deckIdA,
        frontText: 'Terima kasih',
        backText: 'Thank you',
        difficulty: 1,
      );

      // Buat subdeck di Device A
      final subDeckIdA = await deckRepoA.createDeck(
        title: 'Panggilan Akrab',
        parentId: deckIdA,
        sourceLang: 'id',
        targetLang: 'en',
        isPremium: true,
      );

      await cardRepoA.createCard(
        deckId: subDeckIdA,
        frontText: 'Kawan',
        backText: 'Friend',
        difficulty: 1,
      );

      bool shareCallbackCalled = false;
      final exportService = ExportService(
        deckRepository: deckRepoA,
        cardRepository: cardRepoA,
        mediaService: mediaServiceA,
        shareHandler: (file, title) async {
          shareCallbackCalled = true;
          expect(file.existsSync(), isTrue);
          expect(title, 'Bahasa Sehari-hari');
        },
      );

      // Ekspor deck dari Device A
      final exportedFile = await exportService.exportDeck(deck: deckA, share: true);

      expect(exportedFile.existsSync(), isTrue);
      expect(exportedFile.path.endsWith('.flashdeck'), isTrue);
      expect(shareCallbackCalled, isTrue);

      // Verifikasi struktur arsip zip hasil ekspor
      final exportedBytes = await exportedFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(exportedBytes);
      expect(archive.findFile('deck.json'), isNotNull);
      expect(archive.findFile('media/audios/rec_halo.m4a'), isNotNull);
      expect(archive.findFile('media/images/img_halo.png'), isNotNull);

      await dbA.close();

      // --- DEVICE B (Import) ---
      // Alihkan mock path_provider ke folder Device B (simulasi HP lain)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempAppDirB.path,
      );

      final dbB = AppDatabase(NativeDatabase.memory());
      final deckRepoB = DriftDeckRepository(dbB);
      final cardRepoB = DriftCardRepository(dbB);
      final mediaServiceB = MediaService();

      final importService = ImportService(
        database: dbB,
        deckRepository: deckRepoB,
        cardRepository: cardRepoB,
        mediaService: mediaServiceB,
      );

      // Simulasikan Device B sudah memiliki deck lain sehingga ID awal terpakai
      final existingDeckIdB = await deckRepoB.createDeck(title: 'Deck Lama di HP B');
      expect(existingDeckIdB, equals(deckIdA));

      // Impor file .flashdeck ke Device B
      final importedDeck = await importService.importDeckFromFile(exportedFile);

      // 1. Verifikasi deck utama hasil impor
      expect(importedDeck, isNotNull);
      expect(importedDeck.id, isNot(equals(deckIdA))); // Harus ID baru, tidak bentrok
      expect(importedDeck.id, isNot(equals(existingDeckIdB)));
      expect(importedDeck.title, 'Bahasa Sehari-hari');
      expect(importedDeck.sourceLang, 'id');
      expect(importedDeck.targetLang, 'en');
      expect(importedDeck.isPremium, isTrue);

      // 2. Verifikasi kartu deck utama di Device B
      final cardsB = await cardRepoB.getCardsByDeck(importedDeck.id);
      expect(cardsB.length, 2);

      final card1B = cardsB.firstWhere((c) => c.frontText == 'Halo');
      expect(card1B.backText, 'Hello');
      expect(card1B.difficulty, 2);
      expect(card1B.ease, 2.7);
      expect(card1B.intervalDays, 3);
      expect(card1B.frontAudioPath, isNotNull);
      expect(card1B.frontImagePath, isNotNull);

      // Pastikan file media benar-benar diekstrak ke folder Device B dengan konten yang identik
      final extractedAudioPath = await mediaServiceB.resolveAbsolutePath(card1B.frontAudioPath!);
      final extractedImagePath = await mediaServiceB.resolveAbsolutePath(card1B.frontImagePath!);

      expect(File(extractedAudioPath).existsSync(), isTrue);
      expect(await File(extractedAudioPath).readAsString(), 'audio_bytes_halo_device_a');

      expect(File(extractedImagePath).existsSync(), isTrue);
      expect(await File(extractedImagePath).readAsString(), 'image_bytes_halo_device_a');

      final card2B = cardsB.firstWhere((c) => c.frontText == 'Terima kasih');
      expect(card2B.backText, 'Thank you');
      expect(card2B.difficulty, 1);

      // 3. Verifikasi subdeck di Device B
      final subDecksB = await deckRepoB.getSubDecks(importedDeck.id);
      expect(subDecksB.length, 1);
      final subDeckB = subDecksB.first;
      expect(subDeckB.title, 'Panggilan Akrab');
      expect(subDeckB.parentId, importedDeck.id);

      final subCardsB = await cardRepoB.getCardsByDeck(subDeckB.id);
      expect(subCardsB.length, 1);
      expect(subCardsB.first.frontText, 'Kawan');
      expect(subCardsB.first.backText, 'Friend');

      await dbB.close();
    });

    test('File rusak (corrupt bytes) menghasilkan pesan error jelas dan tidak membuat data', () async {
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

      final corruptedBytes = [0, 1, 2, 3, 4, 5, 99, 100]; // Bukan zip valid

      expect(
        () => importService.importDeckFromBytes(corruptedBytes),
        throwsA(isA<ImportException>().having(
          (e) => e.message,
          'message',
          contains('File rusak atau bukan format .flashdeck yang valid'),
        )),
      );

      // Pastikan tidak ada data yang masuk ke database
      final allDecks = await deckRepo.getAllDecks();
      expect(allDecks.isEmpty, isTrue);

      await db.close();
    });

    test('Versi file tidak didukung menghasilkan pesan error jelas dan transaksi di-rollback', () async {
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

      // Buat zip dengan versi 999
      final archive = Archive();
      final invalidManifest = {
        'version': 999,
        'metadata': {'title': 'Deck Masa Depan', 'source_lang': 'id'},
        'cards': [],
      };
      final jsonBytes = utf8.encode(jsonEncode(invalidManifest));
      archive.addFile(ArchiveFile('deck.json', jsonBytes.length, jsonBytes));
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => importService.importDeckFromBytes(zipBytes),
        throwsA(isA<ImportException>().having(
          (e) => e.message,
          'message',
          contains('Versi file tidak didukung: 999'),
        )),
      );

      // Pastikan database tetap bersih tanpa data setengah jadi
      final allDecks = await deckRepo.getAllDecks();
      expect(allDecks.isEmpty, isTrue);

      await db.close();
    });

    test('File zip tanpa deck.json menghasilkan pesan error struktur tidak valid', () async {
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

      // Buat zip tanpa deck.json
      final archive = Archive();
      archive.addFile(ArchiveFile('dummy.txt', 5, utf8.encode('dummy')));
      final zipBytes = ZipEncoder().encode(archive);

      expect(
        () => importService.importDeckFromBytes(zipBytes),
        throwsA(isA<ImportException>().having(
          (e) => e.message,
          'message',
          contains('berkas deck.json tidak ditemukan'),
        )),
      );

      final allDecks = await deckRepo.getAllDecks();
      expect(allDecks.isEmpty, isTrue);

      await db.close();
    });
  });
}
