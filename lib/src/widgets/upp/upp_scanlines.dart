import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// Overlay CRT: líneas horizontales finas sobre el contenido, como el
/// `repeating-linear-gradient` de `.dv-turn` en el diseño original. Un
/// `CustomPainter` es más predecible que repetir un gradiente a cualquier
/// densidad de pantalla.
///
/// Puramente decorativo — `IgnorePointer` para que nunca capture toques.
class UppScanlines extends StatelessWidget {
  const UppScanlines({super.key, this.opacity = 0.045});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanlinesPainter(color: UppTokens.fosforo.withValues(alpha: opacity)),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanlinesPainter extends CustomPainter {
  const _ScanlinesPainter({required this.color});

  final Color color;
  static const double _step = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = 0; y < size.height; y += _step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlinesPainter oldDelegate) => oldDelegate.color != color;
}
