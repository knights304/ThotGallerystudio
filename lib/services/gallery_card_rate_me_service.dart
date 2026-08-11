import '../models/gallery_card.dart';
import '../models/rate_me_card.dart';
import 'rate_me_store.dart';

class GalleryCardRateMeService {
  const GalleryCardRateMeService._();

  static Future<StudioRateMeCard> createFromGalleryCard(
    GalleryCard source, {
    String ownerId = 'studio',
    String ownerName = 'THOT Gallery Studio',
  }) async {
    final now = DateTime.now();
    final cardId = 'rate_${source.id}_${now.toUtc().microsecondsSinceEpoch}';

    String? coverPath;
    final sourceCover = source.coverImagePath;

    if (sourceCover != null && sourceCover.trim().isNotEmpty) {
      try {
        coverPath = await StudioRateMeStore.importCover(
          cardId: cardId,
          sourcePath: sourceCover,
        );
      } catch (_) {
        coverPath = null;
      }
    }

    final media = <StudioRateMeMedia>[];

    final sortedSourceMedia = List<GalleryMediaItem>.from(source.media)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in sortedSourceMedia) {
      if (item.path.trim().isEmpty) continue;

      try {
        final imported = await StudioRateMeStore.importMedia(
          cardId: cardId,
          sourcePath: item.path,
          type: item.type == GalleryMediaType.photo
              ? StudioRateMeMediaType.photo
              : StudioRateMeMediaType.video,
        );

        media.add(
          imported.copyWith(
            caption: item.caption,
            question: '',
          ),
        );
      } catch (_) {
        // Skip missing or unreadable media while preserving the rest.
      }
    }

    final created = StudioRateMeCard(
      id: cardId,
      title: source.title.trim().isEmpty
          ? 'Rate Me'
          : 'Rate Me · ${source.title.trim()}',
      description: source.description.trim().isEmpty
          ? 'Tell me what you think. Choose your favorites and leave an '
              'overall rating, comment, or video reply.'
          : source.description.trim(),
      owner: StudioRateMeOwner(
        type: 'studio',
        id: ownerId,
        displayName: ownerName,
      ),
      responseTarget: const StudioRateMeResponseTarget(mode: 'file'),
      coverImagePath: coverPath,
      media: media,
      createdAt: now,
      updatedAt: now,
    );

    return StudioRateMeStore.saveCard(created);
  }
}
