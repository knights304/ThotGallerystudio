import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/rate_me_card.dart';

class StudioRateMeExportResult {
  const StudioRateMeExportResult({
    required this.file,
    required this.cardId,
    required this.mediaCount,
    required this.sha256,
  });

  final File file;
  final String cardId;
  final int mediaCount;
  final String sha256;
}

class StudioRateMeImportResult {
  const StudioRateMeImportResult({
    required this.card,
    required this.storageDirectory,
    required this.packageSha256,
  });

  final StudioRateMeCard card;
  final Directory storageDirectory;
  final String packageSha256;
}

class StudioRateMePackageService {
  const StudioRateMePackageService._();

  static const String format = 'thotgallery-rate-me';
  static const int formatVersion = 1;

  static Future<StudioRateMeExportResult> exportCard(
    StudioRateMeCard card,
  ) async {
    if (card.id.trim().isEmpty) {
      throw StateError('Rate Me card ID is required.');
    }

    if (card.title.trim().isEmpty) {
      throw StateError('Rate Me card title is required.');
    }

    if (card.media.isEmpty) {
      throw StateError(
        'Add at least one photo or video before exporting.',
      );
    }

    final temporary = await getTemporaryDirectory();
    final exportRoot = Directory(
      p.join(
        temporary.path,
        'studio_tgrate_export_${_safe(card.id)}',
      ),
    );

    if (await exportRoot.exists()) {
      await exportRoot.delete(recursive: true);
    }

    await exportRoot.create(recursive: true);

    try {
      final mediaDirectory = Directory(
        p.join(exportRoot.path, 'media'),
      );
      await mediaDirectory.create(recursive: true);

      String? packagedCoverPath;

      final coverPath = card.coverImagePath;
      if (coverPath != null && coverPath.trim().isNotEmpty) {
        final coverFile = File(coverPath);

        if (await coverFile.exists()) {
          final coverDirectory = Directory(
            p.join(exportRoot.path, 'cover'),
          );
          await coverDirectory.create(recursive: true);

          final extension = _safeExtension(
            coverFile.path,
            fallback: '.jpg',
          );

          packagedCoverPath = 'cover/cover$extension';

          await coverFile.copy(
            p.join(exportRoot.path, packagedCoverPath),
          );
        }
      }

      final packagedMedia = <Map<String, dynamic>>[];

      for (var index = 0; index < card.media.length; index++) {
        final item = card.media[index];
        final source = File(item.path);

        if (!await source.exists()) {
          throw StateError(
            'Rate Me media is missing: ${item.path}',
          );
        }

        final fallback =
            item.type == StudioRateMeMediaType.photo ? '.jpg' : '.mp4';

        final extension = _safeExtension(
          source.path,
          fallback: fallback,
        );

        final sequence = (index + 1).toString().padLeft(4, '0');
        final typeName = item.type.name;
        final packagedPath =
            'media/${sequence}_${typeName}_${_safe(item.id)}$extension';

        await source.copy(
          p.join(exportRoot.path, packagedPath),
        );

        packagedMedia.add({
          'id': item.id,
          'path': packagedPath,
          'type': item.type.name,
          'caption': item.caption,
          'question': item.question,
          'createdAt': item.createdAt?.toIso8601String(),
        });
      }

      final exportedAt = DateTime.now().toUtc();

      final payload = <String, dynamic>{
        'format': format,
        'version': formatVersion,
        'card': {
          'id': card.id,
          'title': card.title,
          'description': card.description,
          'owner': card.owner.toJson(),
          'responseTarget': card.responseTarget.toJson(),
          'coverImagePath': packagedCoverPath,
          'media': packagedMedia,
          'createdAt': card.createdAt?.toIso8601String(),
          'updatedAt': card.updatedAt?.toIso8601String(),
        },
        'exportedAt': exportedAt.toIso8601String(),
      };

      final rateMeFile = File(
        p.join(exportRoot.path, 'rate_me.json'),
      );

      await rateMeFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
        flush: true,
      );

      final fileHashes = <String, String>{};

      await for (final entity
          in exportRoot.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final relative = p
            .relative(entity.path, from: exportRoot.path)
            .replaceAll('\\', '/');

        if (relative == 'manifest.json') continue;

        fileHashes[relative] = await _sha256File(entity);
      }

      final sortedKeys = fileHashes.keys.toList()..sort();

      final manifest = <String, dynamic>{
        'format': format,
        'version': formatVersion,
        'cardId': card.id,
        'title': card.title,
        'mediaCount': packagedMedia.length,
        'exportedAt': exportedAt.toIso8601String(),
        'fileHashes': {
          for (final key in sortedKeys) key: fileHashes[key]!,
        },
      };

      final manifestFile = File(
        p.join(exportRoot.path, 'manifest.json'),
      );

      await manifestFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
        flush: true,
      );

      final outputDirectory = Directory(
        p.join(
          temporary.path,
          'thot_gallery_studio_rate_me_exports',
        ),
      );
      await outputDirectory.create(recursive: true);

      final outputFile = File(
        p.join(
          outputDirectory.path,
          '${_safe(card.title)}_${_safe(card.id)}.tgrate',
        ),
      );

      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final files = await exportRoot
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      files.sort((a, b) => a.path.compareTo(b.path));

      if (files.isEmpty) {
        throw StateError('Rate Me export contains no files.');
      }

      final zipArchive = Archive();

      for (final file in files) {
        final relative =
            p.relative(file.path, from: exportRoot.path).replaceAll('\\', '/');

        final bytes = await file.readAsBytes();

        zipArchive.addFile(
          ArchiveFile(
            relative,
            bytes.length,
            bytes,
          ),
        );
      }

      final encoded = ZipEncoder().encode(zipArchive);

      if (encoded.isEmpty) {
        throw StateError(
          'Rate Me package encoder returned no data.',
        );
      }

      await outputFile.writeAsBytes(
        encoded,
        flush: true,
      );

      if (!await outputFile.exists()) {
        throw StateError('Rate Me package was not created.');
      }

      final outputLength = await outputFile.length();

      if (outputLength <= 22) {
        throw StateError(
          'Rate Me package archive is empty after export.',
        );
      }

      final archiveBytes = await outputFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(archiveBytes);

      final archiveNames = archive.files
          .where((entry) => entry.isFile)
          .map((entry) => entry.name.replaceAll('\\', '/'))
          .toSet();

      if (!archiveNames.contains('manifest.json') ||
          !archiveNames.contains('rate_me.json')) {
        throw StateError(
          'Rate Me package verification failed: '
          'manifest.json or rate_me.json is missing.',
        );
      }

      return StudioRateMeExportResult(
        file: outputFile,
        cardId: card.id,
        mediaCount: packagedMedia.length,
        sha256: await _sha256File(outputFile),
      );
    } finally {
      if (await exportRoot.exists()) {
        await exportRoot.delete(recursive: true);
      }
    }
  }

  static Future<StudioRateMeImportResult> importPackage(
    File packageFile,
  ) async {
    if (!await packageFile.exists()) {
      throw StateError('Rate Me package does not exist.');
    }

    final packageSha256 = await _sha256File(packageFile);
    final temporary = await getTemporaryDirectory();

    final extraction = Directory(
      p.join(
        temporary.path,
        'studio_tgrate_import_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await extraction.create(recursive: true);

    try {
      final input = InputFileStream(packageFile.path);
      final archive = ZipDecoder().decodeStream(input);

      for (final entry in archive) {
        final normalized = p.normalize(entry.name);

        if (p.isAbsolute(normalized) ||
            normalized.startsWith('..') ||
            normalized.contains('/../') ||
            normalized.contains(r'\..\')) {
          throw StateError('Unsafe path inside Rate Me package.');
        }

        final destination = p.join(extraction.path, normalized);

        if (entry.isFile) {
          final output = OutputFileStream(destination);
          entry.writeContent(output);
          await output.close();
        } else {
          await Directory(destination).create(recursive: true);
        }
      }

      final manifestFile = File(
        p.join(extraction.path, 'manifest.json'),
      );
      final rateMeFile = File(
        p.join(extraction.path, 'rate_me.json'),
      );

      if (!await manifestFile.exists() || !await rateMeFile.exists()) {
        throw StateError(
          'Rate Me package is missing required metadata.',
        );
      }

      final manifestDecoded = jsonDecode(
        await manifestFile.readAsString(),
      );

      if (manifestDecoded is! Map) {
        throw StateError('Invalid Rate Me manifest.');
      }

      final manifest = Map<String, dynamic>.from(manifestDecoded);

      if (manifest['format'] != format ||
          manifest['version'] != formatVersion) {
        throw StateError('Unsupported Rate Me package format.');
      }

      final hashesRaw = manifest['fileHashes'];
      if (hashesRaw is! Map) {
        throw StateError(
          'Rate Me package does not contain file hashes.',
        );
      }

      for (final entry in hashesRaw.entries) {
        final relativePath = entry.key.toString();
        final expectedHash = entry.value.toString();
        final file = File(
          p.join(extraction.path, relativePath),
        );

        if (!await file.exists()) {
          throw StateError(
            'Rate Me package file is missing: $relativePath',
          );
        }

        final actualHash = await _sha256File(file);

        if (actualHash != expectedHash) {
          throw StateError(
            'Rate Me package verification failed for $relativePath.',
          );
        }
      }

      final payloadDecoded = jsonDecode(
        await rateMeFile.readAsString(),
      );

      if (payloadDecoded is! Map) {
        throw StateError('Invalid Rate Me package data.');
      }

      final payload = Map<String, dynamic>.from(payloadDecoded);

      if (payload['format'] != format || payload['version'] != formatVersion) {
        throw StateError('Unsupported Rate Me payload version.');
      }

      final cardJson = payload['card'];
      if (cardJson is! Map) {
        throw StateError('Rate Me card payload is missing.');
      }

      final portableCard = StudioRateMeCard.fromJson(
        Map<String, dynamic>.from(cardJson),
      );

      if (portableCard.id.trim().isEmpty) {
        throw StateError('Rate Me card ID is missing.');
      }

      final support = await getApplicationSupportDirectory();
      final importRoot = Directory(
        p.join(
          support.path,
          'studio_rate_me_imports',
          _safe(portableCard.id),
        ),
      );

      if (await importRoot.exists()) {
        await importRoot.delete(recursive: true);
      }

      await _copyDirectory(extraction, importRoot);

      final relocatedMedia = portableCard.media.map((item) {
        return item.copyWith(
          path: p.join(importRoot.path, item.path),
        );
      }).toList();

      final cover = portableCard.coverImagePath;

      final installedCard = portableCard.copyWith(
        coverImagePath: cover == null || cover.isEmpty
            ? null
            : p.join(importRoot.path, cover),
        media: relocatedMedia,
      );

      final installedMetadata = File(
        p.join(importRoot.path, 'installed_card.json'),
      );

      await installedMetadata.writeAsString(
        jsonEncode(installedCard.toJson()),
        flush: true,
      );

      return StudioRateMeImportResult(
        card: installedCard,
        storageDirectory: importRoot,
        packageSha256: packageSha256,
      );
    } finally {
      if (await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
    }
  }

  static Future<void> _copyDirectory(
    Directory source,
    Directory destination,
  ) async {
    await destination.create(recursive: true);

    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relative = p.relative(
        entity.path,
        from: source.path,
      );
      final target = p.join(destination.path, relative);

      if (entity is Directory) {
        await Directory(target).create(recursive: true);
      } else if (entity is File) {
        await File(target).parent.create(recursive: true);
        await entity.copy(target);
      }
    }
  }

  static Future<String> _sha256File(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static String _safe(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return safe.isEmpty ? 'rate_me' : safe;
  }

  static String _safeExtension(
    String sourcePath, {
    required String fallback,
  }) {
    final extension = p.extension(sourcePath).toLowerCase();

    if (extension.isEmpty || extension.length > 8) {
      return fallback;
    }

    final safe = extension.replaceAll(
      RegExp(r'[^a-z0-9.]'),
      '',
    );

    return safe.isEmpty ? fallback : safe;
  }
}
