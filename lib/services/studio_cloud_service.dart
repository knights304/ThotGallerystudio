import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class StudioCloudException implements Exception {
  const StudioCloudException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class StudioCloudProfile {
  const StudioCloudProfile({
    required this.id,
    required this.username,
    required this.displayName,
    required this.profileType,
    required this.active,
    this.avatarKey,
    this.bio = '',
  });

  final String id;
  final String username;
  final String displayName;
  final String profileType;
  final bool active;
  final String? avatarKey;
  final String bio;

  bool get isViewer => profileType == 'viewer';
  bool get isStudio => profileType == 'studio';

  factory StudioCloudProfile.fromJson(Map<String, dynamic> json) {
    return StudioCloudProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      profileType: json['profileType'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      avatarKey: json['avatarKey'] as String?,
      bio: json['bio'] as String? ?? '',
    );
  }
}

class StudioCloudDelivery {
  const StudioCloudDelivery({
    required this.id,
    required this.cardId,
    required this.packageKey,
    required this.status,
    required this.createdAt,
    required this.sender,
    required this.recipient,
    this.openedAt,
    this.respondedAt,
  });

  final String id;
  final String cardId;
  final String packageKey;
  final String status;
  final DateTime createdAt;
  final DateTime? openedAt;
  final DateTime? respondedAt;
  final StudioCloudProfile sender;
  final StudioCloudProfile recipient;

  factory StudioCloudDelivery.fromJson(Map<String, dynamic> json) {
    return StudioCloudDelivery(
      id: json['id'] as String? ?? '',
      cardId: json['cardId'] as String? ?? '',
      packageKey: json['packageKey'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      openedAt: DateTime.tryParse(json['openedAt'] as String? ?? ''),
      respondedAt: DateTime.tryParse(
        json['respondedAt'] as String? ?? '',
      ),
      sender: StudioCloudProfile.fromJson(
        Map<String, dynamic>.from(
          json['sender'] as Map? ?? const {},
        ),
      ),
      recipient: StudioCloudProfile.fromJson(
        Map<String, dynamic>.from(
          json['recipient'] as Map? ?? const {},
        ),
      ),
    );
  }
}

class StudioCloudResponse {
  const StudioCloudResponse({
    required this.id,
    required this.deliveryId,
    required this.cardId,
    required this.overallRating,
    required this.overallComment,
    required this.favoriteMediaIds,
    required this.createdAt,
    required this.responder,
    this.videoReplyKey,
    this.responsePackageKey,
  });

  final String id;
  final String deliveryId;
  final String cardId;
  final double overallRating;
  final String overallComment;
  final List<String> favoriteMediaIds;
  final DateTime createdAt;
  final StudioCloudProfile responder;
  final String? videoReplyKey;
  final String? responsePackageKey;

  factory StudioCloudResponse.fromJson(Map<String, dynamic> json) {
    return StudioCloudResponse(
      id: json['id'] as String? ?? '',
      deliveryId: json['deliveryId'] as String? ?? '',
      cardId: json['cardId'] as String? ?? '',
      overallRating: (json['overallRating'] as num?)?.toDouble() ?? 0.0,
      overallComment: json['overallComment'] as String? ?? '',
      favoriteMediaIds: (json['favoriteMediaIds'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      responder: StudioCloudProfile.fromJson(
        Map<String, dynamic>.from(
          json['responder'] as Map? ?? const {},
        ),
      ),
      videoReplyKey: json['videoReplyKey'] as String?,
      responsePackageKey: json['responsePackageKey'] as String?,
    );
  }
}

class StudioCloudUpload {
  const StudioCloudUpload({
    required this.cardId,
    required this.packageKey,
    required this.size,
  });

  final String cardId;
  final String packageKey;
  final int size;
}

class StudioCloudService {
  StudioCloudService._();

  static final StudioCloudService instance = StudioCloudService._();

  static const String baseUrl =
      'https://thot-gallery-cloud.thot2thoughts.workers.dev';

  static const String _tokenStorageKey = 'thot_gallery_cloud_studio_token';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _cachedToken;

  Future<String?> get token async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    final stored = await _secureStorage.read(
      key: _tokenStorageKey,
    );

    if (stored != null && stored.isNotEmpty) {
      _cachedToken = stored;
    }

    return stored;
  }

  Future<bool> get isAuthenticated async {
    final value = await token;
    return value != null && value.isNotEmpty;
  }

  Future<void> saveDeviceToken(String value) async {
    final normalized = value.trim();

    if (!normalized.startsWith('tga_')) {
      throw const StudioCloudException(
        'Invalid THOT Gallery device token.',
      );
    }

    await _secureStorage.write(
      key: _tokenStorageKey,
      value: normalized,
    );

    _cachedToken = normalized;
  }

  Future<void> clearDeviceToken() async {
    await _secureStorage.delete(key: _tokenStorageKey);
    _cachedToken = null;
  }

  Future<Map<String, String>> _authorizedHeaders({
    String? contentType = 'application/json',
  }) async {
    final authToken = await token;

    if (authToken == null || authToken.isEmpty) {
      throw const StudioCloudException(
        'Studio is not connected to a THOT Gallery cloud profile.',
        statusCode: 401,
      );
    }

    return <String, String>{
      'Authorization': 'Bearer $authToken',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw StudioCloudException(
        'Cloud service returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map) {
      throw StudioCloudException(
        'Cloud service returned an invalid response.',
        statusCode: response.statusCode,
      );
    }

    final object = Map<String, dynamic>.from(decoded);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudioCloudException(
        object['error'] as String? ??
            'Cloud request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (object['ok'] != true) {
      throw StudioCloudException(
        object['error'] as String? ?? 'Cloud request failed.',
        statusCode: response.statusCode,
      );
    }

    return object;
  }

  Future<StudioCloudProfile> register({
    required String username,
    required String displayName,
    required String recoveryEmail,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'username': username.trim(),
          'displayName': displayName.trim(),
          'recoveryEmail': recoveryEmail.trim().toLowerCase(),
          'profileType': 'studio',
          'pin': pin.trim(),
          'deviceLabel': 'studio-device',
        },
      ),
    );

    final object = _decodeObject(response);

    final rawToken = object['token'] as String? ?? '';

    if (rawToken.isEmpty) {
      throw const StudioCloudException(
        'Registration did not return a device token.',
      );
    }

    await saveDeviceToken(rawToken);

    return StudioCloudProfile.fromJson(
      Map<String, dynamic>.from(
        object['profile'] as Map,
      ),
    );
  }

  Future<StudioCloudProfile> login({
    required String username,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'username': username.trim(),
          'pin': pin.trim(),
          'deviceLabel': 'studio-device',
        },
      ),
    );

    final object = _decodeObject(response);

    final rawToken = object['token'] as String? ?? '';

    if (rawToken.isEmpty) {
      throw const StudioCloudException(
        'Login did not return a device token.',
      );
    }

    await saveDeviceToken(rawToken);

    return StudioCloudProfile.fromJson(
      Map<String, dynamic>.from(
        object['profile'] as Map,
      ),
    );
  }

  Future<StudioCloudProfile> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: await _authorizedHeaders(contentType: null),
    );

    final object = _decodeObject(response);

    return StudioCloudProfile.fromJson(
      Map<String, dynamic>.from(object['profile'] as Map),
    );
  }

  Future<List<StudioCloudProfile>> searchProfiles(
    String query,
  ) async {
    final normalized = query.trim();

    if (normalized.length < 2) {
      return const [];
    }

    final uri = Uri.parse('$baseUrl/profiles/search').replace(
      queryParameters: <String, String>{
        'q': normalized,
      },
    );

    final response = await http.get(uri);
    final object = _decodeObject(response);

    return (object['profiles'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => StudioCloudProfile.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<List<StudioCloudDelivery>> getInbox() async {
    final response = await http.get(
      Uri.parse('$baseUrl/rate-me/inbox'),
      headers: await _authorizedHeaders(contentType: null),
    );

    final object = _decodeObject(response);

    return (object['deliveries'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => StudioCloudDelivery.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<List<StudioCloudDelivery>> getSent() async {
    final response = await http.get(
      Uri.parse('$baseUrl/rate-me/sent'),
      headers: await _authorizedHeaders(contentType: null),
    );

    final object = _decodeObject(response);

    return (object['deliveries'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => StudioCloudDelivery.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<StudioCloudUpload> uploadRateMePackage({
    required String cardId,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw const StudioCloudException(
        'Rate Me package does not exist.',
      );
    }

    final response = await http.post(
      Uri.parse('$baseUrl/rate-me/packages').replace(
        queryParameters: <String, String>{
          'cardId': cardId,
        },
      ),
      headers: await _authorizedHeaders(
        contentType: 'application/octet-stream',
      ),
      body: await file.readAsBytes(),
    );

    final object = _decodeObject(response);

    return StudioCloudUpload(
      cardId: object['cardId'] as String? ?? cardId,
      packageKey: object['packageKey'] as String? ?? '',
      size: (object['size'] as num?)?.toInt() ?? 0,
    );
  }

  Future<StudioCloudDelivery> sendRateMe({
    required String recipientProfileId,
    required String cardId,
    required String packageKey,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rate-me/deliveries'),
      headers: await _authorizedHeaders(),
      body: jsonEncode(
        <String, dynamic>{
          'recipientProfileId': recipientProfileId,
          'cardId': cardId,
          'packageKey': packageKey,
        },
      ),
    );

    final object = _decodeObject(response);

    return StudioCloudDelivery.fromJson(
      Map<String, dynamic>.from(
        object['delivery'] as Map,
      ),
    );
  }

  Future<Uint8List> downloadRateMePackage(
    String deliveryId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/rate-me/deliveries/$deliveryId/package',
      ),
      headers: await _authorizedHeaders(contentType: null),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StudioCloudException(
        'Unable to download Rate Me package.',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  Future<StudioCloudDelivery> markOpened(
    String deliveryId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/rate-me/deliveries/$deliveryId/open',
      ),
      headers: await _authorizedHeaders(contentType: null),
    );

    final object = _decodeObject(response);

    return StudioCloudDelivery.fromJson(
      Map<String, dynamic>.from(
        object['delivery'] as Map,
      ),
    );
  }

  Future<String> uploadResponsePackage({
    required String deliveryId,
    required File file,
  }) async {
    if (!await file.exists()) {
      throw const StudioCloudException(
        'Rate Me response package does not exist.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$baseUrl/rate-me/deliveries/'
        '$deliveryId/response-package',
      ),
      headers: await _authorizedHeaders(
        contentType: 'application/octet-stream',
      ),
      body: await file.readAsBytes(),
    );

    final object = _decodeObject(response);

    return object['responsePackageKey'] as String? ?? '';
  }

  Future<void> submitResponse({
    required String deliveryId,
    required double overallRating,
    String overallComment = '',
    List<String> favoriteMediaIds = const [],
    String? responsePackageKey,
    String? videoReplyKey,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/rate-me/deliveries/$deliveryId/response',
      ),
      headers: await _authorizedHeaders(),
      body: jsonEncode(
        <String, dynamic>{
          'overallRating': overallRating,
          'overallComment': overallComment,
          'favoriteMediaIds': favoriteMediaIds,
          if (responsePackageKey != null)
            'responsePackageKey': responsePackageKey,
          if (videoReplyKey != null) 'videoReplyKey': videoReplyKey,
        },
      ),
    );

    _decodeObject(response);
  }

  Future<List<StudioCloudResponse>> getResponseInbox() async {
    final response = await http.get(
      Uri.parse('$baseUrl/rate-me/responses/inbox'),
      headers: await _authorizedHeaders(contentType: null),
    );

    final object = _decodeObject(response);

    return (object['responses'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => StudioCloudResponse.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<void> archiveDelivery(String deliveryId) async {
    final normalized = deliveryId.trim();

    if (normalized.isEmpty) {
      throw const StudioCloudException('Delivery ID is required.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/rate-me/deliveries/$normalized/archive'),
      headers: await _authorizedHeaders(contentType: null),
    );

    _decodeObject(response);
  }

  Future<void> deleteCloudResponse(String responseId) async {
    final normalized = responseId.trim();

    if (normalized.isEmpty) {
      throw const StudioCloudException('Response ID is required.');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/rate-me/responses/$normalized'),
      headers: await _authorizedHeaders(contentType: null),
    );

    _decodeObject(response);
  }
}
