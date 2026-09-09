import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// Los anillos concéntricos + core de la vista radar (1b): tres cuadrados
/// que laten con la amplitud real de la grabación (`ui.amplitud`), un
/// cruce central, y un núcleo cuadrado con una etiqueta corta.
///
/// Los factores de escala replican los del mock (`1 + amp·0.28/0.16/0.08`
/// para el anillo interior/medio/exterior), así el anillo más chico —el
/// más cercano al núcleo— es el que más se mueve.
class UppRadarHud extends StatelessWidget {
  const UppRadarHud({
    super.key,
    required this.amplitud,
    required this.color,
    required this.coreLabel,
    this.size = 250,
  });

  /// 0..1, ya normalizada (misma fuente que `CapturaUiState.amplitud`).
  final double amplitud;
  final Color color;
  final String coreLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final amp = amplitud.clamp(0.0, 1.0);
    final r1 = 1 + amp * 0.28; // anillo interior — el que más late
    final r2 = 1 + amp * 0.16;
    final r3 = 1 + amp * 0.08; // anillo exterior — el que menos late

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size / 2 - 0.5,
            top: -16,
            bottom: -16,
            child: Container(width: 1, color: UppTokens.horm60),
          ),
          Positioned(
            top: size / 2 - 0.5,
            left: -16,
            right: -16,
            child: Container(height: 1, color: UppTokens.horm60),
          ),
          Transform.scale(scale: r3, child: _anillo(size, UppTokens.cian40)),
          Transform.scale(scale: r2, child: _anillo(size - 68, UppTokens.cian60)),
          Transform.scale(
            scale: r1,
            child: Container(
              width: size - 140,
              height: size - 140,
              decoration: BoxDecoration(
                border: Border.all(color: color),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 24)],
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            color: color,
            child: Text(
              coreLabel,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: UppTokens.fontMonoFallback,
                fontSize: 11,
                letterSpacing: 1,
                color: UppTokens.fgOnAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _anillo(double lado, Color color) => Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(border: Border.all(color: color)),
      );
}
