import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/database/app_database.dart' as db;
import '../controllers/trash_controller.dart';

class TrashView extends GetView<TrashController> {
  const TrashView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tempat Sampah'),
          actions: [
            Obx(() {
              final hasItems = controller.trashDecks.isNotEmpty ||
                  controller.trashCards.isNotEmpty;
              if (!hasItems) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Kosongkan Tempat Sampah',
                onPressed: () => _confirmEmptyTrash(context),
              );
            }),
          ],
          bottom: TabBar(
            tabs: [
              Obx(
                () => Tab(
                  text: 'Deck (${controller.trashDecks.length})',
                  icon: const Icon(Icons.folder_delete_outlined),
                ),
              ),
              Obx(
                () => Tab(
                  text: 'Kartu (${controller.trashCards.length})',
                  icon: const Icon(Icons.filter_none_outlined),
                ),
              ),
            ],
          ),
        ),
        body: Obx(() {
          final isEmpty = controller.trashDecks.isEmpty &&
              controller.trashCards.isEmpty;

          if (controller.isLoading.value && isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value.isNotEmpty && isEmpty) {
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
                      onPressed: controller.loadTrash,
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            children: [
              _buildDecksTab(context),
              _buildCardsTab(context),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDecksTab(BuildContext context) {
    return Obx(() {
      if (controller.trashDecks.isEmpty) {
        return _buildEmptyState(
          context,
          icon: Icons.folder_off_outlined,
          title: 'Tidak Ada Deck Terhapus',
          message: 'Deck yang Anda hapus sementara akan tersimpan di sini.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadTrash,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.trashDecks.length,
          itemBuilder: (context, index) {
            final deck = controller.trashDecks[index];
            final cardCount = controller.deckCardCounts[deck.id] ?? 0;
            return _buildDeckTrashCard(context, deck, cardCount);
          },
        ),
      );
    });
  }

  Widget _buildDeckTrashCard(
    BuildContext context,
    db.Deck deck,
    int cardCount,
  ) {
    final isSubDeck = deck.parentId != null;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSubDeck
                      ? Colors.teal.shade100
                      : (deck.isPremium
                          ? Colors.amber.shade100
                          : Theme.of(context).colorScheme.primaryContainer),
                  child: Icon(
                    isSubDeck
                        ? Icons.subdirectory_arrow_right
                        : (deck.isPremium
                            ? Icons.workspace_premium
                            : Icons.folder),
                    color: isSubDeck
                        ? Colors.teal.shade800
                        : (deck.isPremium
                            ? Colors.amber.shade900
                            : Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isSubDeck)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Subdeck',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade900,
                                ),
                              ),
                            )
                          else if (deck.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Premium',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          Text(
                            '$cardCount kartu',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.delete_forever,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'Hapus Permanen',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _confirmHardDeleteDeck(context, deck),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Pulihkan', style: TextStyle(fontSize: 13)),
                  onPressed: () => controller.restoreDeck(deck),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsTab(BuildContext context) {
    return Obx(() {
      if (controller.trashCards.isEmpty) {
        return _buildEmptyState(
          context,
          icon: Icons.filter_none_outlined,
          title: 'Tidak Ada Kartu Terhapus',
          message:
              'Kartu yang Anda hapus satu per satu dari deck akan tersimpan di sini.',
        );
      }

      return RefreshIndicator(
        onRefresh: controller.loadTrash,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: controller.trashCards.length,
          itemBuilder: (context, index) {
            final card = controller.trashCards[index];
            final deckTitle = controller.cardDeckTitles[card.deckId] ?? 'Deck';
            return _buildCardTrashCard(context, card, deckTitle);
          },
        ),
      );
    });
  }

  Widget _buildCardTrashCard(
    BuildContext context,
    db.Card card,
    String deckTitle,
  ) {
    final hasAudio = (card.frontAudioPath != null &&
            card.frontAudioPath!.isNotEmpty) ||
        (card.backAudioPath != null && card.backAudioPath!.isNotEmpty);
    final hasImage = (card.frontImagePath != null &&
            card.frontImagePath!.isNotEmpty) ||
        (card.backImagePath != null && card.backImagePath!.isNotEmpty);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge deck asal
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    deckTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasAudio)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.volume_up, size: 16, color: Colors.blue),
                  ),
                if (hasImage)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.image, size: 16, color: Colors.green),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Sisi Depan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(120),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SISI DEPAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.frontText.isEmpty ? '(Tanpa teks)' : card.frontText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Sisi Belakang
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SISI BELAKANG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.backText.isEmpty ? '(Tanpa teks)' : card.backText,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.delete_forever,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    'Hapus Permanen',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () => _confirmHardDeleteCard(context, card),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Pulihkan', style: TextStyle(fontSize: 13)),
                  onPressed: () => controller.restoreCard(card),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmHardDeleteDeck(BuildContext context, db.Deck deck) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Permanen Deck?'),
        content: Text(
          'Deck "${deck.title}" beserta seluruh subdeck, kartu, dan berkas media yang tidak dipakai lagi akan dihapus secara permanen.\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Get.back();
              controller.hardDeleteDeck(deck);
            },
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  void _confirmHardDeleteCard(BuildContext context, db.Card card) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Permanen Kartu?'),
        content: Text(
          'Kartu "${card.frontText}" dan berkas media terkait yang tidak dipakai kartu lain akan dihapus secara permanen.\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Get.back();
              controller.hardDeleteCard(card);
            },
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Kosongkan Tempat Sampah?'),
        content: const Text(
          'Semua deck dan kartu di tempat sampah akan dihapus secara permanen beserta berkas media yang tidak lagi digunakan.\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Get.back();
              controller.emptyTrash();
            },
            child: const Text('Kosongkan Semua'),
          ),
        ],
      ),
    );
  }
}
