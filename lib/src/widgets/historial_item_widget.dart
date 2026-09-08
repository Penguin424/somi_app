import 'package:flutter/material.dart';

import '../models/captura_model.dart';

class HistorialItemWidget extends StatelessWidget {
  const HistorialItemWidget({super.key, required this.captura});

  final CapturaModel captura;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ChipEstado(estado: captura.estado),
                const Spacer(),
                Text(_formatearFecha(captura.creadaEn), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            if (captura.transcripcion != null) ...[
              const SizedBox(height: 8),
              Text('"${captura.transcripcion}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (captura.respuesta != null) ...[
              const SizedBox(height: 6),
              Text(captura.respuesta!),
            ],
            if (captura.estado == EstadoCaptura.fallida && captura.errorMensaje != null) ...[
              const SizedBox(height: 6),
              Text(captura.errorMensaje!, style: const TextStyle(color: Colors.redAccent)),
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
      EstadoCaptura.pendiente => (Colors.orange, 'Pendiente'),
      EstadoCaptura.enviando => (Colors.blue, 'Enviando'),
      EstadoCaptura.enviada => (Colors.green, 'Enviada'),
      EstadoCaptura.fallida => (Colors.red, 'Fallida'),
    };
    return Chip(
      label: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
