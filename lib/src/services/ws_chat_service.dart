import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';

import '../utils/constants.dart';

/// Eventos que puede mandar el servidor por `WS /chat`. `sealed` para que
/// el `switch` en el consumidor sea exhaustivo.
sealed class WsEvent {
  const WsEvent();
}

class WsTranscripcion extends WsEvent {
  const WsTranscripcion(this.texto);
  final String texto;
}

class WsToken extends WsEvent {
  const WsToken(this.texto);
  final String texto;
}

class WsToolInicio extends WsEvent {
  const WsToolInicio(this.nombre);
  final String nombre;
}

class WsToolFin extends WsEvent {
  const WsToolFin(this.nombre, this.resultado);
  final String nombre;
  final Map<String, dynamic> resultado;
}

class WsAudioChunk extends WsEvent {
  const WsAudioChunk(this.data);
  final Uint8List data;
}

class WsFin extends WsEvent {
  const WsFin();
}

class WsErrorEvento extends WsEvent {
  const WsErrorEvento(this.mensaje);
  final String mensaje;
}

class WsPing extends WsEvent {
  const WsPing();
}

class WsDesconocido extends WsEvent {
  const WsDesconocido();
}

WsEvent parsearEventoWs(Map<String, dynamic> json) {
  switch (json['tipo']) {
    case 'transcripcion':
      return WsTranscripcion(json['texto'] as String? ?? '');
    case 'token':
      return WsToken(json['texto'] as String? ?? '');
    case 'tool_inicio':
      return WsToolInicio(json['nombre'] as String? ?? '');
    case 'tool_fin':
      return WsToolFin(
        json['nombre'] as String? ?? '',
        Map<String, dynamic>.from(json['resultado'] as Map? ?? {}),
      );
    case 'audio_chunk':
      return WsAudioChunk(base64Decode(json['data'] as String? ?? ''));
    case 'fin':
      return const WsFin();
    case 'error':
      return WsErrorEvento(json['mensaje'] as String? ?? 'Error desconocido');
    case 'ping':
      // Mensaje de aplicación, no un frame de protocolo WS: se ignora
      // igual que cualquier tipo no reconocido.
      return const WsPing();
    default:
      return const WsDesconocido();
  }
}

/// Cliente delgado de `WS /chat`. No reconecta ni reintenta por su
/// cuenta: eso lo maneja quien lo usa (ver `ChatNotifier`), porque un
/// `error` del servidor no cierra el socket y no hay que confundir eso
/// con una desconexión real.
class WsChatService {
  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  final StreamController<WsEvent> _eventos = StreamController<WsEvent>.broadcast();
  final StreamController<void> _cerrado = StreamController<void>.broadcast();

  Stream<WsEvent> get eventos => _eventos.stream;
  Stream<void> get alCerrarse => _cerrado.stream;
  bool get conectado => _channel != null;

  Future<void> conectar({required String baseUrl, required String token}) async {
    var wsBase = baseUrl.trim();
    while (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }
    wsBase = wsBase.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/chat');
    final canal = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $token'},
      // Sin timeout, un handshake que no avanza deja el turno colgado.
      connectTimeout: const Duration(seconds: 10),
      // Ping del lado cliente, además del que manda el servidor cada 30s.
      pingInterval: AppConstants.pingInterval,
    );
    await canal.ready;
    _channel = canal;
    _sub = canal.stream.listen(
      (mensaje) {
        try {
          final json = jsonDecode(mensaje as String) as Map<String, dynamic>;
          _eventos.add(parsearEventoWs(json));
        } catch (_) {
          // Mensaje no JSON o malformado: se ignora en vez de romper.
        }
      },
      onDone: () {
        _channel = null;
        _cerrado.add(null);
      },
      onError: (_) {
        _channel = null;
        _cerrado.add(null);
      },
      cancelOnError: false,
    );
  }

  void enviarAudioChunk(Uint8List bytes) {
    _channel?.sink.add(jsonEncode({'tipo': 'audio_chunk', 'data': base64Encode(bytes)}));
  }

  void enviarFinAudio(String idempotencyKey) {
    _channel?.sink.add(jsonEncode({'tipo': 'fin_audio', 'idempotency_key': idempotencyKey}));
  }

  void enviarTexto(String contenido, String idempotencyKey) {
    _channel?.sink.add(jsonEncode({
      'tipo': 'texto',
      'contenido': contenido,
      'idempotency_key': idempotencyKey,
    }));
  }

  Future<void> cerrar() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    cerrar();
    _eventos.close();
    _cerrado.close();
  }
}
