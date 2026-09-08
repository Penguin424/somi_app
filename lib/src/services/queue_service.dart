import 'package:hive_flutter/hive_flutter.dart';

import '../models/captura_model.dart';
import '../utils/constants.dart';

/// Persistencia de la cola offline / historial en Hive. Se guarda como
/// `Map<String, dynamic>` plano (vía `CapturaModel.toMap/fromMap`) para no
/// necesitar `TypeAdapter`s generados con `build_runner`.
class QueueService {
  QueueService._();
  static final QueueService instancia = QueueService._();

  Box<Map>? _box;

  Future<Box<Map>> abrirBox() async {
    final actual = _box;
    if (actual != null && actual.isOpen) return actual;
    final box = await Hive.openBox<Map>(AppConstants.hiveBoxCapturas);
    _box = box;
    return box;
  }

  Future<void> guardar(CapturaModel captura) async {
    final box = await abrirBox();
    await box.put(captura.id, captura.toMap());
  }

  Future<void> eliminar(String id) async {
    final box = await abrirBox();
    await box.delete(id);
  }

  CapturaModel? obtener(String id) {
    final map = _box?.get(id);
    if (map == null) return null;
    return CapturaModel.fromMap(Map<String, dynamic>.from(map));
  }

  List<CapturaModel> listar() {
    final box = _box;
    if (box == null) return const [];
    return box.values
        .map((m) => CapturaModel.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
  }

  Stream<BoxEvent> watch() {
    final box = _box;
    if (box == null) {
      throw StateError('Llamar abrirBox() antes de watch()');
    }
    return box.watch();
  }
}
