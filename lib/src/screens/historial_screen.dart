import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/historial_provider.dart';
import '../theme/upp_tokens.dart';
import '../widgets/historial_item_widget.dart';
import '../widgets/upp/upp_caps_label.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialProvider);
    return Scaffold(
      appBar: AppBar(
        title: const UppCapsLabel('Historial', fontSize: 9.5, tracking: UppTokens.trackingWide),
      ),
      body: historialAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (capturas) {
          if (capturas.isEmpty) {
            return const Center(child: Text('Todavía no hay capturas', style: TextStyle(color: UppTokens.fg3)));
          }
          return RefreshIndicator(
            color: UppTokens.accent,
            backgroundColor: UppTokens.bgPanel,
            onRefresh: () => ref.read(sincronizadorProvider.notifier).sincronizarTodas(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: capturas.length,
              itemBuilder: (context, i) => HistorialItemWidget(captura: capturas[i]),
            ),
          );
        },
      ),
    );
  }
}
