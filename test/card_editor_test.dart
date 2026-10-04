import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:flutter/services.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';
import 'package:english_flashcard_go/app/modules/card_editor/controllers/card_editor_controller.dart';

class MockAudioService extends AudioService {
  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CardEditor & MediaService tests', () {
    late AppDatabase db;
    late DeckRepository deckRepo;
    late CardRepository cardRepo;
    late MediaService mediaService;
    late Deck testDeck;
    late Directory mockAppDir;

    setUp(() async {
      Get.reset();
      mockAppDir = await Directory.systemTemp.createTemp('card_editor_app_dir_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => mockAppDir.path,
      );

      db = AppDatabase(NativeDatabase.memory());
      deckRepo = DriftDeckRepository(db);
      cardRepo = DriftCardRepository(db);
      mediaService = MediaService();

      Get.put<AppDatabase>(db, permanent: true);
      Get.put<DeckRepository>(deckRepo, permanent: true);
      Get.put<CardRepository>(cardRepo, permanent: true);
      Get.put<MediaService>(mediaService, permanent: true);
      Get.put<AudioService>(MockAudioService(), permanent: true);

      final deckId = await deckRepo.createDeck(
        title: 'Deck Media Test',
        sourceLang: 'id',
        targetLang: 'en',
      );
      testDeck = (await deckRepo.getDeckById(deckId))!;
    });

    tearDown(() async {
      await db.close();
    });

    test('MediaService copies files and returns relative path', () async {
      final tempDir = await Directory.systemTemp.createTemp('media_test_');
      final sourceFile = File('${tempDir.path}/sample_sound.m4a');
      await sourceFile.writeAsString('audio content');

      try {
        final relativePath = await mediaService.copyFileToAppStorage(
          sourceFile,
          'audios',
          'test_front',
        );

        // Verify relative path format
        expect(relativePath.startsWith('media/audios/test_front_'), isTrue);
        expect(relativePath.endsWith('.m4a'), isTrue);

        // Verify resolveAbsolutePath returns existing file
        final absolutePath = await mediaService.resolveAbsolutePath(relativePath);
        expect(File(absolutePath).existsSync(), isTrue);
        expect(await File(absolutePath).readAsString(), 'audio content');

        // Clean up
        await mediaService.deleteMediaFile(relativePath);
        expect(File(absolutePath).existsSync(), isFalse);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('Validation: at least one side must be filled', () {
      final controller = CardEditorController(
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      controller.deck.value = testDeck;

      // Initially empty
      expect(controller.validateAtLeastOneSideFilled(), isFalse);

      // Filled only on front
      controller.frontTextController.text = 'Halo';
      expect(controller.validateAtLeastOneSideFilled(), isTrue);

      // Clear front, filled only on back
      controller.frontTextController.clear();
      expect(controller.validateAtLeastOneSideFilled(), isFalse);

      controller.backTextController.text = 'Hello';
      expect(controller.validateAtLeastOneSideFilled(), isTrue);

      // Image or audio only is also valid
      controller.backTextController.clear();
      controller.frontImagePath.value = 'media/images/front.jpg';
      expect(controller.validateAtLeastOneSideFilled(), isTrue);
    });

    test('Duplicate front text detection in the same deck', () async {
      await cardRepo.createCard(
        deckId: testDeck.id,
        frontText: 'Selamat Datang',
        backText: 'Welcome',
      );

      final controller = CardEditorController(
        cardRepository: cardRepo,
        mediaService: mediaService,
      );
      controller.deck.value = testDeck;

      // Duplicate check (case-insensitive)
      controller.frontTextController.text = 'selamat datang';
      expect(await controller.checkForDuplicateFrontText(), isTrue);

      // Unique text
      controller.frontTextController.text = 'Selamat Tinggal';
      expect(await controller.checkForDuplicateFrontText(), isFalse);
    });

    test('All media combinations persist and are retrieved after simulated app restart',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('persist_test_');
      final dbFile = File('${tempDir.path}/media_cards.sqlite');

      try {
        // Session 1: Create card with full media combinations
        final firstDb = AppDatabase(NativeDatabase(dbFile));
        final firstDeckRepo = DriftDeckRepository(firstDb);
        final firstCardRepo = DriftCardRepository(firstDb);

        final deckId = await firstDeckRepo.createDeck(
          title: 'Deck Lengkap',
          sourceLang: 'id',
        );

        final cardId = await firstCardRepo.createCard(
          deckId: deckId,
          frontText: 'Kucing',
          backText: 'Cat',
          frontAudioPath: 'media/audios/rec_front_1.m4a',
          backAudioPath: 'media/audios/rec_back_1.m4a',
          frontImagePath: 'media/images/img_front_1.jpg',
          backImagePath: 'media/images/img_back_1.jpg',
        );

        await firstDb.close();

        // Session 2: Reopen DB (simulating app restart)
        final reopenedDb = AppDatabase(NativeDatabase(dbFile));
        final reopenedCardRepo = DriftCardRepository(reopenedDb);

        final card = await reopenedCardRepo.getCardById(cardId);
        expect(card, isNotNull);
        expect(card!.frontText, 'Kucing');
        expect(card.backText, 'Cat');
        expect(card.frontAudioPath, 'media/audios/rec_front_1.m4a');
        expect(card.backAudioPath, 'media/audios/rec_back_1.m4a');
        expect(card.frontImagePath, 'media/images/img_front_1.jpg');
        expect(card.backImagePath, 'media/images/img_back_1.jpg');

        await reopenedDb.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
