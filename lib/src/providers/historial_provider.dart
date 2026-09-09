import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/captura_model.dart';
import '../services/queue_service.dart';
import '../services/voz_service.dart';
import '../utils/constants.dart';
import 'conversacion_provider.dart';
import 'settings_provider.dart';

final queueServiceProvider = Provider<QueueService>((ref) => QueueService.instancia);

/// True si el dispositivo tiene alguna conectividad de red. Alimenta el
/// indicador "● ONLINE" de la franja de estado de la UI.
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final actual = await Connectivity().checkConnectivity();
  yield !actual.contains(ConnectivityResult.none);
  await for (final estados in Connectivity().onConnectivityChanged) {
    yield !estados.contains(ConnectivityResult.none);
  }
});

/// Lista reactiva de capturas (cola offline + historial), ordenada de más
/// reciente a más vieja. Se re-emite cada vez que Hive cambia, así que
/// tanto la pantalla de Captura como la de Historial quedan siempre al día
/// sin pedir un refresh manual.
final historialProvider = StreamProvider<List<CapturaModel>>((ref) async* {
  final cola = ref.watch(queueServiceProvider);
  final box = await cola.abrirBox();
  yield cola.listar();
  await for (final _ in box.watch()) {
    yield cola.listar();
  }
});

/// Worker de la cola offline: manda las capturas `pendiente` cuando hay
/// red, con backoff exponencial en los errores reintentables (502 y
/// fallos de red). 400/401/422 no se reintentan: la captura queda
/// `fallida` y se muestra así en Historial, tal como pide APP_FLUTTER.md.
class SincronizadorNotifier extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _conexionSub;
  Timer? _timerReintento;
  final Map<String, int> _proximoIntentoEpochMs = {};

  /// Ids con un envío realmente en curso ahora mismo (por WS o por este
  /// notifier), sea quien sea quien lo esté haciendo. Evita que
  /// `sincronizarTodas` dispare un `POST /voz` concurrente con un turno
  /// WS que todavía sigue vivo — la causa de los dos envíos con la misma
  /// `idempotency_key` que pisaban `audioUrl` entre sí.
  final Set<String> _enVuelo = {};

  /// Cuándo (epoch ms) este notifier marcó cada captura como `enviando`.
  /// Si un id de `enviando` no está acá, es que venía de una sesión
  /// anterior (la app se cerró a mitad de un envío) y no hay forma de
  /// saber su edad real: se trata como viejo y se deja reintentar.
  final Map<String, int> _enviandoDesdeEpochMs = {};

  @override
  bool build() {
    ref.onDispose(() {
      _conexionSub?.cancel();
      _timerReintento?.cancel();
    });
    _conexionSub = Connectivity().onConnectivityChanged.listen((estados) {
      if (!estados.contains(ConnectivityResult.none)) {
        sincronizarTodas();
      }
    });
    _timerReintento = Timer.periodic(const Duration(seconds: 15), (_) => sincronizarTodas());
    return false;
  }

  /// Marca `id` como en vuelo. Lo usa `captura_provider._intentarViaWs`
  /// antes de abrir el WS, para que el sincronizador periódico no le pise
  /// el turno con un `POST /voz` concurrente.
  void marcarEnVuelo(String id) => _enVuelo.add(id);

  /// Libera `id`. Debe llamarse siempre, incluso si el envío por WS
  /// falló, o el id queda bloqueado para el sincronizador para siempre.
  void liberar(String id) => _enVuelo.remove(id);

  bool _enviandoEsViejo(CapturaModel c) {
    if (c.estado != EstadoCaptura.enviando) return false;
    final desde = _enviandoDesdeEpochMs[c.id];
    if (desde == null) return true;
    final edad = DateTime.now().millisecondsSinceEpoch - desde;
    return edad >= AppConstants.wsTurnoTimeoutMaximo.inMilliseconds;
  }

  Future<void> sincronizarTodas() async {
    if (state) return; // ya hay una sincronización en curso
    final cola = ref.read(queueServiceProvider);
    final pendientes = cola
        .listar()
        .where((c) => !_enVuelo.contains(c.id))
        .where((c) => c.estado == EstadoCaptura.pendiente || _enviandoEsViejo(c))
        .where((c) => _tocaReintentar(c.id))
        .toList();
    if (pendientes.isEmpty) return;

    state = true;
    for (final captura in pendientes) {
      await sincronizarUna(captura.id);
    }
    state = false;
  }

  bool _tocaReintentar(String id) {
    final proximo = _proximoIntentoEpochMs[id];
    if (proximo == null) return true;
    return DateTime.now().millisecondsSinceEpoch >= proximo;
  }

  /// Relee `id` en Hive y aplica `f` sobre ese registro **fresco**, no
  /// sobre un snapshot viejo. Reutilizado por cada escritura de
  /// `sincronizarUna`: sin esto, dos envíos concurrentes de la misma
  /// captura pueden pisarse con `copyWith` sobre datos ya viejos y perder
  /// la respuesta buena.
  Future<void> _actualizar(String id, CapturaModel Function(CapturaModel actual) f) async {
    final cola = ref.read(queueServiceProvider);
    final fresco = cola.obtener(id);
    if (fresco == null) return; // se borró mientras tanto
    await cola.guardar(f(fresco));
  }

  Future<void> sincronizarUna(String id) async {
    if (_enVuelo.contains(id)) return; // ya se está mandando ahora mismo
    final cola = ref.read(queueServiceProvider);
    final captura = cola.obtener(id);
    if (captura == null || captura.estado == EstadoCaptura.enviada) return;

    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.tieneToken) {
      return; // sin token configurado todavía, no tiene sentido intentar
    }

    _enVuelo.add(id);
    _enviandoDesdeEpochMs[id] = DateTime.now().millisecondsSinceEpoch;
    try {
      await _actualizar(id, (fresco) => fresco.copyWith(estado: EstadoCaptura.enviando));

      try {
        final mensajesMemoria = ref.read(conversacionProvider).value ?? const [];
        final respuesta = await ref.read(vozServiceProvider).enviarVoz(
              baseUrl: settings.baseUrl,
              token: settings.token!,
              audio: File(captura.audioPath),
              idempotencyKey: captura.id,
              personalidad: settings.personalidad,
              contexto: settings.contexto,
              historial: mensajesMemoria.map((m) => m.toMap()).toList(),
            );
        await _actualizar(id, (fresco) {
          // Preservar lo que ya se ganó: si esta respuesta viene vacía
          // (por ejemplo, una respuesta deduplicada del servidor por
          // `idempotency_key`) pero el registro fresco ya tiene el dato
          // bueno de otro envío, no lo pisamos con vacío.
          return fresco.copyWith(
            estado: EstadoCaptura.enviada,
            transcripcion: respuesta.transcripcion.isNotEmpty ? respuesta.transcripcion : fresco.transcripcion,
            respuesta: respuesta.respuesta.isNotEmpty ? respuesta.respuesta : fresco.respuesta,
            audioUrl: respuesta.audioUrl.isNotEmpty ? respuesta.audioUrl : fresco.audioUrl,
            toolsEjecutadas: respuesta.toolsEjecutadas.isNotEmpty ? respuesta.toolsEjecutadas : fresco.toolsEjecutadas,
          );
        });
        if (respuesta.transcripcion.isNotEmpty || respuesta.respuesta.isNotEmpty) {
          await ref.read(conversacionProvider.notifier).registrarTurno(
                respuesta.transcripcion,
                respuesta.respuesta,
              );
        }
        _proximoIntentoEpochMs.remove(id);
      } on VozServiceException catch (e) {
        final intentos = captura.intentos + 1;
        if (e.reintentable) {
          _programarReintento(id, intentos);
          await _actualizar(id, (fresco) => fresco.copyWith(
                estado: EstadoCaptura.pendiente,
                intentos: intentos,
                errorMensaje: e.mensaje,
              ));
        } else {
          _proximoIntentoEpochMs.remove(id);
          await _actualizar(id, (fresco) => fresco.copyWith(
                estado: EstadoCaptura.fallida,
                intentos: intentos,
                errorMensaje: e.mensaje,
              ));
        }
      } catch (e) {
        final intentos = captura.intentos + 1;
        _programarReintento(id, intentos);
        await _actualizar(id, (fresco) => fresco.copyWith(
              estado: EstadoCaptura.pendiente,
              intentos: intentos,
              errorMensaje: 'Error inesperado: $e',
            ));
      }
    } finally {
      _enVuelo.remove(id);
      _enviandoDesdeEpochMs.remove(id);
    }
  }

  void _programarReintento(String id, int intentos) {
    final espera = AppConstants.retryBackoff[
        (intentos - 1).clamp(0, AppConstants.retryBackoff.length - 1)];
    _proximoIntentoEpochMs[id] = DateTime.now().add(espera).millisecondsSinceEpoch;
  }
}

final sincronizadorProvider = NotifierProvider<SincronizadorNotifier, bool>(SincronizadorNotifier.new);
