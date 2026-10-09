import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  String _search = '';

  void _recalcPrecioVenta(
    TextEditingController costoCtrl,
    TextEditingController margenCtrl,
    TextEditingController ventaCtrl,
    void Function(void Function()) setLocal,
  ) {
    final costo = double.tryParse(costoCtrl.text) ?? 0;
    final margen = double.tryParse(margenCtrl.text) ?? 0;
    final precio = calcularPrecioVenta(costo, margen);
    setLocal(() => ventaCtrl.text = precio.toStringAsFixed(2));
  }

  void _showForm({Map<String, dynamic>? producto}) {
    final state = context.read<AppState>();
    final nombreCtrl = TextEditingController(text: producto?['nombre'] ?? '');
    final catCtrl = TextEditingController(text: producto?['categoria'] ?? '');
    final descripcionCtrl = TextEditingController(text: producto?['descripcion'] ?? '');
    var presentacion = (producto?['presentacion'] as String?)?.toLowerCase() == 'combo'
        ? 'combo'
        : 'individual';
    final costoCtrl = TextEditingController(
      text: producto != null ? '${producto['precio_costo'] ?? 0}' : '',
    );
    final margenCtrl = TextEditingController(
      text: producto != null ? '${producto['margen_porcentaje'] ?? 0}' : '',
    );
    final ventaCtrl = TextEditingController(
      text: producto != null ? '${producto['precio_venta'] ?? 0}' : '',
    );
    final stockInicialCtrl = TextEditingController();

    showBearFormDialog(
      context: context,
      title: producto == null ? 'Nuevo producto' : 'Editar producto',
      primaryLabel: producto == null ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty) return;
        final costo = double.tryParse(costoCtrl.text) ?? 0;
        final margen = double.tryParse(margenCtrl.text) ?? 0;
        final data = {
          'nombre': nombreCtrl.text.trim(),
          'categoria': catCtrl.text.trim().isEmpty ? null : catCtrl.text.trim(),
          'descripcion': descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
          'presentacion': presentacion,
          'precio_costo': costo,
          'margen_porcentaje': margen,
        };
        if (producto == null) {
          final stockInicial = double.tryParse(stockInicialCtrl.text.trim()) ?? 0;
          if (stockInicial < 0) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stock inicial inválido')),
              );
            }
            return;
          }
          if (stockInicial > 0) data['stock_inicial'] = stockInicial;
        }
        try {
          if (producto == null) {
            await state.addProducto(data);
          } else {
            await state.editProducto(producto['id'] as String, data);
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
            TextField(
              controller: catCtrl,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            FormGridFull(
              child: TextField(
                controller: descripcionCtrl,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Va debajo del nombre en la etiqueta (ej. "Tinita")',
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              value: presentacion,
              decoration: const InputDecoration(labelText: 'Presentación'),
              items: const [
                DropdownMenuItem(value: 'individual', child: Text('Individual')),
                DropdownMenuItem(value: 'combo', child: Text('Combo')),
              ],
              onChanged: (v) => setLocal(() => presentacion = v ?? 'individual'),
            ),
            TextField(
              controller: costoCtrl,
              decoration: const InputDecoration(labelText: 'Precio costo (USD)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalcPrecioVenta(costoCtrl, margenCtrl, ventaCtrl, setLocal),
            ),
            TextField(
              controller: margenCtrl,
              decoration: const InputDecoration(labelText: 'Margen %'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _recalcPrecioVenta(costoCtrl, margenCtrl, ventaCtrl, setLocal),
            ),
            TextField(
              controller: ventaCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Precio venta (calculado)'),
            ),
            if (producto == null) ...[
              TextField(
                controller: stockInicialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Stock inicial',
                  hintText: 'Cantidad actual en almacén (opcional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMovimiento(Map<String, dynamic> producto, {required bool entrada}) {
    final state = context.read<AppState>();
    final cantCtrl = TextEditingController();
    var fecha = todayISO();
    final stock = (producto['stock_actual'] as num?)?.toDouble() ?? 0;

    showBearFormDialog(
      context: context,
      title: entrada ? 'Entrada de inventario' : 'Salida de inventario',
      primaryLabel: 'Registrar',
      onPrimary: () async {
        final cant = double.tryParse(cantCtrl.text);
        if (cant == null || cant <= 0) return;
        try {
          if (entrada) {
            await state.entradaInventario(producto['id'] as String, cant, fecha: fecha);
          } else {
            await state.salidaInventario(producto['id'] as String, cant, fecha: fecha);
          }
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${producto['nombre']} — Stock actual: ${stock.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FormGrid(
              children: [
                TextField(
                  controller: cantCtrl,
                  decoration: const InputDecoration(labelText: 'Cantidad *'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                _DateField(
                  label: 'Fecha',
                  value: fecha,
                  onChanged: (v) => setLocal(() => fecha = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMovimientos(Map<String, dynamic> producto) async {
    final state = context.read<AppState>();
    final movs = await state.getMovimientosInventario(productoId: producto['id'] as String);
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BearColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Movimientos — ${producto['nombre']}', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                Expanded(
                  child: movs.isEmpty
                      ? const Center(child: Text('Sin movimientos registrados.'))
                      : ScrollableDataTable(
                          columns: const [
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Tipo')),
                            DataColumn(label: Text('Cantidad')),
                            DataColumn(label: Text('Referencia')),
                          ],
                          rows: movs.map((m) {
                            final tipo = m['tipo'] as String? ?? '';
                            return DataRow(cells: [
                              DataCell(Text(fmtDate(m['fecha'] as String?))),
                              DataCell(Text(_tipoLabel(tipo))),
                              DataCell(Text('${(m['cantidad'] as num?)?.toStringAsFixed(0) ?? '0'}')),
                              DataCell(Text(
                                m['referencia_credito_id'] != null
                                    ? 'Venta'
                                    : ((m['nota'] as String?)?.isNotEmpty == true
                                        ? m['nota'] as String
                                        : '—'),
                              )),
                            ]);
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      case 'venta':
        return 'Venta';
      default:
        return tipo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.productos;
    final isAdmin = state.isAdmin;
    final q = _search.trim().toLowerCase();
    final productos = q.isEmpty
        ? all
        : all.where((p) {
            final nombre = (p['nombre'] as String? ?? '').toLowerCase();
            final cat = (p['categoria'] as String? ?? '').toLowerCase();
            return nombre.contains(q) || cat.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Inventario',
            subtitle: 'Catálogo de productos e inventario',
            trailing: isAdmin
                ? ToolbarNewButton(label: 'Nuevo producto', onPressed: () => _showForm())
                : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SearchField(
                  hintText: 'Buscar por Nombre o Categoría...',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 16),
              Text('${productos.length} productos', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: productos.isEmpty
                  ? const Center(child: Text('Sin productos. Registra el primero.'))
                  : ScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Categoría')),
                        DataColumn(label: Text('Costo')),
                        DataColumn(label: Text('Margen %')),
                        DataColumn(label: Text('Precio venta')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: productos.map((p) {
                        final stock = (p['stock_actual'] as num?)?.toDouble() ?? 0;
                        final detalle = productoDetalle(
                          descripcion: p['descripcion'] as String?,
                          presentacion: p['presentacion'] as String?,
                        );
                        return DataRow(cells: [
                          DataCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(p['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(detalle, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          )),
                          DataCell(Text((p['categoria'] as String?) ?? '—')),
                          DataCell(Text(money(p['precio_costo'] as num?))),
                          DataCell(Text('${p['margen_porcentaje'] ?? 0}%')),
                          DataCell(Text(money(p['precio_venta'] as num?))),
                          DataCell(
                            Text(
                              stock.toStringAsFixed(0),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: stock <= 0 ? BearColors.red : null,
                              ),
                            ),
                          ),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin) ...[
                                RowActionButton(
                                  label: 'Editar',
                                  icon: Icons.edit_rounded,
                                  color: BearColors.indigo,
                                  onPressed: () => _showForm(producto: p),
                                ),
                                const SizedBox(width: 6),
                                RowActionButton(
                                  label: 'Stock',
                                  icon: Icons.add_rounded,
                                  color: BearColors.success,
                                  onPressed: () => _showMovimiento(p, entrada: true),
                                ),
                                const SizedBox(width: 6),
                                RowActionButton(
                                  label: 'Stock',
                                  icon: Icons.remove_rounded,
                                  color: BearColors.warning,
                                  onPressed: () => _showMovimiento(p, entrada: false),
                                ),
                                const SizedBox(width: 6),
                              ],
                              RowActionButton(
                                label: 'Historial',
                                icon: Icons.history_rounded,
                                onPressed: () => _showMovimientos(p),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 6),
                                RowActionButton(
                                  label: 'Eliminar',
                                  icon: Icons.delete_outline_rounded,
                                  color: BearColors.danger,
                                  onPressed: () async {
                                    if (!await confirmDelete(context, message: '¿Eliminar este producto?')) return;
                                    try {
                                      await context.read<AppState>().removeProducto(p['id'] as String);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                      }
                                    }
                                  },
                                ),
                              ],
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

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(value) ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (picked != null) {
          onChanged(
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(fmtDate(value)),
      ),
    );
  }
}
