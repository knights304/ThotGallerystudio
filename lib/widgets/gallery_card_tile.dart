import 'package:flutter/material.dart';

import '../models/gallery_card.dart';
import 'collectible_card.dart';

class GalleryCardTile extends StatelessWidget {
  const GalleryCardTile({
    super.key,
    required this.card,
    required this.onTap,
    required this.onFavorite,
    this.onLongPress,
  });

  final GalleryCard card;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: 'gallery-piece-${card.id}',
              child: CollectibleCard(
                card: card,
                compact: true,
                onTap: onTap,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                card.status == GalleryCardStatus.idea
                    ? 'DRAFT'
                    : card.rarity.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filledTonal(
              tooltip: 'Favorite',
              onPressed: onFavorite,
              icon: Icon(
                card.isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
