import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/signature_profile.dart';
import '../services/gallery_store.dart';
import '../theme/gallery_theme.dart';
import '../widgets/gradient_shell.dart';
import 'signature_profile_editor_screen.dart';

class SignatureProfileScreen extends StatefulWidget {
  const SignatureProfileScreen({super.key, required this.store});

  final GalleryStore store;

  @override
  State<SignatureProfileScreen> createState() => _SignatureProfileScreenState();
}

class _SignatureProfileScreenState extends State<SignatureProfileScreen> {
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

  Future<void> _edit() async {
    final profile = await Navigator.of(context).push<SignatureProfile>(
      MaterialPageRoute(
        builder: (_) =>
            SignatureProfileEditorScreen(existing: widget.store.profile),
      ),
    );
    if (profile != null) await widget.store.saveProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.store.profile;
    final hasPhoto =
        profile.photoPath != null && File(profile.photoPath!).existsSync();
    final shareUrl = 'https://thotivites.app/card/${profile.shareSlug}';

    return GradientShell(
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Signature Card',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GalleryColors.purpleDeep,
                  GalleryColors.surfaceRaised,
                  GalleryColors.black,
                ],
              ),
              border: Border.all(color: const Color(0x88C7C5CE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x445D1DA9),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: GalleryColors.surface,
                  backgroundImage:
                      hasPhoto ? FileImage(File(profile.photoPath!)) : null,
                  child: hasPhoto ? null : const Icon(Icons.person, size: 54),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  profile.username,
                  style: const TextStyle(color: GalleryColors.silver),
                ),
                const SizedBox(height: 10),
                Text(profile.headline, textAlign: TextAlign.center),
                if (profile.badges.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: profile.badges
                        .map((badge) => Chip(label: Text(badge)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          if (profile.about.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(title: 'About', child: Text(profile.about)),
          ],
          if (profile.skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Skills',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills
                    .map((skill) => Chip(label: Text(skill)))
                    .toList(),
              ),
            ),
          ],
          if (profile.links.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: 'Links',
              child: Column(
                children: profile.links
                    .map(
                      (link) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.link, size: 18),
                        ),
                        title: Text(link.label),
                        subtitle: Text(
                          link.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                        onTap: () async {
                          final uri = Uri.tryParse(link.url);
                          if (uri != null) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Section(
            title: 'Always-ready sharing',
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: QrImageView(
                    data: shareUrl,
                    size: 180,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  shareUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GalleryColors.silver),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text: '${profile.shareText()}\n\n$shareUrl',
                            subject: profile.displayName,
                          ),
                        ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.tune),
                        label: const Text('Update'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
