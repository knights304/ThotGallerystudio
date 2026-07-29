import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gallery_card.dart';
import '../services/gallery_store.dart';
import '../theme/gallery_theme.dart';
import '../widgets/collectible_card.dart';

class PieceWizardScreen extends StatefulWidget {
  const PieceWizardScreen({super.key, required this.store});

  final GalleryStore store;

  @override
  State<PieceWizardScreen> createState() => _PieceWizardScreenState();
}

class _PieceWizardScreenState extends State<PieceWizardScreen> {
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _tags = TextEditingController();
  final _collections = TextEditingController();
  final _notes = TextEditingController();
  final _thotPoints = TextEditingController(text: '100');
  final _setName = TextEditingController(text: 'Thot Gallery Originals');

  int _step = 0;
  String? _coverPath;
  final List<GalleryMediaItem> _media = [];
  GalleryCardTemplate _template = GalleryCardTemplate.neonBattle;
  String _rarity = 'Original';
  bool _favorite = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _location,
      _tags,
      _collections,
      _notes,
      _thotPoints,
      _setName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  String _templateName(GalleryCardTemplate template) => switch (template) {
        GalleryCardTemplate.royalPurple => 'Royal Purple',
        GalleryCardTemplate.blackChrome => 'Black Chrome',
        GalleryCardTemplate.silverNeon => 'Silver Neon',
        GalleryCardTemplate.neonBattle => 'Neon Battle',
      };

  IconData _templateIcon(GalleryCardTemplate template) => switch (template) {
        GalleryCardTemplate.royalPurple => Icons.workspace_premium_rounded,
        GalleryCardTemplate.blackChrome => Icons.dark_mode_rounded,
        GalleryCardTemplate.silverNeon => Icons.bolt_rounded,
        GalleryCardTemplate.neonBattle => Icons.auto_awesome_rounded,
      };

  Future<void> _pickCover() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (image != null) {
      setState(() => _coverPath = image.path);
    }
  }

  Future<void> _addPhotos() async {
    final images = await _picker.pickMultiImage(imageQuality: 92);
    if (images.isEmpty) {
      return;
    }

    setState(() {
      for (final image in images) {
        _media.add(
          GalleryMediaItem(
            id: '${DateTime.now().microsecondsSinceEpoch}-${_media.length}',
            path: image.path,
            type: GalleryMediaType.photo,
            sortOrder: _media.length,
          ),
        );
      }
      _coverPath ??= images.first.path;
    });
  }

  Future<void> _addVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null) {
      return;
    }

    setState(() {
      _media.add(
        GalleryMediaItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          path: video.path,
          type: GalleryMediaType.video,
          sortOrder: _media.length,
        ),
      );
    });
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = _media.removeAt(oldIndex);
      _media.insert(newIndex, item);

      for (var index = 0; index < _media.length; index++) {
        _media[index].sortOrder = index;
      }
    });
  }

  Future<void> _editMedia(GalleryMediaItem item) async {
    final caption = TextEditingController(text: item.caption);
    var favorite = item.isFavorite;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.type == GalleryMediaType.photo
                    ? 'Photo details'
                    : 'Video details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: caption,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  hintText: 'Add a memory, title, or behind-the-scenes note.',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: favorite,
                onChanged: (value) {
                  setSheetState(() => favorite = value);
                },
                title: const Text('Highlight this media'),
                subtitle: const Text(
                  'Highlighted media can be surfaced first later.',
                ),
              ),
              if (item.type == GalleryMediaType.photo)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wallpaper_rounded),
                  title: const Text('Use as cover'),
                  onTap: () => Navigator.pop(context, 'cover'),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text('Remove from piece'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: const Text('Save media details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) {
      caption.dispose();
      return;
    }

    setState(() {
      if (action == 'delete') {
        _media.removeWhere((value) => value.id == item.id);

        if (_coverPath == item.path) {
          _coverPath = _media
              .where((mediaItem) => mediaItem.type == GalleryMediaType.photo)
              .firstOrNull
              ?.path;
        }
      } else {
        item.caption = caption.text.trim();
        item.isFavorite = favorite;

        if (action == 'cover') {
          _coverPath = item.path;
        }
      }

      for (var index = 0; index < _media.length; index++) {
        _media[index].sortOrder = index;
      }
    });

    caption.dispose();
  }

  GalleryCard _buildCard({required GalleryCardStatus status}) {
    final now = DateTime.now();

    return GalleryCard(
      id: widget.store.nextCardId(),
      title: _title.text.trim().isEmpty
          ? 'Untitled Gallery Piece'
          : _title.text.trim(),
      type: GalleryCardType.thot,
      status: status,
      template: _template,
      description: _description.text.trim(),
      coverImagePath: _coverPath,
      media: List.of(_media),
      thotPoints: int.tryParse(_thotPoints.text) ?? 100,
      setName: _setName.text.trim().isEmpty
          ? 'Thot Gallery Originals'
          : _setName.text.trim(),
      rarityCategory: _rarity == 'Original' ? 'Standard' : 'Premium',
      rarity: _rarity,
      location: _location.text.trim(),
      tags: _split(_tags.text),
      collections: _split(_collections.text),
      notes: _notes.text.trim(),
      isFavorite: _favorite,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _save(GalleryCardStatus status) async {
    if (_saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final card = _buildCard(status: status);
      await widget.store.upsertCard(card);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(card);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Gallery Piece'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => _save(GalleryCardStatus.idea),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Save Draft'),
          ),
        ],
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: () {
          if (_step < 3) {
            setState(() => _step++);
          } else {
            _save(GalleryCardStatus.completed);
          }
        },
        onStepCancel: _step == 0 ? null : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : details.onStepContinue,
                icon: Icon(
                  _step == 3 ? Icons.auto_awesome : Icons.arrow_forward,
                ),
                label: Text(_step == 3 ? 'Create Piece' : 'Continue'),
              ),
              if (_step > 0) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Cover & Media'),
            subtitle: const Text(
              'Choose, caption, and reorder the visual story.',
            ),
            isActive: _step >= 0,
            content: _mediaStep(),
          ),
          Step(
            title: const Text('Story'),
            subtitle: const Text('Name it, describe it, organize it.'),
            isActive: _step >= 1,
            content: _storyStep(),
          ),
          Step(
            title: const Text('Card Style'),
            subtitle: const Text('Pick a template with a live preview.'),
            isActive: _step >= 2,
            content: _styleStep(),
          ),
          Step(
            title: const Text('Preview'),
            subtitle: const Text(
              'One last look before it enters the vault.',
            ),
            isActive: _step >= 3,
            content: _previewStep(),
          ),
        ],
      ),
    );
  }

  Widget _mediaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickCover,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: GalleryColors.purpleBright.withValues(alpha: .55),
              ),
              color: GalleryColors.panel,
              image: _coverPath == null
                  ? null
                  : DecorationImage(
                      image: FileImage(File(_coverPath!)),
                      fit: BoxFit.cover,
                    ),
            ),
            child: _coverPath == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 46),
                        SizedBox(height: 8),
                        Text('Tap to choose a cover'),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'COVER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _addPhotos,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Add Photos'),
            ),
            OutlinedButton.icon(
              onPressed: _addVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Add Video'),
            ),
          ],
        ),
        if (_media.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: GalleryColors.muted,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hold and drag to reorder. Tap an item for caption, highlight, cover, or delete.',
                  style: TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _media.length,
              onReorder: _reorderMedia,
              itemBuilder: (context, index) {
                final item = _media[index];
                final isCover = item.path == _coverPath;

                return ReorderableDragStartListener(
                  key: ValueKey(item.id),
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: InkWell(
                      onTap: () => _editMedia(item),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 96,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  color: GalleryColors.panel,
                                  child: item.type == GalleryMediaType.photo
                                      ? Image.file(
                                          File(item.path),
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.play_circle_fill_rounded,
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (isCover)
                              const Positioned(
                                left: 5,
                                top: 5,
                                child: _MediaBadge(
                                  icon: Icons.wallpaper_rounded,
                                  label: 'Cover',
                                ),
                              ),
                            if (item.isFavorite)
                              const Positioned(
                                right: 5,
                                top: 5,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    Icons.favorite,
                                    size: 13,
                                    color: Colors.pinkAccent,
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 5,
                              right: 5,
                              bottom: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .72),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.drag_indicator,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        item.caption.isEmpty
                                            ? '#${index + 1}'
                                            : item.caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _storyStep() {
    return Column(
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'Location'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tags,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'nightlife, cosplay, behind the scenes',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _collections,
          decoration: const InputDecoration(
            labelText: 'Collections',
            hintText: 'VIP, Summer 2026',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Private notes'),
        ),
      ],
    );
  }

  Widget _styleStep() {
    final previewCard = _buildCard(status: GalleryCardStatus.completed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a card template',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: GalleryCardTemplate.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final template = GalleryCardTemplate.values[index];
              final selected = template == _template;

              return InkWell(
                onTap: () => setState(() => _template = template),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 142,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? GalleryColors.purpleDeep
                        : GalleryColors.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? GalleryColors.purpleBright
                          : GalleryColors.silver.withValues(alpha: .22),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _templateIcon(template),
                        color: selected ? Colors.white : GalleryColors.silver,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _templateName(template),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: CollectibleCard(
              card: previewCard,
              compact: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _rarity,
          decoration: const InputDecoration(labelText: 'Rarity'),
          items: const ['Original', 'Rare', 'Epic', 'Legendary']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() => _rarity = value ?? _rarity);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _thotPoints,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Thot Points 👅'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _setName,
          decoration: const InputDecoration(labelText: 'Set name'),
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _favorite,
          onChanged: (value) => setState(() => _favorite = value),
          title: const Text('Add to Favorites'),
          subtitle: const Text(
            'Pin this piece near the front of your binder.',
          ),
        ),
      ],
    );
  }

  Widget _previewStep() {
    final card = _buildCard(status: GalleryCardStatus.completed);

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: CollectibleCard(card: card),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Chip(
              label: Text(
                '${_media.where((item) => item.type == GalleryMediaType.photo).length} photos',
              ),
            ),
            Chip(
              label: Text(
                '${_media.where((item) => item.type == GalleryMediaType.video).length} videos',
              ),
            ),
            Chip(
              label: Text(
                '${_media.where((item) => item.isFavorite).length} highlights',
              ),
            ),
            Chip(label: Text(_rarity)),
            Chip(
              label: Text(
                '${int.tryParse(_thotPoints.text) ?? 100} TP 👅',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MediaBadge extends StatelessWidget {
  const _MediaBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
