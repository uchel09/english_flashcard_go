import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../data/database/app_database.dart' show Deck;
import '../../../routes/app_pages.dart';
import '../../../widgets/card_import_dialog.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Tambah Deck',
          onPressed: () => _showAddDeckDialog(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Flashcard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistik Belajar',
            onPressed: () => Get.toNamed(Routes.STATISTICS),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Impor Deck',
            onPressed: controller.importDeck,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Pengaturan',
            onPressed: () => Get.toNamed(Routes.SETTINGS),
          ),
        ],
      ),
      body: Obx(() {
        final bool hasNoDecks =
            controller.regularDecks.isEmpty && controller.premiumDecks.isEmpty;

        if (controller.isLoading.value && hasNoDecks) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty && hasNoDecks) {
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
                    onPressed: controller.refreshDecks,
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshDecks(),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            children: [
              if (hasNoDecks) ...[
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_books_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Deck',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Buat deck pertama Anda untuk mulai belajar kosakata.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Deck Pertama'),
                        onPressed: () => _showAddDeckDialog(context),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Impor File .flashdeck'),
                        onPressed: controller.importDeck,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Bagian: Biasa
              _buildSectionHeader(
                context,
                title: 'Biasa',
                count: controller.regularDecks.length,
                icon: Icons.folder,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              if (controller.regularDecks.isEmpty)
                _buildEmptySectionCard(
                  context,
                  message: 'Belum ada deck biasa.',
                )
              else
                ...controller.regularDecks.map(
                  (item) => _buildDeckCard(
                    context,
                    item: item,
                    isPremium: false,
                    onTap: () => _showDeckBottomSheet(
                      context,
                      item.deck,
                      isPremium: false,
                      dueCardCount: item.dueCardCount,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Bagian: Premium
              _buildSectionHeader(
                context,
                title: 'Premium',
                count: controller.premiumDecks.length,
                icon: Icons.stars,
                color: Colors.amber.shade800,
              ),
              const SizedBox(height: 8),
              if (controller.premiumDecks.isEmpty)
                _buildEmptySectionCard(
                  context,
                  message: 'Belum ada deck premium.',
                )
              else
                ...controller.premiumDecks.map(
                  (item) => _buildDeckCard(
                    context,
                    item: item,
                    isPremium: true,
                    onTap: () => _showDeckBottomSheet(
                      context,
                      item.deck,
                      isPremium: true,
                      dueCardCount: item.dueCardCount,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySectionCard(
    BuildContext context, {
    required String message,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withAlpha(120),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckCard(
    BuildContext context, {
    required DeckItemModel item,
    required bool isPremium,
    required VoidCallback onTap,
  }) {
    final deckStyle = ThemeController.to.deckStyle.value;
    final isOutlined = deckStyle == 'outlined';
    final isCompact = deckStyle == 'compact';

    return Card(
      elevation: isOutlined ? 0 : 1,
      margin: EdgeInsets.only(bottom: isCompact ? 4.0 : 8.0),
      shape: isOutlined
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            )
          : null,
      child: ListTile(
        dense: isCompact,
        visualDensity: isCompact ? VisualDensity.compact : null,
        leading: CircleAvatar(
          radius: isCompact ? 16 : 20,
          backgroundColor: isPremium
              ? Colors.amber.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            isPremium ? Icons.workspace_premium : Icons.folder,
            size: isCompact ? 18 : 22,
            color: isPremium
                ? Colors.amber.shade900
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          item.deck.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isCompact ? 14 : 16,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              isPremium
                  ? '${item.subDeckCount} subdeck • ${item.cardCount} kartu'
                  : '${item.cardCount} kartu',
              style: TextStyle(fontSize: isCompact ? 12 : 13),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: item.dueCardCount > 0
                    ? Colors.red.withAlpha(25)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: item.dueCardCount > 0
                      ? Colors.red.withAlpha(120)
                      : Colors.transparent,
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${item.dueCardCount} jatuh tempo',
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  fontWeight: item.dueCardCount > 0 ? FontWeight.bold : FontWeight.normal,
                  color: item.dueCardCount > 0
                      ? Colors.red.shade800
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.more_vert),
        onTap: onTap,
      ),
    );
  }

  // --- Dialog Tambah Deck ---
  void _showAddDeckDialog(BuildContext context) {
    final titleController = TextEditingController();
    final sourceLang = (ThemeController.to.defaultSourceLang.value).obs;
    final isPremium = false.obs;
    final formKey = GlobalKey<FormState>();

    final Map<String, String> languages = {
      'id': 'Indonesia',
      'en': 'English',
      'es': 'Spanyol',
      'fr': 'Prancis',
      'ja': 'Jepang',
      'de': 'Jerman',
      'ar': 'Arab',
      'zh': 'Mandarin',
    };

    Get.dialog(
      AlertDialog(
        title: const Text('Tambah Deck Baru'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Judul Deck',
                    hintText: 'Contoh: Kosakata Liburan',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Judul deck wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bahasa Asal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<String>(
                    initialValue: sourceLang.value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: languages.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) sourceLang.value = val;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kategori Deck',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Biasa')),
                          selected: !isPremium.value,
                          onSelected: (_) => isPremium.value = false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.stars, size: 16),
                          label: const Center(child: Text('Premium')),
                          selected: isPremium.value,
                          onSelected: (_) => isPremium.value = true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Get.back();
                await controller.createDeck(
                  title: titleController.text,
                  sourceLang: sourceLang.value,
                  isPremium: isPremium.value,
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- Bottom Sheet Menu Deck (Biasa & Premium) ---
  void _showDeckBottomSheet(
    BuildContext context,
    Deck deck, {
    required bool isPremium,
    int dueCardCount = 0,
  }) {
    Get.bottomSheet(
      isScrollControlled: true,
      SafeArea(
        child: SingleChildScrollView(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(
                    isPremium ? Icons.workspace_premium : Icons.folder,
                    color: isPremium
                        ? Colors.amber.shade800
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isPremium ? 'Kategori: Premium' : 'Kategori: Biasa',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Buka deck'),
              subtitle: Text(
                isPremium
                    ? 'Buka daftar subdeck di dalam deck ini'
                    : 'Lihat dan kelola kartu dalam deck',
              ),
              onTap: () {
                Get.back();
                if (isPremium) {
                  _showSubDecksModal(context, deck);
                } else {
                  Get.toNamed(Routes.DECK_DETAIL, arguments: deck)?.then((_) {
                    controller.refreshDecks();
                  });
                }
              },
            ),
            ListTile(
              leading: Badge.count(
                count: dueCardCount,
                isLabelVisible: dueCardCount > 0,
                child: const Icon(Icons.school_outlined, color: Colors.teal),
              ),
              title: const Text('Belajar hari ini'),
              subtitle: Text(
                isPremium
                    ? 'Pilih subdeck untuk belajar kartu jatuh tempo'
                    : 'Pelajari kartu jatuh tempo SM-2 ($dueCardCount kartu)',
              ),
              onTap: () {
                Get.back();
                if (isPremium) {
                  _showSubDecksModal(context, deck);
                } else {
                  Get.toNamed(
                    Routes.CARD_VIEWER,
                    arguments: {'deck': deck, 'isStudyMode': true},
                  )?.then((_) => controller.refreshDecks());
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Mulai tes'),
              subtitle: Text(
                isPremium
                    ? 'Pilih subdeck untuk latihan kuis'
                    : 'Latihan kuis pilihan ganda flashcard',
              ),
              onTap: () {
                Get.back();
                if (isPremium) {
                  _showSubDecksModal(context, deck);
                } else {
                  Get.toNamed(Routes.QUIZ, arguments: deck);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Bagikan deck'),
              subtitle: const Text('Ekspor paket deck (.flashdeck) & bagikan'),
              onTap: () {
                Get.back();
                controller.exportDeck(deck);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined, color: Colors.blue),
              title: const Text('Impor kartu (CSV / Teks)'),
              subtitle: const Text('Tambah kartu via berkas CSV atau teks tempel'),
              onTap: () {
                Get.back();
                CardImportHelper.showImportOptionsModal(
                  context,
                  targetDeck: deck,
                  onImportSuccess: controller.refreshDecks,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Ganti nama'),
              onTap: () {
                Get.back();
                _showRenameDeckDialog(context, deck);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Hapus', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Pindahkan deck ke tempat sampah'),
              onTap: () {
                Get.back();
                _showDeleteConfirmationDialog(context, deck);
              },
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  // --- Dialog Ganti Nama Deck ---
  void _showRenameDeckDialog(BuildContext context, Deck deck) {
    final textController = TextEditingController(text: deck.title);
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        title: const Text('Ganti Nama Deck'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nama Baru',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Nama deck tidak boleh kosong';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Get.back();
                await controller.renameDeck(
                  id: deck.id,
                  newTitle: textController.text,
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- Dialog Konfirmasi Soft Delete Deck ---
  void _showDeleteConfirmationDialog(BuildContext context, Deck deck) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Deck?'),
        content: Text(
          'Deck "${deck.title}" akan dipindahkan ke tempat sampah. Anda dapat mengurungkannya nanti.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await controller.softDeleteDeck(deck);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // --- Modal Daftar Subdeck untuk Deck Premium ---
  void _showSubDecksModal(BuildContext context, Deck parentDeck) {
    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parentDeck.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Daftar Subdeck',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Tambah Subdeck',
                  onPressed: () => _showAddSubDeckDialog(context, parentDeck),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: FutureBuilder<List<DeckItemModel>>(
                future: controller.getSubDecks(parentDeck.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final subDecks = snapshot.data ?? [];
                  if (subDecks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 56,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada subdeck.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tekan tombol + di atas untuk menambahkan subdeck baru.',
                            style: TextStyle(fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: subDecks.length,
                    itemBuilder: (context, index) {
                      final item = subDecks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.folder_outlined),
                          ),
                          title: Text(
                            item.deck.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.cardCount} kartu • ${item.dueCardCount} jatuh tempo',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Menu Subdeck',
                            onSelected: (value) {
                              switch (value) {
                                case 'open':
                                  Get.back();
                                  Get.toNamed(
                                    Routes.DECK_DETAIL,
                                    arguments: item.deck,
                                  )?.then((_) => controller.refreshDecks());
                                  break;
                                case 'study':
                                  Get.back();
                                  Get.toNamed(
                                    Routes.CARD_VIEWER,
                                    arguments: {
                                      'deck': item.deck,
                                      'isStudyMode': true,
                                    },
                                  )?.then((_) => controller.refreshDecks());
                                  break;
                                case 'quiz':
                                  Get.back();
                                  Get.toNamed(
                                    Routes.QUIZ,
                                    arguments: item.deck,
                                  );
                                  break;
                                case 'share':
                                  controller.exportDeck(item.deck);
                                  break;
                                case 'rename':
                                  _showRenameDeckDialog(context, item.deck);
                                  break;
                                case 'delete_permanent':
                                  _showDeletePermanentConfirmationDialog(
                                    context,
                                    item.deck,
                                    parentDeck,
                                  );
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'open',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder_open, size: 20),
                                    SizedBox(width: 12),
                                    Text('Buka subdeck'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'study',
                                child: Row(
                                  children: [
                                    Icon(Icons.school_outlined, size: 20),
                                    SizedBox(width: 12),
                                    Text('Belajar hari ini'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'quiz',
                                child: Row(
                                  children: [
                                    Icon(Icons.play_arrow, size: 20),
                                    SizedBox(width: 12),
                                    Text('Mulai tes'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20),
                                    SizedBox(width: 12),
                                    Text('Bagikan subdeck'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 20),
                                    SizedBox(width: 12),
                                    Text('Ganti nama'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete_permanent',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Hapus permanen',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Get.back();
                            Get.toNamed(
                              Routes.DECK_DETAIL,
                              arguments: item.deck,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Dialog Tambah Subdeck ---
  void _showAddSubDeckDialog(BuildContext context, Deck parentDeck) {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        title: Text('Tambah Subdeck di "${parentDeck.title}"'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Judul Subdeck',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Judul subdeck wajib diisi';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Get.back();
                await controller.createSubDeck(
                  parentId: parentDeck.id,
                  title: titleController.text,
                );
                // Refresh bottom sheet subdeck view
                if (context.mounted) {
                  _showSubDecksModal(context, parentDeck);
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- Dialog Konfirmasi Hapus Permanen Subdeck ---
  void _showDeletePermanentConfirmationDialog(
    BuildContext context,
    Deck subDeck,
    Deck parentDeck,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('Hapus Subdeck Permanen?'),
        content: Text(
          'Subdeck "${subDeck.title}" dan seluruh kartu di dalamnya akan dihapus permanen. Tindakan ini tidak dapat diurungkan.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await controller.hardDeleteSubDeck(subDeck.id);
              Get.snackbar(
                'Subdeck Dihapus',
                'Subdeck "${subDeck.title}" telah dihapus secara permanen.',
                snackPosition: SnackPosition.BOTTOM,
              );
              if (context.mounted) {
                _showSubDecksModal(context, parentDeck);
              }
            },
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }
}
