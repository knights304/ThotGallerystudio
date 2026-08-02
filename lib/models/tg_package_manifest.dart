import 'dart:convert';

import 'gallery_card.dart';

/// TG Package format version.
///
/// Version 1 packages are self-verifying at the content level through
/// [fileHashes]. The final archive hash is calculated after compression and is
/// returned by the builder, but it is intentionally not embedded back into the
/// archive because doing so would change the archive hash again.
const int tgPackageVersion = 1;

/// Current Creator application version that generated the package.
const String tgCreatorVersion = '2.0.0';

class TGPackageManifest {
  TGPackageManifest({
    required this.packageVersion,
    required this.creatorVersion,
    required this.cardId,
    required this.cardTitle,
    required this.fingerprint,
    required this.createdAt,
    required this.cardFile,
    required this.coverFile,
    required this.photoCount,
    required this.videoCount,
    required this.mediaCount,
    required this.mediaFiles,
    required this.fileHashes,
    required this.tags,
    required this.collections,
    required this.rarity,
    required this.setName,
    required this.packageHash,
    required this.packageSizeBytes,
  });

  factory TGPackageManifest.fromCard(
    GalleryCard card, {
    String cardFile = 'card.json',
    String? coverFile,
    List<String>? mediaFiles,
    Map<String, String> fileHashes = const {},
    String packageHash = '',
    int packageSizeBytes = 0,
  }) {
    card.ensureFingerprint();
    card.syncMediaCounts();

    final resolvedCoverFile = coverFile ??
        (card.coverImagePath == null || card.coverImagePath!.isEmpty
            ? ''
            : 'cover/${card.coverImagePath!.split('/').last}');

    final resolvedMediaFiles = mediaFiles ??
        card.media
            .map((media) => 'media/${media.path.split('/').last}')
            .toList();

    return TGPackageManifest(
      packageVersion: tgPackageVersion,
      creatorVersion: tgCreatorVersion,
      cardId: card.id,
      cardTitle: card.title,
      fingerprint: card.fingerprint,
      createdAt: DateTime.now().toUtc(),
      cardFile: cardFile,
      coverFile: resolvedCoverFile,
      photoCount: card.photoCount,
      videoCount: card.videoCount,
      mediaCount: card.media.length,
      mediaFiles: List<String>.unmodifiable(resolvedMediaFiles),
      fileHashes: Map<String, String>.unmodifiable(fileHashes),
      tags: List<String>.unmodifiable(card.tags),
      collections: List<String>.unmodifiable(card.collections),
      rarity: card.rarity,
      setName: card.setName,
      packageHash: packageHash,
      packageSizeBytes: packageSizeBytes,
    );
  }

  final int packageVersion;
  final String creatorVersion;
  final String cardId;
  final String cardTitle;
  final String fingerprint;
  final DateTime createdAt;

  /// Package-relative path to the portable card JSON document.
  final String cardFile;

  /// Package-relative cover path, or an empty string when no cover exists.
  final String coverFile;

  final int photoCount;
  final int videoCount;
  final int mediaCount;

  /// Package-relative paths for media in the same order as card.media.
  final List<String> mediaFiles;

  /// SHA-256 digests for package content files.
  ///
  /// Keys are package-relative paths such as `card.json`,
  /// `cover/cover.jpg`, and `media/0001_id_photo.jpg`.
  /// `tg_manifest.json` is intentionally excluded because a manifest cannot
  /// contain a stable hash of itself.
  final Map<String, String> fileHashes;

  final List<String> tags;
  final List<String> collections;
  final String rarity;
  final String setName;

  /// SHA-256 of the final completed .tgpack archive.
  ///
  /// This value is available on the manifest returned by PackageBuilderService.
  /// The copy stored inside the archive normally leaves this empty because
  /// embedding the final archive hash would change the archive itself.
  final String packageHash;

  /// Final compressed package size in bytes.
  ///
  /// Like [packageHash], the runtime result can contain this value even when
  /// the embedded manifest leaves it at zero.
  final int packageSizeBytes;

  String? hashFor(String packagePath) => fileHashes[packagePath];

  Map<String, dynamic> toJson() => {
        'packageVersion': packageVersion,
        'creatorVersion': creatorVersion,
        'cardId': cardId,
        'cardTitle': cardTitle,
        'fingerprint': fingerprint,
        'createdAt': createdAt.toIso8601String(),
        'cardFile': cardFile,
        'coverFile': coverFile,
        'photoCount': photoCount,
        'videoCount': videoCount,
        'mediaCount': mediaCount,
        'mediaFiles': mediaFiles,
        'fileHashes': fileHashes,
        'tags': tags,
        'collections': collections,
        'rarity': rarity,
        'setName': setName,
        'packageHash': packageHash,
        'packageSizeBytes': packageSizeBytes,
      };

  factory TGPackageManifest.fromJson(Map<String, dynamic> json) {
    final rawHashes = json['fileHashes'];
    final hashes = <String, String>{};

    if (rawHashes is Map) {
      for (final entry in rawHashes.entries) {
        hashes[entry.key.toString()] = entry.value.toString();
      }
    }

    return TGPackageManifest(
      packageVersion: (json['packageVersion'] as num?)?.toInt() ?? 1,
      creatorVersion: json['creatorVersion'] as String? ?? '',
      cardId: json['cardId'] as String? ?? '',
      cardTitle: json['cardTitle'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      cardFile: json['cardFile'] as String? ?? 'card.json',
      coverFile: json['coverFile'] as String? ?? '',
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      videoCount: (json['videoCount'] as num?)?.toInt() ?? 0,
      mediaCount: (json['mediaCount'] as num?)?.toInt() ?? 0,
      mediaFiles: List<String>.from(json['mediaFiles'] as List? ?? const []),
      fileHashes: Map<String, String>.unmodifiable(hashes),
      tags: List<String>.from(json['tags'] as List? ?? const []),
      collections: List<String>.from(json['collections'] as List? ?? const []),
      rarity: json['rarity'] as String? ?? '',
      setName: json['setName'] as String? ?? '',
      packageHash: json['packageHash'] as String? ?? '',
      packageSizeBytes: (json['packageSizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  String toCompactJson() => jsonEncode(toJson());

  TGPackageManifest copyWith({
    String? packageHash,
    int? packageSizeBytes,
    Map<String, String>? fileHashes,
  }) {
    return TGPackageManifest(
      packageVersion: packageVersion,
      creatorVersion: creatorVersion,
      cardId: cardId,
      cardTitle: cardTitle,
      fingerprint: fingerprint,
      createdAt: createdAt,
      cardFile: cardFile,
      coverFile: coverFile,
      photoCount: photoCount,
      videoCount: videoCount,
      mediaCount: mediaCount,
      mediaFiles: mediaFiles,
      fileHashes: fileHashes ?? this.fileHashes,
      tags: tags,
      collections: collections,
      rarity: rarity,
      setName: setName,
      packageHash: packageHash ?? this.packageHash,
      packageSizeBytes: packageSizeBytes ?? this.packageSizeBytes,
    );
  }
}
