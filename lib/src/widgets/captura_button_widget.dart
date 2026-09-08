import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captura_provider.dart';

/// El botón grande de grabar. Un toque arranca, otro toque para y manda.
/// Mientras graba, crece un poco con el nivel de audio en vivo y muestra
/// la duración.
class CapturaButtonWidget extends ConsumerWidget {
  const CapturaButtonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final notifier = ref.read(capturaProvider.notifier);
    final grabando = ui.estado == EstadoCapturaUi.grabando;
    // `hablando` no bloquea a propósito: si tocás el botón mientras suena la
    // respuesta, se corta el audio y arranca una captura nueva. Bloquear ahí
    // era lo que dejaba el botón gris sin salida.
    final ocupado = ui.estado == EstadoCapturaUi.subiendo ||
        ui.estado == EstadoCapturaUi.transcribiendo ||
        ui.estado == EstadoCapturaUi.pensando;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (grabando)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _formatearDuracion(ui.duracionGrabacion),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        GestureDetector(
          onTap: ocupado
              ? null
              : () => grabando ? notifier.detenerYEnviar() : notifier.iniciarGrabacion(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 96 + (grabando ? ui.amplitud * 24 : 0),
            height: 96 + (grabando ? ui.amplitud * 24 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: grabando
                  ? Colors.redAccent
                  : (ocupado ? Colors.grey : Theme.of(context).colorScheme.primary),
            ),
            child: Icon(
              grabando ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (grabando)
          TextButton(
            onPressed: () => notifier.cancelarGrabacion(),
            child: const Text('Cancelar'),
          ),
      ],
    );
  }

  String _formatearDuracion(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
