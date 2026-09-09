import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captura_provider.dart';
import '../theme/upp_tokens.dart';
import 'upp/upp_caps_label.dart';

/// Label + hint + color por cada `EstadoCapturaUi`. Único lugar donde
/// vive este mapeo: lo usan tanto la vista densa (`EstadoIndicatorWidget`)
/// como la vista radar (`CapturaRadarBodyWidget`), para que ambas cuenten
/// exactamente la misma historia con estilos distintos.
///
/// Los hints reusan vocabulario que ya existe en el código (`STT`, `LLM`,
/// `TTS` vienen literalmente de los mensajes de error de
/// `voz_service.dart`), no términos de motor específicos (p. ej. no se
/// afirma qué versión de Whisper corre del lado del servidor: eso no es
/// un dato que la app tenga).
({String label, String hint, Color color}) resolverEstadoTexto(CapturaUiState ui) {
  final (label, hint, color) = switch (ui.estado) {
    EstadoCapturaUi.inactivo => ('EN ESPERA', 'Tocá para dictar', UppTokens.fgMuted),
    EstadoCapturaUi.grabando => ('GRABANDO', 'Tocá de nuevo para cerrar el turno', UppTokens.accent),
    EstadoCapturaUi.subiendo => ('SUBIENDO', 'POST /voz ░ idempotency key emitida', UppTokens.accent),
    EstadoCapturaUi.transcribiendo => ('TRANSCRIBIENDO', 'STT ░ servidor', UppTokens.accent),
    EstadoCapturaUi.pensando => ('PENSANDO', 'LLM ░ tools ejecutadas', UppTokens.accent),
    EstadoCapturaUi.hablando => ('HABLANDO', 'TTS ░ respuesta en curso', UppTokens.accent),
    EstadoCapturaUi.enCola => (
        'EN COLA',
        'Se manda sola cuando vuelva la conexión',
        UppTokens.fg3,
      ),
    EstadoCapturaUi.error => ('ERROR', ui.errorMensaje ?? 'Ocurrió un error', UppTokens.danger),
  };
  return (label: label, hint: hint, color: color);
}

/// El bloque "ESTADO ▌ STATUS" de la vista densa: label grande en
/// mayúsculas + hint de una línea, coloreado según el estado.
class EstadoIndicatorWidget extends ConsumerWidget {
  const EstadoIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final texto = resolverEstadoTexto(ui);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const UppCapsLabel('ESTADO ▌ STATUS'),
        const SizedBox(height: 7),
        Text(
          texto.label,
          style: TextStyle(
            fontFamily: UppTokens.fontDisplay,
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
            height: 1,
            color: texto.color,
          ),
        ),
        const SizedBox(height: 6),
        UppCapsLabel(texto.hint, fontSize: 10, tracking: UppTokens.trackingWide),
      ],
    );
  }
}
