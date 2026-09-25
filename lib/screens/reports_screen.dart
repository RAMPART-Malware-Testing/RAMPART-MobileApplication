import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../theme/app_theme.dart';

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;

  const _FilterOption(this.value, this.label, this.icon);
}

/// ประวัติการวิเคราะห์ไฟล์ของผู้ใช้ — ดึงจาก `/api/analy/v1/history`
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const int _pageSize = 10;

  /// ค่าที่ส่งไปเป็น filter ต้องตรงกับ status ของ backend ('' = ทั้งหมด)
  static const List<_FilterOption> _filters = [
    _FilterOption('', 'ทั้งหมด', Icons.folder_outlined),
    _FilterOption('success', 'สำเร็จ', Icons.check_circle_outline),
    _FilterOption('processing', 'กำลังวิเคราะห์', Icons.pending_outlined),
    _FilterOption('failed', 'ไม่สำเร็จ', Icons.error_outline),
    _FilterOption('pending', 'รอดำเนินการ', Icons.schedule),
  ];

  final AnalysisService _service = AnalysisService();
  final ScrollController _scrollController = ScrollController();

  List<AnalysisHistoryItem> _items = const [];
  Pagination? _pagination;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _selectedStatus = '';

  Color get _backgroundColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _cyanColor =>
      Theme.of(context).extension<CustomColors>()!.cyanColor;
  Color get _blueColor =>
      Theme.of(context).extension<CustomColors>()!.blueColor;
  Color get _hintColor =>
      Theme.of(context).extension<CustomColors>()!.hintColor;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final page = await _service.getHistory(
      page: 1,
      limit: _pageSize,
      status: _selectedStatus.isEmpty ? null : _selectedStatus,
    );
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!page.success) {
        _items = const [];
        _pagination = null;
        _error = page.message.isNotEmpty ? page.message : 'ไม่สามารถดึงประวัติได้';
      } else {
        _items = page.items;
        _pagination = page.pagination;
      }
    });
  }

  Future<void> _loadNextPage() async {
    final pagination = _pagination;
    if (_loading || _loadingMore || pagination == null || !pagination.hasNext) {
      return;
    }

    setState(() => _loadingMore = true);
    final page = await _service.getHistory(
      page: pagination.page + 1,
      limit: _pageSize,
      status: _selectedStatus.isEmpty ? null : _selectedStatus,
    );
    if (!mounted) return;

    setState(() {
      _loadingMore = false;
      if (page.success) {
        _items = [..._items, ...page.items];
        _pagination = page.pagination;
      }
    });
  }

  void _selectFilter(String value) {
    if (_selectedStatus == value) return;
    setState(() => _selectedStatus = value);
    _loadFirstPage();
  }

  void _openItem(AnalysisHistoryItem item) {
    if (item.taskId.isEmpty) return;
    if (item.status.toLowerCase() == 'success') {
      Get.toNamed('/analysis-result', arguments: item.taskId);
    } else {
      Get.toNamed('/analysis-progress', arguments: item.taskId);
    }
  }

  ({Color color, IconData icon, String label}) _statusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return (
          color: const Color(0xff22c55e),
          icon: Icons.check_circle,
          label: 'สำเร็จ'
        );
      case 'processing':
        return (
          color: const Color(0xff06b6d4),
          icon: Icons.autorenew,
          label: 'กำลังวิเคราะห์'
        );
      case 'queued':
      case 'dispatching':
      case 'pending':
        return (
          color: const Color(0xfff59e0b),
          icon: Icons.schedule,
          label: 'รอดำเนินการ'
        );
      case 'failed':
        return (
          color: const Color(0xffef4444),
          icon: Icons.error,
          label: 'ไม่สำเร็จ'
        );
      default:
        return (
          color: const Color(0xff94a3b8),
          icon: Icons.help_outline,
          label: status
        );
    }
  }

  String _riskLabel(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return 'ปลอดภัย';
      case 'caution':
        return 'ควรระวัง';
      case 'high':
        return 'อันตรายสูง';
      case 'critical':
        return 'วิกฤต';
      default:
        return '';
    }
  }

  Color _riskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return const Color(0xff22c55e);
      case 'caution':
        return const Color(0xfff59e0b);
      case 'high':
        return const Color(0xfff97316);
      case 'critical':
        return const Color(0xffef4444);
      default:
        return _hintColor;
    }
  }

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildFilterChips(),
                  ],
                ),
              ),
              Expanded(child: _buildReportsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _pagination?.total;
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
            'รายงานทั้งหมด',
            style: TextStyle(fontFamily: 'Kanit',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          total == null
              ? 'ประวัติการวิเคราะห์ไฟล์ของคุณ'
              : 'ประวัติการวิเคราะห์ไฟล์ของคุณ ($total รายการ)',
          style: TextStyle(fontFamily: 'Kanit',
            fontSize: 14,
            color: _hintColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in _filters) ...[
            _buildFilterChip(option),
            if (option != _filters.last) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(_FilterOption option) {
    final isSelected = _selectedStatus == option.value;

    return InkWell(
      onTap: () => _selectFilter(option.value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _cyanColor.withValues(alpha: 0.2)
              : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _cyanColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 18,
              color: isSelected ? _cyanColor : _hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: TextStyle(fontFamily: 'Kanit',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? _cyanColor : _hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff06b6d4)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 56,
                color: Color(0xffef4444)
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Kanit',
                  fontSize: 14,
                  color: _hintColor,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadFirstPage,
                style: OutlinedButton.styleFrom(foregroundColor: _cyanColor),
                child: const Text('ลองใหม่',
                    style: TextStyle(fontFamily: 'Kanit')),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        color: _cyanColor,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: _hintColor),
                  const SizedBox(height: 16),
                  Text(
                    'ไม่พบรายงาน',
                    style: TextStyle(fontFamily: 'Kanit',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: _cyanColor,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xff06b6d4),
                  ),
                ),
              ),
            );
          }
          return _buildReportCard(_items[index]);
        },
      ),
    );
  }

  Widget _buildReportCard(AnalysisHistoryItem report) {
    final status = _statusMeta(report.status);
    final riskLabel = _riskLabel(report.riskLevel);
    final riskColor = _riskColor(report.riskLevel);

    return InkWell(
      onTap: () => _openItem(report),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(status.icon, color: status.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.fileName ?? 'ไม่ทราบชื่อไฟล์',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Kanit',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.label,
                        style: TextStyle(fontFamily: 'Kanit',
                          fontSize: 12,
                          color: status.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _hintColor),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (report.score != null)
                  _buildTag(
                    '${report.score!.toStringAsFixed(0)}/100',
                    riskColor,
                  ),
                if (riskLabel.isNotEmpty) _buildTag(riskLabel, riskColor),
                _buildTag(
                  report.privacy ? 'ส่วนตัว' : 'สาธารณะ',
                  _hintColor,
                ),
                if (report.fileType != null && report.fileType!.isNotEmpty)
                  _buildTag(report.fileType!.toUpperCase(), _hintColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    size: 14, color: _hintColor),
                const SizedBox(width: 6),
                Text(
                  _formatSize(report.fileSize),
                  style: TextStyle(fontFamily: 'Kanit',
                    fontSize: 12,
                    color: _hintColor,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.schedule, size: 14, color: _hintColor),
                const SizedBox(width: 6),
                Text(
                  _formatDate(report.createdAt),
                  style: TextStyle(fontFamily: 'Kanit',
                    fontSize: 12,
                    color: _hintColor,
                  ),
                ),
              ],
            ),
            if (report.toolList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                report.toolList.join(' · '),
                style: TextStyle(fontFamily: 'Kanit',
                  fontSize: 11.5,
                  color: _hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Kanit',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
