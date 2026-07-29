import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/gallery_card.dart';
import '../../services/gallery_store.dart';
import '../../theme/gallery_theme.dart';

class PublishingScreen extends StatefulWidget {
  const PublishingScreen({super.key, required this.store});
  final GalleryStore store;

  @override
  State<PublishingScreen> createState() => _PublishingScreenState();
}

class _PublishingScreenState extends State<PublishingScreen> {
  String? _selectedId;
  bool _busy = false;
  String? _lastExport;

  GalleryCard? get _selected {
    final cards = widget.store.cards;
    if (cards.isEmpty) return null;
    final id = _selectedId;
    if (id == null) return cards.first;
    return cards.where((card) => card.id == id).firstOrNull ?? cards.first;
  }

  Future<void> _export(GalleryCard card) async {
    setState(() => _busy = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final folder =
          Directory(p.join(docs.path, 'ThotGallery', 'Exports', card.id));
      await folder.create(recursive: true);
      final jsonFile = File(p.join(folder.path, '${card.id}.thot.json'));
      await jsonFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(card.toJson()));
      final html = File(p.join(folder.path, 'index.html'));
      await html.writeAsString(
          '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${_escape(card.title)}</title><style>body{background:#09070d;color:#fff;font-family:system-ui;margin:0;display:grid;place-items:center;min-height:100vh}.card{width:min(88vw,420px);padding:28px;border:2px solid #b86bff;border-radius:28px;background:linear-gradient(145deg,#29103f,#0c0912);box-shadow:0 0 50px #6f2da855}h1{margin:0 0 8px}.meta{color:#c9bfd3}.pill{display:inline-block;padding:6px 10px;border-radius:999px;background:#6f2da8;margin:4px 4px 0 0}</style></head><body><article class="card"><p class="meta">${card.id} • ${_escape(card.setName)}</p><h1>${_escape(card.title)}</h1><p>${_escape(card.description)}</p><div><span class="pill">${_escape(card.rarity)}</span><span class="pill">${card.thotPoints} TP</span><span class="pill">${card.media.length} media</span></div><p class="meta">Fingerprint: ${card.shortFingerprint}</p></article></body></html>''');
      await widget.store.recordShare(card.id);
      setState(() => _lastExport = folder.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export created in ${folder.path}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _escape(String value) => const HtmlEscape().convert(value);

  @override
  Widget build(BuildContext context) {
    final card = _selected;

    if (card == null) {
      return const Center(
        child: Text(
          'Create a Gallery Piece before publishing.',
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('PUBLISHING SUITE',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6)),
          const SizedBox(height: 4),
          const Text(
              'Generate a browser page, metadata package, QR payload, and NFC-ready link.',
              style: TextStyle(color: GalleryColors.muted)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: card.id,
            decoration: const InputDecoration(labelText: 'Gallery Piece'),
            items: widget.store.cards
                .map((item) => DropdownMenuItem(
                    value: item.id, child: Text('${item.id} • ${item.title}')))
                .toList(),
            onChanged: (value) => setState(() => _selectedId = value),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: QrImageView(
                      data: card.verificationPayload,
                      size: 230,
                      backgroundColor: Colors.white),
                ),
              ),
              SizedBox(
                width: 440,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text(card.description.isEmpty
                              ? 'No description yet.'
                              : card.description),
                          const SizedBox(height: 14),
                          _line('Package', '${card.id}.thot.json'),
                          _line('Browser page', 'index.html'),
                          _line('QR / NFC payload', card.verificationPayload),
                          _line('Fingerprint', card.shortFingerprint),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _busy ? null : () => _export(card),
                            icon: _busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.rocket_launch_rounded),
                            label: Text(
                                _busy ? 'Exporting…' : 'Build Publish Package'),
                          ),
                          if (_lastExport != null) ...[
                            const SizedBox(height: 12),
                            SelectableText(_lastExport!,
                                style: const TextStyle(
                                    color: GalleryColors.muted)),
                          ],
                        ]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(color: GalleryColors.muted))),
          Expanded(child: SelectableText(value, maxLines: 3)),
        ]),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
