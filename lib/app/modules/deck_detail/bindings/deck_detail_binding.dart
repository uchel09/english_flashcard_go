import 'package:get/get.dart';

import '../controllers/deck_detail_controller.dart';

class DeckDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeckDetailController>(
      () => DeckDetailController(),
    );
  }
}
