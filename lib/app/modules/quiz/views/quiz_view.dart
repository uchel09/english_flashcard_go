import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/services/audio_service.dart';
import '../controllers/quiz_controller.dart';

class QuizView extends GetView<QuizController> {
  const QuizView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.deck.value != null
                ? 'Kuis: ${controller.deck.value!.title}'
                : 'Kuis Flashcard',
          ),
        ),
        actions: [
          Obx(() {
            final isFrontToBack =
                controller.direction.value == QuizDirection.frontToBack;
            final sourceLang =
                controller.deck.value?.sourceLang.toUpperCase() ?? 'ID';
            return TextButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: Text(isFrontToBack ? '$sourceLang → EN' : 'EN → $sourceLang'),
              onPressed: (controller.hasAnswered.value && !controller.isCompleted.value)
                  ? null
                  : () => controller.toggleDirection(),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Empty deck state
        if (controller.allCards.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Deck Masih Kosong',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tambahkan kartu kosakata ke dalam deck ini terlebih dahulu untuk memulai sesi kuis.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali'),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            ),
          );
        }

        // Completed / Summary state
        if (controller.isCompleted.value) {
          return _buildSummaryView(context);
        }

        // Quiz Question state
        final question = controller.currentQuestion;
        if (question == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildQuestionView(context, question);
      }),
    );
  }

  // --- Tampilan Soal & Pilihan Ganda ---
  Widget _buildQuestionView(BuildContext context, QuizQuestion question) {
    final total = controller.totalQuestions;
    final current = controller.currentIndex.value + 1;
    final progress = total > 0 ? current / total : 0.0;
    final isFrontToBack =
        controller.direction.value == QuizDirection.frontToBack;
    final sourceLang =
        controller.deck.value?.sourceLang.toUpperCase() ?? 'ID';

    return Column(
      children: [
        // Progress Bar & Counter
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soal $current dari $total',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Benar: ${controller.score}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Kartu Soal
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        isFrontToBack
                            ? 'Arti kata berikut dalam bahasa Inggris ($sourceLang):'
                            : 'Arti kata berikut dalam bahasa $sourceLang (EN):',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        question.promptText,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Tombol Suara Soal
                      Obx(() {
                        final isPlayingPrompt = AudioService.to.isPlaying.value;
                        return IconButton.filledTonal(
                          icon: Icon(isPlayingPrompt
                              ? Icons.volume_up
                              : Icons.volume_up_outlined),
                          tooltip: 'Dengarkan Pengucapan Soal',
                          onPressed: () => controller.playPromptAudio(),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Pilih Jawaban yang Benar:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Opsi Pilihan Ganda (1 sampai 4 opsi)
              ...question.options.map((option) {
                return _buildOptionTile(context, option);
              }),
            ],
          ),
        ),

        // Tombol Lanjut
        Obx(() {
          if (!controller.hasAnswered.value) {
            return const SizedBox.shrink();
          }

          final isLast = current == total;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward),
                  label: Text(
                    isLast ? 'Lihat Ringkasan Hasil' : 'Soal Berikutnya',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => controller.nextQuestion(),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOptionTile(BuildContext context, QuizOption option) {
    final hasAnswered = controller.hasAnswered.value;
    final selectedOption = controller.selectedOption.value;

    Color? backgroundColor;
    Color? borderColor;
    Widget? trailingIcon;

    if (hasAnswered) {
      if (option.isCorrect) {
        // Correct answer is always green
        backgroundColor = Colors.green.withAlpha(35);
        borderColor = Colors.green;
        trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
      } else if (selectedOption == option) {
        // Wrong answer selected by user is red
        backgroundColor = Colors.red.withAlpha(35);
        borderColor = Colors.red;
        trailingIcon = const Icon(Icons.cancel, color: Colors.red);
      } else {
        // Other wrong options dimmed
        backgroundColor = Theme.of(context).colorScheme.surface;
        borderColor = Theme.of(context).colorScheme.outline.withAlpha(40);
      }
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = Theme.of(context).colorScheme.outline.withAlpha(80);
    }

    return Card(
      elevation: hasAnswered && option.isCorrect ? 2 : 0,
      margin: const EdgeInsets.only(bottom: 10.0),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        title: Text(
          option.text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: hasAnswered && option.isCorrect
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        trailing: trailingIcon,
        onTap: hasAnswered ? null : () => controller.selectOption(option),
      ),
    );
  }

  // --- Ringkasan Akhir Kuis ---
  Widget _buildSummaryView(BuildContext context) {
    final total = controller.totalQuestions;
    final score = controller.score;
    final percentage = controller.scorePercentage;
    final wrongList = controller.wrongQuestions;

    final isPerfect = score == total && total > 0;

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                isPerfect ? Icons.military_tech : Icons.assessment_outlined,
                size: 80,
                color: isPerfect ? Colors.amber : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isPerfect ? 'Luar Biasa!' : 'Kuis Selesai',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Skor Anda: $score / $total (${percentage.toStringAsFixed(0)}%)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isPerfect ? Colors.green : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isPerfect
                    ? 'Selamat! Anda menjawab semua kosakata dengan benar.'
                    : 'Terus berlatih untuk menguasai seluruh kosakata di deck ini.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Daftar Soal yang Salah
        if (wrongList.isNotEmpty) ...[
          Text(
            'Kata yang Perlu Diulangi (${wrongList.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
          ),
          const SizedBox(height: 10),
          ...wrongList.map((q) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: Text(
                  q.promptText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Arti benar: ${q.correctText}'),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],

        // Tombol Aksi Akhir
        if (wrongList.isNotEmpty) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.replay),
            label: Text('Ulangi yang Salah (${wrongList.length})'),
            onPressed: () => controller.retryWrongQuestions(),
          ),
          const SizedBox(height: 12),
        ],

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Ulangi Semua Soal'),
          onPressed: () => controller.restartQuiz(),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Selesai & Kembali ke Deck'),
        ),
      ],
    );
  }
}
