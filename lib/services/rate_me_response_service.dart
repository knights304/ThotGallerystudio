import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/rate_me_response.dart';

class StudioRateMeResponseImportResult {
  const StudioRateMeResponseImportResult({
    required this.response,
    required this.storageDirectory,
    required this.packageSha256,
  });

  final StudioRateMeResponse response;
  final Directory storageDirectory;
  final String packageSha256;
}

class StudioStoredRateMeResponse {
  const StudioStoredRateMeResponse({
    required this.response,
    required this.directory,
  });

  final StudioRateMeResponse response;
  final Directory directory;
}

class StudioRateMeResponseService {
  const StudioRateMeResponseService._();

  static const String format = 'thotgallery-rate-me-response';
  static const int currentFormatVersion = 2;

  static Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      p.join(support.path, 'studio_rate_me_responses'),
    );
    await root.create(recursive: true);
    return root;
  }

  static Future<StudioRateMeResponseImportResult> importPackage(
    File packageFile,
  ) async {
    if (!await packageFile.exists()) {
      throw StateError('Rate Me response package does not exist.');
    }

    final packageSha256 = await _sha256File(packageFile);
    final temporary = await getTemporaryDirectory();

    final extraction = Directory(
      p.join(
        temporary.path,
        'studio_tgrate_response_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    await extraction.create(recursive: true);

    try {
      await _extractZipSafely(
        packageFile: packageFile,
        destination: extraction,
      );

      final manifestFile = File(
        p.join(extraction.path, 'manifest.json'),
      );
      final responseFile = File(
        p.join(extraction.path, 'response.json'),
      );

      if (!await manifestFile.exists() || !await responseFile.exists()) {
        throw StateError(
          'Rate Me response package is missing required metadata.',
        );
      }

      final manifest = await _readJsonMap(
        manifestFile,
        errorMessage: 'Invalid Rate Me response manifest.',
      );

      if (manifest['format'] != format) {
        throw StateError(
          'Unsupported Rate Me response package format.',
        );
      }

      final manifestVersion = _readInt(manifest['version']);

      if (manifestVersion < 1 || manifestVersion > currentFormatVersion) {
        throw StateError(
          'Unsupported Rate Me response package version: '
          '$manifestVersion.',
        );
      }

      await _verifyPackageFiles(
        extraction: extraction,
        manifest: manifest,
      );

      final responseJson = await _readJsonMap(
        responseFile,
        errorMessage: 'Invalid Rate Me response data.',
      );

      if (responseJson['format'] != format) {
        throw StateError(
          'Unsupported Rate Me response payload format.',
        );
      }

      final responseVersion = _readInt(
        responseJson['version'],
      );

      if (responseVersion < 1 || responseVersion > currentFormatVersion) {
        throw StateError(
          'Unsupported Rate Me response version: $responseVersion.',
        );
      }

      final portableResponse = responseVersion >= 2
          ? StudioRateMeResponse.fromJson(responseJson)
          : _convertLegacyResponse(responseJson);

      if (portableResponse.cardId.trim().isEmpty) {
        throw StateError(
          'Rate Me response is missing the original card ID.',
        );
      }

      final root = await _root();
      final cardRoot = Directory(
        p.join(root.path, _safe(portableResponse.cardId)),
      );
      await cardRoot.create(recursive: true);

      final responseId = _responseId(
        portableResponse,
        packageSha256,
      );

      final destination = Directory(
        p.join(cardRoot.path, responseId),
      );

      if (await destination.exists()) {
        await destination.delete(recursive: true);
      }

      await _copyDirectory(
        extraction,
        destination,
      );

      final replyPath = portableResponse.videoReplyPath;

      final installedResponse = portableResponse.copyWith(
        videoReplyPath: replyPath == null || replyPath.trim().isEmpty
            ? null
            : p.join(destination.path, replyPath),
      );

      final installedMetadata = File(
        p.join(destination.path, 'installed_response.json'),
      );

      await installedMetadata.writeAsString(
        jsonEncode(installedResponse.toJson()),
        flush: true,
      );

      return StudioRateMeResponseImportResult(
        response: installedResponse,
        storageDirectory: destination,
        packageSha256: packageSha256,
      );
    } finally {
      if (await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
    }
  }

  static Future<List<StudioStoredRateMeResponse>> loadForCard(
    String cardId,
  ) async {
    if (cardId.trim().isEmpty) {
      return const [];
    }

    final root = await _root();
    final cardRoot = Directory(
      p.join(root.path, _safe(cardId)),
    );

    if (!await cardRoot.exists()) {
      return const [];
    }

    final results = <StudioStoredRateMeResponse>[];

    await for (final entity in cardRoot.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final metadata = File(
        p.join(entity.path, 'installed_response.json'),
      );

      if (!await metadata.exists()) continue;

      try {
        final decoded = await _readJsonMap(
          metadata,
          errorMessage: 'Invalid stored Rate Me response.',
        );

        final response = StudioRateMeResponse.fromJson(
          decoded,
        );

        if (response.cardId == cardId) {
          results.add(
            StudioStoredRateMeResponse(
              response: response,
              directory: entity,
            ),
          );
        }
      } catch (_) {
        // Ignore malformed individual response folders.
      }
    }

    results.sort((a, b) {
      return b.response.createdAt.compareTo(
        a.response.createdAt,
      );
    });

    return results;
  }

  static Future<int> countForCard(String cardId) async {
    return (await loadForCard(cardId)).length;
  }

  static Future<double> averageRatingForCard(
    String cardId,
  ) async {
    final responses = await loadForCard(cardId);

    final rated = responses
        .map((stored) => stored.response)
        .where((response) => response.hasRating)
        .toList();

    if (rated.isEmpty) {
      return 0.0;
    }

    final total = rated.fold<double>(
      0.0,
      (sum, response) => sum + response.overallRating,
    );

    return total / rated.length;
  }

  static Future<Map<String, int>> favoriteCountsForCard(
    String cardId,
  ) async {
    final responses = await loadForCard(cardId);
    final counts = <String, int>{};

    for (final stored in responses) {
      for (final mediaId in stored.response.favoriteMediaIds) {
        counts.update(
          mediaId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    return counts;
  }

  static Future<int> videoReplyCountForCard(
    String cardId,
  ) async {
    final responses = await loadForCard(cardId);

    return responses.where((stored) => stored.response.hasVideoReply).length;
  }

  static Future<int> commentCountForCard(
    String cardId,
  ) async {
    final responses = await loadForCard(cardId);

    return responses.where((stored) => stored.response.hasComment).length;
  }

  static Future<void> deleteResponse(
    StudioStoredRateMeResponse stored,
  ) async {
    if (await stored.directory.exists()) {
      await stored.directory.delete(recursive: true);
    }
  }

  static Future<void> deleteAllForCard(
    String cardId,
  ) async {
    if (cardId.trim().isEmpty) return;

    final root = await _root();
    final cardRoot = Directory(
      p.join(root.path, _safe(cardId)),
    );

    if (await cardRoot.exists()) {
      await cardRoot.delete(recursive: true);
    }
  }

  static Future<void> _extractZipSafely({
    required File packageFile,
    required Directory destination,
  }) async {
    final input = InputFileStream(packageFile.path);

    try {
      final archive = ZipDecoder().decodeStream(input);

      for (final entry in archive) {
        final normalized = p.normalize(entry.name);

        if (normalized.isEmpty ||
            p.isAbsolute(normalized) ||
            normalized == '..' ||
            normalized.startsWith('../') ||
            normalized.startsWith(r'..\') ||
            normalized.contains('/../') ||
            normalized.contains(r'\..\')) {
          throw StateError(
            'Unsafe path inside Rate Me response package.',
          );
        }

        final outputPath = p.join(
          destination.path,
          normalized,
        );

        if (entry.isFile) {
          await File(outputPath).parent.create(
                recursive: true,
              );

          final output = OutputFileStream(outputPath);
          entry.writeContent(output);
          await output.close();
        } else {
          await Directory(outputPath).create(
            recursive: true,
          );
        }
      }
    } finally {
      await input.close();
    }
  }

  static Future<void> _verifyPackageFiles({
    required Directory extraction,
    required Map<String, dynamic> manifest,
  }) async {
    final hashesRaw = manifest['fileHashes'];

    if (hashesRaw is! Map) {
      throw StateError(
        'Rate Me response package does not contain file hashes.',
      );
    }

    for (final entry in hashesRaw.entries) {
      final relativePath = entry.key.toString();
      final expectedHash = entry.value.toString();

      final normalized = p.normalize(relativePath);

      if (normalized.isEmpty ||
          p.isAbsolute(normalized) ||
          normalized == '..' ||
          normalized.startsWith('../') ||
          normalized.startsWith(r'..\') ||
          normalized.contains('/../') ||
          normalized.contains(r'\..\')) {
        throw StateError(
          'Unsafe file path in Rate Me response manifest.',
        );
      }

      final file = File(
        p.join(extraction.path, normalized),
      );

      if (!await file.exists()) {
        throw StateError(
          'Rate Me response file is missing: $relativePath',
        );
      }

      final actualHash = await _sha256File(file);

      if (actualHash != expectedHash) {
        throw StateError(
          'Rate Me response verification failed for '
          '$relativePath.',
        );
      }
    }
  }

  static StudioRateMeResponse _convertLegacyResponse(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];
    final ratings = <int>[];
    final comments = <String>[];
    final favoriteMediaIds = <String>[];
    String? videoReplyPath;

    if (rawItems is List) {
      for (final rawItem in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(rawItem);
        final mediaId = (item['mediaId'] as String?)?.trim() ?? '';
        final rating = _readInt(item['rating']);

        if (rating >= 1 && rating <= 5) {
          ratings.add(rating);
        }

        final note = (item['note'] as String?)?.trim() ?? '';

        if (note.isNotEmpty) {
          comments.add(note);
        }

        if (rating == 5 &&
            mediaId.isNotEmpty &&
            !favoriteMediaIds.contains(mediaId)) {
          favoriteMediaIds.add(mediaId);
        }

        final reply = (item['videoReplyPath'] as String?)?.trim();

        if (videoReplyPath == null && reply != null && reply.isNotEmpty) {
          videoReplyPath = reply;
        }
      }
    }

    final overallRating = ratings.isEmpty
        ? 0.0
        : (ratings.reduce((a, b) => a + b) / ratings.length)
            .round()
            .clamp(1, 5);

    final createdAt = _readDate(json['createdAt']) ??
        _readDate(json['updatedAt']) ??
        DateTime.now();

    return StudioRateMeResponse(
      cardId: (json['cardId'] as String?)?.trim() ?? '',
      responderId: (json['responderId'] as String?)?.trim() ?? '',
      responderName: (json['responderName'] as String?)?.trim() ?? '',
      overallRating: overallRating.toDouble(),
      overallComment: comments.join('\n\n'),
      favoriteMediaIds: favoriteMediaIds,
      videoReplyPath: videoReplyPath,
      createdAt: createdAt,
    );
  }

  static Future<Map<String, dynamic>> _readJsonMap(
    File file, {
    required String errorMessage,
  }) async {
    final decoded = jsonDecode(
      await file.readAsString(),
    );

    if (decoded is! Map) {
      throw StateError(errorMessage);
    }

    return Map<String, dynamic>.from(decoded);
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

  static String _responseId(
    StudioRateMeResponse response,
    String packageSha256,
  ) {
    final responder = response.responderName.trim().isEmpty
        ? 'anonymous'
        : response.responderName.trim();

    return '${_safe(responder)}_'
        '${response.createdAt.microsecondsSinceEpoch}_'
        '${packageSha256.substring(0, 12)}';
  }

  static int _readInt(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text) ?? 0,
      _ => 0,
    };
  }

  static DateTime? _readDate(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  static String _safe(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return safe.isEmpty ? 'rate_me' : safe;
  }
}
