import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/creator_profile.dart';
import '../../models/gallery_card.dart';

class PackageValidationResult {
  const PackageValidationResult({
    required this.isValid,
    required this.messages,
    this.card,
    this.creator,
  });

  final bool isValid;
  final List<String> messages;
  final GalleryCard? card;
  final CreatorProfile? creator;
}

class ThotPackageService {
  static const formatName = 'thot-gallery-package';
  static const formatVersion = 1;

  Future<Directory> exportRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'ThotGallery', 'Exports'));
    await root.create(recursive: true);
    return root;
  }

  Future<File> exportPackage(
    GalleryCard card, {
    CreatorProfile? creator,
    String? browserHtml,
  }) async {
    card.ensureFingerprint();
    final archive = Archive();
    final checksums = <String, String>{};
    final mediaMap = <String, String>{};

    void addBytes(String name, List<int> bytes) {
      archive.addFile(ArchiveFile.bytes(name, bytes));
      checksums[name] = sha256.convert(bytes).toString();
    }

    final manifest = <String, dynamic>{
      'format': formatName,
      'version': formatVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'pieceId': card.id,
      'fingerprint': card.fingerprint,
      'creatorId': creator?.id,
    };
    addBytes('piece.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(card.toJson())));
    if (creator != null) {
      addBytes(
          'creator.json',
          utf8.encode(
              const JsonEncoder.withIndent('  ').convert(creator.toJson())));
    }
    if (browserHtml != null) {
      addBytes('browser/index.html', utf8.encode(browserHtml));
    }

    final paths = <String>{};
    if (card.coverImagePath != null) paths.add(card.coverImagePath!);
    for (final item in card.media) {
      paths.add(item.path);
      if (item.thumbnailPath != null) paths.add(item.thumbnailPath!);
    }
    if (creator?.avatarPath != null) paths.add(creator!.avatarPath!);
    if (creator?.logoPath != null) paths.add(creator!.logoPath!);
    if (creator?.watermarkPath != null) paths.add(creator!.watermarkPath!);

    for (final sourcePath in paths) {
      final file = File(sourcePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final stem =
          sha256.convert(utf8.encode(sourcePath)).toString().substring(0, 12);
      final archiveName = 'media/$stem-${p.basename(sourcePath)}';
      addBytes(archiveName, bytes);
      mediaMap[sourcePath] = archiveName;
    }

    manifest['checksums'] = checksums;
    manifest['mediaMap'] = mediaMap;
    addBytes('manifest.json',
        utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)));

    final encoded = ZipEncoder().encode(archive);
    final root = await exportRoot();
    final folder = Directory(p.join(root.path, card.id));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, '${card.id}.thot'));
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<PackageValidationResult> validate(File file) async {
    final messages = <String>[];
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final byName = <String, ArchiveFile>{
        for (final entry in archive) entry.name: entry
      };
      final manifestEntry = byName['manifest.json'];
      final pieceEntry = byName['piece.json'];
      if (manifestEntry == null || pieceEntry == null) {
        return const PackageValidationResult(
          isValid: false,
          messages: ['Package is missing manifest.json or piece.json.'],
        );
      }
      final manifest =
          jsonDecode(utf8.decode(manifestEntry.content as List<int>))
              as Map<String, dynamic>;
      if (manifest['format'] != formatName) {
        messages.add('Unknown package format.');
      }
      if ((manifest['version'] as num?)?.toInt() != formatVersion) {
        messages.add('Unsupported package version: ${manifest['version']}.');
      }
      final checksums =
          Map<String, dynamic>.from(manifest['checksums'] as Map? ?? const {});
      for (final entry in checksums.entries) {
        final archived = byName[entry.key];
        if (archived == null) {
          messages.add('Missing file: ${entry.key}');
          continue;
        }
        final actual = sha256.convert(archived.content as List<int>).toString();
        if (actual != entry.value) {
          messages.add('Checksum mismatch: ${entry.key}');
        }
      }
      final card = GalleryCard.fromJson(
        jsonDecode(utf8.decode(pieceEntry.content as List<int>))
            as Map<String, dynamic>,
      );
      CreatorProfile? creator;
      final creatorEntry = byName['creator.json'];
      if (creatorEntry != null) {
        creator = CreatorProfile.fromJson(
          jsonDecode(utf8.decode(creatorEntry.content as List<int>))
              as Map<String, dynamic>,
        );
      }
      if (messages.isEmpty) {
        messages.add('Package structure and checksums are valid.');
      }
      return PackageValidationResult(
        isValid: messages.length == 1 &&
            messages.first.startsWith('Package structure'),
        messages: messages,
        card: card,
        creator: creator,
      );
    } catch (error) {
      return PackageValidationResult(
          isValid: false, messages: ['Could not read package: $error']);
    }
  }

  Future<GalleryCard> importPackage(File file) async {
    final result = await validate(file);
    if (!result.isValid || result.card == null) {
      throw FormatException(result.messages.join('\n'));
    }
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final byName = <String, ArchiveFile>{
      for (final entry in archive) entry.name: entry
    };
    final manifestEntry = byName['manifest.json']!;
    final manifest = jsonDecode(
      utf8.decode(manifestEntry.content as List<int>),
    ) as Map<String, dynamic>;
    final mediaMap = Map<String, dynamic>.from(
      manifest['mediaMap'] as Map? ?? const {},
    );
    final documents = await getApplicationDocumentsDirectory();
    final pieceDir = Directory(
      p.join(documents.path, 'ThotGallery', 'Imported', result.card!.id),
    );
    await pieceDir.create(recursive: true);
    final remapped = <String, String>{};
    for (final mapping in mediaMap.entries) {
      final archived = byName[mapping.value.toString()];
      if (archived == null || !archived.isFile) continue;
      final target = File(p.join(pieceDir.path, p.basename(archived.name)));
      await target.writeAsBytes(
        Uint8List.fromList(archived.content as List<int>),
        flush: true,
      );
      remapped[mapping.key] = target.path;
    }
    final card = result.card!;
    if (card.coverImagePath != null) {
      card.coverImagePath =
          remapped[card.coverImagePath!] ?? card.coverImagePath;
    }
    card.media = card.media.map((item) {
      final json = item.toJson();
      json['path'] = remapped[item.path] ?? item.path;
      if (item.thumbnailPath != null) {
        json['thumbnailPath'] =
            remapped[item.thumbnailPath!] ?? item.thumbnailPath;
      }
      return GalleryMediaItem.fromJson(json);
    }).toList();
    return card;
  }
}
