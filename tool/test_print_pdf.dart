// Script de diagnóstico: genera PDF de prueba y lo abre en Preview.
// Uso: dart run tool/test_print_pdf.dart
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (_) => pw.Center(
        child: pw.Text('Test impresión Gestor de Créditos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ),
    ),
  );
  final bytes = await doc.save();
  final path = '${Directory.systemTemp.path}/gestor-test-print.pdf';
  await File(path).writeAsBytes(bytes);
  print('[test_print] PDF generado: $path (${bytes.length} bytes)');

  if (Platform.isMacOS) {
    final result = await Process.run('open', [path]);
    print('[test_print] open exit=${result.exitCode} stderr=${result.stderr}');
    if (result.exitCode != 0) exit(1);
    print('[test_print] OK — debería abrirse Vista Previa');
  } else {
    print('[test_print] OK — abra manualmente: $path');
  }
}
