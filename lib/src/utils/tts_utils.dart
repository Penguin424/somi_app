import 'package:flutter_tts/flutter_tts.dart';

/// Wrapper sobre `flutter_tts`, con la misma forma que `AudioPlayerUtils`.
///
/// Es el respaldo local para cuando el audio del servidor no llega (WS
/// que se corta sin `audio_chunk`, WAV corrupto, 401/404 al bajar la
/// respuesta): sin esto la app se queda completamente muda y en
/// silencio, aunque el texto de la respuesta sí se vea en pantalla.
class TtsUtils {
  final FlutterTts _tts = FlutterTts();
  bool _configurado = false;

  Future<void> _asegurarConfigurado() async {
    if (_configurado) return;
    await _tts.setLanguage('es-MX');
    // Sin esto, `speak()` completa apenas encola el audio en vez de
    // esperar a que termine de sonar, y el `await` de quien llama deja
    // de reflejar la duración real del habla (igual que `play()` de
    // `just_audio`).
    await _tts.awaitSpeakCompletion(true);
    _configurado = true;
  }

  Future<void> hablar(String texto) async {
    if (texto.trim().isEmpty) return;
    await _asegurarConfigurado();
    await _tts.speak(texto);
  }

  Future<void> detener() => _tts.stop();

  void dispose() => _tts.stop();
}
