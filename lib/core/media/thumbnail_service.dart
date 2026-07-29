import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaProbe {
  const MediaProbe({
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.thumbnailPath,
  });

  final int width;
  final int height;
  final int sizeBytes;
  final String? thumbnailPath;
}

class ThumbnailService {
  Directory? _cacheDirectory;

  Future<Directory> get cacheDirectory async {
    if (_cacheDirectory != null) return _cacheDirectory!;
    final support = await getApplicationSupportDirectory();
    _cacheDirectory = Directory(
      p.join(support.path, 'ThotGalleryStudio', 'Cache', 'thumbs'),
    );
    await _cacheDirectory!.create(recursive: true);
    return _cacheDirectory!;
  }

  Future<MediaProbe> probeImage(String sourcePath, String mediaId) async {
    final source = File(sourcePath);
    final stat = await source.stat();
    final cache = await cacheDirectory;
    final destination = p.join(cache.path, '$mediaId.jpg');

    final result = await Isolate.run<Map<String, Object?>>(
      () => _createThumbnail(<String, String>{
        'source': sourcePath,
        'destination': destination,
      }),
    );

    return MediaProbe(
      width: result['width'] as int? ?? 0,
      height: result['height'] as int? ?? 0,
      sizeBytes: stat.size,
      thumbnailPath: result['thumbnailPath'] as String?,
    );
  }

  Future<MediaProbe> probeFile(String sourcePath) async {
    final stat = await File(sourcePath).stat();
    return MediaProbe(
      width: 0,
      height: 0,
      sizeBytes: stat.size,
      thumbnailPath: null,
    );
  }
}

Map<String, Object?> _createThumbnail(Map<String, String> request) {
  final sourcePath = request['source']!;
  final destinationPath = request['destination']!;
  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return <String, Object?>{'width': 0, 'height': 0};
    }
    final thumbnail = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 512 : null,
      height: decoded.height > decoded.width ? 512 : null,
      interpolation: img.Interpolation.average,
    );
    final destination = File(destinationPath);
    destination.parent.createSync(recursive: true);
    destination.writeAsBytesSync(img.encodeJpg(thumbnail, quality: 84));
    return <String, Object?>{
      'width': decoded.width,
      'height': decoded.height,
      'thumbnailPath': destination.path,
    };
  } catch (_) {
    return <String, Object?>{'width': 0, 'height': 0};
  }
}
