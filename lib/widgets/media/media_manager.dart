import 'package:flutter/material.dart';

import '../../models/gallery_card.dart';
import 'media_delete_dialog.dart';
import 'media_grid_tile.dart';

class MediaManager extends StatefulWidget {
  const MediaManager({
    super.key,
    required this.media,
    required this.coverImagePath,
    required this.onMediaChanged,
    required this.onCoverChanged,
    this.onAddPhotos,
    this.onAddVideo,
  });

  final List<GalleryMediaItem> media;
  final String? coverImagePath;

  final ValueChanged<List<GalleryMediaItem>> onMediaChanged;
  final ValueChanged<String?> onCoverChanged;

  final VoidCallback? onAddPhotos;
  final VoidCallback? onAddVideo;

  @override
  State<MediaManager> createState() => _MediaManagerState();
}

class _MediaManagerState extends State<MediaManager> {
  late List<GalleryMediaItem> _media;

  String? _selectedMediaId;

  @override
  void initState() {
    super.initState();
    _media = List<GalleryMediaItem>.from(widget.media);
  }

  @override
  void didUpdateWidget(covariant MediaManager oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sameMediaList(oldWidget.media, widget.media)) {
      _media = List<GalleryMediaItem>.from(widget.media);

      final selectedStillExists = _media.any(
        (item) => item.id == _selectedMediaId,
      );

      if (!selectedStillExists) {
        _selectedMediaId = null;
      }
    }
  }

  bool _sameMediaList(
    List<GalleryMediaItem> first,
    List<GalleryMediaItem> second,
  ) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      final firstItem = first[index];
      final secondItem = second[index];

      if (firstItem.id != secondItem.id ||
          firstItem.path != secondItem.path ||
          firstItem.type != secondItem.type) {
        return false;
      }
    }

    return true;
  }

  void _notifyMediaChanged() {
    widget.onMediaChanged(
      List<GalleryMediaItem>.unmodifiable(_media),
    );
  }

  void _selectMedia(GalleryMediaItem item) {
    setState(() {
      if (_selectedMediaId == item.id) {
        _selectedMediaId = null;
      } else {
        _selectedMediaId = item.id;
      }
    });
  }

  void _setCover(GalleryMediaItem item) {
    if (item.type != GalleryMediaType.photo) {
      return;
    }

    widget.onCoverChanged(item.path);

    setState(() {
      _selectedMediaId = item.id;
    });
  }

  Future<void> _requestDelete(
    GalleryMediaItem item,
    int index,
  ) async {
    final confirmed = await showMediaDeleteDialog(
      context: context,
      mediaItem: item,
    );

    if (!mounted || confirmed != true) {
      return;
    }

    _deleteMedia(item, index);
  }

  void _deleteMedia(
    GalleryMediaItem item,
    int index,
  ) {
    if (index < 0 || index >= _media.length) {
      return;
    }

    final previousCoverPath = widget.coverImagePath;
    final removedWasCover = previousCoverPath == item.path;

    setState(() {
      _media.removeAt(index);

      if (_selectedMediaId == item.id) {
        _selectedMediaId = null;
      }
    });

    String? replacementCoverPath = previousCoverPath;

    if (removedWasCover) {
      replacementCoverPath = _findFirstPhotoPath();
      widget.onCoverChanged(replacementCoverPath);
    }

    _notifyMediaChanged();

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            item.type == GalleryMediaType.video
                ? 'Video removed from the card.'
                : 'Photo removed from the card.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _restoreDeletedMedia(
                item: item,
                originalIndex: index,
                previousCoverPath: previousCoverPath,
              );
            },
          ),
        ),
      );
  }

  void _restoreDeletedMedia({
    required GalleryMediaItem item,
    required int originalIndex,
    required String? previousCoverPath,
  }) {
    if (_media.any((existingItem) => existingItem.id == item.id)) {
      return;
    }

    final safeIndex = originalIndex.clamp(0, _media.length);

    setState(() {
      _media.insert(safeIndex, item);
      _selectedMediaId = item.id;
    });

    _notifyMediaChanged();

    if (previousCoverPath != widget.coverImagePath) {
      widget.onCoverChanged(previousCoverPath);
    }
  }

  String? _findFirstPhotoPath() {
    for (final item in _media) {
      if (item.type == GalleryMediaType.photo) {
        return item.path;
      }
    }

    return null;
  }

  int _calculateColumnCount(double width) {
    if (width >= 1200) {
      return 6;
    }

    if (width >= 900) {
      return 5;
    }

    if (width >= 680) {
      return 4;
    }

    if (width >= 460) {
      return 3;
    }

    return 2;
  }

  double _calculateAspectRatio(double width) {
    if (width < 400) {
      return 0.86;
    }

    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoCount = _media
        .where((item) => item.type == GalleryMediaType.photo)
        .length;
    final videoCount = _media
        .where((item) => item.type == GalleryMediaType.video)
        .length;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MediaManagerHeader(
              totalCount: _media.length,
              photoCount: photoCount,
              videoCount: videoCount,
              onAddPhotos: widget.onAddPhotos,
              onAddVideo: widget.onAddVideo,
            ),
            const SizedBox(height: 16),
            if (_media.isEmpty)
              _MediaEmptyState(
                onAddPhotos: widget.onAddPhotos,
                onAddVideo: widget.onAddVideo,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columnCount = _calculateColumnCount(
                    constraints.maxWidth,
                  );

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _media.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: _calculateAspectRatio(
                        constraints.maxWidth,
                      ),
                    ),
                    itemBuilder: (context, index) {
                      final item = _media[index];

                      return MediaGridTile(
                        key: ValueKey(item.id),
                        mediaItem: item,
                        isCover: widget.coverImagePath == item.path,
                        selected: _selectedMediaId == item.id,
                        onTap: () => _selectMedia(item),
                        onSetCover: () => _setCover(item),
                        onDelete: () => _requestDelete(item, index),
                      );
                    },
                  );
                },
              ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Select an item to highlight it. Use the menu on a photo '
                      'to make it the card cover or remove it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MediaManagerHeader extends StatelessWidget {
  const _MediaManagerHeader({
    required this.totalCount,
    required this.photoCount,
    required this.videoCount,
    required this.onAddPhotos,
    required this.onAddVideo,
  });

  final int totalCount;
  final int photoCount;
  final int videoCount;

  final VoidCallback? onAddPhotos;
  final VoidCallback? onAddVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Living Media',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _buildSummary(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onAddPhotos != null)
              FilledButton.tonalIcon(
                onPressed: onAddPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Photos'),
              ),
            if (onAddVideo != null)
              OutlinedButton.icon(
                onPressed: onAddVideo,
                icon: const Icon(Icons.video_library_outlined),
                label: const Text('Add Video'),
              ),
          ],
        ),
      ],
    );
  }

  String _buildSummary() {
    if (totalCount == 0) {
      return 'No media added yet';
    }

    final photoLabel = photoCount == 1 ? 'photo' : 'photos';
    final videoLabel = videoCount == 1 ? 'video' : 'videos';

    if (photoCount > 0 && videoCount > 0) {
      return '$totalCount items · $photoCount $photoLabel · '
          '$videoCount $videoLabel';
    }

    if (photoCount > 0) {
      return '$photoCount $photoLabel';
    }

    return '$videoCount $videoLabel';
  }
}

class _MediaEmptyState extends StatelessWidget {
  const _MediaEmptyState({
    required this.onAddPhotos,
    required this.onAddVideo,
  });

  final VoidCallback? onAddPhotos;
  final VoidCallback? onAddVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 230,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.collections_outlined,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Build your media collection',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Add photos or videos to bring this gallery card to life.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (onAddPhotos != null || onAddVideo != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (onAddPhotos != null)
                  FilledButton.icon(
                    onPressed: onAddPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add Photos'),
                  ),
                if (onAddVideo != null)
                  OutlinedButton.icon(
                    onPressed: onAddVideo,
                    icon: const Icon(Icons.video_library_outlined),
                    label: const Text('Add Video'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
