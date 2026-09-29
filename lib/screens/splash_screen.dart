import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  final double logoSize;

  const SplashScreen({super.key, this.logoSize = 220});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.splashBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: Image.asset(
                  'assets/icon/splash_logo.png',
                  fit: BoxFit.contain,
                  cacheWidth:
                      (logoSize * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'RAMPART',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
