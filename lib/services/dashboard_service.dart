import '../models/gallery_card.dart';
import '../widgets/creator_dashboard/dashboard_models.dart';

class DashboardService {
  const DashboardService._();

  static const int defaultMaximumBytes = 500 * 1024 * 1024;
  static const int defaultMaximumPhotos = 50;
  static const int defaultMaximumVideos = 10;

  /// Builds dashboard data directly from the values currently being edited.
  ///
  /// This method matches the call already used in card_editor_screen.dart:
  ///
  /// DashboardService.calculate(
  ///   title: _title.text,
  ///   coverImagePath: _coverImagePath,
  ///   media: _media,
  /// )
  static CreatorDashboardData calculate({
    required String title,
    required String? coverImagePath,
    required List<GalleryMediaItem> media,
    String description = '',
    List<String> tags = const [],
    String setName = '',
    String rarity = '',
    int cardNumber = 1,
    int setTotal = 1,
    int maximumBytes = defaultMaximumBytes,
    int maximumPhotos = defaultMaximumPhotos,
    int maximumVideos = defaultMaximumVideos,
  }) {
    final trimmedTitle = title.trim();
    final trimmedDescription = description.trim();
    final trimmedCoverPath = (coverImagePath ?? '').trim();

    final photoCount = media
        .where((item) => item.type == GalleryMediaType.photo)
        .length;

    final videoCount = media
        .where((item) => item.type == GalleryMediaType.video)
        .length;

    final totalBytes = media.fold<int>(
      0,
      (sum, item) => sum + item.sizeBytes.clamp(0, 1 << 62),
    );

    final hasTitle = trimmedTitle.isNotEmpty;
    final hasDescription = trimmedDescription.isNotEmpty;
    final hasCover = trimmedCoverPath.isNotEmpty;
    final hasMedia = media.isNotEmpty;
    final hasTags = tags.isNotEmpty;
    final hasSetName = setName.trim().isNotEmpty;
    final hasRarity = rarity.trim().isNotEmpty;
    final hasCardNumber = cardNumber > 0 && setTotal > 0;
    final withinStorageLimit = totalBytes <= maximumBytes;
    final withinPhotoLimit = photoCount <= maximumPhotos;
    final withinVideoLimit = videoCount <= maximumVideos;
    final allMediaHavePaths =
        media.every((item) => item.path.trim().isNotEmpty);

    var healthScore = 0;

    if (hasTitle) healthScore += 20;
    if (hasCover) healthScore += 20;
    if (hasMedia) healthScore += 20;
    if (hasDescription) healthScore += 10;
    if (hasTags) healthScore += 10;
    if (hasSetName) healthScore += 5;
    if (hasRarity) healthScore += 5;
    if (hasCardNumber) healthScore += 5;
    if (withinStorageLimit &&
        withinPhotoLimit &&
        withinVideoLimit &&
        allMediaHavePaths) {
      healthScore += 5;
    }

    healthScore = healthScore.clamp(0, 100);

    final exportChecks = <DashboardCheck>[
      DashboardCheck(
        label: 'Card title',
        isComplete: hasTitle,
        detail: hasTitle
            ? 'A title is ready.'
            : 'Add a title before exporting.',
      ),
      DashboardCheck(
        label: 'Cover image',
        isComplete: hasCover,
        detail: hasCover
            ? 'Cover art is selected.'
            : 'Choose a cover image.',
      ),
      DashboardCheck(
        label: 'Media attached',
        isComplete: hasMedia,
        detail: hasMedia
            ? '${media.length} media item${media.length == 1 ? '' : 's'} attached.'
            : 'Add at least one photo or video.',
      ),
      DashboardCheck(
        label: 'Storage limit',
        isComplete: withinStorageLimit,
        detail: withinStorageLimit
            ? 'The package is within the storage limit.'
            : 'Remove or compress media before export.',
      ),
      DashboardCheck(
        label: 'Photo limit',
        isComplete: withinPhotoLimit,
        detail: '$photoCount of $maximumPhotos photos used.',
      ),
      DashboardCheck(
        label: 'Video limit',
        isComplete: withinVideoLimit,
        detail: '$videoCount of $maximumVideos videos used.',
      ),
      DashboardCheck(
        label: 'Media file paths',
        isComplete: allMediaHavePaths,
        detail: allMediaHavePaths
            ? 'All media items have a valid file path.'
            : 'One or more media items are missing a file path.',
      ),
    ];

    final recommendations = <String>[];

    if (!hasTitle) {
      recommendations.add(
        'Give this card a title so it is easy to identify.',
      );
    }

    if (!hasCover) {
      recommendations.add(
        'Choose a cover image to make the card presentation-ready.',
      );
    }

    if (!hasDescription) {
      recommendations.add(
        'Add a short story or summary to give the card more context.',
      );
    }

    if (!hasMedia) {
      recommendations.add(
        'Add at least one photo or video to bring this card to life.',
      );
    }

    if (!hasTags) {
      recommendations.add(
        'Add a few tags so the card is easier to organize and discover.',
      );
    }

    if (!withinStorageLimit) {
      recommendations.add(
        'Reduce the media size. The package is over its storage limit.',
      );
    }

    if (!withinPhotoLimit) {
      final overBy = photoCount - maximumPhotos;
      recommendations.add(
        'Remove $overBy photo${overBy == 1 ? '' : 's'} to meet the photo limit.',
      );
    }

    if (!withinVideoLimit) {
      final overBy = videoCount - maximumVideos;
      recommendations.add(
        'Remove $overBy video${overBy == 1 ? '' : 's'} to meet the video limit.',
      );
    }

    if (!allMediaHavePaths) {
      recommendations.add(
        'Refresh or re-import media with missing file paths.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'This card looks polished and ready for export.',
      );
    }

    final isExportReady =
        exportChecks.every((check) => check.isComplete);

    return CreatorDashboardData(
      healthScore: healthScore,
      healthLabel: _healthLabel(healthScore),
      badge: _qualityBadge(healthScore),
      photoCount: photoCount,
      videoCount: videoCount,
      totalBytes: totalBytes,
      maxBytes: maximumBytes,
      maxPhotos: maximumPhotos,
      maxVideos: maximumVideos,
      exportChecks: exportChecks,
      recommendations: recommendations,
      isExportReady: isExportReady,
    );
  }

  /// Builds dashboard data from a complete GalleryCard model.
  ///
  /// Keeping this method allows other screens and future services to use the
  /// same dashboard engine without manually passing every field.
  static CreatorDashboardData build(
    GalleryCard card, {
    int maximumBytes = defaultMaximumBytes,
    int maximumPhotos = defaultMaximumPhotos,
    int maximumVideos = defaultMaximumVideos,
  }) {
    return calculate(
      title: card.title,
      coverImagePath: card.coverImagePath,
      media: card.media,
      description: card.description,
      tags: card.tags,
      setName: card.setName,
      rarity: card.rarity,
      cardNumber: card.cardNumber,
      setTotal: card.setTotal,
      maximumBytes: maximumBytes,
      maximumPhotos: maximumPhotos,
      maximumVideos: maximumVideos,
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';

    const int kilobyte = 1024;
    const int megabyte = 1024 * 1024;
    const int gigabyte = 1024 * 1024 * 1024;
    const int terabyte = 1024 * 1024 * 1024 * 1024;

    if (bytes >= terabyte) {
      return '${(bytes / terabyte).toStringAsFixed(2)} TB';
    }

    if (bytes >= gigabyte) {
      return '${(bytes / gigabyte).toStringAsFixed(2)} GB';
    }

    if (bytes >= megabyte) {
      return '${(bytes / megabyte).toStringAsFixed(1)} MB';
    }

    if (bytes >= kilobyte) {
      return '${(bytes / kilobyte).toStringAsFixed(1)} KB';
    }

    return '$bytes B';
  }

  static String _healthLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Great';
    if (score >= 55) return 'Good';
    if (score >= 35) return 'Building';
    return 'Needs Attention';
  }

  static CardQualityBadge _qualityBadge(int score) {
    if (score >= 90) return CardQualityBadge.diamond;
    if (score >= 75) return CardQualityBadge.gold;
    if (score >= 55) return CardQualityBadge.silver;
    return CardQualityBadge.bronze;
  }
}
