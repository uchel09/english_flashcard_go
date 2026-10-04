import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../routes/app_pages.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController.to;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // 1. Pencadangan & Pemulihan
          _buildSectionTitle(context, 'Pencadangan & Pemulihan'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.file_download_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Impor Deck (.flashdeck)'),
                  subtitle: const Text('Impor deck, kartu, dan media dari berkas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.importDeck,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.table_chart_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Impor Kartu (CSV / Teks)'),
                  subtitle: const Text(
                    'Impor dari format CSV (depan, belakang) atau teks tempel (depan;belakang)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.importCardsCsvOrText(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.file_upload_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Ekspor Semua Deck (.flashdeck)'),
                  subtitle:
                      const Text('Cadangkan seluruh deck aktif ke berkas .flashdeck'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.exportAllDecks,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.archive_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: const Text('Cadangkan Seluruh Data (.zip)'),
                  subtitle: const Text(
                    'Cadangkan seluruh deck, kartu, riwayat belajar, dan media ke satu file zip',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.backupAllDataZip,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.settings_backup_restore,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  title: const Text('Pulihkan Seluruh Data (.zip)'),
                  subtitle: const Text(
                    'Pulihkan semua data dan media dari berkas cadangan zip',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => controller.confirmAndRestoreZip(context),
                ),
              ],
            ),
          ),

          // 2. Tampilan & Tema
          _buildSectionTitle(context, 'Tampilan & Tema'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode Tema (Terang / Gelap / Ikuti Sistem)
                  const Text(
                    'Mode Tema',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    final currentMode = themeController.themeMode;
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Sistem'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                      ],
                      selected: {currentMode},
                      onSelectionChanged: (selected) {
                        if (selected.isNotEmpty) {
                          themeController.setThemeMode(selected.first);
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Warna Aksen
                  const Text(
                    'Warna Aksen',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih warna aksen tema aplikasi:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Obx(
                    () => Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: ThemeController.accentColors.map((option) {
                        final isSelected = themeController.accentColor.value
                                .toARGB32() ==
                            option.color.toARGB32();
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: option.color,
                            radius: 10,
                          ),
                          label: Text(option.name),
                          selected: isSelected,
                          onSelected: (_) =>
                              themeController.setAccentColor(option.color),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Gaya Tampilan Kartu
                  const Text(
                    'Gaya Tampilan Kartu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bentuk visual kartu flashcard:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final currentStyle = themeController.cardStyle.value;
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text('Elevasi / Berbayang'),
                          selected: currentStyle == 'elevated',
                          onSelected: (_) =>
                              themeController.setCardStyle('elevated'),
                        ),
                        ChoiceChip(
                          label: const Text('Garis Tepi'),
                          selected: currentStyle == 'outlined',
                          onSelected: (_) =>
                              themeController.setCardStyle('outlined'),
                        ),
                        ChoiceChip(
                          label: const Text('Datar / Rata'),
                          selected: currentStyle == 'flat',
                          onSelected: (_) =>
                              themeController.setCardStyle('flat'),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Gaya Tampilan Deck
                  const Text(
                    'Gaya Tampilan Deck',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bentuk daftar deck di halaman utama:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final currentDeckStyle = themeController.deckStyle.value;
                    return Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        ChoiceChip(
                          label: const Text('Standar'),
                          selected: currentDeckStyle == 'standard',
                          onSelected: (_) =>
                              themeController.setDeckStyle('standard'),
                        ),
                        ChoiceChip(
                          label: const Text('Ringkas'),
                          selected: currentDeckStyle == 'compact',
                          onSelected: (_) =>
                              themeController.setDeckStyle('compact'),
                        ),
                        ChoiceChip(
                          label: const Text('Garis Tepi'),
                          selected: currentDeckStyle == 'outlined',
                          onSelected: (_) =>
                              themeController.setDeckStyle('outlined'),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // 3. Preferensi Bahasa
          _buildSectionTitle(context, 'Preferensi Bahasa'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bahasa Asal Default',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bahasa bawaan saat membuat deck baru (default: Indonesia):',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    final selectedLang = themeController.defaultSourceLang.value;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedLang,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: SettingsController.availableLanguages.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.setDefaultSourceLang(val);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

          // 4. Pengaturan Suara (TTS)
          _buildSectionTitle(context, 'Pengaturan Suara (TTS)'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kecepatan Bicara (Speech Rate)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kecepatan Bicara',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Obx(() {
                        final rate = themeController.ttsSpeechRate.value;
                        final label = rate == 0.5
                            ? 'Normal (0.50)'
                            : rate < 0.5
                                ? 'Lambat (${rate.toStringAsFixed(2)})'
                                : 'Cepat (${rate.toStringAsFixed(2)})';
                        return Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Atur kecepatan suara pelafalan kata bahasa Inggris:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Obx(
                    () => Slider(
                      value: themeController.ttsSpeechRate.value,
                      min: 0.2,
                      max: 1.0,
                      divisions: 16,
                      label: '${themeController.ttsSpeechRate.value.toStringAsFixed(2)}x',
                      onChanged: (v) => themeController.setTtsSpeechRate(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Nada Suara (Pitch)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nada Suara (Pitch)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Obx(() {
                        final pitch = themeController.ttsPitch.value;
                        final label = pitch == 1.0
                            ? 'Normal (1.00)'
                            : pitch < 1.0
                                ? 'Rendah (${pitch.toStringAsFixed(2)})'
                                : 'Tinggi (${pitch.toStringAsFixed(2)})';
                        return Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Atur tinggi rendah frekuensi nada suara:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Obx(
                    () => Slider(
                      value: themeController.ttsPitch.value,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: themeController.ttsPitch.value.toStringAsFixed(2),
                      onChanged: (v) => themeController.setTtsPitch(v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Pilihan Suara (Voice Selector)
                  const Text(
                    'Pilihan Suara TTS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih profil suara yang digunakan untuk melafalkan kata:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Obx(() {
                    final selectedVoice = themeController.ttsVoiceName.value;
                    final voices = controller.availableVoices;

                    return DropdownButtonFormField<String?>(
                      initialValue: selectedVoice,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Bawaan Sistem (Default)'),
                        ),
                        ...voices.map((v) {
                          final name = v['name'] ?? '';
                          final locale = v['locale'] ?? '';
                          return DropdownMenuItem<String?>(
                            value: name,
                            child: Text(
                              '$name ($locale)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val == null) {
                          themeController.setTtsVoice(null, null);
                        } else {
                          final match = voices.firstWhere(
                            (v) => v['name'] == val,
                            orElse: () => {'name': val, 'locale': 'en-US'},
                          );
                          themeController.setTtsVoice(val, match['locale']);
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  // Tombol Uji Coba Suara
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('Uji Coba Suara (Test Voice)'),
                      onPressed: controller.testTtsVoice,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Pengingat Belajar
          _buildSectionTitle(context, 'Pengingat Belajar Harian'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              children: [
                Obx(
                  () => SwitchListTile(
                    secondary: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: const Text('Pengingat Harian'),
                    subtitle: const Text(
                      'Kirim notifikasi lokal setiap hari untuk belajar',
                    ),
                    value: themeController.isReminderEnabled.value,
                    onChanged: (val) {
                      themeController.setReminderSettings(
                        val,
                        themeController.reminderHour.value,
                        themeController.reminderMinute.value,
                      );
                    },
                  ),
                ),
                Obx(() {
                  if (!themeController.isReminderEnabled.value) {
                    return const SizedBox.shrink();
                  }
                  final h = themeController.reminderHour.value
                      .toString()
                      .padLeft(2, '0');
                  final m = themeController.reminderMinute.value
                      .toString()
                      .padLeft(2, '0');
                  return Column(
                    children: [
                      const Divider(height: 1),
                      ListTile(
                        leading: const Padding(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Icon(Icons.access_time),
                        ),
                        title: const Text('Waktu Pengingat'),
                        subtitle: Text('Setiap hari pukul $h:$m'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: themeController.reminderHour.value,
                              minute: themeController.reminderMinute.value,
                            ),
                          );
                          if (picked != null) {
                            themeController.setReminderSettings(
                              true,
                              picked.hour,
                              picked.minute,
                            );
                          }
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),

          // 5. Statistik Belajar
          _buildSectionTitle(context, 'Statistik & Capaian'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withAlpha(30),
                child: const Icon(Icons.insights, color: Colors.blue),
              ),
              title: const Text('Statistik Belajar'),
              subtitle: const Text(
                'Lihat streak, kartu dipelajari, akurasi, dan kartu tersulit',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(Routes.STATISTICS),
            ),
          ),

          // 6. Tempat Sampah
          _buildSectionTitle(context, 'Penyimpanan & Tempat Sampah'),
          Card(
            margin: const EdgeInsets.only(bottom: 20.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: const Text('Tempat Sampah'),
              subtitle: const Text('Daftar deck dan kartu yang terhapus sementara'),
              trailing: const Icon(Icons.chevron_right),
              onTap: controller.navigateToTrash,
            ),
          ),

          // 5. Informasi Aplikasi
          _buildSectionTitle(context, 'Informasi Aplikasi'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Panduan Aplikasi (Onboarding)'),
                  subtitle: const Text('Buka kembali tur pengenalan 3 layar fitur aplikasi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.toNamed(Routes.ONBOARDING),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Versi Aplikasi'),
                  subtitle: Text('1.0.0 (Offline-First)'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.cloud_off_outlined),
                  title: Text('Mode Operasi'),
                  subtitle: Text('Lokal & Mandiri (Tanpa Backend)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
