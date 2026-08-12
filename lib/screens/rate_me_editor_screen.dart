import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../models/rate_me_card.dart';
import '../services/rate_me_package_service.dart';
import '../services/studio_cloud_service.dart';
import '../services/rate_me_response_service.dart';
import '../services/rate_me_store.dart';
import 'rate_me_responses_screen.dart';
import 'studio_rate_me_recipient_picker_screen.dart';

class StudioRateMeEditorScreen extends StatefulWidget {
  const StudioRateMeEditorScreen({
    super.key,
    this.initialCard,
    this.defaultOwnerId = 'studio',
    this.defaultOwnerName = 'THOT Gallery Studio',
  });

  final StudioRateMeCard? initialCard;
  final String defaultOwnerId;
  final String defaultOwnerName;

  @override
  State<StudioRateMeEditorScreen> createState() =>
      _StudioRateMeEditorScreenState();
}

class _StudioRateMeEditorScreenState extends State<StudioRateMeEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late StudioRateMeCard _card;

  bool _busy = false;
  int _responseCount = 0;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialCard;
    final now = DateTime.now();

    _card = initial ??
        StudioRateMeCard(
          id: 'rate_${now.toUtc().microsecondsSinceEpoch}',
          title: 'Rate Me',
          description: '',
          owner: StudioRateMeOwner(
            type: 'studio',
            id: widget.defaultOwnerId,
            displayName: widget.defaultOwnerName,
          ),
          createdAt: now,
          updatedAt: now,
        );

    _titleController.text = _card.title;
    _descriptionController.text = _card.description;
    _ownerNameController.text = _card.owner.displayName;

    _loadResponseCount();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  StudioRateMeCard _draft() {
    return _card.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Rate Me'
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      owner: StudioRateMeOwner(
        type: 'studio',
        id: _card.owner.id.trim().isEmpty
            ? widget.defaultOwnerId
            : _card.owner.id,
        displayName: _ownerNameController.text.trim().isEmpty
            ? widget.defaultOwnerName
            : _ownerNameController.text.trim(),
      ),
      responseTarget: const StudioRateMeResponseTarget(
        mode: 'file',
      ),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadResponseCount() async {
    final count = await StudioRateMeResponseService.countForCard(
      _card.id,
    );

    if (!mounted) return;

    setState(() => _responseCount = count);
  }

  Future<void> _save() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final saved = await StudioRateMeStore.saveCard(
        _draft(),
      );

      if (!mounted) return;

      setState(() => _card = saved);
      _message('Rate Me card saved.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickCover() async {
    if (_busy) return;

    final image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() => _busy = true);

    try {
      final path = await StudioRateMeStore.importCover(
        cardId: _card.id,
        sourcePath: image.path,
      );

      final saved = await StudioRateMeStore.saveCard(
        _draft().copyWith(
          coverImagePath: path,
        ),
      );

      if (!mounted) return;

      setState(() => _card = saved);
    } catch (error) {
      if (!mounted) return;
      _message('Could not add cover: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    await _importMedia(
      image.path,
      StudioRateMeMediaType.photo,
    );
  }

  Future<void> _addVideo() async {
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    await _importMedia(
      video.path,
      StudioRateMeMediaType.video,
    );
  }

  Future<void> _importMedia(
    String path,
    StudioRateMeMediaType type,
  ) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final media = await StudioRateMeStore.importMedia(
        cardId: _card.id,
        sourcePath: path,
        type: type,
      );

      final saved = await StudioRateMeStore.saveCard(
        _draft().copyWith(
          media: [..._card.media, media],
        ),
      );

      if (!mounted) return;

      setState(() => _card = saved);
    } catch (error) {
      if (!mounted) return;
      _message('Could not add media: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _updateMedia(
    StudioRateMeMedia updated,
  ) async {
    final media = _card.media
        .map((item) => item.id == updated.id ? updated : item)
        .toList();

    final saved = await StudioRateMeStore.saveCard(
      _draft().copyWith(media: media),
    );

    if (!mounted) return;

    setState(() => _card = saved);
  }

  Future<void> _moveMedia(
    int oldIndex,
    int newIndex,
  ) async {
    final media = List<StudioRateMeMedia>.from(
      _card.media,
    );

    final item = media.removeAt(oldIndex);
    media.insert(newIndex, item);

    final saved = await StudioRateMeStore.saveCard(
      _draft().copyWith(media: media),
    );

    if (!mounted) return;

    setState(() => _card = saved);
  }

  Future<void> _deleteMedia(
    StudioRateMeMedia media,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Media?'),
        content: const Text(
          'This removes the photo or video from the Rate Me card.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              false,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              true,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await StudioRateMeStore.deleteMedia(media);

    final saved = await StudioRateMeStore.saveCard(
      _draft().copyWith(
        media: _card.media.where((item) => item.id != media.id).toList(),
      ),
    );

    if (!mounted) return;

    setState(() => _card = saved);
  }

  Future<String?> _chooseCardDestination() {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            4,
            16,
            18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Send Rate Me Card',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how you want to send this Rate Me card.',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(
                  Icons.people_alt_outlined,
                ),
                title: const Text(
                  'Send to Viewer',
                ),
                subtitle: const Text(
                  'Search for a THOT Gallery Viewer account.',
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  'viewer',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.business_rounded,
                ),
                title: const Text(
                  'Send to Studio',
                ),
                subtitle: const Text(
                  'Search for another THOT Gallery Studio account.',
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  'studio',
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                ),
                title: const Text(
                  'Share through device',
                ),
                subtitle: const Text(
                  'Send the .tgrate file using Android sharing.',
                ),
                onTap: () => Navigator.pop(
                  sheetContext,
                  'normal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportAndShare() async {
    if (_busy) return;

    if (_card.media.isEmpty) {
      _message(
        'Add at least one photo or video first.',
      );
      return;
    }

    final destination = await _chooseCardDestination();

    if (destination == null || !mounted) {
      return;
    }

    StudioCloudProfile? recipient;

    if (destination == 'viewer' || destination == 'studio') {
      recipient = await Navigator.of(context).push<StudioCloudProfile>(
        MaterialPageRoute(
          builder: (_) => StudioRateMeRecipientPickerScreen(
            profileType: destination,
          ),
        ),
      );

      if (recipient == null || !mounted) {
        return;
      }
    }

    setState(() => _busy = true);

    try {
      final saved = await StudioRateMeStore.saveCard(
        _draft(),
      );

      if (!mounted) return;

      setState(() => _card = saved);

      final exported = await StudioRateMePackageService.exportCard(
        saved,
      );

      if (destination == 'normal') {
        final filename = exported.file.uri.pathSegments.last;

        final result = await SharePlus.instance.share(
          ShareParams(
            title: 'Share ${saved.title}',
            subject: '${saved.title} · THOT Gallery Rate Me',
            text:
                'Open this Rate Me card in THOT Gallery and tell me what you think.',
            files: [
              XFile(
                exported.file.path,
                mimeType: 'application/zip',
                name: filename,
              ),
            ],
            fileNameOverrides: [
              filename,
            ],
          ),
        );

        if (!mounted) return;

        if (result.status == ShareResultStatus.success) {
          _message(
            'Rate Me card shared.',
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          _message(
            'Share canceled.',
          );
        }

        return;
      }

      final upload = await StudioCloudService.instance.uploadRateMePackage(
        cardId: saved.id,
        file: exported.file,
      );

      await StudioCloudService.instance.sendRateMe(
        recipientProfileId: recipient!.id,
        cardId: saved.id,
        packageKey: upload.packageKey,
      );

      if (!mounted) return;

      _message(
        'Rate Me sent directly to '
        '${recipient.displayName}.',
      );
    } on StudioCloudException catch (error) {
      if (!mounted) return;

      _message(
        'Could not send Rate Me: '
        '${error.message}',
      );
    } catch (error) {
      if (!mounted) return;

      _message(
        'Could not send Rate Me card: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openResponses() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudioRateMeResponsesScreen(
          card: _draft(),
        ),
      ),
    );

    if (!mounted) return;
    await _loadResponseCount();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = _card.coverImagePath;
    final hasCover =
        cover != null && cover.isNotEmpty && File(cover).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Me Studio'),
        actions: [
          IconButton(
            tooltip: 'Responses',
            onPressed: _openResponses,
            icon: Badge(
              isLabelVisible: _responseCount > 0,
              label: Text('$_responseCount'),
              child: const Icon(
                Icons.mark_unread_chat_alt_outlined,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Export and share',
            onPressed: _busy ? null : _exportAndShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          48,
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: hasCover
                      ? Image.file(
                          File(cover),
                          fit: BoxFit.cover,
                        )
                      : const _CoverFallback(),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleController.text.trim().isEmpty
                            ? 'Rate Me'
                            : _titleController.text.trim(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_descriptionController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _descriptionController.text.trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            icon: Icons.collections_outlined,
                            label: '${_card.media.length} media',
                          ),
                          _Pill(
                            icon: Icons.forum_outlined,
                            label:
                                '$_responseCount response${_responseCount == 1 ? '' : 's'}',
                          ),
                          const _Pill(
                            icon: Icons.folder_zip_outlined,
                            label: '.tgrate',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Card title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 6,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Description / intro',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ownerNameController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Owner / creator display name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickCover,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  hasCover ? 'Change Cover' : 'Add Cover',
                ),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Card'),
              ),
              FilledButton.tonalIcon(
                onPressed: _openResponses,
                icon: const Icon(Icons.forum_outlined),
                label: Text(
                  _responseCount == 0
                      ? 'Responses'
                      : 'Responses ($_responseCount)',
                ),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _exportAndShare,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Export .tgrate'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Text(
                'Media',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Add media',
                onSelected: (value) {
                  if (value == 'photo') {
                    _addPhoto();
                  } else if (value == 'video') {
                    _addVideo();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'photo',
                    child: ListTile(
                      leading: Icon(
                        Icons.add_photo_alternate_outlined,
                      ),
                      title: Text('Add Photo'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'video',
                    child: ListTile(
                      leading: Icon(
                        Icons.video_library_outlined,
                      ),
                      title: Text('Add Video'),
                    ),
                  ),
                ],
                child: const Chip(
                  avatar: Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Media'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_card.media.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(
                      Icons.collections_outlined,
                      size: 54,
                      color: Color(0xFFA78BFA),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Add multiple photos and videos, then ask viewers to rate each one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _card.media.length,
              onReorderItem: _moveMedia,
              itemBuilder: (context, index) {
                final media = _card.media[index];

                return Padding(
                  key: ValueKey(media.id),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _StudioMediaEditor(
                    index: index,
                    media: media,
                    onChanged: _updateMedia,
                    onDelete: () => _deleteMedia(media),
                  ),
                );
              },
            ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _StudioMediaEditor extends StatefulWidget {
  const _StudioMediaEditor({
    required this.index,
    required this.media,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final StudioRateMeMedia media;
  final ValueChanged<StudioRateMeMedia> onChanged;
  final VoidCallback onDelete;

  @override
  State<_StudioMediaEditor> createState() => _StudioMediaEditorState();
}

class _StudioMediaEditorState extends State<_StudioMediaEditor> {
  final _captionController = TextEditingController();
  final _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(
    covariant _StudioMediaEditor oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.media.id != widget.media.id ||
        oldWidget.media.caption != widget.media.caption ||
        oldWidget.media.question != widget.media.question) {
      _sync();
    }
  }

  void _sync() {
    _captionController.text = widget.media.caption;
    _questionController.text = widget.media.question;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _save() {
    widget.onChanged(
      widget.media.copyWith(
        caption: _captionController.text.trim(),
        question: _questionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final exists = File(media.path).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!exists)
            const AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(
                child: Text('Media unavailable'),
              ),
            )
          else if (media.type == StudioRateMeMediaType.photo)
            Image.file(
              File(media.path),
              fit: BoxFit.cover,
            )
          else
            _LocalVideo(path: media.path),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: const Icon(
                        Icons.drag_handle_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${media.type.name.toUpperCase()} ${widget.index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Remove media',
                      onPressed: widget.onDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _captionController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _questionController,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Question for viewers',
                    hintText: 'Example: How would you rate this look?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Media Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalVideo extends StatefulWidget {
  const _LocalVideo({
    required this.path,
  });

  final String path;

  @override
  State<_LocalVideo> createState() => _LocalVideoState();
}

class _LocalVideoState extends State<_LocalVideo> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.file(
      File(widget.path),
    );
    _controller = controller;

    try {
      await controller.initialize();

      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          child: VideoPlayer(controller),
        ),
        Row(
          children: [
            IconButton(
              tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
              onPressed: () async {
                if (controller.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }

                if (mounted) {
                  setState(() {});
                }
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
              ),
            ),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: const Color(0xFFA78BFA),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF21192D),
      child: Center(
        child: Icon(
          Icons.rate_review_rounded,
          size: 78,
          color: Color(0xFFFFC857),
        ),
      ),
    );
  }
}
