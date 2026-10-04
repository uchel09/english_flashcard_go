import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../data/repositories/deck_repository.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/export_service.dart';
import '../../../data/services/import_service.dart';
import '../../../routes/app_pages.dart';
import '../../../widgets/card_import_dialog.dart';

class SettingsController extends GetxController {
  final ExportService _exportService;
  final ImportService _importService;
  final DeckRepository _deckRepository;
  final AudioService? _audioService;

  SettingsController({
    ExportService? exportService,
    ImportService? importService,
    DeckRepository? deckRepository,
    AudioService? audioService,
  })  : _exportService = exportService ?? Get.find<ExportService>(),
        _importService = importService ?? Get.find<ImportService>(),
        _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _audioService = audioService ??
            (Get.isRegistered<AudioService>() ? Get.find<AudioService>() : null);

  final RxBool isExporting = false.obs;
  final RxBool isImporting = false.obs;
  final RxInt trashItemCount = 0.obs;
  final RxList<Map<String, String>> availableVoices =
      <Map<String, String>>[].obs;

  static const Map<String, String> availableLanguages = {
    'id': 'Indonesia',
    'en': 'Inggris',
    'es': 'Spanyol',
    'ja': 'Jepang',
    'de': 'Jerman',
    'fr': 'Prancis',
    'zh': 'Mandarin',
    'ar': 'Arab',
  };

  @override
  void onInit() {
    super.onInit();
    loadTrashCount();
    loadTtsVoices();
  }

  Future<void> loadTtsVoices() async {
    try {
      if (_audioService != null) {
        final voices = await _audioService.getAvailableVoices();
        availableVoices.assignAll(voices);
      }
    } catch (_) {}
  }

  Future<void> testTtsVoice() async {
    try {
      if (_audioService != null) {
        await _audioService.speakSample(
          text: 'Hello, this is a voice sample for your English flashcards.',
          lang: 'en-US',
        );
      }
    } catch (e) {
      Get.snackbar(
        'Gagal Memutar Suara',
        'Tidak dapat memutar suara sampel TTS: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void importCardsCsvOrText(BuildContext context) {
    CardImportHelper.showImportOptionsModal(context);
  }

  Future<void> loadTrashCount() async {
    try {
      final decks = await _deckRepository.getTrashDecks();
      trashItemCount.value = decks.length;
    } catch (_) {}
  }

  Future<void> exportAllDecks() async {
    try {
      isExporting.value = true;
      Get.showSnackbar(
        const GetSnackBar(
          title: 'Mengekspor...',
          message: 'Menyiapkan berkas cadangan seluruh deck...',
          duration: Duration(seconds: 2),
          snackPosition: SnackPosition.BOTTOM,
        ),
      );

      final file = await _exportService.exportAllDecks(share: true);
      Get.showSnackbar(
        GetSnackBar(
          title: 'Ekspor Berhasil',
          message: 'Berkas cadangan siap dibagikan: ${file.path.split(RegExp(r'[/\\]')).last}',
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Gagal Ekspor',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> importDeck() async {
    try {
      isImporting.value = true;
      final imported = await _importService.pickAndImportDeck();
      if (imported != null) {
        Get.showSnackbar(
          GetSnackBar(
            title: 'Impor Berhasil',
            message: 'Deck "${imported.title}" berhasil diimpor.',
            duration: const Duration(seconds: 3),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Gagal Impor',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      isImporting.value = false;
    }
  }

  Future<void> backupAllDataZip() async {
    try {
      isExporting.value = true;
      if (Get.context != null) {
        Get.showSnackbar(
          const GetSnackBar(
            title: 'Mencadangkan...',
            message: 'Menyiapkan berkas zip cadangan seluruh data...',
            duration: Duration(seconds: 2),
            snackPosition: SnackPosition.BOTTOM,
          ),
        );
      }

      final file = await _exportService.backupAllDataZip(share: true);
      if (Get.context != null) {
        Get.showSnackbar(
          GetSnackBar(
            title: 'Pencadangan Berhasil',
            message:
                'Berkas cadangan zip siap dibagikan: ${file.path.split(RegExp(r'[/\\]')).last}',
            duration: const Duration(seconds: 3),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar(
          'Gagal Mencadangkan',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
      }
    } finally {
      isExporting.value = false;
    }
  }

  Future<void> confirmAndRestoreZip(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_backup_restore, color: Colors.blue),
            SizedBox(width: 8),
            Text('Pulihkan Cadangan'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih metode pemulihan seluruh data dari berkas cadangan (.zip):',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              '• Tambahkan: Memasukkan deck cadangan tanpa menghapus deck yang ada saat ini.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '• Gantikan: Menghapus seluruh data saat ini dan menggantikannya secara menyeluruh dengan data dari cadangan.',
              style: TextStyle(fontSize: 13, color: Colors.redAccent),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('merge'),
            child: const Text('Tambahkan'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop('replace'),
            child: const Text('Gantikan Data'),
          ),
        ],
      ),
    );

    if (result == 'replace') {
      await performRestoreZip(replaceExisting: true);
    } else if (result == 'merge') {
      await performRestoreZip(replaceExisting: false);
    }
  }

  Future<void> performRestoreZip({required bool replaceExisting}) async {
    try {
      isImporting.value = true;
      if (Get.context != null) {
        Get.showSnackbar(
          const GetSnackBar(
            title: 'Memulihkan...',
            message: 'Mengekstrak dan memulihkan data dari zip...',
            duration: Duration(seconds: 2),
            snackPosition: SnackPosition.BOTTOM,
          ),
        );
      }

      final count = await _importService.pickAndRestoreZip(
        replaceExisting: replaceExisting,
      );
      if (count != null) {
        await loadTrashCount();
        if (Get.context != null) {
          Get.showSnackbar(
            GetSnackBar(
              title: 'Pemulihan Berhasil',
              message:
                  'Berhasil memulihkan $count deck beserta kartu dan medianya.',
              duration: const Duration(seconds: 3),
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar(
          'Gagal Memulihkan Cadangan',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
      }
    } finally {
      isImporting.value = false;
    }
  }

  Future<void> setDefaultSourceLang(String lang) async {
    await ThemeController.to.setDefaultSourceLang(lang);
    Get.showSnackbar(
      GetSnackBar(
        title: 'Bahasa Asal Diperbarui',
        message:
            'Bahasa asal default untuk deck baru: ${availableLanguages[lang] ?? lang}',
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.BOTTOM,
      ),
    );
  }

  void navigateToTrash() {
    Get.toNamed(Routes.TRASH)?.then((_) => loadTrashCount());
  }
}
