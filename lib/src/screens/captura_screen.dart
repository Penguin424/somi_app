import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/captura_model.dart';
import '../models/tool_ejecutada_model.dart';
import '../providers/captura_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/historial_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/upp_tokens.dart';
import '../utils/audio_recorder_utils.dart';
import '../utils/constants.dart';
import '../widgets/captura_button_widget.dart';
import '../widgets/estado_indicator_widget.dart';
import '../widgets/upp/upp_caps_label.dart';
import '../widgets/upp/upp_panel.dart';
import '../widgets/upp/upp_radar_hud.dart';
import '../widgets/upp/upp_scanlines.dart';
import '../widgets/upp/upp_status_strip.dart';
import '../widgets/upp/upp_waveform.dart';
import 'ajustes_screen.dart';
import 'historial_screen.dart';

class CapturaScreen extends ConsumerWidget {
  const CapturaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final vista = ref.watch(vistaCapturaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const UppCapsLabel('SOMI', color: UppTokens.accent, fontSize: 13, tracking: UppTokens.trackingWide),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistorialScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error al cargar ajustes: $e')),
        data: (settings) {
          if (!settings.tieneToken) {
            return _AvisoSinToken(
              onIrAAjustes: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjustesScreen())),
            );
          }
          return Stack(
            children: [
              const UppScanlines(),
              SafeArea(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 4, 18, 0),
                      child: UppStatusStrip(),
                    ),
                    Expanded(
                      child: vista == VistaCaptura.densa ? const _CapturaBody() : const _CapturaBodyRadar(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CapturaBody extends ConsumerWidget {
  const _CapturaBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final chat = ref.watch(chatProvider);
    final modoStreaming = ref.watch(modoStreamingProvider);
    final capturas = ref.watch(historialProvider).value ?? const <CapturaModel>[];

    // En modo WS la transcripción parcial va llegando token a token por
    // `chatProvider`; fuera de ese modo, lo único real es la de la última
    // captura ya resuelta.
    final transcripcion = modoStreaming && chat.transcripcionParcial.isNotEmpty
        ? chat.transcripcionParcial
        : ui.ultimaCaptura?.transcripcion ?? '';
    final mostrarCursor = ui.estado == EstadoCapturaUi.grabando || ui.estado == EstadoCapturaUi.transcribiendo;

    // Misma lógica que `transcripcion`: mientras el turno WS sigue en
    // curso se muestra la respuesta parcial (token a token) en vez de
    // nada, para que una espera de 40s con tool calling se vea como
    // progreso y no como un cuelgue.
    final respuestaEnCurso = modoStreaming && chat.respuestaParcial.isNotEmpty ? chat.respuestaParcial : null;
    final respuestaMostrada = respuestaEnCurso ?? ui.ultimaCaptura?.respuesta;
    final herramientaEnCurso = modoStreaming ? chat.herramientaEnCurso : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: EstadoIndicatorWidget()),
              const SizedBox(width: 16),
              _TimerBox(duracion: ui.duracionGrabacion),
            ],
          ),
          const SizedBox(height: 20),
          UppPanel(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              children: [
                UppWaveform(amplitudes: ui.historialAmplitud),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: UppTokens.border2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      UppCapsLabel(
                        '${AudioRecorderUtils.sampleRateHz ~/ 1000} kHz ░ '
                        '${AudioRecorderUtils.extensionAudio.toUpperCase()} ░ MONO',
                        fontSize: 9,
                      ),
                      UppCapsLabel('AMP ${ui.amplitud.toStringAsFixed(2)}', fontSize: 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const UppCapsLabel('TRANSCRIPCIÓN', fontSize: 9),
              const SizedBox(width: 8),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: UppTokens.fontMonoFallback,
                fontSize: 12.5,
                height: 1.6,
                color: UppTokens.fg1,
              ),
              children: [
                TextSpan(text: transcripcion),
                if (mostrarCursor) const TextSpan(text: ' ▊', style: TextStyle(color: UppTokens.accent)),
              ],
            ),
          ),
          if (herramientaEnCurso != null && herramientaEnCurso.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('▸', style: TextStyle(color: UppTokens.accent, fontSize: 11)),
                const SizedBox(width: 7),
                UppCapsLabel('EJECUTANDO $herramientaEnCurso', fontSize: 9.5, color: UppTokens.accent),
              ],
            ),
          ],
          if (ui.ultimaCaptura != null) ...[
            const SizedBox(height: 16),
            _ToolLog(tools: ui.ultimaCaptura!.toolsEjecutadas),
          ],
          if (respuestaMostrada != null && respuestaMostrada.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: const BoxDecoration(
                color: UppTokens.bgCard,
                border: Border(left: BorderSide(color: UppTokens.accent, width: UppTokens.ruleHeavy)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UppCapsLabel('SOMI RESPONDE', color: UppTokens.accent, fontSize: 9),
                  const SizedBox(height: 7),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w300, height: 1.5, color: UppTokens.fg1),
                      children: [
                        TextSpan(text: respuestaMostrada),
                        if (respuestaEnCurso != null)
                          const TextSpan(text: ' ▊', style: TextStyle(color: UppTokens.accent)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          // `IntrinsicHeight` acota la altura del Row antes de estirar sus
          // hijos: sin esto, `CrossAxisAlignment.stretch` dentro de un
          // `SingleChildScrollView` (altura no acotada) fuerza una
          // restricción de altura infinita y el layout revienta.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: CapturaButtonWidget()),
                const SizedBox(width: 12),
                _ModoStreamingToggle(activo: modoStreaming),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const UppCapsLabel('RECIENTES', fontSize: 9),
          const SizedBox(height: 4),
          if (capturas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Todavía no hay capturas', style: TextStyle(color: UppTokens.fg3)),
            )
          else
            ...capturas.take(5).map((c) => _RecienteRow(captura: c)),
        ],
      ),
    );
  }
}

/// Vista radar (1b): HUD minimalista de anillos concéntricos. Misma data
/// real que `_CapturaBody` (mismo `capturaProvider`, mismo
/// `resolverEstadoTexto`), sólo que muestra mucha menos densidad de
/// información — no repite el log de tools completo ni "RECIENTES", que
/// son cosa de la vista densa.
///
/// No duplica el toggle "▣ CHAT": esa acción ya vive en Ajustes
/// (`modoStreamingProvider`), así que esta vista puede quedarse fiel al
/// mock original (un solo CTA) sin perder funcionalidad real.
class _CapturaBodyRadar extends ConsumerWidget {
  const _CapturaBodyRadar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(capturaProvider);
    final chat = ref.watch(chatProvider);
    final modoStreaming = ref.watch(modoStreamingProvider);
    final texto = resolverEstadoTexto(ui);

    final transcripcion = modoStreaming && chat.transcripcionParcial.isNotEmpty
        ? chat.transcripcionParcial
        : ui.ultimaCaptura?.transcripcion ?? '';

    // Misma lógica que en `_CapturaBody`: mostrar la respuesta parcial en
    // curso (y qué tool se está ejecutando) para que una espera larga se
    // vea como progreso.
    final respuestaEnCurso = modoStreaming && chat.respuestaParcial.isNotEmpty ? chat.respuestaParcial : null;
    final respuestaMostrada = respuestaEnCurso ?? ui.ultimaCaptura?.respuesta;
    final herramientaEnCurso = modoStreaming ? chat.herramientaEnCurso : null;

    final coreLabel = switch (ui.estado) {
      EstadoCapturaUi.grabando => 'REC',
      EstadoCapturaUi.inactivo => '▌',
      _ => '···',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          UppRadarHud(amplitud: ui.amplitud, color: texto.color, coreLabel: coreLabel),
          const SizedBox(height: 44),
          Text(
            texto.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: UppTokens.fontDisplay,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 15 * UppTokens.trackingWidest,
              color: texto.color,
            ),
          ),
          const SizedBox(height: 12),
          UppCapsLabel(
            '${_formatearDuracion(ui.duracionGrabacion)} ░ ${texto.hint}',
            fontSize: 11,
            tracking: UppTokens.trackingCaps,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Text(
            transcripcion.isEmpty ? '—' : transcripcion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: UppTokens.fontMonoFallback,
              fontSize: 12,
              height: 1.65,
              color: UppTokens.fg2,
            ),
          ),
          if (herramientaEnCurso != null && herramientaEnCurso.isNotEmpty) ...[
            const SizedBox(height: 10),
            UppCapsLabel(
              'EJECUTANDO $herramientaEnCurso',
              fontSize: 9.5,
              color: UppTokens.accent,
              textAlign: TextAlign.center,
            ),
          ],
          if (respuestaMostrada != null && respuestaMostrada.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              respuestaMostrada,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w300,
                height: 1.5,
                color: UppTokens.fg1,
              ),
            ),
          ],
          if (ui.ultimaCaptura != null && ui.ultimaCaptura!.toolsEjecutadas.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: UppTokens.border2),
                  bottom: BorderSide(color: UppTokens.border2),
                ),
              ),
              child: Row(
                children: [
                  Container(width: 6, height: 6, color: texto.color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      ui.ultimaCaptura!.toolsEjecutadas.last.nombre,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontFamilyFallback: UppTokens.fontMonoFallback,
                        fontSize: 9.5,
                        letterSpacing: 0.7,
                        color: UppTokens.fg3,
                      ),
                    ),
                  ),
                  UppCapsLabel('${ui.ultimaCaptura!.toolsEjecutadas.length} TOOLS', fontSize: 9.5),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          const CapturaButtonWidget(variant: CapturaButtonVariant.ghost),
        ],
      ),
    );
  }
}

class _TimerBox extends StatelessWidget {
  const _TimerBox({required this.duracion});

  final Duration duracion;

  @override
  Widget build(BuildContext context) {
    return UppPanel(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const UppCapsLabel('T ░ REC', fontSize: 9),
          const SizedBox(height: 6),
          Text(
            _formatearDuracion(duracion),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontFamilyFallback: UppTokens.fontMonoFallback,
              fontSize: 22,
              color: UppTokens.fg1,
            ),
          ),
          const SizedBox(height: 6),
          UppCapsLabel('MAX ${_formatearDuracion(AppConstants.maxRecordingDuration)}', fontSize: 9),
        ],
      ),
    );
  }
}

/// Compartido entre `_TimerBox` (vista densa) y `_CapturaBodyRadar` (vista
/// radar): las dos necesitan el mismo formato mm:ss para el timer.
String _formatearDuracion(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// El log de tools ejecutadas por el orquestador en el último turno.
/// Reemplaza "MCP ░ TOOL LOG" del mock: se muestra el nombre real de cada
/// `ToolEjecutadaModel` (dato real, `tools_ejecutadas` de `POST /voz`),
/// sin la columna de latencia del mock — no existe ese campo en el
/// contrato.
class _ToolLog extends StatelessWidget {
  const _ToolLog({required this.tools});

  final List<ToolEjecutadaModel> tools;

  @override
  Widget build(BuildContext context) {
    return UppPanel(
      background: const Color(0xFF0A0C0E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 7),
            child: UppCapsLabel('TOOLS EJECUTADAS', fontSize: 9),
          ),
          const Divider(height: 1, color: UppTokens.border2),
          if (tools.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('sin llamadas en este turno', style: TextStyle(color: UppTokens.fgMuted, fontSize: 11)),
            )
          else
            ...tools.map(
              (t) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Text('▸', style: TextStyle(color: UppTokens.accent, fontSize: 11)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        t.nombre,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontFamilyFallback: UppTokens.fontMonoFallback,
                          fontSize: 10.5,
                          color: UppTokens.fg2,
                        ),
                      ),
                    ),
                    const Text('✓', style: TextStyle(color: UppTokens.accent, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// El botón "▣ CHAT" del mock, reutilizado como toggle real del modo
/// tiempo real (antes vivía como un `SwitchListTile` suelto arriba de la
/// pantalla).
class _ModoStreamingToggle extends ConsumerWidget {
  const _ModoStreamingToggle({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Modo tiempo real (WS /chat)',
      child: GestureDetector(
        onTap: () => ref.read(modoStreamingProvider.notifier).establecer(!activo),
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            color: activo ? UppTokens.accent : Colors.transparent,
            border: Border.all(color: activo ? UppTokens.accent : UppTokens.border1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('▣', style: TextStyle(fontSize: 16, color: activo ? UppTokens.fgOnAccent : UppTokens.fg3)),
              const SizedBox(height: 4),
              UppCapsLabel('CHAT', fontSize: 8, color: activo ? UppTokens.fgOnAccent : UppTokens.fg3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila de "RECIENTES": intenta resolver una ruta real si alguna
/// tool ejecutada la trajo en su `resultado` (campos `archivo`/`path`/
/// `carpeta`, nombres que no están garantizados por el contrato pero que
/// el propio backend puede mandar); si no hay nada así, cae al fragmento
/// de la transcripción. Nunca inventa un dato que no vino en la captura.
class _RecienteRow extends StatelessWidget {
  const _RecienteRow({required this.captura});

  final CapturaModel captura;

  @override
  Widget build(BuildContext context) {
    final hora = '${captura.creadaEn.hour.toString().padLeft(2, '0')}:'
        '${captura.creadaEn.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: UppTokens.border2))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _etiqueta(captura),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: UppTokens.fontMonoFallback,
                fontSize: 10.5,
                color: UppTokens.fg2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          UppCapsLabel(hora, fontSize: 10.5, color: UppTokens.accent, tracking: 0),
        ],
      ),
    );
  }

  String _etiqueta(CapturaModel captura) {
    for (final tool in captura.toolsEjecutadas) {
      final r = tool.resultado;
      final archivo = r['archivo'] ?? r['path'] ?? r['file'] ?? r['note_path'];
      if (archivo is String && archivo.isNotEmpty) {
        final carpeta = r['carpeta'] ?? r['folder'];
        return carpeta is String && carpeta.isNotEmpty ? '$carpeta/$archivo' : archivo;
      }
    }
    final transcripcion = captura.transcripcion;
    if (transcripcion != null && transcripcion.isNotEmpty) {
      return transcripcion.length > 44 ? '${transcripcion.substring(0, 44)}…' : transcripcion;
    }
    return captura.contexto;
  }
}

class _AvisoSinToken extends StatelessWidget {
  const _AvisoSinToken({required this.onIrAAjustes});

  final VoidCallback onIrAAjustes;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.vpn_key_off_outlined, size: 48, color: UppTokens.fg3),
            const SizedBox(height: 16),
            const Text(
              'Configurá el token del orquestador para empezar a dictar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onIrAAjustes,
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      ),
    );
  }
}
