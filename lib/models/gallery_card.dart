import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

enum GalleryCardType {
  profile,
  galleryPiece,
  rateMe,
  matchMyFreak,
  location,
  activity,
  person,
  interest,
  mystery,
  thot,
}

enum GalleryCardStatus {
  idea,
  planned,
  completed,
  memory,
  favorite,
  archived,
}

enum GalleryCardTemplate {
  royalPurple,
  blackChrome,
  silverNeon,
  neonBattle,
}

enum GalleryImageFit {
  cover,
  contain,
  fill,
}

enum GalleryMediaType {
  photo,
  video,
}

class GalleryMediaItem {
  GalleryMediaItem({
    required this.id,
    required this.path,
    required this.type,
    this.caption = '',
    this.isFavorite = false,
    this.sortOrder = 0,
    this.thumbnailPath,
    this.rating = 0,
    this.tags = const [],
    this.width = 0,
    this.height = 0,
    this.sizeBytes = 0,
    this.importedAt,
    this.contentHash = '',
    this.collections = const [],
  });

  final String id;
  final String path;
  final GalleryMediaType type;
  String caption;
  bool isFavorite;
  int sortOrder;
  String? thumbnailPath;
  int rating;
  List<String> tags;
  int width;
  int height;
  int sizeBytes;
  DateTime? importedAt;
  String contentHash;
  List<String> collections;

  String get filename => p.basename(path);

  String get dimensionsLabel =>
      width > 0 && height > 0 ? '$width×$height' : 'Unknown size';

  String get sizeLabel {
    if (sizeBytes <= 0) {
      return 'Unknown';
    }

    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }

    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'type': type.name,
        'caption': caption,
        'isFavorite': isFavorite,
        'sortOrder': sortOrder,
        'thumbnailPath': thumbnailPath,
        'rating': rating,
        'tags': tags,
        'width': width,
        'height': height,
        'sizeBytes': sizeBytes,
        'importedAt': importedAt?.toIso8601String(),
        'contentHash': contentHash,
        'collections': collections,
      };

  factory GalleryMediaItem.fromJson(Map<String, dynamic> json) {
    return GalleryMediaItem(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      path: json['path'] as String? ?? '',
      type: GalleryMediaType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => GalleryMediaType.photo,
      ),
      caption: json['caption'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      thumbnailPath: json['thumbnailPath'] as String?,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? ''),
      contentHash: json['contentHash'] as String? ?? '',
      collections: List<String>.from(json['collections'] as List? ?? const []),
    );
  }
}

class GalleryCard {
  GalleryCard({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    this.template = GalleryCardTemplate.neonBattle,
    this.description = '',
    this.coverImagePath,
    this.media = const [],
    this.imageFit = GalleryImageFit.cover,
    this.imageAlignmentX = 0,
    this.imageAlignmentY = 0,
    this.thotPoints = 100,
    this.setName = 'Thot Gallery Originals',
    this.rarityCategory = 'Standard',
    this.rarity = 'Original',
    this.cardNumber = 1,
    this.setTotal = 1,
    this.fingerprint = '',
    this.views = 0,
    this.shareCount = 0,
    this.photoCount = 0,
    this.videoCount = 0,
    this.locationCount = 0,
    this.peopleCount = 0,
    this.nfcEnabled = true,
    this.isRevealed = false,
    this.location = '',
    this.date,
    this.rating = 0,
    this.tags = const [],
    this.collections = const [],
    this.participants = const [],
    this.links = const [],
    this.notes = '',
    this.isFavorite = false,
    this.createdAt,
    this.updatedAt,
    this.lastSharedAt,
  });

  final String id;
  String title;
  GalleryCardType type;
  GalleryCardStatus status;
  GalleryCardTemplate template;
  String description;
  String? coverImagePath;
  List<GalleryMediaItem> media;
  GalleryImageFit imageFit;
  double imageAlignmentX;
  double imageAlignmentY;
  int thotPoints;
  String setName;
  String rarityCategory;
  String rarity;
  int cardNumber;
  int setTotal;
  String fingerprint;
  int views;
  int shareCount;
  int photoCount;
  int videoCount;
  int locationCount;
  int peopleCount;
  bool nfcEnabled;
  bool isRevealed;
  String location;
  DateTime? date;
  double rating;
  List<String> tags;
  List<String> collections;
  List<String> participants;
  List<String> links;
  String notes;
  bool isFavorite;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? lastSharedAt;

  GalleryCard copy() => GalleryCard.fromJson(toJson());

  void syncMediaCounts() {
    photoCount =
        media.where((item) => item.type == GalleryMediaType.photo).length;
    videoCount =
        media.where((item) => item.type == GalleryMediaType.video).length;
  }

  void ensureFingerprint() {
    if (fingerprint.isNotEmpty) {
      return;
    }

    final source = '$id|${createdAt?.toIso8601String() ?? ''}|$title|$setName';
    fingerprint = sha256.convert(utf8.encode(source)).toString().toUpperCase();
  }

  String get shortFingerprint {
    ensureFingerprint();

    return [
      fingerprint.substring(0, 4),
      fingerprint.substring(4, 8),
      fingerprint.substring(8, 12),
      fingerprint.substring(12, 16),
    ].join('-');
  }

  String get verificationPayload {
    ensureFingerprint();

    return 'https://thotivites.app/verify'
        '?card=$id'
        '&fingerprint=${Uri.encodeComponent(fingerprint)}';
  }

  bool get isMysteryLocked => type == GalleryCardType.mystery && !isRevealed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'status': status.name,
        'template': template.name,
        'description': description,
        'coverImagePath': coverImagePath,
        'media': media.map((item) => item.toJson()).toList(),
        'imageFit': imageFit.name,
        'imageAlignmentX': imageAlignmentX,
        'imageAlignmentY': imageAlignmentY,
        'thotPoints': thotPoints,
        'setName': setName,
        'rarityCategory': rarityCategory,
        'rarity': rarity,
        'cardNumber': cardNumber,
        'setTotal': setTotal,
        'fingerprint': fingerprint,
        'views': views,
        'shareCount': shareCount,
        'photoCount': photoCount,
        'videoCount': videoCount,
        'locationCount': locationCount,
        'peopleCount': peopleCount,
        'nfcEnabled': nfcEnabled,
        'isRevealed': isRevealed,
        'location': location,
        'date': date?.toIso8601String(),
        'rating': rating,
        'tags': tags,
        'collections': collections,
        'participants': participants,
        'links': links,
        'notes': notes,
        'isFavorite': isFavorite,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'lastSharedAt': lastSharedAt?.toIso8601String(),
      };

  factory GalleryCard.fromJson(Map<String, dynamic> json) {
    final card = GalleryCard(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      type: GalleryCardType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => GalleryCardType.thot,
      ),
      status: GalleryCardStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => GalleryCardStatus.idea,
      ),
      template: GalleryCardTemplate.values.firstWhere(
        (value) => value.name == json['template'],
        orElse: () => GalleryCardTemplate.neonBattle,
      ),
      description: json['description'] as String? ?? '',
      coverImagePath: json['coverImagePath'] as String?,
      media: (json['media'] as List? ?? const [])
          .map(
            (item) => GalleryMediaItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      imageFit: GalleryImageFit.values.firstWhere(
        (value) => value.name == json['imageFit'],
        orElse: () => GalleryImageFit.cover,
      ),
      imageAlignmentX: (json['imageAlignmentX'] as num?)?.toDouble() ?? 0,
      imageAlignmentY: (json['imageAlignmentY'] as num?)?.toDouble() ?? 0,
      thotPoints: (json['thotPoints'] as num?)?.toInt() ?? 100,
      setName: json['setName'] as String? ?? 'Thot Gallery Originals',
      rarityCategory: json['rarityCategory'] as String? ?? 'Standard',
      rarity: json['rarity'] as String? ?? 'Original',
      cardNumber: (json['cardNumber'] as num?)?.toInt() ?? 1,
      setTotal: (json['setTotal'] as num?)?.toInt() ?? 1,
      fingerprint: json['fingerprint'] as String? ?? '',
      views: (json['views'] as num?)?.toInt() ?? 0,
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      videoCount: (json['videoCount'] as num?)?.toInt() ?? 0,
      locationCount: (json['locationCount'] as num?)?.toInt() ?? 0,
      peopleCount: (json['peopleCount'] as num?)?.toInt() ?? 0,
      nfcEnabled: json['nfcEnabled'] as bool? ?? true,
      isRevealed: json['isRevealed'] as bool? ?? false,
      location: json['location'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      collections: List<String>.from(json['collections'] as List? ?? const []),
      participants:
          List<String>.from(json['participants'] as List? ?? const []),
      links: List<String>.from(json['links'] as List? ?? const []),
      notes: json['notes'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      lastSharedAt: DateTime.tryParse(json['lastSharedAt'] as String? ?? ''),
    );

    card.ensureFingerprint();

    if (card.media.isNotEmpty) {
      card.syncMediaCounts();
    }

    return card;
  }

  static String encodeList(List<GalleryCard> cards) {
    for (final card in cards) {
      card.ensureFingerprint();

      if (card.media.isNotEmpty) {
        card.syncMediaCounts();
      }
    }

    return jsonEncode(cards.map((card) => card.toJson()).toList());
  }

  static List<GalleryCard> decodeList(String source) {
    final data = jsonDecode(source) as List<dynamic>;

    return data
        .map((item) => GalleryCard.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
