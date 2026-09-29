import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rampart/models/profile.dart';
import 'package:rampart/services/profile_service.dart';
import 'package:rampart/theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  RampartProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final result = await ProfileService.instance.getProfile();
    if (!mounted) return;

    if (result.success && result.profile != null) {
      setState(() {
        _profile = result.profile;
        _usernameController.text = result.profile!.username;
        _avatarUrl = ProfileService.resolveAvatarUrl(result.profile!.avatarUrl);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      _showSnackBar(result.message, isError: true);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) {
      _showSnackBar('ไม่สามารถเข้าถึงไฟล์ที่เลือกได้', isError: true);
      return;
    }

    final file = File(pickedFile.path!);
    setState(() => _uploadingAvatar = true);

    final uploadResult = await ProfileService.instance.uploadAvatar(file);

    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (uploadResult.success && uploadResult.profile != null) {
      setState(() {
        _profile = uploadResult.profile;
        _avatarUrl = ProfileService.resolveAvatarUrl(uploadResult.profile!.avatarUrl);
      });
      _showSnackBar('เปลี่ยนรูปโปรไฟล์สำเร็จ');
    } else {
      _showSnackBar(uploadResult.message, isError: true);
    }
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);
    final result = await ProfileService.instance.updateUsername(_usernameController.text);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.success && result.profile != null) {
      _showSnackBar('บันทึกข้อมูลสำเร็จ');
      Get.back(result: result.profile);
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Kanit')),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0f172a),
              bgColor,
              const Color(0xFF1e293b),
            ],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(customColors),
                        const SizedBox(height: 32),
                        _buildAvatarSection(customColors),
                        const SizedBox(height: 24),
                        _buildUsernameField(customColors),
                        const SizedBox(height: 16),
                        _buildReadOnlyField('อีเมล', _profile?.email ?? ''),
                        const SizedBox(height: 16),
                        _buildReadOnlyField('บทบาท', _profile?.roleLabel ?? ''),
                        const SizedBox(height: 32),
                        _buildSaveButton(customColors),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(CustomColors customColors) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back, color: customColors.cyanColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [customColors.cyanColor, customColors.blueColor],
              ).createShader(bounds);
            },
            child: const Text(
              'แก้ไขโปรไฟล์',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(CustomColors customColors) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: customColors.cyanColor.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _avatarUrl != null
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: (120 * MediaQuery.devicePixelRatioOf(context)).round(),
                          cacheHeight: (120 * MediaQuery.devicePixelRatioOf(context)).round(),
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
                        )
                      : _buildAvatarFallback(),
                ),
              ),
              if (_uploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text(
              'เปลี่ยนรูปโปรไฟล์',
              style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.cyanColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final initial = (_profile?.username.isNotEmpty == true)
        ? _profile!.username[0].toUpperCase()
        : '?';
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
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField(CustomColors customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ชื่อผู้ใช้',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: customColors.hintColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _usernameController,
          style: const TextStyle(fontFamily: 'Kanit', color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: customColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: customColors.cyanColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'กรุณากรอกชื่อผู้ใช้';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: customColors.hintColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customColors.cardBackground.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 15,
              color: customColors.hintColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(CustomColors customColors) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveUsername,
        style: ElevatedButton.styleFrom(
          backgroundColor: customColors.cyanColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: customColors.cyanColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'บันทึกข้อมูล',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
