import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';
import '../repositories/card_repository.dart';
import '../repositories/deck_repository.dart';
import 'media_service.dart';

typedef ShareHandler = Future<void> Function(File file, String title);

class ExportService extends GetxService {
  static ExportService get to => Get.find<ExportService>();

  final AppDatabase? _db;
  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;
  final MediaService _mediaService;
  final ShareHandler? _shareHandler;

  ExportService({
    AppDatabase? database,
    DeckRepository? deckRepository,
    CardRepository? cardRepository,
    MediaService? mediaService,
    ShareHandler? shareHandler,
  })  : _db = database ??
            (Get.isRegistered<AppDatabase>() ? Get.find<AppDatabase>() : null),
        _deckRepository = deckRepository ?? Get.find<DeckRepository>(),
        _cardRepository = cardRepository ?? Get.find<CardRepository>(),
        _mediaService = mediaService ??
            (Get.isRegistered<MediaService>()
                ? Get.find<MediaService>()
                : MediaService()),
        _shareHandler = shareHandler;

  /// Mengekspor deck beserta subdeck, kartu, dan media terkait ke file `.flashdeck`.
  /// Jika [share] bernilai `true`, file akan dibagikan via `share_plus`.
  Future<File> exportDeck({
    required Deck deck,
    bool share = false,
  }) async {
    // 1. Ambil semua kartu milik deck utama
    final cards = await _cardRepository.getCardsByDeck(deck.id);

    // 2. Ambil subdeck dan kartu-kartunya jika ada
    final subDecks = await _deckRepository.getSubDecks(deck.id);
    final List<Map<String, dynamic>> subDeckMaps = [];

    final archive = Archive();
    final Set<String> addedMediaPaths = {};

    Future<void> addMediaIfValid(String? relativePath) async {
      if (relativePath == null || relativePath.trim().isEmpty) return;
      if (addedMediaPaths.contains(relativePath)) return;

      final absPath = await _mediaService.resolveAbsolutePath(relativePath);
      final file = File(absPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        addedMediaPaths.add(relativePath);
      }
    }

    // Media kartu deck utama
    for (final card in cards) {
      await addMediaIfValid(card.frontAudioPath);
      await addMediaIfValid(card.backAudioPath);
      await addMediaIfValid(card.frontImagePath);
      await addMediaIfValid(card.backImagePath);
    }

    // Subdeck & media kartu subdeck
    for (final sub in subDecks) {
      final subCards = await _cardRepository.getCardsByDeck(sub.id);
      for (final subCard in subCards) {
        await addMediaIfValid(subCard.frontAudioPath);
        await addMediaIfValid(subCard.backAudioPath);
        await addMediaIfValid(subCard.frontImagePath);
        await addMediaIfValid(subCard.backImagePath);
      }

      subDeckMaps.add({
        'metadata': {
          'title': sub.title,
          'source_lang': sub.sourceLang,
          'target_lang': sub.targetLang,
          'is_premium': sub.isPremium,
          'color': sub.color,
        },
        'cards': subCards.map((c) => _cardToMap(c)).toList(),
      });
    }

    // 3. Susun data manifest JSON (deck.json)
    final Map<String, dynamic> manifest = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'metadata': {
        'title': deck.title,
        'source_lang': deck.sourceLang,
        'target_lang': deck.targetLang,
        'is_premium': deck.isPremium,
        'color': deck.color,
      },
      'cards': cards.map((c) => _cardToMap(c)).toList(),
      'subdecks': subDeckMaps,
    };

    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('deck.json', jsonBytes.length, jsonBytes));

    // 4. Kompresi menjadi zip (.flashdeck)
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes.isEmpty) {
      throw Exception('Gagal mengompresi data deck ke format .flashdeck.');
    }

    // 5. Simpan file ke direktori sementara
    final tempDir = await getTemporaryDirectory();
    final sanitizedTitle =
        deck.title.replaceAll(RegExp(r'[^\w\s\-]'), '_').trim();
    final filename = sanitizedTitle.isEmpty ? 'deck' : sanitizedTitle;
    final exportFile = File('${tempDir.path}/$filename.flashdeck');
    await exportFile.writeAsBytes(zipBytes);

    // 6. Bagikan jika diminta
    if (share) {
      await _shareFile(exportFile, deck.title);
    }

    return exportFile;
  }

  /// Mengekspor seluruh root deck beserta subdeck, kartu, dan media terkait ke file `.flashdeck`.
  Future<File> exportAllDecks({bool share = false}) async {
    final rootDecks = await _deckRepository.getRootDecks();
    if (rootDecks.isEmpty) {
      throw Exception('Tidak ada deck yang dapat diekspor.');
    }

    final archive = Archive();
    final Set<String> addedMediaPaths = {};

    Future<void> addMediaIfValid(String? relativePath) async {
      if (relativePath == null || relativePath.trim().isEmpty) return;
      if (addedMediaPaths.contains(relativePath)) return;

      final absPath = await _mediaService.resolveAbsolutePath(relativePath);
      final file = File(absPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        addedMediaPaths.add(relativePath);
      }
    }

    final List<Map<String, dynamic>> decksData = [];

    for (final deck in rootDecks) {
      final cards = await _cardRepository.getCardsByDeck(deck.id);
      for (final card in cards) {
        await addMediaIfValid(card.frontAudioPath);
        await addMediaIfValid(card.backAudioPath);
        await addMediaIfValid(card.frontImagePath);
        await addMediaIfValid(card.backImagePath);
      }

      final subDecks = await _deckRepository.getSubDecks(deck.id);
      final List<Map<String, dynamic>> subDeckMaps = [];
      for (final sub in subDecks) {
        final subCards = await _cardRepository.getCardsByDeck(sub.id);
        for (final subCard in subCards) {
          await addMediaIfValid(subCard.frontAudioPath);
          await addMediaIfValid(subCard.backAudioPath);
          await addMediaIfValid(subCard.frontImagePath);
          await addMediaIfValid(subCard.backImagePath);
        }

        subDeckMaps.add({
          'metadata': {
            'title': sub.title,
            'source_lang': sub.sourceLang,
            'target_lang': sub.targetLang,
            'is_premium': sub.isPremium,
            'color': sub.color,
          },
          'cards': subCards.map((c) => _cardToMap(c)).toList(),
        });
      }

      decksData.add({
        'metadata': {
          'title': deck.title,
          'source_lang': deck.sourceLang,
          'target_lang': deck.targetLang,
          'is_premium': deck.isPremium,
          'color': deck.color,
        },
        'cards': cards.map((c) => _cardToMap(c)).toList(),
        'subdecks': subDeckMaps,
      });
    }

    final Map<String, dynamic> manifest = {
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'decks': decksData,
    };

    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('deck.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes.isEmpty) {
      throw Exception('Gagal mengompresi data deck ke format .flashdeck.');
    }

    final tempDir = await getTemporaryDirectory();
    final exportFile = File(
      '${tempDir.path}/semua_deck_${DateTime.now().millisecondsSinceEpoch}.flashdeck',
    );
    await exportFile.writeAsBytes(zipBytes);

    if (share) {
      await _shareFile(exportFile, 'Semua Deck');
    }

    return exportFile;
  }

  /// Mencadangkan seluruh data (semua deck, subdeck, kartu, riwayat belajar, dan file media) ke satu file zip.
  /// Jika [share] bernilai `true`, file akan dibagikan via `share_plus`.
  Future<File> backupAllDataZip({bool share = true}) async {
    final archive = Archive();
    final Set<String> addedMediaPaths = {};

    Future<void> addMediaIfValid(String? relativePath) async {
      if (relativePath == null || relativePath.trim().isEmpty) return;
      if (addedMediaPaths.contains(relativePath)) return;

      final absPath = await _mediaService.resolveAbsolutePath(relativePath);
      final file = File(absPath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        addedMediaPaths.add(relativePath);
      }
    }

    List<Map<String, dynamic>> decksData = [];
    List<Map<String, dynamic>> cardsData = [];
    List<Map<String, dynamic>> studyLogsData = [];

    if (_db != null) {
      final allDecks = await _db.select(_db.decks).get();
      final allCards = await _db.select(_db.cards).get();
      final allLogs = await _db.select(_db.studyLogs).get();

      decksData = allDecks.map((d) => {
            'id': d.id,
            'title': d.title,
            'parent_id': d.parentId,
            'source_lang': d.sourceLang,
            'target_lang': d.targetLang,
            'is_premium': d.isPremium,
            'color': d.color,
            'created_at': d.createdAt.toIso8601String(),
            'updated_at': d.updatedAt.toIso8601String(),
            'deleted_at': d.deletedAt?.toIso8601String(),
          }).toList();

      for (final card in allCards) {
        await addMediaIfValid(card.frontAudioPath);
        await addMediaIfValid(card.backAudioPath);
        await addMediaIfValid(card.frontImagePath);
        await addMediaIfValid(card.backImagePath);

        cardsData.add({
          'id': card.id,
          'deck_id': card.deckId,
          'front_text': card.frontText,
          'back_text': card.backText,
          'front_audio_path': card.frontAudioPath,
          'back_audio_path': card.backAudioPath,
          'front_image_path': card.frontImagePath,
          'back_image_path': card.backImagePath,
          'difficulty': card.difficulty,
          'next_review_at': card.nextReviewAt?.toIso8601String(),
          'ease': card.ease,
          'interval_days': card.intervalDays,
          'created_at': card.createdAt.toIso8601String(),
          'updated_at': card.updatedAt.toIso8601String(),
          'deleted_at': card.deletedAt?.toIso8601String(),
        });
      }

      studyLogsData = allLogs.map((l) => {
            'id': l.id,
            'card_id': l.cardId,
            'deck_id': l.deckId,
            'rating': l.rating,
            'is_quiz': l.isQuiz,
            'is_correct': l.isCorrect,
            'created_at': l.createdAt.toIso8601String(),
          }).toList();
    } else {
      final allRoot = await _deckRepository.getRootDecks();
      for (final root in allRoot) {
        decksData.add({
          'id': root.id,
          'title': root.title,
          'parent_id': root.parentId,
          'source_lang': root.sourceLang,
          'target_lang': root.targetLang,
          'is_premium': root.isPremium,
          'color': root.color,
          'created_at': root.createdAt.toIso8601String(),
          'updated_at': root.updatedAt.toIso8601String(),
          'deleted_at': root.deletedAt?.toIso8601String(),
        });

        final cards = await _cardRepository.getCardsByDeck(root.id);
        for (final c in cards) {
          await addMediaIfValid(c.frontAudioPath);
          await addMediaIfValid(c.backAudioPath);
          await addMediaIfValid(c.frontImagePath);
          await addMediaIfValid(c.backImagePath);
          cardsData.add({
            'id': c.id,
            'deck_id': c.deckId,
            'front_text': c.frontText,
            'back_text': c.backText,
            'front_audio_path': c.frontAudioPath,
            'back_audio_path': c.backAudioPath,
            'front_image_path': c.frontImagePath,
            'back_image_path': c.backImagePath,
            'difficulty': c.difficulty,
            'next_review_at': c.nextReviewAt?.toIso8601String(),
            'ease': c.ease,
            'interval_days': c.intervalDays,
            'created_at': c.createdAt.toIso8601String(),
            'updated_at': c.updatedAt.toIso8601String(),
            'deleted_at': c.deletedAt?.toIso8601String(),
          });
        }

        final subDecks = await _deckRepository.getSubDecks(root.id);
        for (final sub in subDecks) {
          decksData.add({
            'id': sub.id,
            'title': sub.title,
            'parent_id': sub.parentId,
            'source_lang': sub.sourceLang,
            'target_lang': sub.targetLang,
            'is_premium': sub.isPremium,
            'color': sub.color,
            'created_at': sub.createdAt.toIso8601String(),
            'updated_at': sub.updatedAt.toIso8601String(),
            'deleted_at': sub.deletedAt?.toIso8601String(),
          });

          final subCards = await _cardRepository.getCardsByDeck(sub.id);
          for (final sc in subCards) {
            await addMediaIfValid(sc.frontAudioPath);
            await addMediaIfValid(sc.backAudioPath);
            await addMediaIfValid(sc.frontImagePath);
            await addMediaIfValid(sc.backImagePath);
            cardsData.add({
              'id': sc.id,
              'deck_id': sc.deckId,
              'front_text': sc.frontText,
              'back_text': sc.backText,
              'front_audio_path': sc.frontAudioPath,
              'back_audio_path': sc.backAudioPath,
              'front_image_path': sc.frontImagePath,
              'back_image_path': sc.backImagePath,
              'difficulty': sc.difficulty,
              'next_review_at': sc.nextReviewAt?.toIso8601String(),
              'ease': sc.ease,
              'interval_days': sc.intervalDays,
              'created_at': sc.createdAt.toIso8601String(),
              'updated_at': sc.updatedAt.toIso8601String(),
              'deleted_at': sc.deletedAt?.toIso8601String(),
            });
          }
        }
      }
    }

    final Map<String, dynamic> manifest = {
      'version': 1,
      'type': 'full_backup',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'decks': decksData,
      'cards': cardsData,
      'study_logs': studyLogsData,
    };

    final jsonBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes.isEmpty) {
      throw Exception('Gagal mengompresi cadangan data ke format zip.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportFile = File('${tempDir.path}/flashcard_backup_$timestamp.zip');
    await exportFile.writeAsBytes(zipBytes);

    if (share) {
      await _shareFile(exportFile, 'Cadangan Seluruh Data Flashcard');
    }

    return exportFile;
  }

  Future<void> _shareFile(File file, String title) async {
    if (_shareHandler != null) {
      await _shareHandler(file, title);
      return;
    }

    try {
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Flashdeck: $title',
        text: 'Paket Flashcard Deck: $title',
      );
    } catch (e) {
      debugPrint('Share error (kemungkinan platform tidak mendukung share): $e');
    }
  }

  Map<String, dynamic> _cardToMap(Card card) {
    return {
      'front_text': card.frontText,
      'back_text': card.backText,
      'front_audio_path': card.frontAudioPath,
      'back_audio_path': card.backAudioPath,
      'front_image_path': card.frontImagePath,
      'back_image_path': card.backImagePath,
      'difficulty': card.difficulty,
      'ease': card.ease,
      'interval_days': card.intervalDays,
    };
  }
}
