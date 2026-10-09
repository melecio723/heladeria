import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/format.dart';
import '../utils/print_ticket.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

/// Pantalla de control de caja tipo punto de venta: apertura, resumen en vivo,
/// entradas/salidas de efectivo, cierre con arqueo e historial de sesiones.
class CajaScreen extends StatelessWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sesion = state.cajaSesionActual;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Caja',
            subtitle: state.modoCajaMultiple
                ? 'Control de caja multi-caja: apertura, movimientos y arqueo'
                : 'Control de caja: apertura, movimientos y arqueo de cierre',
            trailing: sesion == null
                ? ToolbarNewButton(
                    label: 'Abrir caja',
                    onPressed: () => abrirCajaDialog(context),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                if (sesion == null)
                  const _CajaCerradaCard()
                else
                  _CajaAbiertaCard(sesion: sesion, resumen: state.cajaResumen),
                const SizedBox(height: 20),
                const _HistorialSesiones(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CajaCerradaCard extends StatelessWidget {
  const _CajaCerradaCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.point_of_sale_rounded, size: 48, color: BearColors.grayLight),
          const SizedBox(height: 12),
          Text('No hay una caja abierta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Abre la caja con un fondo inicial para empezar a registrar ventas, '
            'abonos y movimientos de efectivo del turno.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BearColors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => abrirCajaDialog(context),
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Abrir caja'),
          ),
        ],
      ),
    );
  }
}

class _CajaAbiertaCard extends StatelessWidget {
  const _CajaAbiertaCard({required this.sesion, required this.resumen});

  final Map<String, dynamic> sesion;
  final Map<String, dynamic> resumen;

  @override
  Widget build(BuildContext context) {
    final apertura = (resumen['monto_apertura'] as num?)?.toDouble() ?? 0;
    final ventas = (resumen['ventas'] as num?)?.toDouble() ?? 0;
    final abonos = (resumen['abonos'] as num?)?.toDouble() ?? 0;
    final entradas = (resumen['entradas'] as num?)?.toDouble() ?? 0;
    final salidas = (resumen['salidas'] as num?)?.toDouble() ?? 0;
    final esperado = (resumen['esperado'] as num?)?.toDouble() ?? apertura;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BearColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_open_rounded, color: BearColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sesion['caja_nombre'] as String? ?? 'Caja',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 10),
                        const StatusPill(label: 'Abierta', color: BearColors.success),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Abrió ${sesion['usuario_nombre'] ?? '—'} · ${fmtDateTime(sesion['fecha_apertura'] as String?)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _StatBox(label: 'Fondo inicial', value: money(apertura), color: BearColors.indigo),
              _StatBox(label: 'Ventas efectivo', value: money(ventas), color: BearColors.success),
              _StatBox(label: 'Abonos efectivo', value: money(abonos), color: BearColors.blue),
              _StatBox(label: 'Entradas', value: money(entradas), color: BearColors.warning),
              _StatBox(label: 'Salidas', value: money(salidas), color: BearColors.danger),
              _StatBox(label: 'Total esperado', value: money(esperado), color: BearColors.indigoDeep, highlight: true),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => movimientoCajaDialog(context, entrada: true),
                style: FilledButton.styleFrom(backgroundColor: BearColors.success),
                icon: const Icon(Icons.south_west_rounded, size: 18),
                label: const Text('Entrada de efectivo'),
              ),
              FilledButton.icon(
                onPressed: () => movimientoCajaDialog(context, entrada: false),
                style: FilledButton.styleFrom(backgroundColor: BearColors.warning),
                icon: const Icon(Icons.north_east_rounded, size: 18),
                label: const Text('Salida de efectivo'),
              ),
              FilledButton.icon(
                onPressed: () => cerrarCajaDialog(context),
                style: FilledButton.styleFrom(backgroundColor: BearColors.danger),
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: const Text('Cerrar caja'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _mostrarMovimientos(context, sesion),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: Text('Ver movimientos (${resumen['num_movimientos'] ?? 0})'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _mostrarMovimientos(BuildContext context, Map<String, dynamic> sesion) async {
  final state = context.read<AppState>();
  final movs = await state.getMovimientosCaja(sesion['id'] as String);
  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: BearColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Movimientos — ${sesion['caja_nombre'] ?? 'Caja'}',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: movs.isEmpty
                    ? const Center(child: Text('Sin movimientos registrados.'))
                    : ScrollableDataTable(
                        columns: const [
                          DataColumn(label: Text('Fecha')),
                          DataColumn(label: Text('Tipo')),
                          DataColumn(label: Text('Descripción')),
                          DataColumn(label: Text('Monto')),
                        ],
                        rows: movs.map((m) {
                          final tipo = m['tipo'] as String? ?? '';
                          return DataRow(cells: [
                            DataCell(Text(fmtDateTime(m['fecha'] as String?))),
                            DataCell(_MovTipoChip(tipo: tipo)),
                            DataCell(Text((m['descripcion'] as String?) ?? '—')),
                            DataCell(Text(
                              '${tipo == 'salida' ? '-' : '+'}${money(m['monto'] as num?)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: tipo == 'salida' ? BearColors.danger : BearColors.success,
                              ),
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

class _HistorialSesiones extends StatelessWidget {
  const _HistorialSesiones();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 20, color: BearColors.textMuted),
              const SizedBox(width: 8),
              Text(
                state.isAdmin ? 'Historial de cierres' : 'Mis cierres de caja',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: state.getSesionesCerradas(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: BearColors.indigo)),
                );
              }
              final sesiones = snapshot.data!;
              if (sesiones.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Aún no hay cierres de caja registrados.')),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ScrollableDataTable(
                  columns: const [
                    DataColumn(label: Text('Caja')),
                    DataColumn(label: Text('Cierre')),
                    DataColumn(label: Text('Cajero')),
                    DataColumn(label: Text('Apertura')),
                    DataColumn(label: Text('Esperado')),
                    DataColumn(label: Text('Contado')),
                    DataColumn(label: Text('Diferencia')),
                    DataColumn(label: Text('')),
                  ],
                  rows: sesiones.map((s) {
                    final dif = (s['diferencia'] as num?)?.toDouble() ?? 0;
                    final difColor = dif.abs() < 0.01
                        ? BearColors.success
                        : (dif > 0 ? BearColors.blue : BearColors.danger);
                    return DataRow(cells: [
                      DataCell(Text(s['caja_nombre'] as String? ?? '—')),
                      DataCell(Text(fmtDateTime(s['fecha_cierre'] as String?))),
                      DataCell(Text(s['usuario_nombre'] as String? ?? '—')),
                      DataCell(Text(money(s['monto_apertura'] as num?))),
                      DataCell(Text(money(s['monto_esperado'] as num?))),
                      DataCell(Text(money(s['monto_cierre_contado'] as num?))),
                      DataCell(Text(
                        money(dif),
                        style: TextStyle(fontWeight: FontWeight.w600, color: difColor),
                      )),
                      DataCell(RowActionButton(
                        label: 'Corte',
                        icon: Icons.print_rounded,
                        onPressed: () async {
                          final resumen = await state.getResumenSesion(s['id'] as String);
                          if (!context.mounted) return;
                          await runPrintAction(
                            context,
                            () => printCorteCaja(config: state.config, sesion: s, resumen: resumen),
                          );
                        },
                      )),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlight ? color.withValues(alpha: 0.10) : BearColors.bgAlt,
        borderRadius: BorderRadius.circular(BearTheme.radiusSm),
        border: Border.all(color: highlight ? color.withValues(alpha: 0.4) : BearColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BearColors.textMuted, letterSpacing: 0.3),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _MovTipoChip extends StatelessWidget {
  const _MovTipoChip({required this.tipo});

  final String tipo;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (tipo) {
      case 'venta':
        color = BearColors.success;
        label = 'Venta';
        break;
      case 'abono':
        color = BearColors.blue;
        label = 'Abono';
        break;
      case 'entrada':
        color = BearColors.warning;
        label = 'Entrada';
        break;
      case 'salida':
        color = BearColors.danger;
        label = 'Salida';
        break;
      default:
        color = BearColors.textMuted;
        label = tipo;
    }
    return StatusPill(label: label, color: color);
  }
}

// ---------------------------------------------------------------------------
// Diálogos públicos (reutilizados por la pantalla y el arnés de capturas)
// ---------------------------------------------------------------------------

/// Diálogo de apertura de caja: fondo inicial y, en modo múltiple, la caja.
Future<void> abrirCajaDialog(BuildContext context) async {
  final state = context.read<AppState>();
  final montoCtrl = TextEditingController(text: '0');
  final notasCtrl = TextEditingController();
  final cajasDisponibles = state.cajas.where((c) => (c['activa'] as int? ?? 1) == 1).toList();
  String? cajaId = cajasDisponibles.isNotEmpty ? cajasDisponibles.first['id'] as String : null;

  await showBearFormDialog(
    context: context,
    title: 'Abrir caja',
    primaryLabel: 'Abrir caja',
    onPrimary: () async {
      final monto = double.tryParse(montoCtrl.text.trim()) ?? 0;
      if (monto < 0) return;
      try {
        await state.abrirCaja(
          cajaId: state.modoCajaMultiple ? cajaId : null,
          montoApertura: monto,
          notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
        );
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
          if (state.modoCajaMultiple) ...[
            DropdownButtonFormField<String>(
              value: cajaId,
              decoration: const InputDecoration(labelText: 'Caja *'),
              items: [
                for (final c in cajasDisponibles)
                  DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre'] as String)),
              ],
              onChanged: (v) => setLocal(() => cajaId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fondo inicial (monto de apertura) *',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 6),
          const FormFieldHint('Efectivo con el que inicia el turno en la caja.'),
          const SizedBox(height: 12),
          TextField(
            controller: notasCtrl,
            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
          ),
        ],
      ),
    ),
  );
}

/// Diálogo de entrada/salida manual de efectivo.
Future<void> movimientoCajaDialog(BuildContext context, {required bool entrada}) async {
  final state = context.read<AppState>();
  final montoCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  await showBearFormDialog(
    context: context,
    title: entrada ? 'Entrada de efectivo' : 'Salida de efectivo',
    primaryLabel: 'Registrar',
    onPrimary: () async {
      final monto = double.tryParse(montoCtrl.text.trim());
      if (monto == null || monto <= 0) return;
      try {
        await state.addMovimientoCaja(
          tipo: entrada ? 'entrada' : 'salida',
          monto: monto,
          descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        );
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entrada
              ? 'Registra dinero que ingresa a la caja (fondo extra, préstamo, etc.).'
              : 'Registra dinero que sale de la caja (retiro, gasto, compra de insumos).',
          style: const TextStyle(color: BearColors.textMuted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: montoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto *', prefixText: '\$ '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descCtrl,
          decoration: InputDecoration(
            labelText: 'Concepto',
            hintText: entrada ? 'Ej. Fondo adicional' : 'Ej. Retiro / gasto',
          ),
        ),
      ],
    ),
  );
}

/// Diálogo de cierre de caja: muestra el esperado calculado y la diferencia
/// según el efectivo contado. Al confirmar, guarda el arqueo y ofrece imprimir.
Future<void> cerrarCajaDialog(BuildContext context, {double? prefillContado}) async {
  final state = context.read<AppState>();
  final sesion = state.cajaSesionActual;
  if (sesion == null) return;
  final resumen = state.cajaResumen;
  final esperado = (resumen['esperado'] as num?)?.toDouble() ?? 0;
  final contadoCtrl = TextEditingController(
    text: prefillContado != null ? prefillContado.toStringAsFixed(2) : '',
  );
  final notasCtrl = TextEditingController();

  await showBearFormDialog(
    context: context,
    title: 'Cerrar caja — arqueo',
    primaryLabel: 'Cerrar caja',
    onPrimary: () async {
      final contado = double.tryParse(contadoCtrl.text.trim());
      if (contado == null || contado < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa el efectivo contado')),
        );
        return;
      }
      try {
        final arqueo = await state.cerrarCaja(
          montoContado: contado,
          notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
        );
        if (context.mounted) {
          Navigator.pop(context);
          await mostrarArqueoDialog(context, arqueo);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    },
    child: StatefulBuilder(
      builder: (ctx, setLocal) {
        final contado = double.tryParse(contadoCtrl.text.trim());
        final diferencia = contado != null ? contado - esperado : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ArqueoRow(label: 'Fondo inicial', value: money(resumen['monto_apertura'] as num?)),
            _ArqueoRow(label: 'Ventas efectivo', value: money(resumen['ventas'] as num?)),
            _ArqueoRow(label: 'Abonos efectivo', value: money(resumen['abonos'] as num?)),
            _ArqueoRow(label: 'Entradas', value: money(resumen['entradas'] as num?)),
            _ArqueoRow(label: 'Salidas', value: '-${money(resumen['salidas'] as num?)}'),
            const Divider(height: 24),
            _ArqueoRow(label: 'Total esperado en caja', value: money(esperado), bold: true),
            const SizedBox(height: 16),
            TextField(
              controller: contadoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado *',
                prefixText: '\$ ',
              ),
              onChanged: (_) => setLocal(() {}),
            ),
            const SizedBox(height: 12),
            if (diferencia != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: (diferencia.abs() < 0.01
                          ? BearColors.success
                          : (diferencia > 0 ? BearColors.blue : BearColors.danger))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BearTheme.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      diferencia.abs() < 0.01
                          ? 'Caja cuadrada'
                          : (diferencia > 0 ? 'Sobrante' : 'Faltante'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      money(diferencia),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: diferencia.abs() < 0.01
                            ? BearColors.success
                            : (diferencia > 0 ? BearColors.blue : BearColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: notasCtrl,
              decoration: const InputDecoration(labelText: 'Notas del cierre (opcional)'),
            ),
          ],
        );
      },
    ),
  );
}

/// Muestra el resultado del arqueo (corte de caja) con opción de impresión.
Future<void> mostrarArqueoDialog(BuildContext context, Map<String, dynamic> arqueo) async {
  final state = context.read<AppState>();
  final resumen = (arqueo['resumen'] as Map?)?.cast<String, dynamic>() ?? {};
  final dif = (arqueo['diferencia'] as num?)?.toDouble() ?? 0;
  final difColor = dif.abs() < 0.01
      ? BearColors.success
      : (dif > 0 ? BearColors.blue : BearColors.danger);

  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: BearColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Corte de caja', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${arqueo['caja_nombre'] ?? 'Caja'} · ${fmtDateTime(arqueo['fecha_cierre'] as String?)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ArqueoRow(label: 'Fondo inicial', value: money(resumen['monto_apertura'] as num?)),
              _ArqueoRow(label: 'Ventas efectivo', value: money(resumen['ventas'] as num?)),
              _ArqueoRow(label: 'Abonos efectivo', value: money(resumen['abonos'] as num?)),
              _ArqueoRow(label: 'Entradas', value: money(resumen['entradas'] as num?)),
              _ArqueoRow(label: 'Salidas', value: '-${money(resumen['salidas'] as num?)}'),
              const Divider(height: 24),
              _ArqueoRow(label: 'Total esperado', value: money(arqueo['monto_esperado'] as num?), bold: true),
              _ArqueoRow(label: 'Total contado', value: money(arqueo['monto_cierre_contado'] as num?), bold: true),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: difColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BearTheme.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dif.abs() < 0.01 ? 'Caja cuadrada' : (dif > 0 ? 'Sobrante' : 'Faltante'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      money(dif),
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: difColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => runPrintAction(
                      ctx,
                      () => printCorteCaja(config: state.config, sesion: arqueo, resumen: resumen),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Imprimir corte'),
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

class _ArqueoRow extends StatelessWidget {
  const _ArqueoRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? BearColors.textPrimary : BearColors.textMuted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
