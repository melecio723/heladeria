import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/bear_theme.dart';
import 'format.dart';

/// Verde oficial de WhatsApp.
const whatsappGreen = Color(0xFF25D366);

/// Normaliza un teléfono para wa.me: quita espacios/guiones y agrega código país si falta.
String normalizePhone(String? raw, {String codigoPais = '58'}) {
  if (raw == null || raw.trim().isEmpty) return '';
  var digits = raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  final cc = codigoPais.replaceAll(RegExp(r'\D'), '');
  if (cc.isNotEmpty && !digits.startsWith(cc)) {
    if (digits.startsWith('0')) digits = digits.substring(1);
    digits = '$cc$digits';
  }
  return digits;
}

/// Construye el mensaje de cobranza con formato WhatsApp (negritas con *).
String buildCobranzaMessage({
  required Map<String, dynamic> cliente,
  required List<Map<String, dynamic>> creditos,
  String? firma,
  String? nombreNegocio,
}) {
  final nombre = (cliente['nombre'] as String? ?? 'Cliente').trim();
  final pendientes = creditos
      .where((c) => c['estado'] != 'pagado')
      .toList()
    ..sort((a, b) {
      final fa = a['fecha_vencimiento'] as String? ?? '';
      final fb = b['fecha_vencimiento'] as String? ?? '';
      return fa.compareTo(fb);
    });

  if (pendientes.isEmpty) {
    return 'Hola, *$nombre* 👋\n\nNo tiene deudas pendientes registradas.';
  }

  final totalSaldo = pendientes.fold<double>(
    0,
    (s, c) => s + ((c['saldo'] as num?)?.toDouble() ?? 0),
  );
  final totalPagado = pendientes.fold<double>(
    0,
    (s, c) => s + ((c['monto_pagado'] as num?)?.toDouble() ?? 0),
  );

  final buf = StringBuffer()
    ..writeln('Hola, *$nombre* 👋')
    ..writeln()
    ..writeln(
      'Por medio de este mensaje le compartimos el estado de su cuenta y compras pendientes con nosotros. '
      'A continuación el detalle de su deuda:',
    )
    ..writeln()
    ..writeln('📋 *DETALLE DE DEUDA — TOTAL ABONADO ${money(totalPagado)}*')
    ..writeln();

  for (final c in pendientes) {
    final factura = (c['numero_factura'] ?? c['folio'] ?? '—').toString();
    final saldo = money(c['saldo'] as num?);
    final vence = fmtDate(c['fecha_vencimiento'] as String?);
    buf.writeln('• Factura $factura — $saldo — Vence $vence');
  }

  buf
    ..writeln()
    ..writeln('_Favor actualizar pagos a la brevedad posible._')
    ..writeln()
    ..writeln('Agradecemos su preferencia.')
    ..writeln()
    ..writeln('────────────────');

  final firmaFinal = (firma ?? '').trim();
  if (firmaFinal.isNotEmpty) {
    buf.writeln(firmaFinal);
  } else if ((nombreNegocio ?? '').trim().isNotEmpty) {
    buf.writeln(nombreNegocio!.trim());
  }

  buf.writeln();
  buf.writeln('*Saldo total pendiente: ${money(totalSaldo)}*');

  return buf.toString().trimRight();
}

/// Abre WhatsApp Web / app con mensaje pre-cargado vía wa.me.
Future<bool> openWhatsApp({
  required String telefono,
  required String mensaje,
  String codigoPais = '58',
}) async {
  final phone = normalizePhone(telefono, codigoPais: codigoPais);
  if (phone.isEmpty) return false;

  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(mensaje)}');
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

/// Muestra SnackBar si no hay teléfono del cliente.
void showTelefonoFaltanteSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Agregue teléfono al cliente para enviar recordatorio por WhatsApp'),
      backgroundColor: BearColors.warning,
    ),
  );
}

/// Ícono estilo WhatsApp (burbuja verde).
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chat_rounded, color: whatsappGreen, size: size);
  }
}
