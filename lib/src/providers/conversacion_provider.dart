import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mensaje_conversacion_model.dart';
import '../services/conversacion_service.dart';
import '../utils/constants.dart';

final conversacionServiceProvider =
    Provider<ConversacionService>((ref) => ConversacionService.instancia);

/// Memoria de conversación: los últimos turnos (user/assistant) que se
/// mandan como `historial` en cada `POST /voz` / `WS /chat`, para que
/// "¿y lo de antier?" tenga con qué resolverse. Persistida en Hive
/// (`ConversacionService`), no solo en memoria — sobrevive a cerrar la app.
///
/// `AsyncNotifier` (no `Notifier`) porque la carga inicial desde Hive es
/// async, igual que `SettingsNotifier`.
class ConversacionNotifier extends AsyncNotifier<List<MensajeConversacionModel>> {
  @override
  Future<List<MensajeConversacionModel>> build() {
    return ref.watch(conversacionServiceProvider).leer();
  }

  /// Agrega el par user/assistant de un turno exitoso y recorta a los
  /// últimos `AppConstants.maxMensajesMemoria`. Se llama después de que el
  /// servidor ya respondió — un turno fallido o en cola no entra a la
  /// memoria, porque todavía no hay nada que recordar de él.
  Future<void> registrarTurno(String usuario, String asistente) async {
    if (usuario.trim().isEmpty && asistente.trim().isEmpty) return;
    final actual = state.value ?? const <MensajeConversacionModel>[];
    final actualizado = [
      ...actual,
      MensajeConversacionModel(rol: 'user', contenido: usuario),
      MensajeConversacionModel(rol: 'assistant', contenido: asistente),
    ];
    final recortado = actualizado.length > AppConstants.maxMensajesMemoria
        ? actualizado.sublist(actualizado.length - AppConstants.maxMensajesMemoria)
        : actualizado;
    await ref.read(conversacionServiceProvider).guardar(recortado);
    state = AsyncData(recortado);
  }

  Future<void> limpiar() async {
    await ref.read(conversacionServiceProvider).limpiar();
    state = const AsyncData(<MensajeConversacionModel>[]);
  }
}

final conversacionProvider =
    AsyncNotifierProvider<ConversacionNotifier, List<MensajeConversacionModel>>(
  ConversacionNotifier.new,
);

/// Cantidad de turnos (no de mensajes) en memoria — lo que muestra el `MEM
/// n` de la franja de estado y lo que decide si el botón de borrar hace
/// algo. Provider derivado, no un getter del notifier: así se re-emite
/// solo cuando el estado realmente cambia, sea quien sea quien lo mire.
final conversacionTurnosProvider = Provider<int>((ref) {
  final mensajes = ref.watch(conversacionProvider).value ?? const <MensajeConversacionModel>[];
  return mensajes.length ~/ 2;
});
