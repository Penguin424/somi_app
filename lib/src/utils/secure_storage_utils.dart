import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper chico sobre `flutter_secure_storage` para el token del
/// orquestador y la URL base. El token nunca se hardcodea ni se commitea.
class SecureStorageUtils {
  SecureStorageUtils({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyToken = 'orquestador_auth_token';
  static const _keyBaseUrl = 'orquestador_base_url';
  static const _keyTtsLocalHabilitado = 'tts_local_habilitado';
  static const _keyPersonalidad = 'somi_personalidad';
  static const _keyContexto = 'somi_contexto';

  Future<String?> readToken() => _storage.read(key: _keyToken);

  Future<void> writeToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  Future<void> deleteToken() => _storage.delete(key: _keyToken);

  Future<String?> readBaseUrl() => _storage.read(key: _keyBaseUrl);

  Future<void> writeBaseUrl(String baseUrl) =>
      _storage.write(key: _keyBaseUrl, value: baseUrl);

  /// `null` si el usuario nunca lo tocó: quien llama decide el default
  /// (activado, ver `SettingsNotifier.build`).
  Future<bool?> readTtsLocalHabilitado() async {
    final valor = await _storage.read(key: _keyTtsLocalHabilitado);
    if (valor == null) return null;
    return valor == 'true';
  }

  Future<void> writeTtsLocalHabilitado(bool habilitado) =>
      _storage.write(key: _keyTtsLocalHabilitado, value: habilitado.toString());

  /// `null` si el usuario nunca lo tocó: `SettingsNotifier.build` decide
  /// el default (`PersonalidadSomi.condensada`).
  Future<String?> readPersonalidad() => _storage.read(key: _keyPersonalidad);

  Future<void> writePersonalidad(String personalidad) =>
      _storage.write(key: _keyPersonalidad, value: personalidad);

  Future<String?> readContexto() => _storage.read(key: _keyContexto);

  Future<void> writeContexto(String contexto) =>
      _storage.write(key: _keyContexto, value: contexto);
}
