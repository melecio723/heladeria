import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

class ProductoresScreen extends StatelessWidget {
  const ProductoresScreen({super.key});

  void _showForm(BuildContext context, {Map<String, dynamic>? item}) {
    final nombreCtrl = TextEditingController(text: item?['nombre'] ?? '');
    final duenoCtrl = TextEditingController(text: item?['nombre_dueno'] ?? '');
    final telCtrl = TextEditingController(text: item?['telefono'] ?? '');
    final emailCtrl = TextEditingController(text: item?['email'] ?? '');
    final rfcCtrl = TextEditingController(text: item?['rfc'] ?? '');
    final dirCtrl = TextEditingController(text: item?['direccion'] ?? '');
    final notasCtrl = TextEditingController(text: item?['notas'] ?? '');

    showBearFormDialog(
      context: context,
      title: item == null ? 'Nuevo productor' : 'Editar productor',
      primaryLabel: item == null ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty) return;
        final data = {
          'nombre': nombreCtrl.text.trim(),
          'nombre_dueno': duenoCtrl.text.trim().isEmpty ? null : duenoCtrl.text.trim(),
          'telefono': telCtrl.text.trim().isEmpty ? null : telCtrl.text.trim(),
          'email': emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
          'rfc': rfcCtrl.text.trim().isEmpty ? null : rfcCtrl.text.trim(),
          'direccion': dirCtrl.text.trim().isEmpty ? null : dirCtrl.text.trim(),
          'notas': notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
        };
        try {
          if (item == null) {
            await context.read<AppState>().addProductor(data);
          } else {
            await context.read<AppState>().editProductor(item['id'] as String, data);
          }
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: FormGrid(
        children: [
          TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del negocio *'),
          ),
          TextField(
            controller: duenoCtrl,
            decoration: const InputDecoration(labelText: 'Nombre del dueño'),
          ),
          TextField(controller: telCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
          TextField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(controller: rfcCtrl, decoration: const InputDecoration(labelText: 'RFC')),
          FormGridFull(
            child: TextField(controller: dirCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
          ),
          FormGridFull(
            child: TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<AppState>().productores;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Productores',
            subtitle: 'Registra productores y datos del dueño',
            trailing: ToolbarNewButton(label: 'Nuevo productor', onPressed: () => _showForm(context)),
          ),
          const SizedBox(height: 20),
          Text('${items.length} registrados', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: items.isEmpty
                  ? const Center(child: Text('Sin productores. Crea el primero.'))
                  : ScrollableDataTable(
                        columns: const [
                          DataColumn(label: Text('Nombre')),
                          DataColumn(label: Text('Dueño')),
                          DataColumn(label: Text('Teléfono')),
                          DataColumn(label: Text('Email')),
                          DataColumn(label: Text('RFC')),
                          DataColumn(label: Text('Acciones')),
                        ],
                        rows: items.map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text((p['nombre_dueno'] as String?) ?? '—')),
                            DataCell(Text((p['telefono'] as String?) ?? '—')),
                            DataCell(Text((p['email'] as String?) ?? '—')),
                            DataCell(Text((p['rfc'] as String?) ?? '—')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RowActionButton(
                                  label: 'Editar',
                                  icon: Icons.edit_rounded,
                                  color: BearColors.indigo,
                                  onPressed: () => _showForm(context, item: p),
                                ),
                                const SizedBox(width: 6),
                                RowActionButton(
                                  label: 'Eliminar',
                                  icon: Icons.delete_outline_rounded,
                                  color: BearColors.danger,
                                  onPressed: () async {
                                    if (!await confirmDelete(context, message: '¿Eliminar este productor?')) return;
                                    try {
                                      await context.read<AppState>().removeProductor(p['id'] as String);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(content: Text(e.toString())));
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
