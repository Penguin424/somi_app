import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/captura_provider.dart';

/// Feedback de estado: "Grabando", "Subiendo", "Transcribiendo",
/// "Pensando", "Hablando". Grabar y esperar en silencio se siente roto,
/// según deja dicho APP_FLUTTER.md — este widget es lo que evita eso.
class EstadoIndicatorWidget extends ConsumerWidget {
  const EstadoIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final (texto, icono) = switch (ui.estado) {
      EstadoCapturaUi.inactivo => ('Tocá el botón para grabar', Icons.mic_none_rounded),
      EstadoCapturaUi.grabando => ('Grabando…', Icons.fiber_manual_record),
      EstadoCapturaUi.subiendo => ('Subiendo…', Icons.cloud_upload_outlined),
      EstadoCapturaUi.transcribiendo => ('Transcribiendo…', Icons.text_fields_rounded),
      EstadoCapturaUi.pensando => ('Pensando…', Icons.psychology_outlined),
      EstadoCapturaUi.hablando => ('Hablando…', Icons.volume_up_outlined),
      EstadoCapturaUi.enCola => (
          'Guardada en la cola: se envía sola cuando vuelva la conexión',
          Icons.cloud_off_outlined,
        ),
      EstadoCapturaUi.error => (ui.errorMensaje ?? 'Ocurrió un error', Icons.error_outline),
    };
    final conSpinner = ui.estado == EstadoCapturaUi.subiendo ||
        ui.estado == EstadoCapturaUi.transcribiendo ||
        ui.estado == EstadoCapturaUi.pensando ||
        ui.estado == EstadoCapturaUi.hablando;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (conSpinner)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          Icon(
            icono,
            size: 18,
            color: ui.estado == EstadoCapturaUi.error ? Colors.redAccent : null,
          ),
        const SizedBox(width: 8),
        Flexible(child: Text(texto, textAlign: TextAlign.center)),
      ],
    );
  }
}
