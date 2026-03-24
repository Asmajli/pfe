import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── GRADIENT BUTTON ────────────────────────────────────
class ParkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final List<Color> colors;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final double height;

  const ParkButton({
    super.key, required this.label, this.onTap,
    this.colors = const [AppColors.blue, AppColors.cyan],
    this.loading = false, this.icon, this.outlined = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: outlined ? null : LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: colors.first, width: 1.5) : null,
          boxShadow: outlined ? null : [
            BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: outlined ? colors.first : Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: outlined ? colors.first : Colors.white,
                    )),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── PARK CARD ──────────────────────────────────────────
class ParkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? bgColor;
  final double radius;

  const ParkCard({
    super.key, required this.child, this.padding,
    this.onTap, this.borderColor, this.bgColor, this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor ?? AppColors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: child,
      ),
    );
  }
}

// ── STATUS BADGE ───────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

// ── OCCUPANCY BAR ──────────────────────────────────────
class OccBar extends StatelessWidget {
  final double value;
  final double height;

  const OccBar({super.key, required this.value, this.height = 7});

  Color get _c => value >= 0.9 ? AppColors.red : value >= 0.7 ? AppColors.yellow : AppColors.green;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0), minHeight: height,
        backgroundColor: Colors.white.withOpacity(0.06),
        valueColor: AlwaysStoppedAnimation(_c),
      ),
    );
  }
}

// ── LOGO ───────────────────────────────────────────────
class ParkLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const ParkLogo({super.key, this.size = 48, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          gradient: AppColors.blueGrad,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size * 0.22),
            topRight: Radius.circular(size * 0.22),
            bottomRight: Radius.circular(size * 0.22),
          ),
        ),
        child: Center(child: Text('P', style: TextStyle(
            fontSize: size * 0.45, fontWeight: FontWeight.w900, color: Colors.white))),
      ),
      if (showText) ...[
        const SizedBox(width: 10),
        RichText(text: TextSpan(
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          children: const [
            TextSpan(text: 'Park', style: TextStyle(color: AppColors.textPri)),
            TextSpan(text: 'App', style: TextStyle(color: AppColors.cyan)),
          ],
        )),
      ],
    ]);
  }
}

// ── STAT CARD ──────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color accent;
  final String? trend;

  const StatCard({super.key, required this.value, required this.label,
      required this.icon, required this.accent, this.trend});

  @override
  Widget build(BuildContext context) {
    return ParkCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: accent, size: 16)),
          if (trend != null)
            Text(trend!, style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: AppColors.textPri, letterSpacing: -0.5)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Container(height: 2, decoration: BoxDecoration(
          color: accent, borderRadius: BorderRadius.circular(1))),
      ]),
    );
  }
}

// ── TEXT FIELD ─────────────────────────────────────────
class ParkField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefix, suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;

  const ParkField({
    super.key, required this.label, required this.hint,
    required this.controller, this.obscure = false,
    this.keyboardType, this.validator, this.prefix, this.suffix,
    this.readOnly = false, this.onTap, this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller, obscureText: obscure,
        keyboardType: keyboardType, validator: validator,
        readOnly: readOnly, onTap: onTap, maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPri, fontSize: 14),
        decoration: InputDecoration(hintText: hint, prefixIcon: prefix, suffixIcon: suffix),
      ),
    ]);
  }
}

// ── ERROR BOX ──────────────────────────────────────────
class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: AppColors.red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: AppColors.red, fontSize: 13))),
      ]),
    );
  }
}

// ── SECTION HEADER ─────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPri)),
      if (action != null)
        GestureDetector(onTap: onAction,
          child: Text(action!, style: const TextStyle(fontSize: 12, color: AppColors.cyan, fontWeight: FontWeight.w600))),
    ]);
  }
}

// ── ZONE CARD ──────────────────────────────────────────
class ZoneCard extends StatelessWidget {
  final String name, type, address;
  final int free, total;
  final double price;
  final bool isOpen;
  final VoidCallback? onTap;

  const ZoneCard({
    super.key, required this.name, required this.type,
    required this.address, required this.free, required this.total,
    required this.price, this.isOpen = true, this.onTap,
  });

  Color get _accent => !isOpen ? AppColors.textMuted
      : free == 0 ? AppColors.red
      : free <= 5 ? AppColors.yellow
      : AppColors.green;

  String get _typeIcon => {
    'vip': '⭐', 'couvert': '🏗️', 'souterrain': '🔽', 'pmr': '♿',
  }[type] ?? '🅿️';

  @override
  Widget build(BuildContext context) {
    final occ = (total - free) / (total == 0 ? 1 : total);
    return ParkCard(
      onTap: onTap,
      borderColor: _accent.withOpacity(0.25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_typeIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(address, style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          StatusBadge(
            label: !isOpen ? 'Fermé' : free == 0 ? 'Complet' : '$free libres',
            color: _accent,
          ),
        ]),
        const SizedBox(height: 12),
        OccBar(value: occ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(occ * 100).toInt()}% occupé',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Text('${price.toInt()} DT/h',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.cyan)),
        ]),
      ]),
    );
  }
}