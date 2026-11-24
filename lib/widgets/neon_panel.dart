import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Carte sombre à bordure néon, utilisée partout pour regrouper des infos.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = Neon.cyan,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Neon.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Neon.fade(accent, 0.28)),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
    );
  }
}

/// Titre de section : petite barre rouge, texte espacé, élément optionnel à droite.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Neon.red,
              borderRadius: BorderRadius.circular(2),
              boxShadow: Neon.glow(Neon.red, strength: 0.3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: displayStyle(size: 13, spacing: 3),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Une ligne « légende à gauche, valeur à droite » (infos techniques).
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor = Neon.text});

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Neon.textDim, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
