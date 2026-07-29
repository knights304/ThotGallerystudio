import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/gallery_card.dart';
import '../theme/gallery_theme.dart';

class CardBack extends StatefulWidget {
  const CardBack({super.key, required this.card});

  final GalleryCard card;

  @override
  State<CardBack> createState() => _CardBackState();
}

class _CardBackState extends State<CardBack> {
  bool _showQr = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    card.ensureFingerprint();

    return AspectRatio(
      aspectRatio: 0.70,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/thot_gallery_card_back.png',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x08000000),
                    Color(0x08000000),
                    Color(0xB8000000),
                  ],
                  stops: [0, 0.56, 1],
                ),
              ),
            ),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showQr
                    ? Container(
                        key: const ValueKey('qr'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xAA7A25C5),
                              blurRadius: 28,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: card.verificationPayload,
                          size: 165,
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('reveal'),
                        onTap: () => setState(() => _showQr = true),
                        child: Container(
                          width: 190,
                          height: 190,
                          color: Colors.transparent,
                        ),
                      ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xB8140D19),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xAA9C58D0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 17,
                          color: GalleryColors.success,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'VERIFIED LOCAL ORIGINAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        if (card.nfcEnabled)
                          const Icon(
                            Icons.nfc,
                            size: 20,
                            color: GalleryColors.silver,
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _DataLine(label: 'CARD ID', value: card.id),
                    _DataLine(
                      label: 'FINGERPRINT',
                      value: card.shortFingerprint,
                    ),
                    _DataLine(label: 'SET', value: card.setName),
                    _DataLine(
                      label: 'RARITY',
                      value: '${card.rarityCategory} / ${card.rarity}',
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MiniStat(
                          icon: Icons.visibility_outlined,
                          value: card.views,
                        ),
                        _MiniStat(
                          icon: Icons.share_outlined,
                          value: card.shareCount,
                        ),
                        _MiniStat(
                          icon: Icons.photo_outlined,
                          value: card.photoCount,
                        ),
                        _MiniStat(
                          icon: Icons.videocam_outlined,
                          value: card.videoCount,
                        ),
                        _MiniStat(
                          icon: Icons.location_on_outlined,
                          value: card.locationCount,
                        ),
                        _MiniStat(
                          icon: Icons.people_outline,
                          value: card.peopleCount,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: GalleryColors.silver,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showQr
                              ? 'Tap QR button to hide'
                              : 'Tap center logo to reveal QR',
                          style: const TextStyle(
                            color: GalleryColors.silver,
                            fontSize: 8,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${card.cardNumber}/${card.setTotal}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_showQr)
              Positioned(
                top: 18,
                right: 18,
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _showQr = false),
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: GalleryColors.muted,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: GalleryColors.silver),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
