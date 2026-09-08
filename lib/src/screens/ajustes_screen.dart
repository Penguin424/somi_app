import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _tokenController = TextEditingController();
  final _baseUrlController = TextEditingController();
  bool _tokenVisible = false;
  bool _inicializado = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  void _sincronizarControllers(SettingsState settings) {
    if (_inicializado) return;
    _tokenController.text = settings.token ?? '';
    _baseUrlController.text = settings.baseUrl;
    _inicializado = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          _sincronizarControllers(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'La URL del orquestador y el token quedan guardados en este '
                'dispositivo (almacenamiento seguro). Nunca se hardcodean en '
                'la app.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL del orquestador',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tokenController,
                obscureText: !_tokenVisible,
                decoration: InputDecoration(
                  labelText: 'Token de autenticación',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_tokenVisible ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await ref.read(settingsProvider.notifier).guardarBaseUrl(_baseUrlController.text);
                  await ref.read(settingsProvider.notifier).guardarToken(_tokenController.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Ajustes guardados')));
                  }
                },
                child: const Text('Guardar'),
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
                      color: settings.servidorOk! ? Colors.green : Colors.red,
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
            ],
          );
        },
      ),
    );
  }
}
