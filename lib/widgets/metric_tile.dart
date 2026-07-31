import 'package:flutter/material.dart';

import '../theme/gallery_theme.dart';

/// Reusable metric display tile used throughout the TG Creator UI.
///
/// Pure presentation widget.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = GalleryColors.purpleBright,
    this.alignment = CrossAxisAlignment.center,
    this.expand = true,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final CrossAxisAlignment alignment;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalleryColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return expand ? child : IntrinsicWidth(child: child);
  }
}
