import 'package:flutter/material.dart';

/// โลโก้ RAMPART บนพื้นหลังสีขาว (โลโก้เดิมเป็นตัวอักษรสีขาวล้วน
/// จึงต้องมีพื้นขาวรองรับ ไม่งั้นจะกลืนกับฉากหลังของแอป)
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
        // จำกัดขนาด decode ตามพื้นที่แสดงจริง (R8) — ภาพต้นฉบับ 1024px
        cacheWidth: (size * dpr).round(),
        cacheHeight: (size * dpr).round(),
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
