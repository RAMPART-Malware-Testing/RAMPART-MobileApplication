import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/notification_service.dart';
import '../services/tab_refresh_bus.dart';
import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import 'dashboard_screen.dart';
import 'public_reports_screen.dart';
import 'submit_file_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const int reportsTab = 2;

  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SubmitFileScreen(),
    ReportsScreen(),
    PublicReportsScreen(asTab: true),
    SettingsScreen(),
  ];

  NotificationService get _notifications =>
      Get.isRegistered<NotificationService>()
      ? Get.find<NotificationService>()
      : NotificationService();

  @override
  void initState() {
    super.initState();
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

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    TabRefreshBus.select(index);
    if (index == reportsTab) _notifications.clear();
  }

  Color get _cardColor => Theme.of(context).cardColor;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;
  Color get _failedColor =>
      Theme.of(context).extension<CustomColors>()!.failedColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _cardColor,
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
                  badgeColor: _failedColor,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.public_outlined,
                  activeIcon: Icons.public,
                  label: 'Public',
                ),
                _buildNavItem(
                  index: 4,
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
    Color? badgeColor,
  }) {
    final isActive = _currentIndex == index;
    final color = isActive ? _cyanColor : _hintColor;

    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? _cyanColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? _cyanColor.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isActive ? activeIcon : icon, color: color, size: 26),
                  if (index == reportsTab)
                    Positioned(
                      top: -7,
                      right: -9,
                      child: Obx(() {
                        final count = _notifications.count;
                        if (count <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor ?? _failedColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}