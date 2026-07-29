import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/gallery_card.dart';
import '../services/gallery_store.dart';
import '../theme/gallery_theme.dart';
import '../widgets/flippable_gallery_card.dart';
import '../widgets/living_media_gallery.dart';
import 'card_editor_screen.dart';

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

  Future<void> _deleteCard() async {
    final navigator = Navigator.of(context);

    await widget.store.deleteCard(card.id);

    if (!mounted) {
      return;
    }

    navigator.pop();
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
