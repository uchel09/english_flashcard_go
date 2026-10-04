import 'package:get/get.dart';

import '../controllers/card_viewer_controller.dart';

class CardViewerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CardViewerController>(
      () => CardViewerController(),
    );
  }
}
