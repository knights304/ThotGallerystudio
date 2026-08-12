import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/rate_me_card.dart';
import '../services/rate_me_response_service.dart';
import '../services/studio_cloud_service.dart';
import '../widgets/eggplant_rating.dart';

class StudioRateMeResponsesScreen extends StatefulWidget {
  const StudioRateMeResponsesScreen({
    super.key,
    required this.card,
  });

  final StudioRateMeCard card;

  @override
  State<StudioRateMeResponsesScreen> createState() =>
      _StudioRateMeResponsesScreenState();
}

class _StudioRateMeResponsesScreenState
    extends State<StudioRateMeResponsesScreen> {
  bool _loading = true;
  bool _importing = false;

  List<StudioStoredRateMeResponse> _responses = const [];
  Map<String, int> _favoriteCounts = const {};

  double _averageRating = 0;
  int _commentCount = 0;
  int _videoReplyCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _syncCloudResponses() async {
    try {
      final localResponses = await StudioRateMeResponseService.loadForCard(
        widget.card.id,
      );

      final installedCloudIds = <String>{};

      for (final stored in localResponses) {
        final marker = File(
          '${stored.directory.path}'
          '${Platform.pathSeparator}'
          'cloud_response_id.txt',
        );

        if (!await marker.exists()) {
          continue;
        }

        final responseId = (await marker.readAsString()).trim();

        if (responseId.isNotEmpty) {
          installedCloudIds.add(responseId);
        }
      }

      final cloudResponses =
          await StudioCloudService.instance.getResponseInbox();

      for (final cloudResponse in cloudResponses) {
        if (cloudResponse.cardId != widget.card.id) {
          continue;
        }

        if (installedCloudIds.contains(
          cloudResponse.id,
        )) {
          continue;
        }

        final packageKey = cloudResponse.responsePackageKey?.trim() ?? '';

        // Typed/rating-only cloud responses do not
        // have a multimedia package to download.
        if (packageKey.isEmpty) {
          continue;
        }

        File? temporaryPackage;

        try {
          final bytes =
              await StudioCloudService.instance.downloadResponsePackage(
            cloudResponse.id,
          );

          if (bytes.length <= 22) {
            continue;
          }

          final temporary = await getTemporaryDirectory();

          temporaryPackage = File(
            '${temporary.path}'
            '${Platform.pathSeparator}'
            'studio_cloud_response_'
            '${cloudResponse.id}_'
            '${DateTime.now().microsecondsSinceEpoch}'
            '.tgrateresponse',
          );

          await temporaryPackage.writeAsBytes(
            bytes,
            flush: true,
          );

          final imported = await StudioRateMeResponseService.importPackage(
            temporaryPackage,
          );

          if (imported.response.cardId != widget.card.id) {
            if (await imported.storageDirectory.exists()) {
              await imported.storageDirectory.delete(
                recursive: true,
              );
            }

            continue;
          }

          final marker = File(
            '${imported.storageDirectory.path}'
            '${Platform.pathSeparator}'
            'cloud_response_id.txt',
          );

          await marker.writeAsString(
            cloudResponse.id,
            flush: true,
          );

          installedCloudIds.add(
            cloudResponse.id,
          );
        } catch (_) {
          // A single malformed/missing package should
          // not prevent other responses from loading.
        } finally {
          if (temporaryPackage != null && await temporaryPackage.exists()) {
            await temporaryPackage.delete();
          }
        }
      }
    } on StudioCloudException {
      // Local responses remain available if Studio
      // is offline or the cloud session has expired.
    } catch (_) {
      // Cloud synchronization is best-effort.
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    await _syncCloudResponses();

    final responses = await StudioRateMeResponseService.loadForCard(
      widget.card.id,
    );
    final average = await StudioRateMeResponseService.averageRatingForCard(
      widget.card.id,
    );
    final favoriteCounts =
        await StudioRateMeResponseService.favoriteCountsForCard(
      widget.card.id,
    );
    final commentCount = await StudioRateMeResponseService.commentCountForCard(
      widget.card.id,
    );
    final videoReplyCount =
        await StudioRateMeResponseService.videoReplyCountForCard(
      widget.card.id,
    );

    if (!mounted) return;

    setState(() {
      _responses = responses;
      _averageRating = average;
      _favoriteCounts = favoriteCounts;
      _commentCount = commentCount;
      _videoReplyCount = videoReplyCount;
      _loading = false;
    });
  }

  Future<void> _importResponse() async {
    if (_importing) return;

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a Rate Me response',
      type: FileType.custom,
      allowedExtensions: const ['tgrateresponse'],
    );

    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _importing = true);

    try {
      final imported = await StudioRateMeResponseService.importPackage(
        File(path),
      );

      if (!mounted) return;

      if (imported.response.cardId != widget.card.id) {
        if (await imported.storageDirectory.exists()) {
          await imported.storageDirectory.delete(recursive: true);
        }

        if (!mounted) return;

        _message(
          'That response belongs to a different Rate Me card.',
        );
        return;
      }

      await _load();

      if (!mounted) return;

      final name = imported.response.responderName.trim().isEmpty
          ? 'Anonymous'
          : imported.response.responderName.trim();

      _message('Imported response from $name.');
    } catch (error) {
      if (!mounted) return;
      _message('Could not import response: $error');
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deleteResponse(
    StudioStoredRateMeResponse stored,
  ) async {
    final name = stored.response.responderName.trim().isEmpty
        ? 'Anonymous'
        : stored.response.responderName.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Response?'),
        content: Text(
          'Delete the response from $name and its local media attachments?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    String? cloudResponseId;

    final cloudMarker = File(
      '${stored.directory.path}'
      '${Platform.pathSeparator}'
      'cloud_response_id.txt',
    );

    if (await cloudMarker.exists()) {
      final rawCloudId = (await cloudMarker.readAsString()).trim();

      if (rawCloudId.isNotEmpty) {
        cloudResponseId = rawCloudId;
      }
    }

    if (cloudResponseId != null) {
      try {
        await StudioCloudService.instance.deleteCloudResponse(
          cloudResponseId,
        );
      } on StudioCloudException catch (error) {
        if (!mounted) return;

        _message(
          'Could not delete cloud response: '
          '${error.message}',
        );

        return;
      }
    }

    await StudioRateMeResponseService.deleteResponse(
      stored,
    );

    if (!mounted) return;

    await _load();

    if (!mounted) return;

    _message(
      cloudResponseId == null
          ? 'Local response deleted.'
          : 'Response deleted from Studio and cloud.',
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Me Responses'),
        actions: [
          IconButton(
            tooltip: 'Import .tgrateresponse',
            onPressed: _importing ? null : _importResponse,
            icon: _importing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _importResponse,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Import Response'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (card.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.description,
                    style: const TextStyle(
                      color: Colors.white60,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SummaryPanel(
                  responseCount: _responses.length,
                  averageRating: _averageRating,
                  commentCount: _commentCount,
                  videoReplyCount: _videoReplyCount,
                ),
                if (_favoriteCounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FavoriteMediaPanel(
                    card: card,
                    counts: _favoriteCounts,
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Responses',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (_responses.isEmpty)
                  const _EmptyResponses()
                else
                  for (final stored in _responses) ...[
                    _ResponseCard(
                      card: card,
                      stored: stored,
                      onDelete: () => _deleteResponse(stored),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.responseCount,
    required this.averageRating,
    required this.commentCount,
    required this.videoReplyCount,
  });

  final int responseCount;
  final double averageRating;
  final int commentCount;
  final int videoReplyCount;

  @override
  Widget build(BuildContext context) {
    final hasRating = averageRating > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Rating',
                        style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasRating
                            ? averageRating.toStringAsFixed(2)
                            : 'No ratings',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                _StarDisplay(
                  rating: hasRating ? averageRating : 0.0,
                  size: 27,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons.people_alt_outlined,
                    value: '$responseCount',
                    label: 'Responses',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.chat_bubble_outline_rounded,
                    value: '$commentCount',
                    label: 'Comments',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.videocam_outlined,
                    value: '$videoReplyCount',
                    label: 'Videos',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFA78BFA)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _FavoriteMediaPanel extends StatelessWidget {
  const _FavoriteMediaPanel({
    required this.card,
    required this.counts,
  });

  final StudioRateMeCard card;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most Favorited Media',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in ranked.take(5))
              _FavoriteMediaRow(
                media: _mediaFor(card, entry.key),
                mediaId: entry.key,
                count: entry.value,
              ),
          ],
        ),
      ),
    );
  }

  StudioRateMeMedia? _mediaFor(
    StudioRateMeCard card,
    String mediaId,
  ) {
    for (final media in card.media) {
      if (media.id == mediaId) {
        return media;
      }
    }

    return null;
  }
}

class _FavoriteMediaRow extends StatelessWidget {
  const _FavoriteMediaRow({
    required this.media,
    required this.mediaId,
    required this.count,
  });

  final StudioRateMeMedia? media;
  final String mediaId;
  final int count;

  @override
  Widget build(BuildContext context) {
    final item = media;
    final label = item == null
        ? mediaId
        : item.caption.trim().isNotEmpty
            ? item.caption.trim()
            : '${item.type.name.toUpperCase()} · $mediaId';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF6B9E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.card,
    required this.stored,
    required this.onDelete,
  });

  final StudioRateMeCard card;
  final StudioStoredRateMeResponse stored;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final response = stored.response;
    final name = response.responderName.trim().isEmpty
        ? 'Anonymous'
        : response.responderName.trim();

    final favorites =
        response.favoriteMediaIds.map((id) => _mediaLabel(card, id)).toList();

    final photoReplyPath = response.photoReplyPath;
    final videoReplyPath = response.videoReplyPath;
    final voiceReplyPath = response.voiceReplyPath;

    final hasPhotoReply = photoReplyPath != null &&
        photoReplyPath.trim().isNotEmpty &&
        File(photoReplyPath).existsSync();

    final hasVideoReply = videoReplyPath != null &&
        videoReplyPath.trim().isNotEmpty &&
        File(videoReplyPath).existsSync();

    final hasVoiceReply = voiceReplyPath != null &&
        voiceReplyPath.trim().isNotEmpty &&
        File(voiceReplyPath).existsSync();

    final hasAnyAttachment = hasPhotoReply || hasVideoReply || hasVoiceReply;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline_rounded),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Row(
          children: [
            _StarDisplay(
              rating: response.overallRating,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              response.hasRating
                  ? '${response.overallRating.toStringAsFixed(1)} / 5.0'
                  : 'No rating',
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete response'),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (response.hasComment) ...[
                  const Text(
                    'Comment',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    response.overallComment,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ],
                if (favorites.isNotEmpty) ...[
                  if (response.hasComment) const SizedBox(height: 18),
                  const Text(
                    'Favorites',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final favorite in favorites)
                        Chip(
                          avatar: const Icon(
                            Icons.favorite_rounded,
                            size: 17,
                          ),
                          label: Text(favorite),
                        ),
                    ],
                  ),
                ],
                if (hasPhotoReply) ...[
                  if (response.hasComment || favorites.isNotEmpty)
                    const SizedBox(height: 18),
                  const Text(
                    'Photo Reply',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(photoReplyPath),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (hasVideoReply) ...[
                  if (response.hasComment ||
                      favorites.isNotEmpty ||
                      hasPhotoReply)
                    const SizedBox(height: 18),
                  const Text(
                    'Video Reply',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _VideoReplyPlayer(
                    path: videoReplyPath,
                  ),
                ],
                if (hasVoiceReply) ...[
                  if (response.hasComment ||
                      favorites.isNotEmpty ||
                      hasPhotoReply ||
                      hasVideoReply)
                    const SizedBox(height: 18),
                  const Text(
                    'Voice Reply',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _VoiceReplyPlayer(
                    path: voiceReplyPath,
                  ),
                ],
                if (!response.hasComment &&
                    favorites.isEmpty &&
                    !hasAnyAttachment) ...[
                  const Text(
                    'This response contains only an overall rating.',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  _formatDate(response.createdAt),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _mediaLabel(
    StudioRateMeCard card,
    String mediaId,
  ) {
    for (final media in card.media) {
      if (media.id == mediaId) {
        if (media.caption.trim().isNotEmpty) {
          return media.caption.trim();
        }

        return '${media.type.name.toUpperCase()} ${card.media.indexOf(media) + 1}';
      }
    }

    return mediaId;
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({
    required this.rating,
    this.size = 22,
  });

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return EggplantRating(
      value: rating,
      size: size,
      showValue: false,
    );
  }
}

class _VoiceReplyPlayer extends StatefulWidget {
  const _VoiceReplyPlayer({
    required this.path,
  });

  final String path;

  @override
  State<_VoiceReplyPlayer> createState() => _VoiceReplyPlayerState();
}

class _VoiceReplyPlayerState extends State<_VoiceReplyPlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _playing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.stop();

        if (mounted) {
          setState(() {
            _playing = false;
          });
        }

        return;
      }

      await _player.play(
        DeviceFileSource(widget.path),
      );

      if (mounted) {
        setState(() {
          _playing = true;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: IconButton(
          onPressed: _failed ? null : _toggle,
          iconSize: 38,
          icon: Icon(
            _playing
                ? Icons.stop_circle_rounded
                : Icons.play_circle_fill_rounded,
          ),
        ),
        title: Text(
          _failed
              ? 'Voice reply unavailable'
              : _playing
                  ? 'Playing voice reply'
                  : 'Play voice reply',
        ),
        subtitle: const Text(
          'Audio response',
        ),
      ),
    );
  }
}

class _VideoReplyPlayer extends StatefulWidget {
  const _VideoReplyPlayer({
    required this.path,
  });

  final String path;

  @override
  State<_VideoReplyPlayer> createState() => _VideoReplyPlayerState();
}

class _VideoReplyPlayerState extends State<_VideoReplyPlayer> {
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
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Text('Video reply unavailable'),
        ),
      );
    }

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
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyResponses extends StatelessWidget {
  const _EmptyResponses();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.mark_unread_chat_alt_outlined,
              size: 68,
              color: Color(0xFFA78BFA),
            ),
            SizedBox(height: 16),
            Text(
              'No responses yet',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Import a .tgrateresponse from a Viewer who rated this card.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}-$month-$day $hour:$minute';
}
