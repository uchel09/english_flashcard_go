import 'package:get/get.dart';

import '../controllers/card_editor_controller.dart';

class CardEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CardEditorController>(
      () => CardEditorController(),
    );
  }
}
