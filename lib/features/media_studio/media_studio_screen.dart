import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/media/media_engine.dart';
import '../../models/gallery_card.dart';
import '../../services/gallery_store.dart';
import '../../theme/gallery_theme.dart';
import '../../widgets/living_media_gallery.dart';

enum _MediaFilter { all, photos, videos, favorites, rated, tagged, unrated }

enum _MediaSort { custom, newest, rating, name, size }

class MediaStudioScreen extends StatefulWidget {
  const MediaStudioScreen({super.key, required this.store});

  final GalleryStore store;

  @override
  State<MediaStudioScreen> createState() => _MediaStudioScreenState();
}

class _MediaStudioScreenState extends State<MediaStudioScreen> {
  final _engine = MediaEngine();
  final _picker = ImagePicker();
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};

  GalleryCard? _card;
  GalleryMediaItem? _inspected;
  _MediaFilter _filter = _MediaFilter.all;
  _MediaSort _sort = _MediaSort.custom;
  bool _grid = true;
  bool _dragging = false;
  bool _busy = false;
  double _tileWidth = 220;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refreshFromStore);
    if (widget.store.cards.isNotEmpty) {
      _card = widget.store.cards.first;
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refreshFromStore);
    _search.dispose();
    super.dispose();
  }

  void _refreshFromStore() {
    if (!mounted) return;
    final id = _card?.id;
    if (id != null) {
      _card = widget.store.cards.where((card) => card.id == id).firstOrNull;
    }
    final inspectedId = _inspected?.id;
    if (inspectedId != null && _card != null) {
      _inspected =
          _card!.media.where((item) => item.id == inspectedId).firstOrNull;
    }
    setState(() {});
  }

  List<GalleryMediaItem> get _visible {
    final card = _card;
    if (card == null) return const [];
    final query = _search.text.trim().toLowerCase();
    final result = card.media.where((item) {
      final matchesFilter = switch (_filter) {
        _MediaFilter.all => true,
        _MediaFilter.photos => item.type == GalleryMediaType.photo,
        _MediaFilter.videos => item.type == GalleryMediaType.video,
        _MediaFilter.favorites => item.isFavorite,
        _MediaFilter.rated => item.rating > 0,
        _MediaFilter.tagged => item.tags.isNotEmpty,
        _MediaFilter.unrated => item.rating == 0,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final haystack = [
        item.filename,
        item.caption,
        ...item.tags,
        ...item.collections,
        item.dimensionsLabel,
        item.sizeLabel,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    switch (_sort) {
      case _MediaSort.custom:
        result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      case _MediaSort.newest:
        result.sort((a, b) => (b.importedAt ?? DateTime(2000))
            .compareTo(a.importedAt ?? DateTime(2000)));
      case _MediaSort.rating:
        result.sort((a, b) => b.rating.compareTo(a.rating));
      case _MediaSort.name:
        result.sort((a, b) =>
            a.filename.toLowerCase().compareTo(b.filename.toLowerCase()));
      case _MediaSort.size:
        result.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
    return result;
  }

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage(imageQuality: 100);
    await _importPaths(files.map((file) => file.path));
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      await _importPaths(<String>[file.path]);
    }
  }

  Future<void> _importPaths(Iterable<String> paths) async {
    final card = _card;
    if (card == null || _busy) return;
    setState(() => _busy = true);
    try {
      final prepared = await _engine.preparePaths(
        paths,
        startingOrder: card.media.length,
        existingItems: card.media,
      );
      if (prepared.items.isNotEmpty) {
        card.media = <GalleryMediaItem>[...card.media, ...prepared.items];
        card.coverImagePath ??= prepared.items
            .where((item) => item.type == GalleryMediaType.photo)
            .firstOrNull
            ?.path;
        await widget.store.upsertCard(card);
      }
      if (!mounted) return;
      final parts = <String>['Imported ${prepared.items.length}'];
      if (prepared.duplicatePaths.isNotEmpty) {
        parts.add('skipped ${prepared.duplicatePaths.length} duplicate(s)');
      }
      if (prepared.rejectedPaths.isNotEmpty) {
        parts.add(
            'rejected ${prepared.rejectedPaths.length} unsupported file(s)');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${parts.join(' • ')}.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final card = _card;
    if (card == null) return;
    for (var index = 0; index < card.media.length; index++) {
      card.media[index].sortOrder = index;
    }
    await widget.store.upsertCard(card);
  }

  Future<void> _editItem(GalleryMediaItem item) async {
    final caption = TextEditingController(text: item.caption);
    final tags = TextEditingController(text: item.tags.join(', '));
    final collections =
        TextEditingController(text: item.collections.join(', '));
    var rating = item.rating;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Media details'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: caption,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Caption'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'portrait, purple, VIP',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: collections,
                    decoration: const InputDecoration(
                      labelText: 'Collections',
                      hintText: 'Summer, Creator, 2026',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _RatingPicker(
                    rating: rating,
                    onChanged: (value) => setDialogState(() => rating = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (result == true) {
      item.caption = caption.text.trim();
      item.tags = _parseCsv(tags.text);
      item.collections = _parseCsv(collections.text);
      item.rating = rating;
      await _save();
    }
    caption.dispose();
    tags.dispose();
    collections.dispose();
  }

  List<String> _parseCsv(String value) => value
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _setCover(GalleryMediaItem item) async {
    if (item.type != GalleryMediaType.photo || _card == null) return;
    _card!.coverImagePath = item.path;
    await _save();
  }

  Future<void> _toggleFavorite(GalleryMediaItem item) async {
    item.isFavorite = !item.isFavorite;
    await _save();
  }

  void _toggleSelection(GalleryMediaItem item) {
    setState(() {
      if (!_selected.add(item.id)) _selected.remove(item.id);
      _inspected = item;
    });
  }

  Future<void> _deleteSelected() async {
    final card = _card;
    if (card == null || _selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${_selected.length} media item(s)?'),
        content: const Text(
            'The original files stay on your device. They will only be removed from this Gallery Piece.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    card.media.removeWhere((item) => _selected.contains(item.id));
    if (_inspected != null && _selected.contains(_inspected!.id)) {
      _inspected = null;
    }
    _selected.clear();
    await _save();
  }

  Future<void> _favoriteSelected() async {
    final card = _card;
    if (card == null) return;
    for (final item
        in card.media.where((item) => _selected.contains(item.id))) {
      item.isFavorite = true;
    }
    await _save();
  }

  Future<void> _rateSelected(int rating) async {
    final card = _card;
    if (card == null) return;
    for (final item
        in card.media.where((item) => _selected.contains(item.id))) {
      item.rating = rating;
    }
    await _save();
  }

  Future<void> _tagSelected() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tag ${_selected.length} selected item(s)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Tags', hintText: 'purple, VIP, portrait'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (accepted == true) {
      final tags = _parseCsv(controller.text);
      final card = _card;
      if (card != null) {
        for (final item
            in card.media.where((item) => _selected.contains(item.id))) {
          item.tags = <String>{...item.tags, ...tags}.toList();
        }
        await _save();
      }
    }
    controller.dispose();
  }

  void _openViewer(int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(_card?.title ?? 'Media')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LivingMediaGallery(media: _visible, initialIndex: index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.store.cards;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _importPaths(detail.files.map((file) => file.path));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media Studio Pro'),
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            IconButton(
              tooltip: _grid ? 'List view' : 'Grid view',
              onPressed: () => setState(() => _grid = !_grid),
              icon: Icon(
                  _grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (cards.isEmpty)
              const _NoPieces()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 980;
                  return Column(
                    children: [
                      _TopToolbar(
                        cards: cards,
                        selectedCard: _card,
                        onCardChanged: (card) => setState(() {
                          _card = card;
                          _selected.clear();
                          _inspected = null;
                        }),
                        search: _search,
                        onSearch: (_) => setState(() {}),
                        sort: _sort,
                        onSort: (value) => setState(() => _sort = value),
                        onPhotos: _busy ? null : _pickPhotos,
                        onVideo: _busy ? null : _pickVideo,
                      ),
                      if (_selected.isNotEmpty)
                        _BatchBar(
                          count: _selected.length,
                          onFavorite: _favoriteSelected,
                          onDelete: _deleteSelected,
                          onTag: _tagSelected,
                          onRate: _rateSelected,
                          onClear: () => setState(_selected.clear),
                        ),
                      Expanded(
                        child: desktop
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: 220,
                                    child: _LibrarySidebar(
                                      card: _card,
                                      filter: _filter,
                                      onFilter: (value) =>
                                          setState(() => _filter = value),
                                    ),
                                  ),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: _buildCenter()),
                                  const VerticalDivider(width: 1),
                                  SizedBox(
                                    width: 300,
                                    child: _PropertiesPanel(
                                      item: _inspected,
                                      isCover: _inspected != null &&
                                          _card?.coverImagePath ==
                                              _inspected!.path,
                                      onFavorite: _inspected == null
                                          ? null
                                          : () => _toggleFavorite(_inspected!),
                                      onEdit: _inspected == null
                                          ? null
                                          : () => _editItem(_inspected!),
                                      onCover: _inspected == null
                                          ? null
                                          : () => _setCover(_inspected!),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  SizedBox(
                                    height: 58,
                                    child: _CompactFilters(
                                      filter: _filter,
                                      onFilter: (value) =>
                                          setState(() => _filter = value),
                                    ),
                                  ),
                                  Expanded(child: _buildCenter()),
                                ],
                              ),
                      ),
                      _StatusBar(
                        visible: _visible.length,
                        total: _card?.media.length ?? 0,
                        selected: _selected.length,
                        tileWidth: _tileWidth,
                        onTileWidth: (value) =>
                            setState(() => _tileWidth = value),
                      ),
                    ],
                  );
                },
              ),
            if (_dragging)
              Positioned.fill(
                child: Container(
                  color: GalleryColors.black.withValues(alpha: 0.9),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_upload_rounded,
                          size: 86, color: GalleryColors.purpleBright),
                      SizedBox(height: 14),
                      Text('Drop photos and videos here',
                          style: TextStyle(
                              fontSize: 25, fontWeight: FontWeight.w900)),
                      SizedBox(height: 6),
                      Text('Duplicates are detected automatically.',
                          style: TextStyle(color: GalleryColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenter() {
    final items = _visible;
    if (items.isEmpty) {
      return _EmptyMedia(onPhotos: _pickPhotos, onVideo: _pickVideo);
    }
    if (!_grid) {
      return _MediaList(
        items: items,
        selected: _selected,
        coverPath: _card?.coverImagePath,
        onTap: _openViewer,
        onSelect: _toggleSelection,
        onInspect: (item) => setState(() => _inspected = item),
        onFavorite: _toggleFavorite,
        onEdit: _editItem,
        onCover: _setCover,
      );
    }
    return _MediaGrid(
      items: items,
      selected: _selected,
      coverPath: _card?.coverImagePath,
      tileWidth: _tileWidth,
      onTap: _openViewer,
      onSelect: _toggleSelection,
      onInspect: (item) => setState(() => _inspected = item),
      onFavorite: _toggleFavorite,
      onEdit: _editItem,
      onCover: _setCover,
    );
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.cards,
    required this.selectedCard,
    required this.onCardChanged,
    required this.search,
    required this.onSearch,
    required this.sort,
    required this.onSort,
    required this.onPhotos,
    required this.onVideo,
  });

  final List<GalleryCard> cards;
  final GalleryCard? selectedCard;
  final ValueChanged<GalleryCard> onCardChanged;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final _MediaSort sort;
  final ValueChanged<_MediaSort> onSort;
  final VoidCallback? onPhotos;
  final VoidCallback? onVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: GalleryColors.surface,
        border: Border(bottom: BorderSide(color: Color(0x337D6C8E))),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<GalleryCard>(
              initialValue: selectedCard,
              decoration: const InputDecoration(
                  labelText: 'Gallery Piece', isDense: true),
              items: cards
                  .map((card) => DropdownMenuItem(
                      value: card,
                      child: Text(card.title, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                if (value != null) onCardChanged(value);
              },
            ),
          ),
          SizedBox(
            width: 290,
            child: TextField(
              controller: search,
              onChanged: onSearch,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search filename, caption, tag…',
              ),
            ),
          ),
          SizedBox(
            width: 175,
            child: DropdownButtonFormField<_MediaSort>(
              initialValue: sort,
              decoration:
                  const InputDecoration(labelText: 'Sort', isDense: true),
              items: const [
                DropdownMenuItem(
                    value: _MediaSort.custom, child: Text('Custom order')),
                DropdownMenuItem(
                    value: _MediaSort.newest, child: Text('Newest')),
                DropdownMenuItem(
                    value: _MediaSort.rating, child: Text('Highest rated')),
                DropdownMenuItem(
                    value: _MediaSort.name, child: Text('Filename')),
                DropdownMenuItem(
                    value: _MediaSort.size, child: Text('Largest file')),
              ],
              onChanged: (value) {
                if (value != null) onSort(value);
              },
            ),
          ),
          FilledButton.icon(
              onPressed: onPhotos,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Import photos')),
          FilledButton.tonalIcon(
              onPressed: onVideo,
              icon: const Icon(Icons.video_file_rounded),
              label: const Text('Import video')),
        ],
      ),
    );
  }
}

class _LibrarySidebar extends StatelessWidget {
  const _LibrarySidebar(
      {required this.card, required this.filter, required this.onFilter});
  final GalleryCard? card;
  final _MediaFilter filter;
  final ValueChanged<_MediaFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final media = card?.media ?? const <GalleryMediaItem>[];
    int count(_MediaFilter value) => switch (value) {
          _MediaFilter.all => media.length,
          _MediaFilter.photos =>
            media.where((item) => item.type == GalleryMediaType.photo).length,
          _MediaFilter.videos =>
            media.where((item) => item.type == GalleryMediaType.video).length,
          _MediaFilter.favorites =>
            media.where((item) => item.isFavorite).length,
          _MediaFilter.rated => media.where((item) => item.rating > 0).length,
          _MediaFilter.tagged =>
            media.where((item) => item.tags.isNotEmpty).length,
          _MediaFilter.unrated =>
            media.where((item) => item.rating == 0).length,
        };

    return Container(
      color: GalleryColors.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Text('LIBRARY',
                style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.6,
                    color: GalleryColors.muted,
                    fontWeight: FontWeight.w800)),
          ),
          ..._MediaFilter.values.map((value) => _SidebarTile(
                label: _filterLabel(value),
                icon: _filterIcon(value),
                count: count(value),
                selected: filter == value,
                onTap: () => onFilter(value),
              )),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GalleryColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: GalleryColors.purpleBright),
                SizedBox(height: 8),
                Text('Duplicate guard',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('SHA-256 matching is active during import.',
                    style: TextStyle(fontSize: 12, color: GalleryColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile(
      {required this.label,
      required this.icon,
      required this.count,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: GalleryColors.purpleDeep.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, size: 20),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          trailing: Text('$count',
              style: const TextStyle(color: GalleryColors.muted)),
          onTap: onTap,
        ),
      );
}

class _CompactFilters extends StatelessWidget {
  const _CompactFilters({required this.filter, required this.onFilter});
  final _MediaFilter filter;
  final ValueChanged<_MediaFilter> onFilter;

  @override
  Widget build(BuildContext context) => ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        children: _MediaFilter.values
            .map((value) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: filter == value,
                    avatar: Icon(_filterIcon(value), size: 17),
                    label: Text(_filterLabel(value)),
                    onSelected: (_) => onFilter(value),
                  ),
                ))
            .toList(),
      );
}

String _filterLabel(_MediaFilter value) => switch (value) {
      _MediaFilter.all => 'All media',
      _MediaFilter.photos => 'Photos',
      _MediaFilter.videos => 'Videos',
      _MediaFilter.favorites => 'Favorites',
      _MediaFilter.rated => 'Rated',
      _MediaFilter.tagged => 'Tagged',
      _MediaFilter.unrated => 'Unrated',
    };

IconData _filterIcon(_MediaFilter value) => switch (value) {
      _MediaFilter.all => Icons.photo_library_outlined,
      _MediaFilter.photos => Icons.photo_outlined,
      _MediaFilter.videos => Icons.videocam_outlined,
      _MediaFilter.favorites => Icons.favorite_border_rounded,
      _MediaFilter.rated => Icons.star_border_rounded,
      _MediaFilter.tagged => Icons.sell_outlined,
      _MediaFilter.unrated => Icons.star_outline_rounded,
    };

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.onFavorite,
    required this.onDelete,
    required this.onTag,
    required this.onRate,
    required this.onClear,
  });
  final int count;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTag;
  final ValueChanged<int> onRate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: GalleryColors.purpleDeep.withValues(alpha: 0.4),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded,
              color: GalleryColors.purpleBright),
          const SizedBox(width: 8),
          Text('$count selected',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          TextButton.icon(
              onPressed: onFavorite,
              icon: const Icon(Icons.favorite),
              label: const Text('Favorite')),
          TextButton.icon(
              onPressed: onTag,
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Tag')),
          PopupMenuButton<int>(
            tooltip: 'Rate selected',
            onSelected: onRate,
            itemBuilder: (_) => List.generate(
                6,
                (rating) => PopupMenuItem(
                    value: rating,
                    child: Text(rating == 0
                        ? 'Clear rating'
                        : '$rating star${rating == 1 ? '' : 's'}'))),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Icon(Icons.star_border_rounded),
                SizedBox(width: 6),
                Text('Rate')
              ]),
            ),
          ),
          TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove')),
          IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        ]),
      );
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.items,
    required this.selected,
    required this.coverPath,
    required this.tileWidth,
    required this.onTap,
    required this.onSelect,
    required this.onInspect,
    required this.onFavorite,
    required this.onEdit,
    required this.onCover,
  });
  final List<GalleryMediaItem> items;
  final Set<String> selected;
  final String? coverPath;
  final double tileWidth;
  final ValueChanged<int> onTap;
  final ValueChanged<GalleryMediaItem> onSelect;
  final ValueChanged<GalleryMediaItem> onInspect;
  final ValueChanged<GalleryMediaItem> onFavorite;
  final ValueChanged<GalleryMediaItem> onEdit;
  final ValueChanged<GalleryMediaItem> onCover;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: tileWidth,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .87,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _MediaTile(
            item: item,
            selected: selected.contains(item.id),
            isCover: coverPath == item.path,
            onTap: () {
              onInspect(item);
              onTap(index);
            },
            onSelect: () => onSelect(item),
            onInspect: () => onInspect(item),
            onFavorite: () => onFavorite(item),
            onEdit: () => onEdit(item),
            onCover: () => onCover(item),
          );
        },
      );
}

class _MediaList extends StatelessWidget {
  const _MediaList({
    required this.items,
    required this.selected,
    required this.coverPath,
    required this.onTap,
    required this.onSelect,
    required this.onInspect,
    required this.onFavorite,
    required this.onEdit,
    required this.onCover,
  });
  final List<GalleryMediaItem> items;
  final Set<String> selected;
  final String? coverPath;
  final ValueChanged<int> onTap;
  final ValueChanged<GalleryMediaItem> onSelect;
  final ValueChanged<GalleryMediaItem> onInspect;
  final ValueChanged<GalleryMediaItem> onFavorite;
  final ValueChanged<GalleryMediaItem> onEdit;
  final ValueChanged<GalleryMediaItem> onCover;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: SizedBox(
                  width: 78, height: 58, child: _MediaPreview(item: item)),
              title: Text(item.caption.isEmpty ? item.filename : item.caption,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${item.type.name.toUpperCase()} • ${item.dimensionsLabel} • ${item.sizeLabel}\n${item.tags.join(' • ')}',
                  maxLines: 2),
              isThreeLine: true,
              selected: selected.contains(item.id),
              onTap: () {
                onInspect(item);
                onTap(index);
              },
              onLongPress: () => onSelect(item),
              trailing: _ItemMenu(
                item: item,
                isCover: coverPath == item.path,
                onSelect: () => onSelect(item),
                onFavorite: () => onFavorite(item),
                onEdit: () => onEdit(item),
                onCover: () => onCover(item),
              ),
            ),
          );
        },
      );
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.selected,
    required this.isCover,
    required this.onTap,
    required this.onSelect,
    required this.onInspect,
    required this.onFavorite,
    required this.onEdit,
    required this.onCover,
  });
  final GalleryMediaItem item;
  final bool selected;
  final bool isCover;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final VoidCallback onInspect;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: selected
                  ? GalleryColors.purpleBright
                  : const Color(0x337D6C8E),
              width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onInspect,
          onDoubleTap: onTap,
          onLongPress: onSelect,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Stack(fit: StackFit.expand, children: [
              _MediaPreview(item: item),
              if (isCover)
                const Positioned(
                    left: 8,
                    top: 8,
                    child: Chip(
                        avatar: Icon(Icons.auto_awesome, size: 16),
                        label: Text('Cover'))),
              if (item.isFavorite)
                const Positioned(
                    left: 8,
                    bottom: 8,
                    child: CircleAvatar(
                        radius: 16, child: Icon(Icons.favorite, size: 17))),
              if (selected)
                const Center(
                    child: CircleAvatar(
                        radius: 24, child: Icon(Icons.check, size: 28))),
              Positioned(
                  right: 4,
                  top: 4,
                  child: _ItemMenu(
                      item: item,
                      isCover: isCover,
                      onSelect: onSelect,
                      onFavorite: onFavorite,
                      onEdit: onEdit,
                      onCover: onCover)),
            ])),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.caption.isEmpty ? item.filename : item.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(
                          item.type == GalleryMediaType.photo
                              ? Icons.photo_outlined
                              : Icons.videocam_outlined,
                          size: 16,
                          color: GalleryColors.muted),
                      const SizedBox(width: 5),
                      Expanded(
                          child: Text(
                              '${item.dimensionsLabel} • ${item.sizeLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: GalleryColors.muted, fontSize: 12))),
                      if (item.rating > 0)
                        Text('★${item.rating}',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w800)),
                    ]),
                  ]),
            ),
          ]),
        ),
      );
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel(
      {required this.item,
      required this.isCover,
      required this.onFavorite,
      required this.onEdit,
      required this.onCover});
  final GalleryMediaItem? item;
  final bool isCover;
  final VoidCallback? onFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onCover;

  @override
  Widget build(BuildContext context) {
    final media = item;
    return Container(
      color: GalleryColors.surface,
      padding: const EdgeInsets.all(16),
      child: media == null
          ? const Center(
              child: Text('Select an item to inspect its details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GalleryColors.muted)))
          : ListView(children: [
              AspectRatio(
                  aspectRatio: 1.2,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _MediaPreview(item: media))),
              const SizedBox(height: 16),
              Text(media.filename,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _PropertyRow(label: 'Type', value: media.type.name.toUpperCase()),
              _PropertyRow(label: 'Dimensions', value: media.dimensionsLabel),
              _PropertyRow(label: 'File size', value: media.sizeLabel),
              _PropertyRow(
                  label: 'Rating',
                  value: media.rating == 0 ? 'Unrated' : '${media.rating}/5'),
              _PropertyRow(
                  label: 'Favorite', value: media.isFavorite ? 'Yes' : 'No'),
              _PropertyRow(label: 'Cover', value: isCover ? 'Yes' : 'No'),
              if (media.importedAt != null)
                _PropertyRow(
                    label: 'Imported',
                    value: media.importedAt!
                        .toLocal()
                        .toString()
                        .split('.')
                        .first),
              const Divider(height: 26),
              const Text('Caption',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(media.caption.isEmpty ? 'No caption' : media.caption,
                  style: const TextStyle(color: GalleryColors.silver)),
              const SizedBox(height: 14),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              media.tags.isEmpty
                  ? const Text('No tags',
                      style: TextStyle(color: GalleryColors.muted))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: media.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList()),
              const SizedBox(height: 14),
              const Text('Collections',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              media.collections.isEmpty
                  ? const Text('No collections',
                      style: TextStyle(color: GalleryColors.muted))
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: media.collections
                          .map((name) => Chip(label: Text(name)))
                          .toList()),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit details')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: onFavorite,
                  icon: Icon(media.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border),
                  label:
                      Text(media.isFavorite ? 'Remove favorite' : 'Favorite')),
              if (media.type == GalleryMediaType.photo && !isCover) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                    onPressed: onCover,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Set as cover')),
              ],
            ]),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: GalleryColors.muted))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar(
      {required this.visible,
      required this.total,
      required this.selected,
      required this.tileWidth,
      required this.onTileWidth});
  final int visible;
  final int total;
  final int selected;
  final double tileWidth;
  final ValueChanged<double> onTileWidth;

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
            color: GalleryColors.surface,
            border: Border(top: BorderSide(color: Color(0x337D6C8E)))),
        child: Row(children: [
          Text(
              '$visible shown • $total total${selected > 0 ? ' • $selected selected' : ''}',
              style: const TextStyle(color: GalleryColors.muted, fontSize: 12)),
          const Spacer(),
          const Icon(Icons.photo_size_select_small_rounded,
              size: 17, color: GalleryColors.muted),
          SizedBox(
              width: 150,
              child: Slider(
                  min: 150,
                  max: 340,
                  value: tileWidth,
                  onChanged: onTileWidth)),
          const Icon(Icons.photo_size_select_large_rounded,
              size: 19, color: GalleryColors.muted),
        ]),
      );
}

class _RatingPicker extends StatelessWidget {
  const _RatingPicker({required this.rating, required this.onChanged});
  final int rating;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('Rating'),
        const Spacer(),
        ...List.generate(5, (index) {
          final value = index + 1;
          return IconButton(
            onPressed: () => onChanged(value == rating ? 0 : value),
            icon: Icon(
                value <= rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: Colors.amber),
          );
        }),
      ]);
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu(
      {required this.item,
      required this.isCover,
      required this.onSelect,
      required this.onFavorite,
      required this.onEdit,
      required this.onCover});
  final GalleryMediaItem item;
  final bool isCover;
  final VoidCallback onSelect;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'select') onSelect();
          if (value == 'favorite') onFavorite();
          if (value == 'edit') onEdit();
          if (value == 'cover') onCover();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'select', child: Text('Select')),
          PopupMenuItem(
              value: 'favorite',
              child: Text(item.isFavorite ? 'Remove favorite' : 'Favorite')),
          const PopupMenuItem(value: 'edit', child: Text('Edit details')),
          if (item.type == GalleryMediaType.photo && !isCover)
            const PopupMenuItem(value: 'cover', child: Text('Set as cover')),
        ],
      );
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.item});
  final GalleryMediaItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnail = item.thumbnailPath;
    final path = thumbnail != null && File(thumbnail).existsSync()
        ? thumbnail
        : item.path;
    if (item.type == GalleryMediaType.video) {
      return Container(
        color: GalleryColors.surfaceRaised,
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_fill_rounded, size: 54),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image_outlined, size: 42)),
    );
  }
}

class _EmptyMedia extends StatelessWidget {
  const _EmptyMedia({required this.onPhotos, required this.onVideo});
  final VoidCallback onPhotos;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined,
              size: 82, color: GalleryColors.purpleBright),
          const SizedBox(height: 14),
          const Text('Your Media Studio is waiting',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Import files or drag them into this window.',
              style: TextStyle(color: GalleryColors.muted)),
          const SizedBox(height: 18),
          Wrap(spacing: 10, children: [
            FilledButton.icon(
                onPressed: onPhotos,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Import photos')),
            FilledButton.tonalIcon(
                onPressed: onVideo,
                icon: const Icon(Icons.video_file),
                label: const Text('Import video')),
          ]),
        ]),
      );
}

class _NoPieces extends StatelessWidget {
  const _NoPieces();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Create a Gallery Piece in the Vault first, then return here to manage its media.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: GalleryColors.silver),
          ),
        ),
      );
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
