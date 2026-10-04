import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/export_service.dart';
import 'package:english_flashcard_go/app/data/services/file_intent_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late MediaService mediaService;
  late ExportService exportService;
  late ImportService importService;
  late FileIntentService fileIntentService;
  late Directory tempDir;

  setUp(() async {
    Get.reset();
    tempDir = await Directory.systemTemp.createTemp('file_intent_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => tempDir.path,
    );

    db = AppDatabase(NativeDatabase.memory());
    deckRepo = DriftDeckRepository(db);
    cardRepo = DriftCardRepository(db);
    mediaService = MediaService();
    exportService = ExportService(
      deckRepository: deckRepo,
      cardRepository: cardRepo,
      mediaService: mediaService,
    );
    importService = ImportService(
      database: db,
      deckRepository: deckRepo,
      cardRepository: cardRepo,
      mediaService: mediaService,
    );
    fileIntentService = FileIntentService(importService: importService);

    Get.put<AppDatabase>(db);
    Get.put<DeckRepository>(deckRepo);
    Get.put<CardRepository>(cardRepo);
    Get.put<ImportService>(importService);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FileIntentService Tests', () {
    test('Inisialisasi FileIntentService dan pendaftaran channel berjalan tanpa exception', () async {
      await fileIntentService.init();
      expect(fileIntentService.isImportingFromIntent.value, false);
    });

    test('executeImport berhasil mengimpor file paket .flashdeck dan menghapus file sementara', () async {
      // 1. Buat deck asli lalu ekspor
      final deckId = await deckRepo.createDeck(title: 'Deck Dari WhatsApp');
      await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Airport',
        backText: 'Bandara',
      );

      final deck = await deckRepo.getDeckById(deckId);
      final exportedFile = await exportService.exportDeck(deck: deck!, share: false);
      expect(exportedFile.existsSync(), true);

      // Simulasikan file diterima di folder cache Android
      final incomingFile = File('${tempDir.path}/whatsapp_shared.flashdeck');
      await exportedFile.copy(incomingFile.path);
      expect(incomingFile.existsSync(), true);

      // 2. Jalankan eksekusi impor lewat FileIntentService
      await fileIntentService.executeImport(incomingFile);

      // 3. Verifikasi deck berhasil masuk ke DB
      final allDecks = await deckRepo.getAllDecks();
      expect(
        allDecks.any((d) => d.title == 'Deck Dari WhatsApp'),
        isTrue,
      );

      // 4. Verifikasi file sementara di-cleanup
      expect(incomingFile.existsSync(), false);
    });

    test('Merespons getInitialFile saat diluncurkan via Intent', () async {
      final sampleFile = File('${tempDir.path}/initial.flashdeck');
      await sampleFile.writeAsString('corrupted data');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.flashcard.english/file_intent'),
        (MethodCall call) async {
          if (call.method == 'getInitialFile') {
            return sampleFile.path;
          }
          return null;
        },
      );

      // checkInitialFile membaca path dari channel tanpa unhandled crash
      await fileIntentService.checkInitialFile();
    });
  });
}
