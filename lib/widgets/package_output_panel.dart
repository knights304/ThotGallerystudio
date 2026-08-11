import 'package:flutter/material.dart';

import '../../../theme/gallery_theme.dart';

class PackageOutputPanel extends StatelessWidget {
  const PackageOutputPanel({
    super.key,
    required this.outputPath,
    required this.expectedFilename,
    required this.onChooseDirectory,
    this.isBuilding = false,
  });

  final String? outputPath;
  final String expectedFilename;
  final VoidCallback? onChooseDirectory;
  final bool isBuilding;

  @override
  Widget build(BuildContext context) {
    final displayedPath = outputPath?.trim().isNotEmpty == true
        ? outputPath!
        : 'No output folder selected';

    return Container(
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            onChooseDirectory: isBuilding ? null : onChooseDirectory,
          ),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Package folder'),
                const SizedBox(height: 6),
                SelectableText(
                  displayedPath,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 15),
                const _FieldLabel('Output filename'),
                const SizedBox(height: 6),
                SelectableText(
                  expectedFilename,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.onChooseDirectory,
  });

  final VoidCallback? onChooseDirectory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: GalleryColors.purpleDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_zip_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Output',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onChooseDirectory,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Choose'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: GalleryColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
