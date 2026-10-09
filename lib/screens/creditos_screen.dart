import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/format.dart';
import '../utils/print_ticket.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/security_key_dialog.dart';
import '../widgets/ui_kit.dart';
import '../widgets/whatsapp_notify_dialog.dart';

const _cuotasOpciones = [1, 2, 3, 4, 5, 6, 8, 10, 12];

class CreditosScreen extends StatefulWidget {
  const CreditosScreen({super.key});

  @override
  State<CreditosScreen> createState() => _CreditosScreenState();
}

class _CreditosScreenState extends State<CreditosScreen> {
  String _filtroEstado = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNuevaVenta() {
    final state = context.read<AppState>();
    if (state.clientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero registra al menos un cliente')),
      );
      return;
    }

    String? clienteId;
    final clienteSearchCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var lineItems = <Map<String, dynamic>>[];
    int numCuotas = 1;
    var fechaVenta = todayISO();
    var fechaPrimeraCuota = todayISO();
    var cuotasPreview = <Map<String, dynamic>>[];

    double itemsTotal() {
      return lineItems.fold<double>(0, (s, i) {
        final q = (i['cantidad'] as num?)?.toDouble() ?? 0;
        final p = (i['precio_unitario'] as num?)?.toDouble() ?? 0;
        return s + q * p;
      });
    }

    void recalcCuotas(void Function(void Function()) setLocal) {
      final monto = itemsTotal();
      if (monto > 0 && fechaPrimeraCuota.isNotEmpty) {
        setLocal(
          () => cuotasPreview = generarCuotas(
            monto,
            numCuotas,
            fechaPrimeraCuota,
          ),
        );
      } else {
        setLocal(() => cuotasPreview = []);
      }
    }

    List<Map<String, dynamic>> filteredClientes() {
      final q = clienteSearchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return [];
      return state.clientes
          .where((c) {
            final nombre = (c['nombre'] as String? ?? '').toLowerCase();
            final codigo = (c['codigo'] as String? ?? '').toLowerCase();
            final vendedor = (c['vendedor_nombre'] as String? ?? '')
                .toLowerCase();
            return nombre.contains(q) ||
                codigo.contains(q) ||
                vendedor.contains(q);
          })
          .take(8)
          .toList();
    }

    List<Map<String, dynamic>> filteredProducts() {
      final q = searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return [];
      return state.productos
          .where((p) {
            final nombre = (p['nombre'] as String? ?? '').toLowerCase();
            final cat = (p['categoria'] as String? ?? '').toLowerCase();
            return nombre.contains(q) || cat.contains(q);
          })
          .take(8)
          .toList();
    }

    showBearFormDialog(
      context: context,
      title: 'Nueva venta a crédito',
      primaryLabel: 'Registrar e imprimir',
      onPrimary: () async {
        if (clienteId == null || clienteId!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona un cliente')),
          );
          return;
        }
        final payloadItems = lineItems
            .where((i) => (i['descripcion'] as String? ?? '').trim().isNotEmpty)
            .map((i) {
              final detalle = (i['detalle'] as String?)?.trim();
              final cant = (i['cantidad'] as num?)?.round() ?? 1;
              return {
                if (i['producto_id'] != null) 'producto_id': i['producto_id'],
                'descripcion': (i['descripcion'] as String).trim(),
                if (detalle != null && detalle.isNotEmpty) 'detalle': detalle,
                'cantidad': cant < 1 ? 1 : cant,
                'precio_unitario':
                    (i['precio_unitario'] as num?)?.toDouble() ?? 0,
              };
            })
            .toList();
        final monto = payloadItems.isNotEmpty
            ? payloadItems.fold<double>(0, (s, i) {
                return s +
                    (i['cantidad'] as num).toDouble() *
                        (i['precio_unitario'] as num).toDouble();
              })
            : 0.0;
        if (monto <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agrega productos del catálogo o líneas de venta'),
            ),
          );
          return;
        }
        final montoRedondeado = (monto * 100).round() / 100;
        final cuotas = cuotasPreview.isNotEmpty
            ? cuotasPreview
            : generarCuotas(monto, numCuotas, fechaPrimeraCuota);

        try {
          final credito = await state.addCredito({
            'cliente_id': clienteId,
            'monto_total': montoRedondeado,
            'abono': 0,
            'descripcion': descCtrl.text.trim().isEmpty
                ? payloadItems.map((i) => i['descripcion']).join(', ')
                : descCtrl.text.trim(),
            'fecha_venta': fechaVenta,
            'cuotas': cuotas,
            'items': payloadItems,
          });
          if (context.mounted) {
            Navigator.pop(context);
            final cliente = state.clientes.firstWhere(
              (c) => c['id'] == clienteId,
            );
            await runPrintAction(
              context,
              () => printSecuencialVenta(
                config: state.config,
                credito: {...credito, 'cliente_nombre': cliente['nombre']},
                cliente: cliente,
              ),
            );
          }
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
          final clienteSel = clienteId != null
              ? state.clientes.cast<Map<String, dynamic>?>().firstWhere(
                  (c) => c!['id'] == clienteId,
                  orElse: () => null,
                )
              : null;
          final total = itemsTotal();
          final sugerencias = filteredProducts();
          final clientesSugeridos = filteredClientes();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: clienteSearchCtrl,
                decoration: InputDecoration(
                  labelText: 'Buscar cliente *',
                  hintText: 'Nombre, código o vendedor…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: clienteId != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setLocal(() {
                            clienteId = null;
                            clienteSearchCtrl.clear();
                          }),
                        )
                      : null,
                ),
                onChanged: (_) => setLocal(() => clienteId = null),
              ),
              if (clienteId == null && clientesSugeridos.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 4),
                  child: Column(
                    children: [
                      for (final c in clientesSugeridos)
                        ListTile(
                          dense: true,
                          title: Text(c['nombre'] as String? ?? '—'),
                          subtitle: Text(
                            'Cód. ${c['codigo'] ?? '—'} · Vendedor: ${c['vendedor_nombre'] ?? '—'}',
                          ),
                          onTap: () => setLocal(() {
                            clienteId = c['id'] as String;
                            clienteSearchCtrl.text =
                                c['nombre'] as String? ?? '';
                          }),
                        ),
                    ],
                  ),
                ),
              if (clienteSel != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BearColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BearColors.border),
                  ),
                  child: Text(
                    'Vendedor asignado: ${clienteSel['vendedor_nombre'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Productos', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  hintText: 'Nombre o categoría…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
              if (sugerencias.isNotEmpty) ...[
                const SizedBox(height: 4),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final p in sugerencias)
                        ListTile(
                          dense: true,
                          title: Text(p['nombre'] as String),
                          subtitle: Text(
                            '${productoDetalle(descripcion: p['descripcion'] as String?, presentacion: p['presentacion'] as String?)} · ${money(p['precio_venta'] as num?)} · Stock: ${(p['stock_actual'] as num?)?.toStringAsFixed(0) ?? '0'}',
                          ),
                          onTap: () {
                            setLocal(() {
                              lineItems.add({
                                'producto_id': p['id'],
                                'descripcion': p['nombre'],
                                'detalle': productoDetalle(
                                  descripcion: p['descripcion'] as String?,
                                  presentacion: p['presentacion'] as String?,
                                ),
                                'cantidad': 1,
                                'precio_unitario':
                                    (p['precio_venta'] as num?)?.toDouble() ??
                                    0,
                                'stock_disponible':
                                    (p['stock_actual'] as num?)?.toDouble() ??
                                    0,
                              });
                              searchCtrl.clear();
                              recalcCuotas(setLocal);
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
              if (state.productos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: FormFieldHint(
                    'No hay productos en el catálogo. Puedes agregar líneas manuales abajo.',
                  ),
                ),
              const SizedBox(height: 8),
              if (lineItems.isNotEmpty) ...[
                _LineItemsEditor(
                  items: lineItems,
                  onChanged: () {
                    recalcCuotas(setLocal);
                    setLocal(() {});
                  },
                  onRemove: (index) {
                    setLocal(() {
                      lineItems.removeAt(index);
                      recalcCuotas(setLocal);
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${money(total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: () {
                  setLocal(() {
                    lineItems.add({
                      'descripcion': '',
                      'cantidad': 1,
                      'precio_unitario': 0.0,
                    });
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar línea manual'),
              ),
              const SizedBox(height: 12),
              FormGrid(
                children: [
                  _DateField(
                    label: 'Fecha venta *',
                    value: fechaVenta,
                    onChanged: (v) => setLocal(() => fechaVenta = v),
                  ),
                  DropdownButtonFormField<int>(
                    value: numCuotas,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuotas *',
                    ),
                    items: [
                      for (final n in _cuotasOpciones)
                        DropdownMenuItem(
                          value: n,
                          child: Text('$n ${n == 1 ? 'pago' : 'pagos'}'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => numCuotas = v);
                        recalcCuotas(setLocal);
                      }
                    },
                  ),
                  _DateField(
                    label: 'Fecha 1ª cuota *',
                    value: fechaPrimeraCuota,
                    onChanged: (v) {
                      setLocal(() => fechaPrimeraCuota = v);
                      recalcCuotas(setLocal);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              if (cuotasPreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Cuotas de pago',
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ScrollableDataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Monto')),
                    DataColumn(label: Text('Vence')),
                  ],
                  rows: [
                    for (var i = 0; i < cuotasPreview.length; i++)
                      DataRow(
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(
                            Text(money(cuotasPreview[i]['monto'] as num?)),
                          ),
                          DataCell(
                            Text(
                              fmtDate(
                                cuotasPreview[i]['fecha_vencimiento']
                                    as String?,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showPago(Map<String, dynamic> credito) {
    final montoCtrl = TextEditingController();
    var fechaPago = todayISO();
    String metodo = 'efectivo';
    final saldo = (credito['saldo'] as num?)?.toDouble() ?? 0;

    showBearFormDialog(
      context: context,
      title: 'Registrar pago — ${credito['folio']}',
      primaryLabel: 'Registrar pago',
      onPrimary: () async {
        final m = double.tryParse(montoCtrl.text);
        if (m == null || m <= 0) return;
        try {
          await context.read<AppState>().addPago(credito['id'] as String, {
            'monto': m,
            'fecha_pago': fechaPago,
            'metodo': metodo,
          });
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
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Saldo pendiente: ${money(saldo)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FormGrid(
              children: [
                TextField(
                  controller: montoCtrl,
                  decoration: const InputDecoration(labelText: 'Monto *'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                _DateField(
                  label: 'Fecha pago *',
                  value: fechaPago,
                  onChanged: (v) => setLocal(() => fechaPago = v),
                ),
                DropdownButtonFormField<String>(
                  value: metodo,
                  decoration: const InputDecoration(labelText: 'Método'),
                  items: const [
                    DropdownMenuItem(
                      value: 'efectivo',
                      child: Text('Efectivo'),
                    ),
                    DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia'),
                    ),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => metodo = v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditar(Map<String, dynamic> resumen) async {
    final unlocked = await askSecurityKey(
      context,
      title: 'Editar venta',
      message: 'Ingresa la clave de seguridad para editar esta venta.',
    );
    if (!unlocked || !mounted) return;

    final state = context.read<AppState>();
    final credito = await state.getCreditoDetail(resumen['id'] as String);
    if (!mounted || credito == null) return;

    final descCtrl = TextEditingController(
      text: credito['descripcion'] as String? ?? '',
    );
    final notasCtrl = TextEditingController(
      text: credito['notas'] as String? ?? '',
    );

    await showBearFormDialog(
      context: context,
      title: 'Editar venta — ${credito['folio']}',
      primaryLabel: 'Guardar',
      onPrimary: () async {
        try {
          await state.editCredito(credito['id'] as String, {
            'descripcion': descCtrl.text,
            'notas': notasCtrl.text,
          });
          if (mounted) Navigator.pop(context);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cliente: ${credito['cliente_nombre'] ?? '—'} · Total: ${money(credito['monto_total'] as num?)}',
            style: const TextStyle(color: BearColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notasCtrl,
            decoration: const InputDecoration(labelText: 'Notas'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarVenta(Map<String, dynamic> resumen) async {
    final unlocked = await askSecurityKey(
      context,
      title: 'Borrar venta',
      message: 'Ingresa la clave de seguridad para borrar esta venta.',
    );
    if (!unlocked || !mounted) return;

    final folio = resumen['numero_factura'] ?? resumen['folio'] ?? '';
    final ok = await confirmDelete(
      context,
      message:
          '¿Eliminar la venta $folio de ${resumen['cliente_nombre'] ?? 'cliente'}?\n'
          'Se restaurará el stock y se quitarán pagos y cuotas asociados.',
    );
    if (!ok || !mounted) return;

    try {
      await context.read<AppState>().removeCredito(resumen['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Venta eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _showDetalle(Map<String, dynamic> resumen) async {
    final state = context.read<AppState>();
    final credito = await state.getCreditoDetail(resumen['id'] as String);
    if (!mounted || credito == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: BearColors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Detalle — ${credito['folio']}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FormGrid(
                          children: [
                            _InfoCell(
                              label: 'Cliente',
                              value:
                                  credito['cliente_nombre'] as String? ?? '—',
                            ),
                            _InfoCell(
                              label: 'Código',
                              value:
                                  credito['cliente_codigo'] as String? ?? '—',
                            ),
                            _InfoCell(
                              label: 'Vendedor',
                              value:
                                  credito['vendedor_nombre'] as String? ?? '—',
                            ),
                            _InfoCell(
                              label: 'Promotor',
                              value:
                                  credito['promotor_nombre'] as String? ?? '—',
                            ),
                            _InfoCell(
                              label: 'Total / Saldo',
                              value:
                                  '${money(credito['monto_total'])} / ${money(credito['saldo'])}',
                            ),
                            if (((credito['abono'] as num?)?.toDouble() ?? 0) >
                                0)
                              _InfoCell(
                                label: 'Abono inicial',
                                value: money(credito['abono'] as num?),
                              ),
                            _InfoCell(
                              label: 'Comisión venta',
                              value: money(credito['comision_venta'] as num?),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _EstadoChip(estado: credito['estado'] as String?),
                        if ((credito['items'] as List?)?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Productos',
                            style: Theme.of(ctx).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          for (final i
                              in (credito['items'] as List)
                                  .cast<Map<String, dynamic>>())
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(i['descripcion'] as String? ?? '—'),
                              subtitle: Text(
                                [
                                  if ((i['detalle'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true)
                                    (i['detalle'] as String).trim(),
                                  '${qtyLabel(i['cantidad'] as num?)} x ${money(i['precio_unitario'] as num?)}',
                                ].join('\n'),
                              ),
                              trailing: Text(
                                money(
                                  ((i['cantidad'] as num?)?.toDouble() ?? 0) *
                                      ((i['precio_unitario'] as num?)
                                              ?.toDouble() ??
                                          0),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Cuotas',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        for (final c
                            in (credito['cuotas'] as List)
                                .cast<Map<String, dynamic>>())
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Cuota ${c['numero']} — ${money(c['monto'])}',
                            ),
                            subtitle: Text(
                              'Vence: ${fmtDate(c['fecha_vencimiento'] as String?)} · ${estadoLabel(c['estado'] as String?)} · Pagado: ${money(c['monto_pagado'])}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (credito['estado'] != 'pagado')
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPago(resumen);
                        },
                        child: const Text('Registrar pago'),
                      ),
                    if (credito['estado'] != 'pagado') const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => runPrintAction(
                        ctx,
                        () =>
                            printTicket(config: state.config, credito: credito),
                      ),
                      child: const Text('Ticket venta'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => runPrintAction(
                        ctx,
                        () => printOrdenDespacho(
                          config: state.config,
                          credito: credito,
                        ),
                      ),
                      child: const Text('Orden despacho'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditar(resumen);
                      },
                      child: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BearColors.danger,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _eliminarVenta(resumen);
                      },
                      child: const Text('Borrar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _recordarWhatsApp(Map<String, dynamic> credito) {
    final state = context.read<AppState>();
    final cliente = resolveClienteForWhatsApp(
      state,
      clienteId: credito['cliente_id'] as String?,
      clienteNombre: credito['cliente_nombre'] as String?,
      clienteCodigo: credito['cliente_codigo'] as String?,
      clienteTelefono: credito['cliente_telefono'] as String?,
    );
    if (cliente == null) return;
    final creditos = creditosPendientesCliente(
      state,
      clienteId: credito['cliente_id'] as String?,
      clienteNombre: credito['cliente_nombre'] as String?,
      extra: [credito],
    );
    showWhatsAppNotifyDialog(
      context: context,
      cliente: cliente,
      creditos: creditos,
    );
  }

  Future<void> _mostrarFacturasVencidas() async {
    try {
      final vencidas = await AppDatabase.instance.listCreditosVencidos();
      if (!mounted) return;
      if (vencidas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Excelente! No hay facturas vencidas registradas.'),
          ),
        );
        return;
      }
      final state = context.read<AppState>();
      final fechaHoy = DateTime.now().toIso8601String().split('T').first;

      runPrintAction(
        context,
        () => printReporteCobranza(
          reporte: {
            'periodo': 'Facturas Vencidas',
            'desde': fechaHoy,
            'hasta': fechaHoy,
            'vendedor': null,
            'promotor': null,
            'totales': {
              'ventas': vencidas.fold(
                0.0,
                (s, c) => s + ((c['monto_total'] as num?)?.toDouble() ?? 0),
              ),
              'cobrado': vencidas.fold(
                0.0,
                (s, c) => s + ((c['monto_pagado'] as num?)?.toDouble() ?? 0),
              ),
              'saldo': vencidas.fold(
                0.0,
                (s, c) => s + ((c['saldo'] as num?)?.toDouble() ?? 0),
              ),
              'comision_venta': 0.0,
              'comision_cobrada': 0.0,
              'comision_pendiente': 0.0,
            },
            'resumen': {
              'total_creditos': vencidas.length,
              'pagados': 0,
              'pendientes': vencidas.length,
            },
            'creditos': vencidas,
            'lista_pagados': [],
            'lista_pendientes': vencidas,
          },
          config: state.config,
          tab: 'pendientes',
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF de vencidas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final creditos = context.watch<AppState>().creditos;

    final filteredByEstado = _filtroEstado.isEmpty
        ? creditos
        : creditos.where((c) => c['estado'] == _filtroEstado).toList();

    final filtered = _searchQuery.isEmpty
        ? filteredByEstado
        : filteredByEstado.where((c) {
            final factura = '${c['numero_factura'] ?? c['folio'] ?? ''}'
                .toLowerCase();
            final cliente = '${c['cliente_nombre'] ?? ''}'.toLowerCase();
            final vendedor = '${c['vendedor_nombre'] ?? ''}'.toLowerCase();
            final q = _searchQuery.toLowerCase();
            return factura.contains(q) ||
                cliente.contains(q) ||
                vendedor.contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Ventas / Créditos',
            subtitle:
                'Registra ventas a crédito con cuotas de pago e impresión de ticket',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _mostrarFacturasVencidas,
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: const Text('Facturas Vencidas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                ToolbarNewButton(
                  label: 'Nueva venta',
                  onPressed: _showNuevaVenta,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _FilterTab(
                label: 'Todos',
                selected: _filtroEstado == '',
                onTap: () => setState(() => _filtroEstado = ''),
              ),
              _FilterTab(
                label: 'Pendientes',
                selected: _filtroEstado == 'pendiente',
                onTap: () => setState(() => _filtroEstado = 'pendiente'),
              ),
              _FilterTab(
                label: 'Parciales',
                selected: _filtroEstado == 'parcial',
                onTap: () => setState(() => _filtroEstado = 'parcial'),
              ),
              _FilterTab(
                label: 'Pagados',
                selected: _filtroEstado == 'pagado',
                onTap: () => setState(() => _filtroEstado = 'pagado'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: 'Buscar venta',
              hintText: 'Número de factura, cliente o vendedor...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin ventas registradas o sin coincidencias.',
                      ),
                    )
                  : ScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Factura')),
                        DataColumn(label: Text('Emisión')),
                        DataColumn(label: Text('Cliente')),
                        DataColumn(label: Text('Vendedor')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Saldo')),
                        DataColumn(label: Text('Cuotas')),
                        DataColumn(label: Text('Próx. vence')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: filtered.map((c) {
                        final estado = c['estado'] as String?;
                        final fechaEmision =
                            c['fecha_emision'] as String? ??
                            c['fecha_venta'] as String?;
                        return DataRow(
                          cells: [
                            DataCell(
                              Text('${c['numero_factura'] ?? c['folio']}'),
                            ),
                            DataCell(Text(fmtDate(fechaEmision))),
                            DataCell(
                              Text(c['cliente_nombre'] as String? ?? '—'),
                            ),
                            DataCell(
                              Text(c['vendedor_nombre'] as String? ?? '—'),
                            ),
                            DataCell(Text(money(c['monto_total'] as num?))),
                            DataCell(Text(money(c['saldo'] as num?))),
                            DataCell(Text('${c['num_cuotas'] ?? 1}')),
                            DataCell(
                              Text(fmtDate(c['fecha_vencimiento'] as String?)),
                            ),
                            DataCell(_EstadoChip(estado: estado)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RowActionButton(
                                    label: 'Ver',
                                    icon: Icons.visibility_rounded,
                                    color: BearColors.indigo,
                                    onPressed: () => _showDetalle(c),
                                  ),
                                  const SizedBox(width: 6),
                                  RowActionButton(
                                    label: 'Editar',
                                    icon: Icons.edit_rounded,
                                    color: BearColors.indigo,
                                    onPressed: () => _showEditar(c),
                                  ),
                                  const SizedBox(width: 6),
                                  RowActionButton(
                                    label: 'Borrar',
                                    icon: Icons.delete_outline_rounded,
                                    color: BearColors.danger,
                                    onPressed: () => _eliminarVenta(c),
                                  ),
                                  const SizedBox(width: 6),
                                  RowActionButton(
                                    label: 'Imprimir',
                                    icon: Icons.print_rounded,
                                    color: BearColors.indigo,
                                    onPressed: () async {
                                      final state = context.read<AppState>();
                                      final full = await state.getCreditoDetail(
                                        c['id'] as String,
                                      );
                                      if (full != null && context.mounted) {
                                        await runPrintAction(
                                          context,
                                          () => printTicket(
                                            config: state.config,
                                            credito: full,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (estado != 'pagado') ...[
                                    const SizedBox(width: 6),
                                    RowActionButton(
                                      label: 'Pago',
                                      icon: Icons.payments_rounded,
                                      color: BearColors.success,
                                      onPressed: () => _showPago(c),
                                    ),
                                    const SizedBox(width: 6),
                                    RecordarWhatsAppButton(
                                      onPressed: () => _recordarWhatsApp(c),
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

class _LineItemsEditor extends StatelessWidget {
  const _LineItemsEditor({
    required this.items,
    required this.onChanged,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback onChanged;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return ScrollableDataTable(
      columns: const [
        DataColumn(label: Text('Producto')),
        DataColumn(label: Text('Cant.')),
        DataColumn(label: Text('Precio')),
        DataColumn(label: Text('Subtotal')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (var i = 0; i < items.length; i++)
          DataRow(
            cells: [
              DataCell(
                items[i]['producto_id'] == null
                    ? SizedBox(
                        width: 160,
                        child: TextField(
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Descripción',
                          ),
                          controller: TextEditingController(
                            text: items[i]['descripcion'] as String? ?? '',
                          ),
                          onChanged: (v) {
                            items[i]['descripcion'] = v;
                            onChanged();
                          },
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            items[i]['descripcion'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if ((items[i]['detalle'] as String?)
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                            Text(
                              (items[i]['detalle'] as String).trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            'Stock: ${(items[i]['stock_disponible'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
              DataCell(
                QtyStepper(
                  value: ((items[i]['cantidad'] as num?)?.round() ?? 1).clamp(
                    1,
                    1 << 31,
                  ),
                  onChanged: (v) {
                    items[i]['cantidad'] = v;
                    onChanged();
                  },
                ),
              ),
              DataCell(
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(isDense: true),
                    controller: TextEditingController(
                      text: '${items[i]['precio_unitario']}',
                    ),
                    onChanged: (v) {
                      items[i]['precio_unitario'] = double.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ),
              DataCell(
                Text(
                  money(
                    ((items[i]['cantidad'] as num?)?.toDouble() ?? 0) *
                        ((items[i]['precio_unitario'] as num?)?.toDouble() ??
                            0),
                  ),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemove(i),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String? estado;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (estado) {
      case 'pagado':
        color = BearColors.success;
        break;
      case 'parcial':
        color = BearColors.warning;
        break;
      default:
        color = BearColors.danger;
    }
    return StatusPill(label: estadoLabel(estado), color: color);
  }
}
