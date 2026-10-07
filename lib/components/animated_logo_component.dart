import 'package:flutter/material.dart';

class AnimatedLogoComponent extends StatelessWidget {
  final String imagePath;
  final double size;

  const AnimatedLogoComponent({
    super.key,
    this.imagePath = 'assets/images/logo_bg_white.png',
    this.size = 140.0,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        cacheHeight: (size * dpr).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
