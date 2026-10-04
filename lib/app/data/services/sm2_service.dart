import '../database/app_database.dart';

enum ReviewRating { again, hard, good, easy }

class Sm2ReviewResult {
  final double ease;
  final int intervalDays;
  final DateTime nextReviewAt;
  final int difficulty;

  const Sm2ReviewResult({
    required this.ease,
    required this.intervalDays,
    required this.nextReviewAt,
    required this.difficulty,
  });
}

class Sm2Service {
  /// Memetakan warna kesulitan lama ke nilai ease awal SM-2:
  /// - 1: Mudah (Hijau) -> 2.7
  /// - 2: Sedang (Kuning) -> 2.5
  /// - 3: Sulit (Merah) -> 2.0
  /// - 0: Belum dinilai -> 2.5
  static double getInitialEase(int difficulty) {
    switch (difficulty) {
      case 1:
        return 2.7;
      case 2:
        return 2.5;
      case 3:
        return 2.0;
      case 0:
      default:
        return 2.5;
    }
  }

  /// Menghitung interval estimasi hari untuk ditampilkan di tombol penilaian.
  static int getEstimatedInterval(Card card, ReviewRating rating) {
    double currentEase = card.ease;
    if (card.intervalDays == 0 && card.ease == 2.5 && card.difficulty != 0) {
      currentEase = getInitialEase(card.difficulty);
    }

    switch (rating) {
      case ReviewRating.again:
        return 1;
      case ReviewRating.hard:
        if (card.intervalDays <= 0) return 1;
        if (card.intervalDays == 1) return 2;
        final next = (card.intervalDays * 1.2).round();
        return next <= card.intervalDays ? card.intervalDays + 1 : next;
      case ReviewRating.good:
        if (card.intervalDays <= 0) return 1;
        if (card.intervalDays == 1) return 3;
        final next = (card.intervalDays * currentEase).round();
        return next <= card.intervalDays ? card.intervalDays + 1 : next;
      case ReviewRating.easy:
        final nextEase = (currentEase + 0.15).clamp(1.3, 3.5);
        if (card.intervalDays <= 0) return 3;
        if (card.intervalDays == 1) return 5;
        final next = (card.intervalDays * nextEase * 1.3).round();
        return next <= card.intervalDays ? card.intervalDays + 2 : next;
    }
  }

  /// Format teks hari estimasi untuk tombol (misal: "1 hr", "3 hr").
  static String formatIntervalDays(int days) {
    return '$days hr';
  }

  /// Menghitung ease, interval_days, next_review_at, dan difficulty baru
  /// menggunakan algoritma SM-2 yang disederhanakan.
  static Sm2ReviewResult calculateReview({
    required Card card,
    required ReviewRating rating,
    DateTime? reviewedAt,
  }) {
    final now = reviewedAt ?? DateTime.now();

    // Inisialisasi ease dari tingkat kesulitan lama bila kartu belum pernah direview
    double currentEase = card.ease;
    if (card.intervalDays == 0 && card.ease == 2.5 && card.difficulty != 0) {
      currentEase = getInitialEase(card.difficulty);
    }

    double newEase;
    int newInterval;
    int newDifficulty;

    switch (rating) {
      case ReviewRating.again:
        // Lagi: reset interval ke 1 hari, ease turun 0.20 (min 1.3)
        newEase = (currentEase - 0.20).clamp(1.3, 3.5);
        newInterval = 1;
        newDifficulty = 3; // Sulit (Merah)
        break;

      case ReviewRating.hard:
        // Sulit: ease turun 0.15 (min 1.3), interval bertambah moderat
        newEase = (currentEase - 0.15).clamp(1.3, 3.5);
        if (card.intervalDays <= 0) {
          newInterval = 1;
        } else if (card.intervalDays == 1) {
          newInterval = 2;
        } else {
          newInterval = (card.intervalDays * 1.2).round();
          if (newInterval <= card.intervalDays) {
            newInterval = card.intervalDays + 1;
          }
        }
        newDifficulty = 3; // Sulit (Merah)
        break;

      case ReviewRating.good:
        // Bagus: ease dipertahankan, interval bertambah sesuai ease
        newEase = currentEase.clamp(1.3, 3.5);
        if (card.intervalDays <= 0) {
          newInterval = 1;
        } else if (card.intervalDays == 1) {
          newInterval = 3;
        } else {
          newInterval = (card.intervalDays * newEase).round();
          if (newInterval <= card.intervalDays) {
            newInterval = card.intervalDays + 1;
          }
        }
        newDifficulty = 2; // Sedang (Kuning)
        break;

      case ReviewRating.easy:
        // Mudah: ease bertambah 0.15, interval bertambah cepat dengan bonus 1.3
        newEase = (currentEase + 0.15).clamp(1.3, 3.5);
        if (card.intervalDays <= 0) {
          newInterval = 3;
        } else if (card.intervalDays == 1) {
          newInterval = 5;
        } else {
          newInterval = (card.intervalDays * newEase * 1.3).round();
          if (newInterval <= card.intervalDays) {
            newInterval = card.intervalDays + 2;
          }
        }
        newDifficulty = 1; // Mudah (Hijau)
        break;
    }

    final nextReview = now.add(Duration(days: newInterval));

    return Sm2ReviewResult(
      ease: double.parse(newEase.toStringAsFixed(2)),
      intervalDays: newInterval,
      nextReviewAt: nextReview,
      difficulty: newDifficulty,
    );
  }
}
