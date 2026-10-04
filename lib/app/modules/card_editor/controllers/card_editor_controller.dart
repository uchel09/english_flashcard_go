import 'package:flutter/material.dart' hide Card;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/database/app_database.dart';
import '../../../data/repositories/card_repository.dart';
import '../../../data/services/audio_service.dart';
import '../../../data/services/media_service.dart';

class CardEditorController extends GetxController {
  final CardRepository _cardRepository;
  final MediaService _mediaService;
  final AudioService _audioService;

  CardEditorController({
    CardRepository? cardRepository,
    MediaService? mediaService,
    AudioService? audioService,
  })  : _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _mediaService = mediaService ?? Get.find<MediaService>(),
        _audioService = audioService ?? Get.find<AudioService>();

  final Rx<Deck?> deck = Rx<Deck?>(null);
  final Rx<Card?> editingCard = Rx<Card?>(null);

  final TextEditingController frontTextController = TextEditingController();
  final TextEditingController backTextController = TextEditingController();

  final RxnString frontAudioPath = RxnString();
  final RxnString backAudioPath = RxnString();

  final RxnString frontImagePath = RxnString();
  final RxnString backImagePath = RxnString();

  final RxBool isFrontRecording = false.obs;
  final RxBool isBackRecording = false.obs;
  final RxBool isPlayingPreview = false.obs;
  final RxString activePreviewSide = ''.obs;
  final RxBool isSaving = false.obs;

  bool get isEditing => editingCard.value != null;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map) {
      if (args['deck'] is Deck) {
        deck.value = args['deck'] as Deck;
      }
      if (args['card'] is Card) {
        final card = args['card'] as Card;
        editingCard.value = card;
        frontTextController.text = card.frontText;
        backTextController.text = card.backText;
        frontAudioPath.value = card.frontAudioPath;
        backAudioPath.value = card.backAudioPath;
        frontImagePath.value = card.frontImagePath;
        backImagePath.value = card.backImagePath;
      }
    } else if (args is Deck) {
      deck.value = args;
    }
  }

  @override
  void onClose() {
    if (isFrontRecording.value || isBackRecording.value) {
      _mediaService.stopRecording();
    }
    frontTextController.dispose();
    backTextController.dispose();
    _audioService.stop();
    super.onClose();
  }

  // --- Audio Recording ---

  Future<void> toggleRecording(String side) async {
    final isFront = side == 'front';
    final isCurrentlyRecording = isFront ? isFrontRecording.value : isBackRecording.value;

    if (isCurrentlyRecording) {
      // Stop recording
      try {
        final relativePath = await _mediaService.stopRecording();
        if (isFront) {
          isFrontRecording.value = false;
          if (relativePath != null) frontAudioPath.value = relativePath;
        } else {
          isBackRecording.value = false;
          if (relativePath != null) backAudioPath.value = relativePath;
        }
      } catch (e) {
        debugPrint('Error stopping recording: $e');
      }
    } else {
      // Start recording
      try {
        await _audioService.stop();
        await _mediaService.startRecording(side);
        if (isFront) {
          isFrontRecording.value = true;
        } else {
          isBackRecording.value = true;
        }
      } catch (e) {
        if (isFront) {
          isFrontRecording.value = false;
        } else {
          isBackRecording.value = false;
        }
        Get.dialog(
          AlertDialog(
            title: const Text('Izin Mikrofon Diperlukan'),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
            ),
            actions: [
              FilledButton(
                onPressed: () => Get.back(),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
    }
  }

  // --- Pick Audio File ---

  Future<void> pickAudioFile(String side) async {
    try {
      final relativePath = await _mediaService.pickAudioFile(side);
      if (relativePath != null) {
        if (side == 'front') {
          frontAudioPath.value = relativePath;
        } else {
          backAudioPath.value = relativePath;
        }
      }
    } catch (e) {
      Get.snackbar(
        'Peringatan',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // --- Pick Image ---

  Future<void> pickImage(ImageSource source, String side) async {
    try {
      final relativePath = await _mediaService.pickImage(source, side);
      if (relativePath != null) {
        if (side == 'front') {
          frontImagePath.value = relativePath;
        } else {
          backImagePath.value = relativePath;
        }
      }
    } catch (e) {
      Get.dialog(
        AlertDialog(
          title: const Text('Izin Kamera / Galeri Diperlukan'),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
          ),
          actions: [
            FilledButton(
              onPressed: () => Get.back(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
    }
  }

  // --- Remove Media ---

  Future<void> removeAudio(String side) async {
    await _audioService.stop();
    if (side == 'front') {
      frontAudioPath.value = null;
    } else {
      backAudioPath.value = null;
    }
  }

  Future<void> removeImage(String side) async {
    if (side == 'front') {
      frontImagePath.value = null;
    } else {
      backImagePath.value = null;
    }
  }

  // --- Preview Audio ---

  Future<void> playAudioPreview(String? path, String side) async {
    if (path == null) return;
    if (_audioService.isPlaying.value && activePreviewSide.value == side) {
      await _audioService.stop();
      isPlayingPreview.value = false;
      activePreviewSide.value = '';
    } else {
      activePreviewSide.value = side;
      isPlayingPreview.value = true;
      await _audioService.playAudioPath(path);
      isPlayingPreview.value = false;
      activePreviewSide.value = '';
    }
  }

  Future<String> resolveAbsolutePath(String relativePath) {
    return _mediaService.resolveAbsolutePath(relativePath);
  }

  // --- Validation & Save Flow ---

  bool validateAtLeastOneSideFilled() {
    final hasFront = frontTextController.text.trim().isNotEmpty ||
        frontAudioPath.value != null ||
        frontImagePath.value != null;
    final hasBack = backTextController.text.trim().isNotEmpty ||
        backAudioPath.value != null ||
        backImagePath.value != null;
    return hasFront || hasBack;
  }

  Future<bool> checkForDuplicateFrontText() async {
    final currentDeck = deck.value;
    if (currentDeck == null) return false;

    final queryText = frontTextController.text.trim().toLowerCase();
    if (queryText.isEmpty) return false;

    final existingCards = await _cardRepository.getCardsByDeck(currentDeck.id);
    final editingId = editingCard.value?.id;

    return existingCards.any((card) =>
        card.id != editingId &&
        card.frontText.trim().toLowerCase() == queryText);
  }

  Future<void> saveCard() async {
    // 1. Validation: Minimal salah satu sisi terisi
    if (!validateAtLeastOneSideFilled()) {
      Get.snackbar(
        'Validasi Gagal',
        'Minimal salah satu sisi kartu (depan atau belakang) harus terisi teks, rekaman suara, atau gambar.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final currentDeck = deck.value;
    if (currentDeck == null) {
      Get.snackbar(
        'Gagal Menyimpan',
        'Informasi deck tidak ditemukan.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 2. Check for duplicate front text in the same deck
    final isDuplicate = await checkForDuplicateFrontText();
    if (isDuplicate) {
      final proceed = await _showDuplicateWarningDialog();
      if (!proceed) return;
    }

    // 3. Save to database
    try {
      isSaving.value = true;
      final frontText = frontTextController.text.trim();
      final backText = backTextController.text.trim();

      if (isEditing) {
        await _cardRepository.updateCardData(
          id: editingCard.value!.id,
          frontText: frontText,
          backText: backText,
          frontAudioPath: frontAudioPath.value,
          backAudioPath: backAudioPath.value,
          frontImagePath: frontImagePath.value,
          backImagePath: backImagePath.value,
        );
        Get.back(result: true);
        Get.snackbar(
          'Berhasil',
          'Perubahan kartu berhasil disimpan.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        await _cardRepository.createCard(
          deckId: currentDeck.id,
          frontText: frontText,
          backText: backText,
          frontAudioPath: frontAudioPath.value,
          backAudioPath: backAudioPath.value,
          frontImagePath: frontImagePath.value,
          backImagePath: backImagePath.value,
        );
        Get.back(result: true);
        Get.snackbar(
          'Berhasil',
          'Kartu baru berhasil ditambahkan.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint('Error saving card: $e');
      Get.snackbar(
        'Kesalahan',
        'Gagal menyimpan kartu: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> _showDuplicateWarningDialog() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Peringatan Duplikat'),
          ],
        ),
        content: Text(
          'Kartu dengan teks depan "${frontTextController.text.trim()}" sudah ada di dalam deck ini. Apakah Anda yakin ingin tetap menyimpannya?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Tetap Simpan'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
