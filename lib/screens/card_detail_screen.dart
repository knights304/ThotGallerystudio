import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/gallery_card.dart';
import '../services/gallery_store.dart';
import '../theme/gallery_theme.dart';
import '../widgets/flippable_gallery_card.dart';
import '../widgets/living_media_gallery.dart';
import 'card_editor_screen.dart';
import 'package_builder_screen.dart';
import 'nfc_card_publisher_screen.dart';

class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({
    super.key,
    required this.card,
    required this.store,
  });

  final GalleryCard card;
  final GalleryStore store;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late GalleryCard card;

  @override
  void initState() {
    super.initState();
    card = widget.card;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.store.recordView(card.id);
      if (mounted) {
        final refreshed = widget.store.cards.firstWhere(
          (item) => item.id == card.id,
          orElse: () => card,
        );
        setState(() => card = refreshed);
      }
    });
  }

  String _shareText() {
    card.ensureFingerprint();
    return [
      card.title,
      card.description,
      'Type: ${card.type.name}',
      'Thot Points: ${card.thotPoints} 👅',
      'Set: ${card.setName}',
      'Rarity: ${card.rarityCategory} / ${card.rarity}',
      'Card ID: ${card.id}',
      'Fingerprint: ${card.shortFingerprint}',
      if (card.location.isNotEmpty) 'Location: ${card.location}',
      ...card.links,
      card.verificationPayload,
    ].where((item) => item.trim().isNotEmpty).join('\n');
  }

  Future<void> _share() async {
    await widget.store.recordShare(card.id);
    await SharePlus.instance.share(
      ShareParams(text: _shareText(), subject: card.title),
    );
    if (!mounted) return;
    final refreshed = widget.store.cards.firstWhere(
      (item) => item.id == card.id,
      orElse: () => card,
    );
    setState(() => card = refreshed);
  }

  Future<void> _edit() async {
    final navigator = Navigator.of(context);

    final edited = await navigator.push<GalleryCard>(
      MaterialPageRoute(
        builder: (_) => CardEditorScreen(existing: card),
      ),
    );

    if (edited == null) {
      return;
    }

    edited.ensureFingerprint();
    await widget.store.upsertCard(edited);

    if (!mounted) {
      return;
    }

    setState(() {
      card = edited;
    });
  }

  Future<void> _openPackageBuilder() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PackageBuilderScreen(card: card),
      ),
    );
  }

  Future<void> _openNfcPublisher() async {
    card.ensureFingerprint();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NfcCardPublisherScreen(card: card),
      ),
    );
  }

  Future<void> _deleteCard() async {
    final navigator = Navigator.of(context);

    await widget.store.deleteCard(card.id);

    if (!mounted) {
      return;
    }

    navigator.pop();
  }

  String _shortHash(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Not available';
    }

    if (trimmed.length <= 16) {
      return trimmed;
    }

    return '${trimmed.substring(0, 8)}…${trimmed.substring(trimmed.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(card.title),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'build-package') {
                await _openPackageBuilder();
              }

              if (value == 'physical-nfc-card') {
                await _openNfcPublisher();
              }

              if (value == 'edit') {
                await _edit();
              }

              if (value == 'duplicate') {
                await widget.store.duplicateCard(card);
              }

              if (value == 'delete') {
                await _deleteCard();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'build-package',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined),
                    SizedBox(width: 10),
                    Text('Build Package'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'physical-nfc-card',
                child: Row(
                  children: [
                    Icon(Icons.nfc_rounded),
                    SizedBox(width: 10),
                    Text('Physical NFC Card'),
                  ],
                ),
              ),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 6, 18, 8),
            child: Text(
              'Tap the card to flip it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GalleryColors.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: FlippableGalleryCard(card: card),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(card.type.name)),
                    Chip(label: Text(card.status.name)),
                    Chip(label: Text('${card.thotPoints} TP 👅')),
                    Chip(label: Text(card.rarity)),
                    if (card.rating > 0)
                      Chip(
                        avatar: const Icon(Icons.star_rounded, size: 18),
                        label: Text('${card.rating.toStringAsFixed(1)}/5'),
                      ),
                    ...card.collections.map(
                      (collection) => Chip(
                        avatar:
                            const Icon(Icons.folder_special_outlined, size: 18),
                        label: Text(collection),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (card.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(card.description),
                ],
                if (card.media.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  LivingMediaGallery(media: card.media),
                ],
                const SizedBox(height: 24),
                Text(
                  'Piece Stats',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.25,
                  children: [
                    _StatTile(
                        icon: Icons.visibility_outlined,
                        label: 'Views',
                        value: card.views),
                    _StatTile(
                        icon: Icons.share_outlined,
                        label: 'Shares',
                        value: card.shareCount),
                    _StatTile(
                        icon: Icons.photo_outlined,
                        label: 'Photos',
                        value: card.photoCount),
                    _StatTile(
                        icon: Icons.videocam_outlined,
                        label: 'Videos',
                        value: card.videoCount),
                  ],
                ),
                if (card.location.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: card.location,
                  ),
                if (card.participants.isNotEmpty)
                  _InfoRow(
                    icon: Icons.group_outlined,
                    text: card.participants.join(', '),
                  ),
                if (card.links.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Links',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...card.links.map(
                    (link) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link),
                      title: Text(
                        link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        final uri = Uri.tryParse(link);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  ),
                ],
                if (card.hasImportProvenance) ...[
                  const SizedBox(height: 26),
                  Text(
                    'Import & Authenticity',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GalleryColors.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            GalleryColors.purpleBright.withValues(alpha: .22),
                      ),
                    ),
                    child: Column(
                      children: [
                        _DetailInfoRow(
                          icon: Icons.inventory_2_outlined,
                          label: 'Source package',
                          value: card.sourcePackageName.isEmpty
                              ? 'Unknown'
                              : card.sourcePackageName,
                        ),
                        _DetailInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Imported',
                          value: card.importedAt == null
                              ? 'Unknown'
                              : card.importedAt!.toLocal().toString(),
                        ),
                        _DetailInfoRow(
                          icon: Icons.layers_outlined,
                          label: 'Package version',
                          value: card.importedPackageVersion <= 0
                              ? 'Unknown'
                              : 'TG v${card.importedPackageVersion}',
                        ),
                        _DetailInfoRow(
                          icon: Icons.developer_mode_rounded,
                          label: 'Creator version',
                          value: card.importedCreatorVersion.isEmpty
                              ? 'Unknown'
                              : card.importedCreatorVersion,
                        ),
                        _DetailInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Verified content',
                          value: _shortHash(card.importedContentHash),
                        ),
                        _DetailInfoRow(
                          icon: card.importWasReplacement
                              ? Icons.sync_rounded
                              : Icons.download_done_rounded,
                          label: 'Import action',
                          value: card.importWasReplacement
                              ? 'Replaced existing card'
                              : 'Added to vault',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit This Card'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GalleryColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x447D6C8E)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GalleryColors.purpleBright),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  const _DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: GalleryColors.purpleBright,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(
                  color: GalleryColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Icon(icon, color: GalleryColors.silver),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
