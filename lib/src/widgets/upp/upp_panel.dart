import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// Contenedor con borde recto y fondo de panel/card — la unidad
/// estructural básica del sistema (nunca hay esquinas redondeadas).
class UppPanel extends StatelessWidget {
  const UppPanel({
    super.key,
    required this.child,
    this.background = UppTokens.bgPanel,
    this.borderColor = UppTokens.border1,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color background;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: UppTokens.rule),
      ),
      child: child,
    );
  }
}
