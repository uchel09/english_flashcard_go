// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';

import '../modules/card_editor/bindings/card_editor_binding.dart';
import '../modules/card_editor/views/card_editor_view.dart';
import '../modules/card_viewer/bindings/card_viewer_binding.dart';
import '../modules/card_viewer/views/card_viewer_view.dart';
import '../modules/deck_detail/bindings/deck_detail_binding.dart';
import '../modules/deck_detail/views/deck_detail_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/onboarding/bindings/onboarding_binding.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/quiz/bindings/quiz_binding.dart';
import '../modules/quiz/views/quiz_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/statistics/bindings/statistics_binding.dart';
import '../modules/statistics/views/statistics_view.dart';
import '../modules/trash/bindings/trash_binding.dart';
import '../modules/trash/views/trash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.DECK_DETAIL,
      page: () => const DeckDetailView(),
      binding: DeckDetailBinding(),
    ),
    GetPage(
      name: _Paths.CARD_VIEWER,
      page: () => const CardViewerView(),
      binding: CardViewerBinding(),
    ),
    GetPage(
      name: _Paths.CARD_EDITOR,
      page: () => const CardEditorView(),
      binding: CardEditorBinding(),
    ),
    GetPage(
      name: _Paths.QUIZ,
      page: () => const QuizView(),
      binding: QuizBinding(),
    ),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: _Paths.TRASH,
      page: () => const TrashView(),
      binding: TrashBinding(),
    ),
    GetPage(
      name: _Paths.STATISTICS,
      page: () => const StatisticsView(),
      binding: StatisticsBinding(),
    ),
    GetPage(
      name: _Paths.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
  ];
}
