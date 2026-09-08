import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/voz_service.dart';
import '../utils/constants.dart';
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
  });

  final String baseUrl;
  final String? token;
  final bool? servidorOk;
  final bool verificandoServidor;

  /// Motivo concreto del último chequeo de `/health` (por qué falló, o
  /// "Servidor arriba").
  final String? servidorDetalle;

  bool get tieneToken => token != null && token!.isNotEmpty;

  SettingsState copyWith({
    String? baseUrl,
    String? token,
    bool? servidorOk,
    bool? verificandoServidor,
    String? servidorDetalle,
  }) {
    return SettingsState(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      servidorOk: servidorOk ?? this.servidorOk,
      verificandoServidor: verificandoServidor ?? this.verificandoServidor,
      servidorDetalle: servidorDetalle ?? this.servidorDetalle,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final storage = ref.watch(secureStorageProvider);
    final token = await storage.readToken();
    final baseUrl = await storage.readBaseUrl() ?? AppConstants.defaultBaseUrl;
    return SettingsState(baseUrl: baseUrl, token: token);
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
