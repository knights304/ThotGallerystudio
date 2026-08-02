import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/gallery_card.dart';
import '../models/tg_package_manifest.dart';
import 'package_validation_service.dart';

enum PackageBuildStage {
  validating,
  creatingWorkspace,
  copyingCover,
  copyingMedia,
  writingCard,
  writingManifest,
  compressing,
  hashing,
  cleaningUp,
  completed,
}

class PackageBuildProgress {
  const PackageBuildProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });

  final PackageBuildStage stage;
  final double progress;
  final String message;
}

class PackageBuildResult {
  const PackageBuildResult({
    required this.packageFile,
    required this.manifest,
    required this.validation,
  });

  final File packageFile;
  final TGPackageManifest manifest;
  final PackageValidationReport validation;
}

class PackageBuilderService {
  const PackageBuilderService._();

  static Future<PackageBuildResult> buildPackage({
    required GalleryCard card,
    required Directory outputDirectory,
    void Function(PackageBuildProgress progress)? onProgress,
  }) async {
    void update(
      PackageBuildStage stage,
      double progress,
      String message,
    ) {
      onProgress?.call(
        PackageBuildProgress(
          stage: stage,
          progress: progress,
          message: message,
        ),
      );
    }

    update(
      PackageBuildStage.validating,
      0.05,
      'Validating package...',
    );

    final validation = await PackageValidationService.validate(card);
    if (!validation.canBuild) {
      throw Exception('Package validation failed.');
    }

    final tempDir = await Directory.systemTemp.createTemp('tgpkg_');

    try {
      update(
        PackageBuildStage.creatingWorkspace,
        0.10,
        'Creating workspace...',
      );

      final coverDir = Directory(p.join(tempDir.path, 'cover'));
      final mediaDir = Directory(p.join(tempDir.path, 'media'));

      await coverDir.create(recursive: true);
      await mediaDir.create(recursive: true);

      final fileHashes = <String, String>{};
      var coverRelativePath = '';

      final coverSourcePath = card.coverImagePath?.trim() ?? '';
      if (coverSourcePath.isNotEmpty) {
        update(
          PackageBuildStage.copyingCover,
          0.20,
          'Copying cover...',
        );

        final coverSource = File(coverSourcePath);
        final coverName = _safeCoverFilename(coverSourcePath);
        coverRelativePath = 'cover/$coverName';
        final coverTarget = File(p.join(tempDir.path, coverRelativePath));

        await coverSource.copy(coverTarget.path);
        fileHashes[coverRelativePath] = await _sha256File(coverTarget);
      }

      update(
        PackageBuildStage.copyingMedia,
        0.35,
        'Copying media...',
      );

      final mediaRelativePaths = <String>[];

      for (var index = 0; index < card.media.length; index++) {
        final media = card.media[index];
        final source = File(media.path);
        final packageName = _safeMediaFilename(
          index: index,
          mediaId: media.id,
          sourcePath: media.path,
        );
        final relativePath = 'media/$packageName';
        final target = File(p.join(tempDir.path, relativePath));

        await source.copy(target.path);
        mediaRelativePaths.add(relativePath);
        fileHashes[relativePath] = await _sha256File(target);
      }

      update(
        PackageBuildStage.writingCard,
        0.55,
        'Writing portable card.json...',
      );

      const cardRelativePath = 'card.json';
      final cardFile = File(p.join(tempDir.path, cardRelativePath));
      final portableCardJson = _buildPortableCardJson(
        card,
        coverRelativePath: coverRelativePath,
        mediaRelativePaths: mediaRelativePaths,
      );
      final cardJsonText =
          const JsonEncoder.withIndent('  ').convert(portableCardJson);

      await cardFile.writeAsString(cardJsonText, flush: true);
      fileHashes[cardRelativePath] = await _sha256File(cardFile);

      update(
        PackageBuildStage.writingManifest,
        0.68,
        'Writing verification manifest...',
      );

      var manifest = TGPackageManifest.fromCard(
        card,
        cardFile: cardRelativePath,
        coverFile: coverRelativePath,
        mediaFiles: mediaRelativePaths,
        fileHashes: fileHashes,
      );

      final manifestFile = File(p.join(tempDir.path, 'tg_manifest.json'));
      await manifestFile.writeAsString(
        manifest.toPrettyJson(),
        flush: true,
      );

      update(
        PackageBuildStage.compressing,
        0.80,
        'Compressing package...',
      );

      await outputDirectory.create(recursive: true);

      final outPath = p.join(
        outputDirectory.path,
        '${_safePackageBaseName(card.title)}.tgpack',
      );

      final existingPackage = File(outPath);
      if (await existingPackage.exists()) {
        await existingPackage.delete();
      }

      final encoder = ZipFileEncoder();
      encoder.create(outPath);
      encoder.addDirectory(tempDir);
      encoder.close();

      update(
        PackageBuildStage.hashing,
        0.92,
        'Calculating archive hash...',
      );

      final packageFile = File(outPath);
      final packageHash = await _sha256File(packageFile);
      final packageSizeBytes = await packageFile.length();

      // The final archive hash cannot be embedded into the archive without
      // changing that same hash. The embedded manifest verifies the package
      // contents through fileHashes; this returned manifest additionally
      // reports the final archive hash and compressed size to the UI/caller.
      manifest = manifest.copyWith(
        packageHash: packageHash,
        packageSizeBytes: packageSizeBytes,
      );

      update(
        PackageBuildStage.completed,
        1.0,
        'Package complete.',
      );

      return PackageBuildResult(
        packageFile: packageFile,
        manifest: manifest,
        validation: validation,
      );
    } finally {
      update(
        PackageBuildStage.cleaningUp,
        0.98,
        'Cleaning temporary files...',
      );

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  static Map<String, dynamic> _buildPortableCardJson(
    GalleryCard card, {
    required String coverRelativePath,
    required List<String> mediaRelativePaths,
  }) {
    final json = Map<String, dynamic>.from(card.toJson());

    json['coverImagePath'] =
        coverRelativePath.isEmpty ? null : coverRelativePath;

    json['media'] = [
      for (var index = 0; index < card.media.length; index++)
        <String, dynamic>{
          ...card.media[index].toJson(),
          'path': mediaRelativePaths[index],
          // Thumbnail files are not currently packaged. Avoid leaking a local
          // device path into a portable package.
          'thumbnailPath': null,
        },
    ];

    return json;
  }

  static String _safePackageBaseName(String title) {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.isEmpty ? 'untitled_gallery_piece' : cleaned;
  }

  static String _safeCoverFilename(String sourcePath) {
    final original = p.basename(sourcePath);
    final stem = _safeSegment(p.basenameWithoutExtension(original));
    final extension = p.extension(original).toLowerCase();

    return 'cover_${stem.isEmpty ? 'image' : stem}$extension';
  }

  static String _safeMediaFilename({
    required int index,
    required String mediaId,
    required String sourcePath,
  }) {
    final original = p.basename(sourcePath);
    final stem = _safeSegment(p.basenameWithoutExtension(original));
    final extension = p.extension(original).toLowerCase();
    final safeId = _safeSegment(mediaId);
    final sequence = (index + 1).toString().padLeft(4, '0');

    return '${sequence}_${safeId.isEmpty ? 'media' : safeId}_'
        '${stem.isEmpty ? 'file' : stem}$extension';
  }

  static String _safeSegment(String value) {
    var cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'_+'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');

    if (cleaned.length > 64) {
      cleaned = cleaned.substring(0, 64);
    }

    return cleaned;
  }

  static Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
