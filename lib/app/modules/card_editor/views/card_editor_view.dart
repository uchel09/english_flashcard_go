import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/card_editor_controller.dart';

class CardEditorView extends GetView<CardEditorController> {
  const CardEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(controller.isEditing ? 'Sunting Kartu' : 'Tambah Kartu'),
        ),
        actions: [
          Obx(
            () => controller.isSaving.value
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: 'Simpan Kartu',
                    onPressed: () => controller.saveCard(),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // SISI DEPAN
          _buildSideCard(
            context,
            side: 'front',
            sideLabel:
                'Sisi Depan (${controller.deck.value?.sourceLang.toUpperCase() ?? "ID"})',
            textController: controller.frontTextController,
            audioPathRx: controller.frontAudioPath,
            imagePathRx: controller.frontImagePath,
            isRecordingRx: controller.isFrontRecording,
            color: Theme.of(context).colorScheme.primary,
          ),

          const SizedBox(height: 24),

          // SISI BELAKANG
          _buildSideCard(
            context,
            side: 'back',
            sideLabel: 'Sisi Belakang (English)',
            textController: controller.backTextController,
            audioPathRx: controller.backAudioPath,
            imagePathRx: controller.backImagePath,
            isRecordingRx: controller.isBackRecording,
            color: Theme.of(context).colorScheme.secondary,
          ),

          const SizedBox(height: 32),

          Obx(
            () => FilledButton.icon(
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                controller.isSaving.value ? 'Menyimpan...' : 'Simpan Kartu',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: controller.isSaving.value
                  ? null
                  : () => controller.saveCard(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSideCard(
    BuildContext context, {
    required String side,
    required String sideLabel,
    required TextEditingController textController,
    required RxnString audioPathRx,
    required RxnString imagePathRx,
    required RxBool isRecordingRx,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sideLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Text Input
            TextField(
              controller: textController,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Teks $sideLabel',
                hintText: side == 'front'
                    ? 'Contoh: Selamat Pagi'
                    : 'Contoh: Good Morning',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Media Action Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Record Voice Button
                  Obx(() {
                    final isRec = isRecordingRx.value;
                    return isRec
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.stop),
                            label: const Text('Berhenti Merekam'),
                            onPressed: () =>
                                controller.toggleRecording(side),
                          )
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.mic),
                            label: const Text('Rekam Suara'),
                            onPressed: () =>
                                controller.toggleRecording(side),
                          );
                  }),
                  const SizedBox(width: 8),

                  // Pick Audio File
                  OutlinedButton.icon(
                    icon: const Icon(Icons.audio_file),
                    label: const Text('Pilih Audio'),
                    onPressed: () => controller.pickAudioFile(side),
                  ),
                  const SizedBox(width: 8),

                  // Pick Image
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Gambar'),
                    onPressed: () => _showImageSourceDialog(context, side),
                  ),
                ],
              ),
            ),

            // Preview Area for Audio
            Obx(() {
              final audioPath = audioPathRx.value;
              if (audioPath == null || audioPath.isEmpty) {
                return const SizedBox.shrink();
              }
              final isPreviewPlaying = controller.isPlayingPreview.value &&
                  controller.activePreviewSide.value == side;

              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(120),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack, color: color, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Berkas Rekaman / Audio',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            audioPath,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPreviewPlaying ? Icons.stop : Icons.play_arrow,
                        color: color,
                      ),
                      tooltip: isPreviewPlaying
                          ? 'Berhenti Preview'
                          : 'Putar Preview',
                      onPressed: () =>
                          controller.playAudioPreview(audioPath, side),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Hapus Audio',
                      onPressed: () => controller.removeAudio(side),
                    ),
                  ],
                ),
              );
            }),

            // Preview Area for Image
            Obx(() {
              final imagePath = imagePathRx.value;
              if (imagePath == null || imagePath.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder<String>(
                        future: controller.resolveAbsolutePath(imagePath),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final file = File(snapshot.data!);
                          if (!file.existsSync()) {
                            return const SizedBox(
                              height: 60,
                              child: Center(
                                child: Text('Gambar tidak ditemukan'),
                              ),
                            );
                          }
                          return Image.file(
                            file,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Hapus Gambar',
                          onPressed: () => controller.removeImage(side),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context, String side) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Pilih Sumber Gambar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Get.back();
                controller.pickImage(ImageSource.camera, side);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Get.back();
                controller.pickImage(ImageSource.gallery, side);
              },
            ),
          ],
        ),
      ),
    );
  }
}
