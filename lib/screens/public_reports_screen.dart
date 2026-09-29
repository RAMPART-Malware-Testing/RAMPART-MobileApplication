import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/analysis.dart';
import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';
import '../widgets/analysis_components.dart';
import '../widgets/report_filter_bar.dart';

/// พารามิเตอร์ของหนึ่งคำขอ — รวมตัวกรองทั้งหมดไว้ที่เดียวกับหน้ารายงานของผู้ใช้
class PublicReportsQuery {
  const PublicReportsQuery({
    required this.page,
    required this.limit,
    this.search = '',
    this.status = '',
    this.fileType = '',
    this.sortField = 'created_at',
    this.sortDirection = -1,
  });

  final int page;
  final int limit;
  final String search;
  final String status;
  final String fileType;
  final String sortField;
  final int sortDirection;
}

/// จุดเชื่อมสำหรับเทสต์ — ค่าเริ่มต้นยิงเซิร์ฟเวอร์จริง
typedef PublicReportsLoader = Future<PublicReportsPage> Function(
  PublicReportsQuery query,
);

/// หน้า "Public Reports" — รายงานสาธารณะทั้งหมด แบ่งหน้าโดยเซิร์ฟเวอร์
///
/// หน้า dashboard โชว์แค่ 5 อันดับแรก ปุ่ม "ดูทั้งหมด" พามาที่นี่ ซึ่งทำหน้าที่
/// เดียวกับแท็บ Reports แต่เป็นของ *ทุกคน* ไม่ใช่เฉพาะของผู้ใช้ และดึงจาก
/// `POST /api/analy/v1/dashboard/reports` ซึ่งรับ page/limit ได้จริง
class PublicReportsScreen extends StatefulWidget {
  const PublicReportsScreen({super.key, this.loadPage = defaultLoadPage});

  final PublicReportsLoader loadPage;

  static Future<PublicReportsPage> defaultLoadPage(PublicReportsQuery query) {
    return dashboardService.loadPublicReportsPage(
      page: query.page,
      limit: query.limit,
      s: query.search,
      status: query.status,
      fileType: query.fileType,
      sortField: query.sortField,
      sortDirection: query.sortDirection,
    );
  }

  @override
  State<PublicReportsScreen> createState() => _PublicReportsScreenState();
}

class _PublicReportsScreenState extends State<PublicReportsScreen> {
  static const int _pageSize = DashboardService.publicReportLimit;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  String _search = '';
  String _selectedStatus = '';
  String _selectedFileType = '';
  String _sortField = 'created_at';
  int _sortDirection = -1;

  List<AnalysisHistoryItem> _items = const [];
  int _page = 1;
  int _total = 0;
  int _totalPages = 0;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadNextPage();
    }
  }

  /// รวมตัวกรองที่ผู้ใช้เลือกไว้ — เปลี่ยนตัวกรองแล้วต้องยิงใหม่จากหน้า 1 เสมอ
  PublicReportsQuery _query(int page) => PublicReportsQuery(
    page: page,
    limit: _pageSize,
    search: _search,
    status: _selectedStatus,
    fileType: _selectedFileType,
    sortField: _sortField,
    sortDirection: _sortDirection,
  );

  Future<void> _loadFirstPage() async {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _loading = true;
      _error = '';
    });

    final result = await widget.loadPage(_query(1));
    if (!mounted) return;

    setState(() {
      _loading = false;
      _page = 1;
      _total = result.total;
      _totalPages = _pagesOf(result.total);
      _hasNext = result.hasMore;
      _error = result.error;
      _items = result.error.isEmpty ? result.items : const [];
    });
  }

  Future<void> _loadNextPage() async {
    if (_loading || _loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);

    final next = _page + 1;
    final result = await widget.loadPage(_query(next));
    if (!mounted) return;

    if (result.error.isNotEmpty) {
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error),
          backgroundColor: AnalysisColors.failed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // เซิร์ฟเวอร์แคชผลลัพธ์ไว้ 5 วินาที รายการขอบเขตจึงอาจซ้ำกับที่แสดงอยู่
    // ตัดด้วย task_id กันโผล่สองครั้ง
    final seen = _items.map((item) => item.taskId).toSet();
    setState(() {
      _loadingMore = false;
      _items = [
        ..._items,
        ...result.items.where((item) => !seen.contains(item.taskId)),
      ];
      _page = next;
      if (result.total > 0) {
        _total = result.total;
        _totalPages = _pagesOf(result.total);
      }
      _hasNext = result.hasMore;
    });
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _loadFirstPage,
    );
  }

  void _selectStatus(String value) {
    if (_selectedStatus == value) return;
    setState(() => _selectedStatus = value);
    _loadFirstPage();
  }

  void _selectFileType(String value) {
    if (_selectedFileType == value) return;
    setState(() => _selectedFileType = value);
    _loadFirstPage();
  }

  void _selectSort(ReportFilterOption option) {
    setState(() {
      if (_sortField == option.value) {
        _sortDirection = _sortDirection == 1 ? -1 : 1;
      } else {
        _sortField = option.value;
        _sortDirection = -1;
      }
    });
    _loadFirstPage();
  }

  int _pagesOf(int total) =>
      (total / _pageSize).ceil().clamp(total > 0 ? 1 : 0, 9999);

  void _open(AnalysisHistoryItem item) {
    if (item.taskId.isEmpty) return;
    if (item.status.toLowerCase() == 'success') {
      Get.toNamed('/analysis-result', arguments: item.taskId);
    } else {
      Get.toNamed('/analysis-progress', arguments: item.taskId);
    }
  }

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy HH:mm');
  static final NumberFormat _numberFormat = NumberFormat('#,###');

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static ({Color color, String label}) _statusMeta(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return (color: AnalysisColors.completed, label: 'สำเร็จ');
      case 'processing':
        return (color: AnalysisColors.running, label: 'กำลังวิเคราะห์');
      case 'queued':
      case 'dispatching':
      case 'pending':
        return (color: AnalysisColors.running, label: 'รอดำเนินการ');
      case 'failed':
        return (color: AnalysisColors.failed, label: 'ไม่สำเร็จ');
      default:
        return (
          color: AnalysisColors.waiting,
          label: status.isEmpty ? '-' : status,
        );
    }
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'ย้อนกลับ',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: popAnalysisScreen,
              ),
              const Expanded(
                child: Text(
                  'Public Reports',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'โหลดใหม่',
                icon: const Icon(Icons.refresh, color: AnalysisColors.cyan),
                onPressed: _loading ? null : _loadFirstPage,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 12),
            child: Text(
              _total > 0
                  ? 'รายงานที่เปิดให้ทุกคนดูได้ • ทั้งหมด '
                        '${_numberFormat.format(_total)} รายการ'
                  : 'รายงานที่เปิดให้ทุกคนดูได้',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          // ชุดตัวกรองชุดเดียวกับแท็บ Reports — backend รองรับครบทั้งหมด
          // (`ReportsHistoryParams`) ผู้ใช้จึงกรองชุดเดียวกันได้ทั้งสองหน้า
          ReportSearchField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              _searchDebounce?.cancel();
              _loadFirstPage();
            },
            onClear: () {
              _searchController.clear();
              _onSearchChanged('');
            },
            hasQuery: _search.isNotEmpty,
            hintText: 'ค้นหาด้วยชื่อไฟล์ หรือ MD5...',
          ),
          const SizedBox(height: 10),
          ReportFilterBar(
            status: _selectedStatus,
            onStatus: _selectStatus,
            fileType: _selectedFileType,
            onFileType: _selectFileType,
            sortField: _sortField,
            sortDirection: _sortDirection,
            onSort: _selectSort,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Icon(Icons.hourglass_top, size: 32, color: AnalysisColors.cyan),
      );
    }
    if (_error.isNotEmpty) return _buildMessage(_error, Icons.cloud_off);
    if (_items.isEmpty) {
      return _buildMessage('ยังไม่มีรายงานสาธารณะ', Icons.public_off);
    }

    final hasNext = _hasNext;
    final tailCount = 1 + ((hasNext || _loadingMore) ? 1 : 0);
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: AnalysisColors.cyan,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + tailCount,
        itemBuilder: (context, index) {
          if (index < _items.length) return _buildCard(_items[index]);
          if (index == _items.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Icon(Icons.hourglass_top, color: AnalysisColors.cyan),
                ),
              );
            }
            if (hasNext) return _buildLoadMoreRow();
          }
          return _buildPageFooter();
        },
      ),
    );
  }

  Widget _buildMessage(String message, IconData icon) {
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: AnalysisColors.cyan,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          Icon(icon, size: 50, color: AnalysisColors.textMuted),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Kanit',
              color: AnalysisColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton(
              onPressed: _loadFirstPage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AnalysisColors.cyan,
              ),
              child: const Text(
                'ลองใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreRow() {
    final next = _page + 1;
    final last = _totalPages > 0 ? _totalPages : next;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('public-reports-load-more'),
          onPressed: _loadNextPage,
          icon: const Icon(Icons.expand_more, size: 18),
          label: Text('โหลดเพิ่มเติม (หน้า $next/$last)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AnalysisColors.cyan,
            side: BorderSide(color: AnalysisColors.cyan.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageFooter() {
    if (_total <= 0) return const SizedBox.shrink();
    final pageInfo = _totalPages > 1 ? ' • หน้า $_page/$_totalPages' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Text(
          'แสดง ${_items.length} จาก $_total รายการ$pageInfo',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11.5,
            color: AnalysisColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AnalysisHistoryItem report) {
    final status = _statusMeta(report.status);
    final score = report.score;
    final tier = score == null
        ? AnalysisScoreTier.fromRisk(report.riskLevel)
        : AnalysisScoreTier.fromScore(score);
    final uploader = report.uploadedByUsername;

    return InkWell(
      onTap: () => _open(report),
      borderRadius: BorderRadius.circular(16),
      child: AnalysisCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AnalysisColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AnalysisColors.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    (report.fileType ?? '?').toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AnalysisColors.cyan,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.fileName ?? 'ไม่ทราบชื่อไฟล์',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AnalysisColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (score != null)
                  Text(
                    '${score.toStringAsFixed(0)}/100',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: tier.textColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (score != null) _tag(tier.label, tier.textColor),
                if (uploader != null && uploader.isNotEmpty)
                  _tag('โดย $uploader', AnalysisColors.textSecondary),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 14,
                  color: AnalysisColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  _formatSize(report.fileSize),
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AnalysisColors.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    report.createdAt == null
                        ? '-'
                        : _dateFormat.format(report.createdAt!.toLocal()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 11,
                      color: AnalysisColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
