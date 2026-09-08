import 'tool_ejecutada_model.dart';

/// Estado de una captura en la cola offline / historial.
enum EstadoCaptura { pendiente, enviando, enviada, fallida }

/// Una captura de voz, de punta a punta: desde que se graba hasta que el
/// servidor responde (o falla). Es el objeto que vive en Hive y alimenta
/// tanto la cola offline como el Historial.
///
/// `id` es el `idempotency_key`: se genera al **crear** la captura, no al
/// enviarla, para que un reintento de red nunca duplique la nota (ver
/// "Idempotencia" en APP_FLUTTER.md).
class CapturaModel {
  const CapturaModel({
    required this.id,
    required this.audioPath,
    required this.estado,
    required this.contexto,
    required this.creadaEn,
    this.transcripcion,
    this.respuesta,
    this.audioUrl,
    this.toolsEjecutadas = const [],
    this.errorMensaje,
    this.intentos = 0,
  });

  final String id;
  final String audioPath;
  final EstadoCaptura estado;

  /// "app" o "widget", según de dónde salió la captura.
  final String contexto;

  final DateTime creadaEn;
  final String? transcripcion;
  final String? respuesta;
  final String? audioUrl;
  final List<ToolEjecutadaModel> toolsEjecutadas;
  final String? errorMensaje;
  final int intentos;

  CapturaModel copyWith({
    String? audioPath,
    EstadoCaptura? estado,
    String? contexto,
    String? transcripcion,
    String? respuesta,
    String? audioUrl,
    List<ToolEjecutadaModel>? toolsEjecutadas,
    String? errorMensaje,
    int? intentos,
  }) {
    return CapturaModel(
      id: id,
      audioPath: audioPath ?? this.audioPath,
      estado: estado ?? this.estado,
      contexto: contexto ?? this.contexto,
      creadaEn: creadaEn,
      transcripcion: transcripcion ?? this.transcripcion,
      respuesta: respuesta ?? this.respuesta,
      audioUrl: audioUrl ?? this.audioUrl,
      toolsEjecutadas: toolsEjecutadas ?? this.toolsEjecutadas,
      errorMensaje: errorMensaje,
      intentos: intentos ?? this.intentos,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'audioPath': audioPath,
        'estado': estado.name,
        'contexto': contexto,
        'creadaEn': creadaEn.toIso8601String(),
        'transcripcion': transcripcion,
        'respuesta': respuesta,
        'audioUrl': audioUrl,
        'toolsEjecutadas': toolsEjecutadas.map((t) => t.toMap()).toList(),
        'errorMensaje': errorMensaje,
        'intentos': intentos,
      };

  factory CapturaModel.fromMap(Map<String, dynamic> map) {
    return CapturaModel(
      id: map['id'] as String,
      audioPath: map['audioPath'] as String? ?? '',
      estado: EstadoCaptura.values.byName(map['estado'] as String? ?? 'pendiente'),
      contexto: map['contexto'] as String? ?? 'app',
      creadaEn: DateTime.parse(map['creadaEn'] as String),
      transcripcion: map['transcripcion'] as String?,
      respuesta: map['respuesta'] as String?,
      audioUrl: map['audioUrl'] as String?,
      toolsEjecutadas: ((map['toolsEjecutadas'] as List?) ?? [])
          .map((t) => ToolEjecutadaModel.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
      errorMensaje: map['errorMensaje'] as String?,
      intentos: map['intentos'] as int? ?? 0,
    );
  }
}
