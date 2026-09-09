import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/tool_ejecutada_model.dart';
import '../services/ws_chat_service.dart';
import '../utils/constants.dart';
import '../utils/wav_utils.dart';
import 'settings_provider.dart';

enum EstadoChat { desconectado, conectando, transcribiendo, pensando, hablando, error }

class ChatUiState {
  const ChatUiState({
    this.estado = EstadoChat.desconectado,
    this.transcripcionParcial = '',
    this.respuestaParcial = '',
    this.herramientaEnCurso,
    this.errorMensaje,
  });

  final EstadoChat estado;
  final String transcripcionParcial;
  final String respuestaParcial;

  /// Nombre de la tool que el orquestador está ejecutando ahora mismo
  /// (entre `tool_inicio` y `tool_fin`). Para que una espera larga se
  /// vea como progreso ("ejecutando capturar_nota") y no como un
  /// cuelgue.
  final String? herramientaEnCurso;
  final String? errorMensaje;

  ChatUiState copyWith({
    EstadoChat? estado,
    String? transcripcionParcial,
    String? respuestaParcial,
    String? herramientaEnCurso,
    String? errorMensaje,
  }) {
    return ChatUiState(
      estado: estado ?? this.estado,
      transcripcionParcial: transcripcionParcial ?? this.transcripcionParcial,
      respuestaParcial: respuestaParcial ?? this.respuestaParcial,
      herramientaEnCurso: herramientaEnCurso,
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
    this.toolsEjecutadas = const [],
  });

  final String transcripcion;
  final String respuesta;
  final String rutaAudioLocal;
  final List<ToolEjecutadaModel> toolsEjecutadas;
}

/// Maneja el turno por `WS /chat` (modo "tiempo real", beta).
///
/// El audio no se streamea en vivo mientras se graba: se graba primero a
/// un archivo (m4a/AAC) igual que en el camino simple, y ese archivo se
/// manda partido en chunks por el socket. Esto evita el problema de
/// codificar en tiempo real y sigue el mismo patrón que usan los scripts
/// de prueba del servidor (`probar_ws_audio.py`).
///
/// Si el WS falla a mitad de turno, `enviarYEsperar` devuelve `null` y
/// quien llama puede caer a `POST /voz` con la misma `idempotency_key`
/// sin miedo a duplicar la nota (ver "Idempotencia" en APP_FLUTTER.md).
class ChatNotifier extends Notifier<ChatUiState> {
  final WsChatService _servicio = WsChatService();
  StreamSubscription<WsEvent>? _eventosSub;
  StreamSubscription<void>? _cierreSub;
  Timer? _timerInactividad;
  Timer? _timerTopeGlobal;
  Completer<ResultadoChatWs?>? _completerTurno;

  @override
  ChatUiState build() {
    ref.onDispose(() {
      _eventosSub?.cancel();
      _cierreSub?.cancel();
      _timerInactividad?.cancel();
      _timerTopeGlobal?.cancel();
      _servicio.dispose();
    });
    return const ChatUiState();
  }

  /// Reinicia el plazo de inactividad del turno en curso. Se llama desde
  /// cada evento real del servidor (`transcripcion`, `token`,
  /// `tool_inicio`, `tool_fin`, `audio_chunk`); a propósito **no** se
  /// llama desde `ping`, que llega cada [AppConstants.pingInterval] sin
  /// importar si el turno sigue vivo — contarlo mantendría un turno
  /// muerto esperando para siempre.
  void _reiniciarInactividad() {
    _timerInactividad?.cancel();
    _timerInactividad = Timer(AppConstants.wsInactividadTimeout, _completarPorTimeout);
  }

  void _completarPorTimeout() {
    final completer = _completerTurno;
    if (completer != null && !completer.isCompleted) completer.complete(null);
  }

  Future<ResultadoChatWs?> enviarYEsperar({
    required String idempotencyKey,
    required String rutaAudio,
    String? personalidad,
    String? contexto,
    List<Map<String, dynamic>>? historial,
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

    // Sin esperar confirmación (ver docstring de `WsConfigurado`): el
    // orden de mensajes del socket garantiza que el servidor lo procesa
    // antes que los `audio_chunk` que siguen.
    _servicio.enviarConfigurar(personalidad: personalidad, contexto: contexto, historial: historial);

    final completer = Completer<ResultadoChatWs?>();
    _completerTurno = completer;
    final respuestaBuffer = StringBuffer();
    String transcripcion = '';
    final bytesAudioCrudos = <int>[];
    final toolsEjecutadas = <ToolEjecutadaModel>[];

    _timerTopeGlobal = Timer(AppConstants.wsTurnoTimeoutMaximo, _completarPorTimeout);
    _reiniciarInactividad();

    _eventosSub = _servicio.eventos.listen((evento) async {
      switch (evento) {
        case WsTranscripcion(:final texto):
          _reiniciarInactividad();
          transcripcion = texto;
          state = state.copyWith(estado: EstadoChat.transcribiendo, transcripcionParcial: texto);
        case WsToolInicio(:final nombre):
          _reiniciarInactividad();
          state = state.copyWith(estado: EstadoChat.pensando, herramientaEnCurso: nombre);
        case WsToolFin(:final nombre, :final resultado):
          _reiniciarInactividad();
          toolsEjecutadas.add(ToolEjecutadaModel(nombre: nombre, resultado: resultado));
          state = state.copyWith(herramientaEnCurso: null);
        case WsToken(:final texto):
          _reiniciarInactividad();
          respuestaBuffer.write(texto);
          state = state.copyWith(
            estado: EstadoChat.pensando,
            respuestaParcial: respuestaBuffer.toString(),
            herramientaEnCurso: state.herramientaEnCurso,
          );
        case WsAudioChunk(:final data):
          _reiniciarInactividad();
          // No se separa cabecera de PCM acá: no se puede asumir que el
          // primer frame traiga exactamente 44 bytes de cabecera (puede
          // venir partida en dos frames, o pegada al primer PCM). Se
          // junta todo y se busca la cabecera real al final, en
          // `WavUtils.armarWavDesdeBytesCrudos`.
          bytesAudioCrudos.addAll(data);
          state = state.copyWith(estado: EstadoChat.hablando, herramientaEnCurso: state.herramientaEnCurso);
        case WsFin():
          if (completer.isCompleted) return;
          var rutaLocal = '';
          if (bytesAudioCrudos.isNotEmpty) {
            final dir = await getTemporaryDirectory();
            final archivo = await WavUtils.armarWavDesdeBytesCrudos(
              bytes: bytesAudioCrudos,
              rutaDestino: '${dir.path}/respuesta_ws_${DateTime.now().millisecondsSinceEpoch}.wav',
            );
            rutaLocal = archivo.path;
          }
          completer.complete(ResultadoChatWs(
            transcripcion: transcripcion,
            respuesta: respuestaBuffer.toString(),
            rutaAudioLocal: rutaLocal,
            toolsEjecutadas: List.unmodifiable(toolsEjecutadas),
          ));
        case WsErrorEvento(:final mensaje):
          // No cierra el socket: se guarda para mostrarlo, pero se sigue
          // esperando el `fin` del turno.
          state = state.copyWith(errorMensaje: mensaje);
        case WsPing():
          break;
        case WsConfigurado():
          break;
        case WsDesconocido():
          break;
      }
    });

    _cierreSub = _servicio.alCerrarse.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      final bytes = await File(rutaAudio).readAsBytes();
      if (bytes.isEmpty) {
        // No hay chunks que mandar: mandar solo `fin_audio` deja al
        // servidor esperando un turno que nunca llega. Se corta acá y se
        // cae al camino de "el WS falló", que reintenta por POST /voz.
        if (!completer.isCompleted) completer.complete(null);
      } else {
        const tamanoChunk = 16 * 1024;
        for (var i = 0; i < bytes.length; i += tamanoChunk) {
          final fin = (i + tamanoChunk < bytes.length) ? i + tamanoChunk : bytes.length;
          _servicio.enviarAudioChunk(Uint8List.sublistView(bytes, i, fin));
        }
        _servicio.enviarFinAudio(idempotencyKey);
      }
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
    }

    final resultado = await completer.future;
    _timerInactividad?.cancel();
    _timerTopeGlobal?.cancel();
    _completerTurno = null;
    await _servicio.cerrar();
    state = state.copyWith(estado: EstadoChat.desconectado);
    return resultado;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatUiState>(ChatNotifier.new);
