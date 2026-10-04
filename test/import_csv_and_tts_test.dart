import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/controllers/theme_controller.dart';
import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late ImportService importService;

  setUp(() {
    Get.reset();
    db = AppDatabase(NativeDatabase.memory());
    deckRepo = DriftDeckRepository(db);
    cardRepo = DriftCardRepository(db);
    importService = ImportService(database: db);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  group('CSV Import Parser Tests', () {
    test('Mem-parsing CSV sederhana dengan pemisah koma', () {
      const csv = '''
Apple,Apel
Banana,Pisang
Cat,Kucing
''';

      final cards = importService.parseCsvText(csv);
      expect(cards.length, 3);
      expect(cards[0].frontText, 'Apple');
      expect(cards[0].backText, 'Apel');
      expect(cards[0].isValid, true);
      expect(cards[1].frontText, 'Banana');
      expect(cards[1].backText, 'Pisang');
      expect(cards[2].frontText, 'Cat');
      expect(cards[2].backText, 'Kucing');
    });

    test('Mem-parsing CSV dengan pemisah titik koma', () {
      const csv = '''
Run;Berlari
Walk;Berjalan
Eat;Makan
''';

      final cards = importService.parseCsvText(csv);
      expect(cards.length, 3);
      expect(cards[0].frontText, 'Run');
      expect(cards[0].backText, 'Berlari');
      expect(cards[1].frontText, 'Walk');
      expect(cards[1].backText, 'Berjalan');
      expect(cards[2].frontText, 'Eat');
      expect(cards[2].backText, 'Makan');
    });

    test('Mengabaikan baris header seperti depan,belakang atau front,back', () {
      const csv = '''
depan,belakang
House,Rumah
Car,Mobil
''';

      final cards = importService.parseCsvText(csv);
      expect(cards.length, 2);
      expect(cards[0].frontText, 'House');
      expect(cards[0].backText, 'Rumah');
      expect(cards[1].frontText, 'Car');
      expect(cards[1].backText, 'Mobil');
    });

    test(
      'Menangani nilai di dalam tanda kutip dan tanda kutip ganda RFC 4180',
      () {
        const csv = '''
"Hello, world!","Halo, dunia!"
"She said, ""Goodbye""","Dia berkata, ""Selamat tinggal"""
''';

        final cards = importService.parseCsvText(csv);
        expect(cards.length, 2);
        expect(cards[0].frontText, 'Hello, world!');
        expect(cards[0].backText, 'Halo, dunia!');
        expect(cards[1].frontText, 'She said, "Goodbye"');
        expect(cards[1].backText, 'Dia berkata, "Selamat tinggal"');
      },
    );

    test(
      'Menandai baris CSV tidak valid jika kolom tidak lengkap atau kosong',
      () {
        const csv = '''
Book,Buku
SingleWordOnly
,
''';

        final cards = importService.parseCsvText(csv);
        expect(cards.length, 2);
        expect(cards[0].isValid, true);
        expect(cards[0].frontText, 'Book');
        expect(cards[1].isValid, false); // SingleWordOnly -> hanya 1 kolom
      },
    );
  });

  group('Teks Tempel (Paste Text) Parser Tests', () {
    test('Mem-parsing teks tempel satu baris = depan;belakang', () {
      const rawText = '''
Fire;Api
Water;Air
Wind;Angin
''';

      final cards = importService.parsePastedText(rawText);
      expect(cards.length, 3);
      expect(cards[0].frontText, 'Fire');
      expect(cards[0].backText, 'Api');
      expect(cards[0].isValid, true);
      expect(cards[1].frontText, 'Water');
      expect(cards[1].backText, 'Air');
      expect(cards[2].frontText, 'Wind');
      expect(cards[2].backText, 'Angin');
    });

    test('Menangani baris kosong dan baris tanpa pemisah titik koma', () {
      const rawText = '''
Earth;Tanah

BarisTanpaPemisah
Space;Luar angkasa
''';

      final cards = importService.parsePastedText(rawText);
      expect(cards.length, 3);
      expect(cards[0].frontText, 'Earth');
      expect(cards[0].isValid, true);

      expect(cards[1].frontText, 'BarisTanpaPemisah');
      expect(cards[1].isValid, false);
      expect(cards[1].errorReason, contains('depan;belakang'));

      expect(cards[2].frontText, 'Space');
      expect(cards[2].isValid, true);
    });
  });

  group('Penyimpanan Hasil Impor ke Deck Tests', () {
    test('saveCardsToDeck menyimpan kartu valid ke basis data', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Impor Koleksi');

      final importedCards = [
        ParsedImportCard(frontText: 'Sun', backText: 'Matahari', isValid: true),
        ParsedImportCard(frontText: 'Moon', backText: 'Bulan', isValid: true),
        ParsedImportCard(
          frontText: 'Star',
          backText: '',
          isValid: false,
          errorReason: 'Gagal',
        ),
      ];

      final savedCount = await importService.saveCardsToDeck(
        deckId: deckId,
        cards: importedCards,
      );

      expect(savedCount, 2);

      final cardsInDb = await cardRepo.getCardsByDeck(deckId);
      expect(cardsInDb.length, 2);
      expect(
        cardsInDb.any((c) => c.frontText == 'Sun' && c.backText == 'Matahari'),
        isTrue,
      );
      expect(
        cardsInDb.any((c) => c.frontText == 'Moon' && c.backText == 'Bulan'),
        isTrue,
      );
    });
  });

  group('TTS Settings (Speed, Pitch, Voice) Tests', () {
    test('ThemePreferencesModel menyimpan dan memulihkan preferensi TTS', () {
      const defaultPrefs = ThemePreferencesModel(
        isDarkMode: false,
        accentColorValue: 0xFF2196F3,
      );

      expect(defaultPrefs.ttsSpeechRate, 0.5);
      expect(defaultPrefs.ttsPitch, 1.0);
      expect(defaultPrefs.ttsVoiceName, isNull);
      expect(defaultPrefs.ttsVoiceLocale, isNull);

      final customPrefs = defaultPrefs.copyWith(
        ttsSpeechRate: 0.75,
        ttsPitch: 1.25,
        ttsVoiceName: 'en-us-x-sfg#female_1-local',
        ttsVoiceLocale: 'en-US',
      );

      expect(customPrefs.ttsSpeechRate, 0.75);
      expect(customPrefs.ttsPitch, 1.25);
      expect(customPrefs.ttsVoiceName, 'en-us-x-sfg#female_1-local');
      expect(customPrefs.ttsVoiceLocale, 'en-US');

      final json = customPrefs.toJson();
      final restored = ThemePreferencesModel.fromJson(json);

      expect(restored.ttsSpeechRate, 0.75);
      expect(restored.ttsPitch, 1.25);
      expect(restored.ttsVoiceName, 'en-us-x-sfg#female_1-local');
      expect(restored.ttsVoiceLocale, 'en-US');
    });

    test(
      'ThemeController memperbarui kecepatan bicara, pitch, dan suara TTS',
      () async {
        final themeController = ThemeController();

        expect(themeController.ttsSpeechRate.value, 0.5);
        expect(themeController.ttsPitch.value, 1.0);
        expect(themeController.ttsVoiceName.value, isNull);

        await themeController.setTtsSpeechRate(0.8);
        expect(themeController.ttsSpeechRate.value, 0.8);

        await themeController.setTtsPitch(1.5);
        expect(themeController.ttsPitch.value, 1.5);

        await themeController.setTtsVoice('en-us-x-sfg', 'en-US');
        expect(themeController.ttsVoiceName.value, 'en-us-x-sfg');
        expect(themeController.ttsVoiceLocale.value, 'en-US');
      },
    );

    test(
      'AudioService mengeksekusi getAvailableVoices dan speakSample tanpa exception',
      () async {
        final audioService = AudioService();

        final voices = await audioService.getAvailableVoices();
        expect(voices, isA<List<Map<String, String>>>());

        await audioService.speakSample(text: 'Testing audio');
        await audioService.stop();
      },
    );
  });
}
