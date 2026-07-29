import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/export/browser_gallery_service.dart';
import '../../core/export/marketplace_export_service.dart';
import '../../core/export/thot_package_service.dart';
import '../../models/creator_profile.dart';
import '../../models/gallery_card.dart';
import '../../services/creator_profile_store.dart';
import '../../services/gallery_store.dart';
import '../../theme/gallery_theme.dart';
import '../../widgets/gradient_shell.dart';

class PublishingSuiteScreen extends StatefulWidget {
  const PublishingSuiteScreen(
      {super.key, required this.store, required this.creators});
  final GalleryStore store;
  final CreatorProfileStore creators;

  @override
  State<PublishingSuiteScreen> createState() => _PublishingSuiteScreenState();
}

class _PublishingSuiteScreenState extends State<PublishingSuiteScreen> {
  final _browser = BrowserGalleryService();
  final _packages = ThotPackageService();
  final _marketplace = MarketplaceExportService();
  final Set<String> _selected = {};
  GalleryCard? _active;
  CreatorProfile? _creator;
  bool _busy = false;
  String _status = 'Choose a Gallery Piece to publish.';

  @override
  void initState() {
    super.initState();
    _active = widget.store.cards.isEmpty ? null : widget.store.cards.first;
    _creator = widget.creators.defaultProfile;
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _status = label;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _status = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportBrowser() async {
    final card = _active;
    if (card == null) return;
    await _run('Building responsive offline browser gallery…', () async {
      final file = await _browser.export(card, creator: _creator);
      await widget.store.recordShare(card.id);
      setState(() => _status = 'Browser gallery created: ${file.path}');
      await launchUrl(Uri.file(file.path),
          mode: LaunchMode.externalApplication);
    });
  }

  Future<void> _exportPackage() async {
    final card = _active;
    if (card == null) return;
    await _run('Packing media, theme, metadata, and checksums…', () async {
      final html = _browser.buildHtml(card, creator: _creator);
      final file = await _packages.exportPackage(card,
          creator: _creator, browserHtml: html);
      await widget.store.recordShare(card.id);
      setState(() => _status = '.thot package created: ${file.path}');
      await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          text: '${card.title} · Thot Gallery package'));
    });
  }

  Future<void> _marketplaceExport() async {
    final card = _active;
    if (card == null) return;
    await _run('Forging marketplace bundle…', () async {
      final result = await _marketplace.exportPiece(card, creator: _creator);
      await widget.store.recordShare(card.id);
      setState(() => _status =
          'Marketplace kit created with ${result.files.length} files: ${result.folder.path}');
      final zip = result.files.lastWhere((file) => file.path.endsWith('.zip'));
      await SharePlus.instance.share(ShareParams(
          files: [XFile(zip.path)], text: '${card.title} marketplace kit'));
    });
  }

  Future<void> _batchExport() async {
    final cards = widget.store.cards
        .where((card) => _selected.contains(card.id))
        .toList();
    if (cards.isEmpty) return;
    await _run('Batch exporting ${cards.length} Gallery Pieces…', () async {
      final results = await _marketplace.exportBatch(cards, creator: _creator);
      setState(() => _status =
          'Batch complete: ${results.length} marketplace folders created.');
    });
  }

  Future<void> _importPackage() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['thot']);
    final path = result?.files.single.path;
    if (path == null) return;
    await _run('Validating package checksums…', () async {
      final validation = await _packages.validate(File(path));
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(validation.isValid
              ? 'Valid .thot Package'
              : 'Package Failed Validation'),
          content: Text(validation.messages.join('\n')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Close')),
            if (validation.isValid)
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Import Piece')),
          ],
        ),
      );
      if (accepted == true && validation.card != null) {
        final imported = await _packages.importPackage(File(path))
          ..status = GalleryCardStatus.idea;
        if (widget.store.cards.any((card) => card.id == imported.id)) {
          final copy = GalleryCard.fromJson(imported.toJson());
          await widget.store.duplicateCard(copy);
        } else {
          await widget.store.upsertCard(imported);
        }
        setState(() => _status = 'Imported ${imported.title} into the Vault.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.store.cards;
    return GradientShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CREATOR & PUBLISHING SUITE',
              style: TextStyle(
                  letterSpacing: 2,
                  color: GalleryColors.silver,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Package it. Brand it. Send it into the wild.',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final library = _library(cards);
                final panel = _publishPanel();
                return wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            SizedBox(width: 360, child: library),
                            const SizedBox(width: 18),
                            Expanded(child: panel)
                          ])
                    : ListView(children: [
                        SizedBox(height: 360, child: library),
                        const SizedBox(height: 18),
                        panel
                      ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _library(List<GalleryCard> cards) => Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Expanded(
                    child: Text('Gallery Pieces',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: _importPackage,
                    tooltip: 'Import .thot package',
                    icon: const Icon(Icons.file_download_outlined))
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return ListTile(
                    selected: _active?.id == card.id,
                    leading: Checkbox(
                        value: _selected.contains(card.id),
                        onChanged: (value) => setState(() => value == true
                            ? _selected.add(card.id)
                            : _selected.remove(card.id))),
                    title: Text(card.title),
                    subtitle: Text('${card.id} · ${card.rarity}'),
                    onTap: () => setState(() => _active = card),
                  );
                },
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                          onPressed: _busy ? null : _batchExport,
                          icon: const Icon(Icons.layers_outlined),
                          label: Text('Batch Export (${_selected.length})')))),
          ],
        ),
      );

  Widget _publishPanel() {
    final card = _active;

    if (card == null) {
      return const Center(
        child: Text(
          'Create a Gallery Piece first.',
        ),
      );
    }

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.title,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900)),
              Text('${card.id} · ${card.setName} · ${card.rarity}',
                  style: const TextStyle(color: GalleryColors.silver)),
              const SizedBox(height: 16),
              DropdownButtonFormField<CreatorProfile>(
                initialValue: _creator,
                decoration: const InputDecoration(labelText: 'Creator profile'),
                items: widget.creators.profiles
                    .map((profile) => DropdownMenuItem(
                        value: profile, child: Text(profile.displayName)))
                    .toList(),
                onChanged: (value) => setState(() => _creator = value),
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _ActionCard(
                    icon: Icons.language,
                    title: 'Browser Gallery',
                    subtitle:
                        'Responsive, light/dark, card flip, fullscreen gallery, offline HTML',
                    onTap: _busy ? null : _exportBrowser),
                _ActionCard(
                    icon: Icons.inventory_2_outlined,
                    title: '.thot Package',
                    subtitle:
                        'Versioned portable package with checksums, media, metadata, and theme',
                    onTap: _busy ? null : _exportPackage),
                _ActionCard(
                    icon: Icons.storefront_outlined,
                    title: 'Marketplace Kit',
                    subtitle:
                        'HTML, metadata, social preview, print PDF, .thot file, and ZIP bundle',
                    onTap: _busy ? null : _marketplaceExport),
                _ActionCard(
                    icon: Icons.file_download_outlined,
                    title: 'Import Package',
                    subtitle:
                        'Validate and bring a portable Gallery Piece back into the Vault',
                    onTap: _busy ? null : _importPackage),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(_busy ? Icons.hourglass_top : Icons.check_circle_outline,
                      color: GalleryColors.purpleBright),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status))
                ]))),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 265,
        child: Card(
          color: GalleryColors.panel,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 30, color: GalleryColors.purpleBright),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(color: GalleryColors.silver))
                  ]),
            ),
          ),
        ),
      );
}
