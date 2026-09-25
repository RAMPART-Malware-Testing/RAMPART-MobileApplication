import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/file_upload.dart';
import '../services/analysis_service.dart';
import '../services/pin_service.dart';
import '../widgets/analysis_components.dart';

class SubmitFileScreen extends StatefulWidget {
  const SubmitFileScreen({super.key});

  @override
  State<SubmitFileScreen> createState() => _SubmitFileScreenState();
}

class _SubmitFileScreenState extends State<SubmitFileScreen> {
  final AnalysisService _analysisService = AnalysisService();

  File? _selectedFile;
  SelectedFileInfo? _fileInfo;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String? _error;

  Future<void> _pickFile() async {
    try {
      if (Get.isRegistered<PINService>()) {
        Get.find<PINService>().suppressLockBriefly();
      }
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (!mounted || result == null) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) return;
      if (picked.size > AnalysisService.maxUploadBytes) {
        setState(
          () => _error = 'ขนาดไฟล์เกิน 1GB กรุณาเลือกไฟล์ที่มีขนาดเล็กกว่า',
        );
        return;
      }

      setState(() {
        _selectedFile = File(path);
        _fileInfo = SelectedFileInfo(
          name: picked.name,
          path: path,
          size: picked.size,
          extension: picked.extension,
        );
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'เกิดข้อผิดพลาดในการเลือกไฟล์: $error');
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null || _fileInfo == null) {
      await _pickFile();
      if (!mounted || _selectedFile == null || _fileInfo == null) return;
    }
    await _startUpload();
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _error = null;
    });

    try {
      final result = await _analysisService.uploadFile(
        file: _selectedFile!,
        fileName: _fileInfo!.name,
        privacy: true,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() => _uploadProgress = sent / total);
        },
      );
      if (!mounted) return;
      if (!result.success || result.taskId == null) {
        setState(() {
          _isUploading = false;
          _error = result.message.isEmpty ? 'อัปโหลดไม่สำเร็จ' : result.message;
        });
        return;
      }

      setState(() {
        _isUploading = false;
        _uploadProgress = 1;
      });

      final reused = result.isReused;
      final completedReuse = result.isCompletedReuse;
      final gapFilled = result.isGapFilled;

      if (reused && completedReuse) {
        _showMessage(
          'พบไฟล์นี้ในระบบแล้ว กำลังเปิดผลวิเคราะห์เดิม',
          AnalysisColors.completed,
          Icons.verified_outlined,
        );
      } else if (reused) {
        _showMessage(
          'พบไฟล์นี้กำลังวิเคราะห์อยู่ กำลังติดตามงานเดิม',
          AnalysisColors.cyan,
          Icons.hourglass_top,
        );
      } else if (gapFilled) {
        _showMessage(
          'พบไฟล์นี้เดิม กำลังวิเคราะห์ส่วนที่ขาด',
          AnalysisColors.purple,
          Icons.refresh,
        );
      } else {
        _showMessage(
          'อัปโหลดสำเร็จ กำลังวิเคราะห์...',
          AnalysisColors.completed,
          Icons.check_circle,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _resetForm();
      final route = completedReuse ? '/analysis-result' : '/analysis-progress';
      Get.toNamed(route, arguments: result.taskId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _resetForm() {
    setState(() {
      _selectedFile = null;
      _fileInfo = null;
      _uploadProgress = 0;
      _error = null;
    });
  }

  void _showMessage(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontFamily: 'Kanit')),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AnalysisColors.background, AnalysisColors.surface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildDropzone(),
                if (_fileInfo != null) ...[
                  const SizedBox(height: 14),
                  _buildFileInfo(),
                  const SizedBox(height: 14),
                  _buildPrivacy(),
                ],
                const SizedBox(height: 22),
                _buildInfo(),
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
        const Text(
          'สแกนไฟล์',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'อัปโหลดไฟล์เพื่อวิเคราะห์มัลแวร์ด้วยเครื่องมือหลายตัว',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 13,
            color: AnalysisColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDropzone() {
    return AnalysisCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          InkWell(
            onTap: _isUploading ? null : _pickFile,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
              decoration: BoxDecoration(
                color: AnalysisColors.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _error == null
                      ? AnalysisColors.cyan.withValues(alpha: 0.35)
                      : AnalysisColors.failed.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _fileInfo == null
                        ? Icons.cloud_upload_outlined
                        : Icons.insert_drive_file,
                    size: 58,
                    color: AnalysisColors.cyan,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _fileInfo?.name ?? 'คลิกหรือลากไฟล์มาวางที่นี่',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AnalysisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _fileInfo == null
                        ? 'รองรับไฟล์ทุกประเภท สูงสุด 1GB'
                        : 'ขนาด ${_fileInfo!.displaySize}',
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: AnalysisColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AnalysisColors.failed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: AnalysisColors.failed,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_isUploading) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 7,
                backgroundColor: AnalysisColors.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AnalysisColors.cyan,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'อัปโหลด ${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AnalysisColors.cyan,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadFile,
              icon: Icon(_isUploading ? Icons.hourglass_top : Icons.upload),
              label: Text(
                _isUploading ? 'กำลังอัปโหลด...' : 'อัปโหลดและวิเคราะห์',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AnalysisColors.cyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    final info = _fileInfo!;
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('ข้อมูลไฟล์'),
          const SizedBox(height: 10),
          _row('ชื่อไฟล์', info.name),
          _row('ขนาด', info.displaySize),
          if (info.extension?.isNotEmpty == true)
            _row('ประเภท', '.${info.extension}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacy() {
    return AnalysisCard(
      child: Row(
        children: [
          const Icon(Icons.lock, size: 19, color: AnalysisColors.purple),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ส่วนตัว — เฉพาะคุณ',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    const items = [
      (
        Icons.security,
        'การรักษาความปลอดภัย',
        'ไฟล์ของคุณจะถูกจัดเก็บอย่างปลอดภัย',
        AnalysisColors.completed,
      ),
      (
        Icons.bolt,
        'การวิเคราะห์รวดเร็ว',
        'ผลการวิเคราะห์จะพร้อมภายในไม่กี่นาที',
        AnalysisColors.cyan,
      ),
      (
        Icons.analytics,
        'รายงานละเอียด',
        'ตรวจสอบผลจากเครื่องมือหลายตัว',
        AnalysisColors.purple,
      ),
      (
        Icons.lock,
        'ความเป็นส่วนตัว',
        'ไฟล์ส่วนตัวจะมองเห็นได้เฉพาะคุณ',
        AnalysisColors.blue,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ข้อมูลที่ควรทราบ',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AnalysisColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          AnalysisCard(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: item.$4.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(item.$1, color: item.$4, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AnalysisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 11.5,
                          color: AnalysisColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
