import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../models/gallery_card.dart';
import 'thumbnail_service.dart';

class MediaImportResult {
  const MediaImportResult({
    required this.items,
    required this.rejectedPaths,
    required this.duplicatePaths,
  });

  final List<GalleryMediaItem> items;
  final List<String> rejectedPaths;
  final List<String> duplicatePaths;
}

class MediaEngine {
  MediaEngine({ThumbnailService? thumbnails})
      : _thumbnails = thumbnails ?? ThumbnailService();

  final ThumbnailService _thumbnails;

  static const photoExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif'
  };
  static const videoExtensions = <String>{
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    'webm'
  };

  Future<MediaImportResult> preparePaths(
    Iterable<String> paths, {
    int startingOrder = 0,
    Iterable<GalleryMediaItem> existingItems = const [],
  }) async {
    final items = <GalleryMediaItem>[];
    final rejected = <String>[];
    final duplicates = <String>[];
    final knownHashes = existingItems
        .map((item) => item.contentHash)
        .where((hash) => hash.isNotEmpty)
        .toSet();

    for (final rawPath in paths) {
      final path = rawPath.trim();
      final file = File(path);
      if (path.isEmpty || !await file.exists()) {
        rejected.add(rawPath);
        continue;
      }

      final extension = path.split('.').last.toLowerCase();
      final type = photoExtensions.contains(extension)
          ? GalleryMediaType.photo
          : videoExtensions.contains(extension)
              ? GalleryMediaType.video
              : null;
      if (type == null) {
        rejected.add(path);
        continue;
      }

      final hash = await _hashFile(file);
      if (knownHashes.contains(hash)) {
        duplicates.add(path);
        continue;
      }
      knownHashes.add(hash);

      final id =
          'MEDIA-${DateTime.now().microsecondsSinceEpoch}-${items.length}';
      final probe = type == GalleryMediaType.photo
          ? await _thumbnails.probeImage(path, id)
          : await _thumbnails.probeFile(path);

      items.add(
        GalleryMediaItem(
          id: id,
          path: path,
          type: type,
          sortOrder: startingOrder + items.length,
          thumbnailPath: probe.thumbnailPath,
          width: probe.width,
          height: probe.height,
          sizeBytes: probe.sizeBytes,
          importedAt: DateTime.now(),
          contentHash: hash,
        ),
      );
    }

    return MediaImportResult(
      items: items,
      rejectedPaths: rejected,
      duplicatePaths: duplicates,
    );
  }

  Future<String> _hashFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
