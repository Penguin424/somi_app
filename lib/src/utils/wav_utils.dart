import 'dart:io';
import 'dart:typed_data';

/// Arma un WAV real a partir de los chunks que manda `WS /chat`.
///
/// El primer `audio_chunk` es la cabecera de 44 bytes con tamaños
/// indeterminados (`0xFFFFFFFF`) porque el servidor no sabe la duración
/// final cuando empieza a emitir. Acá se junta esa cabecera con el PCM
/// crudo (16-bit little-endian mono, 24000 Hz) y se parchean los cuatro
/// bytes de `RIFF` y `data` con los tamaños reales, como indica
/// APP_FLUTTER.md.
class WavUtils {
  WavUtils._();

  static Future<File> guardarWavDesdeChunks({
    required List<int> header44,
    required List<List<int>> pcmChunks,
    required String rutaDestino,
  }) async {
    final pcmBytes = pcmChunks.expand((chunk) => chunk).toList(growable: false);
    final headerParcheado = _parchearHeader(
      Uint8List.fromList(header44),
      pcmBytes.length,
    );
    final archivo = File(rutaDestino);
    final sink = archivo.openWrite();
    sink.add(headerParcheado);
    sink.add(pcmBytes);
    await sink.close();
    return archivo;
  }

  static Uint8List _parchearHeader(Uint8List header, int dataLength) {
    final bytes = Uint8List.fromList(header);
    final vista = ByteData.sublistView(bytes);
    if (bytes.length >= 44) {
      // Offset 4: tamaño del chunk RIFF = 36 + tamaño de "data".
      vista.setUint32(4, 36 + dataLength, Endian.little);
      // Offset 40: tamaño del chunk "data".
      vista.setUint32(40, dataLength, Endian.little);
    }
    return bytes;
  }
}
