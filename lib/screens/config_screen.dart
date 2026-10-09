import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/form_dialog.dart';
import '../widgets/ui_kit.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _dirCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _whatsappFirmaCtrl;
  late final TextEditingController _whatsappPaisCtrl;
  late final TextEditingController _impuestoCtrl;
  late final TextEditingController _claveSeguridadCtrl;
  late final TextEditingController _claveSeguridadConfirmCtrl;
  bool _aplicaImpuesto = false;
  int _anchoTicket = 58;
  String _modoCaja = 'unica';
  bool _initialized = false;
  bool _saving = false;
  bool _savingClave = false;
  bool _resetting = false;
  bool _backingUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final config = context.read<AppState>().config;
    _nombreCtrl = TextEditingController(text: config['nombre_negocio'] ?? 'Bear Helados');
    _dirCtrl = TextEditingController(text: config['direccion'] ?? '');
    _telCtrl = TextEditingController(text: config['telefono'] ?? '');
    _whatsappFirmaCtrl = TextEditingController(text: config['whatsapp_firma'] ?? '');
    _whatsappPaisCtrl = TextEditingController(text: config['whatsapp_codigo_pais'] ?? '58');
    _impuestoCtrl = TextEditingController(text: '${config['impuesto_porcentaje'] ?? 16}');
    _claveSeguridadCtrl = TextEditingController();
    _claveSeguridadConfirmCtrl = TextEditingController();
    _aplicaImpuesto = config['aplica_impuesto'] == true;
    _anchoTicket = (config['ancho_ticket_mm'] as int?) ?? 58;
    _modoCaja = (config['modo_caja'] as String?) ?? 'unica';
    _initialized = true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    _whatsappFirmaCtrl.dispose();
    _whatsappPaisCtrl.dispose();
    _impuestoCtrl.dispose();
    _claveSeguridadCtrl.dispose();
    _claveSeguridadConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().saveConfig({
        'nombre_negocio': _nombreCtrl.text.trim(),
        'direccion': _dirCtrl.text.trim(),
        'telefono': _telCtrl.text.trim(),
        'whatsapp_firma': _whatsappFirmaCtrl.text.trim(),
        'whatsapp_codigo_pais': _whatsappPaisCtrl.text.trim().isEmpty ? '58' : _whatsappPaisCtrl.text.trim(),
        'impuesto_porcentaje': int.tryParse(_impuestoCtrl.text) ?? 16,
        'aplica_impuesto': _aplicaImpuesto,
        'ancho_ticket_mm': _anchoTicket,
        'modo_caja': _modoCaja,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveClaveSeguridad() async {
    final clave = _claveSeguridadCtrl.text.trim();
    final confirm = _claveSeguridadConfirmCtrl.text.trim();
    if (clave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la nueva clave de seguridad')),
      );
      return;
    }
    if (clave != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las claves no coinciden')),
      );
      return;
    }
    setState(() => _savingClave = true);
    try {
      await context.read<AppState>().saveConfig({'clave_seguridad': clave});
      _claveSeguridadCtrl.clear();
      _claveSeguridadConfirmCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clave de seguridad guardada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _savingClave = false);
    }
  }

  Future<void> _backupDatabase() async {
    setState(() => _backingUp = true);
    try {
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final location = await getSaveLocation(
        suggestedName: 'gestor-creditos-backup-$stamp.db',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'SQLite', extensions: ['db']),
        ],
      );
      if (location == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Respaldo cancelado')),
          );
        }
        return;
      }

      var dest = location.path;
      if (!dest.toLowerCase().endsWith('.db')) dest = '$dest.db';
      await context.read<AppState>().backupDatabase(dest);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respaldo guardado en: $dest')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo respaldar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _resetOperativos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BearColors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reiniciar datos operativos'),
        content: const Text(
          'Se eliminarán todas las ventas, pagos, cuotas, movimientos de caja e inventario. '
          'Se restaurará el stock descontado por ventas y los contadores de factura volverán a cero. '
          'Clientes, productos y usuarios no se borran.',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BearColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _resetting = true);
    try {
      await context.read<AppState>().resetDatosOperativos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos operativos reiniciados')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  Widget _buildModoCajaCard(BuildContext context) {
    final cajas = context.watch<AppState>().cajas;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: BearColors.indigo),
                const SizedBox(width: 10),
                Text('Modo de caja', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Define cómo se controla el efectivo del negocio.',
              style: TextStyle(color: BearColors.textMuted),
            ),
            const SizedBox(height: 16),
            _ModoCajaOption(
              value: 'unica',
              groupValue: _modoCaja,
              title: 'Una sola caja',
              subtitle: 'Una única caja "Caja principal" para todo el negocio.',
              onChanged: (v) => setState(() => _modoCaja = v),
            ),
            const SizedBox(height: 10),
            _ModoCajaOption(
              value: 'multiple',
              groupValue: _modoCaja,
              title: 'Multi-caja',
              subtitle: 'Varias cajas (ej. Caja 1, Caja 2) con apertura y cierre independientes.',
              onChanged: (v) => setState(() => _modoCaja = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Guardando...' : 'Guardar modo de caja'),
                ),
              ],
            ),
            if (_modoCaja == 'multiple') ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text('Cajas registradas', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  TextButton.icon(
                    onPressed: () => _showCajaForm(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nueva caja'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final c in cajas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.point_of_sale_rounded,
                    color: (c['activa'] as int? ?? 1) == 1 ? BearColors.indigo : BearColors.grayLight,
                  ),
                  title: Text(c['nombre'] as String),
                  subtitle: Text((c['activa'] as int? ?? 1) == 1 ? 'Activa' : 'Inactiva'),
                  trailing: RowActionButton(
                    label: 'Editar',
                    icon: Icons.edit_rounded,
                    color: BearColors.indigo,
                    onPressed: () => _showCajaForm(caja: c),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCajaForm({Map<String, dynamic>? caja}) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: caja?['nombre'] as String? ?? '');
    var activa = (caja?['activa'] as int? ?? 1) == 1;
    showBearFormDialog(
      context: context,
      title: caja == null ? 'Nueva caja' : 'Editar caja',
      primaryLabel: caja == null ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty) return;
        try {
          if (caja == null) {
            await state.addCaja({'nombre': nombreCtrl.text.trim(), 'activa': activa});
          } else {
            await state.editCaja(caja['id'] as String, {'nombre': nombreCtrl.text.trim(), 'activa': activa});
          }
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la caja *'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Caja activa'),
              value: activa,
              activeColor: BearColors.indigo,
              onChanged: (v) => setLocal(() => activa = v ?? true),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: ListView(
        children: [
          const PageHeader(
            title: 'Configuración',
            subtitle: 'Datos del negocio para tickets térmicos y reportes impresos',
          ),
          const SizedBox(height: 24),
          _buildModoCajaCard(context),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/images/bear_logo_nobg.png', height: 100)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del negocio *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _dirCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _whatsappFirmaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Firma WhatsApp (opcional)',
                      hintText: 'Ej: Bear Helados - Tel: 0412-xxx',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FormGrid(
                    children: [
                      TextField(controller: _telCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
                      TextField(
                        controller: _whatsappPaisCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Código país WhatsApp',
                          hintText: '58',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      DropdownButtonFormField<int>(
                        value: _anchoTicket,
                        decoration: const InputDecoration(labelText: 'Ancho ticket (mm)'),
                        items: const [
                          DropdownMenuItem(value: 58, child: Text('58 mm')),
                          DropdownMenuItem(value: 80, child: Text('80 mm')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _anchoTicket = v);
                        },
                      ),
                      TextField(
                        controller: _impuestoCtrl,
                        decoration: const InputDecoration(labelText: 'Impuesto (%)'),
                        keyboardType: TextInputType.number,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aplicar impuesto en ticket'),
                        value: _aplicaImpuesto,
                        activeColor: BearColors.indigo,
                        onChanged: (v) => setState(() => _aplicaImpuesto = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Guardando...' : 'Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: BearColors.indigo),
                      const SizedBox(width: 10),
                      Text('Clave de seguridad', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.watch<AppState>().config['tiene_clave_seguridad'] == true
                        ? 'Clave activa. Se pide al editar o borrar una venta. Solo el administrador puede cambiarla.'
                        : 'Aún no hay clave. Configúrala para proteger la edición y el borrado de ventas.',
                    style: const TextStyle(color: BearColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _claveSeguridadCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva clave de seguridad *',
                      hintText: 'Mínimo 4 caracteres',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _claveSeguridadConfirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmar clave *'),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _savingClave ? null : _saveClaveSeguridad,
                      child: Text(_savingClave ? 'Guardando…' : 'Guardar clave'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt_rounded, color: BearColors.danger),
              title: const Text('Reiniciar datos operativos'),
              subtitle: const Text(
                'Borra ventas de prueba, pagos y movimientos de caja. Deja el sistema en cero para empezar de nuevo.',
              ),
              trailing: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: BearColors.danger),
                onPressed: _resetting ? null : _resetOperativos,
                child: Text(_resetting ? 'Reiniciando…' : 'Reiniciar'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage, color: BearColors.indigo),
              title: const Text('Base de datos local'),
              subtitle: const Text(
                'SQLite offline. Descarga un respaldo completo (.db) eligiendo dónde guardarlo.',
              ),
              trailing: FilledButton.icon(
                onPressed: _backingUp ? null : _backupDatabase,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(_backingUp ? 'Guardando…' : 'Respaldar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModoCajaOption extends StatelessWidget {
  const _ModoCajaOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Material(
      color: selected ? BearColors.indigo.withValues(alpha: 0.08) : BearColors.bgAlt,
      borderRadius: BorderRadius.circular(BearTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(BearTheme.radiusSm),
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BearTheme.radiusSm),
            border: Border.all(
              color: selected ? BearColors.indigo : BearColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? BearColors.indigo : BearColors.grayLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
