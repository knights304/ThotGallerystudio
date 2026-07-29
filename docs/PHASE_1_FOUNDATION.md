# Phase 1: Creator v2 Foundation

## Goal

Preserve the Alpha 7 experience while converting it into a reproducible Android/iOS Flutter application.

## Included in this checkpoint

- Product renamed to **Thot Gallery Creator v2**.
- Package renamed to `thot_gallery_creator`.
- Version advanced to `2.0.0-alpha.1+20`.
- Dependency conflict reduced by pinning `image` to `4.8.0`.
- `file_picker` pinned to a known compatible API line.
- Broken widget-test constructor fixed.
- Mobile scaffold bootstrap script added.
- Official v2 card types locked into the core enum:
  - Profile
  - Gallery Piece
  - Rate Me
  - Match My Freak
- Existing Alpha 7 card types remain readable for backward compatibility.

## Definition of done

Run:

```bash
./tool/bootstrap_mobile.sh
```

The checkpoint is complete when:

```text
flutter pub get   succeeds
flutter analyze   has 0 errors
flutter test      passes
flutter run       launches on the Galaxy Tab S6
```

## Not yet included

This foundation does not yet implement production encryption, the encrypted `.thot` v2 format, database migration, social submissions, or the Vault companion. Those belong to later phases after the build is verified.
