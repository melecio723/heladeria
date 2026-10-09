import 'package:intl/intl.dart';

final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
final dateFmt = DateFormat('dd/MM/yyyy');
final dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

String money(num? v) => currencyFmt.format(v ?? 0);
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return dateFmt.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

/// Fecha y hora legible (dd/MM/yyyy HH:mm) para apertura/cierre de caja.
String fmtDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    return dateTimeFmt.format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

/// Etiqueta legible de la presentación del producto (Individual / Combo).
String presentacionLabel(String? presentacion) {
  final p = (presentacion ?? '').trim().toLowerCase();
  if (p == 'combo') return 'Combo';
  if (p == 'individual' || p.isEmpty) return 'Individual';
  return presentacion!.trim();
}

/// Segunda línea de la etiqueta del producto: descripción + presentación.
/// Ej.: "Tinita · Combo" o simplemente "Individual" si no hay descripción.
String productoDetalle({String? descripcion, String? presentacion}) {
  final desc = (descripcion ?? '').trim();
  final pres = presentacionLabel(presentacion);
  if (desc.isEmpty) return pres;
  return '$desc · $pres';
}

/// Muestra una cantidad como entero limpio ("1", "2") cuando es un número
/// entero, evitando el ".0". Conserva decimales solo si realmente los tiene.
String qtyLabel(num? q) {
  final v = q ?? 0;
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toString();
}

String estadoLabel(String? estado) {
  switch (estado) {
    case 'pagado':
      return 'Pagado';
    case 'parcial':
      return 'Parcial';
    default:
      return 'Pendiente';
  }
}

String todayISO() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> generarCuotas(double monto, int numCuotas, String fechaPrimera) {
  if (numCuotas < 1 || monto <= 0) return [];
  final montoCuota = (monto / numCuotas * 100).round() / 100;
  final cuotas = <Map<String, dynamic>>[];
  var fecha = DateTime.parse(fechaPrimera);
  for (var i = 0; i < numCuotas; i++) {
    final m = i == numCuotas - 1 ? monto - montoCuota * (numCuotas - 1) : montoCuota;
    cuotas.add({
      'monto': m,
      'fecha_vencimiento':
          '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}',
    });
    fecha = DateTime(fecha.year, fecha.month + 1, fecha.day);
  }
  return cuotas;
}
