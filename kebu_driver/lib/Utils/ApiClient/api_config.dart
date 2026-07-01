class ApiConfig {
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static const String _localUrl = 'http://192.168.68.113:9060/v1/api';
  static const String _productionUrl = 'https://backend.kebuone.com/v1/api';

  static const String baseUrl = isProduction ? _productionUrl : _localUrl;

  /// Hard ceiling on every HTTP request. Without this, http calls fall back to
  /// the platform's (very long) TCP connect timeout, so an unreachable/slow
  /// backend can hang the splash's blocking dashboard fetch for minutes.
  static const Duration timeout = Duration(seconds: 15);
}
