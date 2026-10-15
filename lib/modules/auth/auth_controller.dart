import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/session_controller.dart';
import '../../core/utils.dart';

class OnboardingController extends GetxController {
  final session = Get.find<SessionController>();
  final nameC = TextEditingController();

  void submit() {
    final n = nameC.text.trim();
    if (n.length < 2) {
      Toast.err('Please enter your name (min 2 letters).');
      return;
    }
    session.setName(n);
    Get.offAllNamed(session.roomCode.value == null ? Routes.home : Routes.dashboard);
  }

  @override
  void onClose() {
    nameC.dispose();
    super.onClose();
  }
}
