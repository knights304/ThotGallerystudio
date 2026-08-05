import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/physical_card_history_record.dart';

class PhysicalCardHistoryService {
  const PhysicalCardHistoryService._();

  static const _storageKey = 'physical_card_history_v1';

  static Future<List<PhysicalCardHistoryRecord>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final records = PhysicalCardHistoryRecord.decodeList(raw);
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return records;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(
    PhysicalCardHistoryRecord record,
  ) async {
    final records = List<PhysicalCardHistoryRecord>.from(await loadAll());
    final index = records.indexWhere((item) => item.id == record.id);

    if (index == -1) {
      records.insert(0, record);
    } else {
      records[index] = record;
    }

    await _write(records);
  }

  static Future<PhysicalCardHistoryRecord> duplicate(
    PhysicalCardHistoryRecord source,
  ) async {
    final now = DateTime.now();
    final newId = _generateEntitlementId(source.entitlement.cardId);

    int? nextSerial = source.entitlement.serialNumber;
    final editionSize = source.entitlement.editionSize;

    if (nextSerial != null) {
      final candidate = nextSerial + 1;
      if (editionSize == null || candidate <= editionSize) {
        nextSerial = candidate;
      }
    }

    final entitlement = source.entitlement.copyWith(
      id: newId,
      serialNumber: nextSerial,
    );

    final uri = Uri.https(
      'thotgallery.app',
      '/redeem',
      entitlement.toQueryParameters(),
    ).toString();

    final duplicate = PhysicalCardHistoryRecord(
      id: newId,
      createdAt: now,
      updatedAt: now,
      entitlement: entitlement,
      redemptionUri: uri,
      sourceCardTitle: source.sourceCardTitle,
      sourceCardRarity: source.sourceCardRarity,
    );

    await save(duplicate);
    return duplicate;
  }

  static Future<void> delete(String id) async {
    final records = List<PhysicalCardHistoryRecord>.from(await loadAll())
      ..removeWhere((item) => item.id == id);

    await _write(records);
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  static String _generateEntitlementId(String cardId) {
    final random = Random.secure();
    final token = List<int>.generate(
      8,
      (_) => random.nextInt(256),
    )
        .map(
          (value) => value.toRadixString(16).padLeft(2, '0'),
        )
        .join()
        .toUpperCase();

    final safeCardId =
        cardId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    return 'NFC-${safeCardId.isEmpty ? 'CARD' : safeCardId}-$token';
  }

  static Future<void> _write(
    List<PhysicalCardHistoryRecord> records,
  ) async {
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      PhysicalCardHistoryRecord.encodeList(records),
    );
  }
}
