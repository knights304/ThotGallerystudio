import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/creator_profile_store.dart';
import 'services/gallery_store.dart';
import 'theme/gallery_theme.dart';

class ThotGalleryApp extends StatelessWidget {
  const ThotGalleryApp(
      {super.key, required this.store, required this.creators});

  final GalleryStore store;
  final CreatorProfileStore creators;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thot Gallery Creator v2',
      debugShowCheckedModeBanner: false,
      theme: GalleryTheme.dark,
      home: HomeScreen(store: store, creators: creators),
    );
  }
}
