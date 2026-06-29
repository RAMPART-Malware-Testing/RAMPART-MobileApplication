import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rampart/components/animated_logo_component.dart';
import 'package:rampart/controllers/PIN_controller.dart';
import '../theme/app_theme.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({Key? key}) : super(key: key);

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PINController());
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cyanColor = Theme.of(context).extension<CustomColors>()?.cyanColor ?? const Color(0xff06b6d4);
    final hintColor = Theme.of(context).extension<CustomColors>()?.hintColor ?? const Color(0xff94a3b8);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f172a),
              backgroundColor,
              const Color(0xFF1e293b)
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedLogoComponent(
                    pulseController: _pulseController,
                    rotationController: _rotationController,
                    shimmerController: _shimmerController,
                    size: 140,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'RAMPART',
                    style: GoogleFonts.kanit(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: cyanColor.withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SECURITY PIN',
                    style: GoogleFonts.kanit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'กรุณากรอกรหัส PIN 6 หลักเพื่อเข้าใช้งานแอปพลิเคชัน',
                    style: GoogleFonts.kanit(fontSize: 14, color: hintColor),
                  ),
                  const SizedBox(height: 32),
                  Obx(() => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          bool isFilled = index < controller.pin.value.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? cyanColor : Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: isFilled ? cyanColor : Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: isFilled
                                  ? [
                                      BoxShadow(
                                          color: cyanColor.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 1)
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      )),
                  const SizedBox(height: 16),
                  Obx(() => controller.isLoading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const SizedBox(height: 20)),
                  const SizedBox(height: 32),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          return IconButton(
                            icon: Icon(Icons.logout, color: hintColor, size: 28),
                            onPressed: () {
                              Get.offAllNamed('/login');
                            },
                          );
                        }
                        if (index == 11) {
                          return IconButton(
                            icon: Icon(Icons.backspace_outlined, color: cyanColor, size: 28),
                            onPressed: controller.deleteDigit,
                          );
                        }
                        int number = index == 10 ? 0 : index + 1;
                        return _buildKeypadButton(
                          number: number,
                          onPressed: () => controller.addDigit(number, isSetupMode: false),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton({required int number, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: GoogleFonts.kanit(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}