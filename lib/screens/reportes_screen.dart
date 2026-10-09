import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/format.dart';
import '../utils/print_ticket.dart';
import '../widgets/ganancias_chart.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';
import '../widgets/whatsapp_notify_dialog.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with TickerProviderStateMixin {
  late final TabController _vistaTabs;
  late final TabController _periodoTabs;
  late final TabController _listaTabs;
  late final TabController _periodoClienteTabs;
  late final TabController _periodoComisionTabs;

  String _periodo = 'hoy';
  String? _vendedorId;
  String? _promotorId;
  String _desde = '';
  String _hasta = '';
  String _listaTab = 'todos';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _reporte;
  Map<String, dynamic>? _reportePromotor;

  // Por cliente
  String _periodoCliente = '';
  String _desdeCliente = '';
  String _hastaCliente = '';
  String? _vendedorClienteId;
  String _filtroCliente = 'todos';
  String _searchCliente = '';
  bool _loadingClientes = false;
  String? _errorClientes;
  Map<String, dynamic>? _reporteClientes;

  // Vencidas Tab State
  String? _vendedorVencidasId;
  String _searchVencidas = '';
  List<Map<String, dynamic>> _vencidasList = [];
  bool _loadingVencidas = false;

  // Comisiones a pagar
  String _periodoComision = 'semanal';
  String _desdeComision = '';
  String _hastaComision = '';
  String? _vendedorComisionId;
  bool _loadingComisiones = false;
  String? _errorComisiones;
  Map<String, dynamic>? _reporteComisiones;

  // Ganancias
  String _periodoGan = 'semanal';
  String? _vendedorGanId;
  String _desdeGan = '';
  String _hastaGan = '';
  bool _loadingGan = false;
  String? _errorGan;
  Map<String, dynamic>? _reporteGanancias;

  // Auditoría Tab State
  List<Map<String, dynamic>> _auditoriaList = [];
  bool _loadingAuditoria = false;
  String _desdeAuditoria = '';
  String _hastaAuditoria = '';
  String _searchAuditoria = '';

  @override
  void initState() {
    super.initState();
    _vistaTabs = TabController(length: 7, vsync: this);
    _periodoTabs = TabController(length: 4, vsync: this);
    _listaTabs = TabController(length: 4, vsync: this);
    _periodoClienteTabs = TabController(length: 4, vsync: this);
    _periodoComisionTabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: 2,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generarCobranza();
      _generarGanancias();
      _generarClientes();
      _generarComisiones();
      _cargarVencidas();
      _cargarAuditoria();
    });
  }

  @override
  void dispose() {
    _vistaTabs.dispose();
    _periodoTabs.dispose();
    _listaTabs.dispose();
    _periodoClienteTabs.dispose();
    _periodoComisionTabs.dispose();
    super.dispose();
  }

  Future<void> _generarCobranza() async {
    setState(() {
      _loading = true;
      _error = null;
      _reportePromotor = null;
    });
    try {
      final state = context.read<AppState>();
      final data = _periodo == 'personalizado'
          ? await state.generateReporte(
              desde: _desde,
              hasta: _hasta,
              vendedorId: _vendedorId,
              promotorId: _promotorId,
            )
          : await state.generateReporte(
              periodo: _periodo,
              vendedorId: _vendedorId,
              promotorId: _promotorId,
            );
      if (mounted) {
        setState(() {
          _reporte = data;
          _listaTab = 'todos';
          _listaTabs.index = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarVencidas() async {
    setState(() {
      _loadingVencidas = true;
    });
    try {
      final data = await AppDatabase.instance.listCreditosVencidos();
      if (mounted) {
        setState(() {
          _vencidasList = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingVencidas = false);
    }
  }

  Future<void> _cargarAuditoria() async {
    setState(() {
      _loadingAuditoria = true;
    });
    try {
      final data = await AppDatabase.instance.listAuditoria(
        desde: _desdeAuditoria.isEmpty ? null : _desdeAuditoria,
        hasta: _hastaAuditoria.isEmpty ? null : _hastaAuditoria,
      );
      if (mounted) {
        setState(() {
          _auditoriaList = data;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _loadingAuditoria = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _auditoriaFiltrada() {
    var lista = _auditoriaList;
    final q = _searchAuditoria.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((a) {
        final usuario = '${a['usuario_nombre'] ?? ''}'.toLowerCase();
        final accion = '${a['accion'] ?? ''}'.toLowerCase();
        final detalles = '${a['detalles'] ?? ''}'.toLowerCase();
        return usuario.contains(q) ||
            accion.contains(q) ||
            detalles.contains(q);
      }).toList();
    }
    return lista;
  }

  List<Map<String, dynamic>> _vencidasFiltradas() {
    var lista = _vencidasList;
    if (_vendedorVencidasId != null) {
      lista = lista
          .where((c) => c['vendedor_id'] == _vendedorVencidasId)
          .toList();
    }
    final q = _searchVencidas.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((c) {
        final factura = '${c['numero_factura'] ?? c['folio'] ?? ''}'
            .toLowerCase();
        final cliente = '${c['cliente_nombre'] ?? ''}'.toLowerCase();
        final vendedor = '${c['vendedor_nombre'] ?? ''}'.toLowerCase();
        return factura.contains(q) ||
            cliente.contains(q) ||
            vendedor.contains(q);
      }).toList();
    }
    return lista;
  }

  int _calcularDiasAtraso(String? fechaVencimiento) {
    if (fechaVencimiento == null || fechaVencimiento.isEmpty) return 0;
    final v = DateTime.tryParse(fechaVencimiento);
    if (v == null) return 0;
    final diff = DateTime.now().difference(v).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _generarPromotor() async {
    if (_promotorId == null || _promotorId!.isEmpty) {
      setState(() => _error = 'Selecciona un promotor');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _reporte = null;
    });
    try {
      final data = await context.read<AppState>().generateReportePromotor(
        _promotorId!,
        desde: _desde.isEmpty ? null : _desde,
        hasta: _hasta.isEmpty ? null : _hasta,
      );
      if (mounted) setState(() => _reportePromotor = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generarGanancias() async {
    setState(() {
      _loadingGan = true;
      _errorGan = null;
    });
    try {
      final state = context.read<AppState>();
      final data = _periodoGan == 'personalizado'
          ? await state.generateReporteGanancias(
              desde: _desdeGan,
              hasta: _hastaGan,
              vendedorId: _vendedorGanId,
            )
          : await state.generateReporteGanancias(
              periodo: _periodoGan,
              vendedorId: _vendedorGanId,
            );
      if (mounted) setState(() => _reporteGanancias = data);
    } catch (e) {
      if (mounted) setState(() => _errorGan = e.toString());
    } finally {
      if (mounted) setState(() => _loadingGan = false);
    }
  }

  Future<void> _generarClientes() async {
    setState(() {
      _loadingClientes = true;
      _errorClientes = null;
    });
    try {
      final state = context.read<AppState>();
      final Map<String, dynamic> data;
      if (_periodoCliente == 'personalizado') {
        data = await state.generateReporteClientes(
          desde: _desdeCliente,
          hasta: _hastaCliente,
          vendedorId: _vendedorClienteId,
          filtro: _filtroCliente,
        );
      } else if (_periodoCliente.isNotEmpty) {
        data = await state.generateReporteClientes(
          periodo: _periodoCliente,
          vendedorId: _vendedorClienteId,
          filtro: _filtroCliente,
        );
      } else {
        data = await state.generateReporteClientes(
          vendedorId: _vendedorClienteId,
          filtro: _filtroCliente,
        );
      }
      if (mounted) setState(() => _reporteClientes = data);
    } catch (e) {
      if (mounted) setState(() => _errorClientes = e.toString());
    } finally {
      if (mounted) setState(() => _loadingClientes = false);
    }
  }

  Future<void> _generarComisiones() async {
    setState(() {
      _loadingComisiones = true;
      _errorComisiones = null;
    });
    try {
      final state = context.read<AppState>();
      final Map<String, dynamic> data;
      if (_periodoComision == 'personalizado') {
        data = await state.generateReporteComisiones(
          desde: _desdeComision,
          hasta: _hastaComision,
          vendedorId: _vendedorComisionId,
        );
      } else if (_periodoComision.isEmpty) {
        data = await state.generateReporteComisiones(
          vendedorId: _vendedorComisionId,
        );
      } else {
        data = await state.generateReporteComisiones(
          periodo: _periodoComision,
          vendedorId: _vendedorComisionId,
        );
      }
      if (mounted) setState(() => _reporteComisiones = data);
    } catch (e) {
      if (mounted) setState(() => _errorComisiones = e.toString());
    } finally {
      if (mounted) setState(() => _loadingComisiones = false);
    }
  }

  Future<void> _imprimirReporteVencidas() async {
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
              'comision_venta': vencidas.fold(
                0.0,
                (s, c) => s + ((c['comision_venta'] as num?)?.toDouble() ?? 0),
              ),
              'comision_cobrada': 0.0,
              'comision_pendiente': vencidas.fold(
                0.0,
                (s, c) =>
                    s + ((c['comision_pendiente'] as num?)?.toDouble() ?? 0),
              ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
    }
  }

  List<Map<String, dynamic>> _clientesFiltrados() {
    if (_reporteClientes == null) return [];
    final lista = (_reporteClientes!['clientes'] as List)
        .cast<Map<String, dynamic>>();
    final q = _searchCliente.trim().toLowerCase();
    if (q.isEmpty) return lista;
    return lista.where((c) {
      final nombre = (c['nombre'] as String? ?? '').toLowerCase();
      final codigo = (c['codigo'] as String? ?? '').toLowerCase();
      final telefono = (c['telefono'] as String? ?? '').toLowerCase();
      final vend = (c['vendedor_nombre'] as String? ?? '').toLowerCase();
      return nombre.contains(q) ||
          codigo.contains(q) ||
          telefono.contains(q) ||
          vend.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _listaActual() {
    if (_reporte == null) return [];
    final hoy = DateTime.now().toIso8601String().split('T').first;
    switch (_listaTab) {
      case 'pagados':
        return (_reporte!['lista_pagados'] as List)
            .cast<Map<String, dynamic>>();
      case 'pendientes':
        return (_reporte!['lista_pendientes'] as List)
            .cast<Map<String, dynamic>>();
      case 'vencidas':
        final creditos =
            (_reporte!['creditos'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        return creditos.where((c) {
          final estado = c['estado'] as String?;
          final vencimiento = c['fecha_vencimiento'] as String? ?? '';
          return estado != 'pagado' && vencimiento.compareTo(hoy) < 0;
        }).toList();
      default:
        return (_reporte!['creditos'] as List).cast<Map<String, dynamic>>();
    }
  }

  void _mostrarDetalleStat(String titulo, List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalle: $titulo (${items.length})'),
        content: SizedBox(
          width: 700,
          height: 400,
          child: items.isEmpty
              ? const Center(
                  child: Text('No hay registros para este concepto.'),
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final c = items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          'Folio: ${c['folio'] ?? c['numero_factura'] ?? '-'} - Cliente: ${c['cliente_nombre'] ?? '-'}',
                        ),
                        subtitle: Text(
                          'Vendedor: ${c['vendedor_nombre'] ?? '-'} | Vence: ${fmtDate(c['fecha_vencimiento'])}',
                        ),
                        trailing: Text(
                          money((c['saldo'] ?? c['monto_total']) as num?),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value, {
    Color? color,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: BearColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color ?? BearColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _creditoTable(List<Map<String, dynamic>> items, String emptyMsg) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(emptyMsg)),
      );
    }
    final state = context.read<AppState>();
    final showRecordar = _listaTab != 'pagados';

    return ScrollableDataTable(
      columns: [
        const DataColumn(label: Text('Folio')),
        const DataColumn(label: Text('Emisión')),
        const DataColumn(label: Text('Cliente')),
        const DataColumn(label: Text('Vendedor')),
        const DataColumn(label: Text('Total')),
        const DataColumn(label: Text('Pagado')),
        const DataColumn(label: Text('Saldo')),
        const DataColumn(label: Text('Comisión')),
        const DataColumn(label: Text('Vence')),
        const DataColumn(label: Text('Estado')),
        if (showRecordar) const DataColumn(label: Text('Acciones')),
      ],
      rows: items.map((c) {
        final estado = c['estado'] as String?;
        final emision =
            c['fecha_emision'] as String? ?? c['fecha_venta'] as String?;
        final puedeRecordar = showRecordar && estado != 'pagado';
        return DataRow(
          cells: [
            DataCell(Text(c['folio'] as String? ?? '-')),
            DataCell(Text(fmtDate(emision ?? ''))),
            DataCell(Text(c['cliente_nombre'] as String? ?? '-')),
            DataCell(Text(c['vendedor_nombre'] as String? ?? '-')),
            DataCell(Text(money(c['monto_total'] as num?))),
            DataCell(Text(money(c['monto_pagado'] as num?))),
            DataCell(Text(money(c['saldo'] as num?))),
            DataCell(Text(money(c['comision_venta'] as num?))),
            DataCell(Text(fmtDate(c['fecha_vencimiento'] as String?))),
            DataCell(_estadoBadge(estado)),
            if (showRecordar)
              DataCell(
                puedeRecordar
                    ? RecordarWhatsAppButton(
                        onPressed: () {
                          final cliente = resolveClienteForWhatsApp(
                            state,
                            clienteId: c['cliente_id'] as String?,
                            clienteNombre: c['cliente_nombre'] as String?,
                            clienteCodigo: c['cliente_codigo'] as String?,
                            clienteTelefono: c['cliente_telefono'] as String?,
                          );
                          if (cliente == null) return;
                          final creditos = creditosPendientesCliente(
                            state,
                            clienteId: c['cliente_id'] as String?,
                            clienteNombre: c['cliente_nombre'] as String?,
                            extra: [c],
                          );
                          showWhatsAppNotifyDialog(
                            context: context,
                            cliente: cliente,
                            creditos: creditos,
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _estadoBadge(String? estado) {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totales = _reporte?['totales'] as Map<String, dynamic>?;
    final resumen = _reporte?['resumen'] as Map<String, dynamic>?;
    final creditosAll =
        (_reporte?['creditos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final listaPagados =
        (_reporte?['lista_pagados'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final listaPendientes =
        (_reporte?['lista_pendientes'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Reportes',
            subtitle:
                'Cobranza, comisiones a pagar, clientes, promotores, ganancias y auditoría',
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _vistaTabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Cobranza'),
              Tab(text: 'Vencidas'),
              Tab(text: 'Comisiones'),
              Tab(text: 'Por cliente'),
              Tab(text: 'Por promotor'),
              Tab(text: 'Ganancias'),
              Tab(text: 'Auditoría'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _vistaTabs,
              children: [
                _buildCobranza(
                  state,
                  totales,
                  resumen,
                  creditosAll,
                  listaPagados,
                  listaPendientes,
                ),
                _buildVencidas(state),
                _buildComisiones(state),
                _buildClientes(state),
                _buildPromotor(state),
                _buildGanancias(state),
                _buildAuditoria(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditoria() {
    final auditoriaFiltrada = _auditoriaFiltrada();
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: _DateField(
                      label: 'Desde',
                      value: _desdeAuditoria,
                      onChanged: (v) => setState(() => _desdeAuditoria = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: _DateField(
                      label: 'Hasta',
                      value: _hastaAuditoria,
                      onChanged: (v) => setState(() => _hastaAuditoria = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar usuario o acción...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchAuditoria = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loadingAuditoria ? null : _cargarAuditoria,
                    icon: _loadingAuditoria
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _loadingAuditoria ? 'Filtrando...' : 'Filtrar registros',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          children: [
            _statCard(
              'Total eventos',
              '${auditoriaFiltrada.length}',
              color: BearColors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: auditoriaFiltrada.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No hay registros de auditoría en este periodo',
                    ),
                  ),
                )
              : ScrollableDataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha y Hora')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Acción')),
                    DataColumn(label: Text('Detalles')),
                  ],
                  rows: auditoriaFiltrada.map((a) {
                    return DataRow(
                      cells: [
                        DataCell(Text(fmtDateTime(a['fecha_hora'] as String?))),
                        DataCell(
                          Text(
                            a['usuario_nombre'] as String? ?? 'Sistema',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataCell(
                          StatusPill(
                            label: a['accion'] as String? ?? 'Acción',
                            color: BearColors.indigo,
                          ),
                        ),
                        DataCell(Text(a['detalles'] as String? ?? '-')),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildCobranza(
    AppState state,
    Map<String, dynamic>? totales,
    Map<String, dynamic>? resumen,
    List<Map<String, dynamic>> creditosAll,
    List<Map<String, dynamic>> listaPagados,
    List<Map<String, dynamic>> listaPendientes,
  ) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _periodoTabs,
                  isScrollable: true,
                  onTap: (i) {
                    const periodos = [
                      'hoy',
                      'manana',
                      'semanal',
                      'personalizado',
                    ];
                    setState(() => _periodo = periodos[i]);
                  },
                  tabs: const [
                    Tab(text: 'Hoy'),
                    Tab(text: 'Mañana'),
                    Tab(text: 'Semanal'),
                    Tab(text: 'Personalizado'),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_periodo == 'personalizado') ...[
                        SizedBox(
                          width: 140,
                          child: _DateField(
                            label: 'Desde',
                            value: _desde,
                            onChanged: (v) => setState(() => _desde = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: _DateField(
                            label: 'Hasta',
                            value: _hasta,
                            onChanged: (v) => setState(() => _hasta = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: _vendedorId,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por vendedor',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Todos los vendedores',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            for (final v in state.vendedores)
                              DropdownMenuItem<String?>(
                                value: v['id'] as String,
                                child: Text(
                                  '${v['nombre']} (${v['tipo']})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _vendedorId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _loading ? null : _generarCobranza,
                        child: Text(
                          _loading ? 'Generando...' : 'Generar reporte',
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _imprimirReporteVencidas,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                        ),
                        label: const Text('PDF Vencidas'),
                        style: FilledButton.styleFrom(
                          backgroundColor: BearColors.danger,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: BearColors.red)),
                ],
              ],
            ),
          ),
        ),
        if (_reporte != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                '${_reporte!['periodo']}: ${fmtDate(_reporte!['desde'] as String?)}'
                '${_reporte!['desde'] != _reporte!['hasta'] ? ' a ${fmtDate(_reporte!['hasta'] as String?)}' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                onPressed: () => runPrintAction(
                  context,
                  () => printReporteCobranza(
                    reporte: _reporte!,
                    config: state.config,
                    tab: _listaTab,
                  ),
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir / PDF'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _statCard(
                'Ventas',
                money(totales?['ventas'] as num?),
                color: BearColors.indigo,
                onTap: () => _mostrarDetalleStat('Ventas Totales', creditosAll),
              ),
              _statCard(
                'Cobrado',
                money(totales?['cobrado'] as num?),
                color: BearColors.success,
                onTap: () => _mostrarDetalleStat(
                  'Créditos con Pagos',
                  creditosAll
                      .where((c) => ((c['monto_pagado'] as num?) ?? 0) > 0)
                      .toList(),
                ),
              ),
              _statCard(
                'Saldo pendiente',
                money(totales?['saldo'] as num?),
                color: BearColors.gold,
                onTap: () =>
                    _mostrarDetalleStat('Saldos Pendientes', listaPendientes),
              ),
              _statCard(
                'A pagar vendedor',
                money(totales?['comision_venta'] as num?),
                color: BearColors.indigo,
                onTap: () =>
                    _mostrarDetalleStat('Comisiones por Venta', creditosAll),
              ),
              _statCard(
                'Comisión s/ cobrado',
                money(totales?['comision_cobrada'] as num?),
                color: BearColors.success,
                onTap: () =>
                    _mostrarDetalleStat('Comisión sobre Cobrado', listaPagados),
              ),
              _statCard(
                'Comisión s/ saldo',
                money(totales?['comision_pendiente'] as num?),
                color: BearColors.gold,
                onTap: () => _mostrarDetalleStat(
                  'Comisión sobre Saldo',
                  listaPendientes,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '“A pagar vendedor” = % × total de la venta. Se liquida aunque el cliente aún no haya pagado. '
            'Ver pestaña Comisiones para el detalle por persona. (Haz clic en cualquier tarjeta para ver detalles).',
            style: TextStyle(color: BearColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _statCard(
                'Total créditos',
                '${(resumen?['total_creditos'] as num?)?.toInt() ?? 0}',
                onTap: () => _mostrarDetalleStat('Total Créditos', creditosAll),
              ),
              _statCard(
                'Pagados',
                '${(resumen?['pagados'] as num?)?.toInt() ?? 0}',
                color: BearColors.success,
                onTap: () =>
                    _mostrarDetalleStat('Créditos Pagados', listaPagados),
              ),
              _statCard(
                'Pendientes',
                '${(resumen?['pendientes'] as num?)?.toInt() ?? 0}',
                color: BearColors.red,
                onTap: () =>
                    _mostrarDetalleStat('Créditos Pendientes', listaPendientes),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _listaTabs,
            onTap: (i) {
              const tabs = ['todos', 'pagados', 'pendientes', 'vencidas'];
              setState(() => _listaTab = tabs[i]);
            },
            tabs: [
              Tab(text: 'Todos (${creditosAll.length})'),
              Tab(text: 'Pagados (${listaPagados.length})'),
              Tab(text: 'Pendientes (${listaPendientes.length})'),
              const Tab(text: 'Vencidas'),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: _creditoTable(
              _listaActual(),
              _listaTab == 'pagados'
                  ? 'Sin créditos pagados'
                  : _listaTab == 'pendientes'
                  ? 'Sin créditos pendientes'
                  : _listaTab == 'vencidas'
                  ? '¡Excelente! No hay facturas vencidas'
                  : 'Sin créditos en este periodo',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVencidas(AppState state) {
    final vencidasFiltradas = _vencidasFiltradas();
    final totalMontoVencido = vencidasFiltradas.fold<double>(
      0.0,
      (s, c) => s + ((c['saldo'] as num?)?.toDouble() ?? 0),
    );
    final totalVentasVencidas = vencidasFiltradas.fold<double>(
      0.0,
      (s, c) => s + ((c['monto_total'] as num?)?.toDouble() ?? 0),
    );
    final clientesUnicos = vencidasFiltradas
        .map((c) => c['cliente_id'])
        .where((id) => id != null)
        .toSet()
        .length;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _vendedorVencidasId,
                      decoration: const InputDecoration(
                        labelText: 'Filtrar por vendedor',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Todos los vendedores',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final v in state.vendedores)
                          DropdownMenuItem<String?>(
                            value: v['id'] as String,
                            child: Text(
                              '${v['nombre']} (${v['tipo']})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _vendedorVencidasId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar factura o cliente...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchVencidas = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loadingVencidas ? null : _cargarVencidas,
                    icon: _loadingVencidas
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      _loadingVencidas ? 'Actualizando...' : 'Actualizar',
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _imprimirReporteVencidas,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Imprimir / PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: BearColors.danger,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          children: [
            _statCard(
              'Facturas vencidas',
              '${vencidasFiltradas.length}',
              color: BearColors.red,
              onTap: () =>
                  _mostrarDetalleStat('Facturas Vencidas', vencidasFiltradas),
            ),
            _statCard(
              'Monto vencido (Saldo)',
              money(totalMontoVencido),
              color: BearColors.gold,
              onTap: () =>
                  _mostrarDetalleStat('Monto Vencido', vencidasFiltradas),
            ),
            _statCard(
              'Total de esas ventas',
              money(totalVentasVencidas),
              color: BearColors.indigo,
              onTap: () => _mostrarDetalleStat(
                'Ventas Vencidas Totales',
                vencidasFiltradas,
              ),
            ),
            _statCard(
              'Clientes con atraso',
              '$clientesUnicos',
              onTap: () => _mostrarDetalleStat(
                'Vencidas por Cliente',
                vencidasFiltradas,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: vencidasFiltradas.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('¡Excelente! No hay facturas vencidas'),
                  ),
                )
              : ScrollableDataTable(
                  columns: const [
                    DataColumn(label: Text('Folio')),
                    DataColumn(label: Text('Emisión')),
                    DataColumn(label: Text('Cliente')),
                    DataColumn(label: Text('Vendedor')),
                    DataColumn(label: Text('Total')),
                    DataColumn(label: Text('Saldo')),
                    DataColumn(label: Text('Venció')),
                    DataColumn(label: Text('Días de atraso')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: vencidasFiltradas.map((c) {
                    final emision =
                        c['fecha_emision'] as String? ??
                        c['fecha_venta'] as String?;
                    final vence = c['fecha_vencimiento'] as String?;
                    final dias = _calcularDiasAtraso(vence);
                    return DataRow(
                      cells: [
                        DataCell(Text(c['folio'] as String? ?? '-')),
                        DataCell(Text(fmtDate(emision ?? ''))),
                        DataCell(Text(c['cliente_nombre'] as String? ?? '-')),
                        DataCell(Text(c['vendedor_nombre'] as String? ?? '-')),
                        DataCell(Text(money(c['monto_total'] as num?))),
                        DataCell(Text(money(c['saldo'] as num?))),
                        DataCell(Text(fmtDate(vence))),
                        DataCell(
                          StatusPill(
                            label: '$dias días',
                            color: BearColors.red,
                          ),
                        ),
                        DataCell(
                          RecordarWhatsAppButton(
                            onPressed: () {
                              final cliente = resolveClienteForWhatsApp(
                                state,
                                clienteId: c['cliente_id'] as String?,
                                clienteNombre: c['cliente_nombre'] as String?,
                                clienteCodigo: c['cliente_codigo'] as String?,
                                clienteTelefono:
                                    c['cliente_telefono'] as String?,
                              );
                              if (cliente == null) return;
                              final creditos = creditosPendientesCliente(
                                state,
                                clienteId: c['cliente_id'] as String?,
                                clienteNombre: c['cliente_nombre'] as String?,
                                extra: [c],
                              );
                              showWhatsAppNotifyDialog(
                                context: context,
                                cliente: cliente,
                                creditos: creditos,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildClientes(AppState state) {
    final resumen = _reporteClientes?['resumen'] as Map<String, dynamic>?;
    final totales = _reporteClientes?['totales'] as Map<String, dynamic>?;
    final clientes = _clientesFiltrados();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _periodoClienteTabs,
                  isScrollable: true,
                  onTap: (i) {
                    const periodos = ['', 'hoy', 'semanal', 'personalizado'];
                    setState(() => _periodoCliente = periodos[i]);
                  },
                  tabs: const [
                    Tab(text: 'Todo el tiempo'),
                    Tab(text: 'Hoy'),
                    Tab(text: 'Semanal'),
                    Tab(text: 'Personalizado'),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_periodoCliente == 'personalizado') ...[
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Desde',
                          value: _desdeCliente,
                          onChanged: (v) => setState(() => _desdeCliente = v),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Hasta',
                          value: _hastaCliente,
                          onChanged: (v) => setState(() => _hastaCliente = v),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _vendedorClienteId,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por vendedor',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Todos los vendedores',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final v in state.vendedores)
                            DropdownMenuItem<String?>(
                              value: v['id'] as String,
                              child: Text(
                                '${v['nombre']} (${v['tipo']})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _vendedorClienteId = v);
                          _generarClientes();
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: _loadingClientes ? null : _generarClientes,
                      child: Text(
                        _loadingClientes ? 'Generando...' : 'Generar reporte',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterTab(
                      label: 'Todos',
                      selected: _filtroCliente == 'todos',
                      onTap: () {
                        setState(() => _filtroCliente = 'todos');
                        _generarClientes();
                      },
                    ),
                    _FilterTab(
                      label: 'Con adeudo',
                      selected: _filtroCliente == 'adeudo',
                      onTap: () {
                        setState(() => _filtroCliente = 'adeudo');
                        _generarClientes();
                      },
                    ),
                    _FilterTab(
                      label: 'Más activos',
                      selected: _filtroCliente == 'activos',
                      onTap: () {
                        setState(() => _filtroCliente = 'activos');
                        _generarClientes();
                      },
                    ),
                    _FilterTab(
                      label: 'Inactivos',
                      selected: _filtroCliente == 'sin_compras',
                      onTap: () {
                        setState(() => _filtroCliente = 'sin_compras');
                        _generarClientes();
                      },
                    ),
                  ],
                ),
                if (_errorClientes != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorClientes!,
                    style: const TextStyle(color: BearColors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_reporteClientes != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                [
                  if (_reporteClientes!['periodo'] != null)
                    'Periodo: ${_reporteClientes!['periodo']} a '
                        '${fmtDate(_reporteClientes!['desde'] as String?)}'
                        '${_reporteClientes!['desde'] != _reporteClientes!['hasta'] ? ' a ${fmtDate(_reporteClientes!['hasta'] as String?)}' : ''}',
                  if (_vendedorClienteId != null)
                    'Vendedor: ${state.vendedores.firstWhere((v) => v['id'] == _vendedorClienteId, orElse: () => {'nombre': '-'})['nombre']}',
                ].join(' - '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final vendNombre = _vendedorClienteId == null
                      ? null
                      : state.vendedores
                            .firstWhere(
                              (v) => v['id'] == _vendedorClienteId,
                              orElse: () => {'nombre': ''},
                            )['nombre']
                            ?.toString();
                  runPrintAction(
                    context,
                    () => printReporteClientes(
                      reporte: _reporteClientes!,
                      config: state.config,
                      clientes: clientes,
                      vendedorNombre: vendNombre,
                    ),
                  );
                },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Imprimir / PDF'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _statCard(
                'Total clientes',
                '${(resumen?['total_clientes'] as num?)?.toInt() ?? 0}',
              ),
              _statCard(
                'Con adeudo',
                '${(resumen?['con_adeudo'] as num?)?.toInt() ?? 0}',
                color: BearColors.gold,
              ),
              _statCard(
                'Activos',
                '${(resumen?['activos'] as num?)?.toInt() ?? 0}',
                color: BearColors.indigo,
              ),
              _statCard(
                'Inactivos',
                '${(resumen?['sin_compras'] as num?)?.toInt() ?? 0}',
                color: BearColors.textMuted,
              ),
              _statCard(
                'Saldo filtrado',
                money(totales?['saldo'] as num?),
                color: BearColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchField(
            hintText: 'Buscar por nombre, código, teléfono o vendedor...',
            onChanged: (v) => setState(() => _searchCliente = v),
          ),
          const SizedBox(height: 8),
          Text(
            '${clientes.length} cliente(s) en esta vista',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: clientes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Sin clientes en este filtro')),
                  )
                : ScrollableDataTable(
                    columns: const [
                      DataColumn(label: Text('Código')),
                      DataColumn(label: Text('Cliente')),
                      DataColumn(label: Text('Vendedor')),
                      DataColumn(label: Text('Compras')),
                      DataColumn(label: Text('Total comprado')),
                      DataColumn(label: Text('Pagado')),
                      DataColumn(label: Text('Saldo')),
                      DataColumn(label: Text('Última compra')),
                      DataColumn(label: Text('Estado')),
                    ],
                    rows: clientes.map((c) {
                      final tieneAdeudo = c['tiene_adeudo'] == true;
                      final sinCompras = (c['num_compras'] as int? ?? 0) == 0;
                      final estado = sinCompras
                          ? 'Inactivo'
                          : tieneAdeudo
                          ? 'Con adeudo'
                          : 'Al corriente';
                      final color = sinCompras
                          ? BearColors.textMuted
                          : tieneAdeudo
                          ? BearColors.danger
                          : BearColors.success;
                      return DataRow(
                        cells: [
                          DataCell(Text('${c['codigo'] ?? '-'}')),
                          DataCell(Text(c['nombre'] as String? ?? '-')),
                          DataCell(
                            Text(c['vendedor_nombre'] as String? ?? '-'),
                          ),
                          DataCell(Text('${c['num_compras'] ?? 0}')),
                          DataCell(Text(money(c['total_ventas'] as num?))),
                          DataCell(Text(money(c['total_pagado'] as num?))),
                          DataCell(Text(money(c['saldo_pendiente'] as num?))),
                          DataCell(
                            Text(fmtDate(c['ultima_compra'] as String?)),
                          ),
                          DataCell(StatusPill(label: estado, color: color)),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildGanancias(AppState state) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _periodoGan,
                        decoration: const InputDecoration(
                          labelText: 'Periodo',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'hoy',
                            child: Text(
                              'Hoy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'semanal',
                            child: Text(
                              'Esta semana',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'personalizado',
                            child: Text(
                              'Personalizado',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _periodoGan = v ?? 'semanal'),
                      ),
                    ),
                    if (_periodoGan == 'personalizado') ...[
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Desde',
                          value: _desdeGan,
                          onChanged: (v) => setState(() => _desdeGan = v),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Hasta',
                          value: _hastaGan,
                          onChanged: (v) => setState(() => _hastaGan = v),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _vendedorGanId,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por vendedor',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Todos los vendedores',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final v in state.vendedores)
                            DropdownMenuItem<String?>(
                              value: v['id'] as String,
                              child: Text(
                                '${v['nombre']} (${v['tipo']})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _vendedorGanId = v),
                      ),
                    ),
                    FilledButton(
                      onPressed: _loadingGan ? null : _generarGanancias,
                      child: Text(_loadingGan ? 'Generando...' : 'Generar'),
                    ),
                  ],
                ),
                if (_errorGan != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorGan!,
                    style: const TextStyle(color: BearColors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_reporteGanancias != null) ...[
          const SizedBox(height: 12),
          Text(
            'Ganancias - ${_reporteGanancias!['periodo']}: '
            '${fmtDate(_reporteGanancias!['desde'] as String?)}'
            '${_reporteGanancias!['desde'] != _reporteGanancias!['hasta'] ? ' a ${fmtDate(_reporteGanancias!['hasta'] as String?)}' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GananciasView(data: _reporteGanancias!),
        ],
      ],
    );
  }

  Widget _buildComisiones(AppState state) {
    final totales = _reporteComisiones?['totales'] as Map<String, dynamic>?;
    final filas =
        (_reporteComisiones?['vendedores'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return ListView(
      children: [
        Card(
          color: BearColors.indigo.withValues(alpha: 0.06),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.payments_rounded, color: BearColors.indigo),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Comisión a pagar al vendedor = su % × el total de cada venta. '
                    'Aunque el cliente no haya pagado (o solo pagó parte), aquí se toma la venta completa '
                    'para liquidar al empleado.',
                    style: TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  controller: _periodoComisionTabs,
                  isScrollable: true,
                  onTap: (i) {
                    const periodos = ['', 'hoy', 'semanal', 'personalizado'];
                    setState(() => _periodoComision = periodos[i]);
                  },
                  tabs: const [
                    Tab(text: 'Todo el tiempo'),
                    Tab(text: 'Hoy'),
                    Tab(text: 'Semanal'),
                    Tab(text: 'Personalizado'),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_periodoComision == 'personalizado') ...[
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Desde',
                          value: _desdeComision,
                          onChanged: (v) => setState(() => _desdeComision = v),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: _DateField(
                          label: 'Hasta',
                          value: _hastaComision,
                          onChanged: (v) => setState(() => _hastaComision = v),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        value: _vendedorComisionId,
                        decoration: const InputDecoration(
                          labelText: 'Vendedor',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Todos los vendedores',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final v in state.vendedores)
                            DropdownMenuItem<String?>(
                              value: v['id'] as String,
                              child: Text(
                                '${v['nombre']} (${v['porcentaje_comision']}%)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _vendedorComisionId = v);
                          _generarComisiones();
                        },
                      ),
                    ),
                    FilledButton(
                      onPressed: _loadingComisiones ? null : _generarComisiones,
                      child: Text(
                        _loadingComisiones ? 'Generando...' : 'Generar reporte',
                      ),
                    ),
                  ],
                ),
                if (_errorComisiones != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorComisiones!,
                    style: const TextStyle(color: BearColors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_reporteComisiones != null) ...[
          const SizedBox(height: 16),
          Text(
            'Periodo: ${_reporteComisiones!['periodo']}'
            '${_reporteComisiones!['desde'] != null ? ' a ${fmtDate(_reporteComisiones!['desde'] as String?)}' : ''}'
            '${_reporteComisiones!['desde'] != _reporteComisiones!['hasta'] && _reporteComisiones!['hasta'] != null ? ' a ${fmtDate(_reporteComisiones!['hasta'] as String?)}' : ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _statCard(
                'Ventas totales',
                money(totales?['ventas'] as num?),
                color: BearColors.indigo,
              ),
              _statCard(
                'Cobrado clientes',
                money(totales?['cobrado'] as num?),
                color: BearColors.success,
              ),
              _statCard(
                'A PAGAR VENDEDORES',
                money(totales?['comision_a_pagar'] as num?),
                color: BearColors.gold,
              ),
              _statCard('Vendedores', '${totales?['num_vendedores'] ?? 0}'),
              _statCard('Ventas', '${totales?['num_ventas'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: filas.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Sin ventas en este periodo')),
                  )
                : ScrollableDataTable(
                    columns: const [
                      DataColumn(label: Text('Vendedor')),
                      DataColumn(label: Text('%')),
                      DataColumn(label: Text('Ventas')),
                      DataColumn(label: Text('Total vendido')),
                      DataColumn(label: Text('Cobrado')),
                      DataColumn(label: Text('A PAGAR')),
                    ],
                    rows: filas.map((f) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(f['vendedor_nombre'] as String? ?? '-'),
                          ),
                          DataCell(Text('${f['porcentaje'] ?? 0}%')),
                          DataCell(Text('${f['num_ventas'] ?? 0}')),
                          DataCell(Text(money(f['ventas'] as num?))),
                          DataCell(Text(money(f['cobrado'] as num?))),
                          DataCell(
                            Text(
                              money(f['comision_a_pagar'] as num?),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: BearColors.gold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildPromotor(AppState state) {
    final totales = _reportePromotor?['totales'] as Map<String, dynamic>?;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _promotorId,
                    decoration: const InputDecoration(
                      labelText: 'Promotor',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '- Seleccionar -',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final p in state.promotores)
                        DropdownMenuItem<String?>(
                          value: p['id'] as String,
                          child: Text(
                            p['nombre'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _promotorId = v),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: _DateField(
                    label: 'Desde',
                    value: _desde,
                    onChanged: (v) => setState(() => _desde = v),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: _DateField(
                    label: 'Hasta',
                    value: _hasta,
                    onChanged: (v) => setState(() => _hasta = v),
                  ),
                ),
                FilledButton(
                  onPressed: _loading ? null : _generarPromotor,
                  child: Text(_loading ? 'Generando...' : 'Generar reporte'),
                ),
              ],
            ),
          ),
        ),
        if (_error != null && _vistaTabs.index == 4)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: const TextStyle(color: BearColors.red)),
          ),
        if (_reportePromotor != null) ...[
          const SizedBox(height: 16),
          Text(
            'Promotor: ${_reportePromotor!['promotor']['nombre']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            children: [
              _statCard(
                'Ventas equipo',
                money(totales?['ventas'] as num?),
                color: BearColors.indigo,
              ),
              _statCard(
                'Cobrado',
                money(totales?['cobrado'] as num?),
                color: BearColors.success,
              ),
              _statCard(
                'Pendiente',
                money(totales?['saldo'] as num?),
                color: BearColors.gold,
              ),
              _statCard(
                'Comisión venta',
                money(totales?['comision_venta'] as num?),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final block in (_reportePromotor!['vendedores'] as List))
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${block['vendedor']['nombre']} - Ventas: ${money(block['totales']['ventas'] as num?)} | '
                      'A pagar (sobre venta): ${money(block['totales']['comision_venta'] as num?)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pendientes: ${(block['lista_pendientes'] as List).length} | Saldo: ${money(block['totales']['saldo'] as num?)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(
          value.isEmpty ? 'Seleccionar' : fmtDate(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
