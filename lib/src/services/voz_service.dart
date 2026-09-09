import 'dart:io';

import 'package:dio/dio.dart';

import '../models/voz_response_model.dart';

/// Error de `VozService`, con la distinción que pide APP_FLUTTER.md para
/// la cola offline: qué vale la pena reintentar y qué no.
///
/// 502 y fallos de red son reintentables (el servidor puede estar
/// reiniciando); 400, 401 y 422 no lo son, porque reintentar no los va a
/// arreglar.
class VozServiceException implements Exception {
  VozServiceException(this.mensaje, {this.statusCode, this.reintentable = false});

  final String mensaje;
  final int? statusCode;
  final bool reintentable;

  @override
  String toString() => 'VozServiceException($statusCode, reintentable=$reintentable): $mensaje';
}

/// Resultado de `GET /health`, con el motivo concreto cuando falla. El
/// booleano solo no alcanza: si el request se queda colgado o el TLS
/// falla, hay que poder verlo desde Ajustes.
class HealthResultado {
  const HealthResultado({required this.ok, required this.detalle});

  final bool ok;
  final String detalle;
}

/// Cliente del contrato HTTP del orquestador (`POST /voz` y `GET /health`).
/// No conoce el token ni la URL base por su cuenta: se los pasan en cada
/// llamada, así el servicio queda fácil de testear y desacoplado de
/// Ajustes.
class VozService {
  VozService(this._dio);

  final Dio _dio;

  /// Sin esto, un socket que no llega a abrirse (IP inalcanzable, WiFi con
  /// aislamiento de clientes, puerto filtrado) deja el request colgado para
  /// siempre: ni error, ni reintento, ni feedback en pantalla.
  static const _connectTimeout = Duration(seconds: 10);

  /// Normaliza la URL base para tolerar que en Ajustes se pegue con "/" al
  /// final. Pública porque `CapturaNotifier` la reusa para armar la URL
  /// del audio de respuesta (`audioUrlRelativo`) sin duplicar la lógica.
  static String normalizarBaseUrl(String baseUrl) {
    var limpia = baseUrl.trim();
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    return limpia;
  }

  Future<HealthResultado> health({required String baseUrl, String? token}) async {
    try {
      final response = await _dio.get(
        '${normalizarBaseUrl(baseUrl)}/health',
        options: Options(
          headers: (token != null && token.isNotEmpty)
              ? {'Authorization': 'Bearer $token'}
              : null,
          connectTimeout: _connectTimeout,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = response.data;
      if (response.statusCode == 200 && data is Map && data['ok'] == true) {
        return const HealthResultado(ok: true, detalle: 'Servidor arriba');
      }
      return HealthResultado(
        ok: false,
        detalle: 'Respuesta inesperada (HTTP ${response.statusCode})',
      );
    } on DioException catch (e) {
      return HealthResultado(ok: false, detalle: detalleDeError(e));
    } catch (e) {
      return HealthResultado(ok: false, detalle: 'Error inesperado: $e');
    }
  }

  /// Traduce un `DioException` a algo que se pueda leer en pantalla y que
  /// diga en qué etapa falló.
  static String detalleDeError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'No se pudo abrir la conexión (timeout). La URL resuelve a una '
            'IP que este dispositivo no alcanza.';
      case DioExceptionType.receiveTimeout:
        return 'Conectó, pero el servidor no respondió a tiempo.';
      case DioExceptionType.sendTimeout:
        return 'Se cortó mientras se enviaba el audio.';
      case DioExceptionType.connectionError:
        return 'Error de conexión: ${e.error ?? e.message}';
      case DioExceptionType.badCertificate:
        return 'El certificado TLS fue rechazado por el dispositivo.';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return 'Request cancelado.';
      case DioExceptionType.transformTimeout:
        return 'Timeout procesando la respuesta.';
      case DioExceptionType.unknown:
        return 'Error desconocido: ${e.error ?? e.message}';
    }
  }

  Future<VozResponseModel> enviarVoz({
    required String baseUrl,
    required String token,
    required File audio,
    required String idempotencyKey,
    String contexto = 'app',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audio.path,
          filename: audio.path.split(Platform.pathSeparator).last,
          // Sin esto Dio manda `application/octet-stream` y el servidor
          // tiene que adivinar el formato por el nombre del archivo.
          contentType: DioMediaType('audio', 'mp4'),
        ),
        'idempotency_key': idempotencyKey,
        'contexto': contexto,
      });
      final response = await _dio.post(
        '${normalizarBaseUrl(baseUrl)}/voz',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: _connectTimeout,
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return VozResponseModel.fromMap(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw _mapearError(e);
    }
  }

  VozServiceException _mapearError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return VozServiceException(detalleDeError(e), reintentable: true);
      case DioExceptionType.badCertificate:
        // Reintentar no lo va a arreglar: es config de TLS del dispositivo.
        return VozServiceException(detalleDeError(e), reintentable: false);
      default:
        break;
    }

    final status = e.response?.statusCode;
    if (status == null) {
      return VozServiceException(e.message ?? 'Error de red', reintentable: true);
    }
    if (status == 502) {
      return VozServiceException(
        'El servidor tuvo un problema temporal (STT, LLM o TTS)',
        statusCode: status,
        reintentable: true,
      );
    }
    if (status == 400 || status == 401 || status == 422) {
      return VozServiceException(
        _mensajeDelServidor(e) ?? _mensajeParaStatus(status),
        statusCode: status,
        reintentable: false,
      );
    }
    return VozServiceException('Error inesperado del servidor', statusCode: status, reintentable: true);
  }

  /// El servidor manda el motivo real en el cuerpo de la respuesta
  /// (`{"detail": ...}` o `{"error": ...}`, según el endpoint). Antes se
  /// descartaba y siempre se mostraba el mismo texto genérico según el
  /// status code, lo que hacía imposible distinguir "audio vacío" de
  /// cualquier otro motivo detrás de un 400.
  String? _mensajeDelServidor(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final valor = data['detail'] ?? data['error'] ?? data['message'];
      if (valor is String && valor.trim().isNotEmpty) return valor;
    } else if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return null;
  }

  String _mensajeParaStatus(int status) {
    switch (status) {
      case 400:
        return 'El audio llegó vacío';
      case 401:
        return 'Token inválido o faltante';
      case 422:
        return 'Faltan datos en la solicitud';
      default:
        return 'Error del servidor ($status)';
    }
  }
}
