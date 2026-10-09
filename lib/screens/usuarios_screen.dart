import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/form_dialog.dart';
import '../widgets/page_toolbar.dart';
import '../widgets/scrollable_table.dart';
import '../widgets/ui_kit.dart';

/// Gestión de usuarios (solo administrador): CRUD, activar/desactivar y reset
/// de contraseña. Homologado con el resto de pantallas (Bear / BodegApp).
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadUsuarios();
    });
  }

  void _showForm({Map<String, dynamic>? usuario}) {
    final state = context.read<AppState>();
    final esNuevo = usuario == null;
    final nombreCtrl = TextEditingController(text: usuario?['nombre'] ?? '');
    final userCtrl = TextEditingController(text: usuario?['username'] ?? '');
    final passCtrl = TextEditingController();
    String rol = usuario?['rol'] as String? ?? 'vendedor';
    String? vendedorId = usuario?['vendedor_id'] as String?;

    showBearFormDialog(
      context: context,
      title: esNuevo ? 'Nuevo usuario' : 'Editar usuario',
      primaryLabel: esNuevo ? 'Crear' : 'Guardar',
      onPrimary: () async {
        if (nombreCtrl.text.trim().isEmpty || userCtrl.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nombre y usuario son obligatorios')),
          );
          return;
        }
        final data = {
          'nombre': nombreCtrl.text.trim(),
          'username': userCtrl.text.trim(),
          'rol': rol,
          'vendedor_id': rol == 'vendedor' ? vendedorId : null,
          if (passCtrl.text.trim().isNotEmpty) 'password': passCtrl.text.trim(),
        };
        try {
          if (esNuevo) {
            if (passCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Define una contraseña para el nuevo usuario')),
              );
              return;
            }
            await state.addUsuario(data);
          } else {
            await state.editUsuario(usuario['id'] as String, data);
          }
          if (context.mounted) Navigator.pop(context);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: StatefulBuilder(
        builder: (ctx, setLocal) => FormGrid(
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre *'),
            ),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Usuario *', hintText: 'ej. jperez'),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: rol,
                  decoration: const InputDecoration(labelText: 'Rol *'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                    DropdownMenuItem(value: 'vendedor', child: Text('Vendedor')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => rol = v);
                  },
                ),
                FormFieldHint(
                  rol == 'admin'
                      ? 'Acceso total: reportes, ganancias, configuración y usuarios.'
                      : 'Acceso limitado: ventas, clientes e inventario (solo lectura).',
                ),
              ],
            ),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: esNuevo ? 'Contraseña *' : 'Nueva contraseña (opcional)',
                hintText: esNuevo ? 'Mínimo 4 caracteres' : 'Dejar vacío para no cambiar',
              ),
            ),
            if (rol == 'vendedor')
              DropdownButtonFormField<String?>(
                value: vendedorId,
                decoration: const InputDecoration(labelText: 'Vendedor asociado'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— Ninguno —')),
                  for (final v in state.vendedores)
                    DropdownMenuItem(value: v['id'] as String, child: Text(v['nombre'] as String)),
                ],
                onChanged: (v) => setLocal(() => vendedorId = v),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  void _showResetPassword(Map<String, dynamic> usuario) {
    final passCtrl = TextEditingController();
    showBearFormDialog(
      context: context,
      title: 'Resetear contraseña',
      primaryLabel: 'Guardar',
      onPrimary: () async {
        if (passCtrl.text.trim().length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mínimo 4 caracteres')),
          );
          return;
        }
        try {
          await context.read<AppState>().resetUsuarioPassword(usuario['id'] as String, passCtrl.text.trim());
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contraseña actualizada')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Usuario: ${usuario['nombre']} (${usuario['username']})',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nueva contraseña *', hintText: 'Mínimo 4 caracteres'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final usuarios = state.usuarios;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Usuarios',
            subtitle: 'Gestiona accesos y roles (administrador / vendedor)',
            trailing: ToolbarNewButton(label: 'Nuevo usuario', onPressed: () => _showForm()),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: usuarios.isEmpty
                  ? const Center(child: Text('Sin usuarios.'))
                  : ScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Usuario')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Vendedor')),
                        DataColumn(label: Text('Estado')),
                        DataColumn(label: Text('Acciones')),
                      ],
                      rows: usuarios.map((u) {
                        final rol = u['rol'] as String? ?? 'vendedor';
                        final activo = (u['activo'] as int? ?? 1) == 1;
                        final esActual = u['id'] == state.usuarioActual?['id'];
                        return DataRow(cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(u['nombre'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (esActual) ...[
                                const SizedBox(width: 8),
                                const StatusPill(label: 'tú', color: BearColors.blue),
                              ],
                            ],
                          )),
                          DataCell(Text(u['username'] as String? ?? '—')),
                          DataCell(StatusPill(
                            label: rol == 'admin' ? 'Administrador' : 'Vendedor',
                            color: rol == 'admin' ? BearColors.indigo : BearColors.success,
                          )),
                          DataCell(Text((u['vendedor_nombre'] as String?) ?? '—')),
                          DataCell(StatusPill(
                            label: activo ? 'Activo' : 'Inactivo',
                            color: activo ? BearColors.success : BearColors.grayLight,
                          )),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RowActionButton(
                                label: 'Editar',
                                icon: Icons.edit_rounded,
                                color: BearColors.indigo,
                                onPressed: () => _showForm(usuario: u),
                              ),
                              const SizedBox(width: 6),
                              RowActionButton(
                                label: 'Contraseña',
                                icon: Icons.key_rounded,
                                color: BearColors.warning,
                                onPressed: () => _showResetPassword(u),
                              ),
                              const SizedBox(width: 6),
                              RowActionButton(
                                label: activo ? 'Desactivar' : 'Activar',
                                icon: activo ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                                color: activo ? BearColors.grayLight : BearColors.success,
                                onPressed: esActual
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No puedes desactivar tu propia cuenta')),
                                        );
                                      }
                                    : () async {
                                        try {
                                          await state.toggleUsuarioActivo(u['id'] as String, !activo);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                          }
                                        }
                                      },
                              ),
                              const SizedBox(width: 6),
                              RowActionButton(
                                label: 'Eliminar',
                                icon: Icons.delete_outline_rounded,
                                color: BearColors.danger,
                                onPressed: esActual
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('No puedes eliminar tu propia cuenta')),
                                        );
                                      }
                                    : () async {
                                        if (!await confirmDelete(context, message: '¿Eliminar este usuario?')) return;
                                        try {
                                          await state.removeUsuario(u['id'] as String);
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                          }
                                        }
                                      },
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
