import 'package:flutter/widgets.dart';

import '../../theme/upp_tokens.dart';

/// El CTA cian con sombra dura desplazada. Al presionar, se traslada
/// hacia la sombra y esta se achica — el gesto característico del
/// sistema (`.btn:active { transform: translate(2px,2px); box-shadow:
/// 2px 2px 0 var(--upp-hormigon) }`).
class UppHardButton extends StatefulWidget {
  const UppHardButton({
    super.key,
    required this.child,
    required this.onTap,
    this.background = UppTokens.accent,
    this.foreground = UppTokens.fgOnAccent,
    this.padding = const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final EdgeInsetsGeometry padding;

  @override
  State<UppHardButton> createState() => _UppHardButtonState();
}

class _UppHardButtonState extends State<UppHardButton> {
  bool _presionado = false;

  void _setPresionado(bool v) {
    if (widget.onTap == null) return;
    setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.onTap != null;
    final offset = _presionado ? UppTokens.shadowHardOffsetPressed : UppTokens.shadowHardOffset;

    return Listener(
      onPointerDown: (_) => _setPresionado(true),
      onPointerUp: (_) => _setPresionado(false),
      onPointerCancel: (_) => _setPresionado(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          // CSS: `.btn:active { transform: translate(2px,2px) }` — el
          // botón se mueve hacia su sombra, que a la vez se achica más
          // abajo (de 6px a 2px de offset).
          transform: Matrix4.translationValues(
            _presionado ? UppTokens.shadowHardOffsetPressed.dx : 0,
            _presionado ? UppTokens.shadowHardOffsetPressed.dy : 0,
            0,
          ),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: habilitado ? widget.background : UppTokens.fgMuted,
            boxShadow: UppTokens.shadowHard(offset: offset),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: widget.foreground),
            child: IconTheme.merge(
              data: IconThemeData(color: widget.foreground),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
