import 'package:flutter/material.dart';

import '../services/tab_refresh_bus.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import 'dashboard_screen.dart';
import 'submit_file_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // List of screens
  final List<Widget> _screens = [
    const DashboardScreen(),
    const SubmitFileScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // หน้าอื่น (เช่นปุ่ม "ดูเพิ่มเติม" ของกิจกรรมล่าสุดบน dashboard) สลับแท็บ
    // ผ่าน TabRefreshBus.select() ได้ — MainScreen ต้องฟังด้วยจึงจะย้าย
    // IndexedStack ตาม เพราะการเรียก select() เองไม่ได้ setState ที่นี่
    TabRefreshBus.addListener(_onTabBusTick);
  }

  @override
  void dispose() {
    TabRefreshBus.removeListener(_onTabBusTick);
    super.dispose();
  }

  void _onTabBusTick() {
    if (!mounted) return;
    if (_currentIndex == TabRefreshBus.currentIndex) return;
    setState(() => _currentIndex = TabRefreshBus.currentIndex);
  }

  // ใช้สีจาก Theme
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // IndexedStack ไม่ทิ้ง state ของแท็บที่เพิ่งออกจาก (R6 ใน AGENTS.md) —
            // ถ้าใช้ _screens[_currentIndex] แอปจะ refetch และวาดใหม่ทุกครั้งที่สลับแท็บ
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.upload_file_outlined,
                  activeIcon: Icons.upload_file,
                  label: 'Submit',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  label: 'Reports',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          // แท็บถูกสร้างค้างไว้ใน IndexedStack จึงไม่มี initState ใหม่ตอนสลับ —
          // บัสนี้คือทางเดียวที่หน้าจอจะรู้ว่า "ถึงตาตัวเองแล้ว" ส่วนจะยิงเซิร์ฟเวอร์
          // จริงหรือใช้แคชเดิมเป็นการตัดสินใจของ TabCache (อายุ 4 วินาที)
          TabRefreshBus.select(index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? _cyanColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? _cyanColor.withOpacity(0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? _cyanColor : _hintColor,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontFamily: 'Kanit', 
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _cyanColor : _hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
