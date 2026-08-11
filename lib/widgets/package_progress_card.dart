import 'package:flutter/material.dart';

import '../services/package_builder_service.dart';
import '../theme/gallery_theme.dart';

/// Reusable build-progress panel for the TG Package Builder.
///
/// This widget is presentation-only. It does not start, cancel, or manage a
/// package build. The parent screen owns all build state and callbacks.
class PackageProgressCard extends StatelessWidget {
  const PackageProgressCard({
    super.key,
    required this.progress,
    required this.isBuilding,
    this.isComplete = false,
    this.onCancel,
    this.showWhenIdle = false,
  });

  final PackageBuildProgress? progress;
  final bool isBuilding;
  final bool isComplete;
  final VoidCallback? onCancel;
  final bool showWhenIdle;

  @override
  Widget build(BuildContext context) {
    if (!showWhenIdle && progress == null && !isBuilding && !isComplete) {
      return const SizedBox.shrink();
    }

    final normalizedProgress =
        (progress?.progress ?? (isComplete ? 1.0 : 0.0)).clamp(0.0, 1.0);

    final stage = progress?.stage;
    final status = _statusFor(
      stage: stage,
      isBuilding: isBuilding,
      isComplete: isComplete,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: status.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(
                status: status,
                isBuilding: isBuilding,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Build Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(
                label: status.badgeLabel,
                color: status.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressTrack(
            value: normalizedProgress,
            isBuilding: isBuilding,
            isComplete: isComplete,
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  progress?.message ?? status.defaultMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(normalizedProgress * 100).round()}%',
                style: TextStyle(
                  color: status.accentColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                _stageIcon(stage, isComplete),
                size: 16,
                color: GalleryColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _stageLabel(stage, isComplete),
                  style: const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isBuilding && onCancel != null)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    size: 18,
                  ),
                  label: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static _ProgressStatus _statusFor({
    required PackageBuildStage? stage,
    required bool isBuilding,
    required bool isComplete,
  }) {
    if (isComplete || stage == PackageBuildStage.completed) {
      return _ProgressStatus(
        badgeLabel: 'Complete',
        defaultMessage: 'TG package built successfully.',
        accentColor: Colors.greenAccent,
        borderColor: Colors.greenAccent.withValues(alpha: 0.35),
      );
    }

    if (isBuilding) {
      return _ProgressStatus(
        badgeLabel: 'Building',
        defaultMessage: 'Preparing your TG package...',
        accentColor: GalleryColors.purpleBright,
        borderColor: GalleryColors.purpleBright.withValues(alpha: 0.35),
      );
    }

    return _ProgressStatus(
      badgeLabel: 'Idle',
      defaultMessage: 'Waiting to start the package build.',
      accentColor: GalleryColors.silver,
      borderColor: const Color(0x447D6C8E),
    );
  }

  static String _stageLabel(
    PackageBuildStage? stage,
    bool isComplete,
  ) {
    if (isComplete) {
      return 'Complete';
    }

    return switch (stage) {
      PackageBuildStage.validating => 'Validation',
      PackageBuildStage.creatingWorkspace => 'Workspace setup',
      PackageBuildStage.copyingCover => 'Cover transfer',
      PackageBuildStage.copyingMedia => 'Media transfer',
      PackageBuildStage.writingCard => 'Card metadata',
      PackageBuildStage.writingManifest => 'Manifest generation',
      PackageBuildStage.compressing => 'Archive compression',
      PackageBuildStage.hashing => 'Integrity check',
      PackageBuildStage.cleaningUp => 'Temporary-file cleanup',
      PackageBuildStage.completed => 'Complete',
      null => 'Waiting',
    };
  }

  static IconData _stageIcon(
    PackageBuildStage? stage,
    bool isComplete,
  ) {
    if (isComplete) {
      return Icons.verified_rounded;
    }

    return switch (stage) {
      PackageBuildStage.validating => Icons.fact_check_rounded,
      PackageBuildStage.creatingWorkspace => Icons.create_new_folder_rounded,
      PackageBuildStage.copyingCover => Icons.image_rounded,
      PackageBuildStage.copyingMedia => Icons.perm_media_rounded,
      PackageBuildStage.writingCard => Icons.description_rounded,
      PackageBuildStage.writingManifest => Icons.data_object_rounded,
      PackageBuildStage.compressing => Icons.folder_zip_rounded,
      PackageBuildStage.hashing => Icons.fingerprint_rounded,
      PackageBuildStage.cleaningUp => Icons.cleaning_services_rounded,
      PackageBuildStage.completed => Icons.verified_rounded,
      null => Icons.hourglass_empty_rounded,
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.status,
    required this.isBuilding,
  });

  final _ProgressStatus status;
  final bool isBuilding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: status.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status.accentColor.withValues(alpha: 0.30),
        ),
      ),
      child: Center(
        child: isBuilding
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: status.accentColor,
                ),
              )
            : Icon(
                status.badgeLabel == 'Complete'
                    ? Icons.check_circle_rounded
                    : Icons.bolt_rounded,
                color: status.accentColor,
                size: 23,
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.value,
    required this.isBuilding,
    required this.isComplete,
  });

  final double value;
  final bool isBuilding;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: isBuilding || isComplete ? value : 0,
        minHeight: 11,
        backgroundColor: GalleryColors.panel,
        valueColor: AlwaysStoppedAnimation<Color>(
          isComplete ? Colors.greenAccent : GalleryColors.purpleBright,
        ),
      ),
    );
  }
}

class _ProgressStatus {
  const _ProgressStatus({
    required this.badgeLabel,
    required this.defaultMessage,
    required this.accentColor,
    required this.borderColor,
  });

  final String badgeLabel;
  final String defaultMessage;
  final Color accentColor;
  final Color borderColor;
}
