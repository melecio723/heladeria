// ignore_for_file: avoid_print

// Migración Firestore → SQLite local vía API REST de producción.
//
// Uso:
//   cd gestor-creditos-flutter
//   dart run tool/migrate_from_firebase.dart
//   dart run tool/migrate_from_firebase.dart --db-path /ruta/gestor_creditos.db
//   dart run tool/migrate_from_firebase.dart --api-url https://gestor-creditos.web.app/api
//   dart run tool/migrate_from_firebase.dart --dry-run
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _defaultApiUrl = 'https://gestor-creditos.web.app/api';

String _defaultDbPath() {
  final home = Platform.environment['HOME'] ?? '';
  return p.join(
    home,
    'Library/Containers/com.bearhelados.gestorCreditos/Data/Library/Application Support/com.bearhelados.gestorCreditos',
    'gestor_creditos.db',
  );
}

Future<List<dynamic>> _fetchList(String apiUrl, String endpoint) async {
  final uri = Uri.parse('$apiUrl/$endpoint');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('GET $uri → ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body);
  if (data is! List) throw Exception('Se esperaba lista en $endpoint');
  return data;
}

Future<Map<String, dynamic>> _fetchMap(String apiUrl, String endpoint) async {
  final uri = Uri.parse('$apiUrl/$endpoint');
  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('GET $uri → ${res.statusCode}: ${res.body}');
  }
  final data = jsonDecode(res.body);
  if (data is! Map<String, dynamic>)
    throw Exception('Se esperaba objeto en $endpoint');
  return data;
}

Future<Map<String, int>> _importAll(
  Database db,
  String apiUrl, {
  bool dryRun = false,
}) async {
  final counts = <String, int>{};

  print('Descargando productores...');
  final productores = await _fetchList(apiUrl, 'productores');
  counts['productores'] = productores.length;

  print('Descargando vendedores...');
  final vendedores = await _fetchList(apiUrl, 'vendedores');
  counts['vendedores'] = vendedores.length;

  print('Descargando clientes...');
  final clientes = await _fetchList(apiUrl, 'clientes');
  counts['clientes'] = clientes.length;

  print('Descargando créditos (lista)...');
  final creditos = await _fetchList(apiUrl, 'creditos');
  counts['creditos'] = creditos.length;

  print('Descargando config...');
  final config = await _fetchMap(apiUrl, 'config');

  final cuotasAll = <Map<String, dynamic>>[];
  final pagosAll = <Map<String, dynamic>>[];

  print(
    'Descargando detalle de ${creditos.length} créditos (cuotas + pagos)...',
  );
  for (final c in creditos) {
    final id = c['id'] as String;
    final detail = await _fetchMap(apiUrl, 'creditos/$id');
    for (final cuota in (detail['cuotas'] as List? ?? [])) {
      cuotasAll.add({
        ...Map<String, dynamic>.from(cuota as Map),
        'credito_id': id,
      });
    }
    for (final pago in (detail['pagos'] as List? ?? [])) {
      pagosAll.add({
        ...Map<String, dynamic>.from(pago as Map),
        'credito_id': id,
      });
    }
  }
  counts['cuotas'] = cuotasAll.length;
  counts['pagos'] = pagosAll.length;

  if (dryRun) {
    print('\n[DRY RUN] No se escribió en la BD local.');
    return counts;
  }

  await db.transaction((txn) async {
    await txn.execute('PRAGMA foreign_keys = OFF');
    for (final table in [
      'pagos',
      'cuotas',
      'creditos',
      'clientes',
      'vendedores',
      'productores',
      'counters',
    ]) {
      await txn.delete(table);
    }

    for (final row in productores) {
      await txn.insert('productores', {
        'id': row['id'],
        'nombre': row['nombre'],
        'nombre_dueno': row['nombre_dueno'],
        'telefono': row['telefono'],
        'email': row['email'],
        'direccion': row['direccion'],
        'rfc': row['rfc'],
        'notas': row['notas'],
        'created_at': row['created_at'],
      });
    }

    for (final row in vendedores) {
      await txn.insert('vendedores', {
        'id': row['id'],
        'nombre': row['nombre'],
        'tipo': row['tipo'],
        'telefono': row['telefono'],
        'email': row['email'],
        'direccion': row['direccion'],
        'porcentaje_comision': row['porcentaje_comision'] ?? 5,
        'productor_id': row['productor_id'],
        'promotor_id': row['promotor_id'],
        'activo': row['activo'] ?? 1,
        'notas': row['notas'],
        'created_at': row['created_at'],
      });
    }

    for (final row in clientes) {
      await txn.insert('clientes', {
        'id': row['id'],
        'nombre': row['nombre'],
        'telefono': row['telefono'],
        'direccion': row['direccion'],
        'vendedor_id': row['vendedor_id'],
        'codigo': row['codigo'],
        'notas': row['notas'],
        'created_at': row['created_at'],
      });
    }

    for (final row in creditos) {
      await txn.insert('creditos', {
        'id': row['id'],
        'folio': row['folio'],
        'numero_factura': row['numero_factura'],
        'cliente_id': row['cliente_id'],
        'cliente_nombre': row['cliente_nombre'],
        'cliente_codigo': row['cliente_codigo'],
        'cliente_telefono': row['cliente_telefono'],
        'cliente_direccion': row['cliente_direccion'],
        'descripcion': row['descripcion'],
        'monto_total': row['monto_total'],
        'monto_pagado': row['monto_pagado'] ?? 0,
        'fecha_venta': row['fecha_venta'],
        'fecha_vencimiento': row['fecha_vencimiento'],
        'num_cuotas': row['num_cuotas'] ?? 1,
        'estado': row['estado'] ?? 'pendiente',
        'vendedor_id': row['vendedor_id'],
        'productor_id': row['productor_id'],
        'notas': row['notas'],
        'created_at': row['created_at'],
      });
    }

    for (final row in cuotasAll) {
      await txn.insert('cuotas', {
        'id': row['id'],
        'credito_id': row['credito_id'],
        'numero': row['numero'],
        'monto': row['monto'],
        'monto_pagado': row['monto_pagado'] ?? 0,
        'fecha_vencimiento': row['fecha_vencimiento'],
        'estado': row['estado'] ?? 'pendiente',
      });
    }

    for (final row in pagosAll) {
      await txn.insert('pagos', {
        'id': row['id'],
        'credito_id': row['credito_id'],
        'monto': row['monto'],
        'fecha_pago': row['fecha_pago'],
        'metodo': row['metodo'] ?? 'efectivo',
        'notas': row['notas'],
        'cuota_id': row['cuota_id'],
        'created_at': row['created_at'],
      });
    }

    // Config empresa
    const configKeys = [
      'nombre_negocio',
      'direccion',
      'telefono',
      'impuesto_porcentaje',
      'aplica_impuesto',
      'ancho_ticket_mm',
    ];
    for (final key in configKeys) {
      if (config.containsKey(key)) {
        final val = config[key];
        await txn.insert('config', {
          'key': key,
          'value': val.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // Contadores derivados de datos migrados
    var maxClienteCodigo = 0;
    for (final row in clientes) {
      final codigo = int.tryParse('${row['codigo'] ?? ''}') ?? 0;
      if (codigo > maxClienteCodigo) maxClienteCodigo = codigo;
    }
    if (maxClienteCodigo > 0) {
      await txn.insert('counters', {
        'key': 'clientes',
        'count': maxClienteCodigo,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    var maxFactura = 0;
    for (final row in creditos) {
      final nf = int.tryParse('${row['numero_factura'] ?? ''}') ?? 0;
      if (nf > maxFactura) maxFactura = nf;
    }
    if (maxFactura > 0) {
      await txn.insert('counters', {
        'key': 'facturas',
        'count': maxFactura,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final folioByYear = <String, int>{};
    for (final row in creditos) {
      final folio = row['folio'] as String?;
      if (folio == null) continue;
      final parts = folio.split('-');
      if (parts.length == 3 && parts[0] == 'CR') {
        final year = parts[1];
        final num = int.tryParse(parts[2]) ?? 0;
        final key = 'creditos_$year';
        if (num > (folioByYear[key] ?? 0)) folioByYear[key] = num;
      }
    }
    for (final entry in folioByYear.entries) {
      await txn.insert('counters', {
        'key': entry.key,
        'count': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await txn.execute('PRAGMA foreign_keys = ON');
  });

  return counts;
}

Future<Map<String, int>> _verifyCounts(Database db) async {
  final tables = [
    'productores',
    'vendedores',
    'clientes',
    'creditos',
    'cuotas',
    'pagos',
    'config',
    'counters',
  ];
  final result = <String, int>{};
  for (final t in tables) {
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM $t');
    result[t] = rows.first['c'] as int;
  }
  return result;
}

void _printCounts(String label, Map<String, int> counts) {
  print('\n$label');
  for (final entry in counts.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
}

Future<void> main(List<String> args) async {
  var apiUrl = _defaultApiUrl;
  var dbPath = _defaultDbPath();
  var dryRun = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--api-url':
        apiUrl = args[++i];
      case '--db-path':
        dbPath = args[++i];
      case '--dry-run':
        dryRun = true;
      case '--help':
      case '-h':
        print('Uso: dart run tool/migrate_from_firebase.dart [opciones]');
        print('  --api-url URL    API REST (default: $_defaultApiUrl)');
        print('  --db-path PATH   Ruta al .db local');
        print('  --dry-run        Solo descarga y cuenta, sin escribir');
        exit(0);
    }
  }

  print('API: $apiUrl');
  print('BD local: $dbPath');
  if (dryRun) print('Modo: DRY RUN');

  if (!dryRun && !File(dbPath).existsSync()) {
    print('ERROR: No existe la BD en $dbPath');
    print('Abre la app Flutter al menos una vez para crear el archivo.');
    exit(1);
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Database? db;
  if (!dryRun) {
    db = await openDatabase(dbPath);
  }

  try {
    final imported = await _importAll(db ?? _FakeDb(), apiUrl, dryRun: dryRun);
    _printCounts('Registros migrados desde Firebase:', imported);

    if (!dryRun && db != null) {
      final verified = await _verifyCounts(db);
      _printCounts('Verificación en SQLite local:', verified);
      print('\nConfig empresa: ${await db.query('config')}');
    }

    print('\nMigración completada.');
  } catch (e, st) {
    print('ERROR: $e');
    print(st);
    exit(1);
  } finally {
    await db?.close();
  }
}

/// Stub para dry-run (no abre BD).
class _FakeDb implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
