import 'package:flutter/material.dart';

import 'app.dart';
import 'services/creator_profile_store.dart';
import 'services/gallery_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GalleryStore();
  final creators = CreatorProfileStore();
  await Future.wait([store.load(), creators.load()]);
  runApp(ThotGalleryApp(store: store, creators: creators));
}
