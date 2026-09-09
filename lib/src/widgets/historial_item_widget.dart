import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/captura_model.dart';
import '../models/tool_ejecutada_model.dart';
import '../theme/upp_tokens.dart';
import 'upp/upp_caps_label.dart';
import 'upp/upp_panel.dart';

class HistorialItemWidget extends StatelessWidget {
  const HistorialItemWidget({super.key, required this.captura});

  final CapturaModel captura;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: UppPanel(
        background: UppTokens.bgCard,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ChipEstado(estado: captura.estado),
                const Spacer(),
                UppCapsLabel(_formatearFecha(captura.creadaEn), fontSize: 9.5, tracking: 0),
              ],
            ),
            if (captura.transcripcion != null) ...[
              const SizedBox(height: 10),
              Text(
                '"${captura.transcripcion}"',
                style: const TextStyle(fontStyle: FontStyle.italic, color: UppTokens.fg2),
              ),
            ],
            if (captura.respuesta != null) ...[
              const SizedBox(height: 8),
              Text(captura.respuesta!),
            ],
            if (captura.estado == EstadoCaptura.fallida && captura.errorMensaje != null) ...[
              const SizedBox(height: 8),
              Text(captura.errorMensaje!, style: const TextStyle(color: UppTokens.danger)),
            ],
            // Filas colapsables: dato 100% real (`tools_ejecutadas` de
            // `POST /voz`), cada una expande su `resultado` tal cual vino.
            if (captura.toolsEjecutadas.isNotEmpty) ...[
              const SizedBox(height: 14),
              UppCapsLabel('TOOLS EJECUTADAS ░ ${captura.toolsEjecutadas.length}', fontSize: 9),
              const SizedBox(height: 6),
              ...captura.toolsEjecutadas.map((t) => _ToolRow(tool: t)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime f) {
    final h = f.hour.toString().padLeft(2, '0');
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day}/${f.month} $h:$m';
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado});

  final EstadoCaptura estado;

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (estado) {
      EstadoCaptura.pendiente => (UppTokens.fg3, 'PENDIENTE'),
      EstadoCaptura.enviando => (UppTokens.accent, 'ENVIANDO'),
      EstadoCaptura.enviada => (UppTokens.accent, 'ENVIADA'),
      EstadoCaptura.fallida => (UppTokens.danger, 'FALLIDA'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: UppCapsLabel(texto, color: color, fontSize: 9.5, tracking: UppTokens.trackingCaps),
    );
  }
}

/// Fila expandible de una tool ejecutada. `resultado` es el
/// `Map<String, dynamic>` que mandó el orquestador tal cual — se muestra
/// como JSON formateado, sin resumirlo ni inventar un estado que no vino.
class _ToolRow extends StatefulWidget {
  const _ToolRow({required this.tool});

  final ToolEjecutadaModel tool;

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  bool _abierto = false;
  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Widget build(BuildContext context) {
    String resultadoJson;
    try {
      resultadoJson = _encoder.convert(widget.tool.resultado);
    } catch (_) {
      resultadoJson = widget.tool.resultado.toString();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(border: Border.all(color: UppTokens.border1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _abierto = !_abierto),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                children: [
                  Container(width: 6, height: 6, color: UppTokens.accent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.tool.nombre,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: UppTokens.fontMonoFallback,
                        fontSize: 10.5,
                        color: UppTokens.fg1,
                      ),
                    ),
                  ),
                  Icon(_abierto ? Icons.expand_less : Icons.expand_more, size: 16, color: UppTokens.accent),
                ],
              ),
            ),
          ),
          if (_abierto)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF0A0C0E),
                border: Border(top: BorderSide(color: UppTokens.border2)),
              ),
              child: Text(
                resultadoJson,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontFamilyFallback: UppTokens.fontMonoFallback,
                  fontSize: 10,
                  color: UppTokens.fg2,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
