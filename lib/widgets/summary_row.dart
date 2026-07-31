import 'package:flutter/material.dart';

import '../theme/gallery_theme.dart';

/// Reusable key/value row used throughout the TG Creator UI.
///
/// Examples:
/// - Package Summary
/// - Card Details
/// - Creator Profiles
/// - Publishing metadata
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 100,
    this.bottomPadding = 9,
    this.valueStyle,
    this.labelStyle,
    this.valueAlignment = TextAlign.right,
    this.allowWrap = true,
    this.showDivider = false,
  });

  final String label;
  final String value;

  /// Fixed width of the label column.
  final double labelWidth;

  /// Space below each row.
  final double bottomPadding;

  /// Optional custom styles.
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  /// Alignment of the value text.
  final TextAlign valueAlignment;

  /// Allow the value to wrap onto multiple lines.
  final bool allowWrap;

  /// Draw a divider beneath the row.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: labelStyle ??
                  const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: valueAlignment,
              maxLines: allowWrap ? null : 1,
              style: valueStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
            ),
          ),
        ],
      ),
    );

    if (!showDivider) {
      return row;
    }

    return Column(
      children: [
        row,
        const Divider(
          height: 12,
          color: Color(0x223B3B44),
        ),
      ],
    );
  }
}
