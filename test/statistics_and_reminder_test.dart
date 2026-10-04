import 'package:drift/drift.dart' as drift hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/study_log_repository.dart';
import 'package:english_flashcard_go/app/data/services/notification_service.dart';
import 'package:english_flashcard_go/app/data/services/theme_service.dart';
import 'package:english_flashcard_go/app/modules/statistics/controllers/statistics_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late StudyLogRepository studyLogRepo;

  setUp(() {
    Get.reset();
    db = AppDatabase(NativeDatabase.memory());
    deckRepo = DriftDeckRepository(db);
    cardRepo = DriftCardRepository(db);
    studyLogRepo = DriftStudyLogRepository(db);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  group('StudyLogRepository & Statistics Tests', () {
    test('Merekam aktivitas kartu dan menghitung jumlah kartu dipelajari hari ini', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Pemula');
      final card1Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Apple',
        backText: 'Apel',
      );
      final card2Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Banana',
        backText: 'Pisang',
      );

      // Sebelum belajar: 0
      expect(await studyLogRepo.getCardsStudiedTodayCount(), 0);
      expect(await studyLogRepo.getTotalReviewsTodayCount(), 0);

      // Kartu 1 direview sekali hari ini (SM-2 rating: 2 = Good)
      await studyLogRepo.recordLog(
        cardId: card1Id,
        deckId: deckId,
        rating: 2,
        isQuiz: false,
      );

      expect(await studyLogRepo.getCardsStudiedTodayCount(), 1);
      expect(await studyLogRepo.getTotalReviewsTodayCount(), 1);

      // Kartu 1 direview lagi hari ini (total ulasan = 2, kartu unik tetap = 1)
      await studyLogRepo.recordLog(
        cardId: card1Id,
        deckId: deckId,
        rating: 3,
        isQuiz: false,
      );

      expect(await studyLogRepo.getCardsStudiedTodayCount(), 1);
      expect(await studyLogRepo.getTotalReviewsTodayCount(), 2);

      // Kartu 2 direview hari ini
      await studyLogRepo.recordLog(
        cardId: card2Id,
        deckId: deckId,
        rating: 1,
        isQuiz: false,
      );

      expect(await studyLogRepo.getCardsStudiedTodayCount(), 2);
      expect(await studyLogRepo.getTotalReviewsTodayCount(), 3);
    });

    test('Menghitung streak harian dengan benar', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Streak');
      final cardId = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Fire',
        backText: 'Api',
      );

      // Tidak ada log -> streak 0
      expect(await studyLogRepo.getDailyStreak(), 0);

      final now = DateTime.now();

      // Belajar hari ini -> streak 1
      await db.into(db.studyLogs).insert(
            StudyLogsCompanion.insert(
              cardId: cardId,
              deckId: deckId,
              createdAt: drift.Value(now),
            ),
          );
      expect(await studyLogRepo.getDailyStreak(), 1);

      // Belajar kemarin (1 hari lalu) -> streak 2
      final yesterday = now.subtract(const Duration(days: 1));
      await db.into(db.studyLogs).insert(
            StudyLogsCompanion.insert(
              cardId: cardId,
              deckId: deckId,
              createdAt: drift.Value(yesterday),
            ),
          );
      expect(await studyLogRepo.getDailyStreak(), 2);

      // Belajar 2 hari lalu -> streak 3
      final twoDaysAgo = now.subtract(const Duration(days: 2));
      await db.into(db.studyLogs).insert(
            StudyLogsCompanion.insert(
              cardId: cardId,
              deckId: deckId,
              createdAt: drift.Value(twoDaysAgo),
            ),
          );
      expect(await studyLogRepo.getDailyStreak(), 3);
    });

    test('Menjaga streak jika kemarin belajar meski hari ini belum belajar', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Streak Kemarin');
      final cardId = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Water',
        backText: 'Air',
      );

      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await db.into(db.studyLogs).insert(
            StudyLogsCompanion.insert(
              cardId: cardId,
              deckId: deckId,
              createdAt: drift.Value(yesterday),
            ),
          );

      // Karena kemarin belajar, streak masih 1 (belum patah)
      expect(await studyLogRepo.getDailyStreak(), 1);
    });

    test('Merekam aktivitas kuis dan menghitung akurasi kuis', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Kuis');
      final card1 = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Sun',
        backText: 'Matahari',
      );
      final card2 = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Moon',
        backText: 'Bulan',
      );

      // Belum ada kuis -> akurasi 0.0
      expect(await studyLogRepo.getQuizAccuracy(), 0.0);
      expect(await studyLogRepo.getTotalQuizAnswered(), 0);

      // Jawab 3 soal: 2 benar, 1 salah
      await studyLogRepo.recordLog(
        cardId: card1,
        deckId: deckId,
        isQuiz: true,
        isCorrect: true,
      );
      await studyLogRepo.recordLog(
        cardId: card1,
        deckId: deckId,
        isQuiz: true,
        isCorrect: false,
      );
      await studyLogRepo.recordLog(
        cardId: card2,
        deckId: deckId,
        isQuiz: true,
        isCorrect: true,
      );

      expect(await studyLogRepo.getTotalQuizAnswered(), 3);
      expect(await studyLogRepo.getTotalQuizCorrect(), 2);
      // 2 / 3 * 100 = 66.7%
      expect(await studyLogRepo.getQuizAccuracy(), 66.7);
    });

    test('Mengambil daftar kartu tersulit berdasarkan ease rendah dan riwayat salah', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Kosakata Sulit');

      // Card 1: Ease rendah (1.5)
      final card1Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Ephemeral',
        backText: 'Berumur pendek / fana',
      );
      await cardRepo.updateCardData(id: card1Id, ease: 1.5, difficulty: 3);

      // Card 2: Ease tinggi (2.8)
      final card2Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Happy',
        backText: 'Senang',
      );
      await cardRepo.updateCardData(id: card2Id, ease: 2.8, difficulty: 1);

      // Card 3: Ease sedang (2.1) tapi sering salah (rating 0 = Lagi)
      final card3Id = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Ambiguous',
        backText: 'Bermakna ganda',
      );
      await cardRepo.updateCardData(id: card3Id, ease: 2.1, difficulty: 2);

      // Log kesalahan untuk Card 1 dan Card 3
      await studyLogRepo.recordLog(
        cardId: card1Id,
        deckId: deckId,
        rating: 0, // rating lagi / gagal
        isQuiz: false,
      );
      await studyLogRepo.recordLog(
        cardId: card3Id,
        deckId: deckId,
        isQuiz: true,
        isCorrect: false,
      );
      await studyLogRepo.recordLog(
        cardId: card3Id,
        deckId: deckId,
        rating: 0,
        isQuiz: false,
      );

      final hardest = await studyLogRepo.getHardestCards(limit: 5);
      expect(hardest.length, 3);
      // Card 1 paling sulit karena ease paling rendah (1.5)
      expect(hardest.first.card.frontText, 'Ephemeral');
      expect(hardest.first.ease, 1.5);
      expect(hardest.first.failCount, 1);

      // Card 3 urutan kedua dengan ease 2.1 dan 2 kali salah
      expect(hardest[1].card.frontText, 'Ambiguous');
      expect(hardest[1].ease, 2.1);
      expect(hardest[1].failCount, 2);

      // Card 2 urutan terakhir dengan ease 2.8
      expect(hardest.last.card.frontText, 'Happy');
      expect(hardest.last.failCount, 0);
    });

    test('Kartu terhapus (soft delete) tidak muncul di daftar kartu tersulit', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Hapus');
      final cardId = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Tough',
        backText: 'Keras/Tangguh',
      );
      await cardRepo.updateCardData(id: cardId, ease: 1.3, difficulty: 3);

      expect((await studyLogRepo.getHardestCards()).length, 1);

      // Soft delete kartu
      await cardRepo.softDeleteCard(cardId);

      // Harusnya sudah tidak muncul di kartu tersulit
      expect((await studyLogRepo.getHardestCards()).isEmpty, true);
    });
  });

  group('StatisticsController Tests', () {
    test('StatisticsController memuat semua data statistik dengan sukses', () async {
      final deckId = await deckRepo.createDeck(title: 'Deck Controller');
      final cardId = await cardRepo.createCard(
        deckId: deckId,
        frontText: 'Knowledge',
        backText: 'Pengetahuan',
      );

      await studyLogRepo.recordLog(
        cardId: cardId,
        deckId: deckId,
        rating: 2,
        isQuiz: false,
      );
      await studyLogRepo.recordLog(
        cardId: cardId,
        deckId: deckId,
        isQuiz: true,
        isCorrect: true,
      );

      final controller = StatisticsController(studyLogRepository: studyLogRepo);
      await controller.loadStatistics();

      expect(controller.isLoading.value, false);
      expect(controller.errorMessage.value, '');
      expect(controller.cardsStudiedToday.value, 1);
      expect(controller.dailyStreak.value, 1);
      expect(controller.quizAccuracy.value, 100.0);
      expect(controller.totalQuizAnswered.value, 1);
      expect(controller.totalQuizCorrect.value, 1);
      expect(controller.hardestCards.length, 1);
    });
  });

  group('Pengingat Belajar Harian & Notification Tests', () {
    test('ThemePreferencesModel menyimpan dan memuat pengaturan jam pengingat', () {
      const defaultPrefs = ThemePreferencesModel(
        isDarkMode: false,
        accentColorValue: 0xFF2196F3,
      );
      expect(defaultPrefs.isReminderEnabled, false);
      expect(defaultPrefs.reminderHour, 19);
      expect(defaultPrefs.reminderMinute, 0);

      final customPrefs = defaultPrefs.copyWith(
        isReminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 45,
      );
      expect(customPrefs.isReminderEnabled, true);
      expect(customPrefs.reminderHour, 20);
      expect(customPrefs.reminderMinute, 45);

      final json = customPrefs.toJson();
      final restored = ThemePreferencesModel.fromJson(json);

      expect(restored.isReminderEnabled, true);
      expect(restored.reminderHour, 20);
      expect(restored.reminderMinute, 45);
    });

    test('NotificationService dapat diinisialisasi dan dieksekusi tanpa error', () async {
      final notificationService = NotificationService();
      await notificationService.init();

      // Memastikan penjadwalan pengingat dan pembatalan tidak throw unhandled exception
      await notificationService.scheduleDailyReminder(hour: 20, minute: 0);
      await notificationService.cancelReminder();
    });
  });
}
