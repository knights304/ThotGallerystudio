import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/creator_profile.dart';
import '../../services/creator_profile_store.dart';
import '../../theme/gallery_theme.dart';
import '../../widgets/gradient_shell.dart';

class CreatorProfilesScreen extends StatefulWidget {
  const CreatorProfilesScreen({super.key, required this.store});

  final CreatorProfileStore store;

  @override
  State<CreatorProfilesScreen> createState() => _CreatorProfilesScreenState();
}

class _CreatorProfilesScreenState extends State<CreatorProfilesScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _edit([CreatorProfile? existing]) async {
    final original = existing;
    final profile = existing == null
        ? CreatorProfile(
            id: 'creator-${DateTime.now().microsecondsSinceEpoch}',
            displayName: 'New Creator',
            createdAt: DateTime.now(),
          )
        : CreatorProfile.fromJson(existing.toJson());
    final name = TextEditingController(text: profile.displayName);
    final handle = TextEditingController(text: profile.handle);
    final bio = TextEditingController(text: profile.bio);
    final signature = TextEditingController(text: profile.signature);
    final website = TextEditingController(text: profile.website);
    final accent = TextEditingController(text: profile.accentHex);
    String? avatar = profile.avatarPath;
    String? logo = profile.logoPath;
    String? watermark = profile.watermarkPath;
    var defaultTheme = profile.defaultTheme;
    var isDefault = profile.isDefault;

    Future<String?> pickImage() async {
      final result = await ImagePicker().pickImage(source: ImageSource.gallery);
      return result?.path;
    }

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(original == null
              ? 'Create Creator Profile'
              : 'Edit Creator Profile'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _ImagePickerTile(
                          label: 'Avatar',
                          path: avatar,
                          onTap: () async {
                            avatar = await pickImage() ?? avatar;
                            setDialogState(() {});
                          }),
                      _ImagePickerTile(
                          label: 'Logo',
                          path: logo,
                          onTap: () async {
                            logo = await pickImage() ?? logo;
                            setDialogState(() {});
                          }),
                      _ImagePickerTile(
                          label: 'Watermark',
                          path: watermark,
                          onTap: () async {
                            watermark = await pickImage() ?? watermark;
                            setDialogState(() {});
                          }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Display name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: handle,
                      decoration: const InputDecoration(labelText: 'Handle')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: bio,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: signature,
                      decoration: const InputDecoration(
                          labelText: 'Signature / tagline')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: website,
                      decoration: const InputDecoration(labelText: 'Website')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: accent,
                      decoration: const InputDecoration(
                          labelText: 'Accent color, e.g. #9B5CFF')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: defaultTheme,
                    decoration: const InputDecoration(
                        labelText: 'Default export theme'),
                    items: const [
                      'Cyberpunk',
                      'Royal Purple',
                      'Chrome',
                      'Gold',
                      'Minimal'
                    ]
                        .map((value) =>
                            DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: (value) => defaultTheme = value ?? defaultTheme,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use as default creator'),
                    value: isDefault,
                    onChanged: (value) =>
                        setDialogState(() => isDefault = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save Profile')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    profile
      ..displayName = name.text.trim().isEmpty ? 'Creator' : name.text.trim()
      ..handle = handle.text.trim()
      ..bio = bio.text.trim()
      ..signature = signature.text.trim()
      ..website = website.text.trim()
      ..accentHex = accent.text.trim().isEmpty ? '#9B5CFF' : accent.text.trim()
      ..avatarPath = avatar
      ..logoPath = logo
      ..watermarkPath = watermark
      ..defaultTheme = defaultTheme
      ..isDefault = isDefault;
    await widget.store.upsert(profile);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.store.profiles;
    return GradientShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CREATOR PROFILES',
                        style: TextStyle(
                            letterSpacing: 2,
                            color: GalleryColors.silver,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Brand every export with the right identity.',
                        style: TextStyle(
                            fontSize: 27, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('New Creator')),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 390,
                  mainAxisExtent: 270,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundImage: profile.avatarPath != null &&
                                      File(profile.avatarPath!).existsSync()
                                  ? FileImage(File(profile.avatarPath!))
                                  : null,
                              child: profile.avatarPath == null
                                  ? Text(profile.displayName
                                      .substring(0, 1)
                                      .toUpperCase())
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(profile.displayName,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  Text(profile.handle,
                                      style: const TextStyle(
                                          color: GalleryColors.silver))
                                ])),
                            if (profile.isDefault)
                              const Chip(label: Text('DEFAULT')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(profile.bio,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text(profile.signature,
                            style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: GalleryColors.purpleBright)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                                onPressed: () => _edit(profile),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit')),
                            if (!profile.isDefault)
                              TextButton(
                                  onPressed: () =>
                                      widget.store.setDefault(profile.id),
                                  child: const Text('Make Default')),
                            const Spacer(),
                            IconButton(
                                onPressed: profiles.length <= 1
                                    ? null
                                    : () => widget.store.delete(profile.id),
                                icon: const Icon(Icons.delete_outline)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile(
      {required this.label, required this.path, required this.onTap});
  final String label;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 150,
          height: 105,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: GalleryColors.purple.withValues(alpha: .45))),
          child: path != null && File(path!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.file(File(path!), fit: BoxFit.cover))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_photo_alternate_outlined),
                  const SizedBox(height: 6),
                  Text(label)
                ]),
        ),
      );
}
