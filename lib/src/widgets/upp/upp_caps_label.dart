import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// El rótulo mono en mayúsculas con tracking amplio que aparece sobre
/// casi cada bloque del diseño (p. ej. "ESTADO ▌ STATUS", "T ░ REC").
/// El texto se pasa ya en mayúsculas por quien llama: no se fuerza
/// `toUpperCase()` acá porque algunos rótulos mezclan separadores (`░`)
/// que no deben tocarse.
class UppCapsLabel extends StatelessWidget {
  const UppCapsLabel(
    this.texto, {
    super.key,
    this.color = UppTokens.fg3,
    this.fontSize = 9.5,
    this.tracking = UppTokens.trackingWidest,
    this.textAlign,
  });

  final String texto;
  final Color color;
  final double fontSize;
  final double tracking;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: UppTokens.fontMonoFallback,
        fontSize: fontSize,
        letterSpacing: fontSize * tracking,
        color: color,
        height: 1,
      ),
    );
  }
}
