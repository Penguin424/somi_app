import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/providers/historial_provider.dart';
import 'src/screens/captura_screen.dart';
import 'src/theme/upp_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await _configurarSesionDeAudio();
  runApp(const ProviderScope(child: SomiVozApp()));
}

/// Configura la sesión de audio nativa una sola vez al arrancar.
///
/// Sin esto, en iOS la sesión que deja activa `record` (`.playAndRecord`,
/// puesta ahí por el paquete `record` mientras graba) nunca se cierra
/// explícitamente, y `just_audio` cae al fallback `.playback` de
/// `AudioSessionConfiguration.music()`: la app puede quedar ruteada al
/// auricular en vez del altavoz, o bajar el volumen del sistema, al
/// alternar grabación y reproducción en el mismo turno. `playAndRecord`
/// con `defaultToSpeaker` cubre ambos casos con una sola categoría.
Future<void> _configurarSesionDeAudio() async {
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
        AVAudioSessionCategoryOptions.allowBluetooth,
    avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      usage: AndroidAudioUsage.assistant,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: true,
  ));
}

class SomiVozApp extends ConsumerWidget {
  const SomiVozApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arranca el worker de la cola offline apenas levanta la app.
    ref.watch(sincronizadorProvider);

    return MaterialApp(
      title: 'SOMI',
      // El sistema de diseño UPONPENGUIN es inherentemente oscuro (base
      // Negro KGB): no existe una variante clara, así que se fuerza dark.
      theme: UppTheme.build(),
      themeMode: ThemeMode.dark,
      home: const CapturaScreen(),
    );
  }
}
