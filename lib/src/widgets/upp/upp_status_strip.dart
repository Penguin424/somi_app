import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/captura_model.dart';
import '../../providers/historial_provider.dart';
import '../../theme/upp_tokens.dart';
import 'upp_caps_label.dart';

/// La franja superior `SOMI ░ ● ONLINE ░ COLA n`. Conectividad real vía
/// `conectividadProvider`; conteo de cola real contando `pendiente` +
/// `fallida` en `historialProvider`. Se omite el `K-77 ░ 184 MHz` del
/// mock original: es un adorno sin dato detrás.
class UppStatusStrip extends ConsumerWidget {
  const UppStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(conectividadProvider).value ?? true;
    final capturas = ref.watch(historialProvider).value ?? const <CapturaModel>[];
    final enCola = capturas
        .where((c) => c.estado == EstadoCaptura.pendiente || c.estado == EstadoCaptura.enviando)
        .length;
    final color = online ? UppTokens.accent : UppTokens.danger;

    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: UppTokens.border2)),
      ),
      child: Row(
        children: [
          const UppCapsLabel('SOMI', color: UppTokens.accent, fontSize: 9.5),
          const SizedBox(width: 10),
          const UppCapsLabel('░', fontSize: 9.5),
          const Spacer(),
          Container(width: 6, height: 6, color: color),
          const SizedBox(width: 6),
          UppCapsLabel(online ? 'ONLINE' : 'SIN CONEXIÓN', color: color, fontSize: 9.5),
          const SizedBox(width: 8),
          const UppCapsLabel('░', fontSize: 9.5),
          const SizedBox(width: 8),
          UppCapsLabel('COLA $enCola', fontSize: 9.5),
        ],
      ),
    );
  }
}
