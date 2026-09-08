import 'package:just_audio/just_audio.dart';

/// Wrapper sobre `just_audio` para reproducir la respuesta hablada.
///
/// Ojo con el header de auth: sin él, la descarga del WAV de
/// `GET /audio/{nombre}` da 401 **en silencio** (la reproducción
/// simplemente no arranca), según deja documentado APP_FLUTTER.md.
class AudioPlayerUtils {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get estado => _player.playerStateStream;

  /// Reproduce el WAV que devuelve `POST /voz` en `audio_url` (ruta
  /// relativa, resuelta contra la base URL).
  Future<void> reproducirUrl({required String url, required String token}) async {
    final source = AudioSource.uri(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    await _player.setAudioSource(source);
    await _player.play();
  }

  /// Reproduce un WAV ya armado localmente (por ejemplo, el que se junta
  /// a partir de los `audio_chunk` del WebSocket).
  Future<void> reproducirArchivo(String ruta) async {
    await _player.setFilePath(ruta);
    await _player.play();
  }

  Future<void> detener() => _player.stop();

  void dispose() => _player.dispose();
}
