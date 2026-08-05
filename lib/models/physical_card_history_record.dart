import 'dart:convert';

import 'nfc_entitlement.dart';

class PhysicalCardHistoryRecord {
  const PhysicalCardHistoryRecord({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.entitlement,
    required this.redemptionUri,
    this.sourceCardTitle = '',
    this.sourceCardRarity = '',
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NfcEntitlement entitlement;
  final String redemptionUri;
  final String sourceCardTitle;
  final String sourceCardRarity;

  PhysicalCardHistoryRecord copyWith({
    DateTime? updatedAt,
    NfcEntitlement? entitlement,
    String? redemptionUri,
    String? sourceCardTitle,
    String? sourceCardRarity,
  }) {
    return PhysicalCardHistoryRecord(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entitlement: entitlement ?? this.entitlement,
      redemptionUri: redemptionUri ?? this.redemptionUri,
      sourceCardTitle: sourceCardTitle ?? this.sourceCardTitle,
      sourceCardRarity: sourceCardRarity ?? this.sourceCardRarity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'entitlement': {
          'id': entitlement.id,
          'type': entitlement.type.name,
          'cardId': entitlement.cardId,
          'fingerprint': entitlement.fingerprint,
          'title': entitlement.title,
          'targetPackageId': entitlement.targetPackageId,
          'redemptionMode': entitlement.redemptionMode.name,
          'maxRedemptions': entitlement.maxRedemptions,
          'expiresAt': entitlement.expiresAt?.toIso8601String(),
          'serialNumber': entitlement.serialNumber,
          'editionSize': entitlement.editionSize,
        },
        'redemptionUri': redemptionUri,
        'sourceCardTitle': sourceCardTitle,
        'sourceCardRarity': sourceCardRarity,
      };

  factory PhysicalCardHistoryRecord.fromJson(Map<String, dynamic> json) {
    final rawEntitlement = Map<String, dynamic>.from(
      json['entitlement'] as Map? ?? const {},
    );

    final typeName =
        rawEntitlement['type'] as String? ?? NfcEntitlementType.access.name;
    final redemptionName = rawEntitlement['redemptionMode'] as String? ??
        NfcRedemptionMode.unlimited.name;

    final entitlement = NfcEntitlement(
      id: rawEntitlement['id'] as String? ?? '',
      type: NfcEntitlementType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => NfcEntitlementType.access,
      ),
      cardId: rawEntitlement['cardId'] as String? ?? '',
      fingerprint: rawEntitlement['fingerprint'] as String? ?? '',
      title: rawEntitlement['title'] as String? ?? '',
      targetPackageId: rawEntitlement['targetPackageId'] as String? ?? '',
      redemptionMode: NfcRedemptionMode.values.firstWhere(
        (value) => value.name == redemptionName,
        orElse: () => NfcRedemptionMode.unlimited,
      ),
      maxRedemptions: (rawEntitlement['maxRedemptions'] as num?)?.toInt(),
      expiresAt: DateTime.tryParse(
        rawEntitlement['expiresAt'] as String? ?? '',
      ),
      serialNumber: (rawEntitlement['serialNumber'] as num?)?.toInt(),
      editionSize: (rawEntitlement['editionSize'] as num?)?.toInt(),
    );

    final now = DateTime.now();

    return PhysicalCardHistoryRecord(
      id: json['id'] as String? ?? entitlement.id,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      entitlement: entitlement,
      redemptionUri: json['redemptionUri'] as String? ?? '',
      sourceCardTitle: json['sourceCardTitle'] as String? ?? '',
      sourceCardRarity: json['sourceCardRarity'] as String? ?? '',
    );
  }

  static String encodeList(List<PhysicalCardHistoryRecord> records) {
    return jsonEncode(records.map((record) => record.toJson()).toList());
  }

  static List<PhysicalCardHistoryRecord> decodeList(String source) {
    final decoded = jsonDecode(source);

    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => PhysicalCardHistoryRecord.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
}
