import 'package:flutter/material.dart';

import '../../models/gallery_card.dart';

/// Displays a confirmation dialog before removing a media item.
///
/// Returns:
/// - `true` when the user confirms deletion.
/// - `false` when the user cancels.
/// - `null` if the dialog is dismissed externally.
Future<bool?> showMediaDeleteDialog({
  required BuildContext context,
  required GalleryMediaItem mediaItem,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return MediaDeleteDialog(mediaItem: mediaItem);
    },
  );
}

class MediaDeleteDialog extends StatelessWidget {
  const MediaDeleteDialog({
    super.key,
    required this.mediaItem,
  });

  final GalleryMediaItem mediaItem;

  String get _fileName {
    final normalizedPath = mediaItem.path.replaceAll('\\', '/');
    final segments = normalizedPath.split('/');

    if (segments.isEmpty || segments.last.trim().isEmpty) {
      return mediaItem.type == GalleryMediaType.video
          ? 'Untitled video'
          : 'Untitled photo';
    }

    return segments.last;
  }

  String get _mediaTypeLabel {
    return switch (mediaItem.type) {
      GalleryMediaType.photo => 'photo',
      GalleryMediaType.video => 'video',
    };
  }

  IconData get _mediaIcon {
    return switch (mediaItem.type) {
      GalleryMediaType.photo => Icons.image_outlined,
      GalleryMediaType.video => Icons.video_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.delete_forever_outlined,
        color: colorScheme.error,
        size: 34,
      ),
      title: const Text('Delete media?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Remove this $_mediaTypeLabel from the card?',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _mediaIcon,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 19,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The item will be removed from this card. '
                    'The original file will remain on your device.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}
