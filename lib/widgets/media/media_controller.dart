import 'package:flutter/foundation.dart';

import '../../models/gallery_card.dart';

class MediaController extends ChangeNotifier {
  MediaController({
    required List<GalleryMediaItem> media,
    String? selectedMediaId,
  })  : _media = List<GalleryMediaItem>.from(media),
        _selectedMediaId = selectedMediaId;

  List<GalleryMediaItem> _media;
  String? _selectedMediaId;
  String? _draggedMediaId;

  List<GalleryMediaItem> get media =>
      List<GalleryMediaItem>.unmodifiable(_media);

  String? get selectedMediaId => _selectedMediaId;
  String? get draggedMediaId => _draggedMediaId;

  int get totalCount => _media.length;

  int get photoCount => _media
      .where((item) => item.type == GalleryMediaType.photo)
      .length;

  int get videoCount => _media
      .where((item) => item.type == GalleryMediaType.video)
      .length;

  bool get isEmpty => _media.isEmpty;
  bool get isNotEmpty => _media.isNotEmpty;

  bool isSelected(GalleryMediaItem item) {
    return item.id == _selectedMediaId;
  }

  bool isDragging(GalleryMediaItem item) {
    return item.id == _draggedMediaId;
  }

  int indexOfId(String mediaId) {
    return _media.indexWhere((item) => item.id == mediaId);
  }

  void replaceMedia(List<GalleryMediaItem> media) {
    if (_sameMediaList(_media, media)) {
      return;
    }

    _media = List<GalleryMediaItem>.from(media);

    if (_selectedMediaId != null &&
        !_media.any((item) => item.id == _selectedMediaId)) {
      _selectedMediaId = null;
    }

    if (_draggedMediaId != null &&
        !_media.any((item) => item.id == _draggedMediaId)) {
      _draggedMediaId = null;
    }

    notifyListeners();
  }

  void toggleSelection(GalleryMediaItem item) {
    _selectedMediaId =
        _selectedMediaId == item.id ? null : item.id;
    notifyListeners();
  }

  void select(GalleryMediaItem item) {
    if (_selectedMediaId == item.id) {
      return;
    }

    _selectedMediaId = item.id;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedMediaId == null) {
      return;
    }

    _selectedMediaId = null;
    notifyListeners();
  }

  void beginDrag(String mediaId) {
    if (_draggedMediaId == mediaId) {
      return;
    }

    _draggedMediaId = mediaId;
    notifyListeners();
  }

  void endDrag() {
    if (_draggedMediaId == null) {
      return;
    }

    _draggedMediaId = null;
    notifyListeners();
  }

  bool reorderById({
    required String draggedMediaId,
    required String targetMediaId,
  }) {
    final oldIndex = indexOfId(draggedMediaId);
    final targetIndex = indexOfId(targetMediaId);

    if (oldIndex == -1 ||
        targetIndex == -1 ||
        oldIndex == targetIndex) {
      return false;
    }

    final item = _media.removeAt(oldIndex);
    final insertionIndex =
        oldIndex < targetIndex ? targetIndex - 1 : targetIndex;

    _media.insert(insertionIndex, item);
    _selectedMediaId = item.id;
    notifyListeners();
    return true;
  }

  GalleryMediaItem? removeAt(int index) {
    if (index < 0 || index >= _media.length) {
      return null;
    }

    final removed = _media.removeAt(index);

    if (_selectedMediaId == removed.id) {
      _selectedMediaId = null;
    }

    if (_draggedMediaId == removed.id) {
      _draggedMediaId = null;
    }

    notifyListeners();
    return removed;
  }

  bool restore({
    required GalleryMediaItem item,
    required int originalIndex,
  }) {
    if (_media.any((existing) => existing.id == item.id)) {
      return false;
    }

    final safeIndex = originalIndex.clamp(0, _media.length);
    _media.insert(safeIndex, item);
    _selectedMediaId = item.id;
    notifyListeners();
    return true;
  }

  String? firstPhotoPath() {
    for (final item in _media) {
      if (item.type == GalleryMediaType.photo) {
        return item.path;
      }
    }

    return null;
  }

  bool _sameMediaList(
    List<GalleryMediaItem> first,
    List<GalleryMediaItem> second,
  ) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      final firstItem = first[index];
      final secondItem = second[index];

      if (firstItem.id != secondItem.id ||
          firstItem.path != secondItem.path ||
          firstItem.type != secondItem.type) {
        return false;
      }
    }

    return true;
  }
}
