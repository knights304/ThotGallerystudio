import 'package:flutter/material.dart';

import 'app.dart';
import 'services/creator_profile_store.dart';
import 'services/gallery_store.dart';
import 'services/rate_me_incoming_share_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GalleryStore();
  final creators = CreatorProfileStore();
  await Future.wait([store.load(), creators.load()]);

  await StudioRateMeIncomingShareService.instance.start();

  runApp(ThotGalleryApp(store: store, creators: creators));
}
