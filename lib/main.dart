import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/providers/historial_provider.dart';
import 'src/screens/captura_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: SomiVozApp()));
}

class SomiVozApp extends ConsumerWidget {
  const SomiVozApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Arranca el worker de la cola offline apenas levanta la app.
    ref.watch(sincronizadorProvider);

    return MaterialApp(
      title: 'Captura por voz',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const CapturaScreen(),
    );
  }
}
