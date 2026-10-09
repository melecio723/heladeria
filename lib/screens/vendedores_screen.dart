import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

class VendedoresScreen extends StatefulWidget {
  const VendedoresScreen({super.key});

  @override
  State<VendedoresScreen> createState() => _VendedoresScreenState();
}

class _VendedoresScreenState extends State<VendedoresScreen> {
  String _filter = '';

  void _showForm({Map<String, dynamic>? item}) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: item?['nombre'] ?? '');
    final telCtrl = TextEditingController(text: item?['telefono'] ?? '');
    final emailCtrl = TextEditingController(text: item?['email'] ?? '');
    final dirCtrl = TextEditingController(text: item?['direccion'] ?? '');
    final comisionCtrl = TextEditingController(text: '${item?['porcentaje_comision'] ?? 5}');
    String tipo = item?['tipo'] as String? ?? 'vendedor';
    String? promotorId = item?['promotor_id'] as String?;

    showBearFormDialog(
      context: context,
      title: item == null ? 'Nuevo vendedor / promotor' : 'Editar',
      primaryLabel: item == null ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty) return;
        final data = {
          'nombre': nombreCtrl.text.trim(),
          'tipo': tipo,
          'telefono': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
          'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
          'direccion': dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
          'porcentaje_comision': double.tryParse(comisionCtrl.text) ?? 5,
          'promotor_id': tipo == 'vendedor' ? promotorId : null,
        };
        try {
          if (item == null) {
            await state.addVendedor(data);
          } else {
            await state.editVendedor(item['id'] as String, data);
          }
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setLocal) => FormGrid(
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                  items: const [
                    DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                    DropdownMenuItem(value: 'promotor', child: Text('Promotor')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => tipo = v);
                  },
                ),
                FormFieldHint(
                  tipo == 'vendedor'
                      ? 'Los vendedores se asignan a clientes y ventas.'
                      : 'Los promotores supervisan vendedores; no se asignan directamente a clientes.',
                ),
              ],
            ),
            if (tipo == 'vendedor') ...[
              TextField(
                controller: comisionCtrl,
                decoration: const InputDecoration(labelText: 'Comisión de venta (%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              DropdownButtonFormField<String?>(
                value: promotorId,
                decoration: const InputDecoration(labelText: 'Promotor asignado'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Ninguno —')),
                  for (final p in state.promotores)
                    DropdownMenuItem(value: p['id'] as String, child: Text(p['nombre'] as String)),
                ],
                onChanged: (v) => setLocal(() => promotorId = v),
              ),
            ] else
              FormGridFull(
                child: TextField(
                  controller: comisionCtrl,
                  decoration: const InputDecoration(labelText: 'Comisión de venta (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            FormGridFull(
              child: TextField(controller: dirCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filtered(AppState state) {
    final all = [...state.vendedores, ...state.promotores];
    if (_filter.isEmpty) return all;
    return all.where((v) => v['tipo'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _filtered(state);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Vendedores y Promotores',
            subtitle: 'Asigna vendedores a promotores y define comisiones',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _FilterTab(label: 'Todos', selected: _filter == '', onTap: () => setState(() => _filter = '')),
              _FilterTab(label: 'Vendedores', selected: _filter == 'vendedor', onTap: () => setState(() => _filter = 'vendedor')),
              _FilterTab(label: 'Promotores', selected: _filter == 'promotor', onTap: () => setState(() => _filter = 'promotor')),
              const Spacer(),
              ToolbarNewButton(label: 'Nuevo', onPressed: () => _showForm()),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: items.isEmpty
                  ? const Center(child: Text('Sin registros.'))
                  : ScrollableDataTable(
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Tipo')),
                          DataColumn(label: Text('Comisión %')),
                          DataColumn(label: Text('Promotor')),
                          DataColumn(label: Text('Teléfono')),
                          DataColumn(label: Text('Estado')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: items.map((v) {
                          return DataRow(cells: [
                            DataCell(Text(v['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(_TipoBadge(tipo: v['tipo'] as String)),
                            DataCell(Text('${v['porcentaje_comision']}%')),
                            DataCell(Text(
                              v['promotor_nombre'] as String? ??
                                  (v['tipo'] == 'promotor' ? '—' : 'Sin asignar'),
                            )),
                            DataCell(Text((v['telefono'] as String?) ?? '—')),
                            DataCell(Text(v['activo'] == 0 ? 'Inactivo' : 'Activo')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RowActionButton(
                                  label: 'Editar',
                                  icon: Icons.edit_rounded,
                                  color: BearColors.indigo,
                                  onPressed: () => _showForm(item: v),
                                ),
                                const SizedBox(width: 6),
                                RowActionButton(
                                  label: 'Eliminar',
                                  icon: Icons.delete_outline_rounded,
                                  color: BearColors.danger,
                                  onPressed: () async {
                                    if (!await confirmDelete(context, message: '¿Eliminar este registro?')) return;
                                    try {
                                      await state.removeVendedor(v['id'] as String);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                      }
                                    }
                                  },
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? BearColors.indigo : BearColors.surface,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : BearColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({required this.tipo});

  final String tipo;

  @override
  Widget build(BuildContext context) {
    final color = tipo == 'promotor' ? BearColors.warning : BearColors.indigo;
    return StatusPill(label: tipo, color: color);
  }
}
