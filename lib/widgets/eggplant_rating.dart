import 'package:flutter/material.dart';

class EggplantRating extends StatelessWidget {
  const EggplantRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 42,
    this.showValue = true,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double size;
  final bool showValue;

  bool get editable => onChanged != null;

  void _handleTap({
    required int index,
    required TapDownDetails details,
    required double cellWidth,
  }) {
    if (!editable) {
      return;
    }

    final tappedHalf = details.localPosition.dx < cellWidth / 2;

    final rating = tappedHalf ? index + 0.5 : index + 1.0;

    onChanged!(rating);
  }

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 5.0).toDouble();

    // Android color emoji glyphs can render wider than
    // their nominal font size. Giving each eggplant a
    // slightly wider cell prevents full ratings from
    // getting clipped on the right side.
    final cellWidth = size * 1.28;
    final cellHeight = size * 1.16;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final amount = (safeValue - index).clamp(0.0, 1.0).toDouble();

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: editable
                  ? (details) {
                      _handleTap(
                        index: index,
                        details: details,
                        cellWidth: cellWidth,
                      );
                    }
                  : null,
              child: SizedBox(
                width: cellWidth,
                height: cellHeight,
                child: _EggplantFill(amount: amount, fontSize: size),
              ),
            );
          }),
        ),
        if (showValue) ...[
          const SizedBox(height: 7),
          Text(
            safeValue == 0.0
                ? 'Tap an eggplant to rate'
                : '${safeValue.toStringAsFixed(1)} / 5.0',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: editable ? const Color(0xFFC4B5FD) : Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}

class _EggplantFill extends StatelessWidget {
  const _EggplantFill({required this.amount, required this.fontSize});

  final double amount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const eggplant = '🍆';

    final emptyEggplant = Center(
      child: Opacity(
        opacity: 0.18,
        child: Text(
          eggplant,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: fontSize, height: 1),
        ),
      ),
    );

    final filledEggplant = Center(
      child: Text(
        eggplant,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: fontSize, height: 1),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        emptyEggplant,
        if (amount > 0.0)
          ClipRect(
            clipper: _HorizontalFractionClipper(amount),
            child: filledEggplant,
          ),
      ],
    );
  }
}

class _HorizontalFractionClipper extends CustomClipper<Rect> {
  const _HorizontalFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    final safeFraction = fraction.clamp(0.0, 1.0).toDouble();

    return Rect.fromLTWH(0, 0, size.width * safeFraction, size.height);
  }

  @override
  bool shouldReclip(_HorizontalFractionClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}
