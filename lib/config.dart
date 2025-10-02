// lib/core/config/config.dart
class AppConfig {
  // Falls back to the hardcoded default if not provided at build/run time
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://8c177b595a2b.ngrok-free.app');
}
