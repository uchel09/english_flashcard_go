import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../data/database/app_database.dart' as db;
import '../../../data/services/audio_service.dart';
import '../../../routes/app_pages.dart';
import '../../../widgets/card_import_dialog.dart';
import '../controllers/deck_detail_controller.dart';

class DeckDetailView extends GetView<DeckDetailController> {
  const DeckDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              controller: controller.searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari kartu...',
                border: InputBorder.none,
              ),
              onChanged: controller.onSearchChanged,
            );
          }
          return Text(controller.deck.value?.title ?? 'Detail Deck');
        }),
        actions: [
          Obx(() {
            if (controller.cards.isNotEmpty) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Badge.count(
                      count: controller.dueCardCount.value,
                      isLabelVisible: controller.dueCardCount.value > 0,
                      child: const Icon(Icons.school_outlined),
                    ),
                    tooltip:
                        'Belajar Hari Ini (${controller.dueCardCount.value} jatuh tempo)',
                    onPressed: () {
                      final currentDeck = controller.deck.value;
                      if (currentDeck != null) {
                        Get.toNamed(
                          Routes.CARD_VIEWER,
                          arguments: {
                            'deck': currentDeck,
                            'isStudyMode': true,
                          },
                        )?.then((_) => controller.loadCards());
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.style_outlined),
                    tooltip: 'Penampil Kartu',
                    onPressed: () {
                      final currentDeck = controller.deck.value;
                      if (currentDeck != null) {
                        Get.toNamed(
                          Routes.CARD_VIEWER,
                          arguments: {
                            'deck': currentDeck,
                            'cards': controller.cards.toList(),
                          },
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Mulai Tes',
                    onPressed: () {
                      final currentDeck = controller.deck.value;
                      if (currentDeck != null) {
                        Get.toNamed(Routes.QUIZ, arguments: currentDeck);
                      }
                    },
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
          Obx(
            () => IconButton(
              icon: Icon(
                controller.isSearching.value ? Icons.close : Icons.search,
              ),
              tooltip: controller.isSearching.value ? 'Tutup' : 'Cari Kartu',
              onPressed: controller.toggleSearch,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Impor Kartu (CSV / Teks)',
            onPressed: () {
              final currentDeck = controller.deck.value;
              if (currentDeck != null) {
                CardImportHelper.showImportOptionsModal(
                  context,
                  targetDeck: currentDeck,
                  onImportSuccess: controller.loadCards,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tambah Kartu',
            onPressed: () => _openCardEditor(context),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.cards.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty && controller.cards.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    onPressed: controller.loadCards,
                  ),
                ],
              ),
            ),
          );
        }

        final cardsList = controller.filteredCards;
        final isFilterActive =
            controller.isSearching.value && controller.searchQuery.isNotEmpty;

        if (cardsList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFilterActive
                        ? Icons.search_off
                        : Icons.style_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFilterActive
                        ? 'Kartu Tidak Ditemukan'
                        : 'Belum Ada Kartu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFilterActive
                        ? 'Tidak ada kartu yang cocok dengan pencarian "${controller.searchQuery.value}".'
                        : 'Mulai tambahkan kartu pertama ke dalam deck ini.',
                    textAlign: TextAlign.center,
                  ),
                  if (!isFilterActive) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Kartu Pertama'),
                          onPressed: () => _openCardEditor(context),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Impor Kartu (CSV / Teks)'),
                          onPressed: () {
                            final currentDeck = controller.deck.value;
                            if (currentDeck != null) {
                              CardImportHelper.showImportOptionsModal(
                                context,
                                targetDeck: currentDeck,
                                onImportSuccess: controller.loadCards,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final dueCount = controller.dueCardCount.value;
        final showBanner = dueCount > 0 && !isFilterActive;

        return RefreshIndicator(
          onRefresh: controller.loadCards,
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: cardsList.length + (showBanner ? 1 : 0),
            itemBuilder: (context, index) {
              if (showBanner && index == 0) {
                return _buildDueBanner(context, dueCount);
              }
              final card = cardsList[showBanner ? index - 1 : index];
              return _buildCardItem(context, card);
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah Kartu',
        onPressed: () => _openCardEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, db.Card card) {
    return Obx(() {
      final isMinimized = controller.isCardMinimized(card.id);
      final isFrontExpanded = controller.isFrontTextExpanded(card.id);
      final isBackExpanded = controller.isBackTextExpanded(card.id);

      final isFrontPlaying =
          controller.isPlaying(card.id, CardSide.front);
      final isBackPlaying =
          controller.isPlaying(card.id, CardSide.back);

      final cardStyle = ThemeController.to.cardStyle.value;
      final isOutlined = cardStyle == 'outlined';
      final isFlat = cardStyle == 'flat';

      return Card(
        elevation: isOutlined || isFlat ? 0 : 2,
        margin: const EdgeInsets.only(bottom: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isOutlined
              ? BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Sisi Depan + Tombol Minimize/Expand
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SISI DEPAN (${controller.deck.value?.sourceLang.toUpperCase() ?? "ID"})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Tombol Suara Depan
                  IconButton(
                    icon: Icon(
                      isFrontPlaying
                          ? Icons.volume_up
                          : Icons.volume_up_outlined,
                      color: isFrontPlaying
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    tooltip: 'Dengarkan Sisi Depan',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.playAudio(card, CardSide.front),
                  ),
                  // Tombol Minimize / Expand
                  IconButton(
                    icon: Icon(
                      isMinimized ? Icons.expand_more : Icons.expand_less,
                    ),
                    tooltip: isMinimized ? 'Buka Kartu' : 'Kecilkan Kartu',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => controller.toggleCardMinimized(card.id),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Teks Sisi Depan (Vertikal di atas)
              _buildTruncatedText(
                context,
                text: card.frontText,
                isExpanded: isFrontExpanded,
                onToggle: () => controller.toggleFrontTextExpanded(card.id),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (!isMinimized) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Header Sisi Belakang
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SISI BELAKANG (EN)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Tombol Suara Belakang
                    IconButton(
                      icon: Icon(
                        isBackPlaying
                            ? Icons.volume_up
                            : Icons.volume_up_outlined,
                        color: isBackPlaying
                            ? Theme.of(context).colorScheme.secondary
                            : null,
                      ),
                      tooltip: 'Dengarkan Sisi Belakang',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          controller.playAudio(card, CardSide.back),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Teks Sisi Belakang (Vertikal di bawah)
                _buildTruncatedText(
                  context,
                  text: card.backText,
                  isExpanded: isBackExpanded,
                  onToggle: () => controller.toggleBackTextExpanded(card.id),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Baris Tombol Aksi: Kesulitan, Sunting, Hapus
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildDifficultyChip(
                              label: 'Mudah',
                              color: Colors.green,
                              isSelected: card.difficulty == 1,
                              onTap: () => controller.setDifficulty(
                                card,
                                card.difficulty == 1 ? 0 : 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildDifficultyChip(
                              label: 'Sedang',
                              color: Colors.amber.shade800,
                              isSelected: card.difficulty == 2,
                              onTap: () => controller.setDifficulty(
                                card,
                                card.difficulty == 2 ? 0 : 2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildDifficultyChip(
                              label: 'Sulit',
                              color: Colors.red,
                              isSelected: card.difficulty == 3,
                              onTap: () => controller.setDifficulty(
                                card,
                                card.difficulty == 3 ? 0 : 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Tombol Sunting
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Sunting Kartu',
                      onPressed: () => _openCardEditor(context, card: card),
                    ),
                    // Tombol Hapus
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Hapus Kartu',
                      onPressed: () => _showDeleteCardDialog(context, card),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTruncatedText(
    BuildContext context, {
    required String text,
    required bool isExpanded,
    required VoidCallback onToggle,
    TextStyle? style,
    int maxLength = 80,
  }) {
    if (text.length <= maxLength) {
      return Text(text, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpanded ? text : '${text.substring(0, maxLength)}...',
          style: style,
        ),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              isExpanded ? 'Sembunyikan' : 'Baca selengkapnya',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(25),
          border: Border.all(
            color: color,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCardEditor(BuildContext context, {db.Card? card}) {
    final Map<String, dynamic> args = {
      'deck': controller.deck.value,
    };
    if (card != null) {
      args['card'] = card;
    }
    Get.toNamed(Routes.CARD_EDITOR, arguments: args)
        ?.then((_) => controller.loadCards());
  }

  void _showDeleteCardDialog(BuildContext context, db.Card card) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Kartu?'),
        content: Text(
          'Kartu "${card.frontText}" akan dipindahkan ke tempat sampah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await controller.deleteCard(card);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _buildDueBanner(BuildContext context, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.school,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belajar Hari Ini',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '$count kartu jatuh tempo perlu diulang.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer
                        .withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              final currentDeck = controller.deck.value;
              if (currentDeck != null) {
                Get.toNamed(
                  Routes.CARD_VIEWER,
                  arguments: {
                    'deck': currentDeck,
                    'isStudyMode': true,
                  },
                )?.then((_) => controller.loadCards());
              }
            },
            child: const Text('Mulai'),
          ),
        ],
      ),
    );
  }
}
