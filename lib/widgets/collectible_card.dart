import 'dart:io';

import 'package:flutter/material.dart';

import '../models/gallery_card.dart';
import '../theme/gallery_theme.dart';

class CollectibleCard extends StatefulWidget {
  const CollectibleCard({
    super.key,
    required this.card,
    this.onTap,
    this.compact = false,
  });

  final GalleryCard card;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<CollectibleCard> createState() => _CollectibleCardState();
}

class _CollectibleCardState extends State<CollectibleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  GalleryCard get card => widget.card;

  @override
  void initState() {
    super.initState();

    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(period: const Duration(milliseconds: 4300));
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  IconData get _typeIcon => switch (card.type) {
        GalleryCardType.profile => Icons.badge_rounded,
        GalleryCardType.galleryPiece => Icons.collections_rounded,
        GalleryCardType.rateMe => Icons.star_rate_rounded,
        GalleryCardType.matchMyFreak => Icons.favorite_rounded,
        GalleryCardType.location => Icons.location_on_rounded,
        GalleryCardType.activity => Icons.casino_rounded,
        GalleryCardType.person => Icons.person_rounded,
        GalleryCardType.interest => Icons.favorite_outline_rounded,
        GalleryCardType.mystery => Icons.help_rounded,
        GalleryCardType.thot => Icons.local_fire_department_rounded,
      };

  String get _typeLabel => switch (card.type) {
        GalleryCardType.profile => 'PROFILE',
        GalleryCardType.galleryPiece => 'GALLERY PIECE',
        GalleryCardType.rateMe => 'RATE ME',
        GalleryCardType.matchMyFreak => 'MATCH MY FREAK',
        GalleryCardType.location => 'LOCATION',
        GalleryCardType.activity => 'ACTIVITY',
        GalleryCardType.person => 'PERSON',
        GalleryCardType.interest => 'INTEREST',
        GalleryCardType.mystery => 'MYSTERY',
        GalleryCardType.thot => 'THOT CARD',
      };

  List<Color> get _templateColors => switch (card.template) {
        GalleryCardTemplate.royalPurple => const [
            Color(0xFFB76AF3),
            Color(0xFF3A0F5E),
            Color(0xFF16071F),
          ],
        GalleryCardTemplate.blackChrome => const [
            Color(0xFFB8BBC3),
            Color(0xFF202027),
            Color(0xFF050507),
          ],
        GalleryCardTemplate.silverNeon => const [
            Color(0xFFF0F2F8),
            Color(0xFF7652A6),
            Color(0xFF24212B),
          ],
        GalleryCardTemplate.neonBattle => const [
            Color(0xFFBF4DFF),
            Color(0xFF551080),
            Color(0xFF12051D),
          ],
      };

  List<Color> get _rarityColors {
    final rarity = '${card.rarityCategory} ${card.rarity}'.toLowerCase();

    if (rarity.contains('one of one') || rarity.contains('legendary')) {
      return const [
        Color(0xFFFFD66D),
        Color(0xFFFF8A42),
        Color(0xFF6722A6),
      ];
    }

    if (rarity.contains('certified') || rarity.contains('epic')) {
      return const [
        Color(0xFFD5D8DF),
        Color(0xFF8A35CF),
        Color(0xFFF1E9F5),
      ];
    }

    if (rarity.contains('rare')) {
      return const [
        Color(0xFFD6D8E1),
        Color(0xFF5F2B91),
        Color(0xFFA28CB6),
      ];
    }

    return const [
      Color(0xFF8B36D2),
      Color(0xFF290D41),
      Color(0xFFB672F0),
    ];
  }

  BoxFit get _fit => switch (card.imageFit) {
        GalleryImageFit.cover => BoxFit.cover,
        GalleryImageFit.contain => BoxFit.contain,
        GalleryImageFit.fill => BoxFit.fill,
      };

  @override
  Widget build(BuildContext context) {
    final hasImage = card.coverImagePath != null &&
        File(card.coverImagePath!).existsSync();

    final lockedMystery = card.type == GalleryCardType.mystery &&
        card.status != GalleryCardStatus.completed;

    return AspectRatio(
      aspectRatio: 0.70,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedBuilder(
            animation: _shine,
            builder: (context, child) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: card.rarity.toLowerCase() == 'original'
                            ? _templateColors
                            : _rarityColors,
                      ),
                      border: Border.all(
                        color: const Color(0xFFE8DFF1),
                        width: widget.compact ? 1.2 : 2.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x665D1DA9),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(widget.compact ? 7 : 11),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: GalleryColors.surface,
                        border: Border.all(
                          color: const Color(0xFFBBAFC8),
                          width: 1.4,
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              widget.compact ? 9 : 13,
                              widget.compact ? 8 : 11,
                              widget.compact ? 8 : 11,
                              widget.compact ? 6 : 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lockedMystery
                                        ? 'MYSTERY CARD'
                                        : card.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: widget.compact ? 12 : 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${card.thotPoints}',
                                  style: TextStyle(
                                    fontSize: widget.compact ? 11 : 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '👅',
                                  style: TextStyle(
                                    fontSize: widget.compact ? 15 : 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.compact ? 8 : 12,
                            ),
                            child: Container(
                              height: widget.compact ? 16 : 23,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4C166F),
                                    Color(0xFFB655F2),
                                    Color(0xFF3C115C),
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _typeIcon,
                                    size: widget.compact ? 10 : 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _typeLabel,
                                    style: TextStyle(
                                      fontSize: widget.compact ? 8 : 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: widget.compact ? 5 : 8),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.compact ? 8 : 12,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  border: Border.all(
                                    color: const Color(0xFFE0D8E7),
                                    width: widget.compact ? 1.4 : 2.3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x553F155E),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: ClipRect(
                                  child: lockedMystery
                                      ? const _MysteryArtwork()
                                      : hasImage
                                          ? Image.file(
                                              File(card.coverImagePath!),
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: _fit,
                                              alignment: Alignment(
                                                card.imageAlignmentX,
                                                card.imageAlignmentY,
                                              ),
                                            )
                                          : _FallbackArtwork(
                                              icon: _typeIcon,
                                            ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              widget.compact ? 8 : 12,
                              widget.compact ? 7 : 10,
                              widget.compact ? 8 : 12,
                              widget.compact ? 8 : 12,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(widget.compact ? 7 : 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E2EC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF8D699B),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${card.rarity.toUpperCase()} • '
                                    '${card.setName.toUpperCase()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF25162B),
                                      fontSize: widget.compact ? 8 : 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    lockedMystery
                                        ? 'Complete this mystery to reveal '
                                            'its contents.'
                                        : card.description.isEmpty
                                            ? 'Tap to open this Gallery Card.'
                                            : card.description,
                                    maxLines: widget.compact ? 2 : 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFF25162B),
                                      fontSize: widget.compact ? 8 : 11.5,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      if (card.rating > 0) ...[
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFF7428AD),
                                          size: 14,
                                        ),
                                        Text(
                                          card.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Color(0xFF25162B),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        'TG-${card.id.hashCode.abs().toString().padLeft(4, '0').substring(0, 4)}',
                                        style: TextStyle(
                                          color: const Color(0xFF25162B),
                                          fontSize: widget.compact ? 7 : 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.compact)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ShinePainter(
                            progress: _shine.value,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF9D46E6),
            Color(0xFF2A123D),
            Color(0xFF070609),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 84,
          color: const Color(0xEEFFFFFF),
        ),
      ),
    );
  }
}

class _MysteryArtwork extends StatelessWidget {
  const _MysteryArtwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFF6F2CB2),
            Color(0xFF1B0D26),
            Color(0xFF050407),
          ],
        ),
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE1D6EA),
            shadows: [
              Shadow(
                color: Color(0xFF9A43DE),
                blurRadius: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShinePainter extends CustomPainter {
  const _ShinePainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = (size.width * 1.8 * progress) - size.width * 0.4;

    final path = Path()
      ..moveTo(x - 50, 0)
      ..lineTo(x + 25, 0)
      ..lineTo(x - 30, size.height)
      ..lineTo(x - 105, size.height)
      ..close();

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x00FFFFFF),
          Color(0x44FFFFFF),
          Color(0x00FFFFFF),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
