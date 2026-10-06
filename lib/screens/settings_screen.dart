import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:rampart/models/profile.dart';
import 'package:rampart/services/authService.dart';
import 'package:rampart/services/fcm_service.dart';
import 'package:rampart/services/profile_service.dart';
import 'package:rampart/services/tab_refresh_bus.dart';
import 'package:rampart/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = const FlutterSecureStorage();

  RampartProfile? _profile;
  bool _loadingProfile = true;
  bool _notificationsEnabled = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    TabRefreshBus.addListener(_onTabSelected);
    _loadSettings();
    _loadProfile();
  }

  @override
  void dispose() {
    TabRefreshBus.removeListener(_onTabSelected);
    super.dispose();
  }

  /// ผู้ใช้เพิ่งกดแท็บ Settings — ProfileService จะยิงเซิร์ฟเวอร์ใหม่เฉพาะตอนที่แคช
  /// ครบ 4 วินาทีแล้วเท่านั้น และถ้าไม่มีเน็ตจะคืนโปรไฟล์ที่บันทึกไว้ในดิสก์
  void _onTabSelected() {
    if (TabRefreshBus.currentIndex != TabRefreshBus.settingsTab) return;
    _loadProfile();
  }

  Future<void> _loadSettings() async {
    final notifStr = await _storage.read(key: 'notif_enabled');

    setState(() {
      _notificationsEnabled = notifStr != 'false';
    });
  }

  Future<void> _loadProfile({bool force = false}) async {
    // แสดง cache ทันทีถ้ามี แล้วค่อยอัปเดตจาก API
    final cached = ProfileService.instance.cached;
    if (cached != null) {
      setState(() {
        _profile = cached;
        _loadingProfile = false;
      });
    }

    final result = await ProfileService.instance.getProfile(force: force);
    if (!mounted) return;

    setState(() {
      if (result.success && result.profile != null) {
        _profile = result.profile;
      }
      _loadingProfile = false;
    });
  }

/// สวิตช์นี้ต้องมีผลสองชั้น
///
/// ค่าในเครื่องคุมแบนเนอร์ตอนแอปอยู่หน้าจอ (อ่านโดย [FcmService]) แต่ตอนแอปอยู่
/// เบื้องหลังระบบปฏิบัติการเป็นคนวาดแจ้งเตือนเองจาก `notification` block โค้ด Dart
/// ไม่มีโอกาสได้ทำงาน ค่าในเครื่องจึงคุมไม่ได้
///
/// ชั้นที่ได้ผลจริงคือฝั่งเซิร์ฟเวอร์: ปิดสวิตช์แล้วถอนอุปกรณ์ออก ไม่มี token ก็
/// ไม่มีการส่งเลย เปิดกลับแล้วลงทะเบียนใหม่
Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _storage.write(key: 'notif_enabled', value: value.toString());

    final service = AuthService();
    if (value) {
      final token = FcmService().deviceToken.value;
      if (token != null) await service.registerFcmToken(token);
    } else {
      await service.unregisterFcmToken();
    }
  }

  Future<void> _navigateToProfileEdit() async {
    final result = await Get.toNamed('/profile-edit');
    if (result is RampartProfile) {
      setState(() => _profile = result);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ฟีเจอร์นี้กำลังอยู่ระหว่างการพัฒนา', style: TextStyle(fontFamily: 'Kanit')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildLogoutDialog(),
    );

    if (confirmed == true && mounted) {
      setState(() => _loggingOut = true);
      await AuthService().unregisterFcmToken();
      await AuthService().clearAuthData();
      if (!mounted) return;
      Get.offAllNamed('/login');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    // created_at มาจากเซิร์ฟเวอร์เป็น UTC ต้องแปลงเป็นเวลาท้องถิ่นก่อนแสดง
    final formatter = DateFormat('d MMMM yyyy', 'th');
    return formatter.format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f172a),
              Theme.of(context).scaffoldBackgroundColor,
              const Color(0xFF1e293b),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildProfileCard(),
                const SizedBox(height: 24),
                _buildSettingsSection(),
                const SizedBox(height: 24),
                _buildAboutSection(),
                const SizedBox(height: 24),
                _buildLogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [customColors.cyanColor, customColors.blueColor],
            ).createShader(bounds);
          },
          child: const Text(
            'ตั้งค่า',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'จัดการบัญชีและการตั้งค่า',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 14,
            color: customColors.hintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    if (_loadingProfile && _profile == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: customColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final avatarUrl = ProfileService.resolveAvatarUrl(_profile?.avatarUrl);
    final username = _profile?.username ?? 'ผู้ใช้';
    final email = _profile?.email ?? '';
    final role = _profile?.roleLabel ?? '';
    final createdAt = _profile?.createdAt;

    return InkWell(
      onTap: _navigateToProfileEdit,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: customColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: customColors.cyanColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        cacheWidth: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
                        cacheHeight: (60 * MediaQuery.devicePixelRatioOf(context)).round(),
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(username),
                      )
                    : _buildAvatarFallback(username),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 13,
                        color: customColors.hintColor,
                      ),
                    ),
                  ],
                  if (role.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        color: customColors.cyanColor,
                      ),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'เข้าร่วมเมื่อ ${_formatDate(createdAt)}',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 10,
                        color: customColors.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: customColors.cyanColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String username) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [customColors.cyanColor, customColors.blueColor],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ทั่วไป',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.person_outline,
          title: 'แก้ไขโปรไฟล์',
          subtitle: 'จัดการข้อมูลส่วนตัวของคุณ',
          trailing: Icon(Icons.chevron_right, color: customColors.hintColor),
          onTap: _navigateToProfileEdit,
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.lock_reset,
          title: 'เปลี่ยนรหัสผ่าน',
          subtitle: 'ตั้งรหัสผ่านใหม่สำหรับบัญชีนี้',
          trailing: Icon(Icons.chevron_right, color: customColors.hintColor),
          onTap: () => Get.toNamed('/reset-password'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.history,
          title: 'ประวัติการเข้าสู่ระบบ',
          subtitle: 'ดูรายการเข้าสู่ระบบล่าสุด',
          trailing: Icon(Icons.chevron_right, color: customColors.hintColor),
          onTap: () => Get.toNamed('/activity-history', arguments: 'login'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.download_outlined,
          title: 'ประวัติการดาวน์โหลด',
          subtitle: 'ดูรายการไฟล์ที่ดาวน์โหลด',
          trailing: Icon(Icons.chevron_right, color: customColors.hintColor),
          onTap: () => Get.toNamed('/activity-history', arguments: 'download'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.help_outline,
          title: 'ช่วยเหลือและวิธีการใช้งาน',
          subtitle: 'คู่มือและคำถามที่พบบ่อย',
          trailing: Icon(Icons.chevron_right, color: customColors.hintColor),
          onTap: () => Get.toNamed('/help'),
        ),
        const SizedBox(height: 12),
        _buildSettingCard(
          icon: Icons.notifications_outlined,
          title: 'การแจ้งเตือน',
          subtitle: 'รับการแจ้งเตือนเมื่อการวิเคราะห์เสร็จสิ้น',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: _toggleNotifications,
            activeColor: customColors.cyanColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: customColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: customColors.cyanColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: customColors.cyanColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: customColors.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เกี่ยวกับ',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.info_outline,
          title: 'เวอร์ชัน',
          value: '1.0.0',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.article_outlined,
          title: 'เงื่อนไขการใช้งาน',
          value: '',
          onTap: _showComingSoon,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.privacy_tip_outlined,
          title: 'นโยบายความเป็นส่วนตัว',
          value: '',
          onTap: _showComingSoon,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: customColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: customColors.cyanColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 13,
                  color: customColors.hintColor,
                ),
              ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: customColors.hintColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
        ),
      ),
      child: ElevatedButton(
        onPressed: _loggingOut ? null : _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loggingOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout, size: 22),
                  SizedBox(width: 12),
                  Text(
                    'ออกจากระบบ',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLogoutDialog() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return AlertDialog(
      backgroundColor: customColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 12),
          Text(
            'ออกจากระบบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Text(
        'คุณต้องการออกจากระบบใช่หรือไม่?',
        style: TextStyle(
          fontFamily: 'Kanit',
          color: customColors.hintColor,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'ยกเลิก',
            style: TextStyle(
              fontFamily: 'Kanit',
              color: customColors.hintColor,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'ออกจากระบบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
