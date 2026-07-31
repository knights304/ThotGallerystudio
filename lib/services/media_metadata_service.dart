import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

import '../models/gallery_card.dart';

class MediaMetadataService {
  MediaMetadataService._();

  static final Random _random = Random.secure();

  static Future<GalleryMediaItem> createPhoto(String path) async {
    final file = File(path);
    final importedAt = DateTime.now();

    var sizeBytes = 0;
    var width = 0;
    var height = 0;
    var contentHash = '';

    if (await file.exists()) {
      sizeBytes = await file.length();

      try {
        final bytes = await file.readAsBytes();
        final decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          width = decodedImage.width;
          height = decodedImage.height;
        }
      } catch (_) {
        // Keep the media usable even when dimensions cannot be decoded.
      }

      try {
        contentHash = await _sha256ForFile(file);
      } catch (_) {
        // A missing hash must not block importing otherwise valid media.
      }
    }

    return GalleryMediaItem(
      id: _createId('photo'),
      path: path,
      type: GalleryMediaType.photo,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
      importedAt: importedAt,
      contentHash: contentHash,
    );
  }

  static Future<GalleryMediaItem> createVideo(String path) async {
    final file = File(path);
    final importedAt = DateTime.now();

    var sizeBytes = 0;
    var width = 0;
    var height = 0;
    var durationMilliseconds = 0;
    var contentHash = '';

    if (await file.exists()) {
      sizeBytes = await file.length();

      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.file(file);
        await controller.initialize();

        final size = controller.value.size;
        width = size.width.round();
        height = size.height.round();
        durationMilliseconds = controller.value.duration.inMilliseconds;
      } catch (_) {
        // Keep the video importable if the platform cannot read its metadata.
      } finally {
        await controller?.dispose();
      }

      try {
        contentHash = await _sha256ForFile(file);
      } catch (_) {
        // A missing hash must not block importing otherwise valid media.
      }
    }

    return GalleryMediaItem(
      id: _createId('video'),
      path: path,
      type: GalleryMediaType.video,
      width: width,
      height: height,
      sizeBytes: sizeBytes,
      durationMilliseconds: durationMilliseconds,
      importedAt: importedAt,
      contentHash: contentHash,
    );
  }

  static Future<String> _sha256ForFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static String _createId(String prefix) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(0x7fffffff).toRadixString(16);
    return '${prefix}_${timestamp}_$salt';
  }
}
