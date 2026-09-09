import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

/// Wrapper sobre `record` para grabar en AAC/m4a: 32kbps mono a 24000 Hz.
///
/// Antes se grababa en Opus con extensión `.opus`, pero en iOS `record`
/// graba a archivo con `AVAudioRecorder`, que deduce el contenedor de la
/// extensión de la URL — `.opus` no es una extensión que AVFoundation
/// reconozca, así que la grabación nunca arrancaba y el archivo quedaba en
/// 0 bytes sin ningún error visible. m4a/AAC es soportado nativamente por
/// `AVAudioRecorder` (y por Android), así que evita ese problema en todas
/// las plataformas.
class AudioRecorderUtils {
  final AudioRecorder _recorder = AudioRecorder();

  static const String extensionAudio = 'm4a';
  static const String mimeAudio = 'audio/mp4';
  static const int sampleRateHz = 24000;
  static const int bitRateBps = 32000;
  static const int numChannels = 1;

  /// Pide permiso de micrófono. Primero por `permission_handler` (cubre
  /// casos que `record` no maneja en algunas plataformas) y si eso falla,
  /// cae al chequeo propio del plugin.
  Future<bool> tienePermiso() async {
    final estado = await ph.Permission.microphone.request();
    if (estado.isGranted) return true;
    return _recorder.hasPermission();
  }

  Future<bool> estaGrabando() => _recorder.isRecording();

  /// Arranca a grabar y devuelve la ruta del archivo.
  ///
  /// Se graba en el directorio de application support, no en el de caché:
  /// una captura puede quedar horas en la cola offline esperando red
  /// (`queue_service.dart` guarda solo la ruta, no los bytes), y el
  /// directorio de caché es candidato a que el sistema lo vacíe bajo
  /// presión de almacenamiento.
  ///
  /// Lanza si el plugin no confirma que la grabación arrancó: `record`
  /// puede fallar en silencio en iOS (ver docstring de la clase), así que
  /// no basta con que `start()` no lance para confiar en el resultado.
  Future<String> iniciar() async {
    final dir = await getApplicationSupportDirectory();
    final ruta =
        '${dir.path}/captura_${DateTime.now().millisecondsSinceEpoch}.$extensionAudio';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: bitRateBps,
        numChannels: numChannels,
        sampleRate: sampleRateHz,
      ),
      path: ruta,
    );
    if (!await _recorder.isRecording()) {
      throw StateError('El grabador no arrancó (posible problema de audio del dispositivo)');
    }
    return ruta;
  }

  /// Nivel de audio en vivo, para mostrar feedback visual mientras se graba.
  Stream<Amplitude> ondaAmplitud({
    Duration intervalo = const Duration(milliseconds: 200),
  }) =>
      _recorder.onAmplitudeChanged(intervalo);

  /// Para la grabación y devuelve la ruta del archivo, o null si algo falló.
  ///
  /// No valida el contenido del archivo: eso es responsabilidad de quien
  /// llama (`captura_provider.dart`), que decide qué hacer con una captura
  /// vacía en el flujo de UI.
  Future<String?> detener() => _recorder.stop();

  /// Cancela la grabación en curso y descarta el archivo.
  Future<void> cancelar() => _recorder.cancel();

  void dispose() => _recorder.dispose();
}

/// Tamaño mínimo, en bytes, para considerar que un archivo grabado tiene
/// audio real. Un contenedor m4a vacío (sin muestras) pesa unos pocos
/// cientos de bytes; cualquier cosa por debajo de esto es, en la práctica,
/// una grabación que nunca arrancó.
const int tamanoMinimoAudioValido = 1024;

/// True si el archivo en `ruta` existe y tiene contenido de audio real.
Future<bool> archivoDeAudioEsValido(String ruta) async {
  final archivo = File(ruta);
  if (!await archivo.exists()) return false;
  return await archivo.length() >= tamanoMinimoAudioValido;
}
