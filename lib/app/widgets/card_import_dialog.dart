import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/database/app_database.dart' show Deck;
import '../data/repositories/deck_repository.dart';
import '../data/services/import_service.dart';

class CardImportHelper {
  /// Membuka bottom sheet pilihan sumber impor: CSV atau Teks Tempel
  static Future<void> showImportOptionsModal(
    BuildContext context, {
    Deck? targetDeck,
    VoidCallback? onImportSuccess,
  }) async {
    final importService = Get.find<ImportService>();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impor Kartu ke Deck',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (targetDeck != null)
                        Text(
                          'Target: ${targetDeck.title}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1F2196F3),
                    child: Icon(Icons.table_chart_outlined, color: Colors.blue),
                  ),
                  title: const Text('Impor dari Berkas CSV (.csv)'),
                  subtitle: const Text('Format kolom: depan, belakang'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final cards = await importService.pickAndParseCsvFile();
                      if (cards != null && cards.isNotEmpty) {
                        if (context.mounted) {
                          showPreviewModal(
                            context,
                            targetDeck: targetDeck,
                            initialCards: cards,
                            onImportSuccess: onImportSuccess,
                          );
                        }
                      } else if (cards != null && cards.isEmpty) {
                        Get.snackbar(
                          'Berkas Kosong',
                          'Tidak ada data kartu yang ditemukan dalam berkas CSV.',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    } catch (e) {
                      Get.snackbar(
                        'Gagal Membaca CSV',
                        e.toString().replaceAll('Exception: ', ''),
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red.shade700,
                        colorText: Colors.white,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1F4CAF50),
                    child: Icon(Icons.content_paste, color: Colors.green),
                  ),
                  title: const Text('Impor dari Teks Tempel'),
                  subtitle: const Text('Format satu baris = depan;belakang'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showPasteTextInputDialog(
                      context,
                      targetDeck: targetDeck,
                      onImportSuccess: onImportSuccess,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog input teks tempel
  static Future<void> showPasteTextInputDialog(
    BuildContext context, {
    Deck? targetDeck,
    VoidCallback? onImportSuccess,
  }) async {
    final textController = TextEditingController();
    final importService = Get.find<ImportService>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Tempel Teks Kartu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan satu baris untuk tiap kartu dengan pemisah titik koma (;):\nFormat: depan;belakang',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: 'Contoh:\napple;apel\nbook;buku\nrun;berlari',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.preview_outlined, size: 18),
              label: const Text('Lihat Pratinjau'),
              onPressed: () {
                final text = textController.text.trim();
                if (text.isEmpty) {
                  Get.snackbar(
                    'Teks Kosong',
                    'Silakan tempel teks kartu terlebih dahulu.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                final cards = importService.parsePastedText(text);
                if (cards.isEmpty) {
                  Get.snackbar(
                    'Tidak Ada Kartu',
                    'Format tidak dikenali. Pastikan menggunakan format: depan;belakang',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                showPreviewModal(
                  context,
                  targetDeck: targetDeck,
                  initialCards: cards,
                  onImportSuccess: onImportSuccess,
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// Modal Pratinjau Sebelum Disimpan
  static Future<void> showPreviewModal(
    BuildContext context, {
    Deck? targetDeck,
    required List<ParsedImportCard> initialCards,
    VoidCallback? onImportSuccess,
  }) async {
    final importService = Get.find<ImportService>();
    final deckRepo = Get.find<DeckRepository>();

    List<Deck> availableDecks = [];
    if (targetDeck == null) {
      try {
        availableDecks = await deckRepo.getAllDecks();
      } catch (_) {}
    }

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return _CardImportPreviewSheet(
          targetDeck: targetDeck,
          availableDecks: availableDecks,
          initialCards: initialCards,
          importService: importService,
          onImportSuccess: onImportSuccess,
        );
      },
    );
  }
}

class _CardImportPreviewSheet extends StatefulWidget {
  final Deck? targetDeck;
  final List<Deck> availableDecks;
  final List<ParsedImportCard> initialCards;
  final ImportService importService;
  final VoidCallback? onImportSuccess;

  const _CardImportPreviewSheet({
    required this.targetDeck,
    required this.availableDecks,
    required this.initialCards,
    required this.importService,
    this.onImportSuccess,
  });

  @override
  State<_CardImportPreviewSheet> createState() =>
      _CardImportPreviewSheetState();
}

class _CardImportPreviewSheetState extends State<_CardImportPreviewSheet> {
  late List<ParsedImportCard> cards;
  int? selectedDeckId;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    cards = List.from(widget.initialCards);
    if (widget.targetDeck != null) {
      selectedDeckId = widget.targetDeck!.id;
    } else if (widget.availableDecks.isNotEmpty) {
      selectedDeckId = widget.availableDecks.first.id;
    }
  }

  int get validCount => cards.where((c) => c.isValid).length;
  int get invalidCount => cards.where((c) => !c.isValid).length;

  Future<void> _handleSave() async {
    if (selectedDeckId == null) {
      Get.snackbar(
        'Pilih Deck',
        'Silakan tentukan deck tujuan untuk menyimpan kartu.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final validCards = cards.where((c) => c.isValid).toList();
    if (validCards.isEmpty) {
      Get.snackbar(
        'Tidak Ada Kartu Valid',
        'Tidak ada kartu valid untuk disimpan.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final savedCount = await widget.importService.saveCardsToDeck(
        deckId: selectedDeckId!,
        cards: validCards,
      );

      if (mounted) {
        Navigator.pop(context);
      }

      Get.showSnackbar(
        GetSnackBar(
          title: 'Impor Berhasil',
          message: '$savedCount kartu berhasil disimpan ke deck.',
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green.shade700,
          snackPosition: SnackPosition.BOTTOM,
        ),
      );

      widget.onImportSuccess?.call();
    } catch (e) {
      Get.snackbar(
        'Gagal Menyimpan Kartu',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pratinjau Impor Kartu',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$validCount kartu siap diimpor${invalidCount > 0 ? ' ($invalidCount baris tidak valid)' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Pilihan Target Deck jika belum spesifik
          if (widget.targetDeck == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: DropdownButtonFormField<int>(
                initialValue: selectedDeckId,
                decoration: const InputDecoration(
                  labelText: 'Simpan ke Deck',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: widget.availableDecks
                    .map(
                      (d) => DropdownMenuItem<int>(
                        value: d.id,
                        child: Text(d.title),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedDeckId = val);
                },
              ),
            ),

          if (invalidCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$invalidCount baris memiliki format tidak sesuai dan akan dilewati.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Daftar Kartu
          Expanded(
            child: cards.isEmpty
                ? const Center(child: Text('Tidak ada kartu untuk ditampilkan.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (ctx, idx) {
                      final item = cards[idx];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: item.isValid
                                ? Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withAlpha(120)
                                : Colors.red.withAlpha(120),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: item.isValid
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                : Colors.red.withAlpha(30),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isValid
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.red,
                              ),
                            ),
                          ),
                          title: Text(
                            item.frontText.isEmpty
                                ? '(Sisi depan kosong)'
                                : item.frontText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.frontText.isEmpty
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.backText.isEmpty
                                    ? '(Sisi belakang kosong)'
                                    : item.backText,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              if (!item.isValid && item.errorReason != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    item.errorReason!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.grey,
                            ),
                            tooltip: 'Hapus dari daftar impor',
                            onPressed: () {
                              setState(() {
                                cards.removeAt(idx);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      isSaving
                          ? 'Menyimpan...'
                          : 'Simpan ke Deck ($validCount)',
                    ),
                    onPressed: isSaving || validCount == 0 ? null : _handleSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
