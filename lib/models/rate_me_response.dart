class StudioRateMeResponse {
  const StudioRateMeResponse({
    required this.cardId,
    required this.responderId,
    required this.responderName,
    required this.overallRating,
    required this.overallComment,
    this.favoriteMediaIds = const [],
    this.photoReplyPath,
    this.videoReplyPath,
    this.voiceReplyPath,
    required this.createdAt,
  });

  /// ID of the Rate Me card this response belongs to.
  final String cardId;

  /// Stable ID for the Viewer or Studio user who submitted it.
  final String responderId;

  /// Name shown to the owner of the Rate Me card.
  final String responderName;

  /// Overall score for the whole card from 1 through 5.
  final double overallRating;

  /// Written response for the complete card.
  final String overallComment;

  /// IDs of photos/videos selected as favorites.
  final List<String> favoriteMediaIds;

  /// Optional photo response.
  final String? photoReplyPath;

  /// Optional video response.
  final String? videoReplyPath;

  /// Optional recorded voice response.
  final String? voiceReplyPath;

  /// Time the response was created.
  final DateTime createdAt;

  bool get hasRating => overallRating >= 0.5 && overallRating <= 5.0;

  bool get hasComment => overallComment.trim().isNotEmpty;

  bool get hasPhotoReply =>
      photoReplyPath != null && photoReplyPath!.trim().isNotEmpty;

  bool get hasVideoReply =>
      videoReplyPath != null && videoReplyPath!.trim().isNotEmpty;

  bool get hasVoiceReply =>
      voiceReplyPath != null && voiceReplyPath!.trim().isNotEmpty;

  bool get hasFavorites => favoriteMediaIds.isNotEmpty;

  bool get hasAttachments => hasPhotoReply || hasVideoReply || hasVoiceReply;

  bool get hasAnyFeedback =>
      hasRating || hasComment || hasFavorites || hasAttachments;

  StudioRateMeResponse copyWith({
    String? cardId,
    String? responderId,
    String? responderName,
    double? overallRating,
    String? overallComment,
    List<String>? favoriteMediaIds,
    String? photoReplyPath,
    bool clearPhotoReply = false,
    String? videoReplyPath,
    bool clearVideoReply = false,
    String? voiceReplyPath,
    bool clearVoiceReply = false,
    DateTime? createdAt,
  }) {
    return StudioRateMeResponse(
      cardId: cardId ?? this.cardId,
      responderId: responderId ?? this.responderId,
      responderName: responderName ?? this.responderName,
      overallRating: overallRating ?? this.overallRating,
      overallComment: overallComment ?? this.overallComment,
      favoriteMediaIds: favoriteMediaIds ?? this.favoriteMediaIds,
      photoReplyPath:
          clearPhotoReply ? null : photoReplyPath ?? this.photoReplyPath,
      videoReplyPath:
          clearVideoReply ? null : videoReplyPath ?? this.videoReplyPath,
      voiceReplyPath:
          clearVoiceReply ? null : voiceReplyPath ?? this.voiceReplyPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cardId': cardId,
      'responderId': responderId,
      'responderName': responderName,
      'overallRating': overallRating,
      'overallComment': overallComment,
      'favoriteMediaIds': favoriteMediaIds,
      'photoReplyPath': photoReplyPath,
      'videoReplyPath': videoReplyPath,
      'voiceReplyPath': voiceReplyPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudioRateMeResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final favoriteIds = (json['favoriteMediaIds'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    return StudioRateMeResponse(
      cardId: (json['cardId'] as String?)?.trim() ?? '',
      responderId: (json['responderId'] as String?)?.trim() ?? '',
      responderName: (json['responderName'] as String?)?.trim() ?? '',
      overallRating: _readRating(json['overallRating']),
      overallComment: json['overallComment'] as String? ?? '',
      favoriteMediaIds: List<String>.unmodifiable(favoriteIds),
      photoReplyPath: _readOptionalString(json['photoReplyPath']),
      videoReplyPath: _readOptionalString(json['videoReplyPath']),
      voiceReplyPath: _readOptionalString(json['voiceReplyPath']),
      createdAt: _readDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

double _readRating(Object? value) {
  final rating = switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text) ?? 0.0,
    _ => 0.0,
  };

  return rating.clamp(0.0, 5.0).toDouble();
}

String? _readOptionalString(Object? value) {
  if (value is! String) {
    return null;
  }

  final text = value.trim();

  return text.isEmpty ? null : text;
}

DateTime? _readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
