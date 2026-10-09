import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String computeEstado(double montoTotal, double montoPagado) {
  if (montoPagado >= montoTotal - 0.01) return 'pagado';
  if (montoPagado > 0) return 'parcial';
  return 'pendiente';
}

double calcularComision(double monto, double porcentaje) {
  return ((monto * porcentaje / 100) * 100).round() / 100;
}

double calcularPrecioVenta(double costo, double margen) {
  return ((costo * (1 + margen / 100)) * 100).round() / 100;
}

List<Map<String, dynamic>>? parseItemsField(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) {
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }
  return null;
}

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  String? _ultimoUsuarioActivo;

  void setUsuarioActivoEnMemoria(String nombre) {
    _ultimoUsuarioActivo = nombre;
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'gestor_creditos.db');
    _db = await openDatabase(
      path,
      version: 10,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _seedConfigIfNeeded(_db!);
    await _seedAdminIfNeeded(_db!);
    await _seedCajaPrincipalIfNeeded(_db!);
    return _db!;
  }

  Future<void> _createUsuariosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        rol TEXT NOT NULL DEFAULT 'vendedor',
        vendedor_id TEXT,
        activo INTEGER DEFAULT 1,
        must_change_password INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
  }

  Future<void> _createProductoresTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        nombre_dueno TEXT,
        telefono TEXT,
        email TEXT,
        direccion TEXT,
        rfc TEXT,
        notas TEXT,
        created_at TEXT
      )
    ''');
  }

  Future<void> _createProductosTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        categoria TEXT,
        descripcion TEXT,
        presentacion TEXT DEFAULT 'individual',
        precio_costo REAL DEFAULT 0,
        margen_porcentaje REAL DEFAULT 0,
        precio_venta REAL DEFAULT 0,
        stock_actual REAL DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_inventario (
        id TEXT PRIMARY KEY,
        producto_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        cantidad REAL NOT NULL,
        fecha TEXT,
        referencia_credito_id TEXT,
        nota TEXT,
        created_at TEXT,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');
  }

  Future<void> _createCajaTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cajas (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        activa INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_sesiones (
        id TEXT PRIMARY KEY,
        caja_id TEXT NOT NULL,
        usuario_id TEXT,
        fecha_apertura TEXT,
        monto_apertura REAL DEFAULT 0,
        fecha_cierre TEXT,
        monto_cierre_contado REAL,
        monto_esperado REAL,
        diferencia REAL,
        estado TEXT DEFAULT 'abierta',
        notas TEXT,
        created_at TEXT,
        FOREIGN KEY (caja_id) REFERENCES cajas(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caja_movimientos (
        id TEXT PRIMARY KEY,
        sesion_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        referencia_credito_id TEXT,
        descripcion TEXT,
        fecha TEXT,
        usuario_id TEXT,
        created_at TEXT,
        FOREIGN KEY (sesion_id) REFERENCES caja_sesiones(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createAuditoriaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auditoria (
        id TEXT PRIMARY KEY,
        usuario_nombre TEXT NOT NULL,
        accion TEXT NOT NULL,
        detalles TEXT,
        fecha_hora TEXT NOT NULL
      )
    ''');
  }

  Future<void> registrarAuditoria({
    String? usuarioNombre,
    required String accion,
    String? detalles,
  }) async {
    try {
      final db = await database;
      final nombreFinal =
          usuarioNombre ?? _ultimoUsuarioActivo ?? 'Administrador';
      await db.insert('auditoria', {
        'id': _uuid.v4(),
        'usuario_nombre': nombreFinal,
        'accion': accion,
        'detalles': detalles,
        'fecha_hora': _now(),
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> listAuditoria({
    String? desde,
    String? hasta,
  }) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (desde != null &&
        desde.isNotEmpty &&
        hasta != null &&
        hasta.isNotEmpty) {
      where = 'fecha_hora >= ? AND fecha_hora <= ?';
      args = ['$desde 00:00:00', '$hasta 23:59:59'];
    }
    return db.query(
      'auditoria',
      where: where,
      whereArgs: args,
      orderBy: 'fecha_hora DESC',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createProductoresTable(db);
    }
    if (oldVersion < 3) {
      await _createProductosTables(db);
      await db.execute('ALTER TABLE creditos ADD COLUMN items TEXT');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE movimientos_inventario ADD COLUMN nota TEXT',
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE productos ADD COLUMN descripcion TEXT');
      await db.execute(
        "ALTER TABLE productos ADD COLUMN presentacion TEXT DEFAULT 'individual'",
      );
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE creditos ADD COLUMN abono REAL DEFAULT 0');
    }
    if (oldVersion < 7) {
      await _createUsuariosTable(db);
    }
    if (oldVersion < 8) {
      await _createCajaTables(db);
      await db.insert('config', {
        'key': 'modo_caja',
        'value': 'unica',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final cajas = await db.query('cajas', limit: 1);
      if (cajas.isEmpty) {
        await db.insert('cajas', {
          'id': _uuid.v4(),
          'nombre': 'Caja principal',
          'activa': 1,
          'created_at': _now(),
        });
      }
    }
    if (oldVersion < 9) {
      await db.insert('config', {
        'key': 'ancho_ticket_mm',
        'value': '80',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (oldVersion < 10) {
      await _createAuditoriaTable(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createProductoresTable(db);
    await _createProductosTables(db);
    await db.execute('''
      CREATE TABLE vendedores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        telefono TEXT,
        email TEXT,
        direccion TEXT,
        porcentaje_comision REAL DEFAULT 5,
        productor_id TEXT,
        promotor_id TEXT,
        activo INTEGER DEFAULT 1,
        notas TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE clientes (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        telefono TEXT,
        direccion TEXT,
        vendedor_id TEXT NOT NULL,
        codigo TEXT,
        notas TEXT,
        created_at TEXT,
        FOREIGN KEY (vendedor_id) REFERENCES vendedores(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE creditos (
        id TEXT PRIMARY KEY,
        folio TEXT,
        numero_factura TEXT,
        cliente_id TEXT,
        cliente_nombre TEXT,
        cliente_codigo TEXT,
        cliente_telefono TEXT,
        cliente_direccion TEXT,
        descripcion TEXT,
        monto_total REAL NOT NULL,
        monto_pagado REAL DEFAULT 0,
        abono REAL DEFAULT 0,
        fecha_venta TEXT,
        fecha_vencimiento TEXT,
        num_cuotas INTEGER DEFAULT 1,
        estado TEXT DEFAULT 'pendiente',
        vendedor_id TEXT,
        productor_id TEXT,
        notas TEXT,
        items TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE cuotas (
        id TEXT PRIMARY KEY,
        credito_id TEXT NOT NULL,
        numero INTEGER NOT NULL,
        monto REAL NOT NULL,
        monto_pagado REAL DEFAULT 0,
        fecha_vencimiento TEXT,
        estado TEXT DEFAULT 'pendiente',
        FOREIGN KEY (credito_id) REFERENCES creditos(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE pagos (
        id TEXT PRIMARY KEY,
        credito_id TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha_pago TEXT,
        metodo TEXT DEFAULT 'efectivo',
        notas TEXT,
        cuota_id TEXT,
        created_at TEXT,
        FOREIGN KEY (credito_id) REFERENCES creditos(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE counters (
        key TEXT PRIMARY KEY,
        count INTEGER DEFAULT 0
      )
    ''');
    await _createUsuariosTable(db);
    await _createCajaTables(db);
    await _createAuditoriaTable(db);
  }

  Future<void> _seedConfigIfNeeded(Database db) async {
    final rows = await db.query('config');
    if (rows.isEmpty) {
      await db.insert('config', {
        'key': 'nombre_negocio',
        'value': 'Bear Helados',
      });
      await db.insert('config', {'key': 'direccion', 'value': ''});
      await db.insert('config', {'key': 'telefono', 'value': ''});
      await db.insert('config', {'key': 'impuesto_porcentaje', 'value': '16'});
      await db.insert('config', {'key': 'aplica_impuesto', 'value': 'false'});
      await db.insert('config', {'key': 'ancho_ticket_mm', 'value': '80'});
      await db.insert('config', {'key': 'modo_caja', 'value': 'unica'});
      await db.insert('config', {'key': 'whatsapp_firma', 'value': ''});
      await db.insert('config', {'key': 'whatsapp_codigo_pais', 'value': '58'});
    }
  }

  Future<void> _seedCajaPrincipalIfNeeded(Database db) async {
    final rows = await db.query('cajas', limit: 1);
    if (rows.isEmpty) {
      await db.insert('cajas', {
        'id': _uuid.v4(),
        'nombre': 'Caja principal',
        'activa': 1,
        'created_at': _now(),
      });
    }
  }

  String _generarSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hashPassword(String password, String salt) {
    final digest = sha256.convert(utf8.encode('$salt$password'));
    return '$salt\$$digest';
  }

  String _crearPasswordHash(String password) =>
      _hashPassword(password, _generarSalt());

  bool _verificarPassword(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 2) return false;
    final salt = parts.first;
    return _hashPassword(password, salt) == stored;
  }

  Future<void> _seedAdminIfNeeded(Database db) async {
    final rows = await db.query('usuarios', limit: 1);
    if (rows.isNotEmpty) return;
    await db.insert('usuarios', {
      'id': _uuid.v4(),
      'nombre': 'Administrador',
      'username': 'admin',
      'password_hash': _crearPasswordHash('admin123'),
      'rol': 'admin',
      'vendedor_id': null,
      'activo': 1,
      'must_change_password': 1,
      'created_at': _now(),
    });
  }

  Map<String, dynamic> _sanitizeUsuario(Map<String, dynamic> row) {
    final u = Map<String, dynamic>.from(row);
    u.remove('password_hash');
    return u;
  }

  Future<List<Map<String, dynamic>>> listUsuarios() async {
    final db = await database;
    final rows = await db.query('usuarios', orderBy: 'rol, nombre');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final u = _sanitizeUsuario(row);
      if (row['vendedor_id'] != null) {
        final vend = await db.query(
          'vendedores',
          where: 'id = ?',
          whereArgs: [row['vendedor_id']],
        );
        u['vendedor_nombre'] = vend.isNotEmpty ? vend.first['nombre'] : null;
      }
      result.add(u);
    }
    return result;
  }

  Future<Map<String, dynamic>?> autenticar(
    String username,
    String password,
  ) async {
    final db = await database;
    final rows = await db.query(
      'usuarios',
      where: 'username = ?',
      whereArgs: [username.trim().toLowerCase()],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    if ((row['activo'] as int? ?? 1) == 0) return null;
    final stored = row['password_hash'] as String? ?? '';
    if (!_verificarPassword(password, stored)) return null;
    final u = _sanitizeUsuario(row);
    if (row['vendedor_id'] != null) {
      final vend = await db.query(
        'vendedores',
        where: 'id = ?',
        whereArgs: [row['vendedor_id']],
      );
      u['vendedor_nombre'] = vend.isNotEmpty ? vend.first['nombre'] : null;
    }

    final nombreReal = u['nombre'] as String? ?? username;
    setUsuarioActivoEnMemoria(nombreReal);

    await registrarAuditoria(
      usuarioNombre: nombreReal,
      accion: 'Inicio de sesión',
      detalles: 'El usuario inició sesión en el sistema',
    );

    return u;
  }

  Future<Map<String, dynamic>> createUsuario(Map<String, dynamic> body) async {
    final db = await database;
    final username = (body['username'] as String).trim().toLowerCase();
    if (username.isEmpty) throw Exception('El usuario es obligatorio');
    final password = (body['password'] as String? ?? '').trim();
    if (password.length < 4)
      throw Exception('La contraseña debe tener al menos 4 caracteres');
    final existing = await db.query(
      'usuarios',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (existing.isNotEmpty)
      throw Exception('Ya existe un usuario con ese nombre de usuario');
    final rol = (body['rol'] as String?) == 'admin' ? 'admin' : 'vendedor';
    final id = _uuid.v4();
    final data = {
      'id': id,
      'nombre': (body['nombre'] as String).trim(),
      'username': username,
      'password_hash': _crearPasswordHash(password),
      'rol': rol,
      'vendedor_id': rol == 'vendedor' ? body['vendedor_id'] : null,
      'activo': 1,
      'must_change_password': 0,
      'created_at': _now(),
    };
    await db.insert('usuarios', data);
    return _sanitizeUsuario(data);
  }

  Future<Map<String, dynamic>> updateUsuario(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final rol = (body['rol'] as String?) == 'admin' ? 'admin' : 'vendedor';
    final data = <String, dynamic>{
      'nombre': (body['nombre'] as String).trim(),
      'rol': rol,
      'vendedor_id': rol == 'vendedor' ? body['vendedor_id'] : null,
      if (body.containsKey('activo'))
        'activo': (body['activo'] == true || body['activo'] == 1) ? 1 : 0,
    };
    if (body.containsKey('username')) {
      final username = (body['username'] as String).trim().toLowerCase();
      final existing = await db.query(
        'usuarios',
        where: 'username = ? AND id != ?',
        whereArgs: [username, id],
      );
      if (existing.isNotEmpty)
        throw Exception('Ya existe un usuario con ese nombre de usuario');
      data['username'] = username;
    }
    final nueva = (body['password'] as String?)?.trim();
    if (nueva != null && nueva.isNotEmpty) {
      if (nueva.length < 4)
        throw Exception('La contraseña debe tener al menos 4 caracteres');
      data['password_hash'] = _crearPasswordHash(nueva);
      data['must_change_password'] = 0;
    }
    await db.update('usuarios', data, where: 'id = ?', whereArgs: [id]);
    final rows = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    return _sanitizeUsuario(rows.first);
  }

  Future<void> setUsuarioActivo(String id, bool activo) async {
    final db = await database;
    if (!activo) {
      final row = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
      if (row.isNotEmpty && row.first['rol'] == 'admin') {
        final admins = await db.query(
          'usuarios',
          where: "rol = 'admin' AND activo = 1",
        );
        if (admins.length <= 1) {
          throw Exception('Debe existir al menos un administrador activo');
        }
      }
    }
    await db.update(
      'usuarios',
      {'activo': activo ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> resetPassword(String id, String nueva) async {
    final db = await database;
    if (nueva.trim().length < 4)
      throw Exception('La contraseña debe tener al menos 4 caracteres');
    await db.update(
      'usuarios',
      {
        'password_hash': _crearPasswordHash(nueva.trim()),
        'must_change_password': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUsuario(String id) async {
    final db = await database;
    final row = await db.query('usuarios', where: 'id = ?', whereArgs: [id]);
    if (row.isNotEmpty && row.first['rol'] == 'admin') {
      final admins = await db.query(
        'usuarios',
        where: "rol = 'admin' AND activo = 1",
      );
      if (admins.length <= 1) {
        throw Exception('No se puede eliminar el único administrador activo');
      }
    }
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  String _now() => DateTime.now().toIso8601String();

  String? _cleanText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _cleanPresentacion(dynamic v) {
    final s = (v?.toString() ?? '').trim().toLowerCase();
    return s == 'combo' ? 'combo' : 'individual';
  }

  Future<int> _nextCounter(String key) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'counters',
        where: 'key = ?',
        whereArgs: [key],
      );
      final current = rows.isEmpty ? 0 : (rows.first['count'] as int? ?? 0);
      final value = current + 1;
      await txn.insert('counters', {
        'key': key,
        'count': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return value;
    });
  }

  Future<String> generarFolio() async {
    final year = DateTime.now().year;
    final next = await _nextCounter('creditos_$year');
    return 'CR-$year-${next.toString().padLeft(5, '0')}';
  }

  Future<String> generarNumeroFactura() async {
    final next = await _nextCounter('facturas');
    return next.toString().padLeft(10, '0');
  }

  Future<String> generarCodigoCliente() async {
    final next = await _nextCounter('clientes');
    return next.toString();
  }

  Future<String> get databasePath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'gestor_creditos.db');
  }

  Future<Map<String, dynamic>> getConfig() async {
    final db = await database;
    final rows = await db.query('config');
    final map = <String, dynamic>{
      'nombre_negocio': 'Bear Helados',
      'direccion': '',
      'telefono': '',
      'impuesto_porcentaje': 16,
      'aplica_impuesto': false,
      'ancho_ticket_mm': 80,
      'modo_caja': 'unica',
      'whatsapp_firma': '',
      'whatsapp_codigo_pais': '58',
      'tiene_clave_seguridad': false,
    };
    for (final r in rows) {
      final key = r['key'] as String;
      final val = r['value'] as String?;
      if (key == 'clave_seguridad_hash') {
        map['tiene_clave_seguridad'] = (val ?? '').isNotEmpty;
        continue;
      }
      if (key == 'impuesto_porcentaje' || key == 'ancho_ticket_mm') {
        map[key] = int.tryParse(val ?? '') ?? map[key];
      } else if (key == 'aplica_impuesto') {
        map[key] = val == 'true';
      } else {
        map[key] = val ?? '';
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> updateConfig(Map<String, dynamic> body) async {
    final db = await database;
    final allowed = [
      'nombre_negocio',
      'direccion',
      'telefono',
      'impuesto_porcentaje',
      'aplica_impuesto',
      'ancho_ticket_mm',
      'modo_caja',
      'whatsapp_firma',
      'whatsapp_codigo_pais',
    ];
    for (final key in allowed) {
      if (body.containsKey(key)) {
        final val = body[key];
        await db.insert('config', {
          'key': key,
          'value': val.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    if (body.containsKey('clave_seguridad')) {
      final plain = (body['clave_seguridad'] as String?)?.trim() ?? '';
      if (plain.isEmpty) {
        await db.delete(
          'config',
          where: 'key = ?',
          whereArgs: ['clave_seguridad_hash'],
        );
      } else {
        if (plain.length < 4) {
          throw Exception(
            'La clave de seguridad debe tener al menos 4 caracteres',
          );
        }
        await db.insert('config', {
          'key': 'clave_seguridad_hash',
          'value': _crearPasswordHash(plain),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    return getConfig();
  }

  Future<bool> verificarClaveSeguridad(String clave) async {
    final db = await database;
    final rows = await db.query(
      'config',
      where: 'key = ?',
      whereArgs: ['clave_seguridad_hash'],
    );
    final stored = rows.isEmpty ? null : rows.first['value'] as String?;
    if (stored == null || stored.isEmpty) {
      throw Exception(
        'No hay clave de seguridad configurada. El administrador debe definirla en Configuración.',
      );
    }
    return _verificarPassword(clave.trim(), stored);
  }

  Future<void> backupDatabase(String destPath) async {
    final db = await database;
    try {
      await db.execute('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
    final src = await databasePath;
    final srcFile = File(src);
    if (!await srcFile.exists()) {
      throw Exception('No se encontró el archivo de base de datos');
    }
    await srcFile.copy(destPath);
  }

  Future<void> resetDatosOperativos() async {
    final db = await database;
    await db.transaction((txn) async {
      final movs = await txn.query(
        'movimientos_inventario',
        where: "tipo = 'venta'",
      );
      for (final m in movs) {
        final pid = m['producto_id'] as String?;
        if (pid == null) continue;
        final qty = (m['cantidad'] as num?)?.toDouble() ?? 0;
        final prod = await txn.query(
          'productos',
          where: 'id = ?',
          whereArgs: [pid],
        );
        if (prod.isEmpty) continue;
        final current = (prod.first['stock_actual'] as num?)?.toDouble() ?? 0;
        await txn.update(
          'productos',
          {'stock_actual': current + qty},
          where: 'id = ?',
          whereArgs: [pid],
        );
      }

      await txn.delete('pagos');
      await txn.delete('cuotas');
      await txn.delete('creditos');
      await txn.delete('movimientos_inventario');
      await txn.delete('caja_movimientos');
      await txn.delete('caja_sesiones');

      final year = DateTime.now().year;
      await txn.delete(
        'counters',
        where: "key = 'facturas' OR key LIKE 'creditos_%'",
      );
      await txn.insert('counters', {
        'key': 'facturas',
        'count': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('counters', {
        'key': 'creditos_$year',
        'count': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, dynamic>>> listCajas({
    bool soloActivas = false,
  }) async {
    final db = await database;
    return db.query(
      'cajas',
      where: soloActivas ? 'activa = 1' : null,
      orderBy: 'created_at',
    );
  }

  Future<Map<String, dynamic>> createCaja(Map<String, dynamic> body) async {
    final db = await database;
    final nombre = (body['nombre'] as String? ?? '').trim();
    if (nombre.isEmpty) throw Exception('El nombre de la caja es obligatorio');
    final data = {
      'id': _uuid.v4(),
      'nombre': nombre,
      'activa': (body['activa'] == false || body['activa'] == 0) ? 0 : 1,
      'created_at': _now(),
    };
    await db.insert('cajas', data);
    return data;
  }

  Future<Map<String, dynamic>> updateCaja(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (body.containsKey('nombre')) {
      final nombre = (body['nombre'] as String).trim();
      if (nombre.isEmpty)
        throw Exception('El nombre de la caja es obligatorio');
      data['nombre'] = nombre;
    }
    if (body.containsKey('activa')) {
      data['activa'] = (body['activa'] == true || body['activa'] == 1) ? 1 : 0;
    }
    if (data.isNotEmpty) {
      await db.update('cajas', data, where: 'id = ?', whereArgs: [id]);
    }
    final rows = await db.query('cajas', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  Future<Map<String, dynamic>> _cajaPorDefecto(Database db) async {
    final activas = await db.query(
      'cajas',
      where: 'activa = 1',
      orderBy: 'created_at',
      limit: 1,
    );
    if (activas.isNotEmpty) return activas.first;
    final cualquiera = await db.query('cajas', orderBy: 'created_at', limit: 1);
    if (cualquiera.isNotEmpty) return cualquiera.first;
    final data = {
      'id': _uuid.v4(),
      'nombre': 'Caja principal',
      'activa': 1,
      'created_at': _now(),
    };
    await db.insert('cajas', data);
    return data;
  }

  Future<Map<String, dynamic>> _enrichSesion(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final s = Map<String, dynamic>.from(row);
    final caja = await db.query(
      'cajas',
      where: 'id = ?',
      whereArgs: [row['caja_id']],
    );
    s['caja_nombre'] = caja.isNotEmpty ? caja.first['nombre'] : 'Caja';
    if (row['usuario_id'] != null) {
      final u = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [row['usuario_id']],
      );
      s['usuario_nombre'] = u.isNotEmpty ? u.first['nombre'] : null;
    }
    return s;
  }

  Future<Map<String, dynamic>?> getSesionAbierta({
    String? usuarioId,
    String? cajaId,
  }) async {
    final db = await database;
    final where = StringBuffer("estado = 'abierta'");
    final args = <Object?>[];
    if (usuarioId != null) {
      where.write(' AND usuario_id = ?');
      args.add(usuarioId);
    }
    if (cajaId != null) {
      where.write(' AND caja_id = ?');
      args.add(cajaId);
    }
    final rows = await db.query(
      'caja_sesiones',
      where: where.toString(),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha_apertura DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _enrichSesion(db, rows.first);
  }

  Future<Map<String, dynamic>> abrirCaja({
    String? cajaId,
    String? usuarioId,
    required double montoApertura,
    String? notas,
  }) async {
    final db = await database;
    final caja = cajaId != null
        ? (await db.query(
                'cajas',
                where: 'id = ?',
                whereArgs: [cajaId],
              )).firstOrNull ??
              await _cajaPorDefecto(db)
        : await _cajaPorDefecto(db);
    final resolvedCajaId = caja['id'] as String;
    final abierta = await db.query(
      'caja_sesiones',
      where: "caja_id = ? AND estado = 'abierta'",
      whereArgs: [resolvedCajaId],
      limit: 1,
    );
    if (abierta.isNotEmpty) {
      throw Exception(
        'La caja "${caja['nombre']}" ya tiene una sesión abierta',
      );
    }
    final id = _uuid.v4();
    final data = {
      'id': id,
      'caja_id': resolvedCajaId,
      'usuario_id': usuarioId,
      'fecha_apertura': _now(),
      'monto_apertura': montoApertura < 0 ? 0 : montoApertura,
      'fecha_cierre': null,
      'monto_cierre_contado': null,
      'monto_esperado': null,
      'diferencia': null,
      'estado': 'abierta',
      'notas': _cleanText(notas),
      'created_at': _now(),
    };
    await db.insert('caja_sesiones', data);
    return _enrichSesion(db, data);
  }

  Future<void> registrarMovimientoCaja({
    required String sesionId,
    required String tipo,
    required double monto,
    String? referenciaCreditoId,
    String? descripcion,
    String? usuarioId,
    String? fecha,
  }) async {
    if (monto <= 0) return;
    if (!['venta', 'abono', 'entrada', 'salida'].contains(tipo)) {
      throw Exception('Tipo de movimiento de caja inválido');
    }
    final db = await database;
    final sesion = await db.query(
      'caja_sesiones',
      where: "id = ? AND estado = 'abierta'",
      whereArgs: [sesionId],
      limit: 1,
    );
    if (sesion.isEmpty) return;
    await db.insert('caja_movimientos', {
      'id': _uuid.v4(),
      'sesion_id': sesionId,
      'tipo': tipo,
      'monto': monto,
      'referencia_credito_id': referenciaCreditoId,
      'descripcion': _cleanText(descripcion),
      'fecha': fecha ?? _now(),
      'usuario_id': usuarioId,
      'created_at': _now(),
    });
  }

  Future<List<Map<String, dynamic>>> listMovimientosCaja(
    String sesionId,
  ) async {
    final db = await database;
    return db.query(
      'caja_movimientos',
      where: 'sesion_id = ?',
      whereArgs: [sesionId],
      orderBy: 'fecha DESC, created_at DESC',
    );
  }

  Future<Map<String, dynamic>> getResumenSesion(String sesionId) async {
    final db = await database;
    final sesionRows = await db.query(
      'caja_sesiones',
      where: 'id = ?',
      whereArgs: [sesionId],
      limit: 1,
    );
    if (sesionRows.isEmpty) {
      return {
        'monto_apertura': 0.0,
        'ventas': 0.0,
        'abonos': 0.0,
        'entradas': 0.0,
        'salidas': 0.0,
        'esperado': 0.0,
        'num_movimientos': 0,
      };
    }
    final sesion = sesionRows.first;
    final montoApertura = (sesion['monto_apertura'] as num?)?.toDouble() ?? 0;
    final movs = await db.query(
      'caja_movimientos',
      where: 'sesion_id = ?',
      whereArgs: [sesionId],
    );
    double ventas = 0, abonos = 0, entradas = 0, salidas = 0;
    for (final m in movs) {
      final monto = (m['monto'] as num?)?.toDouble() ?? 0;
      switch (m['tipo'] as String?) {
        case 'venta':
          ventas += monto;
          break;
        case 'abono':
          abonos += monto;
          break;
        case 'entrada':
          entradas += monto;
          break;
        case 'salida':
          salidas += monto;
          break;
      }
    }
    final esperado = montoApertura + ventas + abonos + entradas - salidas;
    return {
      'monto_apertura': montoApertura,
      'ventas': ventas,
      'abonos': abonos,
      'entradas': entradas,
      'salidas': salidas,
      'esperado': (esperado * 100).round() / 100,
      'num_movimientos': movs.length,
    };
  }

  Future<Map<String, dynamic>> cerrarCaja({
    required String sesionId,
    required double montoContado,
    String? notas,
  }) async {
    final db = await database;
    final sesionRows = await db.query(
      'caja_sesiones',
      where: 'id = ?',
      whereArgs: [sesionId],
      limit: 1,
    );
    if (sesionRows.isEmpty) throw Exception('Sesión de caja no encontrada');
    if (sesionRows.first['estado'] == 'cerrada')
      throw Exception('La sesión ya está cerrada');

    final resumen = await getResumenSesion(sesionId);
    final esperado = (resumen['esperado'] as num).toDouble();
    final diferencia = ((montoContado - esperado) * 100).round() / 100;

    await db.update(
      'caja_sesiones',
      {
        'fecha_cierre': _now(),
        'monto_cierre_contado': montoContado,
        'monto_esperado': esperado,
        'diferencia': diferencia,
        'estado': 'cerrada',
        if (_cleanText(notas) != null) 'notas': _cleanText(notas),
      },
      where: 'id = ?',
      whereArgs: [sesionId],
    );

    final updated = (await db.query(
      'caja_sesiones',
      where: 'id = ?',
      whereArgs: [sesionId],
    )).first;
    final enriched = await _enrichSesion(db, updated);
    enriched['resumen'] = resumen;
    return enriched;
  }

  Future<List<Map<String, dynamic>>> listSesionesCerradas({
    String? usuarioId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'caja_sesiones',
      where: usuarioId != null
          ? "estado = 'cerrada' AND usuario_id = ?"
          : "estado = 'cerrada'",
      whereArgs: usuarioId != null ? [usuarioId] : null,
      orderBy: 'fecha_cierre DESC',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      result.add(await _enrichSesion(db, row));
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> listProductores() async {
    final db = await database;
    return db.query('productores', orderBy: 'nombre');
  }

  Future<Map<String, dynamic>> createProductor(
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final id = _uuid.v4();
    final data = {
      'id': id,
      'nombre': (body['nombre'] as String).trim(),
      'nombre_dueno': body['nombre_dueno'],
      'telefono': body['telefono'],
      'email': body['email'],
      'direccion': body['direccion'],
      'rfc': body['rfc'],
      'notas': body['notas'],
      'created_at': _now(),
    };
    await db.insert('productores', data);
    return data;
  }

  Future<Map<String, dynamic>> updateProductor(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    await db.update(
      'productores',
      {
        'nombre': body['nombre'],
        'nombre_dueno': body['nombre_dueno'],
        'telefono': body['telefono'],
        'email': body['email'],
        'direccion': body['direccion'],
        'rfc': body['rfc'],
        'notas': body['notas'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query(
      'productores',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.first;
  }

  Future<void> deleteProductor(String id) async {
    final db = await database;
    final vendedores = await db.query(
      'vendedores',
      where: 'productor_id = ?',
      whereArgs: [id],
    );
    if (vendedores.isNotEmpty) {
      throw Exception(
        'No se puede eliminar: tiene ${vendedores.length} vendedor(es) asignado(s)',
      );
    }
    await db.delete('productores', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listVendedores({
    String? tipo,
    String? promotorId,
    String? productorId,
  }) async {
    final db = await database;
    String? where;
    List<Object?>? args;
    if (tipo != null) {
      where = 'tipo = ?';
      args = [tipo];
    }
    if (promotorId != null) {
      where = where == null ? 'promotor_id = ?' : '$where AND promotor_id = ?';
      args = [...?args, promotorId];
    }
    if (productorId != null) {
      where = where == null
          ? 'productor_id = ?'
          : '$where AND productor_id = ?';
      args = [...?args, productorId];
    }
    final rows = await db.query(
      'vendedores',
      where: where,
      whereArgs: args,
      orderBy: 'nombre',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final enriched = Map<String, dynamic>.from(row);
      if (row['promotor_id'] != null) {
        final prom = await db.query(
          'vendedores',
          where: 'id = ?',
          whereArgs: [row['promotor_id']],
        );
        enriched['promotor_nombre'] = prom.isNotEmpty
            ? prom.first['nombre']
            : null;
      }
      if (row['productor_id'] != null) {
        final prod = await db.query(
          'productores',
          where: 'id = ?',
          whereArgs: [row['productor_id']],
        );
        enriched['productor_nombre'] = prod.isNotEmpty
            ? prod.first['nombre']
            : null;
      }
      result.add(enriched);
    }
    return result;
  }

  Future<Map<String, dynamic>> createVendedor(Map<String, dynamic> body) async {
    final db = await database;
    final id = _uuid.v4();
    final data = {
      'id': id,
      'nombre': (body['nombre'] as String).trim(),
      'tipo': body['tipo'],
      'telefono': body['telefono'],
      'email': body['email'],
      'direccion': body['direccion'],
      'porcentaje_comision': body['porcentaje_comision'] ?? 5.0,
      'productor_id': body['productor_id'],
      'promotor_id': body['tipo'] == 'vendedor' ? body['promotor_id'] : null,
      'activo': 1,
      'notas': body['notas'],
      'created_at': _now(),
    };
    await db.insert('vendedores', data);
    return data;
  }

  Future<Map<String, dynamic>> updateVendedor(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final data = {
      'nombre': body['nombre'],
      'tipo': body['tipo'],
      'telefono': body['telefono'],
      'email': body['email'],
      'direccion': body['direccion'],
      'porcentaje_comision': body['porcentaje_comision'],
      'productor_id': body['productor_id'],
      'promotor_id': body['tipo'] == 'vendedor' ? body['promotor_id'] : null,
      'activo': body['activo'] ?? 1,
      'notas': body['notas'],
    };
    await db.update('vendedores', data, where: 'id = ?', whereArgs: [id]);
    final rows = await db.query('vendedores', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  Future<void> deleteVendedor(String id) async {
    final db = await database;
    final clientes = await db.query(
      'clientes',
      where: 'vendedor_id = ?',
      whereArgs: [id],
    );
    if (clientes.isNotEmpty) {
      throw Exception(
        'No se puede eliminar: tiene ${clientes.length} cliente(s) asignado(s)',
      );
    }
    final creditos = await db.query(
      'creditos',
      where: 'vendedor_id = ?',
      whereArgs: [id],
    );
    if (creditos.isNotEmpty) {
      throw Exception(
        'No se puede eliminar: tiene ${creditos.length} venta(s) registrada(s)',
      );
    }
    await db.delete('vendedores', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listClientes({String? vendedorId}) async {
    final db = await database;
    final rows = await db.query(
      'clientes',
      where: vendedorId != null ? 'vendedor_id = ?' : null,
      whereArgs: vendedorId != null ? [vendedorId] : null,
      orderBy: 'nombre',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final enriched = Map<String, dynamic>.from(row);
      final vend = await db.query(
        'vendedores',
        where: 'id = ?',
        whereArgs: [row['vendedor_id']],
      );
      enriched['vendedor_nombre'] = vend.isNotEmpty
          ? vend.first['nombre']
          : null;
      result.add(enriched);
    }
    return result;
  }

  Future<Map<String, dynamic>> createCliente(Map<String, dynamic> body) async {
    final db = await database;
    final id = _uuid.v4();
    final codigo = await generarCodigoCliente();
    final data = {
      'id': id,
      'nombre': (body['nombre'] as String).trim(),
      'telefono': body['telefono'],
      'direccion': body['direccion'],
      'vendedor_id': body['vendedor_id'],
      'codigo': codigo,
      'notas': body['notas'],
      'created_at': _now(),
    };
    await db.insert('clientes', data);

    await registrarAuditoria(
      accion: 'Crear cliente',
      detalles: 'Se creó el cliente ${data['nombre']}',
    );

    final vend = await db.query(
      'vendedores',
      where: 'id = ?',
      whereArgs: [body['vendedor_id']],
    );
    return {
      ...data,
      'vendedor_nombre': vend.isNotEmpty ? vend.first['nombre'] : null,
    };
  }

  Future<Map<String, dynamic>> updateCliente(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    await db.update(
      'clientes',
      {
        'nombre': body['nombre'],
        'telefono': body['telefono'],
        'direccion': body['direccion'],
        'vendedor_id': body['vendedor_id'],
        'notas': body['notas'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await registrarAuditoria(
      accion: 'Editar cliente',
      detalles: 'Se actualizó el cliente ${body['nombre']}',
    );

    final rows = await listClientes();
    return rows.firstWhere((c) => c['id'] == id);
  }

  Future<void> deleteCliente(String id) async {
    final db = await database;
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);

    await registrarAuditoria(
      accion: 'Eliminar cliente',
      detalles: 'Se eliminó el cliente ID $id',
    );
  }

  Future<List<Map<String, dynamic>>> listProductos({String? search}) async {
    final db = await database;
    final rows = await db.query('productos', orderBy: 'nombre');
    if (search == null || search.trim().isEmpty) return rows;
    final q = search.trim().toLowerCase();
    return rows.where((p) {
      final nombre = (p['nombre'] as String? ?? '').toLowerCase();
      final cat = (p['categoria'] as String? ?? '').toLowerCase();
      return nombre.contains(q) || cat.contains(q);
    }).toList();
  }

  Future<Map<String, dynamic>?> getProducto(String id) async {
    final db = await database;
    final rows = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>> createProducto(Map<String, dynamic> body) async {
    final db = await database;
    final costo = (body['precio_costo'] as num?)?.toDouble() ?? 0;
    final margen = (body['margen_porcentaje'] as num?)?.toDouble() ?? 0;
    final precioVenta = body.containsKey('precio_venta')
        ? (body['precio_venta'] as num).toDouble()
        : calcularPrecioVenta(costo, margen);
    final stockInicial = (body['stock_inicial'] as num?)?.toDouble() ?? 0;
    if (stockInicial < 0) throw Exception('Stock inicial inválido');
    final id = _uuid.v4();
    final data = {
      'id': id,
      'nombre': (body['nombre'] as String).trim(),
      'categoria': body['categoria'],
      'descripcion': _cleanText(body['descripcion']),
      'presentacion': _cleanPresentacion(body['presentacion']),
      'precio_costo': costo,
      'margen_porcentaje': margen,
      'precio_venta': precioVenta,
      'stock_actual': stockInicial > 0 ? stockInicial : 0,
      'created_at': _now(),
    };
    await db.transaction((txn) async {
      await txn.insert('productos', data);
      if (stockInicial > 0) {
        await txn.insert('movimientos_inventario', {
          'id': _uuid.v4(),
          'producto_id': id,
          'tipo': 'entrada',
          'cantidad': stockInicial,
          'fecha': _now().split('T').first,
          'referencia_credito_id': null,
          'nota': 'Stock inicial',
          'created_at': _now(),
        });
      }
    });
    return data;
  }

  Future<Map<String, dynamic>> updateProducto(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final costo = (body['precio_costo'] as num?)?.toDouble() ?? 0;
    final margen = (body['margen_porcentaje'] as num?)?.toDouble() ?? 0;
    final precioVenta = body.containsKey('precio_venta')
        ? (body['precio_venta'] as num).toDouble()
        : calcularPrecioVenta(costo, margen);
    await db.update(
      'productos',
      {
        'nombre': (body['nombre'] as String).trim(),
        'categoria': body['categoria'],
        'descripcion': _cleanText(body['descripcion']),
        'presentacion': _cleanPresentacion(body['presentacion']),
        'precio_costo': costo,
        'margen_porcentaje': margen,
        'precio_venta': precioVenta,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query('productos', where: 'id = ?', whereArgs: [id]);
    return rows.first;
  }

  Future<void> deleteProducto(String id) async {
    final db = await database;
    final movs = await db.query(
      'movimientos_inventario',
      where: 'producto_id = ?',
      whereArgs: [id],
    );
    if (movs.isNotEmpty) {
      throw Exception('No se puede eliminar: tiene movimientos de inventario');
    }
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> listMovimientosInventario({
    String? productoId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'movimientos_inventario',
      where: productoId != null ? 'producto_id = ?' : null,
      whereArgs: productoId != null ? [productoId] : null,
      orderBy: 'fecha DESC, created_at DESC',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final enriched = Map<String, dynamic>.from(row);
      final prod = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [row['producto_id']],
      );
      enriched['producto_nombre'] = prod.isNotEmpty
          ? prod.first['nombre']
          : null;
      result.add(enriched);
    }
    return result;
  }

  Future<void> registrarMovimientoInventario({
    required String productoId,
    required String tipo,
    required double cantidad,
    String? fecha,
    String? referenciaCreditoId,
  }) async {
    if (cantidad <= 0) throw Exception('Cantidad inválida');
    if (!['entrada', 'salida', 'venta'].contains(tipo)) {
      throw Exception('Tipo de movimiento inválido');
    }
    final db = await database;
    await db.transaction((txn) async {
      final prod = await txn.query(
        'productos',
        where: 'id = ?',
        whereArgs: [productoId],
      );
      if (prod.isEmpty) throw Exception('Producto no encontrado');
      final currentStock =
          (prod.first['stock_actual'] as num?)?.toDouble() ?? 0;
      final delta = tipo == 'entrada' ? cantidad : -cantidad;
      final nuevoStock = currentStock + delta;
      if (nuevoStock < 0) {
        throw Exception('Stock insuficiente (disponible: $currentStock)');
      }
      await txn.update(
        'productos',
        {'stock_actual': nuevoStock},
        where: 'id = ?',
        whereArgs: [productoId],
      );
      await txn.insert('movimientos_inventario', {
        'id': _uuid.v4(),
        'producto_id': productoId,
        'tipo': tipo,
        'cantidad': cantidad,
        'fecha': fecha ?? _now().split('T').first,
        'referencia_credito_id': referenciaCreditoId,
        'created_at': _now(),
      });
    });
  }

  List<Map<String, dynamic>> _normalizeItems(
    List? items,
    double montoTotal,
    String descripcion,
  ) {
    if (items != null && items.isNotEmpty) {
      return items.map((i) {
        final m = Map<String, dynamic>.from(i as Map);
        final detalle = (m['detalle'] as String?)?.trim();
        final cantidad = ((m['cantidad'] as num?)?.round() ?? 1);
        return {
          if (m['producto_id'] != null) 'producto_id': m['producto_id'],
          'descripcion': (m['descripcion'] as String? ?? 'Producto').trim(),
          if (detalle != null && detalle.isNotEmpty) 'detalle': detalle,
          'cantidad': cantidad < 1 ? 1 : cantidad,
          'precio_unitario': (m['precio_unitario'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
    }
    return [
      {
        'descripcion': descripcion.trim().isEmpty
            ? 'Venta a crédito'
            : descripcion.trim(),
        'cantidad': 1,
        'precio_unitario': montoTotal,
      },
    ];
  }

  Map<String, dynamic> _withParsedItems(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    final items = parseItemsField(data['items']);
    if (items != null) data['items'] = items;
    return data;
  }

  Future<List<Map<String, dynamic>>> getCuotas(String creditoId) async {
    final db = await database;
    return db.query(
      'cuotas',
      where: 'credito_id = ?',
      whereArgs: [creditoId],
      orderBy: 'numero',
    );
  }

  Future<List<Map<String, dynamic>>> listCreditosVencidos() async {
    final db = await database;
    final hoy = DateTime.now().toIso8601String().split('T').first;

    final rows = await db.query(
      'creditos',
      where: "estado != ? AND fecha_vencimiento < ?",
      whereArgs: ['pagado', hoy],
      orderBy: 'fecha_vencimiento ASC',
    );

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final enriched = await enrichCredito(row);
      if (enriched != null) result.add(enriched);
    }
    return result;
  }

  Future<Map<String, dynamic>?> enrichCredito(Map<String, dynamic> data) async {
    final db = await database;
    final parsed = _withParsedItems(data);
    final vendedor = data['vendedor_id'] != null
        ? (await db.query(
            'vendedores',
            where: 'id = ?',
            whereArgs: [data['vendedor_id']],
          )).firstOrNull
        : null;
    final productor = data['productor_id'] != null
        ? (await db.query(
            'productores',
            where: 'id = ?',
            whereArgs: [data['productor_id']],
          )).firstOrNull
        : null;
    Map<String, dynamic>? promotor;
    if (vendedor?['promotor_id'] != null) {
      promotor = (await db.query(
        'vendedores',
        where: 'id = ?',
        whereArgs: [vendedor!['promotor_id']],
      )).firstOrNull;
    }
    final montoPagado = (data['monto_pagado'] as num?)?.toDouble() ?? 0;
    final montoTotal = (data['monto_total'] as num).toDouble();
    final saldo = (montoTotal - montoPagado).clamp(0.0, double.infinity);
    final porcentaje =
        (vendedor?['porcentaje_comision'] as num?)?.toDouble() ?? 0;
    return {
      ...parsed,
      'vendedor_nombre': vendedor?['nombre'],
      'vendedor_tipo': vendedor?['tipo'],
      'vendedor_comision': porcentaje,
      'promotor_id': promotor?['id'],
      'promotor_nombre': promotor?['nombre'],
      'productor_nombre': productor?['nombre'],
      'productor_dueno': productor?['nombre_dueno'],
      'saldo': saldo,
      'comision_venta': calcularComision(montoTotal, porcentaje),
      'comision_cobrada': calcularComision(montoPagado, porcentaje),
      'comision_pendiente': calcularComision(saldo, porcentaje),
    };
  }

  Future<List<Map<String, dynamic>>> listCreditos({
    String? estado,
    String? vendedorId,
  }) async {
    final db = await database;
    String? where;
    List<Object?>? args = [];
    if (estado != null) {
      where = 'estado = ?';
      args.add(estado);
    }
    if (vendedorId != null) {
      where = where == null ? 'vendedor_id = ?' : '$where AND vendedor_id = ?';
      args.add(vendedorId);
    }
    final rows = await db.query(
      'creditos',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'fecha_vencimiento',
    );
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final enriched = await enrichCredito(row);
      if (enriched != null) result.add(enriched);
    }
    return result;
  }

  Future<Map<String, dynamic>?> getCredito(String id) async {
    final db = await database;
    final rows = await db.query('creditos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final credito = await enrichCredito(rows.first);
    if (credito == null) return null;
    credito['cuotas'] = await getCuotas(id);
    credito['pagos'] = await db.query(
      'pagos',
      where: 'credito_id = ?',
      whereArgs: [id],
      orderBy: 'fecha_pago DESC',
    );
    return credito;
  }

  Future<Map<String, dynamic>> createCredito(
    Map<String, dynamic> body, {
    String? cajaSesionId,
  }) async {
    final db = await database;
    final clienteId = body['cliente_id'] as String?;
    if (clienteId == null)
      throw Exception('Debe seleccionar un cliente registrado');

    final clientes = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [clienteId],
    );
    if (clientes.isEmpty) throw Exception('Cliente no encontrado');
    final cliente = clientes.first;

    final montoTotal = (body['monto_total'] as num).toDouble();
    if (montoTotal <= 0) throw Exception('Monto inválido');

    final abono = ((body['abono'] as num?)?.toDouble() ?? 0).clamp(
      0.0,
      montoTotal,
    );

    final descripcion = body['descripcion'] as String? ?? 'Venta a crédito';
    final rawItems = body['items'] as List?;
    final lineItems = _normalizeItems(rawItems, montoTotal, descripcion);

    for (final item in lineItems) {
      final productoId = item['producto_id'] as String?;
      if (productoId == null) continue;
      final prodRows = await db.query(
        'productos',
        where: 'id = ?',
        whereArgs: [productoId],
      );
      if (prodRows.isEmpty)
        throw Exception('Producto no encontrado: ${item['descripcion']}');
      final stock = (prodRows.first['stock_actual'] as num?)?.toDouble() ?? 0;
      final qty = (item['cantidad'] as num).toDouble();
      if (stock < qty) {
        throw Exception(
          'Stock insuficiente para "${prodRows.first['nombre']}": disponible ${stock.toStringAsFixed(0)}, solicitado ${qty.toStringAsFixed(0)}',
        );
      }
    }

    List<Map<String, dynamic>> cuotas = [];
    if (body['cuotas'] is List) {
      cuotas = (body['cuotas'] as List).cast<Map<String, dynamic>>();
    }
    if (cuotas.isEmpty) {
      final fv = body['fecha_vencimiento'] as String?;
      if (fv == null) throw Exception('Fecha de vencimiento obligatoria');
      cuotas = [
        {'monto': montoTotal, 'fecha_vencimiento': fv},
      ];
    }

    final sumCuotas = cuotas.fold<double>(
      0,
      (s, c) => s + (c['monto'] as num).toDouble(),
    );
    if ((sumCuotas - montoTotal).abs() > 0.02) {
      throw Exception('La suma de cuotas no coincide con el total');
    }

    final id = _uuid.v4();
    final folio = await generarFolio();
    final numeroFactura = await generarNumeroFactura();
    final fechas = cuotas.map((c) => c['fecha_vencimiento'] as String).toList()
      ..sort();
    final descFinal = descripcion.trim().isEmpty
        ? lineItems.map((i) => i['descripcion']).join(', ')
        : descripcion.trim();
    final itemsJson = jsonEncode(lineItems);

    await db.transaction((txn) async {
      await txn.insert('creditos', {
        'id': id,
        'folio': folio,
        'numero_factura': numeroFactura,
        'cliente_id': clienteId,
        'cliente_nombre': cliente['nombre'],
        'cliente_codigo': cliente['codigo'],
        'cliente_telefono': cliente['telefono'],
        'cliente_direccion': cliente['direccion'],
        'descripcion': descFinal,
        'items': itemsJson,
        'monto_total': montoTotal,
        'monto_pagado': 0,
        'abono': abono,
        'fecha_venta': body['fecha_venta'] ?? _now().split('T').first,
        'fecha_vencimiento': fechas.last,
        'num_cuotas': cuotas.length,
        'estado': 'pendiente',
        'vendedor_id': cliente['vendedor_id'],
        'productor_id': body['productor_id'],
        'notas': body['notas'],
        'created_at': _now(),
      });
      for (var i = 0; i < cuotas.length; i++) {
        final c = cuotas[i];
        await txn.insert('cuotas', {
          'id': _uuid.v4(),
          'credito_id': id,
          'numero': i + 1,
          'monto': c['monto'],
          'monto_pagado': 0,
          'fecha_vencimiento': c['fecha_vencimiento'],
          'estado': 'pendiente',
        });
      }

      for (final item in lineItems) {
        final productoId = item['producto_id'] as String?;
        if (productoId == null) continue;
        final qty = (item['cantidad'] as num).toDouble();
        final prod = await txn.query(
          'productos',
          where: 'id = ?',
          whereArgs: [productoId],
        );
        final currentStock =
            (prod.first['stock_actual'] as num?)?.toDouble() ?? 0;
        await txn.update(
          'productos',
          {'stock_actual': currentStock - qty},
          where: 'id = ?',
          whereArgs: [productoId],
        );
        await txn.insert('movimientos_inventario', {
          'id': _uuid.v4(),
          'producto_id': productoId,
          'tipo': 'venta',
          'cantidad': qty,
          'fecha': body['fecha_venta'] ?? _now().split('T').first,
          'referencia_credito_id': id,
          'created_at': _now(),
        });
      }
    });

    if (abono > 0) {
      await createPago(id, {
        'monto': abono,
        'fecha_pago': body['fecha_venta'] ?? _now().split('T').first,
        'metodo': body['abono_metodo'] ?? 'efectivo',
        'notas': 'Abono inicial',
        'caja_mov_tipo': 'venta',
        'usuario_id': body['usuario_id'],
      }, cajaSesionId: cajaSesionId);
    }

    await registrarAuditoria(
      accion: 'Crear venta',
      detalles: 'Se registró la venta $folio por monto de $montoTotal',
    );

    return (await getCredito(id))!;
  }

  Future<Map<String, dynamic>> updateCredito(
    String id,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    final rows = await db.query('creditos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw Exception('Venta no encontrada');

    final data = <String, dynamic>{};
    if (body.containsKey('descripcion')) {
      data['descripcion'] = (body['descripcion'] as String?)?.trim() ?? '';
    }
    if (body.containsKey('notas')) {
      data['notas'] = (body['notas'] as String?)?.trim();
    }
    if (data.isEmpty) return (await getCredito(id))!;

    await db.update('creditos', data, where: 'id = ?', whereArgs: [id]);

    await registrarAuditoria(
      accion: 'Editar venta',
      detalles: 'Se actualizó la venta ${rows.first['folio']}',
    );

    return (await getCredito(id))!;
  }

  Future<void> deleteCredito(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'creditos',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw Exception('Venta no encontrada');
      final folio = rows.first['folio'];

      final movs = await txn.query(
        'movimientos_inventario',
        where: "referencia_credito_id = ? AND tipo = 'venta'",
        whereArgs: [id],
      );
      for (final m in movs) {
        final pid = m['producto_id'] as String?;
        if (pid == null) continue;
        final qty = (m['cantidad'] as num?)?.toDouble() ?? 0;
        final prod = await txn.query(
          'productos',
          where: 'id = ?',
          whereArgs: [pid],
        );
        if (prod.isEmpty) continue;
        final current = (prod.first['stock_actual'] as num?)?.toDouble() ?? 0;
        await txn.update(
          'productos',
          {'stock_actual': current + qty},
          where: 'id = ?',
          whereArgs: [pid],
        );
      }

      await txn.delete(
        'movimientos_inventario',
        where: 'referencia_credito_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'caja_movimientos',
        where: 'referencia_credito_id = ?',
        whereArgs: [id],
      );
      await txn.delete('pagos', where: 'credito_id = ?', whereArgs: [id]);
      await txn.delete('cuotas', where: 'credito_id = ?', whereArgs: [id]);
      await txn.delete('creditos', where: 'id = ?', whereArgs: [id]);

      await registrarAuditoria(
        accion: 'Eliminar venta',
        detalles: 'Se eliminó la venta $folio',
      );
    });
  }

  Future<Map<String, dynamic>> createPago(
    String creditoId,
    Map<String, dynamic> body, {
    String? cajaSesionId,
  }) async {
    final db = await database;
    final creditoRows = await db.query(
      'creditos',
      where: 'id = ?',
      whereArgs: [creditoId],
    );
    if (creditoRows.isEmpty) throw Exception('Crédito no encontrado');

    final credito = creditoRows.first;
    final monto = (body['monto'] as num).toDouble();
    final montoTotal = (credito['monto_total'] as num).toDouble();
    final montoPagadoActual =
        (credito['monto_pagado'] as num?)?.toDouble() ?? 0;
    final saldo = montoTotal - montoPagadoActual;
    if (monto > saldo + 0.01)
      throw Exception(
        'El pago excede el saldo (\$${saldo.toStringAsFixed(2)})',
      );

    final cuotaId = body['cuota_id'] as String?;
    final cuotas = await getCuotas(creditoId);
    final pagoId = _uuid.v4();

    await db.transaction((txn) async {
      var restante = monto;
      final cuotasActualizadas = cuotas
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

      Iterable<Map<String, dynamic>> targetCuotas;
      if (cuotaId != null) {
        targetCuotas = cuotas.where((c) => c['id'] == cuotaId);
      } else {
        targetCuotas = cuotas;
      }

      for (final c in targetCuotas) {
        if (restante <= 0) break;
        final cMonto = (c['monto'] as num).toDouble();
        final cPagado = (c['monto_pagado'] as num?)?.toDouble() ?? 0;
        final cSaldo = cMonto - cPagado;
        if (cSaldo <= 0) continue;
        final aplicar = restante < cSaldo ? restante : cSaldo;
        final nuevoPagado = cPagado + aplicar;
        await txn.update(
          'cuotas',
          {
            'monto_pagado': nuevoPagado,
            'estado': computeEstado(cMonto, nuevoPagado),
          },
          where: 'id = ?',
          whereArgs: [c['id']],
        );
        final idx = cuotasActualizadas.indexWhere((x) => x['id'] == c['id']);
        if (idx >= 0) {
          cuotasActualizadas[idx]['monto_pagado'] = nuevoPagado;
          cuotasActualizadas[idx]['estado'] = computeEstado(
            cMonto,
            nuevoPagado,
          );
        }
        restante -= aplicar;
      }

      final nuevoPagadoCredito = (montoPagadoActual + monto)
          .clamp(0, montoTotal)
          .toDouble();
      final estado = computeEstado(montoTotal, nuevoPagadoCredito);
      final pendientes = cuotasActualizadas
          .where((c) => c['estado'] != 'pagado')
          .toList();
      pendientes.sort(
        (a, b) => (a['fecha_vencimiento'] as String).compareTo(
          b['fecha_vencimiento'] as String,
        ),
      );
      final fechaVenc = pendientes.isNotEmpty
          ? pendientes.first['fecha_vencimiento']
          : cuotasActualizadas.last['fecha_vencimiento'];

      await txn.insert('pagos', {
        'id': pagoId,
        'credito_id': creditoId,
        'monto': monto,
        'fecha_pago': body['fecha_pago'] ?? _now().split('T').first,
        'metodo': body['metodo'] ?? 'efectivo',
        'notas': body['notas'],
        'cuota_id': cuotaId,
        'created_at': _now(),
      });
      await txn.update(
        'creditos',
        {
          'monto_pagado': nuevoPagadoCredito,
          'estado': estado,
          'fecha_vencimiento': fechaVenc,
        },
        where: 'id = ?',
        whereArgs: [creditoId],
      );
    });

    final metodo = (body['metodo'] as String?) ?? 'efectivo';
    if (cajaSesionId != null && metodo == 'efectivo') {
      final tipo = (body['caja_mov_tipo'] as String?) ?? 'abono';
      final credito = creditoRows.first;
      await registrarMovimientoCaja(
        sesionId: cajaSesionId,
        tipo: tipo,
        monto: monto,
        referenciaCreditoId: creditoId,
        descripcion: tipo == 'venta'
            ? 'Venta ${credito['folio'] ?? ''}'.trim()
            : 'Abono ${credito['folio'] ?? ''}'.trim(),
        usuarioId: body['usuario_id'] as String?,
        fecha: body['fecha_pago'] as String?,
      );
    }

    await registrarAuditoria(
      accion: 'Registrar pago',
      detalles: 'Se registró un pago de $monto a la venta ${credito['folio']}',
    );

    final pagos = await db.query('pagos', where: 'id = ?', whereArgs: [pagoId]);
    return pagos.first;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, String>? _getDateRange(String periodo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (periodo == 'hoy') {
      final s = _formatDate(today);
      return {'desde': s, 'hasta': s, 'label': 'Hoy'};
    }
    if (periodo == 'manana') {
      final tomorrow = today.add(const Duration(days: 1));
      final s = _formatDate(tomorrow);
      return {'desde': s, 'hasta': s, 'label': 'Mañana'};
    }
    if (periodo == 'semanal') {
      final day = today.weekday;
      final start = today.subtract(Duration(days: day - 1));
      final end = start.add(const Duration(days: 6));
      return {
        'desde': _formatDate(start),
        'hasta': _formatDate(end),
        'label': 'Esta semana',
      };
    }
    return null;
  }

  Map<String, double> _sumTotales(List<Map<String, dynamic>> creditos) {
    double sum(String key) =>
        creditos.fold(0.0, (s, c) => s + ((c[key] as num?)?.toDouble() ?? 0));
    return {
      'ventas': sum('monto_total'),
      'cobrado': sum('monto_pagado'),
      'saldo': sum('saldo'),
      'comision_venta': sum('comision_venta'),
      'comision_cobrada': sum('comision_cobrada'),
      'comision_pendiente': sum('comision_pendiente'),
    };
  }

  Future<Map<String, dynamic>> buildReporte({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
    String? promotorId,
  }) async {
    var range = periodo != null ? _getDateRange(periodo) : null;
    if (range == null && desde != null && hasta != null) {
      range = {'desde': desde, 'hasta': hasta, 'label': 'Personalizado'};
    }
    if (range == null) {
      throw Exception(
        'Indica periodo (hoy|manana|semanal) o rango desde/hasta',
      );
    }

    var creditos = await listCreditos();
    if (vendedorId != null) {
      creditos = creditos.where((c) => c['vendedor_id'] == vendedorId).toList();
    }
    if (promotorId != null) {
      creditos = creditos.where((c) => c['promotor_id'] == promotorId).toList();
    }
    creditos = creditos
        .where(
          (c) =>
              (c['fecha_vencimiento'] as String).compareTo(range!['desde']!) >=
                  0 &&
              (c['fecha_vencimiento'] as String).compareTo(range['hasta']!) <=
                  0,
        )
        .toList();

    final pagados = creditos.where((c) => c['estado'] == 'pagado').toList();
    final pendientes = creditos.where((c) => c['estado'] != 'pagado').toList();

    return {
      'periodo': range['label'],
      'desde': range['desde'],
      'hasta': range['hasta'],
      'totales': _sumTotales(creditos),
      'resumen': {
        'total_creditos': creditos.length,
        'pagados': pagados.length,
        'pendientes': pendientes.length,
      },
      'creditos': creditos,
      'lista_pagados': pagados,
      'lista_pendientes': pendientes,
    };
  }

  Future<Map<String, dynamic>> buildReporteComisiones({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
  }) async {
    var range = periodo != null && periodo.isNotEmpty
        ? _getDateRange(periodo)
        : null;
    if (range == null &&
        desde != null &&
        hasta != null &&
        desde.isNotEmpty &&
        hasta.isNotEmpty) {
      range = {'desde': desde, 'hasta': hasta, 'label': 'Personalizado'};
    }

    var creditos = await listCreditos(vendedorId: vendedorId);
    if (range != null) {
      creditos = creditos.where((c) {
        final f = (c['fecha_venta'] as String?) ?? '';
        return f.compareTo(range!['desde']!) >= 0 &&
            f.compareTo(range['hasta']!) <= 0;
      }).toList();
    }

    final vendedores = await listVendedores(tipo: 'vendedor');
    final porId = {for (final v in vendedores) v['id'] as String: v};

    final agrupado = <String, List<Map<String, dynamic>>>{};
    for (final c in creditos) {
      final vid = (c['vendedor_id'] as String?) ?? '_sin';
      agrupado.putIfAbsent(vid, () => []).add(c);
    }

    final filas = <Map<String, dynamic>>[];
    for (final entry in agrupado.entries) {
      final vend = porId[entry.key];
      final lista = entry.value;
      final totales = _sumTotales(lista);
      final pct =
          (vend?['porcentaje_comision'] as num?)?.toDouble() ??
          (lista.isNotEmpty
              ? (lista.first['vendedor_comision'] as num?)?.toDouble() ?? 0
              : 0);
      filas.add({
        'vendedor_id': entry.key,
        'vendedor_nombre':
            vend?['nombre'] ?? lista.first['vendedor_nombre'] ?? 'Sin vendedor',
        'porcentaje': pct,
        'num_ventas': lista.length,
        'ventas': totales['ventas'],
        'cobrado': totales['cobrado'],
        'saldo': totales['saldo'],
        'comision_a_pagar': totales['comision_venta'],
        'comision_cobrada': totales['comision_cobrada'],
        'comision_pendiente_cliente': totales['comision_pendiente'],
      });
    }
    filas.sort(
      (a, b) => (b['comision_a_pagar'] as double).compareTo(
        a['comision_a_pagar'] as double,
      ),
    );

    double sumKey(String k) =>
        filas.fold(0.0, (s, f) => s + ((f[k] as num?)?.toDouble() ?? 0));

    return {
      'periodo': range?['label'] ?? 'Todo el tiempo',
      'desde': range?['desde'],
      'hasta': range?['hasta'],
      'nota':
          'La comisión a pagar se calcula sobre el total de cada venta (% × monto), '
          'aunque el cliente aún no haya pagado.',
      'vendedores': filas,
      'totales': {
        'ventas': sumKey('ventas'),
        'cobrado': sumKey('cobrado'),
        'saldo': sumKey('saldo'),
        'comision_a_pagar': sumKey('comision_a_pagar'),
        'num_vendedores': filas.length,
        'num_ventas': creditos.length,
      },
    };
  }

  Future<Map<String, dynamic>> buildReportePromotor(
    String promotorId, {
    String? desde,
    String? hasta,
  }) async {
    final db = await database;
    final promRows = await db.query(
      'vendedores',
      where: 'id = ?',
      whereArgs: [promotorId],
    );
    if (promRows.isEmpty || promRows.first['tipo'] != 'promotor') {
      throw Exception('Promotor no encontrado');
    }
    final promotor = promRows.first;

    final vendedores = await listVendedores(promotorId: promotorId);
    final vendedorIds = vendedores.map((v) => v['id'] as String).toSet();

    var creditos = await listCreditos();
    creditos = creditos
        .where((c) => vendedorIds.contains(c['vendedor_id']))
        .toList();
    if (desde != null && desde.isNotEmpty) {
      creditos = creditos
          .where((c) => (c['fecha_venta'] as String).compareTo(desde) >= 0)
          .toList();
    }
    if (hasta != null && hasta.isNotEmpty) {
      creditos = creditos
          .where((c) => (c['fecha_venta'] as String).compareTo(hasta) <= 0)
          .toList();
    }

    final porVendedor = vendedores.map((v) {
      final vc = creditos.where((c) => c['vendedor_id'] == v['id']).toList();
      return {
        'vendedor': v,
        'totales': _sumTotales(vc),
        'creditos': vc,
        'lista_pagados': vc.where((c) => c['estado'] == 'pagado').toList(),
        'lista_pendientes': vc.where((c) => c['estado'] != 'pagado').toList(),
      };
    }).toList();

    return {
      'promotor': promotor,
      'vendedores': porVendedor,
      'totales': _sumTotales(creditos),
      'lista_pagados': creditos.where((c) => c['estado'] == 'pagado').toList(),
      'lista_pendientes': creditos
          .where((c) => c['estado'] != 'pagado')
          .toList(),
      'creditos': creditos,
    };
  }

  Future<Map<String, dynamic>> buildReporteGanancias({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
  }) async {
    var range = periodo != null ? _getDateRange(periodo) : null;
    if (range == null && desde != null && hasta != null) {
      range = {'desde': desde, 'hasta': hasta, 'label': 'Personalizado'};
    }
    if (range == null) {
      throw Exception(
        'Indica periodo (hoy|manana|semanal) o rango desde/hasta',
      );
    }

    final productos = await listProductos();
    final costoPorProducto = <String, double>{
      for (final p in productos)
        p['id'] as String: (p['precio_costo'] as num?)?.toDouble() ?? 0,
    };

    var creditos = await listCreditos();
    if (vendedorId != null) {
      creditos = creditos.where((c) => c['vendedor_id'] == vendedorId).toList();
    }
    creditos = creditos.where((c) {
      final f = (c['fecha_venta'] as String?) ?? '';
      return f.compareTo(range!['desde']!) >= 0 &&
          f.compareTo(range['hasta']!) <= 0;
    }).toList();

    double ingresos = 0, costo = 0, comision = 0;
    var itemsSinCosto = 0;
    final porProducto = <String, Map<String, dynamic>>{};

    for (final c in creditos) {
      final total = (c['monto_total'] as num?)?.toDouble() ?? 0;
      ingresos += total;
      comision += (c['comision_venta'] as num?)?.toDouble() ?? 0;

      final items = (c['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final it in items) {
        final pid = it['producto_id'] as String?;
        final qty = (it['cantidad'] as num?)?.toDouble() ?? 0;
        final precio = (it['precio_unitario'] as num?)?.toDouble() ?? 0;
        final ingItem = qty * precio;
        double costoItem = 0;
        if (pid != null && costoPorProducto.containsKey(pid)) {
          costoItem = costoPorProducto[pid]! * qty;
        } else {
          itemsSinCosto++;
        }
        costo += costoItem;

        final key = (it['descripcion'] as String? ?? 'Producto').trim();
        final acc = porProducto.putIfAbsent(
          key,
          () => {
            'descripcion': key,
            'cantidad': 0.0,
            'ingresos': 0.0,
            'costo': 0.0,
          },
        );
        acc['cantidad'] = (acc['cantidad'] as double) + qty;
        acc['ingresos'] = (acc['ingresos'] as double) + ingItem;
        acc['costo'] = (acc['costo'] as double) + costoItem;
      }
    }

    final ganancia = ingresos - costo - comision;
    final lista = porProducto.values.toList()
      ..sort(
        (a, b) => (b['ingresos'] as double).compareTo(a['ingresos'] as double),
      );

    return {
      'periodo': range['label'],
      'desde': range['desde'],
      'hasta': range['hasta'],
      'ingresos': ingresos,
      'costo': costo,
      'comision': comision,
      'ganancia': ganancia,
      'num_ventas': creditos.length,
      'items_sin_costo': itemsSinCosto,
      'por_producto': lista,
    };
  }

  Future<Map<String, dynamic>> buildReporteClientes({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
    String filtro = 'todos',
  }) async {
    Map<String, String>? range;
    if (periodo != null && periodo.isNotEmpty) {
      range = _getDateRange(periodo);
    } else if (desde != null &&
        desde.isNotEmpty &&
        hasta != null &&
        hasta.isNotEmpty) {
      range = {'desde': desde, 'hasta': hasta, 'label': 'Personalizado'};
    }

    final clientes = await listClientes(vendedorId: vendedorId);
    final allCreditos = await listCreditos(vendedorId: vendedorId);
    final clientesReport = <Map<String, dynamic>>[];

    for (final cl in clientes) {
      final cid = cl['id'] as String;
      final creditos = allCreditos
          .where((c) => c['cliente_id'] == cid)
          .toList();

      var creditosEnPeriodo = creditos;
      if (range != null) {
        creditosEnPeriodo = creditos.where((c) {
          final f = (c['fecha_venta'] as String?) ?? '';
          return f.compareTo(range!['desde']!) >= 0 &&
              f.compareTo(range['hasta']!) <= 0;
        }).toList();
      }

      final totalVentas = creditos.fold(
        0.0,
        (s, c) => s + ((c['monto_total'] as num?)?.toDouble() ?? 0),
      );
      final totalPagado = creditos.fold(
        0.0,
        (s, c) => s + ((c['monto_pagado'] as num?)?.toDouble() ?? 0),
      );
      final saldo = creditos.fold(
        0.0,
        (s, c) => s + ((c['saldo'] as num?)?.toDouble() ?? 0),
      );
      final ventasEnPeriodo = creditosEnPeriodo.fold(
        0.0,
        (s, c) => s + ((c['monto_total'] as num?)?.toDouble() ?? 0),
      );

      String? ultimaCompra;
      for (final c in creditos) {
        final f = c['fecha_venta'] as String?;
        if (f == null) continue;
        if (ultimaCompra == null || f.compareTo(ultimaCompra) > 0)
          ultimaCompra = f;
      }

      clientesReport.add({
        'id': cl['id'],
        'codigo': cl['codigo'],
        'nombre': cl['nombre'],
        'telefono': cl['telefono'],
        'vendedor_nombre': cl['vendedor_nombre'],
        'num_compras': creditos.length,
        'compras_periodo': creditosEnPeriodo.length,
        'total_ventas': totalVentas,
        'ventas_periodo': ventasEnPeriodo,
        'total_pagado': totalPagado,
        'saldo_pendiente': saldo,
        'ultima_compra': ultimaCompra,
        'tiene_adeudo': saldo > 0.005,
      });
    }

    List<Map<String, dynamic>> lista;
    switch (filtro) {
      case 'adeudo':
        lista = clientesReport.where((c) => c['tiene_adeudo'] == true).toList()
          ..sort(
            (a, b) => (b['saldo_pendiente'] as double).compareTo(
              a['saldo_pendiente'] as double,
            ),
          );
        break;
      case 'activos':
        if (range != null) {
          lista =
              clientesReport
                  .where((c) => (c['compras_periodo'] as int) > 0)
                  .toList()
                ..sort(
                  (a, b) => (b['ventas_periodo'] as double).compareTo(
                    a['ventas_periodo'] as double,
                  ),
                );
        } else {
          lista =
              clientesReport
                  .where((c) => (c['num_compras'] as int) > 0)
                  .toList()
                ..sort(
                  (a, b) => (b['total_ventas'] as double).compareTo(
                    a['total_ventas'] as double,
                  ),
                );
        }
        break;
      case 'sin_compras':
        lista =
            clientesReport.where((c) => (c['num_compras'] as int) == 0).toList()
              ..sort(
                (a, b) =>
                    (a['nombre'] as String).compareTo(b['nombre'] as String),
              );
        break;
      default:
        lista = List<Map<String, dynamic>>.from(clientesReport)
          ..sort(
            (a, b) => (b['total_ventas'] as double).compareTo(
              a['total_ventas'] as double,
            ),
          );
    }

    double sumSaldo(List<Map<String, dynamic>> items) => items.fold(
      0.0,
      (s, c) => s + ((c['saldo_pendiente'] as num?)?.toDouble() ?? 0),
    );
    double sumVentas(List<Map<String, dynamic>> items) => items.fold(
      0.0,
      (s, c) => s + ((c['total_ventas'] as num?)?.toDouble() ?? 0),
    );

    return {
      'periodo': range?['label'],
      'desde': range?['desde'],
      'hasta': range?['hasta'],
      'filtro': filtro,
      'clientes': lista,
      'resumen': {
        'total_clientes': clientes.length,
        'con_adeudo': clientesReport
            .where((c) => c['tiene_adeudo'] == true)
            .length,
        'activos': clientesReport
            .where((c) => (c['num_compras'] as int) > 0)
            .length,
        'sin_compras': clientesReport
            .where((c) => (c['num_compras'] as int) == 0)
            .length,
      },
      'totales': {
        'ventas': sumVentas(lista),
        'saldo': sumSaldo(lista),
        'mostrados': lista.length,
      },
    };
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final creditos = await listCreditos();
    final hoy = DateTime.now().toIso8601String().split('T').first;
    final vendedores = await listVendedores(tipo: 'vendedor');
    final promotores = await listVendedores(tipo: 'promotor');
    final clientes = await listClientes();
    final productores = await listProductores();
    final productos = await listProductos();

    double sum(String key) =>
        creditos.fold(0.0, (s, c) => s + ((c[key] as num?)?.toDouble() ?? 0));

    return {
      'total': creditos.length,
      'pagados': creditos.where((c) => c['estado'] == 'pagado').length,
      'pendientes': creditos.where((c) => c['estado'] != 'pagado').length,
      'ventas_total': sum('monto_total'),
      'cobrado_total': sum('monto_pagado'),
      'saldo_total': sum('saldo'),
      'vencen_hoy': creditos
          .where(
            (c) => c['fecha_vencimiento'] == hoy && c['estado'] != 'pagado',
          )
          .length,
      'vendedores': vendedores.where((v) => v['activo'] != 0).length,
      'promotores': promotores.where((v) => v['activo'] != 0).length,
      'clientes': clientes.length,
      'productores': productores.length,
      'productos': productos.length,
    };
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
