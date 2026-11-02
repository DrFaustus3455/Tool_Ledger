/// Build-time configuration, supplied with `--dart-define`.
///
///   flutter build web --dart-define=DATA_SOURCE=live \
///     --dart-define=API_BASE_URL=https://api.example.com
abstract final class AppConfig {
  static const dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: 'mock',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static bool get useLiveBackend => dataSource == 'live';
}
