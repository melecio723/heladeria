import 'dart:async';
import 'dart:io' show File, Platform, Process;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const _logoAsset = 'assets/images/bear_logo_nobg.png';

const _fontBase = 7.0;
const _fontSmall = 6.5;
const _fontTitle = 8.5;

double _fontScale(double widthMm) => widthMm <= 58 ? 1.0 : 1.22;

String fmtDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final parts = dateStr.split('T').first.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateStr;
  } catch (_) {
    return dateStr;
  }
}

String fmtDateTime(String? dtStr) {
  if (dtStr == null || dtStr.isEmpty) return '-';
  try {
    final dt = DateTime.parse(dtStr);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return dtStr;
  }
}

String qtyLabel(num? qty) {
  if (qty == null) return '1';
  if (qty == qty.roundToDouble()) {
    return qty.toInt().toString();
  }
  return qty.toString();
}

Future<String?> _saveAndOpenPdf({
  required Uint8List pdfBytes,
  required String filename,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final path = '${dir.path}/$safeName';
  await File(path).writeAsBytes(pdfBytes);
  debugPrint('[print] PDF guardado: $path (${pdfBytes.length} bytes)');

  if (Platform.isMacOS) {
    final result = await Process.run('open', [path]);
    if (result.exitCode != 0) {
      throw StateError('open falló: ${result.stderr}');
    }
    return 'Se abrió el PDF en Vista Previa — use Archivo > Imprimir';
  }
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
    return 'Se abrió el PDF — use Archivo > Imprimir en su lector';
  }
  if (Platform.isLinux) {
    await Process.run('xdg-open', [path]);
    return 'Se abrió el PDF — use Archivo > Imprimir en su lector';
  }
  return null;
}

Future<String?> _printOrOpenPdf({
  required Uint8List pdfBytes,
  String filename = 'documento.pdf',
}) async {
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final msg = await _saveAndOpenPdf(
          pdfBytes: pdfBytes,
          filename: filename,
        );
        if (msg != null) return msg;
      } catch (e, st) {
        debugPrint('[print] Error abriendo PDF: $e\n$st');
      }
    }
  }
  await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  return 'Use Imprimir o Guardar desde el diálogo de compartir';
}

Future<void> runPrintAction(
  BuildContext context,
  Future<String?> Function() action,
) async {
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando documento…'),
            ],
          ),
        ),
      ),
    ),
  );

  String? message;
  try {
    message = await action();
  } catch (e, st) {
    debugPrint('[print] Error en acción: $e\n$st');
    message = 'Error al generar el documento: $e';
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (context.mounted) {
    showPrintMessage(context, message);
  }
}

void showPrintMessage(BuildContext context, String? message) {
  if (message != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String? _itemDetalle(Map<String, dynamic> item) {
  final detalle = (item['detalle'] as String?)?.trim();
  if (detalle == null || detalle.isEmpty) return null;
  return detalle;
}

List<Map<String, dynamic>> getItemsFromCredito(Map<String, dynamic> credito) {
  final items = credito['items'] as List?;
  if (items != null && items.isNotEmpty) {
    return items.cast<Map<String, dynamic>>();
  }
  final desc = credito['descripcion'] as String? ?? 'Venta a crédito';
  return [
    {
      'descripcion': desc,
      'cantidad': 1,
      'precio_unitario': credito['monto_total'],
    },
  ];
}

({double subtotal, double impuesto, double total}) calcTotales(
  List<Map<String, dynamic>> items,
  Map<String, dynamic> config,
) {
  var subtotal = 0.0;
  for (final i in items) {
    subtotal +=
        (i['cantidad'] as num? ?? 1).toDouble() *
        (i['precio_unitario'] as num? ?? 0).toDouble();
  }
  final pct = config['aplica_impuesto'] == true
      ? ((config['impuesto_porcentaje'] as num?) ?? 16).toDouble()
      : 0.0;
  final impuesto = (subtotal * pct / 100 * 100).round() / 100;
  final total = ((subtotal + impuesto) * 100).round() / 100;
  return (subtotal: subtotal, impuesto: impuesto, total: total);
}

double _estimateTicketHeightMm({
  required int itemCount,
  int cuotaCount = 0,
  bool hasNotas = false,
}) {
  var h = 80.0;
  h += itemCount.clamp(1, 40) * 14.0;
  if (cuotaCount > 0) h += 10.0 + cuotaCount * 6.0;
  h += 28.0;
  if (hasNotas) h += 12.0;
  if (h < 120) h = 120;
  if (h > 400) h = 400;
  return h;
}

PdfPageFormat _ticketFormat(Map<String, dynamic> config, {double? heightMm}) {
  final widthMm = (config['ancho_ticket_mm'] as num?)?.toDouble() ?? 58.0;
  final marginMm = widthMm <= 58 ? 1.8 : 2.5;
  final h = heightMm ?? 150.0;
  return PdfPageFormat(
    widthMm * PdfPageFormat.mm,
    h * PdfPageFormat.mm,
    marginLeft: marginMm * PdfPageFormat.mm,
    marginRight: marginMm * PdfPageFormat.mm,
    marginTop: marginMm * PdfPageFormat.mm,
    marginBottom: marginMm * PdfPageFormat.mm,
  );
}

pw.ThemeData get _ticketTheme =>
    pw.ThemeData.withFont(base: pw.Font.courier(), bold: pw.Font.courierBold());

Future<pw.MemoryImage> _loadLogo() async {
  final logoData = await rootBundle.load(_logoAsset);
  return pw.MemoryImage(logoData.buffer.asUint8List());
}

String _clienteCodigo(
  Map<String, dynamic> credito,
  Map<String, dynamic>? cliente,
) {
  final code =
      credito['cliente_codigo'] as String? ?? cliente?['codigo'] as String?;
  if (code == null || code.trim().isEmpty) return '-';
  return code.trim();
}

String? _venceCredito(Map<String, dynamic> credito) {
  final direct = credito['fecha_vencimiento'] as String?;
  if (direct != null && direct.isNotEmpty) return direct;
  final cuotas = credito['cuotas'] as List?;
  if (cuotas != null && cuotas.isNotEmpty) {
    return (cuotas.last as Map<String, dynamic>)['fecha_vencimiento']
        as String?;
  }
  return null;
}

String _money(num? v) => (v ?? 0).toStringAsFixed(2);

pw.TextStyle _ts({double? size, bool bold = false, double scale = 1}) =>
    pw.TextStyle(
      fontSize: (size ?? _fontBase) * scale,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

pw.Widget _ticketLine(
  String text, {
  bool bold = false,
  double? size,
  pw.TextAlign? align,
  double scale = 1,
}) {
  return pw.Text(
    text,
    textAlign: align,
    softWrap: true,
    maxLines: 6,
    style: _ts(size: size, bold: bold, scale: scale),
  );
}

pw.Widget _ticketRow(
  String left,
  String right, {
  bool bold = false,
  double scale = 1,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: pw.Text(
          left,
          softWrap: true,
          maxLines: 4,
          style: _ts(bold: bold, scale: scale),
        ),
      ),
      pw.SizedBox(width: 2),
      pw.Expanded(
        flex: 2,
        child: pw.Text(
          right,
          textAlign: pw.TextAlign.right,
          softWrap: true,
          maxLines: 2,
          style: _ts(bold: bold, scale: scale),
        ),
      ),
    ],
  );
}

pw.Widget _ticketTotalsBlock(
  List<({String label, String value, bool bold})> lines, {
  double scale = 1,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (final line in lines)
        _ticketRow(line.label, line.value, bold: line.bold, scale: scale),
    ],
  );
}

pw.Widget _ticketDivider() => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 2),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      top: pw.BorderSide(
        color: PdfColors.black,
        width: 0.4,
        style: pw.BorderStyle.dashed,
      ),
    ),
  ),
  height: 1,
);

pw.Widget _ticketLogo(pw.MemoryImage logoImage, double widthMm) {
  final maxW = (widthMm - 10) * PdfPageFormat.mm;
  final maxH = (widthMm <= 58 ? 11.0 : 16.0) * PdfPageFormat.mm;
  return pw.Center(
    child: pw.ConstrainedBox(
      constraints: pw.BoxConstraints(maxWidth: maxW, maxHeight: maxH),
      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
    ),
  );
}

Future<Uint8List> buildTicketPdf({
  required Map<String, dynamic> config,
  required Map<String, dynamic> credito,
  Map<String, dynamic>? cliente,
  pw.MemoryImage? logoImage,
}) async {
  final logo = logoImage ?? await _loadLogo();
  final items = getItemsFromCredito(credito);
  final totales = calcTotales(items, config);
  final negocio = config['nombre_negocio'] ?? 'Bear Helados';
  final pctLabel = ((config['impuesto_porcentaje'] as num?) ?? 16).toDouble();
  final codigo = _clienteCodigo(credito, cliente);
  final vence = _venceCredito(credito);
  final cuotas =
      (credito['cuotas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final widthMm = (config['ancho_ticket_mm'] as num?)?.toDouble() ?? 58.0;
  final scale = _fontScale(widthMm);
  final folio = '${credito['numero_factura'] ?? credito['folio'] ?? ''}';
  final heightMm = _estimateTicketHeightMm(
    itemCount: items.length,
    cuotaCount: cuotas.length,
  );

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: _ticketFormat(config, heightMm: heightMm),
      theme: _ticketTheme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _ticketLogo(logo, widthMm),
          pw.SizedBox(height: 2),
          pw.Center(
            child: _ticketLine(
              negocio,
              bold: true,
              size: _fontTitle,
              scale: scale,
            ),
          ),
          pw.SizedBox(height: 2),
          _ticketLine('Factura No. $folio', scale: scale),
          _ticketLine('Condicion: CREDITO', bold: true, scale: scale),
          _ticketDivider(),
          _ticketLine(
            'Emision: ${fmtDate(credito['fecha_venta'] as String?)}',
            scale: scale,
          ),
          _ticketLine('Vence: ${fmtDate(vence)}', scale: scale),
          _ticketDivider(),
          _ticketLine(
            'Cliente: ${credito['cliente_nombre'] ?? '-'}',
            bold: true,
            scale: scale,
          ),
          _ticketLine('Codigo: $codigo', scale: scale),
          _ticketLine(
            'Vendedor: ${credito['vendedor_nombre'] ?? '-'}',
            scale: scale,
          ),
          _ticketDivider(),
          for (final i in items) ...[
            _ticketLine('${i['descripcion']}', bold: true, scale: scale),
            if (_itemDetalle(i) != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 2),
                child: _ticketLine(
                  _itemDetalle(i)!,
                  size: _fontSmall,
                  scale: scale,
                ),
              ),
            _ticketRow(
              '${qtyLabel(i['cantidad'] as num?)} x ${_money((i['precio_unitario'] as num?)?.toDouble())}',
              _money(
                ((i['cantidad'] as num?)?.toDouble() ?? 0) *
                    ((i['precio_unitario'] as num?)?.toDouble() ?? 0),
              ),
              scale: scale,
            ),
            pw.SizedBox(height: 2),
          ],
          _ticketDivider(),
          _ticketTotalsBlock([
            (label: 'Sub Total:', value: _money(totales.subtotal), bold: false),
            (
              label: 'Impuesto ${pctLabel.toStringAsFixed(0)}%:',
              value: _money(totales.impuesto),
              bold: false,
            ),
            (
              label: 'Total Operacion:',
              value: _money(totales.total),
              bold: true,
            ),
          ], scale: scale),
          if (cuotas.length > 1) ...[
            _ticketDivider(),
            _ticketLine('CUOTAS (${cuotas.length})', bold: true, scale: scale),
            for (final c in cuotas)
              _ticketRow(
                '#${c['numero']} ${fmtDate(c['fecha_vencimiento'] as String?)}',
                _money((c['monto'] as num?)?.toDouble()),
                scale: scale,
              ),
          ],
          _ticketDivider(),
          pw.SizedBox(height: 2),
          pw.Center(
            child: _ticketLine(
              'Gracias por su compra',
              size: _fontSmall,
              scale: scale,
            ),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

Future<String?> printOrdenDespacho({
  required Map<String, dynamic> config,
  required Map<String, dynamic> credito,
  Map<String, dynamic>? cliente,
}) async {
  final logoImage = await _loadLogo();
  final items = getItemsFromCredito(credito);
  final negocio = config['nombre_negocio'] ?? 'Gestor de Créditos';
  final codigo = _clienteCodigo(credito, cliente);
  final dir =
      credito['cliente_direccion'] as String? ??
      cliente?['direccion'] as String?;
  final tel =
      credito['cliente_telefono'] as String? ?? cliente?['telefono'] as String?;
  final widthMm = (config['ancho_ticket_mm'] as num?)?.toDouble() ?? 58.0;
  final scale = _fontScale(widthMm);
  final heightMm = _estimateTicketHeightMm(itemCount: items.length);

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: _ticketFormat(config, heightMm: heightMm),
      theme: _ticketTheme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _ticketLogo(logoImage, widthMm),
          pw.SizedBox(height: 2),
          pw.Center(
            child: _ticketLine(
              'ORDEN DE DESPACHO',
              bold: true,
              size: _fontTitle,
              scale: scale,
            ),
          ),
          pw.Center(
            child: _ticketLine(negocio, size: _fontSmall, scale: scale),
          ),
          _ticketDivider(),
          _ticketRow(
            'Factura',
            '${credito['numero_factura'] ?? credito['folio']}',
            scale: scale,
          ),
          _ticketRow(
            'Emision',
            fmtDate(credito['fecha_venta'] as String?),
            scale: scale,
          ),
          _ticketDivider(),
          _ticketLine(
            'Cliente: ${credito['cliente_nombre'] ?? '-'}',
            bold: true,
            scale: scale,
          ),
          _ticketLine('Codigo: $codigo', size: _fontSmall, scale: scale),
          if (dir != null && dir.isNotEmpty)
            _ticketLine('Dir: $dir', size: _fontSmall, scale: scale),
          if (tel != null && tel.isNotEmpty)
            _ticketLine('Tel: $tel', size: _fontSmall, scale: scale),
          _ticketLine(
            'Vendedor: ${credito['vendedor_nombre'] ?? '-'}',
            size: _fontSmall,
            scale: scale,
          ),
          _ticketDivider(),
          _ticketLine('PRODUCTOS', bold: true, size: _fontSmall, scale: scale),
          pw.SizedBox(height: 3),
          for (final i in items) ...[
            _ticketLine('${i['descripcion']}', bold: true, scale: scale),
            if (_itemDetalle(i) != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 2),
                child: _ticketLine(
                  _itemDetalle(i)!,
                  size: _fontSmall,
                  scale: scale,
                ),
              ),
            _ticketRow('Cant.', qtyLabel(i['cantidad'] as num?), scale: scale),
            pw.SizedBox(height: 2),
          ],
          _ticketDivider(),
          pw.SizedBox(height: 4),
          pw.Center(
            child: _ticketLine(
              '--- ENTREGAR ---',
              size: _fontSmall,
              scale: scale,
            ),
          ),
        ],
      ),
    ),
  );

  final folio = credito['numero_factura'] ?? credito['folio'] ?? 'doc';
  return _printOrOpenPdf(
    pdfBytes: await doc.save(),
    filename: 'orden-despacho-$folio.pdf',
  );
}

Future<String?> printTicket({
  required Map<String, dynamic> config,
  required Map<String, dynamic> credito,
  Map<String, dynamic>? cliente,
}) async {
  final folio = credito['numero_factura'] ?? credito['folio'] ?? 'doc';
  return _printOrOpenPdf(
    pdfBytes: await buildTicketPdf(
      config: config,
      credito: credito,
      cliente: cliente,
    ),
    filename: 'ticket-$folio.pdf',
  );
}

Future<String?> printSecuencialVenta({
  required Map<String, dynamic> config,
  required Map<String, dynamic> credito,
  Map<String, dynamic>? cliente,
}) async {
  final msg1 = await printTicket(
    config: config,
    credito: credito,
    cliente: cliente,
  );
  final msg2 = await printTicket(
    config: config,
    credito: credito,
    cliente: cliente,
  );
  return msg2 ?? msg1;
}

Future<Uint8List> buildCorteCajaPdf({
  required Map<String, dynamic> config,
  required Map<String, dynamic> sesion,
  required Map<String, dynamic> resumen,
  pw.MemoryImage? logoImage,
}) async {
  final logo = logoImage ?? await _loadLogo();
  final negocio = config['nombre_negocio'] ?? 'Bear Helados';
  final widthMm = (config['ancho_ticket_mm'] as num?)?.toDouble() ?? 58.0;
  final scale = _fontScale(widthMm);

  final apertura = (resumen['monto_apertura'] as num?)?.toDouble() ?? 0;
  final ventas = (resumen['ventas'] as num?)?.toDouble() ?? 0;
  final abonos = (resumen['abonos'] as num?)?.toDouble() ?? 0;
  final entradas = (resumen['entradas'] as num?)?.toDouble() ?? 0;
  final salidas = (resumen['salidas'] as num?)?.toDouble() ?? 0;
  final esperado =
      (resumen['esperado'] as num?)?.toDouble() ??
      (sesion['monto_esperado'] as num?)?.toDouble() ??
      0;
  final contado = (sesion['monto_cierre_contado'] as num?)?.toDouble();
  final diferencia = (sesion['diferencia'] as num?)?.toDouble();

  String difLabel() {
    if (diferencia == null) return '-';
    if (diferencia.abs() < 0.01) return 'Cuadrada';
    return diferencia > 0 ? 'Sobrante' : 'Faltante';
  }

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: _ticketFormat(config, heightMm: 140),
      theme: _ticketTheme,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _ticketLogo(logo, widthMm),
          pw.SizedBox(height: 2),
          pw.Center(
            child: _ticketLine(
              negocio,
              bold: true,
              size: _fontTitle,
              scale: scale,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: _ticketLine(
              'CORTE DE CAJA',
              bold: true,
              size: _fontTitle,
              scale: scale,
            ),
          ),
          _ticketDivider(),
          _ticketLine('Caja: ${sesion['caja_nombre'] ?? '-'}', scale: scale),
          _ticketLine(
            'Cajero: ${sesion['usuario_nombre'] ?? '-'}',
            scale: scale,
          ),
          _ticketLine(
            'Apertura: ${fmtDateTime(sesion['fecha_apertura'] as String?)}',
            scale: scale,
          ),
          _ticketLine(
            'Cierre: ${fmtDateTime(sesion['fecha_cierre'] as String?)}',
            scale: scale,
          ),
          _ticketDivider(),
          _ticketRow('Fondo inicial', _money(apertura), scale: scale),
          _ticketRow('Ventas efectivo', _money(ventas), scale: scale),
          _ticketRow('Abonos efectivo', _money(abonos), scale: scale),
          _ticketRow('Entradas', _money(entradas), scale: scale),
          _ticketRow('Salidas', _money(salidas), scale: scale),
          _ticketDivider(),
          _ticketRow(
            'Total esperado',
            _money(esperado),
            bold: true,
            scale: scale,
          ),
          if (contado != null)
            _ticketRow(
              'Total contado',
              _money(contado),
              bold: true,
              scale: scale,
            ),
          if (diferencia != null)
            _ticketRow(
              'Diferencia',
              '${_money(diferencia)} (${difLabel()})',
              bold: true,
              scale: scale,
            ),
          if ((sesion['notas'] as String?)?.trim().isNotEmpty == true) ...[
            _ticketDivider(),
            _ticketLine('Notas:', bold: true, size: _fontSmall, scale: scale),
            _ticketLine(
              (sesion['notas'] as String).trim(),
              size: _fontSmall,
              scale: scale,
            ),
          ],
          _ticketDivider(),
          pw.SizedBox(height: 4),
          pw.Center(
            child: _ticketLine(
              'Firma: ____________________',
              size: _fontSmall,
              scale: scale,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
            child: _ticketLine(
              'Corte generado por el sistema',
              size: _fontSmall,
              scale: scale,
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

Future<String?> printCorteCaja({
  required Map<String, dynamic> config,
  required Map<String, dynamic> sesion,
  required Map<String, dynamic> resumen,
}) async {
  final id = '${sesion['id'] ?? 'corte'}'.split('-').first;
  return _printOrOpenPdf(
    pdfBytes: await buildCorteCajaPdf(
      config: config,
      sesion: sesion,
      resumen: resumen,
    ),
    filename: 'corte-caja-$id.pdf',
  );
}

Future<String?> printReporteCobranza({
  required Map<String, dynamic> reporte,
  required Map<String, dynamic> config,
  String tab = 'todos',
}) async {
  final logoImage = await _loadLogo();
  final items = tab == 'pagados'
      ? (reporte['lista_pagados'] as List).cast<Map<String, dynamic>>()
      : tab == 'pendientes'
      ? (reporte['lista_pendientes'] as List).cast<Map<String, dynamic>>()
      : (reporte['creditos'] as List).cast<Map<String, dynamic>>();

  final totales = reporte['totales'] as Map<String, dynamic>;
  final resumen = reporte['resumen'] as Map<String, dynamic>;
  final negocio = config['nombre_negocio'] ?? 'Gestor de Créditos';
  final desde = reporte['desde'] as String? ?? '';
  final hasta = reporte['hasta'] as String? ?? '';
  final periodo = reporte['periodo'] as String? ?? '';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Image(logoImage, height: 48),
        pw.SizedBox(height: 8),
        pw.Text(
          'Reporte de cobranza - $negocio',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Periodo: $periodo (${fmtDate(desde)}${desde != hasta ? ' - ${fmtDate(hasta)}' : ''}) - ${items.length} venta(s)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _pdfStat('Ventas', totales['ventas'], isCurrency: true),
            _pdfStat('Cobrado', totales['cobrado'], isCurrency: true),
            _pdfStat('Pendiente', totales['saldo'], isCurrency: true),
            _pdfStat('Créditos', resumen['total_creditos'], isCurrency: false),
            _pdfStat('Pagados', resumen['pagados'], isCurrency: false),
            _pdfStat('Pendientes', resumen['pendientes'], isCurrency: false),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Detalle ($tab)',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          headers: [
            'Factura',
            'Cliente',
            'Vendedor',
            'Total',
            'Pagado',
            'Saldo',
            'Vence',
            'Estado',
          ],
          data: items.isEmpty
              ? [
                  ['Sin registros', '', '', '', '', '', '', '', ''],
                ]
              : items.map((c) {
                  return [
                    c['numero_factura'] ?? c['folio'] ?? '-',
                    c['cliente_nombre'] ?? '-',
                    c['vendedor_nombre'] ?? '-',
                    '\$${((c['monto_total'] as num?) ?? 0).toStringAsFixed(2)}',
                    '\$${((c['monto_pagado'] as num?) ?? 0).toStringAsFixed(2)}',
                    '\$${((c['saldo'] as num?) ?? 0).toStringAsFixed(2)}',
                    fmtDate(c['fecha_vencimiento'] as String?),
                    c['estado'] ?? '-',
                  ];
                }).toList(),
        ),
      ],
    ),
  );

  return _printOrOpenPdf(
    pdfBytes: await doc.save(),
    filename: 'reporte-cobranza-${periodo.replaceAll(' ', '-')}.pdf',
  );
}

Future<String?> printReporteClientes({
  required Map<String, dynamic> reporte,
  required Map<String, dynamic> config,
  required List<Map<String, dynamic>> clientes,
  String? vendedorNombre,
}) async {
  final logoImage = await _loadLogo();
  final totales = reporte['totales'] as Map<String, dynamic>? ?? {};
  final resumen = reporte['resumen'] as Map<String, dynamic>? ?? {};
  final negocio = config['nombre_negocio'] ?? 'Gestor de Créditos';
  final desde = reporte['desde'] as String? ?? '';
  final hasta = reporte['hasta'] as String? ?? '';
  final periodo = reporte['periodo'] as String? ?? 'Todo el tiempo';
  final filtro = reporte['filtro'] as String? ?? 'todos';

  const filtroLabels = {
    'todos': 'Todos',
    'adeudo': 'Con adeudo',
    'activos': 'Más activos',
    'sin_compras': 'Inactivos',
  };
  final filtroLabel = filtroLabels[filtro] ?? filtro;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Image(logoImage, height: 48),
        pw.SizedBox(height: 8),
        pw.Text(
          'Reporte de clientes - $negocio',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          [
            if (periodo.isNotEmpty) 'Periodo: $periodo',
            if (desde.isNotEmpty)
              '(${fmtDate(desde)}${desde != hasta ? ' - ${fmtDate(hasta)}' : ''})',
            'Filtro: $filtroLabel',
            if (vendedorNombre != null && vendedorNombre.isNotEmpty)
              'Vendedor: $vendedorNombre',
            '${clientes.length} cliente(s)',
          ].join(' - '),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        pw.Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _pdfStat(
              'Total clientes',
              resumen['total_clientes'],
              isCurrency: false,
            ),
            _pdfStat('Con adeudo', resumen['con_adeudo'], isCurrency: false),
            _pdfStat('Activos', resumen['activos'], isCurrency: false),
            _pdfStat('Inactivos', resumen['sin_compras'], isCurrency: false),
            _pdfStat('Saldo filtrado', totales['saldo'], isCurrency: true),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Listado de clientes',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          headers: [
            'Código',
            'Cliente',
            'Vendedor',
            'Compras',
            'Total',
            'Pagado',
            'Saldo',
            'Última compra',
          ],
          data: clientes.isEmpty
              ? [
                  ['Sin registros', '', '', '', '', '', '', ''],
                ]
              : clientes.map((c) {
                  return [
                    '${c['codigo'] ?? '-'}',
                    c['nombre'] ?? '-',
                    c['vendedor_nombre'] ?? '-',
                    '${c['num_compras'] ?? 0}',
                    '\$${((c['total_ventas'] as num?) ?? 0).toStringAsFixed(2)}',
                    '\$${((c['total_pagado'] as num?) ?? 0).toStringAsFixed(2)}',
                    '\$${((c['saldo_pendiente'] as num?) ?? 0).toStringAsFixed(2)}',
                    fmtDate(c['ultima_compra'] as String?),
                  ];
                }).toList(),
        ),
      ],
    ),
  );

  final suffix = vendedorNombre?.replaceAll(' ', '-') ?? 'todos';
  return _printOrOpenPdf(
    pdfBytes: await doc.save(),
    filename: 'reporte-clientes-$suffix.pdf',
  );
}

pw.Widget _pdfStat(String label, dynamic value, {bool isCurrency = true}) {
  final display = (value is num && isCurrency)
      ? '\$${value.toStringAsFixed(2)}'
      : (value is num ? value.toInt().toString() : '$value');
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
        ),
        pw.Text(
          display,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
