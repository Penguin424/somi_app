// Test de arranque. El default de `flutter create` probaba el contador de
// ejemplo, que ya no existe en esta app.
//
// La app real depende de plugins con canales de plataforma (Hive,
// flutter_secure_storage, record) que no están disponibles en el entorno
// de `flutter test` sin mocks, así que no se levanta acá completa. Este
// test queda como smoke test de que el proyecto compila y corre tests;
// un test de widgets en serio necesitaría mockear esos plugins.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
