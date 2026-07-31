import 'package:flutter/material.dart';

import '../../services/dashboard_service.dart';
import 'dashboard_models.dart';
import 'dashboard_theme.dart';

class StorageCard extends StatelessWidget {
  const StorageCard({
    super.key,
    required this.data,
  });

  final CreatorDashboardData data;

  @override
  Widget build(BuildContext context) {
    final progress = data.storageProgress.clamp(0.0, 1.0);
    final color = CreatorDashboardTheme.progressColor(progress);

    return Container(
      width: double.infinity,
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
              const Icon(Icons.storage_outlined,
                  color: CreatorDashboardTheme.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Storage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            'Used',
            DashboardService.formatBytes(data.totalBytes),
          ),
          _InfoRow(
            'Remaining',
            DashboardService.formatBytes(data.remainingBytes),
          ),
          const Divider(height: 24, color: Colors.white12),
          _InfoRow(
            'Limit',
            DashboardService.formatBytes(data.maxBytes),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
