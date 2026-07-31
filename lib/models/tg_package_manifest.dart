import 'dart:convert';

import 'gallery_card.dart';

/// Current TG Package format version.
/// Increment this only when the package structure changes.
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
    required this.coverFile,
    required this.photoCount,
    required this.videoCount,
    required this.mediaCount,
    required this.mediaFiles,
    required this.tags,
    required this.collections,
    required this.rarity,
    required this.setName,
    required this.packageHash,
    required this.packageSizeBytes,
  });

  factory TGPackageManifest.fromCard(
    GalleryCard card, {
    String packageHash = '',
    int packageSizeBytes = 0,
  }) {
    card.ensureFingerprint();
    card.syncMediaCounts();

    return TGPackageManifest(
      packageVersion: tgPackageVersion,
      creatorVersion: tgCreatorVersion,
      cardId: card.id,
      cardTitle: card.title,
      fingerprint: card.fingerprint,
      createdAt: DateTime.now().toUtc(),
      coverFile: card.coverImagePath == null
          ? ''
          : 'cover/${card.coverImagePath!.split('/').last}',
      photoCount: card.photoCount,
      videoCount: card.videoCount,
      mediaCount: card.media.length,
      mediaFiles: card.media
          .map((m) => 'media/${m.path.split('/').last}')
          .toList(),
      tags: List<String>.from(card.tags),
      collections: List<String>.from(card.collections),
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

  final String coverFile;

  final int photoCount;

  final int videoCount;

  final int mediaCount;

  final List<String> mediaFiles;

  final List<String> tags;

  final List<String> collections;

  final String rarity;

  final String setName;

  /// SHA256 of the completed .tgpack archive.
  final String packageHash;

  /// Final compressed package size.
  final int packageSizeBytes;

  Map<String, dynamic> toJson() => {
        'packageVersion': packageVersion,
        'creatorVersion': creatorVersion,
        'cardId': cardId,
        'cardTitle': cardTitle,
        'fingerprint': fingerprint,
        'createdAt': createdAt.toIso8601String(),
        'coverFile': coverFile,
        'photoCount': photoCount,
        'videoCount': videoCount,
        'mediaCount': mediaCount,
        'mediaFiles': mediaFiles,
        'tags': tags,
        'collections': collections,
        'rarity': rarity,
        'setName': setName,
        'packageHash': packageHash,
        'packageSizeBytes': packageSizeBytes,
      };

  factory TGPackageManifest.fromJson(Map<String, dynamic> json) {
    return TGPackageManifest(
      packageVersion: json['packageVersion'] ?? 1,
      creatorVersion: json['creatorVersion'] ?? '',
      cardId: json['cardId'] ?? '',
      cardTitle: json['cardTitle'] ?? '',
      fingerprint: json['fingerprint'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      coverFile: json['coverFile'] ?? '',
      photoCount: json['photoCount'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      mediaCount: json['mediaCount'] ?? 0,
      mediaFiles: List<String>.from(json['mediaFiles'] ?? const []),
      tags: List<String>.from(json['tags'] ?? const []),
      collections: List<String>.from(json['collections'] ?? const []),
      rarity: json['rarity'] ?? '',
      setName: json['setName'] ?? '',
      packageHash: json['packageHash'] ?? '',
      packageSizeBytes: json['packageSizeBytes'] ?? 0,
    );
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  String toCompactJson() {
    return jsonEncode(toJson());
  }

  TGPackageManifest copyWith({
    String? packageHash,
    int? packageSizeBytes,
  }) {
    return TGPackageManifest(
      packageVersion: packageVersion,
      creatorVersion: creatorVersion,
      cardId: cardId,
      cardTitle: cardTitle,
      fingerprint: fingerprint,
      createdAt: createdAt,
      coverFile: coverFile,
      photoCount: photoCount,
      videoCount: videoCount,
      mediaCount: mediaCount,
      mediaFiles: mediaFiles,
      tags: tags,
      collections: collections,
      rarity: rarity,
      setName: setName,
      packageHash: packageHash ?? this.packageHash,
      packageSizeBytes: packageSizeBytes ?? this.packageSizeBytes,
    );
  }
}
