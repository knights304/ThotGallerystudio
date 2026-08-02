import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/gallery_card.dart';
import '../models/tg_package_manifest.dart';

enum PackageImportIssueSeverity {
  error,
  warning,
  info,
}

class PackageImportIssue {
  const PackageImportIssue({
    required this.severity,
    required this.message,
    this.path,
  });

  final PackageImportIssueSeverity severity;
  final String message;
  final String? path;
}

class PackageImportInspection {
  const PackageImportInspection({
    required this.packageFile,
    required this.issues,
    this.manifest,
    this.card,
    this.extractionDirectory,
  });

  final File packageFile;
  final List<PackageImportIssue> issues;
  final TGPackageManifest? manifest;
  final GalleryCard? card;
  final Directory? extractionDirectory;

  bool get isValid =>
      manifest != null &&
      card != null &&
      !issues.any(
        (issue) => issue.severity == PackageImportIssueSeverity.error,
      );

  int get errorCount => issues
      .where((issue) => issue.severity == PackageImportIssueSeverity.error)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == PackageImportIssueSeverity.warning)
      .length;

  Future<void> dispose() async {
    final directory = extractionDirectory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class PackageImportService {
  const PackageImportService._();

  static Future<PackageImportInspection> inspectPackage(
      File packageFile) async {
    final issues = <PackageImportIssue>[];
    Directory? extractionDirectory;

    try {
      if (!await packageFile.exists()) {
        return PackageImportInspection(
          packageFile: packageFile,
          issues: const [
            PackageImportIssue(
              severity: PackageImportIssueSeverity.error,
              message: 'The selected package file does not exist.',
            ),
          ],
        );
      }

      if (p.extension(packageFile.path).toLowerCase() != '.tgpack') {
        issues.add(
          const PackageImportIssue(
            severity: PackageImportIssueSeverity.warning,
            message: 'The selected file does not use the .tgpack extension.',
          ),
        );
      }

      extractionDirectory = await Directory.systemTemp.createTemp('tgimport_');

      final input = InputFileStream(packageFile.path);
      late final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input, verify: true);
      } finally {
        await input.close();
      }

      for (final entry in archive) {
        final relativePath = _normalizedPackagePath(entry.name);

        if (relativePath == null) {
          issues.add(
            PackageImportIssue(
              severity: PackageImportIssueSeverity.error,
              message: 'Unsafe archive path detected.',
              path: entry.name,
            ),
          );
          continue;
        }

        if (entry.isSymbolicLink) {
          issues.add(
            PackageImportIssue(
              severity: PackageImportIssueSeverity.error,
              message: 'Symbolic links are not allowed in TG packages.',
              path: relativePath,
            ),
          );
          continue;
        }

        final targetPath = p.joinAll([
          extractionDirectory.path,
          ...p.posix.split(relativePath),
        ]);

        if (entry.isFile) {
          final targetFile = File(targetPath);
          await targetFile.parent.create(recursive: true);

          final output = OutputFileStream(targetFile.path);
          try {
            entry.writeContent(output);
          } finally {
            await output.close();
          }
        } else {
          await Directory(targetPath).create(recursive: true);
        }
      }

      if (_hasErrors(issues)) {
        return PackageImportInspection(
          packageFile: packageFile,
          issues: List.unmodifiable(issues),
          extractionDirectory: extractionDirectory,
        );
      }

      final manifestFile = File(
        p.join(extractionDirectory.path, 'tg_manifest.json'),
      );

      if (!await manifestFile.exists()) {
        issues.add(
          const PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Package is missing tg_manifest.json.',
            path: 'tg_manifest.json',
          ),
        );

        return PackageImportInspection(
          packageFile: packageFile,
          issues: List.unmodifiable(issues),
          extractionDirectory: extractionDirectory,
        );
      }

      final manifestJson = _decodeJsonObject(
        await manifestFile.readAsString(),
        label: 'tg_manifest.json',
      );
      final manifest = TGPackageManifest.fromJson(manifestJson);

      if (manifest.packageVersion != tgPackageVersion) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message:
                'Unsupported TG package version ${manifest.packageVersion}. '
                'This app supports version $tgPackageVersion.',
          ),
        );
      }

      if (manifest.fileHashes.isEmpty) {
        issues.add(
          const PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Package does not contain a file integrity table.',
          ),
        );
      }

      await _verifyHashes(
        extractionDirectory: extractionDirectory,
        manifest: manifest,
        issues: issues,
      );

      final cardRelativePath =
          _normalizedPackagePath(manifest.cardFile) ?? 'card.json';
      final cardFile = File(
        p.joinAll([
          extractionDirectory.path,
          ...p.posix.split(cardRelativePath),
        ]),
      );

      if (!await cardFile.exists()) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Package card metadata file is missing.',
            path: manifest.cardFile,
          ),
        );

        return PackageImportInspection(
          packageFile: packageFile,
          issues: List.unmodifiable(issues),
          manifest: manifest,
          extractionDirectory: extractionDirectory,
        );
      }

      final portableCardJson = _decodeJsonObject(
        await cardFile.readAsString(),
        label: manifest.cardFile,
      );

      _validateManifestAgainstCard(
        manifest: manifest,
        cardJson: portableCardJson,
        issues: issues,
      );

      final resolvedCardJson = _resolveCardPaths(
        portableCardJson,
        extractionDirectory,
        issues,
      );

      GalleryCard? card;
      if (!_hasErrors(issues)) {
        card = GalleryCard.fromJson(resolvedCardJson);
      }

      if (!_hasErrors(issues)) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.info,
            message:
                'TG Package v${manifest.packageVersion} verified successfully.',
          ),
        );
      }

      return PackageImportInspection(
        packageFile: packageFile,
        issues: List.unmodifiable(issues),
        manifest: manifest,
        card: card,
        extractionDirectory: extractionDirectory,
      );
    } catch (error) {
      issues.add(
        PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Could not inspect package: $error',
        ),
      );

      return PackageImportInspection(
        packageFile: packageFile,
        issues: List.unmodifiable(issues),
        extractionDirectory: extractionDirectory,
      );
    }
  }

  static Future<void> _verifyHashes({
    required Directory extractionDirectory,
    required TGPackageManifest manifest,
    required List<PackageImportIssue> issues,
  }) async {
    for (final entry in manifest.fileHashes.entries) {
      final relativePath = _normalizedPackagePath(entry.key);

      if (relativePath == null) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Unsafe path in manifest integrity table.',
            path: entry.key,
          ),
        );
        continue;
      }

      final file = File(
        p.joinAll([
          extractionDirectory.path,
          ...p.posix.split(relativePath),
        ]),
      );

      if (!await file.exists()) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Verified package file is missing.',
            path: relativePath,
          ),
        );
        continue;
      }

      final actualHash = await _sha256File(file);
      if (actualHash.toLowerCase() != entry.value.toLowerCase()) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'SHA-256 verification failed.',
            path: relativePath,
          ),
        );
      }
    }

    if (!manifest.fileHashes.containsKey(manifest.cardFile)) {
      issues.add(
        PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'card.json is not protected by the integrity table.',
          path: manifest.cardFile,
        ),
      );
    }

    if (manifest.coverFile.isNotEmpty &&
        !manifest.fileHashes.containsKey(manifest.coverFile)) {
      issues.add(
        PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Cover file is not protected by the integrity table.',
          path: manifest.coverFile,
        ),
      );
    }

    for (final mediaPath in manifest.mediaFiles) {
      if (!manifest.fileHashes.containsKey(mediaPath)) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Media file is not protected by the integrity table.',
            path: mediaPath,
          ),
        );
      }
    }
  }

  static void _validateManifestAgainstCard({
    required TGPackageManifest manifest,
    required Map<String, dynamic> cardJson,
    required List<PackageImportIssue> issues,
  }) {
    final cardId = cardJson['id'] as String? ?? '';
    final cardTitle = cardJson['title'] as String? ?? '';
    final fingerprint = cardJson['fingerprint'] as String? ?? '';
    final coverPath = cardJson['coverImagePath'] as String? ?? '';
    final mediaJson = cardJson['media'] as List? ?? const [];

    if (cardId != manifest.cardId) {
      issues.add(
        const PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest card ID does not match card.json.',
        ),
      );
    }

    if (cardTitle != manifest.cardTitle) {
      issues.add(
        const PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest card title does not match card.json.',
        ),
      );
    }

    if (fingerprint != manifest.fingerprint) {
      issues.add(
        const PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest fingerprint does not match card.json.',
        ),
      );
    }

    if (coverPath != manifest.coverFile) {
      issues.add(
        const PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest cover path does not match card.json.',
        ),
      );
    }

    final cardMediaPaths = <String>[];
    for (final item in mediaJson) {
      if (item is Map) {
        cardMediaPaths.add(item['path']?.toString() ?? '');
      }
    }

    if (cardMediaPaths.length != manifest.mediaCount) {
      issues.add(
        PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest expects ${manifest.mediaCount} media files, but '
              'card.json contains ${cardMediaPaths.length}.',
        ),
      );
    }

    if (cardMediaPaths.length == manifest.mediaFiles.length) {
      for (var index = 0; index < cardMediaPaths.length; index++) {
        if (cardMediaPaths[index] != manifest.mediaFiles[index]) {
          issues.add(
            PackageImportIssue(
              severity: PackageImportIssueSeverity.error,
              message: 'Media path mismatch at position ${index + 1}.',
              path: cardMediaPaths[index],
            ),
          );
        }
      }
    } else {
      issues.add(
        const PackageImportIssue(
          severity: PackageImportIssueSeverity.error,
          message: 'Manifest media list does not match card.json.',
        ),
      );
    }
  }

  static Map<String, dynamic> _resolveCardPaths(
    Map<String, dynamic> portableCardJson,
    Directory extractionDirectory,
    List<PackageImportIssue> issues,
  ) {
    final resolved = Map<String, dynamic>.from(portableCardJson);

    final coverPath = portableCardJson['coverImagePath'] as String?;
    if (coverPath != null && coverPath.isNotEmpty) {
      final normalized = _normalizedPackagePath(coverPath);
      if (normalized == null) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Unsafe cover path in card.json.',
            path: coverPath,
          ),
        );
      } else {
        resolved['coverImagePath'] = p.joinAll([
          extractionDirectory.path,
          ...p.posix.split(normalized),
        ]);
      }
    }

    final rawMedia = portableCardJson['media'] as List? ?? const [];
    final resolvedMedia = <Map<String, dynamic>>[];

    for (final rawItem in rawMedia) {
      if (rawItem is! Map) {
        issues.add(
          const PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Invalid media record in card.json.',
          ),
        );
        continue;
      }

      final item = Map<String, dynamic>.from(rawItem);
      final portablePath = item['path']?.toString() ?? '';
      final normalized = _normalizedPackagePath(portablePath);

      if (normalized == null) {
        issues.add(
          PackageImportIssue(
            severity: PackageImportIssueSeverity.error,
            message: 'Unsafe media path in card.json.',
            path: portablePath,
          ),
        );
        continue;
      }

      item['path'] = p.joinAll([
        extractionDirectory.path,
        ...p.posix.split(normalized),
      ]);
      item['thumbnailPath'] = null;
      resolvedMedia.add(item);
    }

    resolved['media'] = resolvedMedia;
    return resolved;
  }

  static Map<String, dynamic> _decodeJsonObject(
    String source, {
    required String label,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static String? _normalizedPackagePath(String value) {
    final replaced = value.replaceAll('\\', '/').trim();
    if (replaced.isEmpty) {
      return null;
    }

    if (replaced.startsWith('/') || replaced.contains(':')) {
      return null;
    }

    final normalized = p.posix.normalize(replaced);
    if (normalized == '.' ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.contains('/../')) {
      return null;
    }

    return normalized;
  }

  static bool _hasErrors(List<PackageImportIssue> issues) {
    return issues.any(
      (issue) => issue.severity == PackageImportIssueSeverity.error,
    );
  }

  static Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
