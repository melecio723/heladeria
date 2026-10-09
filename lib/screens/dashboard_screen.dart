import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../utils/format.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = context.watch<AppState>().dashboard;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: ListView(
        children: [
          const PageHeader(
            title: 'Indicadores',
            subtitle: 'Gestor de Créditos — Bear Helados · funciona sin conexión',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _StatCard(title: 'Ventas totales', value: money(d['ventas_total']), icon: Icons.trending_up_rounded, color: BearColors.indigo),
              _StatCard(title: 'Cobrado', value: money(d['cobrado_total']), icon: Icons.payments_rounded, color: BearColors.success),
              _StatCard(title: 'Saldo pendiente', value: money(d['saldo_total']), icon: Icons.account_balance_wallet_rounded, color: BearColors.warning),
              _StatCard(title: 'Créditos activos', value: '${d['pendientes'] ?? 0}', icon: Icons.receipt_long_rounded, color: BearColors.blue),
              _StatCard(title: 'Vencen hoy', value: '${d['vencen_hoy'] ?? 0}', icon: Icons.today_rounded, color: BearColors.danger),
              _StatCard(title: 'Clientes', value: '${d['clientes'] ?? 0}', icon: Icons.people_alt_rounded, color: BearColors.indigo),
              _StatCard(title: 'Vendedores', value: '${d['vendedores'] ?? 0}', icon: Icons.badge_rounded, color: BearColors.blue),
              _StatCard(title: 'Promotores', value: '${d['promotores'] ?? 0}', icon: Icons.groups_rounded, color: BearColors.warning),
              _StatCard(title: 'Productores', value: '${d['productores'] ?? 0}', icon: Icons.storefront_rounded, color: BearColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 236,
      child: SoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: BearColors.textPrimary,
                    fontSize: 24,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
