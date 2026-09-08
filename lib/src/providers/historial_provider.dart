import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/captura_model.dart';
import '../services/queue_service.dart';
import '../services/voz_service.dart';
import '../utils/constants.dart';
import 'settings_provider.dart';

final queueServiceProvider = Provider<QueueService>((ref) => QueueService.instancia);

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

  Future<void> sincronizarTodas() async {
    if (state) return; // ya hay una sincronización en curso
    final cola = ref.read(queueServiceProvider);
    final pendientes = cola
        .listar()
        .where((c) => c.estado == EstadoCaptura.pendiente || c.estado == EstadoCaptura.enviando)
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

  Future<void> sincronizarUna(String id) async {
    final cola = ref.read(queueServiceProvider);
    final captura = cola.obtener(id);
    if (captura == null || captura.estado == EstadoCaptura.enviada) return;

    final settings = ref.read(settingsProvider).value;
    if (settings == null || !settings.tieneToken) {
      return; // sin token configurado todavía, no tiene sentido intentar
    }

    await cola.guardar(captura.copyWith(estado: EstadoCaptura.enviando));

    try {
      final respuesta = await ref.read(vozServiceProvider).enviarVoz(
            baseUrl: settings.baseUrl,
            token: settings.token!,
            audio: File(captura.audioPath),
            idempotencyKey: captura.id,
            contexto: captura.contexto,
          );
      await cola.guardar(captura.copyWith(
        estado: EstadoCaptura.enviada,
        transcripcion: respuesta.transcripcion,
        respuesta: respuesta.respuesta,
        audioUrl: respuesta.audioUrl,
        toolsEjecutadas: respuesta.toolsEjecutadas,
      ));
      _proximoIntentoEpochMs.remove(id);
    } on VozServiceException catch (e) {
      final intentos = captura.intentos + 1;
      if (e.reintentable) {
        _programarReintento(id, intentos);
        await cola.guardar(captura.copyWith(
          estado: EstadoCaptura.pendiente,
          intentos: intentos,
          errorMensaje: e.mensaje,
        ));
      } else {
        _proximoIntentoEpochMs.remove(id);
        await cola.guardar(captura.copyWith(
          estado: EstadoCaptura.fallida,
          intentos: intentos,
          errorMensaje: e.mensaje,
        ));
      }
    } catch (e) {
      final intentos = captura.intentos + 1;
      _programarReintento(id, intentos);
      await cola.guardar(captura.copyWith(
        estado: EstadoCaptura.pendiente,
        intentos: intentos,
        errorMensaje: 'Error inesperado: $e',
      ));
    }
  }

  void _programarReintento(String id, int intentos) {
    final espera = AppConstants.retryBackoff[
        (intentos - 1).clamp(0, AppConstants.retryBackoff.length - 1)];
    _proximoIntentoEpochMs[id] = DateTime.now().add(espera).millisecondsSinceEpoch;
  }
}

final sincronizadorProvider = NotifierProvider<SincronizadorNotifier, bool>(SincronizadorNotifier.new);
