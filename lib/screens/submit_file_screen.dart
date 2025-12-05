import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../models/file_upload.dart';
import '../services/file_upload_service.dart';

class SubmitFileScreen extends StatefulWidget {
  const SubmitFileScreen({Key? key}) : super(key: key);

  @override
  State<SubmitFileScreen> createState() => _SubmitFileScreenState();
}

class _SubmitFileScreenState extends State<SubmitFileScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final FileUploadService _uploadService = FileUploadService();

  // File state
  File? _selectedFile;
  SelectedFileInfo? _fileInfo;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  // Visibility state (default = private)
  bool _isPublic = false;

  // Optional description
  final TextEditingController _descriptionController = TextEditingController();

  // ใช้สีจาก Theme
  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _blueColor =>
      Theme.of(context).extension<CustomColors>()!.blueColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      // เปิด file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        final extension = result.files.single.extension;

        // ตรวจสอบขนาดไฟล์ (สูงสุด 100MB)
        const maxSize = 100 * 1024 * 1024; // 100MB
        if (fileSize > maxSize) {
          setState(() {
            _error = 'ขนาดไฟล์เกิน 100MB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า';
          });
          return;
        }

        setState(() {
          _selectedFile = file;
          _fileInfo = SelectedFileInfo(
            name: fileName,
            path: file.path,
            size: fileSize,
            extension: extension,
          );
          _error = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'เลือกไฟล์: $fileName',
                      style: GoogleFonts.kanit(),
                    ),
                  ),
                ],
              ),
              backgroundColor: _cyanColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการเลือกไฟล์: $e';
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _fileInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'กรุณาเลือกไฟล์ก่อนอัปโหลด',
                  style: GoogleFonts.kanit(),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    try {
      // TODO: ดึง token จาก storage หรือ state management
      const token = 'your_auth_token_here';

      // Simulate upload progress (ในการใช้งานจริงจะได้รับจาก API)
      _simulateProgress();

      await _uploadService.uploadFile(
        file: _selectedFile!,
        fileName: _fileInfo!.name,
        isPublic: _isPublic,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        token: token,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      setState(() {
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      // แสดง success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'อัปโหลดไฟล์สำเร็จ!',
                        style: GoogleFonts.kanit(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'กำลังเริ่มวิเคราะห์... (${_isPublic ? 'Public' : 'Private'})',
                        style: GoogleFonts.kanit(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Reset form
      await Future.delayed(const Duration(seconds: 1));
      _resetForm();
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error ?? 'เกิดข้อผิดพลาด',
                    style: GoogleFonts.kanit(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _simulateProgress() {
    // Simulate progress for better UX
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isUploading && mounted) {
        setState(() {
          if (_uploadProgress < 0.3) {
            _uploadProgress = 0.3;
          }
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isUploading && mounted) {
        setState(() {
          if (_uploadProgress < 0.6) {
            _uploadProgress = 0.6;
          }
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_isUploading && mounted) {
        setState(() {
          if (_uploadProgress < 0.9) {
            _uploadProgress = 0.9;
          }
        });
      }
    });
  }

  void _resetForm() {
    setState(() {
      _selectedFile = null;
      _fileInfo = null;
      _isPublic = false;
      _uploadProgress = 0.0;
      _error = null;
      _descriptionController.clear();
    });
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
              _backgroundColor,
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
                _buildUploadCard(),
                const SizedBox(height: 16),
                if (_fileInfo != null) _buildFileInfoCard(),
                if (_fileInfo != null) const SizedBox(height: 16),
                if (_fileInfo != null) _buildVisibilityCard(),
                if (_fileInfo != null) const SizedBox(height: 16),
                if (_fileInfo != null) _buildDescriptionCard(),
                const SizedBox(height: 24),
                _buildInfoCards(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [_cyanColor, _blueColor],
            ).createShader(bounds);
          },
          child: Text(
            'ส่งไฟล์วิเคราะห์',
            style: GoogleFonts.kanit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'อัปโหลดไฟล์เพื่อตรวจสอบมัลแวร์',
          style: GoogleFonts.kanit(
            fontSize: 14,
            color: _hintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _error != null
                  ? Colors.red.withOpacity(0.5)
                  : Colors.white
                      .withOpacity(0.1 + (_pulseController.value * 0.05)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: (_error != null ? Colors.red : _cyanColor)
                    .withOpacity(0.1 + (_pulseController.value * 0.1)),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Upload Icon/Area
              GestureDetector(
                onTap: _isUploading ? null : _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: _cyanColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _cyanColor.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _fileInfo != null
                            ? Icons.insert_drive_file
                            : Icons.cloud_upload_outlined,
                        size: 64,
                        color: _cyanColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _fileInfo?.name ?? 'คลิกเพื่อเลือกไฟล์',
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileInfo != null
                            ? 'ขนาด: ${_fileInfo!.displaySize}'
                            : 'รองรับไฟล์ทุกประเภท (ขนาดสูงสุด 100MB)',
                        style: GoogleFonts.kanit(
                          fontSize: 12,
                          color: _hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.kanit(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Upload Progress
              if (_isUploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_cyanColor),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Text(
                  'กำลังอัปโหลด ${(_uploadProgress * 100).toInt()}%',
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: _cyanColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Upload Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cyanColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: _cyanColor.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isUploading ? Icons.hourglass_empty : Icons.upload,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isUploading ? 'กำลังอัปโหลด...' : 'อัปโหลดและวิเคราะห์',
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: _cyanColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'ข้อมูลไฟล์',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('ชื่อไฟล์', _fileInfo!.name),
          const SizedBox(height: 8),
          _buildInfoRow('ขนาด', _fileInfo!.displaySize),
          if (_fileInfo!.extension != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('ประเภท', '.${_fileInfo!.extension}'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.kanit(
              fontSize: 13,
              color: _hintColor,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.kanit(
              fontSize: 13,
              color: _textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isPublic
              ? _cyanColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPublic ? Icons.public : Icons.lock,
                color: _isPublic ? _cyanColor : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'การมองเห็น',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPublic ? 'Public' : 'Private',
                      style: GoogleFonts.kanit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isPublic
                          ? 'ผลการวิเคราะห์จะเป็นสาธารณะ'
                          : 'ผลการวิเคราะห์เป็นส่วนตัว (ค่าเริ่มต้น)',
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        color: _hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPublic,
                onChanged: _isUploading
                    ? null
                    : (value) {
                        setState(() {
                          _isPublic = value;
                        });
                      },
                activeTrackColor: _cyanColor,
                inactiveThumbColor: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: _cyanColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'คำอธิบาย (ไม่บังคับ)',
                style: GoogleFonts.kanit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            enabled: !_isUploading,
            maxLines: 3,
            maxLength: 200,
            style: GoogleFonts.kanit(
              color: _textColor,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'เพิ่มคำอธิบายเกี่ยวกับไฟล์นี้...',
              hintStyle: GoogleFonts.kanit(
                color: _hintColor,
                fontSize: 13,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _cyanColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              counterStyle: GoogleFonts.kanit(
                color: _hintColor,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ข้อมูลที่ควรทราบ',
          style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.security,
          title: 'การรักษาความปลอดภัย',
          description: 'ไฟล์ของคุณจะถูกเข้ารหัสและจัดเก็บอย่างปลอดภัย',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.speed,
          title: 'การวิเคราะห์รวดเร็ว',
          description: 'ผลการวิเคราะห์จะพร้อมภายใน 2-5 นาที',
          color: _cyanColor,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.analytics,
          title: 'รายงานละเอียด',
          description: 'รับรายงานการวิเคราะห์แบบละเอียดทุกประการ',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.lock,
          title: 'ความเป็นส่วนตัว',
          description:
              'ไฟล์ Private จะมองเห็นได้เฉพาะคุณเท่านั้น (ค่าเริ่มต้น)',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    color: _hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
