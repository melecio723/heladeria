import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/whatsapp_notify.dart';

/// Abre el modal de notificación por WhatsApp con mensaje prellenado.
Future<void> showWhatsAppNotifyDialog({
  required BuildContext context,
  required Map<String, dynamic> cliente,
  required List<Map<String, dynamic>> creditos,
}) {
  final telefono = (cliente['telefono'] as String?)?.trim() ?? '';
  if (telefono.isEmpty) {
    showTelefonoFaltanteSnackBar(context);
    return Future.value();
  }

  return showDialog(
    context: context,
    builder: (ctx) => _WhatsAppNotifyDialog(
      cliente: cliente,
      creditos: creditos,
    ),
  );
}

class _WhatsAppNotifyDialog extends StatefulWidget {
  const _WhatsAppNotifyDialog({
    required this.cliente,
    required this.creditos,
  });

  final Map<String, dynamic> cliente;
  final List<Map<String, dynamic>> creditos;

  @override
  State<_WhatsAppNotifyDialog> createState() => _WhatsAppNotifyDialogState();
}

class _WhatsAppNotifyDialogState extends State<_WhatsAppNotifyDialog> {
  late final TextEditingController _mensajeCtrl;
  late final TextEditingController _firmaCtrl;
  bool _savingFirma = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final config = state.config;
    _firmaCtrl = TextEditingController(text: config['whatsapp_firma'] as String? ?? '');
    _mensajeCtrl = TextEditingController(text: _buildMessage(config));
    _firmaCtrl.addListener(_onFirmaChanged);
  }

  void _onFirmaChanged() {
    // Guardar firma automáticamente con debounce ligero vía post-frame.
    Future.microtask(_persistFirma);
  }

  Future<void> _persistFirma() async {
    if (_savingFirma) return;
    _savingFirma = true;
    try {
      await context.read<AppState>().saveConfig({'whatsapp_firma': _firmaCtrl.text.trim()});
    } finally {
      _savingFirma = false;
    }
  }

  String _buildMessage(Map<String, dynamic> config) {
    return buildCobranzaMessage(
      cliente: widget.cliente,
      creditos: widget.creditos,
      firma: _firmaCtrl.text.trim().isNotEmpty ? _firmaCtrl.text.trim() : null,
      nombreNegocio: config['nombre_negocio'] as String?,
    );
  }

  void _regenerar() {
    final config = context.read<AppState>().config;
    setState(() => _mensajeCtrl.text = _buildMessage(config));
  }

  Future<void> _abrirWhatsApp() async {
    final state = context.read<AppState>();
    final config = state.config;
    final codigoPais = (config['whatsapp_codigo_pais'] as String?) ?? '58';
    final telefono = widget.cliente['telefono'] as String? ?? '';

    final ok = await openWhatsApp(
      telefono: telefono,
      mensaje: _mensajeCtrl.text,
      codigoPais: codigoPais,
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp. Verifique el teléfono del cliente.')),
      );
    }
  }

  @override
  void dispose() {
    _firmaCtrl.removeListener(_onFirmaChanged);
    _mensajeCtrl.dispose();
    _firmaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.cliente['nombre'] as String? ?? '—';
    final codigo = widget.cliente['codigo'] as String? ?? '—';

    return Dialog(
      backgroundColor: BearColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const WhatsAppIcon(size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notificación por WhatsApp', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '$nombre ($codigo)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'VISTA PREVIA DEL MENSAJE (editable)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mensajeCtrl,
                maxLines: 12,
                minLines: 8,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  hintText: 'Mensaje de cobranza…',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'FIRMA DEL MENSAJE',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _firmaCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: Bear Helados - Tel: 0412-xxx',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Se guarda automáticamente en la configuración.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BearColors.warningLight,
                  borderRadius: BorderRadius.circular(BearTheme.radiusSm),
                  border: Border.all(color: BearColors.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: BearColors.warning.withValues(alpha: 0.9)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WhatsApp Web se abrirá en el navegador de tu sistema (Chrome, Edge, etc.) con el mensaje pre-cargado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BearColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _regenerar,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('REGENERAR'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _abrirWhatsApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: whatsappGreen,
                      foregroundColor: BearColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: const Text('Abrir WhatsApp'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón "Recordar" estilo OmniStock (verde claro con ícono WhatsApp).
class RecordarWhatsAppButton extends StatelessWidget {
  const RecordarWhatsAppButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: whatsappGreen.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WhatsAppIcon(size: 15),
              const SizedBox(width: 5),
              Text(
                'Recordar',
                style: TextStyle(
                  color: whatsappGreen.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resuelve datos del cliente y créditos pendientes para el recordatorio.
Map<String, dynamic>? resolveClienteForWhatsApp(
  AppState state, {
  String? clienteId,
  String? clienteNombre,
  String? clienteCodigo,
  String? clienteTelefono,
}) {
  Map<String, dynamic>? cliente;
  if (clienteId != null) {
    cliente = state.clientes.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['id'] == clienteId,
          orElse: () => null,
        );
  }
  cliente ??= {
    'nombre': clienteNombre ?? 'Cliente',
    'codigo': clienteCodigo ?? '—',
    'telefono': clienteTelefono,
    if (clienteId != null) 'id': clienteId,
  };
  if ((cliente['telefono'] as String?)?.trim().isEmpty != false && clienteTelefono != null) {
    cliente = {...cliente, 'telefono': clienteTelefono};
  }
  return cliente;
}

List<Map<String, dynamic>> creditosPendientesCliente(
  AppState state, {
  String? clienteId,
  String? clienteNombre,
  List<Map<String, dynamic>>? extra,
}) {
  final fromState = state.creditos.where((c) {
    if (c['estado'] == 'pagado') return false;
    if (clienteId != null) return c['cliente_id'] == clienteId;
    if (clienteNombre != null) return c['cliente_nombre'] == clienteNombre;
    return false;
  });
  final merged = <String, Map<String, dynamic>>{};
  for (final c in [...?extra, ...fromState]) {
    final id = c['id'] as String? ?? '${c['folio']}';
    merged[id] = c;
  }
  return merged.values.toList();
}
