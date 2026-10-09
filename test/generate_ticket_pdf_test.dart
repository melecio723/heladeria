import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_creditos/utils/print_ticket.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera PDF de ticket estilo Bear de referencia', () async {
    final logoData = await rootBundle.load('assets/images/bear_logo_nobg.png');

    final config = {
      'nombre_negocio': 'Bear',
      'ancho_ticket_mm': 58,
      'aplica_impuesto': false,
    };
    final credito = {
      'numero_factura': '0000000054',
      'fecha_venta': '2026-03-18',
      'fecha_vencimiento': '2026-03-30',
      'cliente_nombre': 'Yonaide',
      'cliente_codigo': '78',
      'vendedor_nombre': 'MARIALEJAN',
      'items': [
        {
          'descripcion': 'COMBO DE HELADOS',
          'cantidad': 1,
          'precio_unitario': 15.0,
        },
      ],
    };

    final bytes = await buildTicketPdf(
      config: config,
      credito: credito,
      logoImage: pw.MemoryImage(logoData.buffer.asUint8List()),
    );

    final out = File('/tmp/ticket-bear-referencia.pdf');
    await out.writeAsBytes(bytes);
    expect(bytes.length, greaterThan(500));
    expect(await out.exists(), isTrue);
  });
}
