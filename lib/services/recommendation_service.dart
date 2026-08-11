import '../models/gallery_card.dart';
import 'storage_service.dart';

class RecommendationService {
  const RecommendationService._();

  static List<String> buildRecommendations(
    GalleryCard card, {
    int maximumBytes = StorageService.defaultMaximumBytes,
    int maximumPhotos = StorageService.defaultMaximumPhotos,
    int maximumVideos = StorageService.defaultMaximumVideos,
  }) {
    final recommendations = <String>[];
    final media = card.media;
    final totalBytes = StorageService.totalBytes(media);
    final photoCount = StorageService.photoCount(media);
    final videoCount = StorageService.videoCount(media);

    if (card.title.trim().isEmpty) {
      recommendations.add('Give this card a title so it is easy to identify.');
    }

    if ((card.coverImagePath ?? '').trim().isEmpty) {
      recommendations
          .add('Choose a cover image to make the card presentation-ready.');
    }

    if (card.description.trim().isEmpty) {
      recommendations
          .add('Add a short story or summary to give the card context.');
    }

    if (media.isEmpty) {
      recommendations
          .add('Add at least one photo or video to bring this card to life.');
    }

    if (card.tags.isEmpty) {
      recommendations.add(
          'Add a few tags so this card is easier to organize and discover.');
    }

    if (totalBytes > maximumBytes) {
      recommendations.add(
          'Reduce the media size before export. The package is over its storage limit.');
    }

    if (photoCount > maximumPhotos) {
      recommendations.add(
          'Remove ${photoCount - maximumPhotos} photo${photoCount - maximumPhotos == 1 ? '' : 's'} to meet the photo limit.');
    }

    if (videoCount > maximumVideos) {
      recommendations.add(
          'Remove ${videoCount - maximumVideos} video${videoCount - maximumVideos == 1 ? '' : 's'} to meet the video limit.');
    }

    final missingMetadata = media.where(
      (item) =>
          item.sizeBytes <= 0 ||
          item.contentHash.isEmpty ||
          (item.type == GalleryMediaType.photo &&
              (item.width <= 0 || item.height <= 0)),
    );

    if (missingMetadata.isNotEmpty) {
      recommendations.add(
        'Refresh metadata for ${missingMetadata.length} media item${missingMetadata.length == 1 ? '' : 's'} so storage and quality details are accurate.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add('This card looks polished and ready for export.');
    }

    return recommendations;
  }
}
