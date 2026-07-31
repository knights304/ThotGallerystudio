import 'package:flutter/material.dart';

import 'dashboard_models.dart';
import 'dashboard_theme.dart';

class ExportReadiness extends StatelessWidget {
  const ExportReadiness({
    super.key,
    required this.data,
  });

  final CreatorDashboardData data;

  @override
  Widget build(BuildContext context) {
    final complete = data.exportChecks.where((c) => c.isComplete).length;
    final total = data.exportChecks.length;
    final progress = total == 0 ? 0.0 : complete / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.panelRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                data.isExportReady
                    ? Icons.verified_outlined
                    : Icons.fact_check_outlined,
                color: data.isExportReady
                    ? CreatorDashboardTheme.success
                    : CreatorDashboardTheme.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Export Readiness',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Text('$complete / $total'),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(
                CreatorDashboardTheme.progressColor(progress),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...data.exportChecks.map((check) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      check.isComplete
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: check.isComplete
                          ? CreatorDashboardTheme.success
                          : CreatorDashboardTheme.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (check.detail.isNotEmpty)
                            Text(
                              check.detail,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (data.isExportReady
                      ? CreatorDashboardTheme.success
                      : CreatorDashboardTheme.warning)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data.isExportReady
                  ? 'This card is ready to export.'
                  : 'Complete the remaining checklist items before exporting.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: data.isExportReady
                    ? CreatorDashboardTheme.success
                    : CreatorDashboardTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
