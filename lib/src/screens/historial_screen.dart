import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/historial_provider.dart';
import '../widgets/historial_item_widget.dart';

class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: historialAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (capturas) {
          if (capturas.isEmpty) {
            return const Center(child: Text('Todavía no hay capturas'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(sincronizadorProvider.notifier).sincronizarTodas(),
            child: ListView.builder(
              itemCount: capturas.length,
              itemBuilder: (context, i) => HistorialItemWidget(captura: capturas[i]),
            ),
          );
        },
      ),
    );
  }
}
