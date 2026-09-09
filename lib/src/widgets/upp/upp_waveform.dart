import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// Las 42 barras de la waveform en vivo. Alimentada por el historial de
/// amplitud normalizada (0..1) que trae `CapturaUiState.historialAmplitud`.
///
/// La envolvente senoidal del diseño original (`0.45 + 0.55·sin(i/41·π)`)
/// hace que las barras del centro sean más altas que las de los bordes,
/// dando la silueta de "pastilla" característica de la waveform del mock.
class UppWaveform extends StatelessWidget {
  const UppWaveform({
    super.key,
    required this.amplitudes,
    this.color = UppTokens.accent,
    this.barCount = 42,
    this.height = 92,
  });

  /// Últimas muestras normalizadas (0..1), más recientes al final. Si hay
  /// menos de [barCount], se completa con silencio (barras mínimas) a la
  /// izquierda — así la waveform "entra" desde el silencio en vez de
  /// arrancar ya llena.
  final List<double> amplitudes;
  final Color color;
  final int barCount;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WaveformPainter(
          amplitudes: amplitudes,
          color: color,
          barCount: barCount,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.amplitudes, required this.color, required this.barCount});

  final List<double> amplitudes;
  final Color color;
  final int barCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const barWidth = 3.0;
    final gap = barCount > 1 ? (size.width - barCount * barWidth) / (barCount - 1) : 0.0;

    // Alinea las últimas `barCount` muestras a la derecha; rellena el
    // resto con silencio.
    final muestras = List<double>.filled(barCount, 0.05);
    final disponibles = amplitudes.length;
    for (var i = 0; i < math.min(barCount, disponibles); i++) {
      muestras[barCount - 1 - i] = amplitudes[disponibles - 1 - i];
    }

    for (var i = 0; i < barCount; i++) {
      final envolvente = 0.45 + 0.55 * math.sin((i / (barCount - 1)) * math.pi);
      final amp = muestras[i].clamp(0.0, 1.0);
      final alto = math.max(2.0, amp * envolvente * size.height);
      final x = i * (barWidth + gap);
      final rect = Rect.fromLTWH(x, (size.height - alto) / 2, barWidth, alto);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.amplitudes != amplitudes || oldDelegate.color != color;
}
