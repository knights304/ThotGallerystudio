import '../models/gallery_card.dart';
import '../widgets/creator_dashboard/dashboard_models.dart';
import 'storage_service.dart';

class ExportService {
  const ExportService._();

  static List<DashboardCheck> buildChecks(
    GalleryCard card, {
    int maximumBytes = StorageService.defaultMaximumBytes,
    int maximumPhotos = StorageService.defaultMaximumPhotos,
    int maximumVideos = StorageService.defaultMaximumVideos,
  }) {
    final media = card.media;
    final totalBytes = StorageService.totalBytes(media);
    final photoCount = StorageService.photoCount(media);
    final videoCount = StorageService.videoCount(media);

    return [
      DashboardCheck(
        label: 'Card title',
        isComplete: card.title.trim().isNotEmpty,
        detail: card.title.trim().isNotEmpty
            ? 'A title is ready.'
            : 'Add a title before export.',
      ),
      DashboardCheck(
        label: 'Cover image',
        isComplete: (card.coverImagePath ?? '').trim().isNotEmpty,
        detail: (card.coverImagePath ?? '').trim().isNotEmpty
            ? 'Cover art is selected.'
            : 'Choose a cover image.',
      ),
      DashboardCheck(
        label: 'Media attached',
        isComplete: media.isNotEmpty,
        detail: media.isNotEmpty
            ? '${media.length} media item${media.length == 1 ? '' : 's'} attached.'
            : 'Add at least one photo or video.',
      ),
      DashboardCheck(
        label: 'Storage limit',
        isComplete: totalBytes <= maximumBytes,
        detail: totalBytes <= maximumBytes
            ? 'Package is within the storage limit.'
            : 'Remove or compress media before export.',
      ),
      DashboardCheck(
        label: 'Photo limit',
        isComplete: photoCount <= maximumPhotos,
        detail: '$photoCount of $maximumPhotos photos used.',
      ),
      DashboardCheck(
        label: 'Video limit',
        isComplete: videoCount <= maximumVideos,
        detail: '$videoCount of $maximumVideos videos used.',
      ),
      DashboardCheck(
        label: 'Media files',
        isComplete: media.every((item) => item.path.trim().isNotEmpty),
        detail: media.every((item) => item.path.trim().isNotEmpty)
            ? 'All media items have a file path.'
            : 'One or more media items are missing a file path.',
      ),
    ];
  }

  static bool isReady(List<DashboardCheck> checks) {
    return checks.isNotEmpty && checks.every((check) => check.isComplete);
  }
}
