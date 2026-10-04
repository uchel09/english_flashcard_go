import 'package:get/get.dart';

import '../../../data/repositories/study_log_repository.dart';

class StatisticsController extends GetxController {
  final StudyLogRepository _studyLogRepository;

  StatisticsController({StudyLogRepository? studyLogRepository})
    : _studyLogRepository =
          studyLogRepository ?? Get.find<StudyLogRepository>();

  final RxInt cardsStudiedToday = 0.obs;
  final RxInt totalReviewsToday = 0.obs;
  final RxInt dailyStreak = 0.obs;
  final RxDouble quizAccuracy = 0.0.obs;
  final RxInt totalQuizAnswered = 0.obs;
  final RxInt totalQuizCorrect = 0.obs;
  final RxList<HardestCardModel> hardestCards = <HardestCardModel>[].obs;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadStatistics();
  }

  Future<void> loadStatistics() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      cardsStudiedToday.value = await _studyLogRepository
          .getCardsStudiedTodayCount();
      totalReviewsToday.value = await _studyLogRepository
          .getTotalReviewsTodayCount();
      dailyStreak.value = await _studyLogRepository.getDailyStreak();
      quizAccuracy.value = await _studyLogRepository.getQuizAccuracy();
      totalQuizAnswered.value = await _studyLogRepository
          .getTotalQuizAnswered();
      totalQuizCorrect.value = await _studyLogRepository.getTotalQuizCorrect();

      final hardest = await _studyLogRepository.getHardestCards(limit: 6);
      hardestCards.assignAll(hardest);
    } catch (e) {
      errorMessage.value = 'Gagal memuat statistik belajar: $e';
    } finally {
      isLoading.value = false;
    }
  }
}
