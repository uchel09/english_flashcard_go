import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/audio_service.dart';
import '../../../data/services/media_service.dart';
import '../../../data/services/sm2_service.dart';
import '../controllers/card_viewer_controller.dart';

class CardViewerView extends GetView<CardViewerController> {
  const CardViewerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () {
            final deckTitle = controller.deck.value?.title ?? '';
            if (controller.isStudyMode.value) {
              return Text(
                deckTitle.isNotEmpty
                    ? 'Belajar Hari Ini: $deckTitle'
                    : 'Belajar Hari Ini',
              );
            }
            return Text(
              deckTitle.isNotEmpty
                  ? 'Penampil: $deckTitle'
                  : 'Penampil Kartu',
            );
          },
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty) {
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
                    onPressed: () {
                      final deckId = controller.deck.value?.id;
                      if (deckId != null) {
                        if (controller.isStudyMode.value) {
                          controller.loadDueCards(deckId);
                        } else {
                          controller.loadCards(deckId);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }

        // Tampilan bila seluruh kartu dalam sesi telah selesai dipelajari
        if (controller.isStudyMode.value && controller.isFinished.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Selesai Belajar Hari Ini!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Luar biasa! Anda telah mereview ${controller.studiedCount.value} kartu yang jatuh tempo dengan algoritma SM-2.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Kembali ke Beranda'),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
          );
        }

        // Tampilan kartu kosong
        if (controller.cards.isEmpty) {
          if (controller.isStudyMode.value) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.celebration_outlined,
                      size: 80,
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Semua Kartu Sudah Dipelajari 🎉',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada kartu yang jatuh tempo untuk dipelajari hari ini di deck ini. Silakan kembali lagi besok!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => Get.back(),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_none_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum Ada Kartu',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Deck ini belum memiliki kartu flashcard untuk ditampilkan.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final card = controller.currentCard;
        if (card == null) return const SizedBox.shrink();

        final isFlipped = controller.isFlipped.value;
        final currentSide = isFlipped ? CardSide.back : CardSide.front;
        final sideText = isFlipped ? card.backText : card.frontText;
        final sideImagePath =
            isFlipped ? card.backImagePath : card.frontImagePath;
        final sideTitle = isFlipped
            ? 'Sisi Belakang (English)'
            : 'Sisi Depan (${controller.deck.value?.sourceLang.toUpperCase() ?? "ID"})';

        final progress =
            (controller.currentIndex.value + 1) / controller.cards.length;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Bar Progres & Indikator Posisi Kartu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    controller.isStudyMode.value
                        ? 'Kartu Jatuh Tempo ${controller.currentIndex.value + 1} dari ${controller.cards.length}'
                        : 'Kartu ${controller.currentIndex.value + 1} dari ${controller.cards.length}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (controller.isStudyMode.value)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'SM-2 Spaced Repetition',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 16),

              // Area Kartu (Bisa diketuk untuk membalik sisi)
              Expanded(
                child: GestureDetector(
                  onTap: controller.flipCard,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Label Sisi
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isFlipped
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sideTitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isFlipped
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Gambar jika ada
                          if (sideImagePath != null &&
                              sideImagePath.isNotEmpty) ...[
                            _buildCardImage(sideImagePath),
                            const SizedBox(height: 16),
                          ],

                          // Teks Kartu
                          Text(
                            sideText.isEmpty ? '(Tanpa teks)' : sideText,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),

                          // Tombol Audio & Petunjuk Ketuk
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton.filledTonal(
                                icon: Icon(
                                  controller.isPlaying(currentSide)
                                      ? Icons.stop
                                      : Icons.volume_up,
                                ),
                                tooltip: 'Putar Suara',
                                onPressed: () =>
                                    controller.playAudio(currentSide),
                              ),
                              Text(
                                'Ketuk untuk membalik ↻',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontStyle: FontStyle.italic,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bagian Bawah: Penilaian SM-2 atau Kontrol Navigasi Standar
              if (controller.isStudyMode.value)
                _buildStudyModeControls(context, card)
              else
                _buildNormalControls(context),
            ],
          ),
        );
      }),
    );
  }

  // Kontrol Penilaian Mode Belajar SM-2: Lagi / Sulit / Bagus / Mudah
  Widget _buildStudyModeControls(BuildContext context, card) {
    if (!controller.isFlipped.value) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.flip),
          label: const Text(
            'Balik Kartu (Lihat Jawaban)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: controller.flipCard,
        ),
      );
    }

    final isSaving = controller.isSavingRating.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Seberapa baik Anda mengingat kartu ini?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 1. Lagi (Again) - Merah
            Expanded(
              child: _buildRatingButton(
                label: 'Lagi',
                intervalText: Sm2Service.formatIntervalDays(
                  Sm2Service.getEstimatedInterval(card, ReviewRating.again),
                ),
                color: Colors.red,
                isDisabled: isSaving,
                onTap: () => controller.rateCard(ReviewRating.again),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Sulit (Hard) - Oranye
            Expanded(
              child: _buildRatingButton(
                label: 'Sulit',
                intervalText: Sm2Service.formatIntervalDays(
                  Sm2Service.getEstimatedInterval(card, ReviewRating.hard),
                ),
                color: Colors.orange.shade800,
                isDisabled: isSaving,
                onTap: () => controller.rateCard(ReviewRating.hard),
              ),
            ),
            const SizedBox(width: 8),

            // 3. Bagus (Good) - Biru
            Expanded(
              child: _buildRatingButton(
                label: 'Bagus',
                intervalText: Sm2Service.formatIntervalDays(
                  Sm2Service.getEstimatedInterval(card, ReviewRating.good),
                ),
                color: Colors.blue.shade700,
                isDisabled: isSaving,
                onTap: () => controller.rateCard(ReviewRating.good),
              ),
            ),
            const SizedBox(width: 8),

            // 4. Mudah (Easy) - Hijau
            Expanded(
              child: _buildRatingButton(
                label: 'Mudah',
                intervalText: Sm2Service.formatIntervalDays(
                  Sm2Service.getEstimatedInterval(card, ReviewRating.easy),
                ),
                color: Colors.green.shade700,
                isDisabled: isSaving,
                onTap: () => controller.rateCard(ReviewRating.easy),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required String label,
    required String intervalText,
    required Color color,
    required bool isDisabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              intervalText,
              style: TextStyle(
                color: color.withAlpha(200),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kontrol Mode Penampil Biasa
  Widget _buildNormalControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton.filledTonal(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kartu Sebelumnya',
          onPressed: controller.currentIndex.value > 0
              ? controller.previousCard
              : null,
        ),
        FilledButton.icon(
          icon: const Icon(Icons.flip),
          label: const Text('Balik Kartu'),
          onPressed: controller.flipCard,
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Kartu Berikutnya',
          onPressed: controller.currentIndex.value < controller.cards.length - 1
              ? controller.nextCard
              : null,
        ),
      ],
    );
  }

  Widget _buildCardImage(String relativePath) {
    return FutureBuilder<String>(
      future: MediaService.to.resolveAbsolutePath(relativePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final file = File(snapshot.data!);
        if (!file.existsSync()) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            height: 140,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

