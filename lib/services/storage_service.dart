import '../models/gallery_card.dart';

class StorageService {
  const StorageService._();

  static const int defaultMaximumBytes = 500 * 1024 * 1024;
  static const int defaultMaximumPhotos = 50;
  static const int defaultMaximumVideos = 10;

  static int totalBytes(Iterable<GalleryMediaItem> media) {
    return media.fold<int>(
      0,
      (total, item) => total + item.sizeBytes.clamp(0, 1 << 62),
    );
  }

  static int photoCount(Iterable<GalleryMediaItem> media) {
    return media
        .where((item) => item.type == GalleryMediaType.photo)
        .length;
  }

  static int videoCount(Iterable<GalleryMediaItem> media) {
    return media
        .where((item) => item.type == GalleryMediaType.video)
        .length;
  }

  static bool isWithinStorageLimit(
    Iterable<GalleryMediaItem> media, {
    int maximumBytes = defaultMaximumBytes,
  }) {
    return totalBytes(media) <= maximumBytes;
  }

  static bool isWithinMediaLimits(
    Iterable<GalleryMediaItem> media, {
    int maximumPhotos = defaultMaximumPhotos,
    int maximumVideos = defaultMaximumVideos,
  }) {
    return photoCount(media) <= maximumPhotos &&
        videoCount(media) <= maximumVideos;
  }
}
