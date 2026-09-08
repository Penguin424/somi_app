/// Una tool ejecutada por el orquestador durante un turno (ej.
/// `capturar_nota`), tal como viene en `tools_ejecutadas` de `POST /voz`
/// o en `tool_fin` de `WS /chat`.
class ToolEjecutadaModel {
  const ToolEjecutadaModel({required this.nombre, required this.resultado});

  final String nombre;
  final Map<String, dynamic> resultado;

  Map<String, dynamic> toMap() => {'nombre': nombre, 'resultado': resultado};

  factory ToolEjecutadaModel.fromMap(Map<String, dynamic> map) {
    return ToolEjecutadaModel(
      nombre: map['nombre'] as String? ?? '',
      resultado: Map<String, dynamic>.from(map['resultado'] as Map? ?? {}),
    );
  }
}
