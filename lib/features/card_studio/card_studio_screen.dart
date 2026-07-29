import 'package:flutter/material.dart';

import '../../models/gallery_card.dart';
import '../../services/gallery_store.dart';
import '../../theme/gallery_theme.dart';
import '../../widgets/collectible_card.dart';

class CardStudioScreen extends StatefulWidget {
  const CardStudioScreen({super.key, required this.store});
  final GalleryStore store;

  @override
  State<CardStudioScreen> createState() => _CardStudioScreenState();
}

class _CardStudioScreenState extends State<CardStudioScreen> {
  GalleryCard? _draft;
  String? _selectedId;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _setName = TextEditingController();
  final _rarity = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
    if (widget.store.cards.isNotEmpty) _select(widget.store.cards.first);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    _title.dispose();
    _description.dispose();
    _setName.dispose();
    _rarity.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final id = _selectedId;
    if (id != null) {
      for (final card in widget.store.cards) {
        if (card.id == id) {
          _select(card, refresh: false);
          break;
        }
      }
    }
    setState(() {});
  }

  void _select(GalleryCard card, {bool refresh = true}) {
    _selectedId = card.id;
    _draft = card.copy();
    _title.text = _draft!.title;
    _description.text = _draft!.description;
    _setName.text = _draft!.setName;
    _rarity.text = _draft!.rarity;
    if (refresh && mounted) setState(() {});
  }

  void _syncText() {
    final draft = _draft;
    if (draft == null) return;
    draft
      ..title =
          _title.text.trim().isEmpty ? 'Untitled Piece' : _title.text.trim()
      ..description = _description.text.trim()
      ..setName = _setName.text.trim().isEmpty
          ? 'Thot Gallery Originals'
          : _setName.text.trim()
      ..rarity = _rarity.text.trim().isEmpty ? 'Original' : _rarity.text.trim();
    setState(() {});
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    _syncText();
    await widget.store.upsertCard(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Card Studio changes saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.store.cards;
    final draft = _draft;
    if (cards.isEmpty || draft == null) {
      return const Center(
          child: Text('Create a Gallery Piece before opening Card Studio.'));
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          final picker = _PiecePicker(
            cards: cards,
            selectedId: _selectedId,
            onSelected: _select,
          );
          final preview = _PreviewPane(card: draft);
          final controls = _ControlsPane(
            card: draft,
            title: _title,
            description: _description,
            setName: _setName,
            rarity: _rarity,
            onChanged: _syncText,
            onSave: _save,
          );

          if (!wide) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                picker,
                const SizedBox(height: 16),
                preview,
                const SizedBox(height: 16),
                controls
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 230, child: picker),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: preview),
                const SizedBox(width: 16),
                SizedBox(width: 340, child: controls),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PiecePicker extends StatelessWidget {
  const _PiecePicker(
      {required this.cards,
      required this.selectedId,
      required this.onSelected});
  final List<GalleryCard> cards;
  final String? selectedId;
  final ValueChanged<GalleryCard> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PIECES',
                style:
                    TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...cards.take(12).map((card) => ListTile(
                  dense: true,
                  selected: card.id == selectedId,
                  selectedTileColor:
                      GalleryColors.purple.withValues(alpha: .16),
                  leading: Icon(
                      card.isFavorite ? Icons.favorite : Icons.style_outlined),
                  title: Text(card.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(card.rarity),
                  onTap: () => onSelected(card),
                )),
          ],
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({required this.card});
  final GalleryCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(children: [
              Icon(Icons.auto_awesome_rounded,
                  color: GalleryColors.purpleBright),
              SizedBox(width: 8),
              Text('LIVE CARD PREVIEW',
                  style: TextStyle(
                      letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 420, maxHeight: 620),
                  child: AspectRatio(
                      aspectRatio: 0.68, child: CollectibleCard(card: card)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
                '${card.template.name} • ${card.rarity} • ${card.thotPoints} TP',
                style: const TextStyle(color: GalleryColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _ControlsPane extends StatelessWidget {
  const _ControlsPane({
    required this.card,
    required this.title,
    required this.description,
    required this.setName,
    required this.rarity,
    required this.onChanged,
    required this.onSave,
  });
  final GalleryCard card;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController setName;
  final TextEditingController rarity;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('CARD STUDIO PRO',
              style:
                  TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (_) => onChanged()),
          const SizedBox(height: 10),
          TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (_) => onChanged()),
          const SizedBox(height: 10),
          TextField(
              controller: setName,
              decoration: const InputDecoration(labelText: 'Set name'),
              onChanged: (_) => onChanged()),
          const SizedBox(height: 10),
          TextField(
              controller: rarity,
              decoration: const InputDecoration(labelText: 'Rarity'),
              onChanged: (_) => onChanged()),
          const SizedBox(height: 16),
          DropdownButtonFormField<GalleryCardTemplate>(
            initialValue: card.template,
            decoration: const InputDecoration(labelText: 'Template'),
            items: GalleryCardTemplate.values
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value.name)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                card.template = value;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GalleryCardType>(
            initialValue: card.type,
            decoration: const InputDecoration(labelText: 'Card type'),
            items: GalleryCardType.values
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text(value.name)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                card.type = value;
                onChanged();
              }
            },
          ),
          const SizedBox(height: 18),
          Text('Thot Points: ${card.thotPoints}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
              value: card.thotPoints.clamp(0, 1000).toDouble(),
              min: 0,
              max: 1000,
              divisions: 100,
              onChanged: (value) {
                card.thotPoints = value.round();
                onChanged();
              }),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('NFC enabled'),
            value: card.nfcEnabled,
            onChanged: (value) {
              card.nfcEnabled = value;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save Studio Changes')),
        ],
      ),
    );
  }
}
