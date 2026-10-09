import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/bear_theme.dart';

/// Fondo general de la app: degradado azulado suave estilo BodegApp.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BearColors.bgAlt, BearColors.bg],
        ),
      ),
      child: child,
    );
  }
}

/// Encabezado de página: título grande + subtítulo, con acción opcional a la derecha.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

/// Barra de búsqueda redondeada tipo BodegApp ("Buscar por Nombre, Categoría...").
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.width,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: BearColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: BearColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: BearColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: BearColors.indigo, width: 2),
        ),
      ),
    );
    return width != null ? SizedBox(width: width, child: field) : field;
  }
}

/// Tarjeta blanca redondeada con sombra suave. Envuelve contenido.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BearColors.surface,
        borderRadius: BorderRadius.circular(BearTheme.radius),
        boxShadow: const [
          BoxShadow(color: BearColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Pastilla de estado con color de acento (pagado / pendiente / parcial…).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Selector de cantidad entera con botones - / + (stepper) y entrada manual.
/// Cantidad mínima [min] (por defecto 1). Emite enteros vía [onChanged].
class QtyStepper extends StatefulWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.width = 118,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final double width;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant QtyStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != (int.tryParse(_ctrl.text) ?? widget.min)) {
      _ctrl.text = widget.value.toString();
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(int v) {
    final clamped = v < widget.min ? widget.min : v;
    _ctrl.text = clamped.toString();
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.remove_rounded, onTap: () => _set(widget.value - 1)),
          Expanded(
            child: TextField(
              controller: _ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              ),
              onChanged: (v) {
                final n = int.tryParse(v) ?? widget.min;
                widget.onChanged(n < widget.min ? widget.min : n);
              },
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: () => _set(widget.value + 1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BearColors.indigo.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: BearColors.indigo),
        ),
      ),
    );
  }
}

/// Botón de acción de fila compacto (Editar, Historial…) estilo suave.
class RowActionButton extends StatelessWidget {
  const RowActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BearColors.textMuted;
    return Material(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 15, color: c), const SizedBox(width: 5)],
              Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
