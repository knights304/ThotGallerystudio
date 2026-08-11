import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/rate_me_response.dart';

class StudioRateMeResponseShareResult {
  const StudioRateMeResponseShareResult({
    required this.file,
    required this.cardId,
    required this.sha256,
  });

  final File file;
  final String cardId;
  final String sha256;
}

class StudioRateMeResponseShareService {
  const StudioRateMeResponseShareService._();

  static const String format = 'thotgallery-rate-me-response';

  static const int formatVersion = 3;

  static Future<StudioRateMeResponseShareResult> exportResponse(
    StudioRateMeResponse response,
  ) async {
    if (response.cardId.trim().isEmpty) {
      throw StateError(
        'Rate Me response is missing the card ID.',
      );
    }

    if (response.overallRating < 0.5 || response.overallRating > 5.0) {
      throw StateError(
        'Overall rating must be between 0.5 and 5.',
      );
    }

    final temporary = await getTemporaryDirectory();

    final exportRoot = Directory(
      p.join(
        temporary.path,
        'studio_tgrate_response_'
        '${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    if (await exportRoot.exists()) {
      await exportRoot.delete(recursive: true);
    }

    await exportRoot.create(recursive: true);

    try {
      final attachmentsDirectory = Directory(
        p.join(
          exportRoot.path,
          'attachments',
        ),
      );

      String? packagedPhoto;
      String? packagedVideo;
      String? packagedVoice;

      if (response.photoReplyPath != null) {
        packagedPhoto = await _copyAttachment(
          sourcePath: response.photoReplyPath!,
          exportRoot: exportRoot,
          attachmentsDirectory: attachmentsDirectory,
          baseName: 'photo_reply',
          fallbackExtension: '.jpg',
        );
      }

      if (response.videoReplyPath != null) {
        packagedVideo = await _copyAttachment(
          sourcePath: response.videoReplyPath!,
          exportRoot: exportRoot,
          attachmentsDirectory: attachmentsDirectory,
          baseName: 'video_reply',
          fallbackExtension: '.mp4',
        );
      }

      if (response.voiceReplyPath != null) {
        packagedVoice = await _copyAttachment(
          sourcePath: response.voiceReplyPath!,
          exportRoot: exportRoot,
          attachmentsDirectory: attachmentsDirectory,
          baseName: 'voice_reply',
          fallbackExtension: '.m4a',
        );
      }

      final exportedAt = DateTime.now().toUtc();

      final responsePayload = <String, dynamic>{
        'format': format,
        'version': formatVersion,
        'cardId': response.cardId,
        'responderId': response.responderId,
        'responderName': response.responderName,
        'overallRating': response.overallRating,
        'overallComment': response.overallComment,
        'favoriteMediaIds': response.favoriteMediaIds,
        'photoReplyPath': packagedPhoto,
        'videoReplyPath': packagedVideo,
        'voiceReplyPath': packagedVoice,
        'createdAt': response.createdAt.toIso8601String(),
        'exportedAt': exportedAt.toIso8601String(),
      };

      final responseFile = File(
        p.join(
          exportRoot.path,
          'response.json',
        ),
      );

      await responseFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(responsePayload)}\n',
        flush: true,
      );

      final fileHashes = <String, String>{};

      await for (final entity in exportRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final relative = p
            .relative(
              entity.path,
              from: exportRoot.path,
            )
            .replaceAll('\\', '/');

        if (relative == 'manifest.json') {
          continue;
        }

        fileHashes[relative] = await _sha256File(entity);
      }

      final sortedKeys = fileHashes.keys.toList()..sort();

      final manifest = <String, dynamic>{
        'format': format,
        'version': formatVersion,
        'cardId': response.cardId,
        'responderName': response.responderName,
        'responseCount': 1,
        'exportedAt': exportedAt.toIso8601String(),
        'fileHashes': {
          for (final key in sortedKeys) key: fileHashes[key]!,
        },
      };

      final manifestFile = File(
        p.join(
          exportRoot.path,
          'manifest.json',
        ),
      );

      await manifestFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
        flush: true,
      );

      final sourceFiles = <File>[];

      await for (final entity in exportRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          sourceFiles.add(entity);
        }
      }

      sourceFiles.sort(
        (a, b) => a.path.compareTo(b.path),
      );

      final archive = Archive();

      for (final file in sourceFiles) {
        final relative = p
            .relative(
              file.path,
              from: exportRoot.path,
            )
            .replaceAll('\\', '/');

        final bytes = await file.readAsBytes();

        archive.addFile(
          ArchiveFile(
            relative,
            bytes.length,
            bytes,
          ),
        );
      }

      final encoded = ZipEncoder().encode(archive);

      final zipBytes = Uint8List.fromList(encoded);

      if (zipBytes.length <= 22) {
        throw StateError(
          'Rate Me response package is empty.',
        );
      }

      final verification = ZipDecoder().decodeBytes(
        zipBytes,
        verify: true,
      );

      final names = verification.files
          .where((entry) => entry.isFile)
          .map(
            (entry) => entry.name.replaceAll('\\', '/'),
          )
          .toSet();

      if (!names.contains(
            'manifest.json',
          ) ||
          !names.contains(
            'response.json',
          )) {
        throw StateError(
          'Rate Me response package verification failed.',
        );
      }

      final outputDirectory = Directory(
        p.join(
          temporary.path,
          'thot_gallery_rate_me_responses',
        ),
      );

      await outputDirectory.create(
        recursive: true,
      );

      final outputFile = File(
        p.join(
          outputDirectory.path,
          'response_'
          '${_safe(response.cardId)}_'
          '${DateTime.now().microsecondsSinceEpoch}'
          '.tgrateresponse',
        ),
      );

      await outputFile.writeAsBytes(
        zipBytes,
        flush: true,
      );

      return StudioRateMeResponseShareResult(
        file: outputFile,
        cardId: response.cardId,
        sha256: await _sha256File(outputFile),
      );
    } finally {
      if (await exportRoot.exists()) {
        await exportRoot.delete(
          recursive: true,
        );
      }
    }
  }

  static Future<String?> _copyAttachment({
    required String sourcePath,
    required Directory exportRoot,
    required Directory attachmentsDirectory,
    required String baseName,
    required String fallbackExtension,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      return null;
    }

    await attachmentsDirectory.create(
      recursive: true,
    );

    var extension = p.extension(source.path).toLowerCase();

    if (extension.isEmpty || extension.length > 10) {
      extension = fallbackExtension;
    }

    final relative = 'attachments/$baseName$extension';

    await source.copy(
      p.join(
        exportRoot.path,
        relative,
      ),
    );

    return relative;
  }

  static Future<String> _sha256File(
    File file,
  ) async {
    final digest = await sha256
        .bind(
          file.openRead(),
        )
        .first;

    return digest.toString();
  }

  static String _safe(String value) {
    final result = value.trim().replaceAll(
          RegExp(
            r'[^A-Za-z0-9._-]+',
          ),
          '_',
        );

    return result.isEmpty ? 'rate_me' : result;
  }
}
