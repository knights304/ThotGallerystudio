import 'package:flutter/material.dart';

class TgCrest extends StatelessWidget {
  const TgCrest({super.key, this.size = 160, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFFC986FF),
              Color(0xFF6E25B2),
              Color(0xFF12081A),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFE6DBEF),
            width: size * 0.018,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA8B35D0),
              blurRadius: 28,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              size: size * 0.76,
              color: const Color(0xFFE0D7E8),
            ),
            Positioned(
              top: size * 0.15,
              child: Icon(
                Icons.favorite_border,
                size: size * 0.22,
                color: const Color(0xFFC868FF),
              ),
            ),
            Text(
              'TG',
              style: TextStyle(
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
                letterSpacing: size * 0.01,
                color: const Color(0xFFE8E3EC),
                shadows: const [
                  Shadow(color: Color(0xFF8D35D1), blurRadius: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
