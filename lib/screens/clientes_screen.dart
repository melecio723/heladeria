import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String _search = '';

  void _showForm({Map<String, dynamic>? cliente}) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: cliente?['nombre'] ?? '');
    final telCtrl = TextEditingController(text: cliente?['telefono'] ?? '');
    final dirCtrl = TextEditingController(text: cliente?['direccion'] ?? '');
    final notasCtrl = TextEditingController(text: cliente?['notas'] ?? '');
    String? vendedorId = cliente?['vendedor_id'] as String?;

    showBearFormDialog(
      context: context,
      title: cliente == null ? 'Nuevo cliente' : 'Editar cliente',
      primaryLabel: cliente == null ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty ||
            vendedorId == null ||
            vendedorId!.isEmpty)
          return;
        final data = {
          'nombre': nombreCtrl.text.trim(),
          'telefono': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
          'direccion': dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
          'vendedor_id': vendedorId,
          'notas': notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
        };
        try {
          if (cliente == null) {
            await state.addCliente(data);
          } else {
            await state.editCliente(cliente['id'] as String, data);
          }
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setLocal) {
          final vendedores = state.vendedores;
          return FormGrid(
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    value: vendedorId,
                    decoration: const InputDecoration(
                      labelText: 'Vendedor asignado *',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— Seleccionar —'),
                      ),
                      for (final v in vendedores)
                        DropdownMenuItem(
                          value: v['id'] as String,
                          child: Text(
                            '${v['nombre']} (${v['porcentaje_comision']}%)'
                            '${v['promotor_nombre'] != null ? ' — ${v['promotor_nombre']}' : ''}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => vendedorId = v),
                  ),
                  if (vendedores.isEmpty)
                    const FormFieldHint(
                      'No hay vendedores activos. Ve a Vendedores y crea uno con tipo Vendedor (los promotores no se asignan a clientes).',
                    ),
                ],
              ),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              FormGridFull(
                child: TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
              ),
              FormGridFull(
                child: TextField(
                  controller: notasCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.clientes;
    final isAdmin = state.isAdmin;
    final q = _search.trim().toLowerCase();
    final clientes = q.isEmpty
        ? all
        : all.where((c) {
            final nombre = (c['nombre'] as String? ?? '').toLowerCase();
            final vend = (c['vendedor_nombre'] as String? ?? '').toLowerCase();
            final tel = (c['telefono'] as String? ?? '').toLowerCase();
            return nombre.contains(q) || vend.contains(q) || tel.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Clientes',
            subtitle: 'Catálogo de clientes con vendedor asignado',
            trailing: ToolbarNewButton(
              label: 'Nuevo cliente',
              onPressed: () => _showForm(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Buscar por Nombre, Vendedor o Teléfono...',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${clientes.length} clientes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: clientes.isEmpty
                  ? const Center(
                      child: Text('Sin clientes. Registra el primero.'),
                    )
                  : ScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Vendedor asignado')),
                        DataColumn(label: Text('Teléfono')),
                        DataColumn(label: Text('Dirección')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: clientes.map((c) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${c['codigo'] ?? '—'}')),
                            DataCell(
                              Text(
                                c['nombre'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text((c['vendedor_nombre'] as String?) ?? '—'),
                            ),
                            DataCell(Text((c['telefono'] as String?) ?? '—')),
                            DataCell(Text((c['direccion'] as String?) ?? '—')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RowActionButton(
                                    label: 'Editar',
                                    icon: Icons.edit_rounded,
                                    color: BearColors.indigo,
                                    onPressed: () => _showForm(cliente: c),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 6),
                                    RowActionButton(
                                      label: 'Eliminar',
                                      icon: Icons.delete_outline_rounded,
                                      color: BearColors.danger,
                                      onPressed: () async {
                                        if (!await confirmDelete(
                                          context,
                                          message: '¿Eliminar este cliente?',
                                        ))
                                          return;
                                        await context
                                            .read<AppState>()
                                            .removeCliente(c['id'] as String);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
