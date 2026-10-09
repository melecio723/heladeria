import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:win32/win32.dart' as win32;
import 'format.dart';

class RawThermalPrinter {
  /// Lista impresoras instaladas en Windows usando la API Win32 EnumPrinters.
  static List<String> getWindowsPrinters() {
    if (!Platform.isWindows) return [];

    final printers = <String>[];
    final flags = win32.PRINTER_ENUM_LOCAL | win32.PRINTER_ENUM_CONNECTIONS;
    final pBytesNeeded = calloc<win32.DWORD>();
    final pReturned = calloc<win32.DWORD>();

    try {
      win32.EnumPrinters(
        flags,
        nullptr,
        2,
        nullptr,
        0,
        pBytesNeeded,
        pReturned,
      );

      final needed = pBytesNeeded.value;
      if (needed == 0) return printers;

      final pBuffer = calloc<Uint8>(needed);
      try {
        final res = win32.EnumPrinters(
          flags,
          nullptr,
          2,
          pBuffer.cast(),
          needed,
          pBytesNeeded,
          pReturned,
        );

        if (res != 0) {
          final count = pReturned.value;
          final pPrinterInfo = pBuffer.cast<win32.PRINTER_INFO_2>();
          for (var i = 0; i < count; i++) {
            final info = (pPrinterInfo + i).ref;
            if (info.pPrinterName != nullptr) {
              final name = info.pPrinterName.toDartString();
              if (name.isNotEmpty) {
                printers.add(name);
              }
            }
          }
        }
      } finally {
        calloc.free(pBuffer);
      }
    } catch (e) {
      debugPrint('[raw_print] Error listando impresoras en Windows: $e');
    } finally {
      calloc.free(pBytesNeeded);
      calloc.free(pReturned);
    }

    return printers;
  }

  /// Envía bytes raw directamente al spooler de Windows (sin diálogos de PDF ni escalados).
  static Future<bool> printRawWindows({
    required String printerName,
    required List<int> bytes,
    String docName = 'Ticket ESC/POS',
  }) async {
    if (!Platform.isWindows) return false;

    final hPrinter = calloc<win32.HANDLE>();
    final pPrinterName = printerName.toNativeUtf16();
    final pDocName = docName.toNativeUtf16();
    final pDataType = 'RAW'.toNativeUtf16();

    try {
      final openRes = win32.OpenPrinter(pPrinterName, hPrinter, nullptr);
      if (openRes == 0) {
        final err = win32.GetLastError();
        debugPrint(
            '[raw_print] OpenPrinter falló para "$printerName" (Error $err)');
        return false;
      }

      final h = hPrinter.value;

      final docInfo = calloc<win32.DOC_INFO_1>();
      docInfo.ref.pDocName = pDocName;
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = pDataType;

      final dwJob = win32.StartDocPrinter(h, 1, docInfo);
      if (dwJob > 0) {
        win32.StartPagePrinter(h);

        final pData = calloc<Uint8>(bytes.length);
        pData.asTypedList(bytes.length).setAll(0, bytes);

        final written = calloc<win32.DWORD>();
        final writeRes = win32.WritePrinter(
          h,
          pData.cast(),
          bytes.length,
          written,
        );

        win32.EndPagePrinter(h);
        win32.EndDocPrinter(h);

        calloc.free(pData);
        calloc.free(written);

        calloc.free(docInfo);

        win32.ClosePrinter(h);
        return writeRes != 0;
      } else {
        win32.ClosePrinter(h);
        return false;
      }
    } catch (e, st) {
      debugPrint('[raw_print] Excepción imprimiendo RAW en Windows: $e\n$st');
      return false;
    } finally {
      calloc.free(pDocName);
      calloc.free(pDataType);
      calloc.free(pPrinterName);
      calloc.free(hPrinter);
    }
  }

  /// Envía bytes raw directamente a la impresora en Linux usando `lp -o raw` o `/dev/usb/lp0`.
  static Future<bool> printRawLinux({
    required String printerName,
    required List<int> bytes,
  }) async {
    if (!Platform.isLinux) return false;

    try {
      final tempFile = File('/tmp/escpos_ticket.bin');
      await tempFile.writeAsBytes(bytes);

      ProcessResult res;
      if (printerName.isNotEmpty) {
        res = await Process.run(
            'lp', ['-d', printerName, '-o', 'raw', tempFile.path]);
      } else {
        res = await Process.run('lp', ['-o', 'raw', tempFile.path]);
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      return res.exitCode == 0;
    } catch (e) {
      debugPrint('[raw_print] Error imprimiendo RAW en Linux: $e');
      return false;
    }
  }

  /// Genera búfer de bytes en comandos nativos ESC/POS.
  static Future<List<int>> generateTicketEscPos({
    required Map<String, dynamic> config,
    required Map<String, dynamic> credito,
    Map<String, dynamic>? cliente,
    bool openDrawer = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final widthMm = (config['ancho_ticket_mm'] as num?)?.toDouble() ?? 80.0;
    final paperSize = widthMm <= 58 ? PaperSize.mm58 : PaperSize.mm80;
    final generator = Generator(paperSize, profile);

    List<int> bytes = [];

    bytes += generator.reset();

    final negocio = config['nombre_negocio'] ?? 'Negocio Comercial';
    bytes += generator.text(
      negocio,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    final folio = '${credito['numero_factura'] ?? credito['folio'] ?? ''}';
    bytes += generator.text(
      'FACTURA No. $folio',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Condicion: CREDITO',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    bytes += generator
        .text('Emision: ${fmtDate(credito['fecha_venta'] as String?)}');
    final vence = credito['fecha_vencimiento'] as String?;
    if (vence != null && vence.isNotEmpty) {
      bytes += generator.text('Vence:   ${fmtDate(vence)}');
    }
    bytes += generator.hr();

    bytes += generator.text(
      'Cliente: ${credito['cliente_nombre'] ?? '-'}',
      styles: const PosStyles(bold: true),
    );
    final codigo = credito['cliente_codigo'] ?? cliente?['codigo'] ?? '-';
    bytes += generator.text('Codigo:  $codigo');
    bytes += generator.text('Vendedor:${credito['vendedor_nombre'] ?? '-'}');
    bytes += generator.hr();

    final items = (credito['items'] as List?)?.cast<Map<String, dynamic>>() ??
        [
          {
            'descripcion': credito['descripcion'] ?? 'Venta general',
            'cantidad': 1,
            'precio_unitario': credito['monto_total'] ?? 0,
          }
        ];

    var subtotal = 0.0;
    for (final i in items) {
      final desc = '${i['descripcion']}';
      final cant = (i['cantidad'] as num? ?? 1).toDouble();
      final precio = (i['precio_unitario'] as num? ?? 0).toDouble();
      final itemTotal = cant * precio;
      subtotal += itemTotal;

      bytes += generator.text(desc, styles: const PosStyles(bold: true));
      final cantStr = qtyLabel(cant);
      final priceStr = precio.toStringAsFixed(2);
      final totalStr = itemTotal.toStringAsFixed(2);

      bytes += generator.row([
        PosColumn(text: ' $cantStr x \$$priceStr', width: 8),
        PosColumn(
            text: '\$$totalStr',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    final pct = config['aplica_impuesto'] == true
        ? ((config['impuesto_porcentaje'] as num?) ?? 16).toDouble()
        : 0.0;
    final impuesto = (subtotal * pct / 100 * 100).round() / 100;
    final total = ((subtotal + impuesto) * 100).round() / 100;

    bytes += generator.row([
      PosColumn(text: 'Sub Total:', width: 8),
      PosColumn(
          text: '\$${subtotal.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (pct > 0) {
      bytes += generator.row([
        PosColumn(text: 'Impuesto (${pct.toStringAsFixed(0)}%):', width: 8),
        PosColumn(
            text: '\$${impuesto.toStringAsFixed(2)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          text: 'TOTAL OPERACION:',
          width: 8,
          styles: const PosStyles(bold: true)),
      PosColumn(
          text: '\$${total.toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    final cuotas =
        (credito['cuotas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (cuotas.length > 1) {
      bytes += generator.hr();
      bytes += generator.text('CUOTAS (${cuotas.length})',
          styles: const PosStyles(bold: true));
      for (final c in cuotas) {
        final numCuota = c['numero'];
        final fechaC = fmtDate(c['fecha_vencimiento'] as String?);
        final montoC =
            ((c['monto'] as num?) ?? 0).toDouble().toStringAsFixed(2);
        bytes += generator.row([
          PosColumn(text: '#$numCuota $fechaC', width: 8),
          PosColumn(
              text: '\$$montoC',
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }

    bytes += generator.hr();
    bytes += generator.feed(1);
    bytes += generator.text(
      'Gracias por su compra',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);

    if (openDrawer) {
      bytes += generator.drawer();
    }

    bytes += generator.cut();

    return bytes;
  }
}
