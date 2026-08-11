import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/rate_me_card.dart';

class StudioRateMeStore {
  const StudioRateMeStore._();

  static Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      p.join(support.path, 'studio_rate_me_cards'),
    );
    await root.create(recursive: true);
    return root;
  }

  static Future<Directory> _cardRoot(String cardId) async {
    final root = await _root();
    final cardRoot = Directory(
      p.join(root.path, _safe(cardId)),
    );
    await cardRoot.create(recursive: true);
    return cardRoot;
  }

  static Future<StudioRateMeCard?> loadCard(String cardId) async {
    if (cardId.trim().isEmpty) return null;

    final root = await _cardRoot(cardId);
    final metadata = File(
      p.join(root.path, 'card.json'),
    );

    if (!await metadata.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(
        await metadata.readAsString(),
      );

      if (decoded is! Map) {
        return null;
      }

      return StudioRateMeCard.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<StudioRateMeCard>> loadAll() async {
    final root = await _root();
    final cards = <StudioRateMeCard>[];

    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;

      final metadata = File(
        p.join(entity.path, 'card.json'),
      );

      if (!await metadata.exists()) continue;

      try {
        final decoded = jsonDecode(
          await metadata.readAsString(),
        );

        if (decoded is! Map) continue;

        cards.add(
          StudioRateMeCard.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
        );
      } catch (_) {
        // Ignore malformed local cards.
      }
    }

    cards.sort((a, b) {
      final aDate =
          a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return cards;
  }

  static Future<StudioRateMeCard> saveCard(
    StudioRateMeCard card,
  ) async {
    final now = DateTime.now();
    final saved = card.copyWith(
      createdAt: card.createdAt ?? now,
      updatedAt: now,
    );

    final root = await _cardRoot(saved.id);
    final metadata = File(
      p.join(root.path, 'card.json'),
    );

    await metadata.writeAsString(
      jsonEncode(saved.toJson()),
      flush: true,
    );

    return saved;
  }

  static Future<String> importCover({
    required String cardId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw StateError('Selected cover image does not exist.');
    }

    final root = await _cardRoot(cardId);
    final mediaRoot = Directory(
      p.join(root.path, 'cover'),
    );
    await mediaRoot.create(recursive: true);

    final extension = _safeExtension(
      source.path,
      fallback: '.jpg',
    );

    final destination = File(
      p.join(mediaRoot.path, 'cover$extension'),
    );

    await source.copy(destination.path);
    return destination.path;
  }

  static Future<StudioRateMeMedia> importMedia({
    required String cardId,
    required String sourcePath,
    required StudioRateMeMediaType type,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw StateError('Selected media does not exist.');
    }

    final root = await _cardRoot(cardId);
    final mediaRoot = Directory(
      p.join(root.path, 'media'),
    );
    await mediaRoot.create(recursive: true);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final extension = _safeExtension(
      source.path,
      fallback: type == StudioRateMeMediaType.photo ? '.jpg' : '.mp4',
    );

    final destination = File(
      p.join(mediaRoot.path, '$id$extension'),
    );

    await source.copy(destination.path);

    return StudioRateMeMedia(
      id: id,
      path: destination.path,
      type: type,
      createdAt: DateTime.now(),
    );
  }

  static Future<void> deleteMedia(
    StudioRateMeMedia media,
  ) async {
    final file = File(media.path);

    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> deleteCard(String cardId) async {
    if (cardId.trim().isEmpty) return;

    final root = await _root();
    final cardRoot = Directory(
      p.join(root.path, _safe(cardId)),
    );

    if (await cardRoot.exists()) {
      await cardRoot.delete(recursive: true);
    }
  }

  static String _safe(String value) {
    final safe = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return safe.isEmpty ? 'rate_me' : safe;
  }

  static String _safeExtension(
    String sourcePath, {
    required String fallback,
  }) {
    final extension = p.extension(sourcePath).toLowerCase();

    if (extension.isEmpty || extension.length > 8) {
      return fallback;
    }

    final safe = extension.replaceAll(
      RegExp(r'[^a-z0-9.]'),
      '',
    );

    return safe.isEmpty ? fallback : safe;
  }
}
