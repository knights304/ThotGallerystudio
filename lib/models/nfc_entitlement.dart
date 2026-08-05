enum NfcEntitlementType {
  access,
  gift,
  unlock,
}

enum NfcRedemptionMode {
  unlimited,
  onePerAccount,
  oneTime,
  limited,
}

class NfcEntitlement {
  const NfcEntitlement({
    required this.id,
    required this.type,
    required this.cardId,
    required this.fingerprint,
    this.title = '',
    this.targetPackageId = '',
    this.redemptionMode = NfcRedemptionMode.unlimited,
    this.maxRedemptions,
    this.expiresAt,
    this.serialNumber,
    this.editionSize,
  });

  final String id;
  final NfcEntitlementType type;
  final String cardId;
  final String fingerprint;

  /// Friendly label shown in Creator/Viewer.
  final String title;

  /// Reserved for the future backend/package catalog.
  final String targetPackageId;

  final NfcRedemptionMode redemptionMode;
  final int? maxRedemptions;
  final DateTime? expiresAt;

  /// Optional physical-edition metadata, e.g. 17 / 100.
  final int? serialNumber;
  final int? editionSize;

  NfcEntitlement copyWith({
    String? id,
    NfcEntitlementType? type,
    String? cardId,
    String? fingerprint,
    String? title,
    String? targetPackageId,
    NfcRedemptionMode? redemptionMode,
    int? maxRedemptions,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    int? serialNumber,
    bool clearSerialNumber = false,
    int? editionSize,
    bool clearEditionSize = false,
  }) {
    return NfcEntitlement(
      id: id ?? this.id,
      type: type ?? this.type,
      cardId: cardId ?? this.cardId,
      fingerprint: fingerprint ?? this.fingerprint,
      title: title ?? this.title,
      targetPackageId: targetPackageId ?? this.targetPackageId,
      redemptionMode: redemptionMode ?? this.redemptionMode,
      maxRedemptions: maxRedemptions ?? this.maxRedemptions,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      serialNumber:
          clearSerialNumber ? null : (serialNumber ?? this.serialNumber),
      editionSize: clearEditionSize ? null : (editionSize ?? this.editionSize),
    );
  }

  bool get hasEdition =>
      serialNumber != null &&
      editionSize != null &&
      serialNumber! > 0 &&
      editionSize! > 0;

  Map<String, String> toQueryParameters() {
    final values = <String, String>{
      'entitlement': id,
      'type': type.name,
      'card': cardId,
      'fingerprint': fingerprint,
      'redemption': redemptionMode.name,
    };

    if (title.trim().isNotEmpty) {
      values['title'] = title.trim();
    }

    if (targetPackageId.trim().isNotEmpty) {
      values['package'] = targetPackageId.trim();
    }

    if (maxRedemptions != null && maxRedemptions! > 0) {
      values['max'] = maxRedemptions.toString();
    }

    if (expiresAt != null) {
      values['expires'] = expiresAt!.toUtc().toIso8601String();
    }

    if (serialNumber != null && serialNumber! > 0) {
      values['serial'] = serialNumber.toString();
    }

    if (editionSize != null && editionSize! > 0) {
      values['edition'] = editionSize.toString();
    }

    return values;
  }

  factory NfcEntitlement.fromUri(Uri uri) {
    final query = uri.queryParameters;

    final typeName = query['type'] ?? NfcEntitlementType.access.name;
    final redemptionName =
        query['redemption'] ?? NfcRedemptionMode.unlimited.name;

    return NfcEntitlement(
      id: query['entitlement'] ?? '',
      type: NfcEntitlementType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => NfcEntitlementType.access,
      ),
      cardId: query['card'] ?? '',
      fingerprint: query['fingerprint'] ?? '',
      title: query['title'] ?? '',
      targetPackageId: query['package'] ?? '',
      redemptionMode: NfcRedemptionMode.values.firstWhere(
        (value) => value.name == redemptionName,
        orElse: () => NfcRedemptionMode.unlimited,
      ),
      maxRedemptions: int.tryParse(query['max'] ?? ''),
      expiresAt: DateTime.tryParse(query['expires'] ?? ''),
      serialNumber: int.tryParse(query['serial'] ?? ''),
      editionSize: int.tryParse(query['edition'] ?? ''),
    );
  }
}
