import 'nfc_entitlement.dart';

class PhysicalCardProtocol {
  const PhysicalCardProtocol._();

  static const int version = 1;
  static const String host = 'thotgallery.app';
  static const String redeemPath = '/redeem';

  static Uri buildUri(NfcEntitlement entitlement) {
    return Uri.https(
      host,
      redeemPath,
      <String, String>{
        'v': '$version',
        ...entitlement.toQueryParameters(),
      },
    );
  }

  static PhysicalCardProtocolParseResult parse(Uri uri) {
    if (uri.scheme != 'https') {
      return const PhysicalCardProtocolParseResult.invalid(
        'Physical-card links must use HTTPS.',
      );
    }

    if (uri.host.toLowerCase() != host || uri.path != redeemPath) {
      return const PhysicalCardProtocolParseResult.invalid(
        'This is not a THOT Gallery physical-card redemption link.',
      );
    }

    final rawVersion = uri.queryParameters['v'];
    final parsedVersion = int.tryParse(rawVersion ?? '');

    if (parsedVersion == null) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Physical-card protocol version is missing.',
      );
    }

    if (parsedVersion != version) {
      return PhysicalCardProtocolParseResult.invalid(
        'Unsupported physical-card protocol version $parsedVersion.',
      );
    }

    final entitlement = NfcEntitlement.fromUri(uri);

    if (entitlement.id.trim().isEmpty) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Entitlement ID is missing.',
      );
    }

    if (entitlement.cardId.trim().isEmpty) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Card ID is missing.',
      );
    }

    if (entitlement.fingerprint.trim().isEmpty) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Card fingerprint is missing.',
      );
    }

    if (entitlement.redemptionMode == NfcRedemptionMode.limited &&
        (entitlement.maxRedemptions == null ||
            entitlement.maxRedemptions! <= 0)) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Limited redemption requires a positive maximum redemption count.',
      );
    }

    if (entitlement.hasEdition &&
        entitlement.serialNumber! > entitlement.editionSize!) {
      return const PhysicalCardProtocolParseResult.invalid(
        'Physical edition serial cannot exceed the edition size.',
      );
    }

    return PhysicalCardProtocolParseResult.valid(
      version: parsedVersion,
      entitlement: entitlement,
    );
  }
}

class PhysicalCardProtocolParseResult {
  const PhysicalCardProtocolParseResult.valid({
    required this.version,
    required this.entitlement,
  })  : isValid = true,
        errorMessage = null;

  const PhysicalCardProtocolParseResult.invalid(
    this.errorMessage,
  )   : isValid = false,
        version = null,
        entitlement = null;

  final bool isValid;
  final int? version;
  final NfcEntitlement? entitlement;
  final String? errorMessage;
}
