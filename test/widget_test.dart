import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:english_flashcard_go/app/controllers/theme_controller.dart';
import 'package:english_flashcard_go/app/data/database/app_database.dart';
import 'package:english_flashcard_go/app/data/repositories/card_repository.dart';
import 'package:english_flashcard_go/app/data/repositories/deck_repository.dart';
import 'package:english_flashcard_go/app/data/services/audio_service.dart';
import 'package:english_flashcard_go/app/data/services/export_service.dart';
import 'package:english_flashcard_go/app/data/services/import_service.dart';
import 'package:english_flashcard_go/app/data/services/media_service.dart';
import 'package:english_flashcard_go/app/data/services/theme_service.dart';
import 'package:english_flashcard_go/main.dart';

class MockThemeService extends ThemeService {
  ThemePreferencesModel? preferences = const ThemePreferencesModel(
    isDarkMode: false,
    accentColorValue: 0xFF3F51B5,
    hasCompletedOnboarding: true,
  );

  @override
  Future<ThemePreferencesModel?> readPreferences() async => preferences;

  @override
  Future<void> writePreferences(ThemePreferencesModel model) async {
    preferences = model;
  }
}

class MockAudioService extends AudioService {
  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() {
    Get.reset();
  });

  testWidgets('App renders HomeView with AppBar, Biasa, and Premium sections',
      (WidgetTester tester) async {
    final mockService = MockThemeService();
    final themeController = Get.put(
      ThemeController(themeService: mockService),
      permanent: true,
    );
    await themeController.loadThemeSettings();

    final db = AppDatabase(NativeDatabase.memory());
    final deckRepo = DriftDeckRepository(db);
    final cardRepo = DriftCardRepository(db);
    final mediaService = MediaService();

    Get.put<AppDatabase>(db, permanent: true);
    Get.put<DeckRepository>(deckRepo, permanent: true);
    Get.put<CardRepository>(cardRepo, permanent: true);
    Get.put<AudioService>(MockAudioService(), permanent: true);
    Get.put<MediaService>(mediaService, permanent: true);
    Get.put<ExportService>(
      ExportService(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      ),
      permanent: true,
    );
    Get.put<ImportService>(
      ImportService(
        database: db,
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      ),
      permanent: true,
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Flashcard'), findsOneWidget);
    expect(find.byTooltip('Tambah Deck'), findsOneWidget);
    expect(find.byTooltip('Pengaturan'), findsOneWidget);

    // Verify Body Sections
    expect(find.text('Biasa'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);

    // Navigate to Settings
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Tampilan & Tema'), findsOneWidget);
    expect(find.text('Mode Tema'), findsOneWidget);
    await db.close();
  });

  testWidgets('HomeView create deck, rename, soft delete, and undo flow',
      (WidgetTester tester) async {
    final mockService = MockThemeService();
    final themeController = Get.put(
      ThemeController(themeService: mockService),
      permanent: true,
    );
    await themeController.loadThemeSettings();

    final db = AppDatabase(NativeDatabase.memory());
    final deckRepo = DriftDeckRepository(db);
    final cardRepo = DriftCardRepository(db);
    final mediaService = MediaService();

    Get.put<AppDatabase>(db, permanent: true);
    Get.put<DeckRepository>(deckRepo, permanent: true);
    Get.put<CardRepository>(cardRepo, permanent: true);
    Get.put<AudioService>(MockAudioService(), permanent: true);
    Get.put<MediaService>(mediaService, permanent: true);
    Get.put<ExportService>(
      ExportService(
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      ),
      permanent: true,
    );
    Get.put<ImportService>(
      ImportService(
        database: db,
        deckRepository: deckRepo,
        cardRepository: cardRepo,
        mediaService: mediaService,
      ),
      permanent: true,
    );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Create a regular deck
    await tester.tap(find.byTooltip('Tambah Deck'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Deck Baru'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Bahasa Sehari-hari');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Bahasa Sehari-hari'), findsOneWidget);

    // 2. Open bottom sheet by tapping the deck
    await tester.tap(find.text('Bahasa Sehari-hari'));
    await tester.pumpAndSettle();

    expect(find.text('Buka deck'), findsOneWidget);
    expect(find.text('Ganti nama'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);

    // 3. Rename deck
    await tester.tap(find.text('Ganti nama'));
    await tester.pumpAndSettle();

    expect(find.text('Ganti Nama Deck'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Kosakata Sehari-hari');
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Kosakata Sehari-hari'), findsOneWidget);

    // 4. Soft delete deck
    await tester.tap(find.text('Kosakata Sehari-hari'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Hapus Deck?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();

    // Should be removed from regular list and show Undo
    expect(find.text('Kosakata Sehari-hari'), findsNothing);
    expect(find.text('Urungkan'), findsOneWidget);

    // 5. Undo deletion
    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();

    expect(find.text('Kosakata Sehari-hari'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await db.close();
  });

  test('ThemeController toggles dark mode and saves preferences', () async {
    final mockService = MockThemeService();
    final themeController = ThemeController(themeService: mockService);

    expect(themeController.isDarkMode.value, false);

    await themeController.setDarkMode(true);
    expect(themeController.isDarkMode.value, true);
    expect(mockService.preferences?.isDarkMode, true);

    await themeController.setAccentColor(Colors.teal);
    expect(themeController.accentColor.value, Colors.teal);
    expect(mockService.preferences?.accentColorValue, Colors.teal.toARGB32());
  });
}
