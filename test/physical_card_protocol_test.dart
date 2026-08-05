import 'package:flutter_test/flutter_test.dart';

import 'package:thot_gallery_creator/models/nfc_entitlement.dart';
import 'package:thot_gallery_creator/models/physical_card_protocol.dart';

void main() {
  group('PhysicalCardProtocol v1', () {
    test('round-trips a valid gift entitlement', () {
      final entitlement = NfcEntitlement(
        id: 'NFC-TG000001-ABC123',
        type: NfcEntitlementType.gift,
        cardId: 'TG-000001',
        fingerprint:
            '5F4CCC6641540F64B75A32226C2694997EFA1B813BA248E769941F6108129EDA',
        title: 'Rare Card Gift',
        targetPackageId: 'EATER',
        redemptionMode: NfcRedemptionMode.oneTime,
        serialNumber: 17,
        editionSize: 100,
      );

      final uri = PhysicalCardProtocol.buildUri(entitlement);
      final parsed = PhysicalCardProtocol.parse(uri);

      expect(parsed.isValid, isTrue);
      expect(parsed.version, PhysicalCardProtocol.version);
      expect(parsed.entitlement, isNotNull);

      final decoded = parsed.entitlement!;
      expect(decoded.id, entitlement.id);
      expect(decoded.type, entitlement.type);
      expect(decoded.cardId, entitlement.cardId);
      expect(decoded.fingerprint, entitlement.fingerprint);
      expect(decoded.title, entitlement.title);
      expect(decoded.targetPackageId, entitlement.targetPackageId);
      expect(decoded.redemptionMode, entitlement.redemptionMode);
      expect(decoded.serialNumber, 17);
      expect(decoded.editionSize, 100);
    });

    test('rejects wrong host', () {
      final uri = Uri.parse(
        'https://example.com/redeem'
        '?v=1'
        '&entitlement=NFC-TEST'
        '&type=access'
        '&card=TG-000001'
        '&fingerprint=ABC'
        '&redemption=unlimited',
      );

      final parsed = PhysicalCardProtocol.parse(uri);

      expect(parsed.isValid, isFalse);
      expect(parsed.entitlement, isNull);
    });

    test('rejects unsupported protocol version', () {
      final uri = Uri.parse(
        'https://thotgallery.app/redeem'
        '?v=99'
        '&entitlement=NFC-TEST'
        '&type=access'
        '&card=TG-000001'
        '&fingerprint=ABC'
        '&redemption=unlimited',
      );

      final parsed = PhysicalCardProtocol.parse(uri);

      expect(parsed.isValid, isFalse);
      expect(parsed.errorMessage, contains('Unsupported'));
    });

    test('rejects limited redemption without a positive max', () {
      final uri = Uri.parse(
        'https://thotgallery.app/redeem'
        '?v=1'
        '&entitlement=NFC-TEST'
        '&type=gift'
        '&card=TG-000001'
        '&fingerprint=ABC'
        '&redemption=limited'
        '&max=0',
      );

      final parsed = PhysicalCardProtocol.parse(uri);

      expect(parsed.isValid, isFalse);
      expect(parsed.errorMessage, contains('positive maximum'));
    });

    test('rejects edition serial larger than edition size', () {
      final uri = Uri.parse(
        'https://thotgallery.app/redeem'
        '?v=1'
        '&entitlement=NFC-TEST'
        '&type=gift'
        '&card=TG-000001'
        '&fingerprint=ABC'
        '&redemption=unlimited'
        '&serial=101'
        '&edition=100',
      );

      final parsed = PhysicalCardProtocol.parse(uri);

      expect(parsed.isValid, isFalse);
      expect(parsed.errorMessage, contains('serial'));
    });
  });
}
