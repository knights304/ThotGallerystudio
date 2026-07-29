import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/gallery_card.dart';

class MediaGridTile extends StatelessWidget {
  const MediaGridTile({
    super.key,
    required this.mediaItem,
    required this.isCover,
    required this.onTap,
    required this.onDelete,
    required this.onSetCover,
    this.selected = false,
  });

  final GalleryMediaItem mediaItem;
  final bool isCover;
  final bool selected;

  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onSetCover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2.5 : 1,
          ),
          color: theme.colorScheme.surfaceContainerHighest,
          boxShadow: [
            BoxShadow(
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [

              //--------------------------------------------------
              // Thumbnail
              //--------------------------------------------------

              _buildThumbnail(),

              //--------------------------------------------------
              // Gradient
              //--------------------------------------------------

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              //--------------------------------------------------
              // Cover Badge
              //--------------------------------------------------

              if (isCover)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Cover',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              //--------------------------------------------------
              // Video Badge
              //--------------------------------------------------

              if (mediaItem.type == GalleryMediaType.video)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              //--------------------------------------------------
              // Tap Overlay
              //--------------------------------------------------

              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                  ),
                ),
              ),

              //--------------------------------------------------
              // Popup Menu
              //--------------------------------------------------

              Positioned(
                right: 6,
                top: 6,
                child: PopupMenuButton<String>(
                  tooltip: 'Media Options',
                  onSelected: (value) {
                    switch (value) {
                      case 'cover':
                        onSetCover();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!isCover &&
                        mediaItem.type == GalleryMediaType.photo)
                      const PopupMenuItem(
                        value: 'cover',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline),
                            SizedBox(width: 10),
                            Text('Set as Cover'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (mediaItem.type == GalleryMediaType.photo) {
      final file = File(mediaItem.path);

      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _missingTile(),
        );
      }

      return _missingTile();
    }

    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 70,
        ),
      ),
    );
  }

  Widget _missingTile() {
    return Container(
      color: Colors.grey.shade300,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              'Missing File',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
