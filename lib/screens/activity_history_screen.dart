import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:rampart/models/profile.dart';
import 'package:rampart/services/profile_service.dart';
import 'package:rampart/theme/app_theme.dart';
import 'package:rampart/widgets/analysis_components.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final String _mode = Get.arguments?.toString() ?? 'login';
  bool _loading = true;
  String? _error;

  List<LoginHistoryEntry> _loginEntries = [];
  List<DownloadHistoryEntry> _downloadEntries = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_mode == 'login') {
      final result = await ProfileService.instance.loginHistory();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _loginEntries = result.entries;
          _loading = false;
        });
      } else {
        setState(() {
          _error = result.message;
          _loading = false;
        });
      }
    } else {
      final result = await ProfileService.instance.downloadHistory();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _downloadEntries = result.entries;
          _loading = false;
        });
      } else {
        setState(() {
          _error = result.message;
          _loading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'ไม่ทราบวันที่';
    // เซิร์ฟเวอร์ส่งเวลามาเป็น UTC — ต้องแปลงเป็นเวลาท้องถิ่นก่อนแสดง
    // ไม่งั้นผู้ใช้ในไทยจะเห็นเวลาย้อนหลังไป 7 ชั่วโมง
    final formatter = DateFormat('d MMM yyyy HH:mm', 'th');
    return formatter.format(date.toLocal());
  }

  String _truncateUserAgent(String? ua) {
    if (ua == null || ua.isEmpty) return 'ไม่ทราบ';
    if (ua.length <= 40) return ua;
    return '${ua.substring(0, 37)}...';
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
          child: Column(
            children: [
              _buildHeader(customColors),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorState(customColors)
                        : _buildContent(customColors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(CustomColors customColors) {
    final title = _mode == 'login' ? 'ประวัติการเข้าสู่ระบบ' : 'ประวัติการดาวน์โหลด';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.arrow_back, color: customColors.cyanColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(CustomColors customColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: customColors.hintColor),
            const SizedBox(height: 16),
            Text(
              _error ?? 'เกิดข้อผิดพลาด',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 15,
                color: customColors.hintColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'ลองอีกครั้ง',
                style: TextStyle(fontFamily: 'Kanit', fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: customColors.cyanColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(CustomColors customColors) {
    final isEmpty = _mode == 'login' ? _loginEntries.isEmpty : _downloadEntries.isEmpty;

    if (isEmpty) {
      return _buildEmptyState(customColors);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: _mode == 'login'
          ? _buildLoginList(customColors)
          : _buildDownloadList(customColors),
    );
  }

  Widget _buildEmptyState(CustomColors customColors) {
    final message = _mode == 'login'
        ? 'ยังไม่มีประวัติการเข้าสู่ระบบ'
        : 'ยังไม่มีประวัติการดาวน์โหลด';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: customColors.hintColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 15,
              color: customColors.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginList(CustomColors customColors) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _loginEntries.length,
      itemBuilder: (context, index) {
        final entry = _loginEntries[index];
        // backend บันทึกการล็อกอินที่ข้าม OTP สำเร็จไว้ว่า success_device_bypass
        // จึงต้องดูคำขึ้นต้น ไม่ใช่เทียบคำว่า success ตรงตัว
        final status = entry.status?.toLowerCase() ?? '';
        final isSuccess = status.startsWith('success');
        // otp_required คือขั้นกลางของการล็อกอินปกติ ไม่ใช่ความล้มเหลว
        final isPendingOtp = !isSuccess && status == 'otp_required';
        final statusLabel = isSuccess
            ? 'สำเร็จ'
            : isPendingOtp
            ? 'รอ OTP'
            : 'ไม่สำเร็จ';
        final statusColor = isSuccess
            ? Colors.green
            : isPendingOtp
            ? Colors.amber
            : Colors.red;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(entry.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.devices, _truncateUserAgent(entry.userAgent), customColors),
              if (entry.ip != null && entry.ip!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildInfoRow(Icons.location_on_outlined, entry.ip!, customColors),
              ],
              if (entry.provider != null && entry.provider!.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildInfoRow(Icons.vpn_key_outlined, entry.provider!, customColors),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDownloadList(CustomColors customColors) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _downloadEntries.length,
      itemBuilder: (context, index) {
        final entry = _downloadEntries[index];
        final toolLabel = entry.tool != null ? analysisToolLabel(entry.tool!) : 'ไม่ทราบเครื่องมือ';
        final fileName = entry.fileName?.isNotEmpty == true ? entry.fileName! : entry.md5 ?? 'ไม่ทราบชื่อไฟล์';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: customColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: customColors.cyanColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: customColors.cyanColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      toolLabel,
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: customColors.cyanColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                fileName,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(entry.createdAt),
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: customColors.hintColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, CustomColors customColors) {
    return Row(
      children: [
        Icon(icon, size: 14, color: customColors.hintColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: customColors.hintColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
