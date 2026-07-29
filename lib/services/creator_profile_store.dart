import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/creator_profile.dart';

class CreatorProfileStore extends ChangeNotifier {
  static const _key = 'creator_profiles_v1';
  final List<CreatorProfile> _profiles = [];

  List<CreatorProfile> get profiles => List.unmodifiable(_profiles);
  CreatorProfile? get defaultProfile {
    for (final profile in _profiles) {
      if (profile.isDefault) return profile;
    }
    return _profiles.isEmpty ? null : _profiles.first;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _profiles.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        _profiles.addAll(CreatorProfile.decodeList(raw));
      } catch (_) {}
    }
    if (_profiles.isEmpty) {
      _profiles.add(CreatorProfile(
        id: 'creator-default',
        displayName: 'Thot Gallery Creator',
        handle: '@thotgallery',
        bio: 'Collector, curator, and creator of living Gallery Pieces.',
        signature: 'Your Guilty Pleasure',
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await _save();
    }
    notifyListeners();
  }

  Future<void> upsert(CreatorProfile profile) async {
    profile.updatedAt = DateTime.now();
    profile.createdAt ??= DateTime.now();
    if (profile.isDefault) {
      for (final item in _profiles) {
        item.isDefault = item.id == profile.id;
      }
    }
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }
    await _save();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    if (_profiles.length <= 1) return;
    final wasDefault = _profiles.any((p) => p.id == id && p.isDefault);
    _profiles.removeWhere((profile) => profile.id == id);
    if (wasDefault && _profiles.isNotEmpty) _profiles.first.isDefault = true;
    await _save();
    notifyListeners();
  }

  Future<void> setDefault(String id) async {
    for (final profile in _profiles) {
      profile.isDefault = profile.id == id;
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, CreatorProfile.encodeList(_profiles));
  }
}
