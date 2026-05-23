class ApiConfig {
  const ApiConfig._();

  // Production defaults. Can be overridden at build time with:
  // --dart-define=API_BASE_URL=... --dart-define=API_ACCESS_KEY=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bharataiconnect.com',
  );

  static const String apiAccessKey = String.fromEnvironment(
    'API_ACCESS_KEY',
    defaultValue: 'dev-rider-api-key',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
}
