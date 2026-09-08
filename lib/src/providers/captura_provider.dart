import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:uuid/uuid.dart';

import '../models/captura_model.dart';
import '../utils/audio_player_utils.dart';
import '../utils/audio_recorder_utils.dart';
import '../utils/constants.dart';
import 'chat_provider.dart';
import 'historial_provider.dart';
import 'settings_provider.dart';

enum EstadoCapturaUi {
  inactivo,
  grabando,
  subiendo,
  transcribiendo,
  pensando,
  hablando,

  /// Guardada en la cola offline: no se pudo mandar ahora, se manda sola
  /// cuando vuelva la red.
  enCola,
  error,
}

class CapturaUiState {
  const CapturaUiState({
    required this.estado,
    required this.duracionGrabacion,
    required this.amplitud,
    this.ultimaCaptura,
    this.errorMensaje,
  });

  factory CapturaUiState.inicial() => const CapturaUiState(
        estado: EstadoCapturaUi.inactivo,
        duracionGrabacion: Duration.zero,
        amplitud: 0,
      );

  final EstadoCapturaUi estado;
  final Duration duracionGrabacion;
  final double amplitud;
  final CapturaModel? ultimaCaptura;
  final String? errorMensaje;

  CapturaUiState copyWith({
    EstadoCapturaUi? estado,
    Duration? duracionGrabacion,
    double? amplitud,
    CapturaModel? ultimaCaptura,
    String? errorMensaje,
  }) {
    return CapturaUiState(
      estado: estado ?? this.estado,
      duracionGrabacion: duracionGrabacion ?? this.duracionGrabacion,
      amplitud: amplitud ?? this.amplitud,
      ultimaCaptura: ultimaCaptura ?? this.ultimaCaptura,
      errorMensaje: errorMensaje,
    );
  }
}

/// Activa/desactiva el modo "tiempo real" (WS) desde la pantalla de
/// Captura. Apagado por defecto: el camino simple (`POST /voz`) es el que
/// da una app usable sin sorpresas (pasos 1-3 de APP_FLUTTER.md).
class ModoStreamingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void establecer(bool valor) => state = valor;
}

final modoStreamingProvider = NotifierProvider<ModoStreamingNotifier, bool>(ModoStreamingNotifier.new);

/// Orquesta todo el flujo de una captura: grabar, guardarla en la cola
/// (offline-safe desde el primer instante), mandarla (por WS si el modo
/// streaming está activo, si no por POST /voz) y reproducir la respuesta.
class CapturaNotifier extends Notifier<CapturaUiState> {
  final AudioRecorderUtils _recorder = AudioRecorderUtils();
  final AudioPlayerUtils _player = AudioPlayerUtils();
  Timer? _timerDuracion;
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _inicioGrabacion;
  String? _idempotencyKeyActual;

  @override
  CapturaUiState build() {
    ref.onDispose(() {
      _timerDuracion?.cancel();
      _ampSub?.cancel();
      _recorder.dispose();
      _player.dispose();
    });
    return CapturaUiState.inicial();
  }

  Future<void> iniciarGrabacion() async {
    final permiso = await _recorder.tienePermiso();
    if (!permiso) {
      state = state.copyWith(estado: EstadoCapturaUi.error, errorMensaje: 'Falta permiso de micrófono');
      return;
    }

    // Si venía sonando la respuesta anterior, se corta: grabar siempre gana.
    await _player.detener();

    _idempotencyKeyActual = const Uuid().v4();
    try {
      await _recorder.iniciar();
    } catch (e) {
      _idempotencyKeyActual = null;
      state = state.copyWith(
        estado: EstadoCapturaUi.error,
        errorMensaje: 'No se pudo iniciar la grabación: $e',
      );
      return;
    }
    _inicioGrabacion = DateTime.now();
    state = state.copyWith(
      estado: EstadoCapturaUi.grabando,
      duracionGrabacion: Duration.zero,
      amplitud: 0,
      errorMensaje: null,
    );

    _timerDuracion = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final inicio = _inicioGrabacion;
      if (inicio == null) return;
      final transcurrido = DateTime.now().difference(inicio);
      state = state.copyWith(duracionGrabacion: transcurrido);
      if (transcurrido >= AppConstants.maxRecordingDuration) {
        detenerYEnviar();
      }
    });

    _ampSub = _recorder.ondaAmplitud().listen((amp) {
      // `current` viene en dBFS negativos (~-45 silencio, ~0 máximo).
      final normalizado = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      state = state.copyWith(amplitud: normalizado);
    });
  }

  Future<void> cancelarGrabacion() async {
    _timerDuracion?.cancel();
    await _ampSub?.cancel();
    await _recorder.cancelar();
    _idempotencyKeyActual = null;
    state = CapturaUiState.inicial();
  }

  Future<void> detenerYEnviar({String contexto = 'app'}) async {
    _timerDuracion?.cancel();
    await _ampSub?.cancel();

    final ruta = await _recorder.detener();
    final idempotencyKey = _idempotencyKeyActual;
    if (ruta == null || idempotencyKey == null) {
      state = state.copyWith(estado: EstadoCapturaUi.error, errorMensaje: 'No se pudo grabar el audio');
      return;
    }

    final captura = CapturaModel(
      id: idempotencyKey,
      audioPath: ruta,
      estado: EstadoCaptura.pendiente,
      contexto: contexto,
      creadaEn: DateTime.now(),
    );
    final cola = ref.read(queueServiceProvider);
    await cola.guardar(captura);
    state = state.copyWith(estado: EstadoCapturaUi.subiendo, ultimaCaptura: captura, errorMensaje: null);

    final usarStreaming = ref.read(modoStreamingProvider);
    var resueltaPorWs = false;
    if (usarStreaming) {
      state = state.copyWith(estado: EstadoCapturaUi.transcribiendo);
      resueltaPorWs = await _intentarViaWs(captura);
    }
    if (!resueltaPorWs) {
      state = state.copyWith(estado: EstadoCapturaUi.subiendo);
      await ref.read(sincronizadorProvider.notifier).sincronizarUna(captura.id);
    }

    _idempotencyKeyActual = null;

    final actualizada = ref.read(queueServiceProvider).obtener(captura.id);
    if (actualizada == null) {
      state = state.copyWith(estado: EstadoCapturaUi.inactivo);
      return;
    }

    // Pase lo que pase, el estado tiene que terminar en uno que deje grabar
    // de nuevo. Quedarse en `hablando` o `subiendo` deja el botón gris para
    // siempre.
    switch (actualizada.estado) {
      case EstadoCaptura.enviada:
        state = state.copyWith(
          estado: EstadoCapturaUi.hablando,
          ultimaCaptura: actualizada,
          errorMensaje: null,
        );
        if (!resueltaPorWs && actualizada.audioUrl != null) {
          await _reproducirRespuesta(actualizada.audioUrl!);
        }
        state = state.copyWith(estado: EstadoCapturaUi.inactivo, ultimaCaptura: actualizada);
      case EstadoCaptura.fallida:
        state = state.copyWith(
          estado: EstadoCapturaUi.error,
          ultimaCaptura: actualizada,
          errorMensaje: actualizada.errorMensaje,
        );
      case EstadoCaptura.pendiente:
      case EstadoCaptura.enviando:
        // No se pudo mandar ahora, pero ya está guardada: el sincronizador
        // la manda sola cuando vuelva la red. La app queda usable.
        state = state.copyWith(
          estado: EstadoCapturaUi.enCola,
          ultimaCaptura: actualizada,
          errorMensaje: actualizada.errorMensaje,
        );
    }
  }

  Future<bool> _intentarViaWs(CapturaModel captura) async {
    final resultado = await ref.read(chatProvider.notifier).enviarYEsperar(
          idempotencyKey: captura.id,
          rutaOpus: captura.audioPath,
        );
    if (resultado == null) {
      // El WS falló a mitad de turno: la captura queda `pendiente` en la
      // cola y el sincronizador la manda por POST /voz con la misma
      // idempotency_key. Es seguro, no duplica la nota.
      return false;
    }

    final cola = ref.read(queueServiceProvider);
    await cola.guardar(captura.copyWith(
      estado: EstadoCaptura.enviada,
      transcripcion: resultado.transcripcion,
      respuesta: resultado.respuesta,
    ));

    if (resultado.rutaAudioLocal.isNotEmpty) {
      state = state.copyWith(estado: EstadoCapturaUi.hablando);
      try {
        await _player.reproducirArchivo(resultado.rutaAudioLocal);
      } catch (_) {
        // Que no se reproduzca el audio no invalida la captura.
      }
    }
    return true;
  }

  Future<void> _reproducirRespuesta(String audioUrlRelativo) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.tieneToken) return;
    try {
      await _player.reproducirUrl(
        url: '${settings.baseUrl}$audioUrlRelativo',
        token: settings.token!,
      );
    } catch (_) {
      // La nota ya se guardó en el servidor; que falle el audio de vuelta
      // (404 por el TTL de 10 minutos, red cortada) no puede dejar la UI
      // trabada.
    }
  }
}

final capturaProvider = NotifierProvider<CapturaNotifier, CapturaUiState>(CapturaNotifier.new);
