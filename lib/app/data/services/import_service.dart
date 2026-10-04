import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../repositories/card_repository.dart';
import '../repositories/deck_repository.dart';
import 'media_service.dart';

class ImportException implements Exception {
  final String message;
  ImportException(this.message);

  @override
  String toString() => message;
}

class ParsedImportCard {
  String frontText;
  String backText;
  bool isValid;
  String? errorReason;

  ParsedImportCard({
    required this.frontText,
    required this.backText,
    this.isValid = true,
    this.errorReason,
  });

  Map<String, dynamic> toMap() => {
        'frontText': frontText,
        'backText': backText,
        'isValid': isValid,
        'errorReason': errorReason,
      };
}

typedef FilePickerHandler = Future<FilePickerResult?> Function();

class ImportService extends GetxService {
  static ImportService get to => Get.find<ImportService>();

  final AppDatabase _db;
  final FilePickerHandler? _filePickerHandler;

  ImportService({
    AppDatabase? database,
    DeckRepository? deckRepository,
    CardRepository? cardRepository,
    MediaService? mediaService,
    FilePickerHandler? filePickerHandler,
  })  : _db = database ?? Get.find<AppDatabase>(),
        _filePickerHandler = filePickerHandler;

  /// Memilih file `.flashdeck` via file picker lalu mengimpornya.
  /// Mengembalikan `Deck` baru yang berhasil diimpor, atau `null` jika pengguna membatalkan pemilihan.
  Future<Deck?> pickAndImportDeck() async {
    FilePickerResult? result;
    if (_filePickerHandler != null) {
      result = await _filePickerHandler();
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['flashdeck', 'zip'],
      );
    }

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;
    if (path == null) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        return importDeckFromBytes(bytes);
      }
      throw ImportException('Gagal membaca file yang dipilih.');
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw ImportException('File tidak ditemukan di penyimpanan.');
    }

    return importDeckFromFile(file);
  }

  /// Mengimpor deck dari objek `File` `.flashdeck`.
  Future<Deck> importDeckFromFile(File file) async {
    if (!file.existsSync()) {
      throw ImportException('File .flashdeck tidak ditemukan.');
    }
    final bytes = await file.readAsBytes();
    return importDeckFromBytes(bytes);
  }

  /// Mengimpor deck dari raw bytes arsip `.flashdeck`.
  Future<Deck> importDeckFromBytes(List<int> bytes) async {
    // 1. Validasi arsip ZIP
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
      if (archive.isEmpty) {
        throw ImportException(
          'File rusak atau bukan format .flashdeck yang valid.',
        );
      }
    } catch (e) {
      if (e is ImportException) rethrow;
      throw ImportException(
        'File rusak atau bukan format .flashdeck yang valid.',
      );
    }

    // 2. Validasi keberadaan deck.json
    final jsonFile = archive.findFile('deck.json');
    if (jsonFile == null) {
      throw ImportException(
        'Struktur file tidak valid: berkas deck.json tidak ditemukan.',
      );
    }

    // 3. Validasi isi deck.json
    Map<String, dynamic> manifest;
    try {
      final content = utf8.decode(jsonFile.content as List<int>);
      manifest = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw ImportException(
        'File rusak: berkas deck.json tidak dapat dibaca.',
      );
    }

    // 4. Validasi versi
    final version = manifest['version'];
    if (version == null) {
      throw ImportException(
        'Struktur file tidak valid: informasi versi tidak ditemukan.',
      );
    }
    if (version is! int || version != 1) {
      throw ImportException(
        'Versi file tidak didukung: $version. Aplikasi saat ini hanya mendukung versi 1.',
      );
    }

    // 5. Validasi metadata deck utama atau multi-deck
    final rawDecks = manifest['decks'];
    final bool isMultiDeck = rawDecks is List && rawDecks.isNotEmpty;

    final metadata =
        isMultiDeck ? null : (manifest['metadata'] ?? manifest['deck']);
    if (!isMultiDeck) {
      if (metadata == null || metadata is! Map<String, dynamic>) {
        throw ImportException(
          'Struktur file tidak valid: metadata deck tidak ditemukan.',
        );
      }
      final title = metadata['title'] as String?;
      if (title == null || title.trim().isEmpty) {
        throw ImportException(
          'Struktur file tidak valid: nama judul deck tidak ditemukan.',
        );
      }
    }

    // 6. Ekstraksi file media ke folder aplikasi
    final appDir = await getApplicationDocumentsDirectory();
    final List<File> createdFiles = [];
    final Map<String, String> remappedMedia = {};

    try {
      for (final file in archive) {
        if (!file.isFile || file.name == 'deck.json') continue;

        final relativeZipPath = file.name;
        String targetRelativePath = relativeZipPath;
        File targetFile = File(p.join(appDir.path, targetRelativePath));

        // Hindari menimpa media lain yang sudah ada dengan nama yang sama
        if (targetFile.existsSync()) {
          final ext = p.extension(relativeZipPath);
          final base = p.basenameWithoutExtension(relativeZipPath);
          final dir = p.dirname(relativeZipPath);
          final uniqueName =
              '${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
          targetRelativePath = p.join(dir, uniqueName).replaceAll(r'\', '/');
          targetFile = File(p.join(appDir.path, targetRelativePath));
        }

        targetFile.parent.createSync(recursive: true);
        await targetFile.writeAsBytes(file.content as List<int>);
        createdFiles.add(targetFile);
        remappedMedia[relativeZipPath] = targetRelativePath;
      }
    } catch (e) {
      _cleanupFiles(createdFiles);
      throw ImportException('Gagal mengekstrak media dari paket deck: $e');
    }

    // 7. Simpan ke database menggunakan transaksi (mencegah data setengah jadi)
    try {
      final createdDeck = await _db.transaction<Deck>(() async {
        if (isMultiDeck) {
          Deck? firstDeck;
          for (final deckItem in rawDecks) {
            if (deckItem is! Map<String, dynamic>) continue;
            final deckMeta = deckItem['metadata'] ?? deckItem['deck'] ?? {};
            final deckTitle =
                (deckMeta['title'] as String? ?? 'Deck Impor').trim();

            final rootDeckId = await _db.into(_db.decks).insert(
              DecksCompanion.insert(
                title: deckTitle.isEmpty ? 'Deck Impor' : deckTitle,
                sourceLang: Value(deckMeta['source_lang'] as String? ?? 'id'),
                targetLang: Value(deckMeta['target_lang'] as String? ?? 'en'),
                isPremium: Value(deckMeta['is_premium'] as bool? ?? false),
                color: Value(deckMeta['color'] as int?),
              ),
            );

            final rawCards = deckItem['cards'];
            if (rawCards is List && rawCards.isNotEmpty) {
              await _insertCardsBatch(rootDeckId, rawCards, remappedMedia);
            }

            final rawSubdecks = deckItem['subdecks'];
            if (rawSubdecks is List) {
              for (final subItem in rawSubdecks) {
                if (subItem is Map<String, dynamic>) {
                  final subMeta = subItem['metadata'] ?? subItem['deck'] ?? {};
                  final subTitle =
                      (subMeta['title'] as String? ?? 'Subdeck').trim();
                  final subDeckId = await _db.into(_db.decks).insert(
                    DecksCompanion.insert(
                      title: subTitle.isEmpty ? 'Subdeck' : subTitle,
                      parentId: Value(rootDeckId),
                      sourceLang:
                          Value(subMeta['source_lang'] as String? ?? 'id'),
                      targetLang:
                          Value(subMeta['target_lang'] as String? ?? 'en'),
                      isPremium: Value(subMeta['is_premium'] as bool? ?? false),
                      color: Value(subMeta['color'] as int?),
                    ),
                  );

                  final subCards = subItem['cards'];
                  if (subCards is List && subCards.isNotEmpty) {
                    await _insertCardsBatch(subDeckId, subCards, remappedMedia);
                  }
                }
              }
            }

            firstDeck ??= await (_db.select(_db.decks)
                  ..where((t) => t.id.equals(rootDeckId)))
                .getSingle();
          }
          return firstDeck ?? (await _db.select(_db.decks).get()).first;
        }

        // Single deck import
        final title = (metadata!['title'] as String).trim();
        final rootDeckId = await _db.into(_db.decks).insert(
          DecksCompanion.insert(
            title: title,
            sourceLang: Value(metadata['source_lang'] as String? ?? 'id'),
            targetLang: Value(metadata['target_lang'] as String? ?? 'en'),
            isPremium: Value(metadata['is_premium'] as bool? ?? false),
            color: Value(metadata['color'] as int?),
          ),
        );

        // B. Insert kartu-kartu deck utama (Batch)
        final rawCards = manifest['cards'];
        if (rawCards is List && rawCards.isNotEmpty) {
          await _insertCardsBatch(rootDeckId, rawCards, remappedMedia);
        }

        // C. Insert subdeck dan kartu-kartunya jika ada
        final rawSubdecks = manifest['subdecks'];
        if (rawSubdecks is List) {
          for (final subItem in rawSubdecks) {
            if (subItem is Map<String, dynamic>) {
              final subMeta = subItem['metadata'] ?? subItem['deck'] ?? {};
              final subTitle = subMeta['title'] as String? ?? 'Subdeck';
              final subDeckId = await _db.into(_db.decks).insert(
                DecksCompanion.insert(
                  title: subTitle.trim(),
                  parentId: Value(rootDeckId),
                  sourceLang: Value(subMeta['source_lang'] as String? ?? 'id'),
                  targetLang: Value(subMeta['target_lang'] as String? ?? 'en'),
                  isPremium: Value(subMeta['is_premium'] as bool? ?? false),
                  color: Value(subMeta['color'] as int?),
                ),
              );

              final subCards = subItem['cards'];
              if (subCards is List && subCards.isNotEmpty) {
                await _insertCardsBatch(subDeckId, subCards, remappedMedia);
              }
            }
          }
        }

        return (await (_db.select(_db.decks)
              ..where((t) => t.id.equals(rootDeckId)))
            .getSingle());
      });

      return createdDeck;
    } catch (e) {
      // Hapus media yang baru saja diekstrak jika transaksi database gagal
      _cleanupFiles(createdFiles);
      if (e is ImportException) rethrow;
      throw ImportException('Gagal menyimpan deck ke basis data: $e');
    }
  }

  Future<void> _insertCardsBatch(
    int deckId,
    List<dynamic> items,
    Map<String, String> remappedMedia,
  ) async {
    String? remap(String? original) {
      if (original == null || original.isEmpty) return null;
      return remappedMedia[original] ?? original;
    }

    final companions = <CardsCompanion>[];
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        companions.add(
          CardsCompanion.insert(
            deckId: deckId,
            frontText: item['front_text'] as String? ?? '',
            backText: item['back_text'] as String? ?? '',
            frontAudioPath: Value(remap(item['front_audio_path'] as String?)),
            backAudioPath: Value(remap(item['back_audio_path'] as String?)),
            frontImagePath: Value(remap(item['front_image_path'] as String?)),
            backImagePath: Value(remap(item['back_image_path'] as String?)),
            difficulty: Value((item['difficulty'] as num?)?.toInt() ?? 0),
            ease: Value((item['ease'] as num?)?.toDouble() ?? 2.5),
            intervalDays: Value((item['interval_days'] as num?)?.toInt() ?? 0),
          ),
        );
      }
    }

    if (companions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAll(_db.cards, companions);
      });
    }
  }


  void _cleanupFiles(List<File> files) {
    for (final file in files) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e) {
          debugPrint('Gagal menghapus file media ekstraksi: $e');
        }
      }
    }
  }

  /// Membaca teks tempel (format satu baris: depan;belakang)
  List<ParsedImportCard> parsePastedText(String rawText) {
    final lines = rawText.split(RegExp(r'\r\n|\r|\n'));
    final results = <ParsedImportCard>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final semicolonIdx = line.indexOf(';');
      if (semicolonIdx != -1) {
        final front = line.substring(0, semicolonIdx).trim();
        final back = line.substring(semicolonIdx + 1).trim();

        if (front.isEmpty && back.isEmpty) {
          results.add(
            ParsedImportCard(
              frontText: '',
              backText: '',
              isValid: false,
              errorReason: 'Baris ${i + 1}: Teks depan dan belakang kosong',
            ),
          );
        } else {
          results.add(
            ParsedImportCard(
              frontText: front,
              backText: back,
              isValid: true,
            ),
          );
        }
      } else {
        // Tidak ada pemisah titik koma
        results.add(
          ParsedImportCard(
            frontText: line,
            backText: '',
            isValid: false,
            errorReason:
                'Baris ${i + 1}: Format tidak sesuai (harus: depan;belakang)',
          ),
        );
      }
    }
    return results;
  }

  /// Mem-parsing konten CSV (kolom: depan, belakang)
  List<ParsedImportCard> parseCsvText(String rawCsv) {
    if (rawCsv.trim().isEmpty) return [];

    final rawRows = _parseCsvRows(rawCsv);
    if (rawRows.isEmpty) return [];

    final results = <ParsedImportCard>[];
    int startIndex = 0;

    // Periksa apakah baris pertama merupakan header (mis. depan,belakang / front,back)
    if (_isHeaderRow(rawRows.first)) {
      startIndex = 1;
    }

    for (int i = startIndex; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.isEmpty || (row.length == 1 && row.first.trim().isEmpty)) {
        continue;
      }

      if (row.length >= 2) {
        final front = row[0].trim();
        final back = row[1].trim();
        if (front.isEmpty && back.isEmpty) {
          results.add(
            ParsedImportCard(
              frontText: '',
              backText: '',
              isValid: false,
              errorReason: 'Baris ${i + 1}: Teks kosong',
            ),
          );
        } else {
          results.add(
            ParsedImportCard(
              frontText: front,
              backText: back,
              isValid: true,
            ),
          );
        }
      } else if (row.length == 1) {
        final single = row.first.trim();
        if (single.contains(';')) {
          final parts = single.split(';');
          final front = parts.first.trim();
          final back = parts.sublist(1).join(';').trim();
          results.add(
            ParsedImportCard(
              frontText: front,
              backText: back,
              isValid: front.isNotEmpty || back.isNotEmpty,
            ),
          );
        } else {
          results.add(
            ParsedImportCard(
              frontText: single,
              backText: '',
              isValid: false,
              errorReason: 'Baris ${i + 1}: Hanya 1 kolom terdeteksi',
            ),
          );
        }
      }
    }
    return results;
  }

  bool _isHeaderRow(List<String> row) {
    if (row.length < 2) return false;
    final f = row[0].toLowerCase().trim();
    final b = row[1].toLowerCase().trim();
    const frontAliases = {
      'depan',
      'front',
      'sisi depan',
      'term',
      'kata',
      'word',
      'pertanyaan',
      'question',
    };
    const backAliases = {
      'belakang',
      'back',
      'sisi belakang',
      'arti',
      'definition',
      'terjemahan',
      'jawaban',
      'meaning',
      'answer',
    };
    return frontAliases.contains(f) && backAliases.contains(b);
  }

  List<List<String>> _parseCsvRows(String input) {
    final rows = <List<String>>[];
    if (input.trim().isEmpty) return rows;

    // Deteksi pemisah default (, atau ;) berdasarkan baris pertama non-kosong
    final lines = input.split(RegExp(r'\r\n|\r|\n'));
    final firstLine =
        lines.firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    int commaCount = 0;
    int semicolonCount = 0;
    bool inQuoteScan = false;
    for (int c = 0; c < firstLine.length; c++) {
      if (firstLine[c] == '"') {
        inQuoteScan = !inQuoteScan;
      } else if (!inQuoteScan) {
        if (firstLine[c] == ',') commaCount++;
        if (firstLine[c] == ';') semicolonCount++;
      }
    }
    final delimiter = semicolonCount > commaCount ? ';' : ',';

    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool insideQuote = false;

    int i = 0;
    while (i < input.length) {
      final char = input[i];

      if (insideQuote) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            insideQuote = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          insideQuote = true;
          i++;
          continue;
        } else if (char == delimiter) {
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r' || char == '\n') {
          if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString().trim());
          currentField.clear();
          if (currentRow.any((element) => element.isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    currentRow.add(currentField.toString().trim());
    if (currentRow.any((element) => element.isNotEmpty)) {
      rows.add(List.from(currentRow));
    }

    return rows;
  }

  /// Memilih file CSV via FilePicker dan mengembalikan daftar kartu hasil parsing
  Future<List<ParsedImportCard>?> pickAndParseCsvFile() async {
    FilePickerResult? result;
    if (_filePickerHandler != null) {
      result = await _filePickerHandler();
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
    }

    if (result == null || result.files.isEmpty) {
      return null;
    }

    String content = '';
    final path = result.files.single.path;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          content = await file.readAsString(encoding: utf8);
        } catch (_) {
          content = await file.readAsString(encoding: latin1);
        }
      }
    } else if (result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      try {
        content = utf8.decode(bytes);
      } catch (_) {
        content = latin1.decode(bytes);
      }
    }

    if (content.trim().isEmpty) {
      throw ImportException('Berkas CSV kosong atau tidak dapat dibaca.');
    }

    return parseCsvText(content);
  }

  /// Menyimpan kartu yang diimpor ke deck tertentu
  Future<int> saveCardsToDeck({
    required int deckId,
    required List<ParsedImportCard> cards,
  }) async {
    final validCards = cards
        .where(
          (c) =>
              c.isValid &&
              (c.frontText.isNotEmpty || c.backText.isNotEmpty),
        )
        .toList();
    if (validCards.isEmpty) return 0;

    final companions = validCards
        .map(
          (c) => CardsCompanion.insert(
            deckId: deckId,
            frontText: c.frontText,
            backText: c.backText,
          ),
        )
        .toList();

    await _db.batch((batch) {
      batch.insertAll(_db.cards, companions);
    });

    return validCards.length;
  }

  /// Memilih file zip cadangan melalui FilePicker lalu memulihkan seluruh data.
  /// Jika [replaceExisting] bernilai `true`, data yang ada saat ini akan digantikan.
  /// Mengembalikan jumlah deck yang berhasil dipulihkan, atau `null` jika pengguna membatalkan pilihan.
  Future<int?> pickAndRestoreZip({bool replaceExisting = false}) async {
    FilePickerResult? result;
    if (_filePickerHandler != null) {
      result = await _filePickerHandler();
    } else {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'flashdeck'],
      );
    }

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;
    if (path == null) {
      final bytes = result.files.single.bytes;
      if (bytes != null) {
        return restoreAllDataFromBytes(bytes,
            replaceExisting: replaceExisting);
      }
      throw ImportException('Gagal membaca file cadangan yang dipilih.');
    }

    final file = File(path);
    if (!file.existsSync()) {
      throw ImportException('File cadangan tidak ditemukan di penyimpanan.');
    }

    return restoreAllDataFromFile(file, replaceExisting: replaceExisting);
  }

  /// Memulihkan seluruh data dari berkas zip cadangan.
  Future<int> restoreAllDataFromFile(
    File file, {
    bool replaceExisting = false,
  }) async {
    if (!file.existsSync()) {
      throw ImportException('File cadangan zip tidak ditemukan.');
    }
    final bytes = await file.readAsBytes();
    return restoreAllDataFromBytes(bytes, replaceExisting: replaceExisting);
  }

  /// Memulihkan seluruh data (deck, kartu, riwayat belajar, dan file media) dari byte zip.
  Future<int> restoreAllDataFromBytes(
    List<int> bytes, {
    bool replaceExisting = false,
  }) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
      if (archive.isEmpty) {
        throw ImportException(
          'File rusak atau bukan format cadangan zip yang valid.',
        );
      }
    } catch (e) {
      if (e is ImportException) rethrow;
      throw ImportException(
        'File rusak atau bukan format cadangan zip yang valid.',
      );
    }

    final backupEntry = archive.findFile('backup.json');
    final deckEntry = archive.findFile('deck.json');
    if (backupEntry == null && deckEntry == null) {
      throw ImportException(
        'Struktur file cadangan tidak valid: berkas backup.json atau deck.json tidak ditemukan.',
      );
    }

    Map<String, dynamic> manifest;
    try {
      final targetFile = backupEntry ?? deckEntry!;
      final content = utf8.decode(targetFile.content as List<int>);
      manifest = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw ImportException(
        'File rusak: berkas manifest cadangan tidak dapat dibaca.',
      );
    }

    final version = manifest['version'];
    if (version == null || version is! int || version != 1) {
      throw ImportException(
        'Versi file cadangan tidak didukung: $version. Aplikasi saat ini hanya mendukung versi 1.',
      );
    }

    final List<Map<String, dynamic>> rawDecks = [];
    final List<Map<String, dynamic>> rawCards = [];
    final List<Map<String, dynamic>> rawLogs = [];

    if (manifest['type'] == 'full_backup') {
      final dList = manifest['decks'] as List? ?? [];
      for (final d in dList) {
        if (d is Map<String, dynamic>) rawDecks.add(d);
      }
      final cList = manifest['cards'] as List? ?? [];
      for (final c in cList) {
        if (c is Map<String, dynamic>) rawCards.add(c);
      }
      final lList = manifest['study_logs'] as List? ?? [];
      for (final l in lList) {
        if (l is Map<String, dynamic>) rawLogs.add(l);
      }
    } else if (manifest['decks'] != null && manifest['decks'] is List) {
      int pseudoDeckId = 1;
      int pseudoCardId = 1;
      for (final deckItem in manifest['decks']) {
        if (deckItem is! Map<String, dynamic>) continue;
        final dId = pseudoDeckId++;
        final meta = deckItem['metadata'] ?? deckItem['deck'] ?? {};
        rawDecks.add({
          'id': dId,
          'title': meta['title'] ?? 'Deck',
          'source_lang': meta['source_lang'] ?? 'id',
          'target_lang': meta['target_lang'] ?? 'en',
          'is_premium': meta['is_premium'] ?? false,
          'color': meta['color'],
        });
        if (deckItem['cards'] is List) {
          for (final c in deckItem['cards']) {
            if (c is Map) {
              rawCards.add({
                'id': pseudoCardId++,
                'deck_id': dId,
                ...Map<String, dynamic>.from(c),
              });
            }
          }
        }
        if (deckItem['subdecks'] is List) {
          for (final s in deckItem['subdecks']) {
            if (s is! Map<String, dynamic>) continue;
            final sId = pseudoDeckId++;
            final sMeta = s['metadata'] ?? s['deck'] ?? {};
            rawDecks.add({
              'id': sId,
              'parent_id': dId,
              'title': sMeta['title'] ?? 'Subdeck',
              'source_lang': sMeta['source_lang'] ?? 'id',
              'target_lang': sMeta['target_lang'] ?? 'en',
              'is_premium': sMeta['is_premium'] ?? false,
              'color': sMeta['color'],
            });
            if (s['cards'] is List) {
              for (final sc in s['cards']) {
                if (sc is Map) {
                  rawCards.add({
                    'id': pseudoCardId++,
                    'deck_id': sId,
                    ...Map<String, dynamic>.from(sc),
                  });
                }
              }
            }
          }
        }
      }
    } else if (manifest['metadata'] != null || manifest['deck'] != null) {
      final meta = manifest['metadata'] ?? manifest['deck'] ?? {};
      const int dId = 1;
      int pseudoCardId = 1;
      rawDecks.add({
        'id': dId,
        'title': meta['title'] ?? 'Deck',
        'source_lang': meta['source_lang'] ?? 'id',
        'target_lang': meta['target_lang'] ?? 'en',
        'is_premium': meta['is_premium'] ?? false,
        'color': meta['color'],
      });
      if (manifest['cards'] is List) {
        for (final c in manifest['cards']) {
          if (c is Map) {
            rawCards.add({
              'id': pseudoCardId++,
              'deck_id': dId,
              ...Map<String, dynamic>.from(c),
            });
          }
        }
      }
      if (manifest['subdecks'] is List) {
        int pseudoSubId = 2;
        for (final s in manifest['subdecks']) {
          if (s is! Map<String, dynamic>) continue;
          final sId = pseudoSubId++;
          final sMeta = s['metadata'] ?? s['deck'] ?? {};
          rawDecks.add({
            'id': sId,
            'parent_id': dId,
            'title': sMeta['title'] ?? 'Subdeck',
            'source_lang': sMeta['source_lang'] ?? 'id',
            'target_lang': sMeta['target_lang'] ?? 'en',
            'is_premium': sMeta['is_premium'] ?? false,
            'color': sMeta['color'],
          });
          if (s['cards'] is List) {
            for (final sc in s['cards']) {
              if (sc is Map) {
                rawCards.add({
                  'id': pseudoCardId++,
                  'deck_id': sId,
                  ...Map<String, dynamic>.from(sc),
                });
              }
            }
          }
        }
      }
    }

    // Ekstraksi berkas media
    final appDir = await getApplicationDocumentsDirectory();
    final List<File> createdFiles = [];
    try {
      for (final file in archive) {
        if (!file.isFile ||
            file.name == 'backup.json' ||
            file.name == 'deck.json') {
          continue;
        }
        final targetFile = File(p.join(appDir.path, file.name));
        targetFile.parent.createSync(recursive: true);
        await targetFile.writeAsBytes(file.content as List<int>);
        createdFiles.add(targetFile);
      }
    } catch (e) {
      _cleanupFiles(createdFiles);
      throw ImportException('Gagal mengekstrak berkas media cadangan: $e');
    }

    // Transaksi database pemulihan data
    try {
      final restoredCount = await _db.transaction<int>(() async {
        if (replaceExisting) {
          await _db.delete(_db.studyLogs).go();
          await _db.delete(_db.cards).go();
          await _db.delete(_db.decks).go();
        }

        final oldDeckIdToNewDeckId = <int, int>{};
        final oldCardIdToNewCardId = <int, int>{};

        final rootDecks =
            rawDecks.where((d) => d['parent_id'] == null).toList();
        final childDecks =
            rawDecks.where((d) => d['parent_id'] != null).toList();

        for (final d in rootDecks) {
          final oldId = d['id'] as int?;
          final newId = await _db.into(_db.decks).insert(
                DecksCompanion.insert(
                  title: (d['title'] as String? ?? 'Deck').trim(),
                  sourceLang: Value(d['source_lang'] as String? ?? 'id'),
                  targetLang: Value(d['target_lang'] as String? ?? 'en'),
                  isPremium: Value(d['is_premium'] as bool? ?? false),
                  color: Value(d['color'] as int?),
                  createdAt: Value(d['created_at'] != null
                      ? DateTime.parse(d['created_at'])
                      : DateTime.now()),
                  updatedAt: Value(d['updated_at'] != null
                      ? DateTime.parse(d['updated_at'])
                      : DateTime.now()),
                  deletedAt: Value(d['deleted_at'] != null
                      ? DateTime.parse(d['deleted_at'])
                      : null),
                ),
              );
          if (oldId != null) {
            oldDeckIdToNewDeckId[oldId] = newId;
          }
        }

        for (final d in childDecks) {
          final oldId = d['id'] as int?;
          final oldParentId = d['parent_id'] as int?;
          final newParentId = oldParentId != null
              ? oldDeckIdToNewDeckId[oldParentId]
              : null;
          final newId = await _db.into(_db.decks).insert(
                DecksCompanion.insert(
                  title: (d['title'] as String? ?? 'Subdeck').trim(),
                  parentId: Value(newParentId),
                  sourceLang: Value(d['source_lang'] as String? ?? 'id'),
                  targetLang: Value(d['target_lang'] as String? ?? 'en'),
                  isPremium: Value(d['is_premium'] as bool? ?? false),
                  color: Value(d['color'] as int?),
                  createdAt: Value(d['created_at'] != null
                      ? DateTime.parse(d['created_at'])
                      : DateTime.now()),
                  updatedAt: Value(d['updated_at'] != null
                      ? DateTime.parse(d['updated_at'])
                      : DateTime.now()),
                  deletedAt: Value(d['deleted_at'] != null
                      ? DateTime.parse(d['deleted_at'])
                      : null),
                ),
              );
          if (oldId != null) {
            oldDeckIdToNewDeckId[oldId] = newId;
          }
        }

        for (final c in rawCards) {
          final oldId = c['id'] as int?;
          final oldDeckId = c['deck_id'] as int?;
          final newDeckId = oldDeckId != null
              ? oldDeckIdToNewDeckId[oldDeckId]
              : oldDeckIdToNewDeckId.values.firstOrNull;
          if (newDeckId == null) continue;

          final newCardId = await _db.into(_db.cards).insert(
                CardsCompanion.insert(
                  deckId: newDeckId,
                  frontText: c['front_text'] as String? ?? '',
                  backText: c['back_text'] as String? ?? '',
                  frontAudioPath: Value(c['front_audio_path'] as String?),
                  backAudioPath: Value(c['back_audio_path'] as String?),
                  frontImagePath: Value(c['front_image_path'] as String?),
                  backImagePath: Value(c['back_image_path'] as String?),
                  difficulty:
                      Value((c['difficulty'] as num?)?.toInt() ?? 0),
                  nextReviewAt: Value(c['next_review_at'] != null
                      ? DateTime.parse(c['next_review_at'])
                      : null),
                  ease: Value((c['ease'] as num?)?.toDouble() ?? 2.5),
                  intervalDays:
                      Value((c['interval_days'] as num?)?.toInt() ?? 0),
                  createdAt: Value(c['created_at'] != null
                      ? DateTime.parse(c['created_at'])
                      : DateTime.now()),
                  updatedAt: Value(c['updated_at'] != null
                      ? DateTime.parse(c['updated_at'])
                      : DateTime.now()),
                  deletedAt: Value(c['deleted_at'] != null
                      ? DateTime.parse(c['deleted_at'])
                      : null),
                ),
              );
          if (oldId != null) {
            oldCardIdToNewCardId[oldId] = newCardId;
          }
        }

        for (final l in rawLogs) {
          final oldCardId = l['card_id'] as int?;
          final oldDeckId = l['deck_id'] as int?;
          final newCardId = oldCardId != null
              ? oldCardIdToNewCardId[oldCardId]
              : null;
          final newDeckId = oldDeckId != null
              ? oldDeckIdToNewDeckId[oldDeckId]
              : null;
          if (newCardId != null && newDeckId != null) {
            await _db.into(_db.studyLogs).insert(
                  StudyLogsCompanion.insert(
                    cardId: newCardId,
                    deckId: newDeckId,
                    rating: Value((l['rating'] as num?)?.toInt() ?? 0),
                    isQuiz: Value(l['is_quiz'] as bool? ?? false),
                    isCorrect: Value(l['is_correct'] as bool? ?? false),
                    createdAt: Value(l['created_at'] != null
                        ? DateTime.parse(l['created_at'])
                        : DateTime.now()),
                  ),
                );
          }
        }

        return oldDeckIdToNewDeckId.length;
      });
      return restoredCount;
    } catch (e) {
      if (e is ImportException) rethrow;
      throw ImportException('Gagal memulihkan basis data dari cadangan: $e');
    }
  }
}
