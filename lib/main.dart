import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/routes.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'core/session_controller.dart';
import 'data/firestore_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Get.put(FirestoreService(), permanent: true);
  await Get.putAsync(() => NotificationService().init(), permanent: true);
  final session = Get.put(SessionController(), permanent: true);
  try {
    await session.ensureAuth();
  } catch (_) {
    // Offline on first launch: auth is retried when creating/joining a room.
  }

  runApp(BachelorKhataApp(initialRoute: Routes.splash, themeMode: session.themeMode));
}

class BachelorKhataApp extends StatelessWidget {
  const BachelorKhataApp({super.key, required this.initialRoute, required this.themeMode});
  final String initialRoute;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Bachelor Khata',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
