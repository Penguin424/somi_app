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

  /// Plazo de inactividad de un turno por `WS /chat`: se reinicia con
  /// cada evento real del servidor (`transcripcion`, `token`,
  /// `tool_inicio`, `tool_fin`, `audio_chunk`). `ping` no cuenta como
  /// actividad (viene cada [pingInterval] sin importar si el turno sigue
  /// vivo). Antes había un único timeout de 20s para todo el turno, que
  /// no toleraba el tool calling normal del LLM.
  static const Duration wsInactividadTimeout = Duration(seconds: 25);

  /// Tope global de un turno por WS, sin importar la actividad: guarda
  /// de seguridad para no quedar esperando para siempre si el servidor
  /// manda actividad pero nunca termina. Alineado con
  /// [maxRecordingDuration].
  static const Duration wsTurnoTimeoutMaximo = Duration(minutes: 3);

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
