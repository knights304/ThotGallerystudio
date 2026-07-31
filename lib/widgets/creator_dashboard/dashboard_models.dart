enum CardQualityBadge {
  bronze,
  silver,
  gold,
  diamond,
}

class DashboardCheck {
  const DashboardCheck({
    required this.label,
    required this.isComplete,
    this.detail = '',
  });

  final String label;
  final bool isComplete;
  final String detail;
}

class CreatorDashboardData {
  const CreatorDashboardData({
    required this.healthScore,
    required this.healthLabel,
    required this.badge,
    required this.photoCount,
    required this.videoCount,
    required this.totalBytes,
    required this.maxBytes,
    required this.maxPhotos,
    required this.maxVideos,
    required this.exportChecks,
    required this.recommendations,
    required this.isExportReady,
  });

  final int healthScore;
  final String healthLabel;
  final CardQualityBadge badge;
  final int photoCount;
  final int videoCount;
  final int totalBytes;
  final int maxBytes;
  final int maxPhotos;
  final int maxVideos;
  final List<DashboardCheck> exportChecks;
  final List<String> recommendations;
  final bool isExportReady;

  double get storageProgress =>
      maxBytes <= 0 ? 0 : (totalBytes / maxBytes).clamp(0.0, 1.0);

  double get photoProgress =>
      maxPhotos <= 0 ? 0 : (photoCount / maxPhotos).clamp(0.0, 1.0);

  double get videoProgress =>
      maxVideos <= 0 ? 0 : (videoCount / maxVideos).clamp(0.0, 1.0);

  int get remainingBytes => (maxBytes - totalBytes).clamp(0, maxBytes);
}
