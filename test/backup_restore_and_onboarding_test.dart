import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:english_flashcard_go/app/controllers/theme_controller.dart';
import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/study_log_repository.dart';
import 'package:english_flashcard_go/app/data/services/export_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';
import 'package:english_flashcard_go/app/data/services/sample_deck_service.dart';
import 'package:english_flashcard_go/app/data/services/theme_service.dart';
import 'package:english_flashcard_go/app/modules/onboarding/controllers/onboarding_controller.dart';
import 'package:english_flashcard_go/app/modules/onboarding/views/onboarding_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirA;
  late Directory tempDirB;

  setUp(() async {
    Get.reset();
    tempDirA = await Directory.systemTemp.createTemp('backup_device_a_');
    tempDirB = await Directory.systemTemp.createTemp('backup_device_b_');
  });

  tearDown(() async {
    Get.reset();
    try {
      if (tempDirA.existsSync()) {
        tempDirA.deleteSync(recursive: true);
      }
    } catch (_) {}
    try {
      if (tempDirB.existsSync()) {
        tempDirB.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('Theme & Onboarding State Tests', () {
    test('ThemePreferencesModel and ThemeController manage onboarding state', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempDirA.path,
      );

      final themeService = ThemeService();
      final themeController = ThemeController(themeService: themeService);

      expect(themeController.hasCompletedOnboarding.value, isFalse);

      await themeController.completeOnboarding();
      expect(themeController.hasCompletedOnboarding.value, isTrue);

      // Verify persistence by loading in a new instance
      final loadedPreferences = await themeService.readPreferences();
      expect(loadedPreferences?.hasCompletedOnboarding, isTrue);

      final newController = ThemeController(themeService: themeService);
      await newController.loadThemeSettings();
      expect(newController.hasCompletedOnboarding.value, isTrue);

      // Verify reset
      await newController.resetOnboarding();
      expect(newController.hasCompletedOnboarding.value, isFalse);
    });
  });

  group('SampleDeckService Tests', () {
    test('seedSampleDeckIfNotExists membuat deck contoh bawaan yang dapat dihapus', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);
      final sampleService = SampleDeckService(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
      );

      // 1. Initial state: database empty
      final initialDecks = await deckRepo.getAllDecks();
      expect(initialDecks.isEmpty, isTrue);

      // 2. Seed sample deck
      final seeded = await sampleService.seedSampleDeckIfNotExists();
      expect(seeded, isTrue);

      final decksAfter = await deckRepo.getAllDecks();
      expect(decksAfter.length, 1);
      final sampleDeck = decksAfter.first;
      expect(sampleDeck.title, 'Kosakata Dasar (Contoh)');

      // Verify sample cards
      final cards = await cardRepo.getCardsByDeck(sampleDeck.id);
      expect(cards.length, 6);
      expect(cards.any((c) => c.frontText == 'Apple' && c.backText == 'Apel'), isTrue);
      expect(cards.any((c) => c.frontText == 'Knowledge'), isTrue);

      // 3. Second call should not duplicate
      final seededAgain = await sampleService.seedSampleDeckIfNotExists();
      expect(seededAgain, isFalse);
      expect((await deckRepo.getAllDecks()).length, 1);

      // 4. Sample deck can be soft-deleted to trash and permanently deleted
      await deckRepo.softDeleteDeck(sampleDeck.id);
      expect((await deckRepo.getAllDecks()).isEmpty, isTrue);

      final trashDecks = await deckRepo.getTrashDecks();
      expect(trashDecks.length, 1);
      expect(trashDecks.first.id, sampleDeck.id);

      // Permanently delete
      await deckRepo.hardDeleteDeck(sampleDeck.id);
      expect((await deckRepo.getTrashDecks()).isEmpty, isTrue);

      await db.close();
    });
  });

  group('Full Zip Backup and Restore Tests', () {
    test('Round-trip backupAllDataZip lalu restoreAllDataFromFile dengan media dan riwayat belajar', () async {
      // --- DEVICE A (Create data & Backup to zip) ---
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempDirA.path,
      );

      final dbA = AppDatabase(NativeDatabase.memory());
      final deckRepoA = DriftDeckRepository(dbA);
      final cardRepoA = DriftCardRepository(dbA);
      final studyRepoA = DriftStudyLogRepository(dbA);
      final mediaServiceA = MediaService();

      // Buat file media nyata di Device A
      final audioFileA = File(p.join(tempDirA.path, 'media', 'audios', 'rec_backup_test.m4a'));
      audioFileA.parent.createSync(recursive: true);
      await audioFileA.writeAsString('audio_backup_bytes_123');

      final imageFileA = File(p.join(tempDirA.path, 'media', 'images', 'img_backup_test.png'));
      imageFileA.parent.createSync(recursive: true);
      await imageFileA.writeAsString('image_backup_bytes_456');

      // Buat root deck di Device A
      final deckIdA = await deckRepoA.createDeck(
        title: 'Kosakata Bisnis',
        sourceLang: 'id',
        targetLang: 'en',
        isPremium: false,
      );

      // Buat kartu dengan media di Device A
      final cardIdA = await cardRepoA.createCard(
        deckId: deckIdA,
        frontText: 'Negotiation',
        backText: 'Negosiasi',
        frontAudioPath: 'media/audios/rec_backup_test.m4a',
        frontImagePath: 'media/images/img_backup_test.png',
        difficulty: 3,
        ease: 2.1,
        intervalDays: 4,
      );

      // Buat subdeck di Device A
      final subDeckIdA = await deckRepoA.createDeck(
        title: 'Kontrak Kerja',
        parentId: deckIdA,
        sourceLang: 'id',
        targetLang: 'en',
      );

      await cardRepoA.createCard(
        deckId: subDeckIdA,
        frontText: 'Agreement',
        backText: 'Perjanjian',
        difficulty: 1,
      );

      // Buat log aktivitas belajar di Device A
      await studyRepoA.recordLog(
        cardId: cardIdA,
        deckId: deckIdA,
        rating: 2,
        isQuiz: false,
        isCorrect: true,
      );

      final exportServiceA = ExportService(
        database: dbA,
        deckRepository: deckRepoA,
        cardRepository: cardRepoA,
        mediaService: mediaServiceA,
      );

      final backupZipFile = await exportServiceA.backupAllDataZip(share: false);
      expect(backupZipFile.existsSync(), isTrue);
      expect(backupZipFile.path.endsWith('.zip'), isTrue);

      // Verifikasi struktur arsip zip
      final zipBytes = await backupZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      expect(archive.findFile('backup.json'), isNotNull);
      expect(archive.findFile('media/audios/rec_backup_test.m4a'), isNotNull);
      expect(archive.findFile('media/images/img_backup_test.png'), isNotNull);

      await dbA.close();

      // --- DEVICE B (Restore from zip) ---
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempDirB.path,
      );

      final dbB = AppDatabase(NativeDatabase.memory());
      final deckRepoB = DriftDeckRepository(dbB);
      final cardRepoB = DriftCardRepository(dbB);

      final importServiceB = ImportService(
        database: dbB,
        deckRepository: deckRepoB,
        cardRepository: cardRepoB,
      );

      // Restore data di Device B
      final restoredCount = await importServiceB.restoreAllDataFromFile(
        backupZipFile,
        replaceExisting: true,
      );
      expect(restoredCount, 2); // 1 root deck + 1 subdeck

      // Verifikasi deck di Device B
      final rootDecksB = await deckRepoB.getRootDecks();
      expect(rootDecksB.length, 1);
      final restoredRootDeck = rootDecksB.first;
      expect(restoredRootDeck.title, 'Kosakata Bisnis');

      // Verifikasi subdeck di Device B
      final subDecksB = await deckRepoB.getSubDecks(restoredRootDeck.id);
      expect(subDecksB.length, 1);
      final restoredSubDeck = subDecksB.first;
      expect(restoredSubDeck.title, 'Kontrak Kerja');

      // Verifikasi kartu deck utama di Device B
      final cardsRootB = await cardRepoB.getCardsByDeck(restoredRootDeck.id);
      expect(cardsRootB.length, 1);
      final restoredCard = cardsRootB.first;
      expect(restoredCard.frontText, 'Negotiation');
      expect(restoredCard.backText, 'Negosiasi');
      expect(restoredCard.difficulty, 3);
      expect(restoredCard.ease, 2.1);
      expect(restoredCard.intervalDays, 4);

      // Verifikasi media file fisik telah diekstrak ke direktori Device B
      final restoredAudioFile = File(p.join(tempDirB.path, restoredCard.frontAudioPath!));
      expect(restoredAudioFile.existsSync(), isTrue);
      expect(await restoredAudioFile.readAsString(), 'audio_backup_bytes_123');

      final restoredImageFile = File(p.join(tempDirB.path, restoredCard.frontImagePath!));
      expect(restoredImageFile.existsSync(), isTrue);
      expect(await restoredImageFile.readAsString(), 'image_backup_bytes_456');

      // Verifikasi kartu subdeck di Device B
      final cardsSubB = await cardRepoB.getCardsByDeck(restoredSubDeck.id);
      expect(cardsSubB.length, 1);
      expect(cardsSubB.first.frontText, 'Agreement');

      // Verifikasi study logs dipulihkan
      final allLogsB = await dbB.select(dbB.studyLogs).get();
      expect(allLogsB.length, 1);
      expect(allLogsB.first.cardId, restoredCard.id);
      expect(allLogsB.first.deckId, restoredRootDeck.id);

      await dbB.close();
    });

    test('Restore dengan replaceExisting: false menggabungkan deck tanpa bentrok ID', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => tempDirA.path,
      );

      final db = AppDatabase(NativeDatabase.memory());
      final deckRepo = DriftDeckRepository(db);
      final cardRepo = DriftCardRepository(db);

      // Buat deck awal di DB
      await deckRepo.createDeck(
        title: 'Deck Eksisting',
        sourceLang: 'id',
        targetLang: 'en',
      );

      final exportService = ExportService(
        database: db,
        deckRepository: deckRepo,
        cardRepository: cardRepo,
      );

      final backupFile = await exportService.backupAllDataZip(share: false);

      final importService = ImportService(
        database: db,
        deckRepository: deckRepo,
        cardRepository: cardRepo,
      );

      // Restore dengan replaceExisting: false (merge)
      final restoredCount = await importService.restoreAllDataFromFile(
        backupFile,
        replaceExisting: false,
      );

      expect(restoredCount, 1);
      final allDecks = await deckRepo.getAllDecks();
      expect(allDecks.length, 2); // 1 existing + 1 merged from backup

      await db.close();
    });

    test('Restore file rusak melempar ImportException dengan pesan jelas', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final importService = ImportService(database: db);

      // Berkas acak bukan zip
      final corruptedFile = File(p.join(tempDirA.path, 'corrupt.zip'));
      await corruptedFile.writeAsString('Bukan file zip');

      expect(
        () => importService.restoreAllDataFromFile(corruptedFile),
        throwsA(isA<ImportException>()),
      );

      await db.close();
    });
  });

  group('Onboarding Flow Widget Tests', () {
    testWidgets('OnboardingView menampilkan 3 layar, navigasi lanjut, dan tombol mulai belajar', (tester) async {
      final themeService = ThemeService();
      final themeController = Get.put(ThemeController(themeService: themeService));
      final onboardingController = Get.put(OnboardingController());

      expect(onboardingController.pages.length, 3);
      expect(onboardingController.currentPage.value, 0);

      await tester.pumpWidget(
        GetMaterialApp(
          home: const OnboardingView(),
        ),
      );
      await tester.pumpAndSettle();

      // Layar 1
      expect(find.text('Belajar Flashcard Interaktif'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      // Pindah ke Layar 2 via controller
      onboardingController.nextPage();
      await tester.pumpAndSettle();
      expect(onboardingController.currentPage.value, 1);
      expect(find.text('Metode Spaced Repetition (SM-2)'), findsOneWidget);

      // Pindah ke Layar 3
      onboardingController.nextPage();
      await tester.pumpAndSettle();
      expect(onboardingController.currentPage.value, 2);
      expect(find.text('Kuis Pilihan Ganda & 100% Offline'), findsOneWidget);
      expect(find.text('Mulai Belajar'), findsOneWidget);

      // Tap Mulai Belajar
      await tester.tap(find.text('Mulai Belajar'));
      await tester.pumpAndSettle();

      expect(themeController.hasCompletedOnboarding.value, isTrue);
    });
  });
}
