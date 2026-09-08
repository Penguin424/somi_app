import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

/// Wrapper sobre `record` para grabar en Opus, como pide APP_FLUTTER.md:
/// 24kbps mono a 24000 Hz (~90KB por 30 segundos, contra ~2.8MB en WAV).
class AudioRecorderUtils {
  final AudioRecorder _recorder = AudioRecorder();

  /// Pide permiso de micrófono. Primero por `permission_handler` (cubre
  /// casos que `record` no maneja en algunas plataformas) y si eso falla,
  /// cae al chequeo propio del plugin.
  Future<bool> tienePermiso() async {
    final estado = await ph.Permission.microphone.request();
    if (estado.isGranted) return true;
    return _recorder.hasPermission();
  }

  Future<bool> estaGrabando() => _recorder.isRecording();

  /// Arranca a grabar en un archivo temporal y devuelve su ruta.
  Future<String> iniciar() async {
    final dir = await getTemporaryDirectory();
    final ruta =
        '${dir.path}/captura_${DateTime.now().millisecondsSinceEpoch}.opus';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 24000,
        numChannels: 1,
        sampleRate: 24000,
      ),
      path: ruta,
    );
    return ruta;
  }

  /// Nivel de audio en vivo, para mostrar feedback visual mientras se graba.
  Stream<Amplitude> ondaAmplitud({
    Duration intervalo = const Duration(milliseconds: 200),
  }) =>
      _recorder.onAmplitudeChanged(intervalo);

  /// Para la grabación y devuelve la ruta del archivo, o null si algo falló.
  Future<String?> detener() => _recorder.stop();

  /// Cancela la grabación en curso y descarta el archivo.
  Future<void> cancelar() => _recorder.cancel();

  void dispose() => _recorder.dispose();
}
