import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/theme_controller.dart';
import '../../../routes/app_pages.dart';

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;

  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
  });
}

class OnboardingController extends GetxController {
  late final PageController pageController;
  final RxInt currentPage = 0.obs;

  final List<OnboardingPageData> pages = const [
    OnboardingPageData(
      icon: Icons.style_rounded,
      title: 'Belajar Flashcard Interaktif',
      description:
          'Kuasai kosakata bahasa Inggris lebih cepat dengan kartu bolak-balik dua sisi yang dilengkapi teks, rekaman suara, audio, dan gambar visual.',
    ),
    OnboardingPageData(
      icon: Icons.auto_awesome_rounded,
      title: 'Metode Spaced Repetition (SM-2)',
      description:
          'Sistem pengulangan berkala cerdas menghitung interval belajar Anda secara otomatis (Lagi, Sulit, Bagus, Mudah) agar awet tersimpan dalam ingatan.',
    ),
    OnboardingPageData(
      icon: Icons.offline_pin_rounded,
      title: 'Kuis Pilihan Ganda & 100% Offline',
      description:
          'Uji pemahaman lewat kuis interaktif, pantau statistik harian, dan lakukan pencadangan data kapan saja secara mandiri tanpa butuh internet.',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  void nextPage() {
    if (currentPage.value < pages.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      finishOnboarding();
    }
  }

  Future<void> finishOnboarding() async {
    if (Get.isRegistered<ThemeController>()) {
      await ThemeController.to.completeOnboarding();
    }
    Get.offAllNamed(Routes.HOME);
  }
}
