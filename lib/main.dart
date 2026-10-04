import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/controllers/theme_controller.dart';
import 'app/data/database/app_database.dart';
import 'app/data/repositories/card_repository.dart';
import 'app/data/repositories/deck_repository.dart';
import 'app/data/repositories/study_log_repository.dart';
import 'app/data/services/audio_service.dart';
import 'app/data/services/export_service.dart';
import 'app/data/services/file_intent_service.dart';
import 'app/data/services/import_service.dart';
import 'app/data/services/media_service.dart';
import 'app/data/services/notification_service.dart';
import 'app/data/services/sample_deck_service.dart';
import 'app/routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  final notificationService = Get.put(NotificationService(), permanent: true);
  await notificationService.init();

  // Initialize theme
  final themeController = Get.put(ThemeController(), permanent: true);
  await themeController.loadThemeSettings();

  // Initialize database, repositories, and services
  final db = AppDatabase();
  Get.put<AppDatabase>(db, permanent: true);
  Get.put<DeckRepository>(DriftDeckRepository(db), permanent: true);
  Get.put<CardRepository>(DriftCardRepository(db), permanent: true);
  Get.put<StudyLogRepository>(DriftStudyLogRepository(db), permanent: true);
  Get.put<AudioService>(AudioService(), permanent: true);
  Get.put<MediaService>(MediaService(), permanent: true);
  Get.put<ExportService>(ExportService(), permanent: true);
  Get.put<ImportService>(ImportService(), permanent: true);

  // Seed sample deck on first run if database has no decks
  final sampleDeckService = Get.put(SampleDeckService(), permanent: true);
  await sampleDeckService.seedSampleDeckIfNotExists();

  // Initialize file intent service for Android "Open with"
  final fileIntentService = Get.put(FileIntentService(), permanent: true);
  await fileIntentService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String? initialRoute;
  const MyApp({super.key, this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.to;
    return Obx(
      () => GetMaterialApp(
        title: 'English Flashcard',
        initialRoute: initialRoute ??
            (themeController.hasCompletedOnboarding.value
                ? Routes.HOME
                : Routes.ONBOARDING),
        getPages: AppPages.routes,
        theme: themeController.lightTheme,
        darkTheme: themeController.darkTheme,
        themeMode: themeController.themeMode,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
