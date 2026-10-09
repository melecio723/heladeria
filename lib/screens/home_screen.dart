import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/ui_kit.dart';
import 'caja_screen.dart';
import 'clientes_screen.dart';
import 'config_screen.dart';
import 'creditos_screen.dart';
import 'dashboard_screen.dart';
import 'productores_screen.dart';
import 'productos_screen.dart';
import 'reportes_screen.dart';
import 'usuarios_screen.dart';
import 'vendedores_screen.dart';

/// Un destino de navegación con su página y si requiere rol admin.
class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.label,
    required this.page,
    this.adminOnly = false,
  });

  final IconData icon;
  final String label;
  final Widget page;
  final bool adminOnly;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _all = [
    _NavDestination(icon: Icons.insights_rounded, label: 'Indicadores', page: DashboardScreen(), adminOnly: true),
    _NavDestination(icon: Icons.point_of_sale_rounded, label: 'Ventas / Créditos', page: CreditosScreen()),
    _NavDestination(icon: Icons.account_balance_wallet_rounded, label: 'Caja', page: CajaScreen()),
    _NavDestination(icon: Icons.people_alt_rounded, label: 'Clientes', page: ClientesScreen()),
    _NavDestination(icon: Icons.inventory_2_rounded, label: 'Inventario', page: ProductosScreen()),
    _NavDestination(icon: Icons.badge_rounded, label: 'Vendedores', page: VendedoresScreen(), adminOnly: true),
    _NavDestination(icon: Icons.assessment_rounded, label: 'Reportes', page: ReportesScreen(), adminOnly: true),
    _NavDestination(icon: Icons.storefront_rounded, label: 'Productores', page: ProductoresScreen(), adminOnly: true),
    _NavDestination(icon: Icons.manage_accounts_rounded, label: 'Usuarios', page: UsuariosScreen(), adminOnly: true),
    _NavDestination(icon: Icons.settings_rounded, label: 'Configuración', page: ConfigScreen(), adminOnly: true),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const Scaffold(
        body: AppBackground(
          child: Center(child: CircularProgressIndicator(color: BearColors.indigo)),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        body: AppBackground(child: Center(child: Text('Error: ${state.error}'))),
      );
    }

    final visibles = _all.where((d) => state.isAdmin || !d.adminOnly).toList();
    final index = state.navIndex.clamp(0, visibles.length - 1);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: index,
            onSelect: state.setNav,
            destinations: visibles,
            usuario: state.usuarioActual,
            onLogout: () => state.logout(),
          ),
          Expanded(
            child: AppBackground(child: visibles[index].page),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.destinations,
    required this.usuario,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<_NavDestination> destinations;
  final Map<String, dynamic>? usuario;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final rol = usuario?['rol'] as String? ?? 'vendedor';
    final nombre = usuario?['nombre'] as String? ?? 'Usuario';

    return Container(
      width: 244,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BearColors.sidebarTop, BearColors.sidebarBottom],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset('assets/images/bear_logo_nobg.png', height: 34),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bear Helados',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Gestor de Créditos',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    _NavItem(
                      icon: destinations[i].icon,
                      label: destinations[i].label,
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            _SessionFooter(nombre: nombre, rol: rol, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _SessionFooter extends StatelessWidget {
  const _SessionFooter({
    required this.nombre,
    required this.rol,
    required this.onLogout,
  });

  final String nombre;
  final String rol;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                child: Text(
                  nombre.isNotEmpty ? nombre.characters.first.toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    Text(
                      rol == 'admin' ? 'Administrador' : 'Vendedor',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 17, color: Colors.white.withValues(alpha: 0.85)),
                    const SizedBox(width: 8),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: BearColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
