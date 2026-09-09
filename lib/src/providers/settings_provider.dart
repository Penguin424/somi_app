import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/voz_service.dart';
import '../utils/constants.dart';
import '../utils/personalidad_somi.dart';
import '../utils/secure_storage_utils.dart';

final secureStorageProvider = Provider<SecureStorageUtils>((ref) => SecureStorageUtils());

final dioProvider = Provider<Dio>((ref) => Dio());

final vozServiceProvider = Provider<VozService>((ref) => VozService(ref.watch(dioProvider)));

/// URL base + token del orquestador, tal como quedaron guardados en
/// Ajustes (`flutter_secure_storage`), más el último resultado de
/// `GET /health`.
class SettingsState {
  const SettingsState({
    required this.baseUrl,
    this.token,
    this.servidorOk,
    this.verificandoServidor = false,
    this.servidorDetalle,
    this.ttsLocalHabilitado = true,
    this.personalidad = PersonalidadSomi.condensada,
    this.contexto = '',
  });

  final String baseUrl;
  final String? token;
  final bool? servidorOk;
  final bool verificandoServidor;

  /// Motivo concreto del último chequeo de `/health` (por qué falló, o
  /// "Servidor arriba").
  final String? servidorDetalle;

  /// Si está apagado, `CapturaNotifier` nunca habla con `flutter_tts`
  /// aunque el audio del servidor no llegue: la nota se guarda igual,
  /// solo que en silencio. Activado por defecto, es el respaldo que
  /// evita que la app se quede muda.
  final bool ttsLocalHabilitado;

  /// Texto que se suma al system prompt del orquestador (campo
  /// `personalidad` de `POST /voz` / `WS /chat`), no lo reemplaza. String
  /// no nullable a propósito: vacío es un valor válido ("sin personalidad
  /// propia", el comportamiento de antes de esta feature), y `copyWith`
  /// solo distingue "no tocar" con `null` — con String? habría que
  /// inventar otro sentinela para "borrar".
  final String personalidad;

  /// Texto libre de situación (campo `contexto`). Vacío = no mandar nada.
  final String contexto;

  bool get tieneToken => token != null && token!.isNotEmpty;

  SettingsState copyWith({
    String? baseUrl,
    String? token,
    bool? servidorOk,
    bool? verificandoServidor,
    String? servidorDetalle,
    bool? ttsLocalHabilitado,
    String? personalidad,
    String? contexto,
  }) {
    return SettingsState(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      servidorOk: servidorOk ?? this.servidorOk,
      verificandoServidor: verificandoServidor ?? this.verificandoServidor,
      servidorDetalle: servidorDetalle ?? this.servidorDetalle,
      ttsLocalHabilitado: ttsLocalHabilitado ?? this.ttsLocalHabilitado,
      personalidad: personalidad ?? this.personalidad,
      contexto: contexto ?? this.contexto,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final storage = ref.watch(secureStorageProvider);
    final token = await storage.readToken();
    final baseUrl = await storage.readBaseUrl() ?? AppConstants.defaultBaseUrl;
    final ttsLocalHabilitado = await storage.readTtsLocalHabilitado() ?? true;
    final personalidad = await storage.readPersonalidad() ?? PersonalidadSomi.condensada;
    final contexto = await storage.readContexto() ?? '';
    return SettingsState(
      baseUrl: baseUrl,
      token: token,
      ttsLocalHabilitado: ttsLocalHabilitado,
      personalidad: personalidad,
      contexto: contexto,
    );
  }

  Future<void> guardarToken(String token) async {
    await ref.read(secureStorageProvider).writeToken(token);
    final actual = state.value ?? const SettingsState(baseUrl: AppConstants.defaultBaseUrl);
    state = AsyncData(actual.copyWith(token: token));
  }

  Future<void> guardarBaseUrl(String baseUrl) async {
    var limpia = baseUrl.trim();
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    await ref.read(secureStorageProvider).writeBaseUrl(limpia);
    final actual = state.value ?? const SettingsState(baseUrl: AppConstants.defaultBaseUrl);
    state = AsyncData(actual.copyWith(baseUrl: limpia));
  }

  Future<void> establecerTtsLocalHabilitado(bool habilitado) async {
    await ref.read(secureStorageProvider).writeTtsLocalHabilitado(habilitado);
    final actual = state.value ?? const SettingsState(baseUrl: AppConstants.defaultBaseUrl);
    state = AsyncData(actual.copyWith(ttsLocalHabilitado: habilitado));
  }

  Future<void> guardarPersonalidad(String personalidad) async {
    await ref.read(secureStorageProvider).writePersonalidad(personalidad);
    final actual = state.value ?? const SettingsState(baseUrl: AppConstants.defaultBaseUrl);
    state = AsyncData(actual.copyWith(personalidad: personalidad));
  }

  Future<void> guardarContexto(String contexto) async {
    await ref.read(secureStorageProvider).writeContexto(contexto);
    final actual = state.value ?? const SettingsState(baseUrl: AppConstants.defaultBaseUrl);
    state = AsyncData(actual.copyWith(contexto: contexto));
  }

  Future<void> verificarServidor() async {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.copyWith(verificandoServidor: true));
    final resultado = await ref.read(vozServiceProvider).health(
          baseUrl: actual.baseUrl,
          token: actual.token,
        );
    final vigente = state.value ?? actual;
    state = AsyncData(vigente.copyWith(
      servidorOk: resultado.ok,
      servidorDetalle: resultado.detalle,
      verificandoServidor: false,
    ));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
