import 'package:flutter/material.dart';

import 'dashboard_models.dart';
import 'dashboard_theme.dart';

class QualityBadge extends StatelessWidget {
  const QualityBadge({
    super.key,
    required this.badge,
  });

  final CardQualityBadge badge;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (badge) {
      CardQualityBadge.bronze => ('🥉', 'BRONZE', const Color(0xFFCD7F32)),
      CardQualityBadge.silver => ('🥈', 'SILVER', CreatorDashboardTheme.silver),
      CardQualityBadge.gold => ('🥇', 'GOLD', const Color(0xFFFFD166)),
      CardQualityBadge.diamond => ('💎', 'DIAMOND', const Color(0xFF8BE9FD)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QUALITY BADGE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  color: Colors.white60,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
