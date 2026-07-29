import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/gallery_card.dart';

class MediaVaultService {
  Directory? _root;

  Future<Directory> get root async {
    if (_root != null) {
      return _root!;
    }

    final documents = await getApplicationDocumentsDirectory();
    final rootDirectory = Directory(
      p.join(documents.path, 'ThotGalleryStudio'),
    );

    await rootDirectory.create(recursive: true);
    await Directory(
      p.join(rootDirectory.path, 'Pieces'),
    ).create(recursive: true);
    await Directory(
      p.join(rootDirectory.path, 'Drafts'),
    ).create(recursive: true);
    await Directory(
      p.join(rootDirectory.path, 'Exports'),
    ).create(recursive: true);

    _root = rootDirectory;
    return rootDirectory;
  }

  Future<Directory> pieceDirectory(
    String id, {
    required bool draft,
  }) async {
    final base = await root;
    final directory = Directory(
      p.join(base.path, draft ? 'Drafts' : 'Pieces', id),
    );

    await directory.create(recursive: true);
    await Directory(
      p.join(directory.path, 'photos'),
    ).create(recursive: true);
    await Directory(
      p.join(directory.path, 'videos'),
    ).create(recursive: true);
    await Directory(
      p.join(directory.path, 'thumbs'),
    ).create(recursive: true);

    return directory;
  }

  Future<GalleryCard> savePiece(GalleryCard card) async {
    final isDraft = card.status == GalleryCardStatus.idea;
    final target = await pieceDirectory(card.id, draft: isDraft);

    final other = await pieceDirectory(card.id, draft: !isDraft);
    if (other.path != target.path && await other.exists()) {
      try {
        await other.delete(recursive: true);
      } on FileSystemException {
        // Keep the newly saved version even if old-folder cleanup fails.
      }
    }

    card.coverImagePath = await _importFile(
      card.coverImagePath,
      target,
      preferredName: 'cover',
    );

    final imported = <GalleryMediaItem>[];

    for (var index = 0; index < card.media.length; index++) {
      final item = card.media[index];
      final subfolder =
          item.type == GalleryMediaType.photo ? 'photos' : 'videos';

      final importedPath = await _importFile(
        item.path,
        Directory(p.join(target.path, subfolder)),
        preferredName:
            '${item.type.name}_${(index + 1).toString().padLeft(3, '0')}',
      );

      if (importedPath == null) {
        continue;
      }

      imported.add(
        GalleryMediaItem(
          id: item.id,
          path: importedPath,
          type: item.type,
          caption: item.caption,
          isFavorite: item.isFavorite,
          sortOrder: index,
          thumbnailPath: item.thumbnailPath,
          rating: item.rating,
          tags: List<String>.of(item.tags),
          width: item.width,
          height: item.height,
          sizeBytes: item.sizeBytes,
          importedAt: item.importedAt,
        ),
      );
    }

    card.media = imported;
    card.syncMediaCounts();

    final jsonFile = File(p.join(target.path, 'piece.json'));
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(card.toJson()),
      flush: true,
    );

    return card;
  }

  Future<String?> _importFile(
    String? sourcePath,
    Directory target, {
    required String preferredName,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final source = File(sourcePath);
    if (!await source.exists()) {
      return null;
    }

    await target.create(recursive: true);

    if (p.isWithin(target.path, source.path)) {
      return source.path;
    }

    final extension = p.extension(source.path).isEmpty
        ? '.bin'
        : p.extension(source.path).toLowerCase();

    var destination = File(
      p.join(target.path, '$preferredName$extension'),
    );
    var suffix = 1;

    while (await destination.exists()) {
      destination = File(
        p.join(target.path, '${preferredName}_$suffix$extension'),
      );
      suffix++;
    }

    await source.copy(destination.path);
    return destination.path;
  }

  Future<List<GalleryCard>> loadAll() async {
    final base = await root;
    final cards = <GalleryCard>[];

    for (final folder in <String>['Pieces', 'Drafts']) {
      final directory = Directory(p.join(base.path, folder));

      if (!await directory.exists()) {
        continue;
      }

      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory) {
          continue;
        }

        final jsonFile = File(p.join(entity.path, 'piece.json'));
        if (!await jsonFile.exists()) {
          continue;
        }

        try {
          final decoded = jsonDecode(await jsonFile.readAsString());
          if (decoded is! Map<String, dynamic>) {
            continue;
          }

          cards.add(GalleryCard.fromJson(decoded));
        } on FormatException {
          // Ignore malformed JSON so one damaged piece does not block startup.
        } on FileSystemException {
          // Ignore unreadable files and continue loading the remaining pieces.
        }
      }
    }

    return cards;
  }

  Future<void> deletePiece(String id) async {
    final base = await root;

    for (final folder in <String>['Pieces', 'Drafts']) {
      final directory = Directory(p.join(base.path, folder, id));

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }
}
