import 'package:flutter/material.dart';

import '../../../theme/gallery_theme.dart';

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    super.key,
    required this.progress,
    required this.status,
    required this.isBuilding,
    this.outputPath,
  });

  final double progress;
  final String? status;
  final bool isBuilding;
  final String? outputPath;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: 20),

            LinearProgressIndicator(
              value: isBuilding ? progress : null,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Text(
                    status ?? 'Ready to build package',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (outputPath != null &&
                outputPath!.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              const Text(
                'Output',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              SelectableText(
                outputPath!,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.auto_awesome_rounded),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Build Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
