import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gallery_card.dart';
import '../models/signature_profile.dart';
import 'media_vault_service.dart';

class GalleryStore extends ChangeNotifier {
  static const _legacyCardsKey = 'gallery_cards_v1';
  static const _profileKey = 'signature_profile_v1';

  GalleryStore({MediaVaultService? vault})
      : _vault = vault ?? MediaVaultService();

  final MediaVaultService _vault;
  final List<GalleryCard> _cards = [];
  SignatureProfile _profile = SignatureProfile();

  List<GalleryCard> get cards => List.unmodifiable(_cards);
  List<GalleryCard> get drafts => _cards
      .where((card) => card.status == GalleryCardStatus.idea)
      .toList(growable: false);
  List<GalleryCard> get published => _cards
      .where((card) => card.status != GalleryCardStatus.idea)
      .toList(growable: false);
  List<GalleryCard> get favorites =>
      _cards.where((card) => card.isFavorite).toList(growable: false);

  List<String> get collections {
    final values = <String>{};
    for (final card in _cards) {
      values.addAll(card.collections.where((item) => item.trim().isNotEmpty));
    }
    final list = values.toList()..sort();
    return list;
  }

  SignatureProfile get profile => _profile;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final profileJson = preferences.getString(_profileKey);

    try {
      if (profileJson != null && profileJson.isNotEmpty) {
        _profile = SignatureProfile.decode(profileJson);
      }
    } catch (_) {
      _profile = SignatureProfile();
    }

    _cards
      ..clear()
      ..addAll(await _vault.loadAll());

    if (_cards.isEmpty) {
      final legacy = preferences.getString(_legacyCardsKey);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          final oldCards = GalleryCard.decodeList(legacy);
          for (final card in oldCards) {
            await _vault.savePiece(card);
          }
          _cards.addAll(oldCards);
        } catch (_) {}
      }
    }

    _sort();
    notifyListeners();
  }

  String nextCardId() {
    var highest = 0;
    final pattern = RegExp(r'^TG-(\d+)$');
    for (final card in _cards) {
      final match = pattern.firstMatch(card.id);
      if (match != null) {
        highest = highest < int.parse(match.group(1)!)
            ? int.parse(match.group(1)!)
            : highest;
      }
    }
    return 'TG-${(highest + 1).toString().padLeft(6, '0')}';
  }

  Future<void> saveProfile(SignatureProfile profile) async {
    _profile = profile;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, profile.encode());
    notifyListeners();
  }

  Future<void> upsertCard(GalleryCard card) async {
    final index = _cards.indexWhere((item) => item.id == card.id);
    card.updatedAt = DateTime.now();
    card.createdAt ??= DateTime.now();
    card.ensureFingerprint();
    card.syncMediaCounts();

    final saved = await _vault.savePiece(card);
    if (index == -1) {
      _cards.insert(0, saved);
    } else {
      _cards[index] = saved;
    }
    _sort();
    notifyListeners();
  }

  Future<void> recordView(String id) async {
    final card = _find(id);
    if (card == null) return;
    card.views += 1;
    await upsertCard(card);
  }

  Future<void> recordShare(String id) async {
    final card = _find(id);
    if (card == null) return;
    card.shareCount += 1;
    card.lastSharedAt = DateTime.now();
    await upsertCard(card);
  }

  Future<void> deleteCard(String id) async {
    _cards.removeWhere((card) => card.id == id);
    await _vault.deletePiece(id);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final card = _find(id);
    if (card == null) return;
    card.isFavorite = !card.isFavorite;
    await upsertCard(card);
  }

  Future<void> duplicateCard(GalleryCard source) async {
    final copiedCard = GalleryCard.fromJson(source.toJson())
      ..title = '${source.title} Copy'
      ..isFavorite = false
      ..views = 0
      ..shareCount = 0
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    final fresh = GalleryCard(
      id: nextCardId(),
      title: copiedCard.title,
      type: copiedCard.type,
      status: GalleryCardStatus.idea,
      template: copiedCard.template,
      description: copiedCard.description,
      coverImagePath: copiedCard.coverImagePath,
      media: copiedCard.media
          .map((item) => GalleryMediaItem.fromJson(item.toJson()))
          .toList(),
      imageFit: copiedCard.imageFit,
      imageAlignmentX: copiedCard.imageAlignmentX,
      imageAlignmentY: copiedCard.imageAlignmentY,
      thotPoints: copiedCard.thotPoints,
      setName: copiedCard.setName,
      rarityCategory: copiedCard.rarityCategory,
      rarity: copiedCard.rarity,
      cardNumber: copiedCard.cardNumber,
      setTotal: copiedCard.setTotal,
      photoCount: copiedCard.photoCount,
      videoCount: copiedCard.videoCount,
      locationCount: copiedCard.locationCount,
      peopleCount: copiedCard.peopleCount,
      nfcEnabled: copiedCard.nfcEnabled,
      location: copiedCard.location,
      date: copiedCard.date,
      rating: copiedCard.rating,
      tags: List.of(copiedCard.tags),
      collections: List.of(copiedCard.collections),
      participants: List.of(copiedCard.participants),
      links: List.of(copiedCard.links),
      notes: copiedCard.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await upsertCard(fresh);
  }

  GalleryCard? _find(String id) {
    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  void _sort() {
    _cards.sort(
        (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(2000)).compareTo(
              a.updatedAt ?? a.createdAt ?? DateTime(2000),
            ));
  }
}
