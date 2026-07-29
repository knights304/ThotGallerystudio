import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/gallery_card.dart';
import '../theme/gallery_theme.dart';
import 'card_back.dart';
import 'collectible_card.dart';

class FlippableGalleryCard extends StatefulWidget {
  const FlippableGalleryCard({
    super.key,
    required this.card,
  });

  final GalleryCard card;

  @override
  State<FlippableGalleryCard> createState() => _FlippableGalleryCardState();
}

class _FlippableGalleryCardState extends State<FlippableGalleryCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _glowController;

  bool _showBack = false;
  double _tiltX = 0;
  double _tiltY = 0;
  Offset _shineAlignment = Offset.zero;

  bool get _isPremiumRarity {
    final rarity = widget.card.rarity.toLowerCase();
    return rarity.contains('legendary') ||
        rarity.contains('epic') ||
        rarity.contains('rare');
  }

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..addListener(() {
        final shouldShowBack = _flipController.value >= 0.5;
        if (shouldShowBack != _showBack) {
          setState(() => _showBack = shouldShowBack);
        }
      });

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> flip() async {
    if (_flipController.isAnimating) {
      return;
    }

    await HapticFeedback.selectionClick();

    if (_flipController.value < 0.5) {
      await _flipController.forward();
    } else {
      await _flipController.reverse();
    }
  }

  void _updateTilt(DragUpdateDetails details, Size size) {
    if (size.width == 0 || size.height == 0) {
      return;
    }

    setState(() {
      _tiltY = (details.localPosition.dx / size.width - .5) * .20;
      _tiltX = -(details.localPosition.dy / size.height - .5) * .16;
      _shineAlignment = Offset(
        (details.localPosition.dx / size.width - .5) * 2,
        (details.localPosition.dy / size.height - .5) * 2,
      );
    });
  }

  void _resetTilt() {
    setState(() {
      _tiltX = 0;
      _tiltY = 0;
      _shineAlignment = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: flip,
          onPanUpdate: (details) => _updateTilt(details, size),
          onPanEnd: (_) => _resetTilt(),
          onPanCancel: _resetTilt,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _flipController,
              _glowController,
            ]),
            builder: (context, child) {
              final angle = _flipController.value * math.pi;
              final backAngle = angle - math.pi;
              final glow =
                  _isPremiumRarity ? .22 + (_glowController.value * .18) : .10;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateX(_tiltX)
                  ..rotateY(_tiltY),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: GalleryColors.purpleBright.withValues(
                        alpha: glow,
                      ),
                      blurRadius: _isPremiumRarity ? 34 : 20,
                      spreadRadius: _isPremiumRarity ? 3 : 1,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(_showBack ? backAngle : angle),
                      child: _showBack
                          ? CardBack(card: widget.card)
                          : CollectibleCard(card: widget.card),
                    ),
                    if (!_showBack)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedAlign(
                              alignment: Alignment(
                                _shineAlignment.dx.clamp(-1.0, 1.0).toDouble(),
                                _shineAlignment.dy.clamp(-1.0, 1.0).toDouble(),
                              ),
                              duration: const Duration(milliseconds: 90),
                              child: FractionallySizedBox(
                                widthFactor: .58,
                                heightFactor: 1.25,
                                child: Transform.rotate(
                                  angle: -.34,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.white.withValues(
                                            alpha: _isPremiumRarity ? .20 : .10,
                                          ),
                                          GalleryColors.purpleBright.withValues(
                                            alpha: _isPremiumRarity ? .17 : .07,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _isPremiumRarity ? .95 : .55,
                          duration: const Duration(milliseconds: 250),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .58),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: GalleryColors.purpleBright.withValues(
                                  alpha: .4,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.threesixty_rounded,
                                  size: 14,
                                  color: GalleryColors.silver,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _showBack ? 'BACK' : 'FRONT',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
