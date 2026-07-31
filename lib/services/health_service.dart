import '../models/gallery_card.dart';
import '../widgets/creator_dashboard/dashboard_models.dart';

class HealthService {
  const HealthService._();

  static int calculateScore(GalleryCard card) {
    var score = 0;

    if (card.title.trim().isNotEmpty) score += 15;
    if (card.description.trim().isNotEmpty) score += 10;
    if ((card.coverImagePath ?? '').trim().isNotEmpty) score += 20;
    if (card.media.isNotEmpty) score += 15;
    if (card.tags.isNotEmpty) score += 10;
    if (card.setName.trim().isNotEmpty) score += 5;
    if (card.rarity.trim().isNotEmpty) score += 5;
    if (card.cardNumber > 0 && card.setTotal > 0) score += 5;
    if (card.media.any((item) => item.sizeBytes > 0)) score += 5;
    if (card.media.every(
      (item) => item.contentHash.isNotEmpty || item.path.isEmpty,
    )) {
      score += 5;
    }
    if (card.media.every(
      (item) =>
          item.type == GalleryMediaType.video ||
          (item.width > 0 && item.height > 0),
    )) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  static String labelForScore(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Great';
    if (score >= 55) return 'Good';
    if (score >= 35) return 'Building';
    return 'Needs Attention';
  }

  static CardQualityBadge badgeForScore(int score) {
    if (score >= 90) return CardQualityBadge.diamond;
    if (score >= 75) return CardQualityBadge.gold;
    if (score >= 55) return CardQualityBadge.silver;
    return CardQualityBadge.bronze;
  }
}
