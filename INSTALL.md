# Install Thot Gallery Creator v2 Foundation

## 1. Extract and enter the project

```bash
unzip Thot_Gallery_Creator_v2_Foundation.zip
cd Thot_Gallery_Creator_v2_Foundation
```

## 2. Generate platform projects and run checks

```bash
chmod +x tool/bootstrap_mobile.sh
./tool/bootstrap_mobile.sh
```

The script generates fresh Android and iOS scaffolding without replacing the migrated `lib`, `assets`, or tests.

## 3. Connect the Galaxy Tab S6

Enable Developer Options and USB debugging, then run:

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID
```

## 4. Build a debug APK

```bash
flutter build apk --debug
```

APK location:

```text
build/app/outputs/flutter-apk/app-debug.apk
```
