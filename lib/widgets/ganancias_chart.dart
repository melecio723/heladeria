import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/bear_theme.dart';
import '../utils/format.dart';
import 'form_dialog.dart';
import 'scrollable_table.dart';
import 'ui_kit.dart';

const _costoColor = BearColors.danger;
const _comisionColor = BearColors.gold;
const _gananciaColor = BearColors.success;

/// Dona (donut) con la descomposición de la venta: Costo / Comisión / Ganancia.
class GananciasChart extends StatelessWidget {
  const GananciasChart({
    super.key,
    required this.costo,
    required this.comision,
    required this.ganancia,
  });

  final double costo;
  final double comision;
  final double ganancia;

  @override
  Widget build(BuildContext context) {
    final gananciaPos = ganancia < 0 ? 0.0 : ganancia;
    final total = costo + comision + gananciaPos;

    final sections = <PieChartSectionData>[];
    if (total <= 0) {
      sections.add(PieChartSectionData(
        value: 1,
        color: BearColors.border,
        title: '',
        radius: 40,
      ));
    } else {
      void add(double v, Color c) {
        if (v <= 0) return;
        final pct = v / total * 100;
        sections.add(PieChartSectionData(
          value: v,
          color: c,
          radius: 42,
          title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ));
      }

      add(costo, _costoColor);
      add(comision, _comisionColor);
      add(gananciaPos, _gananciaColor);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 170,
          height: 170,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 42,
              sectionsSpace: 2,
              startDegreeOffset: -90,
            ),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Legend(color: _costoColor, label: 'Costo de fabricación', value: costo),
              const SizedBox(height: 10),
              _Legend(color: _comisionColor, label: 'Comisión del vendedor', value: comision),
              const SizedBox(height: 10),
              _Legend(color: _gananciaColor, label: 'Ganancia neta (dueño)', value: ganancia),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          money(value),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Vista completa del reporte de ganancias: tarjetas de resumen, gráfico de
/// descomposición y detalle por producto. Reutilizable en pantalla y capturas.
class GananciasView extends StatelessWidget {
  const GananciasView({super.key, required this.data});

  final Map<String, dynamic> data;

  double _d(String k) => (data[k] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final ingresos = _d('ingresos');
    final costo = _d('costo');
    final comision = _d('comision');
    final ganancia = _d('ganancia');
    final numVentas = (data['num_ventas'] as num?)?.toInt() ?? 0;
    final itemsSinCosto = (data['items_sin_costo'] as num?)?.toInt() ?? 0;
    final margen = ingresos > 0 ? ganancia / ingresos * 100 : 0.0;
    final porProducto = (data['por_producto'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(label: 'Ingresos (ventas)', value: money(ingresos), color: BearColors.indigo),
            _StatCard(label: 'Costo fabricación', value: money(costo), color: BearColors.danger),
            _StatCard(label: 'Comisiones', value: money(comision), color: BearColors.gold),
            _StatCard(label: 'Ganancia neta', value: money(ganancia), color: BearColors.success),
            _StatCard(label: 'Margen', value: '${margen.toStringAsFixed(1)}%', color: BearColors.blue),
            _StatCard(label: 'Ventas', value: '$numVentas', color: BearColors.textMuted),
          ],
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Descomposición de la venta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Ingresos − Costo − Comisión = Ganancia del dueño',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              GananciasChart(costo: costo, comision: comision, ganancia: ganancia),
            ],
          ),
        ),
        if (itemsSinCosto > 0) ...[
          const SizedBox(height: 8),
          FormFieldHint(
            'Aviso: $itemsSinCosto línea(s) sin costo registrado (venta manual o producto sin precio de costo). '
            'Su costo se toma como \$0, por lo que la ganancia puede estar sobreestimada.',
          ),
        ],
        if (porProducto.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Detalle por producto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: ScrollableDataTable(
              columns: const [
                DataColumn(label: Text('Producto')),
                DataColumn(label: Text('Cant.')),
                DataColumn(label: Text('Ingresos')),
                DataColumn(label: Text('Costo')),
                DataColumn(label: Text('Utilidad bruta')),
              ],
              rows: porProducto.map((p) {
                final ing = (p['ingresos'] as num?)?.toDouble() ?? 0;
                final cos = (p['costo'] as num?)?.toDouble() ?? 0;
                return DataRow(cells: [
                  DataCell(Text(p['descripcion'] as String? ?? '—')),
                  DataCell(Text(qtyLabel(p['cantidad'] as num?))),
                  DataCell(Text(money(ing))),
                  DataCell(Text(money(cos))),
                  DataCell(Text(money(ing - cos))),
                ]);
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color ?? BearColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
