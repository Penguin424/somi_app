import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captura_provider.dart';
import '../providers/historial_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/captura_button_widget.dart';
import '../widgets/estado_indicator_widget.dart';
import '../widgets/historial_item_widget.dart';
import 'ajustes_screen.dart';
import 'historial_screen.dart';

class CapturaScreen extends ConsumerWidget {
  const CapturaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final ui = ref.watch(capturaProvider);
    final historialAsync = ref.watch(historialProvider);
    final modoStreaming = ref.watch(modoStreamingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura por voz'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistorialScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar ajustes: $e')),
        data: (settings) {
          if (!settings.tieneToken) {
            return _AvisoSinToken(
              onIrAAjustes: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
            );
          }
          return SafeArea(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Modo tiempo real (beta)'),
                  subtitle: const Text(
                    'Transcripción y respuesta en vivo por WebSocket',
                  ),
                  value: modoStreaming,
                  onChanged: (v) =>
                      ref.read(modoStreamingProvider.notifier).establecer(v),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EstadoIndicatorWidget(),
                          const SizedBox(height: 24),
                          const CapturaButtonWidget(),
                          const SizedBox(height: 32),
                          if (ui.ultimaCaptura?.respuesta != null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ui.ultimaCaptura?.transcripcion != null)
                                      Text(
                                        '"${ui.ultimaCaptura!.transcripcion}"',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(ui.ultimaCaptura!.respuesta!),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 160,
                  child: historialAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (capturas) {
                      final recientes = capturas.take(5).toList();
                      if (recientes.isEmpty) {
                        return const Center(
                          child: Text('Todavía no hay capturas'),
                        );
                      }
                      return ListView.builder(
                        itemCount: recientes.length,
                        itemBuilder: (context, i) =>
                            HistorialItemWidget(captura: recientes[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AvisoSinToken extends StatelessWidget {
  const _AvisoSinToken({required this.onIrAAjustes});

  final VoidCallback onIrAAjustes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Configurá el token del orquestador para empezar a dictar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onIrAAjustes,
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      ),
    );
  }
}
