/// Un turno de la memoria de conversación que se manda como `historial` en
/// `POST /voz` / `WS /chat`. `rol` es `user` o `assistant` — los únicos
/// dos que acepta el orquestador (`entrada.py::normalizar_historial`
/// descarta cualquier otro, así que no tiene sentido modelar más acá).
class MensajeConversacionModel {
  const MensajeConversacionModel({required this.rol, required this.contenido});

  final String rol;
  final String contenido;

  Map<String, dynamic> toMap() => {'role': rol, 'content': contenido};

  factory MensajeConversacionModel.fromMap(Map<String, dynamic> map) {
    return MensajeConversacionModel(
      rol: map['role'] as String? ?? 'user',
      contenido: map['content'] as String? ?? '',
    );
  }
}
