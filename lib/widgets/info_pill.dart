import 'package:flutter/material.dart';

import '../theme/gallery_theme.dart';

/// A small reusable information badge used throughout TG Creator.
///
/// Ideal for:
/// - Package size
/// - SHA-256 hash
/// - Media count
/// - Version
/// - Tags
/// - Creator name
/// - Status indicators
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = GalleryColors.purpleBright,
    this.backgroundColor,
    this.borderColor,
    this.textColor = Colors.white,
    this.compact = false,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String text;

  final Color iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color textColor;

  /// Reduces padding and icon size for tighter layouts.
  final bool compact;

  /// Optional click handler.
  final VoidCallback? onTap;

  /// Optional tooltip shown on hover.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    Widget pill = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? GalleryColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ??
              GalleryColors.purpleBright.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 15 : 17,
            color: iconColor,
          ),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      pill = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: pill,
        ),
      );
    }

    if (tooltip != null && tooltip!.trim().isNotEmpty) {
      pill = Tooltip(
        message: tooltip!,
        child: pill,
      );
    }

    return pill;
  }
}
