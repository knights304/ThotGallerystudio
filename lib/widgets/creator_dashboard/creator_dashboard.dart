import 'package:flutter/material.dart';

import '../../services/dashboard_service.dart';
import 'dashboard_models.dart';
import 'dashboard_theme.dart';
import 'health_ring.dart';
import 'quality_badge.dart';

class CreatorDashboard extends StatelessWidget {
  const CreatorDashboard({
    super.key,
    required this.data,
  });

  final CreatorDashboardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: CreatorDashboardTheme.purple.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: CreatorDashboardTheme.deepPurple.withValues(alpha: 0.22),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(isExportReady: data.isExportReady),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 18,
                  children: [
                    HealthRing(
                      score: data.healthScore,
                      label: data.healthLabel,
                    ),
                    Column(
                      children: [
                        QualityBadge(badge: data.badge),
                        const SizedBox(height: 12),
                        Text(
                          data.isExportReady
                              ? 'Ready to export'
                              : 'Finish the checklist below',
                          style: TextStyle(
                            color: data.isExportReady
                                ? CreatorDashboardTheme.success
                                : Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ProgressRow(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos',
                  valueLabel: '${data.photoCount} / ${data.maxPhotos}',
                  progress: data.photoProgress,
                ),
                const SizedBox(height: 14),
                _ProgressRow(
                  icon: Icons.movie_outlined,
                  label: 'Videos',
                  valueLabel: '${data.videoCount} / ${data.maxVideos}',
                  progress: data.videoProgress,
                ),
                const SizedBox(height: 14),
                _ProgressRow(
                  icon: Icons.storage_outlined,
                  label: 'Storage',
                  valueLabel:
                      '${DashboardService.formatBytes(data.totalBytes)} / ${DashboardService.formatBytes(data.maxBytes)}',
                  progress: data.storageProgress,
                ),
                const SizedBox(height: 22),
                _Section(
                  title: 'Export Readiness',
                  icon: Icons.fact_check_outlined,
                  child: Column(
                    children: data.exportChecks
                        .map((check) => _ChecklistRow(check: check))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Zee Recommendations',
                  icon: Icons.auto_awesome,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: data.recommendations
                        .map(
                          (message) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💜'),
                                const SizedBox(width: 8),
                                Expanded(child: Text(message)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
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

class _Header extends StatelessWidget {
  const _Header({required this.isExportReady});

  final bool isExportReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4C1F70),
            Color(0xFF20102D),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Creator Dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          Icon(
            isExportReady
                ? Icons.verified_outlined
                : Icons.build_circle_outlined,
            color: isExportReady
                ? CreatorDashboardTheme.success
                : CreatorDashboardTheme.warning,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = CreatorDashboardTheme.progressColor(progress);

    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: CreatorDashboardTheme.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              valueLabel,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 9,
            value: progress,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.panelRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: CreatorDashboardTheme.purple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.check});

  final DashboardCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.isComplete
        ? CreatorDashboardTheme.success
        : CreatorDashboardTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            check.isComplete
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }
}
