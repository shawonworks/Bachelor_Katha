import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/session_controller.dart';
import '../../core/utils.dart';
import '../../data/firestore_service.dart';

class HomeController extends GetxController {
  final session = Get.find<SessionController>();
  final _svc = Get.find<FirestoreService>();

  final roomNameC = TextEditingController();
  final codeC = TextEditingController();
  final creating = false.obs;
  final joining = false.obs;

  Future<void> create() async {
    final name = roomNameC.text.trim();
    if (name.length < 2) {
      Toast.err('Enter a room name.');
      return;
    }
    creating.value = true;
    String? code;
    try {
      final uid = await session.ensureAuth();
      code = await _svc.createRoom(name: name, uid: uid, userName: session.name.value);
    } catch (e) {
      Toast.error(e);
    }
    creating.value = false;
    if (code != null) _enter(code);
  }

  Future<void> join() async {
    final code = codeC.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      Toast.err('Enter the 6-digit room code.');
      return;
    }
    joining.value = true;
    var ok = false;
    try {
      final uid = await session.ensureAuth();
      await _svc.joinRoom(code: code, uid: uid, userName: session.name.value);
      ok = true;
    } catch (e) {
      Toast.error(e);
    }
    joining.value = false;
    if (ok) _enter(code);
  }

  void _enter(String code) {
    session.setRoom(code);
    Get.offAllNamed(Routes.dashboard);
  }

  @override
  void onClose() {
    roomNameC.dispose();
    codeC.dispose();
    super.onClose();
  }
}
