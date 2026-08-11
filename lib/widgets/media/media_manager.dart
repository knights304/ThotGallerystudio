import 'package:flutter/material.dart';

import '../../models/gallery_card.dart';
import 'media_controller.dart';
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
  late final MediaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MediaController(media: widget.media);
  }

  @override
  void didUpdateWidget(covariant MediaManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.replaceMedia(widget.media);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _notifyMediaChanged() {
    widget.onMediaChanged(_controller.media);
  }

  void _setCover(GalleryMediaItem item) {
    if (item.type != GalleryMediaType.photo) {
      return;
    }

    _controller.select(item);
    widget.onCoverChanged(item.path);
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
    final previousCoverPath = widget.coverImagePath;
    final removedWasCover = previousCoverPath == item.path;
    final removed = _controller.removeAt(index);

    if (removed == null) {
      return;
    }

    if (removedWasCover) {
      widget.onCoverChanged(_controller.firstPhotoPath());
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
              final restored = _controller.restore(
                item: item,
                originalIndex: index,
              );

              if (!restored) {
                return;
              }

              _notifyMediaChanged();

              if (previousCoverPath != widget.coverImagePath) {
                widget.onCoverChanged(previousCoverPath);
              }
            },
          ),
        ),
      );
  }

  void _reorderMedia({
    required String draggedMediaId,
    required String targetMediaId,
  }) {
    final changed = _controller.reorderById(
      draggedMediaId: draggedMediaId,
      targetMediaId: targetMediaId,
    );

    if (changed) {
      _notifyMediaChanged();
    }
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

  Widget _buildDragFeedback(
    BuildContext context,
    GalleryMediaItem item,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    final feedbackWidth = width < 600 ? 150.0 : 180.0;

    return Material(
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: feedbackWidth,
        child: Opacity(
          opacity: 0.92,
          child: MediaGridTile(
            mediaItem: item,
            isCover: widget.coverImagePath == item.path,
            selected: true,
            onTap: () {},
            onSetCover: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTile({
    required BuildContext context,
    required GalleryMediaItem item,
    required int index,
  }) {
    final tile = MediaGridTile(
      key: ValueKey(item.id),
      mediaItem: item,
      isCover: widget.coverImagePath == item.path,
      selected: _controller.isSelected(item),
      onTap: () => _controller.toggleSelection(item),
      onSetCover: () => _setCover(item),
      onDelete: () => _requestDelete(item, index),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        return details.data != item.id;
      },
      onAcceptWithDetails: (details) {
        _reorderMedia(
          draggedMediaId: details.data,
          targetMediaId: item.id,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: isTargeted ? 3 : 0,
              color: isTargeted
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: LongPressDraggable<String>(
            data: item.id,
            delay: const Duration(milliseconds: 250),
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () => _controller.beginDrag(item.id),
            onDragEnd: (_) => _controller.endDrag(),
            onDraggableCanceled: (_, __) => _controller.endDrag(),
            feedback: _buildDragFeedback(context, item),
            childWhenDragging: Opacity(
              opacity: 0.28,
              child: tile,
            ),
            child: tile,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final media = _controller.media;

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MediaManagerHeader(
                  totalCount: _controller.totalCount,
                  photoCount: _controller.photoCount,
                  videoCount: _controller.videoCount,
                  onAddPhotos: widget.onAddPhotos,
                  onAddVideo: widget.onAddVideo,
                ),
                const SizedBox(height: 16),
                if (_controller.isEmpty)
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
                        itemCount: media.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columnCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: _calculateAspectRatio(
                            constraints.maxWidth,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          return _buildDraggableTile(
                            context: context,
                            item: media[index],
                            index: index,
                          );
                        },
                      );
                    },
                  ),
                if (_controller.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Press and hold a media tile, then drag it onto '
                          'another tile to change the display order.',
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
      },
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
      constraints: const BoxConstraints(minHeight: 230),
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
