import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/gallery_card.dart';
import '../services/dashboard_service.dart';
import '../services/media_metadata_service.dart';
import '../widgets/creator_dashboard/creator_dashboard.dart';
import '../widgets/media/media_manager.dart';

class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({super.key, this.existing});

  final GalleryCard? existing;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _tags;
  late final TextEditingController _participants;
  late final TextEditingController _links;
  late final TextEditingController _notes;
  late final TextEditingController _thotPoints;
  late final TextEditingController _setName;
  late final TextEditingController _rarityCategory;
  late final TextEditingController _rarity;
  late final TextEditingController _photoCount;
  late final TextEditingController _videoCount;
  late final TextEditingController _locationCount;
  late final TextEditingController _peopleCount;
  late final TextEditingController _cardNumber;
  late final TextEditingController _setTotal;

  late GalleryCardType _type;
  late GalleryCardStatus _status;
  late GalleryCardTemplate _template;
  late GalleryImageFit _imageFit;
  late double _imageAlignmentX;
  late double _imageAlignmentY;
  late double _rating;
  String? _coverImagePath;
  late List<GalleryMediaItem> _media;
  bool _isImportingMedia = false;

  @override
  void initState() {
    super.initState();
    final card = widget.existing;
    _title = TextEditingController(text: card?.title ?? '');
    _description = TextEditingController(text: card?.description ?? '');
    _location = TextEditingController(text: card?.location ?? '');
    _tags = TextEditingController(text: card?.tags.join(', ') ?? '');
    _participants =
        TextEditingController(text: card?.participants.join(', ') ?? '');
    _links = TextEditingController(text: card?.links.join('\n') ?? '');
    _notes = TextEditingController(text: card?.notes ?? '');
    _thotPoints = TextEditingController(
      text: (card?.thotPoints ?? 100).toString(),
    );
    _setName = TextEditingController(
      text: card?.setName ?? 'Thot Gallery Originals',
    );
    _rarityCategory = TextEditingController(
      text: card?.rarityCategory ?? 'Standard',
    );
    _rarity = TextEditingController(
      text: card?.rarity ?? 'Original',
    );
    _photoCount = TextEditingController(
      text: (card?.photoCount ?? 0).toString(),
    );
    _videoCount = TextEditingController(
      text: (card?.videoCount ?? 0).toString(),
    );
    _locationCount = TextEditingController(
      text: (card?.locationCount ?? 0).toString(),
    );
    _peopleCount = TextEditingController(
      text: (card?.peopleCount ?? 0).toString(),
    );
    _cardNumber = TextEditingController(
      text: (card?.cardNumber ?? 1).toString(),
    );
    _setTotal = TextEditingController(
      text: (card?.setTotal ?? 1).toString(),
    );
    _type = card?.type ?? GalleryCardType.thot;
    _status = card?.status ?? GalleryCardStatus.idea;
    _template = card?.template ?? GalleryCardTemplate.neonBattle;
    _imageFit = card?.imageFit ?? GalleryImageFit.cover;
    _imageAlignmentX = card?.imageAlignmentX ?? 0;
    _imageAlignmentY = card?.imageAlignmentY ?? 0;
    _rating = card?.rating ?? 0;
    _coverImagePath = card?.coverImagePath;
    _media = List<GalleryMediaItem>.from(card?.media ?? const []);
    _title.addListener(_refreshDashboard);
  }

  @override
  void dispose() {
    _title.removeListener(_refreshDashboard);
    for (final controller in [
      _title,
      _description,
      _location,
      _tags,
      _participants,
      _links,
      _notes,
      _thotPoints,
      _setName,
      _rarityCategory,
      _rarity,
      _photoCount,
      _videoCount,
      _locationCount,
      _peopleCount,
      _cardNumber,
      _setTotal,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _commaList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  List<String> _lineList(String value) => value
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _refreshDashboard() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickCover() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image != null) {
      setState(() {
        _coverImagePath = image.path;
        _imageAlignmentX = 0;
        _imageAlignmentY = 0;
      });
    }
  }

  Future<void> _addPhotos() async {
    if (_isImportingMedia) return;

    final images = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (images.isEmpty || !mounted) return;

    setState(() => _isImportingMedia = true);

    try {
      final importedItems = <GalleryMediaItem>[];

      for (final image in images) {
        importedItems.add(
          await MediaMetadataService.createPhoto(image.path),
        );
      }

      if (!mounted) return;

      setState(() {
        _media.addAll(importedItems);
        _coverImagePath ??= images.first.path;
      });

      _showImportMessage(
        importedItems.length == 1
            ? 'Photo imported with metadata.'
            : '${importedItems.length} photos imported with metadata.',
      );
    } catch (error) {
      if (mounted) {
        _showImportMessage('Could not import the selected photos: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingMedia = false);
      }
    }
  }

  Future<void> _addVideo() async {
    if (_isImportingMedia) return;

    final video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (video == null || !mounted) return;

    setState(() => _isImportingMedia = true);

    try {
      final importedVideo = await MediaMetadataService.createVideo(video.path);
      if (!mounted) return;

      setState(() {
        _media.add(importedVideo);
      });

      _showImportMessage('Video imported with metadata.');
    } catch (error) {
      if (mounted) {
        _showImportMessage('Could not import the selected video: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingMedia = false);
      }
    }
  }

  void _showImportMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;

    Navigator.of(context).pop(
      GalleryCard(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        type: _type,
        status: _status,
        template: _template,
        description: _description.text.trim(),
        coverImagePath: _coverImagePath,
        media: List<GalleryMediaItem>.from(_media),
        imageFit: _imageFit,
        imageAlignmentX: _imageAlignmentX,
        imageAlignmentY: _imageAlignmentY,
        thotPoints: int.tryParse(_thotPoints.text.trim()) ?? 100,
        setName: _setName.text.trim(),
        rarityCategory: _rarityCategory.text.trim(),
        rarity: _rarity.text.trim(),
        fingerprint: existing?.fingerprint ?? '',
        views: existing?.views ?? 0,
        shareCount: existing?.shareCount ?? 0,
        photoCount:
            _media.where((item) => item.type == GalleryMediaType.photo).length,
        videoCount:
            _media.where((item) => item.type == GalleryMediaType.video).length,
        locationCount: int.tryParse(_locationCount.text.trim()) ?? 0,
        peopleCount: int.tryParse(_peopleCount.text.trim()) ?? 0,
        cardNumber: int.tryParse(_cardNumber.text.trim()) ?? 1,
        setTotal: int.tryParse(_setTotal.text.trim()) ?? 1,
        nfcEnabled: existing?.nfcEnabled ?? true,
        isRevealed: existing?.isRevealed ?? false,
        location: _location.text.trim(),
        date: existing?.date ?? DateTime.now(),
        rating: _rating,
        tags: _commaList(_tags.text),
        participants: _commaList(_participants.text),
        links: _lineList(_links.text),
        notes: _notes.text.trim(),
        isFavorite: existing?.isFavorite ?? false,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        lastSharedAt: existing?.lastSharedAt,
      ),
    );
  }

  BoxFit get _previewFit => switch (_imageFit) {
        GalleryImageFit.cover => BoxFit.cover,
        GalleryImageFit.contain => BoxFit.contain,
        GalleryImageFit.fill => BoxFit.fill,
      };

  @override
  Widget build(BuildContext context) {
    final hasCover =
        _coverImagePath != null && File(_coverImagePath!).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Create Card' : 'Edit Card'),
        actions: [
          if (_isImportingMedia)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: _isImportingMedia ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CreatorDashboard(
              data: DashboardService.calculate(
                title: _title.text,
                coverImagePath: _coverImagePath,
                media: _media,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: _pickCover,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _coverImagePath == null
                    ? 'Choose Cover Image'
                    : 'Replace Cover Image',
              ),
            ),
            const SizedBox(height: 10),
            MediaManager(
              media: _media,
              coverImagePath: _coverImagePath,
              onMediaChanged: (updatedMedia) {
                setState(() {
                  _media = List<GalleryMediaItem>.from(updatedMedia);
                });
              },
              onCoverChanged: (path) {
                setState(() {
                  _coverImagePath = path;
                  _imageAlignmentX = 0;
                  _imageAlignmentY = 0;
                });
              },
              onAddPhotos: _isImportingMedia ? () {} : _addPhotos,
              onAddVideo: _isImportingMedia ? () {} : _addVideo,
            ),
            const SizedBox(height: 16),
            if (hasCover) ...[
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 1.42,
                child: Container(
                  color: Colors.black,
                  child: Image.file(
                    File(_coverImagePath!),
                    fit: _previewFit,
                    alignment: Alignment(_imageAlignmentX, _imageAlignmentY),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GalleryImageFit>(
                initialValue: _imageFit,
                decoration: const InputDecoration(
                  labelText: 'Photo fit',
                  helperText:
                      'Cover fills the frame. Contain shows the whole photo.',
                ),
                items: GalleryImageFit.values
                    .map((fit) => DropdownMenuItem(
                          value: fit,
                          child: Text(fit.name),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _imageFit = value!),
              ),
              const SizedBox(height: 10),
              Text('Move left/right: ${_imageAlignmentX.toStringAsFixed(2)}'),
              Slider(
                min: -1,
                max: 1,
                divisions: 40,
                value: _imageAlignmentX,
                onChanged: (value) => setState(() => _imageAlignmentX = value),
              ),
              Text('Move up/down: ${_imageAlignmentY.toStringAsFixed(2)}'),
              Slider(
                min: -1,
                max: 1,
                divisions: 40,
                value: _imageAlignmentY,
                onChanged: (value) => setState(() => _imageAlignmentY = value),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Card title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Give the card a title.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thotPoints,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Thot Points 👅',
                helperText: 'Displayed at the top-right of the card.',
              ),
              validator: (value) {
                final points = int.tryParse(value ?? '');
                if (points == null || points < 0 || points > 9999) {
                  return 'Use a number from 0 to 9999.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _setName,
              decoration: const InputDecoration(
                labelText: 'Custom set',
                hintText: 'Midnight Adventures',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rarityCategory,
              decoration: const InputDecoration(
                labelText: 'Rarity category',
                hintText: 'Standard, Premium, Event Exclusive',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rarity,
              decoration: const InputDecoration(
                labelText: 'Custom rarity',
                hintText: 'Rare, Certified, One of One',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationCount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Locations'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _peopleCount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'People'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Card number'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _setTotal,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Set total'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Story or summary'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GalleryCardType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Card type'),
              items: GalleryCardType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GalleryCardTemplate>(
              initialValue: _template,
              decoration: const InputDecoration(labelText: 'Card template'),
              items: GalleryCardTemplate.values
                  .map(
                    (template) => DropdownMenuItem(
                      value: template,
                      child: Text(template.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _template = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GalleryCardStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: GalleryCardStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            Text('Rating: ${_rating.toStringAsFixed(1)}'),
            Slider(
              value: _rating,
              min: 0,
              max: 5,
              divisions: 10,
              label: _rating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _rating = value),
            ),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Food, Date Night, Adventure',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _participants,
              decoration: const InputDecoration(
                labelText: 'Participants',
                hintText: 'Separate names with commas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _links,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Links',
                hintText: 'One URL per line',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Private notes or favorite moments',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Save Gallery Card'),
            ),
          ],
        ),
      ),
    );
  }
}
