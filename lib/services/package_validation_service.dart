import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/gallery_card.dart';

enum PackageValidationSeverity {
  info,
  warning,
  error,
}

enum PackageValidationCode {
  missingTitle,
  missingDescription,
  missingCover,
  missingCoverFile,
  missingMedia,
  missingMediaFile,
  duplicateMediaPath,
  duplicateMediaHash,
  emptyMediaPath,
  invalidMediaSize,
  invalidPhotoDimensions,
  invalidVideoDuration,
  missingFingerprint,
  missingSetName,
  invalidCardNumber,
  invalidSetTotal,
  cardNumberExceedsSetTotal,
  missingRarity,
  largePackage,
  veryLargePackage,
  validPackage,
}

class PackageValidationIssue {
  const PackageValidationIssue({
    required this.code,
    required this.severity,
    required this.title,
    required this.message,
    this.filePath,
    this.mediaId,
  });

  final PackageValidationCode code;
  final PackageValidationSeverity severity;
  final String title;
  final String message;
  final String? filePath;
  final String? mediaId;

  bool get isError => severity == PackageValidationSeverity.error;

  bool get isWarning => severity == PackageValidationSeverity.warning;

  bool get isInfo => severity == PackageValidationSeverity.info;

  Map<String, dynamic> toJson() {
    return {
      'code': code.name,
      'severity': severity.name,
      'title': title,
      'message': message,
      'filePath': filePath,
      'mediaId': mediaId,
    };
  }
}

class PackageValidationReport {
  const PackageValidationReport({
    required this.issues,
    required this.estimatedSizeBytes,
    required this.existingFileCount,
    required this.missingFileCount,
    required this.photoCount,
    required this.videoCount,
    required this.createdAt,
  });

  final List<PackageValidationIssue> issues;
  final int estimatedSizeBytes;
  final int existingFileCount;
  final int missingFileCount;
  final int photoCount;
  final int videoCount;
  final DateTime createdAt;

  List<PackageValidationIssue> get errors {
    return issues.where((issue) => issue.isError).toList(growable: false);
  }

  List<PackageValidationIssue> get warnings {
    return issues.where((issue) => issue.isWarning).toList(growable: false);
  }

  List<PackageValidationIssue> get information {
    return issues.where((issue) => issue.isInfo).toList(growable: false);
  }

  bool get isValid => errors.isEmpty;

  bool get canBuild => isValid;

  int get errorCount => errors.length;

  int get warningCount => warnings.length;

  int get informationCount => information.length;

  int get totalMediaCount => photoCount + videoCount;

  String get estimatedSizeLabel {
    return PackageValidationService.formatBytes(estimatedSizeBytes);
  }

  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'canBuild': canBuild,
      'estimatedSizeBytes': estimatedSizeBytes,
      'existingFileCount': existingFileCount,
      'missingFileCount': missingFileCount,
      'photoCount': photoCount,
      'videoCount': videoCount,
      'createdAt': createdAt.toIso8601String(),
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
}

class PackageValidationService {
  const PackageValidationService._();

  static const int largePackageThresholdBytes = 1024 * 1024 * 1024;

  static const int veryLargePackageThresholdBytes = 4 * 1024 * 1024 * 1024;

  static Future<PackageValidationReport> validate(
    GalleryCard card,
  ) async {
    final issues = <PackageValidationIssue>[];

    var estimatedSizeBytes = 0;
    var existingFileCount = 0;
    var missingFileCount = 0;
    var photoCount = 0;
    var videoCount = 0;

    _validateCardMetadata(card, issues);

    final normalizedPaths = <String, GalleryMediaItem>{};
    final contentHashes = <String, GalleryMediaItem>{};

    final coverPath = card.coverImagePath?.trim() ?? '';

    if (coverPath.isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingCover,
          severity: PackageValidationSeverity.error,
          title: 'Cover image required',
          message: 'Choose a cover image before building the TG package.',
        ),
      );
    } else {
      final coverFile = File(coverPath);

      if (!await coverFile.exists()) {
        missingFileCount++;

        issues.add(
          PackageValidationIssue(
            code: PackageValidationCode.missingCoverFile,
            severity: PackageValidationSeverity.error,
            title: 'Cover file is missing',
            message:
                'The selected cover image could not be found on this device.',
            filePath: coverPath,
          ),
        );
      } else {
        existingFileCount++;

        try {
          estimatedSizeBytes += await coverFile.length();
        } on FileSystemException {
          issues.add(
            PackageValidationIssue(
              code: PackageValidationCode.missingCoverFile,
              severity: PackageValidationSeverity.error,
              title: 'Cover file cannot be read',
              message:
                  'The selected cover exists but TG could not read its size.',
              filePath: coverPath,
            ),
          );
        }
      }
    }

    if (card.media.isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingMedia,
          severity: PackageValidationSeverity.error,
          title: 'Media required',
          message:
              'Add at least one photo or video before building the package.',
        ),
      );
    }

    for (final media in card.media) {
      if (media.type == GalleryMediaType.photo) {
        photoCount++;
      } else {
        videoCount++;
      }

      final mediaPath = media.path.trim();

      if (mediaPath.isEmpty) {
        missingFileCount++;

        issues.add(
          PackageValidationIssue(
            code: PackageValidationCode.emptyMediaPath,
            severity: PackageValidationSeverity.error,
            title: 'Media path is empty',
            message: 'A media item does not contain a usable file path.',
            mediaId: media.id,
          ),
        );

        continue;
      }

      final normalizedPath = _normalizePath(mediaPath);
      final duplicatePathItem = normalizedPaths[normalizedPath];

      if (duplicatePathItem != null) {
        issues.add(
          PackageValidationIssue(
            code: PackageValidationCode.duplicateMediaPath,
            severity: PackageValidationSeverity.warning,
            title: 'Duplicate media file',
            message:
                '${p.basename(mediaPath)} appears more than once in this card.',
            filePath: mediaPath,
            mediaId: media.id,
          ),
        );
      } else {
        normalizedPaths[normalizedPath] = media;
      }

      final hash = media.contentHash.trim().toLowerCase();

      if (hash.isNotEmpty) {
        final duplicateHashItem = contentHashes[hash];

        if (duplicateHashItem != null && duplicateHashItem.path != media.path) {
          issues.add(
            PackageValidationIssue(
              code: PackageValidationCode.duplicateMediaHash,
              severity: PackageValidationSeverity.warning,
              title: 'Possible duplicate content',
              message:
                  '${p.basename(mediaPath)} appears to contain the same data as another media file.',
              filePath: mediaPath,
              mediaId: media.id,
            ),
          );
        } else {
          contentHashes[hash] = media;
        }
      }

      final mediaFile = File(mediaPath);

      if (!await mediaFile.exists()) {
        missingFileCount++;

        issues.add(
          PackageValidationIssue(
            code: PackageValidationCode.missingMediaFile,
            severity: PackageValidationSeverity.error,
            title: 'Media file is missing',
            message:
                '${p.basename(mediaPath)} could not be found on this device.',
            filePath: mediaPath,
            mediaId: media.id,
          ),
        );

        continue;
      }

      existingFileCount++;

      try {
        final actualSize = await mediaFile.length();
        estimatedSizeBytes += actualSize;

        if (actualSize <= 0) {
          issues.add(
            PackageValidationIssue(
              code: PackageValidationCode.invalidMediaSize,
              severity: PackageValidationSeverity.error,
              title: 'Media file is empty',
              message: '${p.basename(mediaPath)} contains no readable data.',
              filePath: mediaPath,
              mediaId: media.id,
            ),
          );
        }
      } on FileSystemException {
        issues.add(
          PackageValidationIssue(
            code: PackageValidationCode.invalidMediaSize,
            severity: PackageValidationSeverity.error,
            title: 'Media file cannot be read',
            message: 'TG could not read ${p.basename(mediaPath)}.',
            filePath: mediaPath,
            mediaId: media.id,
          ),
        );
      }

      _validateMediaMetadata(media, issues);
    }

    _validatePackageSize(
      estimatedSizeBytes,
      issues,
    );

    if (!issues.any((issue) => issue.isError || issue.isWarning)) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.validPackage,
          severity: PackageValidationSeverity.info,
          title: 'Package is ready',
          message: 'All required metadata and media files passed validation.',
        ),
      );
    }

    return PackageValidationReport(
      issues: List.unmodifiable(issues),
      estimatedSizeBytes: estimatedSizeBytes,
      existingFileCount: existingFileCount,
      missingFileCount: missingFileCount,
      photoCount: photoCount,
      videoCount: videoCount,
      createdAt: DateTime.now().toUtc(),
    );
  }

  static void _validateCardMetadata(
    GalleryCard card,
    List<PackageValidationIssue> issues,
  ) {
    if (card.title.trim().isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingTitle,
          severity: PackageValidationSeverity.error,
          title: 'Title required',
          message: 'Enter a title before building the TG package.',
        ),
      );
    }

    if (card.description.trim().isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingDescription,
          severity: PackageValidationSeverity.warning,
          title: 'Description is empty',
          message:
              'Adding a description will make the package easier to identify and browse.',
        ),
      );
    }

    if (card.setName.trim().isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingSetName,
          severity: PackageValidationSeverity.warning,
          title: 'Set name is empty',
          message: 'Add a set name to keep exported cards organized.',
        ),
      );
    }

    if (card.rarity.trim().isEmpty) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.missingRarity,
          severity: PackageValidationSeverity.warning,
          title: 'Rarity is empty',
          message: 'Choose a rarity before publishing this card.',
        ),
      );
    }

    if (card.cardNumber < 1) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.invalidCardNumber,
          severity: PackageValidationSeverity.error,
          title: 'Invalid card number',
          message: 'The card number must be at least 1.',
        ),
      );
    }

    if (card.setTotal < 1) {
      issues.add(
        const PackageValidationIssue(
          code: PackageValidationCode.invalidSetTotal,
          severity: PackageValidationSeverity.error,
          title: 'Invalid set total',
          message: 'The total number of cards in the set must be at least 1.',
        ),
      );
    }

    if (card.cardNumber > card.setTotal && card.setTotal > 0) {
      issues.add(
        PackageValidationIssue(
          code: PackageValidationCode.cardNumberExceedsSetTotal,
          severity: PackageValidationSeverity.warning,
          title: 'Card number exceeds set total',
          message:
              'Card ${card.cardNumber} is greater than the set total of ${card.setTotal}.',
        ),
      );
    }

    if (card.fingerprint.trim().isEmpty) {
      card.ensureFingerprint();

      if (card.fingerprint.trim().isEmpty) {
        issues.add(
          const PackageValidationIssue(
            code: PackageValidationCode.missingFingerprint,
            severity: PackageValidationSeverity.error,
            title: 'Fingerprint unavailable',
            message: 'TG could not generate a fingerprint for this card.',
          ),
        );
      }
    }
  }

  static void _validateMediaMetadata(
    GalleryMediaItem media,
    List<PackageValidationIssue> issues,
  ) {
    final filename = p.basename(media.path);

    if (media.type == GalleryMediaType.photo &&
        (media.width <= 0 || media.height <= 0)) {
      issues.add(
        PackageValidationIssue(
          code: PackageValidationCode.invalidPhotoDimensions,
          severity: PackageValidationSeverity.warning,
          title: 'Photo dimensions unavailable',
          message:
              '$filename does not contain recorded width and height metadata.',
          filePath: media.path,
          mediaId: media.id,
        ),
      );
    }

    if (media.type == GalleryMediaType.video &&
        media.durationMilliseconds <= 0) {
      issues.add(
        PackageValidationIssue(
          code: PackageValidationCode.invalidVideoDuration,
          severity: PackageValidationSeverity.warning,
          title: 'Video duration unavailable',
          message: '$filename does not contain recorded duration metadata.',
          filePath: media.path,
          mediaId: media.id,
        ),
      );
    }
  }

  static void _validatePackageSize(
    int sizeBytes,
    List<PackageValidationIssue> issues,
  ) {
    if (sizeBytes >= veryLargePackageThresholdBytes) {
      issues.add(
        PackageValidationIssue(
          code: PackageValidationCode.veryLargePackage,
          severity: PackageValidationSeverity.warning,
          title: 'Very large package',
          message:
              'This package is approximately ${formatBytes(sizeBytes)} and may take a long time to build or share.',
        ),
      );

      return;
    }

    if (sizeBytes >= largePackageThresholdBytes) {
      issues.add(
        PackageValidationIssue(
          code: PackageValidationCode.largePackage,
          severity: PackageValidationSeverity.warning,
          title: 'Large package',
          message: 'This package is approximately ${formatBytes(sizeBytes)}.',
        ),
      );
    }
  }

  static String _normalizePath(String value) {
    try {
      return p.normalize(File(value).absolute.path).toLowerCase();
    } catch (_) {
      return p.normalize(value).toLowerCase();
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const kilobyte = 1024;
    const megabyte = kilobyte * 1024;
    const gigabyte = megabyte * 1024;
    const terabyte = gigabyte * 1024;

    if (bytes >= terabyte) {
      return '${(bytes / terabyte).toStringAsFixed(2)} TB';
    }

    if (bytes >= gigabyte) {
      return '${(bytes / gigabyte).toStringAsFixed(2)} GB';
    }

    if (bytes >= megabyte) {
      return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    }

    if (bytes >= kilobyte) {
      return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }
}
