import 'package:flutter/material.dart';

/// Botón primario de toolbar homologado con la web (`+ Nuevo`, `+ Nuevo cliente`, etc.).
class ToolbarNewButton extends StatelessWidget {
  const ToolbarNewButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }
}
