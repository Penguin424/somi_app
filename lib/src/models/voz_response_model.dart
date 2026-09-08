import 'tool_ejecutada_model.dart';

/// Respuesta 200 de `POST /voz`, según el contrato de APP_FLUTTER.md.
class VozResponseModel {
  const VozResponseModel({
    required this.transcripcion,
    required this.respuesta,
    required this.toolsEjecutadas,
    required this.audioUrl,
  });

  final String transcripcion;
  final String respuesta;
  final List<ToolEjecutadaModel> toolsEjecutadas;

  /// Ruta relativa (`/audio/<uuid>.wav`): hay que resolverla contra la
  /// base URL antes de reproducirla.
  final String audioUrl;

  factory VozResponseModel.fromMap(Map<String, dynamic> map) {
    return VozResponseModel(
      transcripcion: map['transcripcion'] as String? ?? '',
      respuesta: map['respuesta'] as String? ?? '',
      toolsEjecutadas: ((map['tools_ejecutadas'] as List?) ?? [])
          .map((t) => ToolEjecutadaModel.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
      audioUrl: map['audio_url'] as String? ?? '',
    );
  }
}
