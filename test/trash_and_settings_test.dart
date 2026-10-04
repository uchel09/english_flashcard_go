import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:english_flashcard_go/app/controllers/theme_controller.dart';
import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/export_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';
import 'package:english_flashcard_go/app/data/services/theme_service.dart';
import 'package:english_flashcard_go/app/modules/trash/controllers/trash_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempAppDir;

  setUp(() async {
    Get.reset();
    tempAppDir = await Directory.systemTemp.createTemp('trash_settings_test_');
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

  group('Tempat Sampah (Trash) - Restore & Permanent Delete Tests', () {
    test('Deck terhapus bisa dipulihkan utuh, termasuk media dan kartu', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final mediaService = MediaService();

      // 1. Buat deck, subdeck, dan kartu ber-media
      final rootDeckId = await deckRepo.createDeck(
        title: 'Deck Utama Liburan',
        isPremium: true,
      );
      final subDeckId = await deckRepo.createDeck(
        title: 'Subdeck Bandara',
        parentId: rootDeckId,
      );

      // Buat file media fisik
      final audioPath = 'media/audios/rec_liburan.m4a';
      final imagePath = 'media/images/img_liburan.jpg';
      final audioFile = File(p.join(tempAppDir.path, audioPath));
      audioFile.parent.createSync(recursive: true);
      await audioFile.writeAsString('fake_audio_bytes');

      final imageFile = File(p.join(tempAppDir.path, imagePath));
      imageFile.parent.createSync(recursive: true);
      await imageFile.writeAsString('fake_image_bytes');

      final cardId = await cardRepo.createCard(
        deckId: rootDeckId,
        frontText: 'Tiket Pesawat',
        backText: 'Flight Ticket',
        frontAudioPath: audioPath,
        frontImagePath: imagePath,
      );

      await cardRepo.createCard(
        deckId: subDeckId,
        frontText: 'Paspor',
        backText: 'Passport',
      );

      // 2. Soft-delete deck utama
      await deckRepo.softDeleteDeck(rootDeckId);

      // Cek di TrashController
      final trashController = TrashController(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      await trashController.loadTrash();

      expect(trashController.trashDecks.any((d) => d.id == rootDeckId), isTrue);
      // Media fisik harus tetap ada saat di tempat sampah!
      expect(audioFile.existsSync(), isTrue);
      expect(imageFile.existsSync(), isTrue);

      // 3. Pulihkan deck
      final deckToRestore =
          trashController.trashDecks.firstWhere((d) => d.id == rootDeckId);
      await trashController.restoreDeck(deckToRestore);

      // Verifikasi deck aktif kembali
      final activeDecks = await deckRepo.getAllDecks();
      expect(activeDecks.any((d) => d.id == rootDeckId), isTrue);
      expect(activeDecks.any((d) => d.id == subDeckId), isTrue);

      // Verifikasi kartu masih utuh dan terhubung ke file media
      final restoredCards = await cardRepo.getCardsByDeck(rootDeckId);
      expect(restoredCards.length, 1);
      final restoredCard = restoredCards.first;
      expect(restoredCard.id, cardId);
      expect(restoredCard.frontText, 'Tiket Pesawat');
      expect(restoredCard.frontAudioPath, audioPath);
      expect(restoredCard.frontImagePath, imagePath);

      // Media fisik tetap ada dan utuh di penyimpanan
      expect(audioFile.existsSync(), isTrue);
      expect(imageFile.existsSync(), isTrue);
      expect(await audioFile.readAsString(), 'fake_audio_bytes');
      expect(await imageFile.readAsString(), 'fake_image_bytes');

      await db.close();
    });

    test('Hapus permanen kartu menghapus media yang tidak dipakai lagi dan mempertahankan media yang dipakai bersama', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final mediaService = MediaService();

      final deckId = await deckRepo.createDeck(title: 'Deck Uji Media');

      final sharedAudioPath = 'media/audios/shared_audio.m4a';
      final uniqueAudioPath = 'media/audios/unique_audio.m4a';

      final sharedFile = File(p.join(tempAppDir.path, sharedAudioPath));
      sharedFile.parent.createSync(recursive: true);
      await sharedFile.writeAsString('shared_bytes');

      final uniqueFile = File(p.join(tempAppDir.path, uniqueAudioPath));
      uniqueFile.parent.createSync(recursive: true);
      await uniqueFile.writeAsString('unique_bytes');

      // Kartu 1 menggunakan sharedAudio dan uniqueAudio
      final card1Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Kartu 1',
        backText: 'Card 1',
        frontAudioPath: sharedAudioPath,
        backAudioPath: uniqueAudioPath,
      );

      // Kartu 2 juga menggunakan sharedAudio
      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Kartu 2',
        backText: 'Card 2',
        frontAudioPath: sharedAudioPath,
      );

      // Soft delete Kartu 1
      await cardRepo.softDeleteCard(card1Id);

      final trashController = TrashController(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      await trashController.loadTrash();
      expect(trashController.trashCards.length, 1);

      // Hapus permanen Kartu 1
      final card1 = trashController.trashCards.first;
      await trashController.hardDeleteCard(card1);

      // Verifikasi:
      // 1. uniqueAudioPath harus TERHAPUS karena tidak dipakai lagi
      expect(uniqueFile.existsSync(), isFalse);
      // 2. sharedAudioPath harus TETAP ADA karena masih dipakai oleh Kartu 2
      expect(sharedFile.existsSync(), isTrue);
      expect(await sharedFile.readAsString(), 'shared_bytes');

      await db.close();
    });

    test('Hapus permanen deck menghapus subdeck, kartu, dan media fisiknya', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final mediaService = MediaService();

      final parentId = await deckRepo.createDeck(title: 'Deck Dihapus', isPremium: true);
      final subId = await deckRepo.createDeck(title: 'Subdeck Dihapus', parentId: parentId);

      final audioPath = 'media/audios/rec_deck_hapus.m4a';
      final audioFile = File(p.join(tempAppDir.path, audioPath));
      audioFile.parent.createSync(recursive: true);
      await audioFile.writeAsString('deck_audio_to_delete');

      await cardRepo.createCard(
        deckId: subId,
        frontText: 'Subcard',
        backText: 'Subcard',
        frontAudioPath: audioPath,
      );

      await deckRepo.softDeleteDeck(parentId);

      final trashController = TrashController(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      await trashController.loadTrash();

      final parentDeck = trashController.trashDecks.firstWhere((d) => d.id == parentId);
      await trashController.hardDeleteDeck(parentDeck);

      // Verifikasi deck, subdeck, kartu hilang dari database
      expect(await deckRepo.getDeckById(parentId), isNull);
      expect(await deckRepo.getDeckById(subId), isNull);
      final remainingCards = await cardRepo.getCardsByDeck(subId, includeDeleted: true);
      expect(remainingCards.isEmpty, isTrue);

      // Verifikasi media fisik terhapus dari disk
      expect(audioFile.existsSync(), isFalse);

      await db.close();
    });

    test('Kosongkan tempat sampah menghapus semua item dan membersihkan media', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final mediaService = MediaService();

      final deckId = await deckRepo.createDeck(title: 'Deck Sampah');
      final audioPath = 'media/audios/sampah.m4a';
      final audioFile = File(p.join(tempAppDir.path, audioPath));
      audioFile.parent.createSync(recursive: true);
      await audioFile.writeAsString('sampah_bytes');

      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Kata Sampah',
        backText: 'Trash Word',
        frontAudioPath: audioPath,
      );

      // Soft delete deck
      await deckRepo.softDeleteDeck(deckId);

      // Buat deck aktif lain dengan kartu yang dihapus
      final activeDeckId = await deckRepo.createDeck(title: 'Deck Aktif');
      final orphanCardId = await cardRepo.createCard(
        deckId: activeDeckId,
        frontText: 'Kartu Dihapus',
        backText: 'Deleted Card',
      );
      await cardRepo.softDeleteCard(orphanCardId);

      final trashController = TrashController(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      await trashController.loadTrash();
      expect(trashController.trashDecks.length, 1);
      expect(trashController.trashCards.length, 1);

      // Kosongkan tempat sampah
      await trashController.emptyTrash();

      // Verifikasi tempat sampah kosong total
      expect(trashController.trashDecks.isEmpty, isTrue);
      expect(trashController.trashCards.isEmpty, isTrue);
      expect(audioFile.existsSync(), isFalse);

      await db.close();
    });
  });

  group('Tema & Pengaturan Tests', () {
    test('ThemeController menyimpan dan memulihkan pengaturan tema dan preferensi', () async {
      final themeService = ThemeService();
      final controller1 = ThemeController(themeService: themeService);

      await controller1.setThemeMode(ThemeMode.dark);
      await controller1.setAccentColor(Colors.teal);
      await controller1.setCardStyle('outlined');
      await controller1.setDeckStyle('compact');
      await controller1.setDefaultSourceLang('es');

      // Buat controller2 baru dan baca preferensi dari file
      final controller2 = ThemeController(themeService: themeService);
      await controller2.loadThemeSettings();

      expect(controller2.themeMode, ThemeMode.dark);
      expect(controller2.isDarkMode.value, isTrue);
      expect(controller2.accentColor.value.toARGB32(), Colors.teal.toARGB32());
      expect(controller2.cardStyle.value, 'outlined');
      expect(controller2.deckStyle.value, 'compact');
      expect(controller2.defaultSourceLang.value, 'es');
    });

    test('Export semua deck dan import multi-deck round-trip', () async {
      final dbA = AppDatabase(NativeDatabase.memory());
      final deckRepoA = DriftDeckRepository(dbA);
      final cardRepoA = DriftCardRepository(dbA);
      final mediaServiceA = MediaService();

      // Deck 1
      final d1 = await deckRepoA.createDeck(title: 'Deck 1');
      await cardRepoA.createCard(deckId: d1, frontText: 'Satu', backText: 'One');

      // Deck 2 (Premium dengan Subdeck)
      final d2 = await deckRepoA.createDeck(title: 'Deck 2', isPremium: true);
      final sub2 = await deckRepoA.createDeck(title: 'Subdeck 2A', parentId: d2);
      await cardRepoA.createCard(deckId: sub2, frontText: 'Dua', backText: 'Two');

      final exportService = ExportService(
        deckRepository: deckRepoA,
        cardRepository: cardRepoA,
        mediaService: mediaServiceA,
      );

      final exportFile = await exportService.exportAllDecks(share: false);
      expect(exportFile.existsSync(), isTrue);

      // --- Device B (Import) ---
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

      await importService.importDeckFromFile(exportFile);

      // Verifikasi di Device B
      final rootDecksB = await deckRepoB.getRootDecks();
      expect(rootDecksB.length, 2);

      final importedD1 = rootDecksB.firstWhere((d) => d.title == 'Deck 1');
      final d1Cards = await cardRepoB.getCardsByDeck(importedD1.id);
      expect(d1Cards.length, 1);
      expect(d1Cards.first.frontText, 'Satu');

      final importedD2 = rootDecksB.firstWhere((d) => d.title == 'Deck 2');
      final subDecksB = await deckRepoB.getSubDecks(importedD2.id);
      expect(subDecksB.length, 1);
      expect(subDecksB.first.title, 'Subdeck 2A');

      final subCardsB = await cardRepoB.getCardsByDeck(subDecksB.first.id);
      expect(subCardsB.length, 1);
      expect(subCardsB.first.frontText, 'Dua');

      await dbA.close();
      await dbB.close();
    });
  });
}
