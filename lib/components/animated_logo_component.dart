import 'package:flutter/material.dart';

class AnimatedLogoComponent extends StatelessWidget {
  final AnimationController pulseController;
  final AnimationController rotationController;
  final AnimationController shimmerController;
  final String imagePath;
  final double size;

  const AnimatedLogoComponent({
    super.key,
    required this.pulseController,
    required this.rotationController,
    required this.shimmerController,
    this.imagePath = 'assets/images/logo_none_white2.png',
    this.size = 140.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        pulseController,
        rotationController,
        shimmerController,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 1.15, 
              height: size * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            // ส่วนของตัวโลโก้
            SizedBox(
              width: size,
              height: size,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        );
      },
    );
  }
}