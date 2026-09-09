import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' show Amplitude;
import 'package:uuid/uuid.dart';

import '../models/captura_model.dart';
import '../services/voz_service.dart';
import '../utils/audio_player_utils.dart';
import '../utils/audio_recorder_utils.dart';
import '../utils/constants.dart';
import '../utils/tts_utils.dart';
import 'chat_provider.dart';
import 'conversacion_provider.dart';
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
    this.historialAmplitud = const [],
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

  /// Últimas muestras de amplitud normalizada (0..1) de la grabación en
  /// curso, más recientes al final — alimenta la waveform en vivo
  /// (`UppWaveform`). Buffer acotado a `_maxMuestrasAmplitud`.
  final List<double> historialAmplitud;
  final CapturaModel? ultimaCaptura;
  final String? errorMensaje;

  CapturaUiState copyWith({
    EstadoCapturaUi? estado,
    Duration? duracionGrabacion,
    double? amplitud,
    List<double>? historialAmplitud,
    CapturaModel? ultimaCaptura,
    String? errorMensaje,
  }) {
    return CapturaUiState(
      estado: estado ?? this.estado,
      duracionGrabacion: duracionGrabacion ?? this.duracionGrabacion,
      amplitud: amplitud ?? this.amplitud,
      historialAmplitud: historialAmplitud ?? this.historialAmplitud,
      ultimaCaptura: ultimaCaptura ?? this.ultimaCaptura,
      errorMensaje: errorMensaje,
    );
  }
}

/// Las dos variantes visuales de la pantalla de Captura del diseño "SOMI
/// Voz": `densa` (1a, HUD con waveform y logs) y `radar` (1b, HUD
/// minimalista de anillos concéntricos). Misma data real detrás de las
/// dos — sólo cambia cuánta densidad de información se muestra.
enum VistaCaptura { densa, radar }

/// Preferencia de sesión (no persistida), igual que
/// `ModoStreamingNotifier`: vuelve a `densa` en cada arranque de la app.
class VistaCapturaNotifier extends Notifier<VistaCaptura> {
  @override
  VistaCaptura build() => VistaCaptura.densa;

  void establecer(VistaCaptura valor) => state = valor;
}

final vistaCapturaProvider = NotifierProvider<VistaCapturaNotifier, VistaCaptura>(VistaCapturaNotifier.new);

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
  final TtsUtils _tts = TtsUtils();
  Timer? _timerDuracion;
  StreamSubscription<Amplitude>? _ampSub;
  DateTime? _inicioGrabacion;
  String? _idempotencyKeyActual;

  /// Cantidad de barras de `UppWaveform`: el buffer de amplitud no
  /// necesita guardar más que eso.
  static const int _maxMuestrasAmplitud = 42;

  /// Cuánto se espera a que arranque la reproducción antes de darla por
  /// colgada. Sin esto, un `play()` de `just_audio` que nunca resuelve
  /// (sesión de audio de iOS que no logra activarse) deja el estado en
  /// `hablando` para siempre.
  static const Duration _timeoutInicioReproduccion = Duration(seconds: 10);

  @override
  CapturaUiState build() {
    ref.onDispose(() {
      _timerDuracion?.cancel();
      _ampSub?.cancel();
      _recorder.dispose();
      _player.dispose();
      _tts.dispose();
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
    await _tts.detener();

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
      historialAmplitud: const [],
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

    // 100ms (no 200) para que la waveform (`UppWaveform`) se vea fluida.
    _ampSub = _recorder.ondaAmplitud(intervalo: const Duration(milliseconds: 100)).listen((amp) {
      // `current` viene en dBFS negativos (~-45 silencio, ~0 máximo).
      final normalizado = ((amp.current + 45) / 45).clamp(0.0, 1.0);
      final historial = [...state.historialAmplitud, normalizado];
      if (historial.length > _maxMuestrasAmplitud) {
        historial.removeRange(0, historial.length - _maxMuestrasAmplitud);
      }
      state = state.copyWith(amplitud: normalizado, historialAmplitud: historial);
    });
  }

  Future<void> cancelarGrabacion() async {
    _timerDuracion?.cancel();
    await _ampSub?.cancel();
    await _recorder.cancelar();
    _idempotencyKeyActual = null;
    state = CapturaUiState.inicial();
  }

  Future<void> detenerYEnviar({String origen = 'app'}) async {
    _timerDuracion?.cancel();
    await _ampSub?.cancel();

    final ruta = await _recorder.detener();
    final idempotencyKey = _idempotencyKeyActual;
    if (ruta == null || idempotencyKey == null) {
      state = state.copyWith(estado: EstadoCapturaUi.error, errorMensaje: 'No se pudo grabar el audio');
      return;
    }

    // El grabador puede devolver una ruta "exitosa" que apunta a un
    // archivo vacío (ver docstring de `AudioRecorderUtils`). Si se manda
    // igual, el servidor lo rechaza con un 400 genérico y el error real
    // queda escondido detrás de un mensaje de la API. Mejor cortarlo acá,
    // donde se sabe exactamente qué pasó.
    if (!await archivoDeAudioEsValido(ruta)) {
      unawaited(File(ruta).delete().catchError((_) => File(ruta)));
      _idempotencyKeyActual = null;
      state = state.copyWith(
        estado: EstadoCapturaUi.error,
        errorMensaje: 'No se capturó audio del micrófono',
      );
      return;
    }

    final captura = CapturaModel(
      id: idempotencyKey,
      audioPath: ruta,
      estado: EstadoCaptura.pendiente,
      origen: origen,
      creadaEn: DateTime.now(),
    );
    final cola = ref.read(queueServiceProvider);
    await cola.guardar(captura);
    // `amplitud`/`historialAmplitud` no se resetean solos al dejar de
    // grabar (el stream del mic ya se canceló arriba): sin este reset,
    // la waveform y los anillos del radar quedarían "congelados" a mitad
    // de pulso durante todo el resto del turno.
    state = state.copyWith(
      estado: EstadoCapturaUi.subiendo,
      ultimaCaptura: captura,
      errorMensaje: null,
      amplitud: 0,
      historialAmplitud: const [],
    );

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
        if (resueltaPorWs) {
          // El audio (o su respaldo por TTS) ya se resolvió dentro de
          // `_intentarViaWs`; acá solo hace falta reflejar el estado
          // final, preservando el aviso discreto que haya quedado.
          state = state.copyWith(
            estado: EstadoCapturaUi.inactivo,
            ultimaCaptura: actualizada,
            errorMensaje: state.errorMensaje,
          );
        } else {
          state = state.copyWith(
            estado: EstadoCapturaUi.hablando,
            ultimaCaptura: actualizada,
            errorMensaje: null,
          );
          final audioUrl = actualizada.audioUrl;
          if (audioUrl != null && audioUrl.isNotEmpty) {
            await _reproducirRespuesta(audioUrl);
          } else {
            // El servidor no devolvió `audio_url` en este turno (por
            // ejemplo, una respuesta deduplicada por `idempotency_key`):
            // hablar con TTS local para que la app no quede muda con la
            // nota ya guardada.
            await _hablarConRespaldo(actualizada.respuesta);
          }
          state = state.copyWith(
            estado: EstadoCapturaUi.inactivo,
            ultimaCaptura: actualizada,
            // Se preserva el aviso discreto de reproducción (si lo
            // hubo): `copyWith` no completa `errorMensaje` con `??`, así
            // que sin esto el paso anterior lo pisaría con `null` y el
            // aviso nunca se vería en pantalla.
            errorMensaje: state.errorMensaje,
          );
        }
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

  /// La memoria de conversación tal como la necesita el campo `historial`
  /// de `POST /voz` / `WS /chat`: `{"role": ..., "content": ...}` planos,
  /// sin el modelo local de por medio.
  List<Map<String, dynamic>> _historialParaEnviar() {
    final mensajes = ref.read(conversacionProvider).value ?? const [];
    return mensajes.map((m) => m.toMap()).toList();
  }

  Future<bool> _intentarViaWs(CapturaModel captura) async {
    final settings = ref.read(settingsProvider).value;
    final sincronizador = ref.read(sincronizadorProvider.notifier);
    sincronizador.marcarEnVuelo(captura.id);
    try {
      final resultado = await ref.read(chatProvider.notifier).enviarYEsperar(
            idempotencyKey: captura.id,
            rutaAudio: captura.audioPath,
            personalidad: settings?.personalidad,
            contexto: settings?.contexto,
            historial: _historialParaEnviar(),
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
        toolsEjecutadas: resultado.toolsEjecutadas,
      ));
      await ref.read(conversacionProvider.notifier).registrarTurno(
            resultado.transcripcion,
            resultado.respuesta,
          );

      if (resultado.rutaAudioLocal.isNotEmpty) {
        state = state.copyWith(estado: EstadoCapturaUi.hablando);
        try {
          await _player.reproducirArchivo(resultado.rutaAudioLocal).timeout(_timeoutInicioReproduccion);
        } catch (_) {
          // La nota ya se guardó; que falle el WAV local (cabecera
          // inesperada, cuelgue del player) no puede dejar el turno sin
          // voz: se habla con TTS local.
          state = state.copyWith(
            errorMensaje: 'No se pudo reproducir la voz del servidor, se usó voz local',
          );
          await _hablarConRespaldo(resultado.respuesta);
        }
      } else {
        // El servidor no mandó ningún `audio_chunk` en este turno: sin
        // esto la app queda muda aunque el texto sí se vea.
        await _hablarConRespaldo(resultado.respuesta);
      }
      return true;
    } finally {
      sincronizador.liberar(captura.id);
    }
  }

  Future<void> _reproducirRespuesta(String audioUrlRelativo) async {
    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.tieneToken) return;
    try {
      await _player
          .reproducirUrl(
            url: '${VozService.normalizarBaseUrl(settings.baseUrl)}$audioUrlRelativo',
            token: settings.token!,
          )
          .timeout(_timeoutInicioReproduccion);
    } catch (_) {
      // La nota ya se guardó en el servidor; que falle el audio de vuelta
      // (404 por el TTL de 10 minutos, red cortada, WAV corrupto, o el
      // `play()` de just_audio que se cuelga) no puede dejar la UI
      // trabada. No es un error real de la captura -- la nota se guardó
      // -- así que se avisa discreto y se habla con TTS local en vez de
      // pasar a `EstadoCapturaUi.error`.
      state = state.copyWith(
        errorMensaje: 'No se pudo reproducir la voz del servidor, se usó voz local',
      );
      await _hablarConRespaldo(state.ultimaCaptura?.respuesta);
    }
  }

  /// TTS local de respaldo: se usa en los tres puntos donde hoy puede no
  /// sonar nada aunque la nota sí se haya guardado (ver docstring de la
  /// clase y Fase 1.3 del plan de arreglo del silencio). Respeta el
  /// interruptor de Ajustes: si el usuario lo apagó, la nota se guarda
  /// igual, solo que en silencio.
  Future<void> _hablarConRespaldo(String? texto) async {
    if (texto == null || texto.trim().isEmpty) return;
    final habilitado = ref.read(settingsProvider).value?.ttsLocalHabilitado ?? true;
    if (!habilitado) return;
    try {
      await _tts.hablar(texto);
    } catch (_) {
      // Si ni el TTS local funciona, no queda nada más por hacer: la
      // nota ya se guardó, que es lo que importa.
    }
  }
}

final capturaProvider = NotifierProvider<CapturaNotifier, CapturaUiState>(CapturaNotifier.new);
