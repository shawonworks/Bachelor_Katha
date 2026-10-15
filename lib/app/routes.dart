import 'package:get/get.dart';

import '../core/session_controller.dart';
import '../modules/auth/auth_controller.dart';
import '../modules/auth/auth_view.dart';
import '../modules/expense/add_expense_controller.dart';
import '../modules/expense/add_expense_view.dart';
import '../modules/room/dashboard_view.dart';
import '../modules/room/home_controller.dart';
import '../modules/room/home_view.dart';
import '../modules/room/room_controller.dart';
import '../modules/splash/splash_view.dart';
import '../modules/summary/history_view.dart';
import '../modules/summary/summary_view.dart';

abstract class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const dashboard = '/dashboard';
  static const add = '/add';
  static const summary = '/summary';
  static const history = '/history';
}

class AppPages {
  static final pages = <GetPage>[
    GetPage(name: Routes.splash, page: () => const SplashView()),
    GetPage(
      name: Routes.onboarding,
      page: () => const OnboardingView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => OnboardingController())),
    ),
    GetPage(
      name: Routes.home,
      page: () => const HomeView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => HomeController())),
    ),
    GetPage(
      name: Routes.dashboard,
      page: () => const DashboardView(),
      binding: BindingsBuilder(() {
        Get.put(RoomController(Get.find<SessionController>().roomCode.value!));
      }),
    ),
    GetPage(
      name: Routes.add,
      page: () => const AddExpenseView(),
      binding: BindingsBuilder(() => Get.lazyPut(() => AddExpenseController())),
    ),
    GetPage(name: Routes.summary, page: () => const SummaryView()),
    GetPage(name: Routes.history, page: () => const HistoryView()),
  ];
}
