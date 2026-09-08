import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../services/ws_chat_service.dart';
import '../utils/wav_utils.dart';
import 'settings_provider.dart';

enum EstadoChat { desconectado, conectando, transcribiendo, pensando, hablando, error }

class ChatUiState {
  const ChatUiState({
    this.estado = EstadoChat.desconectado,
    this.transcripcionParcial = '',
    this.respuestaParcial = '',
    this.errorMensaje,
  });

  final EstadoChat estado;
  final String transcripcionParcial;
  final String respuestaParcial;
  final String? errorMensaje;

  ChatUiState copyWith({
    EstadoChat? estado,
    String? transcripcionParcial,
    String? respuestaParcial,
    String? errorMensaje,
  }) {
    return ChatUiState(
      estado: estado ?? this.estado,
      transcripcionParcial: transcripcionParcial ?? this.transcripcionParcial,
      respuestaParcial: respuestaParcial ?? this.respuestaParcial,
      errorMensaje: errorMensaje,
    );
  }
}

/// Resultado de un turno completo por WS, ya con el WAV de respuesta
/// armado localmente a partir de los `audio_chunk` acumulados.
class ResultadoChatWs {
  const ResultadoChatWs({
    required this.transcripcion,
    required this.respuesta,
    required this.rutaAudioLocal,
  });

  final String transcripcion;
  final String respuesta;
  final String rutaAudioLocal;
}

/// Maneja el turno por `WS /chat` (modo "tiempo real", beta).
///
/// El audio no se streamea en vivo mientras se graba: se graba primero a
/// un archivo Opus igual que en el camino simple, y ese archivo se manda
/// partido en chunks por el socket. Esto evita el problema de codificar
/// Opus en tiempo real y sigue el mismo patrón que usan los scripts de
/// prueba del servidor (`probar_ws_audio.py`).
///
/// Si el WS falla a mitad de turno, `enviarYEsperar` devuelve `null` y
/// quien llama puede caer a `POST /voz` con la misma `idempotency_key`
/// sin miedo a duplicar la nota (ver "Idempotencia" en APP_FLUTTER.md).
class ChatNotifier extends Notifier<ChatUiState> {
  final WsChatService _servicio = WsChatService();
  StreamSubscription<WsEvent>? _eventosSub;
  StreamSubscription<void>? _cierreSub;

  @override
  ChatUiState build() {
    ref.onDispose(() {
      _eventosSub?.cancel();
      _cierreSub?.cancel();
      _servicio.dispose();
    });
    return const ChatUiState();
  }

  Future<ResultadoChatWs?> enviarYEsperar({
    required String idempotencyKey,
    required String rutaOpus,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.tieneToken) return null;

    await _eventosSub?.cancel();
    await _cierreSub?.cancel();
    await _servicio.cerrar();

    state = state.copyWith(
      estado: EstadoChat.conectando,
      transcripcionParcial: '',
      respuestaParcial: '',
      errorMensaje: null,
    );

    try {
      await _servicio.conectar(baseUrl: settings.baseUrl, token: settings.token!);
    } catch (e) {
      state = state.copyWith(estado: EstadoChat.error, errorMensaje: 'No se pudo conectar: $e');
      return null;
    }

    final completer = Completer<ResultadoChatWs?>();
    final respuestaBuffer = StringBuffer();
    String transcripcion = '';
    Uint8List? header;
    final pcm = <int>[];

    _eventosSub = _servicio.eventos.listen((evento) async {
      switch (evento) {
        case WsTranscripcion(:final texto):
          transcripcion = texto;
          state = state.copyWith(estado: EstadoChat.transcribiendo, transcripcionParcial: texto);
        case WsToolInicio():
          state = state.copyWith(estado: EstadoChat.pensando);
        case WsToolFin():
          break;
        case WsToken(:final texto):
          respuestaBuffer.write(texto);
          state = state.copyWith(estado: EstadoChat.pensando, respuestaParcial: respuestaBuffer.toString());
        case WsAudioChunk(:final data):
          if (header == null) {
            header = data;
          } else {
            pcm.addAll(data);
          }
          state = state.copyWith(estado: EstadoChat.hablando);
        case WsFin():
          if (completer.isCompleted) return;
          var rutaLocal = '';
          final headerActual = header;
          if (headerActual != null) {
            final dir = await getTemporaryDirectory();
            final archivo = await WavUtils.guardarWavDesdeChunks(
              header44: headerActual,
              pcmChunks: [pcm],
              rutaDestino: '${dir.path}/respuesta_ws_${DateTime.now().millisecondsSinceEpoch}.wav',
            );
            rutaLocal = archivo.path;
          }
          completer.complete(ResultadoChatWs(
            transcripcion: transcripcion,
            respuesta: respuestaBuffer.toString(),
            rutaAudioLocal: rutaLocal,
          ));
        case WsErrorEvento(:final mensaje):
          // No cierra el socket: se guarda para mostrarlo, pero se sigue
          // esperando el `fin` del turno.
          state = state.copyWith(errorMensaje: mensaje);
        case WsPing():
          break;
        case WsDesconocido():
          break;
      }
    });

    _cierreSub = _servicio.alCerrarse.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      final bytes = await File(rutaOpus).readAsBytes();
      const tamanoChunk = 16 * 1024;
      for (var i = 0; i < bytes.length; i += tamanoChunk) {
        final fin = (i + tamanoChunk < bytes.length) ? i + tamanoChunk : bytes.length;
        _servicio.enviarAudioChunk(Uint8List.sublistView(bytes, i, fin));
      }
      _servicio.enviarFinAudio(idempotencyKey);
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
    }

    final resultado = await completer.future.timeout(timeout, onTimeout: () => null);
    await _servicio.cerrar();
    state = state.copyWith(estado: EstadoChat.desconectado);
    return resultado;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatUiState>(ChatNotifier.new);
