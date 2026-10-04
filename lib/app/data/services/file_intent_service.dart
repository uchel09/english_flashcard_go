import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../modules/home/controllers/home_controller.dart';
import 'import_service.dart';

class FileIntentService extends GetxService {
  static FileIntentService get to => Get.find<FileIntentService>();

  static const MethodChannel _channel =
      MethodChannel('com.flashcard.english/file_intent');

  final ImportService _importService;

  FileIntentService({ImportService? importService})
      : _importService = importService ?? Get.find<ImportService>();

  final RxBool isImportingFromIntent = false.obs;

  Future<FileIntentService> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFileReceived') {
        final filePath = call.arguments as String?;
        if (filePath != null && filePath.isNotEmpty) {
          await handleIncomingFile(filePath);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkInitialFile();
    });

    return this;
  }

  Future<void> checkInitialFile() async {
    try {
      final initialPath = await _channel.invokeMethod<String>('getInitialFile');
      if (initialPath != null && initialPath.isNotEmpty) {
        await handleIncomingFile(initialPath);
      }
    } catch (e) {
      debugPrint('FileIntentService: getInitialFile check failed: $e');
    }
  }

  Future<void> handleIncomingFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;

    final fileName = p.basename(filePath);

    if (Get.context == null) {
      // In headless test environment where no UI overlay exists
      await executeImport(file);
      return;
    }

    await Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Konfirmasi Impor Deck'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi menerima berkas paket flashcard dari aplikasi eksternal (WhatsApp / File Manager):',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Apakah Anda ingin mengimpor deck ini ke dalam aplikasi?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              try {
                if (file.existsSync()) file.deleteSync();
              } catch (_) {}
              Get.back();
            },
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Impor Sekarang'),
            onPressed: () async {
              Get.back();
              await executeImport(file);
            },
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<void> executeImport(File file) async {
    try {
      isImportingFromIntent.value = true;
      if (Get.context != null) {
        Get.showSnackbar(
          const GetSnackBar(
            title: 'Mengimpor Deck...',
            message: 'Mengekstrak berkas dan memverifikasi isi deck...',
            duration: Duration(seconds: 2),
            snackPosition: SnackPosition.BOTTOM,
          ),
        );
      }

      final importedDeck = await _importService.importDeckFromFile(file);

      if (Get.isRegistered<HomeController>()) {
        HomeController.to.refreshDecks();
      }

      if (Get.context != null) {
        Get.showSnackbar(
          GetSnackBar(
            title: 'Impor Berhasil',
            message: 'Deck "${importedDeck.title}" berhasil ditambahkan.',
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green.shade700,
            snackPosition: SnackPosition.BOTTOM,
          ),
        );
      }

      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    } catch (e) {
      if (Get.context != null) {
        Get.snackbar(
          'Gagal Mengimpor Deck',
          e.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
      }
    } finally {
      isImportingFromIntent.value = false;
    }
  }
}
