import 'package:flutter/material.dart';

import '../../../models/gallery_card.dart';
import '../../../theme/gallery_theme.dart';
import '../../../widgets/info_pill.dart';
import '../../../widgets/summary_row.dart';

class MetadataPanel extends StatelessWidget {
  const MetadataPanel({
    super.key,
    required this.card,
    this.onEdit,
    this.isBusy = false,
  });

  final GalleryCard card;
  final VoidCallback? onEdit;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final title = _fallback(card.title, 'Untitled piece');
    final setName = _fallback(card.setName, 'Not assigned');
    final rarity = _fallback(card.rarity, 'Not assigned');
    final rarityCategory = _fallback(card.rarityCategory, 'Not assigned');
    final description = _fallback(card.description, 'No description provided');
    final location = _fallback(card.location, 'Not specified');

    return Container(
      decoration: BoxDecoration(
        color: GalleryColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: GalleryColors.purpleBright.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            onEdit: isBusy ? null : onEdit,
          ),
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: GalleryColors.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoPill(
                      icon: Icons.category_rounded,
                      text: _cardTypeLabel(card.type),
                    ),
                    InfoPill(
                      icon: Icons.flag_rounded,
                      text: _statusLabel(card.status),
                    ),
                    InfoPill(
                      icon: Icons.auto_awesome_rounded,
                      text: rarity,
                    ),
                    InfoPill(
                      icon: Icons.stars_rounded,
                      text: '${card.thotPoints} points',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SummaryRow(
                  label: 'Set',
                  value: setName,
                ),
                SummaryRow(
                  label: 'Rarity category',
                  value: rarityCategory,
                ),
                SummaryRow(
                  label: 'Rarity',
                  value: rarity,
                ),
                SummaryRow(
                  label: 'Card number',
                  value: '${card.cardNumber} / ${card.setTotal}',
                ),
                SummaryRow(
                  label: 'Location',
                  value: location,
                ),
                SummaryRow(
                  label: 'Media',
                  value:
                      '${card.media.length} attached item${card.media.length == 1 ? '' : 's'}',
                ),
                SummaryRow(
                  label: 'Tags',
                  value: card.tags.isEmpty ? 'None' : card.tags.join(', '),
                ),
                SummaryRow(
                  label: 'NFC',
                  value: card.nfcEnabled ? 'Enabled' : 'Disabled',
                  bottomPadding: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static String _cardTypeLabel(GalleryCardType type) {
    return _sentenceCase(type.name);
  }

  static String _statusLabel(GalleryCardStatus status) {
    return _sentenceCase(status.name);
  }

  static String _sentenceCase(String value) {
    final words = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    if (words.isEmpty) {
      return '';
    }

    return '${words[0].toUpperCase()}${words.substring(1)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onEdit,
  });

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: GalleryColors.purpleDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Card Metadata',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onEdit != null)
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit'),
            ),
        ],
      ),
    );
  }
}
