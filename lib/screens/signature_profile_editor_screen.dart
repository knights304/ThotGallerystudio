import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/signature_profile.dart';

class SignatureProfileEditorScreen extends StatefulWidget {
  const SignatureProfileEditorScreen({super.key, required this.existing});

  final SignatureProfile existing;

  @override
  State<SignatureProfileEditorScreen> createState() =>
      _SignatureProfileEditorScreenState();
}

class _SignatureProfileEditorScreenState
    extends State<SignatureProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _headline;
  late final TextEditingController _about;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _location;
  late final TextEditingController _skills;
  late final TextEditingController _badges;
  late final TextEditingController _slug;
  late List<ProfileLink> _links;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _displayName = TextEditingController(text: p.displayName);
    _username = TextEditingController(text: p.username);
    _headline = TextEditingController(text: p.headline);
    _about = TextEditingController(text: p.about);
    _phone = TextEditingController(text: p.phone);
    _email = TextEditingController(text: p.email);
    _location = TextEditingController(text: p.location);
    _skills = TextEditingController(text: p.skills.join(', '));
    _badges = TextEditingController(text: p.badges.join(', '));
    _slug = TextEditingController(text: p.shareSlug);
    _links = p.links
        .map((link) => ProfileLink(label: link.label, url: link.url))
        .toList();
    _photoPath = p.photoPath;
  }

  @override
  void dispose() {
    for (final controller in [
      _displayName,
      _username,
      _headline,
      _about,
      _phone,
      _email,
      _location,
      _skills,
      _badges,
      _slug,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _list(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image != null) setState(() => _photoPath = image.path);
  }

  Future<void> _addLink() async {
    final label = TextEditingController();
    final url = TextEditingController();

    final result = await showDialog<ProfileLink>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isEmpty || url.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                ProfileLink(
                  label: label.text.trim(),
                  url: url.text.trim(),
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    label.dispose();
    url.dispose();

    if (result != null) setState(() => _links.add(result));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      SignatureProfile(
        displayName: _displayName.text.trim(),
        username: _username.text.trim(),
        headline: _headline.text.trim(),
        about: _about.text.trim(),
        photoPath: _photoPath,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        location: _location.text.trim(),
        skills: _list(_skills.text),
        badges: _list(_badges.text),
        links: _links,
        shareSlug: _slug.text
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9-]+'), '-'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Signature Card'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.account_circle_outlined),
              label: Text(
                _photoPath == null ? 'Choose Profile Image' : 'Replace Image',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a display name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _headline,
              decoration: const InputDecoration(labelText: 'Headline/tagline'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _about,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'About me'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Skills',
                hintText: 'Separate with commas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _badges,
              decoration: const InputDecoration(
                labelText: 'Badges',
                hintText: 'Separate with commas',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _slug,
              decoration: const InputDecoration(
                labelText: 'Permanent card name',
                prefixText: 'thotivites.app/card/',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Links',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _addLink,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add'),
                ),
              ],
            ),
            ..._links.asMap().entries.map(
                  (entry) => Card(
                    child: ListTile(
                      title: Text(entry.value.label),
                      subtitle: Text(entry.value.url),
                      trailing: IconButton(
                        onPressed: () =>
                            setState(() => _links.removeAt(entry.key)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Signature Card'),
            ),
          ],
        ),
      ),
    );
  }
}
