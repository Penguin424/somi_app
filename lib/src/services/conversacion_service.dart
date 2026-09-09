import 'package:hive_flutter/hive_flutter.dart';

import '../models/mensaje_conversacion_model.dart';
import '../utils/constants.dart';

/// Persistencia de la memoria de conversación en Hive, en una box propia
/// (`hiveBoxConversacion`) separada de `hiveBoxCapturas` — borrar el
/// contexto nunca debe borrar el registro de notas ya capturadas.
///
/// Se guarda como una única entrada (`_keyMensajes`) con la lista completa,
/// no una entrada por mensaje: es una lista corta y acotada
/// (`AppConstants.maxMensajesMemoria`) que siempre se lee/escribe entera,
/// así que no hace falta el modelo de `QueueService` (una entrada por id).
class ConversacionService {
  ConversacionService._();
  static final ConversacionService instancia = ConversacionService._();

  static const _keyMensajes = 'mensajes';

  Box? _box;

  Future<Box> _abrirBox() async {
    final actual = _box;
    if (actual != null && actual.isOpen) return actual;
    final box = await Hive.openBox(AppConstants.hiveBoxConversacion);
    _box = box;
    return box;
  }

  Future<List<MensajeConversacionModel>> leer() async {
    final box = await _abrirBox();
    final crudo = box.get(_keyMensajes) as List?;
    if (crudo == null) return const [];
    return crudo
        .map((m) => MensajeConversacionModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> guardar(List<MensajeConversacionModel> mensajes) async {
    final box = await _abrirBox();
    await box.put(_keyMensajes, mensajes.map((m) => m.toMap()).toList());
  }

  Future<void> limpiar() async {
    final box = await _abrirBox();
    await box.delete(_keyMensajes);
  }
}
