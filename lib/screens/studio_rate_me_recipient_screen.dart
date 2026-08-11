import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../models/rate_me_card.dart';
import '../models/rate_me_response.dart';
import '../services/studio_cloud_service.dart';
import '../services/studio_rate_me_response_share_service.dart';
import '../widgets/eggplant_rating.dart';

class StudioRateMeRecipientScreen extends StatefulWidget {
  const StudioRateMeRecipientScreen({
    super.key,
    required this.card,
    required this.delivery,
  });

  final StudioRateMeCard card;
  final StudioCloudDelivery delivery;

  @override
  State<StudioRateMeRecipientScreen> createState() =>
      _StudioRateMeRecipientScreenState();
}

class _StudioRateMeRecipientScreenState
    extends State<StudioRateMeRecipientScreen> {
  final TextEditingController _commentController = TextEditingController();

  final Set<String> _favoriteMediaIds = <String>{};

  final ImagePicker _picker = ImagePicker();

  final AudioRecorder _recorder = AudioRecorder();

  final AudioPlayer _audioPlayer = AudioPlayer();

  double _rating = 0.0;

  bool _busy = false;
  bool _submitted = false;
  bool _recording = false;
  bool _playingVoice = false;

  String? _photoReplyPath;
  String? _videoReplyPath;
  String? _voiceReplyPath;

  @override
  void initState() {
    super.initState();

    _submitted = widget.delivery.status == 'responded';

    _audioPlayer.onPlayerComplete.listen(
      (_) {
        if (mounted) {
          setState(
            () => _playingVoice = false,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();

    _recorder.dispose();
    _audioPlayer.dispose();

    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_busy || _submitted) {
      return;
    }

    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );

    if (result == null || !mounted) {
      return;
    }

    setState(
      () => _photoReplyPath = result.path,
    );
  }

  Future<void> _pickVideo() async {
    if (_busy || _submitted) {
      return;
    }

    final result = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(
      () => _videoReplyPath = result.path,
    );
  }

  Future<void> _recordVideo() async {
    if (_busy || _submitted) {
      return;
    }

    final result = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(
      () => _videoReplyPath = result.path,
    );
  }

  Future<void> _toggleVoiceRecording() async {
    if (_busy || _submitted) {
      return;
    }

    if (_recording) {
      final result = await _recorder.stop();

      if (!mounted) return;

      setState(() {
        _recording = false;

        if (result != null && result.trim().isNotEmpty) {
          _voiceReplyPath = result;
        }
      });

      return;
    }

    final allowed = await _recorder.hasPermission();

    if (!allowed) {
      _message(
        'Microphone permission is required to record a voice response.',
      );
      return;
    }

    final temporary = await getTemporaryDirectory();

    final path = p.join(
      temporary.path,
      'rate_me_voice_'
      '${DateTime.now().microsecondsSinceEpoch}'
      '.m4a',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    if (!mounted) return;

    setState(
      () => _recording = true,
    );
  }

  Future<void> _toggleVoicePlayback() async {
    final path = _voiceReplyPath;

    if (path == null || !File(path).existsSync()) {
      return;
    }

    if (_playingVoice) {
      await _audioPlayer.stop();

      if (mounted) {
        setState(
          () => _playingVoice = false,
        );
      }

      return;
    }

    await _audioPlayer.play(
      DeviceFileSource(path),
    );

    if (mounted) {
      setState(
        () => _playingVoice = true,
      );
    }
  }

  void _toggleFavorite(
    String mediaId,
  ) {
    if (_submitted) return;

    setState(() {
      if (!_favoriteMediaIds.add(mediaId)) {
        _favoriteMediaIds.remove(mediaId);
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || _submitted) {
      return;
    }

    if (_recording) {
      _message(
        'Stop the voice recording before sending.',
      );
      return;
    }

    if (_rating < 0.5 || _rating > 5.0) {
      _message(
        'Choose a rating from 0.5 to 5 first.',
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final profile = await StudioCloudService.instance.getMe();

      final response = StudioRateMeResponse(
        cardId: widget.card.id,
        responderId: profile.id,
        responderName: profile.displayName.trim().isEmpty
            ? profile.username
            : profile.displayName,
        overallRating: _rating,
        overallComment: _commentController.text.trim(),
        favoriteMediaIds: _favoriteMediaIds.toList()..sort(),
        photoReplyPath: _photoReplyPath,
        videoReplyPath: _videoReplyPath,
        voiceReplyPath: _voiceReplyPath,
        createdAt: DateTime.now(),
      );

      String? responsePackageKey;

      if (response.hasAttachments) {
        final exported = await StudioRateMeResponseShareService.exportResponse(
          response,
        );

        responsePackageKey =
            await StudioCloudService.instance.uploadResponsePackage(
          deliveryId: widget.delivery.id,
          file: exported.file,
        );
      }

      await StudioCloudService.instance.submitResponse(
        deliveryId: widget.delivery.id,
        overallRating: _rating,
        overallComment: _commentController.text.trim(),
        favoriteMediaIds: _favoriteMediaIds.toList()..sort(),
        responsePackageKey: responsePackageKey,
      );

      if (!mounted) return;

      setState(
        () => _submitted = true,
      );

      _message(
        response.hasAttachments
            ? 'Rating, message, and media response sent.'
            : 'Rate Me response sent.',
      );
    } on StudioCloudException catch (error) {
      if (!mounted) return;

      if (error.statusCode == 409) {
        setState(
          () => _submitted = true,
        );
      }

      _message(error.message);
    } catch (error) {
      if (!mounted) return;

      _message(
        'Could not send response: $error',
      );
    } finally {
      if (mounted) {
        setState(
          () => _busy = false,
        );
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Rate Me'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          40,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    'From @${widget.delivery.sender.username}',
                    style: const TextStyle(
                      color: Color(0xFFA78BFA),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (card.description.trim().isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    Text(
                      card.description,
                    ),
                  ],
                  const SizedBox(
                    height: 12,
                  ),
                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      SizedBox(
                        width: 7,
                      ),
                      Expanded(
                        child: Text(
                          'Incoming card content is read-only.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Gallery',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < card.media.length; index++) ...[
            _IncomingMedia(
              index: index,
              media: card.media[index],
              favorite: _favoriteMediaIds.contains(
                card.media[index].id,
              ),
              locked: _submitted,
              onFavorite: () => _toggleFavorite(
                card.media[index].id,
              ),
            ),
            const SizedBox(
              height: 12,
            ),
          ],
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                18,
              ),
              child: Column(
                children: [
                  const Text(
                    'Overall Rating',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  EggplantRating(
                    value: _rating,
                    onChanged: _submitted
                        ? null
                        : (value) {
                            setState(() {
                              _rating = value;
                            });
                          },
                    size: 44,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            enabled: !_submitted,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Type a response',
              hintText: 'Write as much or as little as you want.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Media Response',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use any combination you want. Photo, video, voice, and text can all be sent together.',
            style: TextStyle(
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: _submitted ? null : _pickPhoto,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                ),
                label: const Text('Photo'),
              ),
              FilledButton.tonalIcon(
                onPressed: _submitted ? null : _pickVideo,
                icon: const Icon(
                  Icons.video_library_outlined,
                ),
                label: const Text('Video'),
              ),
              FilledButton.tonalIcon(
                onPressed: _submitted ? null : _recordVideo,
                icon: const Icon(
                  Icons.videocam_outlined,
                ),
                label: const Text(
                  'Record Video',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _submitted ? null : _toggleVoiceRecording,
                icon: Icon(
                  _recording
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                ),
                label: Text(
                  _recording ? 'Stop Voice' : 'Record Voice',
                ),
              ),
            ],
          ),
          if (_photoReplyPath != null) ...[
            const SizedBox(height: 16),
            _AttachmentCard(
              icon: Icons.image_outlined,
              title: 'Photo attached',
              onRemove: _submitted
                  ? null
                  : () {
                      setState(
                        () => _photoReplyPath = null,
                      );
                    },
              child: Image.file(
                File(
                  _photoReplyPath!,
                ),
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_videoReplyPath != null) ...[
            const SizedBox(height: 16),
            _AttachmentCard(
              icon: Icons.videocam_outlined,
              title: 'Video attached',
              onRemove: _submitted
                  ? null
                  : () {
                      setState(
                        () => _videoReplyPath = null,
                      );
                    },
              child: _IncomingVideo(
                path: _videoReplyPath!,
              ),
            ),
          ],
          if (_voiceReplyPath != null) ...[
            const SizedBox(height: 16),
            _AttachmentCard(
              icon: Icons.mic_rounded,
              title: 'Voice message attached',
              onRemove: _submitted
                  ? null
                  : () async {
                      await _audioPlayer.stop();

                      setState(() {
                        _playingVoice = false;
                        _voiceReplyPath = null;
                      });
                    },
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconButton(
                  onPressed: _toggleVoicePlayback,
                  icon: Icon(
                    _playingVoice
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_fill_rounded,
                  ),
                ),
                title: Text(
                  _playingVoice
                      ? 'Playing voice response'
                      : 'Preview voice response',
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (_submitted)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFA78BFA),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You already responded to this Rate Me card.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                    ),
              label: Text(
                _busy ? 'Sending...' : 'Send Complete Response',
              ),
            ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.icon,
    required this.title,
    required this.child,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                  ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _IncomingMedia extends StatelessWidget {
  const _IncomingMedia({
    required this.index,
    required this.media,
    required this.favorite,
    required this.locked,
    required this.onFavorite,
  });

  final int index;
  final StudioRateMeMedia media;
  final bool favorite;
  final bool locked;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final exists = media.path.isNotEmpty && File(media.path).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              if (!exists)
                const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(
                    child: Text(
                      'Media unavailable',
                    ),
                  ),
                )
              else if (media.type == StudioRateMeMediaType.photo)
                Image.file(
                  File(media.path),
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              else
                _IncomingVideo(
                  path: media.path,
                ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filled(
                  onPressed: locked ? null : onFavorite,
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: favorite ? Colors.pinkAccent : null,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.caption.trim().isEmpty
                      ? '${media.type.name.toUpperCase()} ${index + 1}'
                      : media.caption,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (media.question.trim().isNotEmpty) ...[
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    media.question,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingVideo extends StatefulWidget {
  const _IncomingVideo({
    required this.path,
  });

  final String path;

  @override
  State<_IncomingVideo> createState() => _IncomingVideoState();
}

class _IncomingVideoState extends State<_IncomingVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

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

      setState(
        () => _failed = true,
      );
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

    if (_failed) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Text(
            'Video unavailable',
          ),
        ),
      );
    }

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
              ),
            ),
          ],
        ),
      ],
    );
  }
}
