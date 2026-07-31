import 'package:flutter/material.dart';

import '../../../models/gallery_card.dart';
import '../../../theme/gallery_theme.dart';

class ContentPanel extends StatelessWidget {
  const ContentPanel({
    super.key,
    required this.cards,
    required this.selectedCards,
    required this.onSelectionChanged,
    this.onReorder,
    this.isBusy = false,
  });

  final List<GalleryCard> cards;
  final List<GalleryCard> selectedCards;

  final ValueChanged<List<GalleryCard>> onSelectionChanged;

  final void Function(int oldIndex, int newIndex)? onReorder;

  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: .22),
        ),
      ),
      child: Column(
        children: [
          const _Header(),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: .08),
          ),
          if (cards.isEmpty)
            const _EmptyState()
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: cards.length,
              onReorder: (oldIndex, newIndex) {
                if (isBusy) return;
                onReorder?.call(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final card = cards[index];
                final selected = selectedCards.contains(card);

                return _CardTile(
                  key: ValueKey(card.id),
                  card: card,
                  selected: selected,
                  enabled: !isBusy,
                  onChanged: (value) {
                    final updated = [...selectedCards];

                    if (value) {
                      if (!updated.contains(card)) {
                        updated.add(card);
                      }
                    } else {
                      updated.remove(card);
                    }

                    onSelectionChanged(updated);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.view_carousel_rounded),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Package Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.card,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final GalleryCard card;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: enabled
          ? (value) => onChanged(value ?? false)
          : null,
      title: Text(
        card.title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        card.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      secondary: const Icon(Icons.drag_indicator),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: Colors.white38,
          ),
          SizedBox(height: 16),
          Text(
            'No content selected',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Select one or more gallery cards to include in this package.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
