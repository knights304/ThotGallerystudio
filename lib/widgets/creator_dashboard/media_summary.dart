import 'package:flutter/material.dart';

import 'dashboard_models.dart';
import 'dashboard_theme.dart';

class MediaSummary extends StatelessWidget {
  const MediaSummary({
    super.key,
    required this.data,
  });

  final CreatorDashboardData data;

  @override
  Widget build(BuildContext context) {
    final totalMedia = data.photoCount + data.videoCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.panelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CreatorDashboardTheme.purple.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.perm_media_outlined,
                color: CreatorDashboardTheme.purple,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Media Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _TotalBadge(total: totalMedia),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useVerticalLayout = constraints.maxWidth < 430;

              if (useVerticalLayout) {
                return Column(
                  children: [
                    _MediaTypeCard(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      count: data.photoCount,
                      maximum: data.maxPhotos,
                      progress: data.photoProgress,
                    ),
                    const SizedBox(height: 12),
                    _MediaTypeCard(
                      icon: Icons.movie_outlined,
                      label: 'Videos',
                      count: data.videoCount,
                      maximum: data.maxVideos,
                      progress: data.videoProgress,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _MediaTypeCard(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      count: data.photoCount,
                      maximum: data.maxPhotos,
                      progress: data.photoProgress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MediaTypeCard(
                      icon: Icons.movie_outlined,
                      label: 'Videos',
                      count: data.videoCount,
                      maximum: data.maxVideos,
                      progress: data.videoProgress,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  const _TotalBadge({
    required this.total,
  });

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.purple.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: CreatorDashboardTheme.purple.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '$total total',
        style: const TextStyle(
          color: CreatorDashboardTheme.silver,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MediaTypeCard extends StatelessWidget {
  const _MediaTypeCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.maximum,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final int count;
  final int maximum;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final remaining = (maximum - count).clamp(0, maximum);
    final color = CreatorDashboardTheme.progressColor(safeProgress);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CreatorDashboardTheme.panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: CreatorDashboardTheme.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: CreatorDashboardTheme.purple,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count / $maximum',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: safeProgress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            count > maximum
                ? '${count - maximum} over the limit'
                : '$remaining remaining',
            style: TextStyle(
              color: count > maximum
                  ? CreatorDashboardTheme.danger
                  : Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
