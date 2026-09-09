import 'package:flutter/material.dart';

import '../../theme/upp_tokens.dart';

/// CTA con borde (sin sombra dura, sin relleno) — el estilo de botón que
/// usa la vista radar (1b): `border:2px solid var(--accent); color:
/// var(--accent)`, con feedback de toque vía `InkWell` en vez del gesto
/// de "hover" que no aplica en touch.
class UppGhostButton extends StatelessWidget {
  const UppGhostButton({
    super.key,
    required this.child,
    required this.onTap,
    this.color = UppTokens.accent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    final c = habilitado ? color : UppTokens.fgMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: c.withValues(alpha: 0.18),
        highlightColor: c.withValues(alpha: 0.10),
        child: Container(
          padding: const EdgeInsets.all(18),
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: c, width: UppTokens.ruleHeavy)),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: c),
            child: child,
          ),
        ),
      ),
    );
  }
}
