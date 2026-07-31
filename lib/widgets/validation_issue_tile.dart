import 'package:flutter/material.dart';

import '../services/package_validation_service.dart';
import '../theme/gallery_theme.dart';

/// Reusable presentation widget for one package-validation result.
///
/// This widget contains no validation logic. It only renders the supplied
/// [PackageValidationIssue].
class ValidationIssueTile extends StatelessWidget {
  const ValidationIssueTile({
    super.key,
    required this.issue,
    this.showFilePath = true,
    this.compact = false,
  });

  final PackageValidationIssue issue;
  final bool showFilePath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(issue.severity);
    final hasFilePath = showFilePath &&
        issue.filePath != null &&
        issue.filePath!.trim().isNotEmpty;

    return Semantics(
      container: true,
      label: '${presentation.label}: ${issue.title}. ${issue.message}',
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(compact ? 15 : 18),
          border: Border.all(
            color: presentation.color.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SeverityIcon(
              icon: presentation.icon,
              color: presentation.color,
              compact: compact,
            ),
            SizedBox(width: compact ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          issue.title,
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SeverityBadge(
                        label: presentation.label,
                        color: presentation.color,
                        compact: compact,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  Text(
                    issue.message,
                    style: TextStyle(
                      color: GalleryColors.muted,
                      fontSize: compact ? 12 : 13,
                      height: 1.4,
                    ),
                  ),
                  if (hasFilePath) ...[
                    SizedBox(height: compact ? 7 : 9),
                    _FilePathRow(
                      filePath: issue.filePath!.trim(),
                      compact: compact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _IssuePresentation _presentationFor(
    PackageValidationSeverity severity,
  ) {
    return switch (severity) {
      PackageValidationSeverity.error => const _IssuePresentation(
          label: 'Error',
          icon: Icons.cancel_rounded,
          color: Colors.redAccent,
        ),
      PackageValidationSeverity.warning => const _IssuePresentation(
          label: 'Warning',
          icon: Icons.warning_amber_rounded,
          color: Colors.amber,
        ),
      PackageValidationSeverity.info => const _IssuePresentation(
          label: 'Info',
          icon: Icons.info_rounded,
          color: Colors.lightBlueAccent,
        ),
    };
  }
}

class _SeverityIcon extends StatelessWidget {
  const _SeverityIcon({
    required this.icon,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 40.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 11 : 13),
      ),
      child: Icon(
        icon,
        color: color,
        size: compact ? 19 : 22,
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({
    required this.label,
    required this.color,
    required this.compact,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _FilePathRow extends StatelessWidget {
  const _FilePathRow({
    required this.filePath,
    required this.compact,
  });

  final String filePath;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: GalleryColors.panel.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: compact ? 14 : 16,
            color: GalleryColors.silver,
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: SelectableText(
              filePath,
              maxLines: compact ? 1 : 2,
              style: TextStyle(
                color: GalleryColors.silver,
                fontSize: compact ? 10 : 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssuePresentation {
  const _IssuePresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
