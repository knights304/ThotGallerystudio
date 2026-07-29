import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thot_gallery_creator/app.dart';
import 'package:thot_gallery_creator/services/creator_profile_store.dart';
import 'package:thot_gallery_creator/services/gallery_store.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return documentsPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'thot_gallery_test_',
    );

    PathProviderPlatform.instance = FakePathProviderPlatform(
      temporaryDirectory.path,
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  testWidgets('Thot Gallery Creator boots', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = GalleryStore();
    final creators = CreatorProfileStore();

    await tester.runAsync(() async {
      await Future.wait<void>([
        store.load(),
        creators.load(),
      ]);
    });

    await tester.pumpWidget(
      ThotGalleryApp(
        store: store,
        creators: creators,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ThotGalleryApp), findsOneWidget);
  });
}
