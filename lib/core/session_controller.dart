import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SessionController extends GetxController {
  final _box = GetStorage();
  final name = ''.obs;
  final roomCode = RxnString();
  late ThemeMode themeMode;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void onInit() {
    super.onInit();
    name.value = _box.read<String>('name') ?? '';
    roomCode.value = _box.read<String>('room');
    themeMode = switch (_box.read<String>('theme')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<String> ensureAuth() async {
    final user = FirebaseAuth.instance.currentUser ??
        (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null) throw 'Sign-in failed. Check your internet.';
    return user.uid;
  }

  void setName(String v) {
    name.value = v;
    _box.write('name', v);
  }

  void setRoom(String code) {
    roomCode.value = code;
    _box.write('room', code);
  }

  void clearRoom() {
    roomCode.value = null;
    _box.remove('room');
  }

  void toggleTheme() {
    final dark = Get.isDarkMode;
    Get.changeThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
    _box.write('theme', dark ? 'light' : 'dark');
  }
}
