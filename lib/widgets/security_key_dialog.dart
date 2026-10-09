import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/bear_theme.dart';

/// Pide la clave de seguridad configurada por el admin.
/// Retorna `true` si la clave es correcta.
Future<bool> askSecurityKey(
  BuildContext context, {
  String title = 'Clave de seguridad',
  String message = 'Ingresa la clave de seguridad para continuar.',
}) async {
  final state = context.read<AppState>();
  if (!(state.config['tiene_clave_seguridad'] == true)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay clave de seguridad. El administrador debe configurarla en Configuración.',
          ),
        ),
      );
    }
    return false;
  }

  final ctrl = TextEditingController();
  String? error;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: BearColors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Clave de seguridad',
                  errorText: error,
                ),
                onSubmitted: (_) async {
                  final valid = await state.verificarClaveSeguridad(ctrl.text);
                  if (!ctx.mounted) return;
                  if (valid) {
                    Navigator.pop(ctx, true);
                  } else {
                    setLocal(() => error = 'Clave incorrecta');
                  }
                },
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final valid = await state.verificarClaveSeguridad(ctrl.text);
                if (!ctx.mounted) return;
                if (valid) {
                  Navigator.pop(ctx, true);
                } else {
                  setLocal(() => error = 'Clave incorrecta');
                }
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    },
  );

  ctrl.dispose();
  return ok == true;
}
