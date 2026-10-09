import 'package:flutter/material.dart';

import '../theme/bear_theme.dart';

/// Diálogo de formulario homologado con la web: título, contenido scrollable,
/// botones Crear/Guardar (primario rojo) + Cancelar (outline), alineados a la izquierda.
Future<T?> showBearFormDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  required String primaryLabel,
  required VoidCallback onPrimary,
  bool primaryEnabled = true,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: BearColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(child: child),
              ),
              const SizedBox(height: 20),
              FormDialogActions(
                primaryLabel: primaryLabel,
                onPrimary: onPrimary,
                onCancel: () => Navigator.pop(ctx),
                primaryEnabled: primaryEnabled,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class FormDialogActions extends StatelessWidget {
  const FormDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
    this.primaryEnabled = true,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: BearColors.danger,
            backgroundColor: BearColors.dangerSoft,
            side: BorderSide.none,
          ),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: primaryEnabled ? onPrimary : null,
          child: Text(primaryLabel),
        ),
      ],
    );
  }
}

/// Hint de ayuda bajo campos (como `.field-hint` en la web).
class FormFieldHint extends StatelessWidget {
  const FormFieldHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: BearColors.gold,
              fontSize: 12,
            ),
      ),
    );
  }
}

/// Grid de dos columnas para formularios (como `.form-grid` en la web).
class FormGrid extends StatelessWidget {
  const FormGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 480;
        if (!twoCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacing(children),
          );
        }
        final rows = <Widget>[];
        var i = 0;
        while (i < children.length) {
          final child = children[i];
          if (child is FormGridFull) {
            rows.add(child.child);
            rows.add(const SizedBox(height: 12));
            i++;
          } else if (i + 1 < children.length && children[i + 1] is! FormGridFull) {
            rows.add(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 12),
                Expanded(child: children[i + 1]),
              ],
            ));
            rows.add(const SizedBox(height: 12));
            i += 2;
          } else {
            rows.add(children[i]);
            rows.add(const SizedBox(height: 12));
            i++;
          }
        }
        if (rows.isNotEmpty && rows.last is SizedBox) rows.removeLast();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }

  List<Widget> _withSpacing(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) result.add(const SizedBox(height: 12));
    }
    return result;
  }
}

/// Campo de ancho completo dentro del grid.
class FormGridFull extends StatelessWidget {
  const FormGridFull({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
