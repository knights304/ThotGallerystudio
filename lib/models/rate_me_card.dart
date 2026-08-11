enum StudioRateMeMediaType {
  photo,
  video,
}

class StudioRateMeOwner {
  const StudioRateMeOwner({
    required this.type,
    required this.id,
    required this.displayName,
  });

  final String type;
  final String id;
  final String displayName;

  StudioRateMeOwner copyWith({
    String? type,
    String? id,
    String? displayName,
  }) {
    return StudioRateMeOwner(
      type: type ?? this.type,
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'displayName': displayName,
    };
  }

  factory StudioRateMeOwner.fromJson(Map<String, dynamic> json) {
    return StudioRateMeOwner(
      type: (json['type'] as String?)?.trim().isNotEmpty == true
          ? (json['type'] as String).trim()
          : 'studio',
      id: (json['id'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
    );
  }
}

class StudioRateMeResponseTarget {
  const StudioRateMeResponseTarget({
    this.mode = 'file',
    this.url,
  });

  final String mode;
  final String? url;

  StudioRateMeResponseTarget copyWith({
    String? mode,
    String? url,
    bool clearUrl = false,
  }) {
    return StudioRateMeResponseTarget(
      mode: mode ?? this.mode,
      url: clearUrl ? null : url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      if (url != null && url!.trim().isNotEmpty) 'url': url,
    };
  }

  factory StudioRateMeResponseTarget.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawMode = (json['mode'] as String?)?.trim();

    return StudioRateMeResponseTarget(
      mode: rawMode == null || rawMode.isEmpty ? 'file' : rawMode,
      url: (json['url'] as String?)?.trim(),
    );
  }
}

class StudioRateMeMedia {
  const StudioRateMeMedia({
    required this.id,
    required this.path,
    required this.type,
    this.caption = '',
    this.question = '',
    this.createdAt,
  });

  final String id;
  final String path;
  final StudioRateMeMediaType type;

  /// Optional label shown with this photo or video.
  final String caption;

  /// Optional prompt shown to the person viewing the Rate Me card.
  ///
  /// Version 2 responses use one overall rating and comment, but this field
  /// remains useful as lightweight context for individual media.
  final String question;

  final DateTime? createdAt;

  StudioRateMeMedia copyWith({
    String? id,
    String? path,
    StudioRateMeMediaType? type,
    String? caption,
    String? question,
    DateTime? createdAt,
  }) {
    return StudioRateMeMedia(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      caption: caption ?? this.caption,
      question: question ?? this.question,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'type': type.name,
      'caption': caption,
      'question': question,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory StudioRateMeMedia.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;

    return StudioRateMeMedia(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      path: json['path'] as String? ?? '',
      type: StudioRateMeMediaType.values.firstWhere(
        (value) => value.name == rawType,
        orElse: () => StudioRateMeMediaType.photo,
      ),
      caption: json['caption'] as String? ?? '',
      question: json['question'] as String? ?? '',
      createdAt: _tryDate(json['createdAt']),
    );
  }
}

class StudioRateMeCard {
  const StudioRateMeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    this.responseTarget = const StudioRateMeResponseTarget(),
    this.coverImagePath,
    this.media = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String description;

  /// Identifies whether this card belongs to Studio or a Viewer.
  final StudioRateMeOwner owner;

  /// `file` keeps the current offline .tgrateresponse workflow.
  /// A future cloud card can use `cloud` with a URL.
  final StudioRateMeResponseTarget responseTarget;

  final String? coverImagePath;
  final List<StudioRateMeMedia> media;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasMedia => media.isNotEmpty;

  int get photoCount =>
      media.where((item) => item.type == StudioRateMeMediaType.photo).length;

  int get videoCount =>
      media.where((item) => item.type == StudioRateMeMediaType.video).length;

  StudioRateMeCard copyWith({
    String? id,
    String? title,
    String? description,
    StudioRateMeOwner? owner,
    StudioRateMeResponseTarget? responseTarget,
    String? coverImagePath,
    bool clearCoverImage = false,
    List<StudioRateMeMedia>? media,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudioRateMeCard(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      responseTarget: responseTarget ?? this.responseTarget,
      coverImagePath:
          clearCoverImage ? null : coverImagePath ?? this.coverImagePath,
      media: media ?? this.media,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'owner': owner.toJson(),
      'responseTarget': responseTarget.toJson(),
      'coverImagePath': coverImagePath,
      'media': media.map((item) => item.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory StudioRateMeCard.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    final targetJson = json['responseTarget'];
    final rawMedia = json['media'];

    return StudioRateMeCard(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Rate Me',
      description: json['description'] as String? ?? '',
      owner: ownerJson is Map
          ? StudioRateMeOwner.fromJson(
              Map<String, dynamic>.from(ownerJson),
            )
          : const StudioRateMeOwner(
              type: 'studio',
              id: '',
              displayName: '',
            ),
      responseTarget: targetJson is Map
          ? StudioRateMeResponseTarget.fromJson(
              Map<String, dynamic>.from(targetJson),
            )
          : const StudioRateMeResponseTarget(),
      coverImagePath: json['coverImagePath'] as String?,
      media: rawMedia is List
          ? rawMedia
              .whereType<Map>()
              .map(
                (item) => StudioRateMeMedia.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      createdAt: _tryDate(json['createdAt']),
      updatedAt: _tryDate(json['updatedAt']),
    );
  }
}

DateTime? _tryDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
