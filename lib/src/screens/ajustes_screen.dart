import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/captura_model.dart';
import '../providers/captura_provider.dart';
import '../providers/historial_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/upp_tokens.dart';
import '../utils/constants.dart';
import '../utils/personalidad_somi.dart';
import '../widgets/upp/upp_caps_label.dart';
import '../widgets/upp/upp_hard_button.dart';
import '../widgets/upp/upp_panel.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _tokenController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _personalidadController = TextEditingController();
  final _contextoController = TextEditingController();
  bool _tokenVisible = false;
  bool _inicializado = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _baseUrlController.dispose();
    _personalidadController.dispose();
    _contextoController.dispose();
    super.dispose();
  }

  void _sincronizarControllers(SettingsState settings) {
    if (_inicializado) return;
    _tokenController.text = settings.token ?? '';
    _baseUrlController.text = settings.baseUrl;
    _personalidadController.text = settings.personalidad;
    _contextoController.text = settings.contexto;
    _inicializado = true;
  }

  String _formatearDuracionCorta(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const UppCapsLabel('Ajustes ░ Uso Interno', fontSize: 9.5, tracking: UppTokens.trackingWide),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          _sincronizarControllers(settings);
          final modoStreaming = ref.watch(modoStreamingProvider);
          final vistaCaptura = ref.watch(vistaCapturaProvider);
          final capturas = ref.watch(historialProvider).value ?? const <CapturaModel>[];
          final enCola = capturas
              .where((c) => c.estado == EstadoCaptura.pendiente || c.estado == EstadoCaptura.enviando)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              UppPanel(
                child: const Text(
                  'La URL y el token viven en el almacenamiento seguro del '
                  'dispositivo. Nunca se compilan en la app.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: UppTokens.fontMonoFallback,
                    fontSize: 10,
                    height: 1.6,
                    color: UppTokens.fg3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const UppCapsLabel('URL del orquestador', fontSize: 9),
              const SizedBox(height: 7),
              TextField(
                controller: _baseUrlController,
                style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: UppTokens.fontMonoFallback),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 18),
              const UppCapsLabel('Token de autenticación', fontSize: 9),
              const SizedBox(height: 7),
              TextField(
                controller: _tokenController,
                obscureText: !_tokenVisible,
                style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: UppTokens.fontMonoFallback),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixIcon: TextButton(
                    onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
                    child: UppCapsLabel(_tokenVisible ? 'OCULTAR' : 'VER', fontSize: 9.5, color: UppTokens.accent),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 20),
              const UppCapsLabel('Personalidad de SOMI', fontSize: 9),
              const SizedBox(height: 7),
              UppPanel(
                child: Text(
                  'Se SUMA al prompt del servidor (reglas de tools, fecha de hoy), '
                  'nunca lo reemplaza.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: UppTokens.fontMonoFallback,
                    fontSize: 10,
                    height: 1.6,
                    color: UppTokens.fg3,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _personalidadController,
                maxLines: null,
                minLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: UppTokens.fontMonoFallback, fontSize: 12),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _personalidadController.text = PersonalidadSomi.condensada;
                    }),
                    child: const Text('Restaurar SOMI (voz)'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _personalidadController.text = PersonalidadSomi.completa;
                    }),
                    child: const Text('Versión completa'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const UppCapsLabel('Contexto de esta conversación', fontSize: 9),
              const SizedBox(height: 7),
              TextField(
                controller: _contextoController,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: UppTokens.fontMonoFallback),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'ej. estoy en el gimnasio',
                ),
              ),
              const SizedBox(height: 28),
              UppHardButton(
                onTap: () async {
                  await ref.read(settingsProvider.notifier).guardarBaseUrl(_baseUrlController.text);
                  await ref.read(settingsProvider.notifier).guardarToken(_tokenController.text.trim());
                  await ref.read(settingsProvider.notifier).guardarPersonalidad(_personalidadController.text);
                  await ref.read(settingsProvider.notifier).guardarContexto(_contextoController.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
                  }
                },
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Center(
                  child: Text('Guardar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => ref.read(settingsProvider.notifier).verificarServidor(),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Probar conexión'),
              ),
              const SizedBox(height: 12),
              if (settings.verificandoServidor)
                const Center(child: CircularProgressIndicator())
              else if (settings.servidorOk != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      settings.servidorOk! ? Icons.check_circle : Icons.error,
                      color: settings.servidorOk! ? UppTokens.accent : UppTokens.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.servidorDetalle ??
                            (settings.servidorOk! ? 'Servidor arriba' : 'No se pudo conectar'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              const Divider(height: 1),
              _FilaToggle(
                titulo: 'Modo tiempo real',
                subtitulo: 'WS /chat ░ transcripción en vivo',
                valor: modoStreaming,
                onChanged: (v) => ref.read(modoStreamingProvider.notifier).establecer(v),
              ),
              const Divider(height: 1, color: UppTokens.border2),
              _FilaToggle(
                titulo: 'TTS local de respaldo',
                subtitulo: 'Habla si el audio del servidor no llega',
                valor: settings.ttsLocalHabilitado,
                onChanged: (v) => ref.read(settingsProvider.notifier).establecerTtsLocalHabilitado(v),
              ),
              const Divider(height: 1, color: UppTokens.border2),
              _FilaVistaCaptura(
                valor: vistaCaptura,
                onChanged: (v) => ref.read(vistaCapturaProvider.notifier).establecer(v),
              ),
              const Divider(height: 1, color: UppTokens.border2),
              _FilaInfo(
                titulo: 'Cola offline',
                subtitulo: '$enCola pendientes ░ backoff '
                    '${_formatearDuracionCorta(AppConstants.retryBackoff.first)} → '
                    '${_formatearDuracionCorta(AppConstants.retryBackoff.last)}',
              ),
              const Divider(height: 1, color: UppTokens.border2),
            ],
          );
        },
      ),
    );
  }
}

class _FilaToggle extends StatelessWidget {
  const _FilaToggle({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!valor),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  UppCapsLabel(subtitulo, fontSize: 9.5, tracking: UppTokens.trackingCaps),
                ],
              ),
            ),
            Switch(value: valor, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Selector Densa/Radar para la pantalla de Captura — las dos variantes
/// visuales del diseño "SOMI Voz" (1a y 1b). Misma data real detrás de
/// las dos, sólo cambia cuánto se muestra en pantalla.
class _FilaVistaCaptura extends StatelessWidget {
  const _FilaVistaCaptura({required this.valor, required this.onChanged});

  final VistaCaptura valor;
  final ValueChanged<VistaCaptura> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Text('Vista de captura', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          _Segmento(
            texto: 'DENSA',
            activo: valor == VistaCaptura.densa,
            onTap: () => onChanged(VistaCaptura.densa),
          ),
          const SizedBox(width: 8),
          _Segmento(
            texto: 'RADAR',
            activo: valor == VistaCaptura.radar,
            onTap: () => onChanged(VistaCaptura.radar),
          ),
        ],
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento({required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? UppTokens.accent : Colors.transparent,
          border: Border.all(color: activo ? UppTokens.accent : UppTokens.border1),
        ),
        child: UppCapsLabel(
          texto,
          fontSize: 9,
          color: activo ? UppTokens.fgOnAccent : UppTokens.fg3,
        ),
      ),
    );
  }
}

class _FilaInfo extends StatelessWidget {
  const _FilaInfo({required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          UppCapsLabel(subtitulo, fontSize: 9.5, tracking: UppTokens.trackingCaps),
        ],
      ),
    );
  }
}
