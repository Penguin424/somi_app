import 'dart:io';
import 'dart:typed_data';

/// Arma un WAV real a partir de los bytes crudos que manda `WS /chat`
/// como `audio_chunk`.
///
/// No se puede asumir que la cabecera llegue en un chunk propio de
/// exactamente 44 bytes: el servidor puede mandarla partida en dos
/// frames, o pegada al primer PCM en el mismo frame. Por eso acá se
/// junta TODO lo que llegó en el turno y se busca la cabecera real
/// (`RIFF`…`WAVE`…`data`) en el buffer completo, en vez de confiar en
/// los límites de los frames que mandó el socket. Si no aparece una
/// cabecera válida, se trata todo como PCM crudo (16-bit little-endian
/// mono, 24000 Hz, según documenta APP_FLUTTER.md) y se sintetiza una
/// cabecera propia de 44 bytes — mejor eso que un WAV inválido que ni
/// siquiera arranca a reproducirse.
class WavUtils {
  WavUtils._();

  static const int _sampleRateHz = 24000;
  static const int _bitsPorMuestra = 16;
  static const int _canales = 1;

  /// Junta todos los `audio_chunk` de un turno (ya concatenados, sin
  /// separar cabecera de PCM por frame) y arma un `.wav` reproducible.
  static Future<File> armarWavDesdeBytesCrudos({
    required List<int> bytes,
    required String rutaDestino,
  }) async {
    final buffer = Uint8List.fromList(bytes);
    final offsetPcm = _buscarInicioDePcm(buffer);

    final Uint8List header;
    final Uint8List pcm;
    if (offsetPcm != null) {
      pcm = buffer.sublist(offsetPcm);
      header = _parchearHeader(buffer.sublist(0, offsetPcm), pcm.length);
    } else {
      // No se encontró una cabecera WAV reconocible: todo el buffer es
      // PCM crudo.
      pcm = buffer;
      header = _sintetizarHeader(pcm.length);
    }

    final archivo = File(rutaDestino);
    final sink = archivo.openWrite();
    sink.add(header);
    sink.add(pcm);
    await sink.close();
    return archivo;
  }

  /// Busca la marca `data` recorriendo los chunks de una cabecera WAV
  /// real (saltando `fmt ` y cualquier chunk intermedio por su tamaño
  /// declarado, no por un offset fijo) y devuelve dónde empieza el PCM:
  /// justo después de los 4 bytes de tamaño que siguen a `data`. `null`
  /// si no aparece una cabecera reconocible (`RIFF`…`WAVE`…`data`).
  static int? _buscarInicioDePcm(Uint8List buffer) {
    if (buffer.length < 12) return null;
    if (!_coincide(buffer, 0, 'RIFF') || !_coincide(buffer, 8, 'WAVE')) return null;

    var i = 12;
    while (i + 8 <= buffer.length) {
      if (_coincide(buffer, i, 'data')) {
        return i + 8;
      }
      final tamanoChunk = ByteData.sublistView(buffer, i + 4, i + 8).getUint32(0, Endian.little);
      // Los chunks RIFF van alineados a 2 bytes: si el tamaño declarado
      // es impar, hay un byte de relleno antes del próximo chunk.
      final avance = 8 + tamanoChunk + (tamanoChunk.isOdd ? 1 : 0);
      if (avance <= 0) return null; // tamaño corrupto: no seguir buscando en bucle
      i += avance;
    }
    return null;
  }

  static bool _coincide(Uint8List buffer, int offset, String marca) {
    if (offset + marca.length > buffer.length) return false;
    for (var i = 0; i < marca.length; i++) {
      if (buffer[offset + i] != marca.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// El primer `audio_chunk` trae tamaños indeterminados (`0xFFFFFFFF`)
  /// porque el servidor no sabe la duración final cuando empieza a
  /// emitir: acá se parchean con los tamaños reales ya conocidos.
  static Uint8List _parchearHeader(Uint8List header, int dataLength) {
    final bytes = Uint8List.fromList(header);
    if (bytes.length < 44) return bytes; // cabecera degenerada: no tocar
    final vista = ByteData.sublistView(bytes);
    // Offset 4: tamaño del chunk RIFF = tamaño total del archivo - 8.
    vista.setUint32(4, bytes.length + dataLength - 8, Endian.little);
    // Los últimos 4 bytes de la cabecera son siempre el tamaño de
    // "data", sea cual sea el largo real de la cabecera (puede traer
    // chunks intermedios entre `fmt ` y `data`).
    vista.setUint32(bytes.length - 4, dataLength, Endian.little);
    return bytes;
  }

  static Uint8List _sintetizarHeader(int dataLength) {
    final bytes = Uint8List(44);
    final vista = ByteData.sublistView(bytes);

    void escribir(int offset, String valor) {
      for (var i = 0; i < valor.length; i++) {
        bytes[offset + i] = valor.codeUnitAt(i);
      }
    }

    final byteRate = _sampleRateHz * _canales * _bitsPorMuestra ~/ 8;
    final blockAlign = _canales * _bitsPorMuestra ~/ 8;

    escribir(0, 'RIFF');
    vista.setUint32(4, 36 + dataLength, Endian.little);
    escribir(8, 'WAVE');
    escribir(12, 'fmt ');
    vista.setUint32(16, 16, Endian.little); // tamaño del chunk fmt (PCM)
    vista.setUint16(20, 1, Endian.little); // formato 1 = PCM
    vista.setUint16(22, _canales, Endian.little);
    vista.setUint32(24, _sampleRateHz, Endian.little);
    vista.setUint32(28, byteRate, Endian.little);
    vista.setUint16(32, blockAlign, Endian.little);
    vista.setUint16(34, _bitsPorMuestra, Endian.little);
    escribir(36, 'data');
    vista.setUint32(40, dataLength, Endian.little);
    return bytes;
  }
}
