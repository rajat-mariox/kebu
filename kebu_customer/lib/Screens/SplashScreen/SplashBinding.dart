import 'package:get/get.dart';
import 'package:kebu_customer/Screens/SplashScreen/Controller.dart';


class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SplashController());
  }
}