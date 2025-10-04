// lib/core/config/config.dart
class AppConfig {
  // Falls back to the hardcoded default if not provided at build/run time
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'https://0510f2f99bd7.ngrok-free.app');
}

//ngrok http 8080
