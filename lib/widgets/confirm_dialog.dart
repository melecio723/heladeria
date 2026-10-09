import 'package:flutter/material.dart';

import '../theme/bear_theme.dart';

/// Diálogo de confirmación para eliminar (homologado con `confirm()` de la web).
Future<bool> confirmDelete(
  BuildContext context, {
  String message = '¿Eliminar este registro?',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BearColors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Confirmar'),
      content: Text(message),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BearColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}
