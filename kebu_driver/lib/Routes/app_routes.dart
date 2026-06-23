import 'package:get/get.dart';
import 'package:kebu_driver/Screens/SplashScreen/SplashBinding.dart';
import 'package:kebu_driver/Screens/SplashScreen/splash_screen.dart';


class AppRoutes {
  static String initialRoute = '/initialRoute';

  static List<GetPage> pages = [
    GetPage(
      name: initialRoute,
      page: () => const SplashScreen(),
      bindings: [
        SplashBinding(),
      ],
      transition: Transition.rightToLeft,
      //transitionDuration: Duration(seconds: 2),
    ),
  ];
}
