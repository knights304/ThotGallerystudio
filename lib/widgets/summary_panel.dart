import 'dart:io';

import 'package:flutter/material.dart';

import '../models/gallery_card.dart';
import '../services/package_validation_service.dart';
import '../theme/gallery_theme.dart';

/// Reusable package overview card for the TG Package Builder.
///
/// This widget is presentation-only. It does not run validation, mutate the
/// GalleryCard, or start package builds.
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    super.key,
    required this.card,
    this.validation,
    this.packageFormatLabel = '.tgpack v1',
  });

  final GalleryCard card;
  final PackageValidationReport? validation;
  final String packageFormatLabel;

  @override
  Widget build(BuildContext context) {
    final coverPath = card.coverImagePath?.trim();
    final hasCover = coverPath != null &&
        coverPath.isNotEmpty &&
        File(coverPath).existsSync();

    final photoCount = validation?.photoCount ?? _photoCount(card);
    final videoCount = validation?.videoCount ?? _videoCount(card);
    final estimatedSize =
        validation?.estimatedSizeLabel ?? _fallbackSizeLabel(card);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0x447D6C8E),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(),
          const SizedBox(height: 17),
          LayoutBuilder(
            builder: (context, constraints) {
              final useStackedLayout = constraints.maxWidth < 430;

              if (useStackedLayout) {
                return Column(
                  children: [
                    _CoverPreview(
                      coverPath: coverPath,
                      hasCover: hasCover,
                      width: double.infinity,
                      height: 220,
                    ),
                    const SizedBox(height: 16),
                    _MetadataList(
                      card: card,
                      packageFormatLabel: packageFormatLabel,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoverPreview(
                    coverPath: coverPath,
                    hasCover: hasCover,
                    width: 118,
                    height: 148,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _MetadataList(
                      card: card,
                      packageFormatLabel: packageFormatLabel,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 470) {
                return Column(
                  children: [
                    _MetricTile(
                      icon: Icons.photo_library_rounded,
                      value: '$photoCount',
                      label: 'Photos',
                    ),
                    const SizedBox(height: 10),
                    _MetricTile(
                      icon: Icons.movie_rounded,
                      value: '$videoCount',
                      label: 'Videos',
                    ),
                    const SizedBox(height: 10),
                    _MetricTile(
                      icon: Icons.sd_storage_rounded,
                      value: estimatedSize,
                      label: 'Estimated size',
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.photo_library_rounded,
                      value: '$photoCount',
                      label: 'Photos',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.movie_rounded,
                      value: '$videoCount',
                      label: 'Videos',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.sd_storage_rounded,
                      value: estimatedSize,
                      label: 'Estimated',
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

  static int _photoCount(GalleryCard card) {
    return card.media
        .where((item) => item.type == GalleryMediaType.photo)
        .length;
  }

  static int _videoCount(GalleryCard card) {
    return card.media
        .where((item) => item.type == GalleryMediaType.video)
        .length;
  }

  static String _fallbackSizeLabel(GalleryCard card) {
    final knownBytes = card.media.fold<int>(
      0,
      (total, item) => total + item.sizeBytes,
    );

    if (knownBytes <= 0) {
      return 'Calculating';
    }

    return PackageValidationService.formatBytes(knownBytes);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.dashboard_customize_rounded,
          color: GalleryColors.purpleBright,
        ),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Summary Panel',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.coverPath,
    required this.hasCover,
    required this.width,
    required this.height,
  });

  final String? coverPath;
  final bool hasCover;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: 0.30),
        ),
      ),
      child: hasCover
          ? Image.file(
              File(coverPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _MissingCoverPreview(),
            )
          : const _MissingCoverPreview(),
    );
  }
}

class _MetadataList extends StatelessWidget {
  const _MetadataList({
    required this.card,
    required this.packageFormatLabel,
  });

  final GalleryCard card;
  final String packageFormatLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryRow(
          label: 'Card',
          value: card.title.trim().isEmpty ? 'Untitled' : card.title.trim(),
        ),
        _SummaryRow(
          label: 'Set',
          value: card.setName.trim().isEmpty
              ? 'Not assigned'
              : card.setName.trim(),
        ),
        _SummaryRow(
          label: 'Rarity',
          value:
              card.rarity.trim().isEmpty ? 'Not assigned' : card.rarity.trim(),
        ),
        _SummaryRow(
          label: 'Card number',
          value: '${card.cardNumber} / ${card.setTotal}',
        ),
        _SummaryRow(
          label: 'Package format',
          value: packageFormatLabel,
          isLast: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: GalleryColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: GalleryColors.purpleBright,
            size: 21,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GalleryColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingCoverPreview extends StatelessWidget {
  const _MissingCoverPreview();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: GalleryColors.panel,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: GalleryColors.muted,
              size: 38,
            ),
            SizedBox(height: 8),
            Text(
              'No cover',
              style: TextStyle(
                color: GalleryColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
