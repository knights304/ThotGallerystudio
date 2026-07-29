import 'package:flutter/material.dart';

import '../theme/gallery_theme.dart';

class GradientShell extends StatelessWidget {
  const GradientShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.3,
          colors: [
            Color(0x445D1DA9),
            GalleryColors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
