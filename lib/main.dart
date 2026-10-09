import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/caja_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'theme/bear_theme.dart';
import 'widgets/whatsapp_notify_dialog.dart';

const bool kShots =
    bool.hasEnvironment('SHOTS') && String.fromEnvironment('SHOTS') != '';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kShots) {
    runApp(const _ShotsApp());
  } else {
    runApp(const GestorCreditosApp());
  }
}

class GestorCreditosApp extends StatelessWidget {
  const GestorCreditosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'Gestor de Créditos — Bear Helados',
        debugShowCheckedModeBanner: false,
        theme: BearTheme.light,
        home: const _RootGate(),
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AppState, bool>((s) => s.isLoggedIn);
    return loggedIn ? const HomeScreen() : const LoginScreen();
  }
}

final GlobalKey _repaintKey = GlobalKey();
final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

class _ShotsApp extends StatefulWidget {
  const _ShotsApp();

  @override
  State<_ShotsApp> createState() => _ShotsAppState();
}

class _ShotsAppState extends State<_ShotsApp> {
  final AppState _state = AppState()..init();

  @override
  void initState() {
    super.initState();
    debugPrint('SHOTS: initState');
    Future.delayed(const Duration(seconds: 3), _run);
  }

  Future<void> _run() async {
    debugPrint('SHOTS: _run start');
    for (var i = 0; i < 40; i++) {
      if (!_state.loading) break;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    debugPrint('SHOTS: loading=${_state.loading} error=${_state.error}');
    await _settle(800);

    final dir = await getApplicationSupportDirectory();
    final shotsDir = Directory('${dir.path}/shots')
      ..createSync(recursive: true);

    await _settle(900);
    await _capture('${shotsDir.path}/login_01_login.png');

    await _state.login('admin', 'admin123');
    await _state.loadUsuarios();
    await _settle(1000);
    _state.setNav(0);
    await _settle(900);
    await _capture('${shotsDir.path}/login_02_admin.png');

    try {
      final existeVend = _state.usuarios.any(
        (u) => u['username'] == 'vendedor',
      );
      if (!existeVend) {
        await _state.addUsuario({
          'nombre': 'Juan Pérez',
          'username': 'vendedor',
          'password': 'vendedor123',
          'rol': 'vendedor',
        });
      }
    } catch (e) {
      debugPrint('SHOTS: seed vendedor error $e');
    }

    final usuariosIdx = 8;
    _state.setNav(usuariosIdx);
    await _settle(1100);
    await _capture('${shotsDir.path}/login_04_usuarios.png');

    try {
      if (_state.cajaSesionActual == null) {
        await _state.abrirCaja(montoApertura: 500);
      }
      await _state.addMovimientoCaja(
        tipo: 'venta',
        monto: 320,
        descripcion: 'Venta contado',
      );
      await _state.addMovimientoCaja(
        tipo: 'abono',
        monto: 150,
        descripcion: 'Abono crédito',
      );
      await _state.addMovimientoCaja(
        tipo: 'entrada',
        monto: 100,
        descripcion: 'Fondo extra',
      );
      await _state.addMovimientoCaja(
        tipo: 'salida',
        monto: 60,
        descripcion: 'Compra insumos',
      );
    } catch (e) {
      debugPrint('SHOTS: caja seed error $e');
    }

    const cajaIdx = 2;
    _state.setNav(cajaIdx);
    await _settle(1200);
    await _capture('${shotsDir.path}/caja_01_abierta.png');

    final esperado = (_state.cajaResumen['esperado'] as num?)?.toDouble() ?? 0;
    final ctx = _navKey.currentContext;
    if (ctx != null) {
      cerrarCajaDialog(ctx, prefillContado: esperado - 40);
      await _settle(1100);
      await _capture('${shotsDir.path}/caja_02_cierre.png');
      _navKey.currentState?.pop();
      await _settle(500);

      try {
        final arqueo = await _state.cerrarCaja(montoContado: esperado - 40);
        final ctx2 = _navKey.currentContext;
        if (ctx2 != null) {
          mostrarArqueoDialog(ctx2, arqueo);
          await _settle(1000);
          await _capture('${shotsDir.path}/caja_04_arqueo.png');
          _navKey.currentState?.pop();
          await _settle(400);
        }
      } catch (e) {
        debugPrint('SHOTS: cierre caja error $e');
      }
    }

    const configIdx = 9;
    _state.setNav(configIdx);
    await _settle(1100);
    await _capture('${shotsDir.path}/caja_03_config.png');

    try {
      String? vendedorId = _state.vendedores.isNotEmpty
          ? _state.vendedores.first['id'] as String?
          : null;
      if (vendedorId == null) {
        await _state.addVendedor({
          'nombre': 'Vendedor Demo',
          'tipo': 'vendedor',
          'porcentaje_comision': 5,
        });
        vendedorId = _state.vendedores.isNotEmpty
            ? _state.vendedores.first['id'] as String?
            : null;
      }

      var cliente = _state.clientes.cast<Map<String, dynamic>?>().firstWhere(
        (c) => (c?['telefono'] as String?)?.trim().isNotEmpty == true,
        orElse: () => null,
      );
      if (cliente == null && vendedorId != null) {
        await _state.addCliente({
          'nombre': 'Melecio',
          'telefono': '04141234567',
          'vendedor_id': vendedorId,
        });
        cliente = _state.clientes.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['nombre'] == 'Melecio',
          orElse: () => null,
        );
      }

      final pendientes = _state.creditos
          .where((c) => c['estado'] != 'pagado')
          .toList();
      if (pendientes.isEmpty && cliente != null) {
        await _state.addCredito({
          'cliente_id': cliente['id'],
          'monto_total': 878.01,
          'abono': 0,
          'descripcion': 'Helados surtidos',
          'fecha_venta': DateTime.now().toIso8601String().split('T').first,
          'cuotas': [
            {
              'monto': 878.01,
              'fecha_vencimiento': DateTime.now()
                  .add(const Duration(days: 30))
                  .toIso8601String()
                  .split('T')
                  .first,
            },
          ],
          'items': [
            {
              'descripcion': 'Helado vainilla',
              'cantidad': 10,
              'precio_unitario': 87.80,
            },
          ],
        });
      }

      await _state.saveConfig({
        'whatsapp_firma': 'Bear Helados - Tel: 0412-0000000',
      });
      _state.setNav(1);
      await _settle(1000);

      final credito = _state.creditos.firstWhere(
        (c) => c['estado'] != 'pagado',
        orElse: () => _state.creditos.first,
      );
      final clienteWhatsApp = resolveClienteForWhatsApp(
        _state,
        clienteId: credito['cliente_id'] as String?,
        clienteNombre: credito['cliente_nombre'] as String?,
        clienteCodigo: credito['cliente_codigo'] as String?,
        clienteTelefono: credito['cliente_telefono'] as String?,
      );
      final ctxWa = _navKey.currentContext;
      if (ctxWa != null && clienteWhatsApp != null) {
        showWhatsAppNotifyDialog(
          context: ctxWa,
          cliente: clienteWhatsApp,
          creditos: creditosPendientesCliente(
            _state,
            clienteId: credito['cliente_id'] as String?,
            clienteNombre: credito['cliente_nombre'] as String?,
            extra: [credito],
          ),
        );
        await _settle(1200);
        await _capture('${shotsDir.path}/whatsapp_01_modal.png');
        _navKey.currentState?.pop();
        await _settle(400);
      }
    } catch (e) {
      debugPrint('SHOTS: whatsapp seed error $e');
    }

    _state.logout();
    await _settle(400);
    await _state.login('vendedor', 'vendedor123');
    await _settle(900);
    _state.setNav(0);
    await _settle(900);
    await _capture('${shotsDir.path}/login_03_vendedor.png');

    debugPrint('SHOTS_DIR=${shotsDir.path}');
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  Future<void> _settle(int ms) async {
    for (var i = 0; i < 4; i++) {
      WidgetsBinding.instance.scheduleFrame();
      await Future.delayed(Duration(milliseconds: ms ~/ 4));
    }
  }

  Future<void> _capture(String path) async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      File(path).writeAsBytesSync(byteData.buffer.asUint8List());
      debugPrint('SHOT_SAVED=$path');
    } catch (e) {
      debugPrint('SHOT_ERROR=$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp(
        title: 'Gestor de Créditos — Bear Helados',
        debugShowCheckedModeBanner: false,
        theme: BearTheme.light,
        navigatorKey: _navKey,
        builder: (context, child) =>
            RepaintBoundary(key: _repaintKey, child: child),
        home: const _RootGate(),
      ),
    );
  }
}
