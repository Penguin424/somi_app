/// Constantes de la app. Nada de secretos acá: el token vive en
/// `flutter_secure_storage`, cargado desde la pantalla de Ajustes.
class AppConstants {
  AppConstants._();

  /// Valor por defecto de la URL del orquestador. El usuario puede
  /// cambiarla desde Ajustes si hace falta.
  static const String defaultBaseUrl = 'https://voz.underpenguin.com';

  static const String hiveBoxCapturas = 'capturas';

  static const Duration maxRecordingDuration = Duration(minutes: 5);

  static const Duration pingInterval = Duration(seconds: 30);

  /// Backoff exponencial para reintentos de la cola offline: 2s, 4s, 8s...
  /// hasta un tope de 5 minutos, como pide APP_FLUTTER.md.
  static const List<Duration> retryBackoff = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
    Duration(seconds: 64),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];
}
