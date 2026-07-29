import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/gallery_card.dart';
import '../theme/gallery_theme.dart';

class LivingMediaGallery extends StatefulWidget {
  const LivingMediaGallery({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  final List<GalleryMediaItem> media;
  final int initialIndex;

  @override
  State<LivingMediaGallery> createState() => _LivingMediaGalleryState();
}

class _LivingMediaGalleryState extends State<LivingMediaGallery> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.media.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.media.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openFullscreen(int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FullscreenMediaViewer(
          media: widget.media,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Living Media',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Open fullscreen',
              onPressed: () => _openFullscreen(_index),
              icon: const Icon(Icons.fullscreen_rounded),
            ),
            const SizedBox(width: 6),
            Text(
              '${_index + 1}/${widget.media.length}',
              style: const TextStyle(color: GalleryColors.silver),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.media.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.media[index];
                return switch (item.type) {
                  GalleryMediaType.photo => GestureDetector(
                      onTap: () => _openFullscreen(index),
                      child: _PhotoMedia(item: item),
                    ),
                  GalleryMediaType.video => _VideoMedia(item: item),
                };
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.media[_index].caption.trim().isNotEmpty)
          Text(
            widget.media[_index].caption,
            style: const TextStyle(color: GalleryColors.silver),
          ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.media.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = widget.media[index];
              final selected = index == _index;
              return GestureDetector(
                onTap: () => _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                ),
                onLongPress: () => _openFullscreen(index),
                child: Container(
                  width: 86,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? GalleryColors.purple
                          : const Color(0x557D6C8E),
                      width: selected ? 2 : 1,
                    ),
                    color: GalleryColors.surfaceRaised,
                  ),
                  child: item.type == GalleryMediaType.photo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(item.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        )
                      : const Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.videocam_outlined, size: 30),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Icon(Icons.play_circle_fill, size: 18),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FullscreenMediaViewer extends StatefulWidget {
  const _FullscreenMediaViewer({
    required this.media,
    required this.initialIndex,
  });

  final List<GalleryMediaItem> media;
  final int initialIndex;

  @override
  State<_FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<_FullscreenMediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.media[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${_index + 1} of ${widget.media.length}'),
        actions: [
          if (item.isFavorite)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.media.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final mediaItem = widget.media[index];
                return switch (mediaItem.type) {
                  GalleryMediaType.photo => _PhotoMedia(item: mediaItem),
                  GalleryMediaType.video => _VideoMedia(item: mediaItem),
                };
              },
            ),
          ),
          if (item.caption.trim().isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                color: Colors.black87,
                child: Text(
                  item.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GalleryColors.silver),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoMedia extends StatelessWidget {
  const _PhotoMedia({required this.item});

  final GalleryMediaItem item;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.file(
          File(item.path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined, size: 60)),
        ),
      ),
    );
  }
}

class _VideoMedia extends StatefulWidget {
  const _VideoMedia({required this.item});

  final GalleryMediaItem item;

  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.item.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
            ),
          ),
          IconButton.filled(
            onPressed: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 8,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
