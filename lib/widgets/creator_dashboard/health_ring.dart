import 'package:flutter/material.dart';

import 'dashboard_theme.dart';

class HealthRing extends StatelessWidget {
  const HealthRing({
    super.key,
    required this.score,
    required this.label,
  });

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = (score / 100).clamp(0.0, 1.0);

    return SizedBox.square(
      dimension: 132,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 11,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(
              CreatorDashboardTheme.purple,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: CreatorDashboardTheme.silver,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
