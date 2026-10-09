import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

class AppState extends ChangeNotifier {
  final _db = AppDatabase.instance;

  bool loading = true;
  String? error;
  int navIndex = 0;

  // --- Sesión ---
  Map<String, dynamic>? usuarioActual;
  bool get isLoggedIn => usuarioActual != null;
  bool get isAdmin => usuarioActual?['rol'] == 'admin';
  bool get isVendedor => usuarioActual?['rol'] == 'vendedor';
  bool get mustChangePassword => (usuarioActual?['must_change_password'] as int? ?? 0) == 1;

  Map<String, dynamic> dashboard = {};
  List<Map<String, dynamic>> clientes = [];
  List<Map<String, dynamic>> vendedores = [];
  List<Map<String, dynamic>> promotores = [];
  List<Map<String, dynamic>> productores = [];
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> creditos = [];
  List<Map<String, dynamic>> usuarios = [];
  Map<String, dynamic> config = {};

  // --- Caja ---
  List<Map<String, dynamic>> cajas = [];
  Map<String, dynamic>? cajaSesionActual;
  Map<String, dynamic> cajaResumen = {};

  String get modoCaja => (config['modo_caja'] as String?) ?? 'unica';
  bool get modoCajaMultiple => modoCaja == 'multiple';
  bool get cajaAbierta => cajaSesionActual != null;

  Future<void> init() async {
    loading = true;
    notifyListeners();
    try {
      await refreshAll();
      error = null;
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    dashboard = await _db.getDashboard();
    clientes = await _db.listClientes();
    vendedores = await _db.listVendedores(tipo: 'vendedor');
    promotores = await _db.listVendedores(tipo: 'promotor');
    productores = await _db.listProductores();
    productos = await _db.listProductos();
    creditos = await _db.listCreditos();
    config = await _db.getConfig();
    cajas = await _db.listCajas();
    await _loadCajaSesion();
    notifyListeners();
  }

  // --- Caja ---

  /// Carga la sesión de caja abierta relevante y su resumen en vivo. En modo
  /// único se comparte una sola caja; en múltiple se prioriza la del usuario.
  Future<void> _loadCajaSesion() async {
    if (modoCajaMultiple) {
      cajaSesionActual = await _db.getSesionAbierta(usuarioId: usuarioActual?['id']);
    } else {
      cajaSesionActual = await _db.getSesionAbierta();
    }
    cajaResumen = cajaSesionActual != null
        ? await _db.getResumenSesion(cajaSesionActual!['id'] as String)
        : {};
  }

  Future<void> refreshCaja() async {
    cajas = await _db.listCajas();
    await _loadCajaSesion();
    notifyListeners();
  }

  Future<void> abrirCaja({String? cajaId, required double montoApertura, String? notas}) async {
    await _db.abrirCaja(
      cajaId: cajaId,
      usuarioId: usuarioActual?['id'] as String?,
      montoApertura: montoApertura,
      notas: notas,
    );
    await refreshCaja();
  }

  Future<Map<String, dynamic>> cerrarCaja({required double montoContado, String? notas}) async {
    if (cajaSesionActual == null) throw Exception('No hay una sesión de caja abierta');
    final arqueo = await _db.cerrarCaja(
      sesionId: cajaSesionActual!['id'] as String,
      montoContado: montoContado,
      notas: notas,
    );
    await refreshCaja();
    return arqueo;
  }

  Future<void> addMovimientoCaja({
    required String tipo,
    required double monto,
    String? descripcion,
  }) async {
    if (cajaSesionActual == null) throw Exception('No hay una sesión de caja abierta');
    await _db.registrarMovimientoCaja(
      sesionId: cajaSesionActual!['id'] as String,
      tipo: tipo,
      monto: monto,
      descripcion: descripcion,
      usuarioId: usuarioActual?['id'] as String?,
    );
    await refreshCaja();
  }

  Future<List<Map<String, dynamic>>> getMovimientosCaja(String sesionId) =>
      _db.listMovimientosCaja(sesionId);

  Future<Map<String, dynamic>> getResumenSesion(String sesionId) =>
      _db.getResumenSesion(sesionId);

  Future<List<Map<String, dynamic>>> getSesionesCerradas() =>
      _db.listSesionesCerradas(usuarioId: isAdmin ? null : usuarioActual?['id'] as String?);

  Future<void> addCaja(Map<String, dynamic> data) async {
    await _db.createCaja(data);
    await refreshCaja();
  }

  Future<void> editCaja(String id, Map<String, dynamic> data) async {
    await _db.updateCaja(id, data);
    await refreshCaja();
  }

  void setNav(int index) {
    navIndex = index;
    notifyListeners();
  }

  // --- Sesión / autenticación ---
  Future<bool> login(String username, String password) async {
    final user = await _db.autenticar(username, password);
    if (user == null) return false;
    usuarioActual = user;
    navIndex = 0;
    await _loadCajaSesion();
    notifyListeners();
    return true;
  }

  void logout() {
    usuarioActual = null;
    navIndex = 0;
    notifyListeners();
  }

  // --- Usuarios (gestión, solo admin) ---
  Future<void> loadUsuarios() async {
    usuarios = await _db.listUsuarios();
    notifyListeners();
  }

  Future<void> addUsuario(Map<String, dynamic> data) async {
    await _db.createUsuario(data);
    await loadUsuarios();
  }

  Future<void> editUsuario(String id, Map<String, dynamic> data) async {
    await _db.updateUsuario(id, data);
    await loadUsuarios();
  }

  Future<void> toggleUsuarioActivo(String id, bool activo) async {
    await _db.setUsuarioActivo(id, activo);
    await loadUsuarios();
  }

  Future<void> resetUsuarioPassword(String id, String nueva) async {
    await _db.resetPassword(id, nueva);
    await loadUsuarios();
  }

  Future<void> removeUsuario(String id) async {
    await _db.deleteUsuario(id);
    await loadUsuarios();
  }

  Future<void> saveConfig(Map<String, dynamic> data) async {
    config = await _db.updateConfig(data);
    notifyListeners();
  }

  Future<void> resetDatosOperativos() async {
    await _db.resetDatosOperativos();
    await refreshAll();
  }

  Future<void> addVendedor(Map<String, dynamic> data) async {
    await _db.createVendedor(data);
    await refreshAll();
  }

  Future<void> editVendedor(String id, Map<String, dynamic> data) async {
    await _db.updateVendedor(id, data);
    await refreshAll();
  }

  Future<void> removeVendedor(String id) async {
    await _db.deleteVendedor(id);
    await refreshAll();
  }

  Future<void> addCliente(Map<String, dynamic> data) async {
    await _db.createCliente(data);
    await refreshAll();
  }

  Future<void> editCliente(String id, Map<String, dynamic> data) async {
    await _db.updateCliente(id, data);
    await refreshAll();
  }

  Future<void> removeCliente(String id) async {
    await _db.deleteCliente(id);
    await refreshAll();
  }

  Future<Map<String, dynamic>> addCredito(Map<String, dynamic> data) async {
    final c = await _db.createCredito(
      {...data, 'usuario_id': usuarioActual?['id']},
      cajaSesionId: cajaSesionActual?['id'] as String?,
    );
    await refreshAll();
    return c;
  }

  Future<void> editCredito(String id, Map<String, dynamic> data) async {
    await _db.updateCredito(id, data);
    await refreshAll();
  }

  Future<void> removeCredito(String id) async {
    await _db.deleteCredito(id);
    await refreshAll();
  }

  Future<bool> verificarClaveSeguridad(String clave) => _db.verificarClaveSeguridad(clave);

  Future<void> backupDatabase(String destPath) => _db.backupDatabase(destPath);

  Future<void> addPago(String creditoId, Map<String, dynamic> data) async {
    await _db.createPago(
      creditoId,
      {...data, 'usuario_id': usuarioActual?['id']},
      cajaSesionId: cajaSesionActual?['id'] as String?,
    );
    await refreshAll();
  }

  Future<Map<String, dynamic>?> getCreditoDetail(String id) => _db.getCredito(id);

  Future<void> addProductor(Map<String, dynamic> data) async {
    await _db.createProductor(data);
    await refreshAll();
  }

  Future<void> editProductor(String id, Map<String, dynamic> data) async {
    await _db.updateProductor(id, data);
    await refreshAll();
  }

  Future<void> removeProductor(String id) async {
    await _db.deleteProductor(id);
    await refreshAll();
  }

  Future<void> addProducto(Map<String, dynamic> data) async {
    await _db.createProducto(data);
    await refreshAll();
  }

  Future<void> editProducto(String id, Map<String, dynamic> data) async {
    await _db.updateProducto(id, data);
    await refreshAll();
  }

  Future<void> removeProducto(String id) async {
    await _db.deleteProducto(id);
    await refreshAll();
  }

  Future<void> entradaInventario(String productoId, double cantidad, {String? fecha}) async {
    await _db.registrarMovimientoInventario(
      productoId: productoId,
      tipo: 'entrada',
      cantidad: cantidad,
      fecha: fecha,
    );
    await refreshAll();
  }

  Future<void> salidaInventario(String productoId, double cantidad, {String? fecha}) async {
    await _db.registrarMovimientoInventario(
      productoId: productoId,
      tipo: 'salida',
      cantidad: cantidad,
      fecha: fecha,
    );
    await refreshAll();
  }

  Future<List<Map<String, dynamic>>> getMovimientosInventario({String? productoId}) =>
      _db.listMovimientosInventario(productoId: productoId);

  Future<Map<String, dynamic>> generateReporte({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
    String? promotorId,
  }) =>
      _db.buildReporte(
        periodo: periodo,
        desde: desde,
        hasta: hasta,
        vendedorId: vendedorId,
        promotorId: promotorId,
      );

  Future<Map<String, dynamic>> generateReporteComisiones({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
  }) =>
      _db.buildReporteComisiones(
        periodo: periodo,
        desde: desde,
        hasta: hasta,
        vendedorId: vendedorId,
      );

  Future<Map<String, dynamic>> generateReportePromotor(String promotorId, {String? desde, String? hasta}) =>
      _db.buildReportePromotor(promotorId, desde: desde, hasta: hasta);

  Future<Map<String, dynamic>> generateReporteGanancias({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
  }) =>
      _db.buildReporteGanancias(
        periodo: periodo,
        desde: desde,
        hasta: hasta,
        vendedorId: vendedorId,
      );

  Future<Map<String, dynamic>> generateReporteClientes({
    String? periodo,
    String? desde,
    String? hasta,
    String? vendedorId,
    String filtro = 'todos',
  }) =>
      _db.buildReporteClientes(
        periodo: periodo,
        desde: desde,
        hasta: hasta,
        vendedorId: vendedorId,
        filtro: filtro,
      );
}
