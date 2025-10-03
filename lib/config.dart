// lib/core/config/config.dart
class AppConfig {
  // Falls back to the hardcoded default if not provided at build/run time
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://c021a4dc3399.ngrok-free.app');
}
