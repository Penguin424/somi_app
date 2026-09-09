import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captura_provider.dart';
import '../theme/upp_tokens.dart';
import 'upp/upp_ghost_button.dart';
import 'upp/upp_hard_button.dart';

/// Estilo del CTA: `hard` es el botón cian con sombra dura de la vista
/// densa (1a); `ghost` es el botón con borde de la vista radar (1b). La
/// lógica de qué acción dispara y qué texto muestra es la misma en las
/// dos — sólo cambia el envoltorio visual.
enum CapturaButtonVariant { hard, ghost }

/// El CTA de grabar/cerrar turno. Un toque arranca, otro toque para y
/// manda. `hablando` no bloquea a propósito: si tocás el botón mientras
/// suena la respuesta, se corta el audio y arranca una captura nueva —
/// bloquear ahí era lo que dejaba el botón gris sin salida.
class CapturaButtonWidget extends ConsumerWidget {
  const CapturaButtonWidget({super.key, this.variant = CapturaButtonVariant.hard});

  final CapturaButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final notifier = ref.read(capturaProvider.notifier);
    final grabando = ui.estado == EstadoCapturaUi.grabando;
    final ocupado = ui.estado == EstadoCapturaUi.subiendo ||
        ui.estado == EstadoCapturaUi.transcribiendo ||
        ui.estado == EstadoCapturaUi.pensando;

    final String etiqueta;
    if (grabando) {
      etiqueta = 'CERRAR TURNO';
    } else if (ocupado) {
      etiqueta = switch (ui.estado) {
        EstadoCapturaUi.subiendo => 'SUBIENDO',
        EstadoCapturaUi.transcribiendo => 'TRANSCRIBIENDO',
        EstadoCapturaUi.pensando => 'PENSANDO',
        _ => 'PROCESANDO',
      };
    } else {
      etiqueta = 'DICTAR';
    }

    final onTap = ocupado ? null : () => grabando ? notifier.detenerYEnviar() : notifier.iniciarGrabacion();
    final textoBoton = Text(
      etiqueta,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.7),
    );

    final boton = switch (variant) {
      CapturaButtonVariant.hard => UppHardButton(
          onTap: onTap,
          background: grabando ? UppTokens.danger : UppTokens.accent,
          foreground: grabando ? UppTokens.fg1 : UppTokens.fgOnAccent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [textoBoton, const Text('▸', style: TextStyle(fontSize: 18))],
          ),
        ),
      CapturaButtonVariant.ghost => UppGhostButton(
          onTap: onTap,
          color: grabando ? UppTokens.danger : UppTokens.accent,
          child: textoBoton,
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        boton,
        if (grabando)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton(
              onPressed: () => notifier.cancelarGrabacion(),
              child: const Text('Cancelar'),
            ),
          ),
      ],
    );
  }
}
