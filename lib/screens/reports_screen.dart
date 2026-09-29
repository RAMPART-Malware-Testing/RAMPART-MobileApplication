import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../services/report_download_service.dart';
import '../services/session_guard.dart';
import '../services/tab_refresh_bus.dart';
import '../widgets/analysis_components.dart';

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _ToolChip {
  const _ToolChip(this.tool, this.score);

  final String tool;
  final num? score;
}

/// ช่องใส่ตัวดึงประวัติ ใช้ในเทสต์แทนการยิงเครือข่าย — รูปแบบเดียวกับ
/// `DashboardScreen.load` ที่ฉีดข้อมูลชุดเดียว
typedef HistoryLoader =
    Future<AnalysisHistoryPage> Function({
      required int page,
      required int limit,
      required String s,
      required String status,
      required String fileType,
      required String sortField,
      required int sortDirection,
      required bool force,
    });

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.loadHistory});

  final HistoryLoader? loadHistory;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// ดึงจากเซิร์ฟเวอร์ทีละ 5 รายการ — backend รับ page/limit จริง
  /// (`schemas/analy.py`) การแบ่งหน้าเลยไม่ได้ทำในเครื่อง
  static const int _pageSize = 5;
  static const List<_FilterOption> _statusFilters = [
    _FilterOption('', 'ทั้งหมด'),
    _FilterOption('success', 'สำเร็จ'),
    _FilterOption('processing', 'กำลังวิเคราะห์'),
    _FilterOption('failed', 'ไม่สำเร็จ'),
    _FilterOption('pending', 'รอดำเนินการ'),
  ];
  static const List<String> _fileTypes = [
    'apk',
    'exe',
    'msi',
    'bat',
    'dmg',
    'ipa',
    'zip',
  ];
  static const List<_FilterOption> _sortOptions = [
    _FilterOption('created_at', 'วันที่'),
    _FilterOption('file_name', 'ชื่อไฟล์'),
    _FilterOption('file_size', 'ขนาด'),
    _FilterOption('score', 'ความเสี่ยง'),
  ];

  final AnalysisService _service = AnalysisService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AnalysisHistoryItem> _items = const [];
  Pagination? _pagination;
  bool _loading = true;
  bool _loadingMore = false;

  /// รีเฟรชเงียบเวลากดแท็บ — แยกจาก [_loading] เพราะต้องไม่ล้างรายการเดิม แต่ยังต้อง
  /// บอกผู้ใช้ให้รู้ว่ากำลังยิงใหม่ ไม่งั้นการกดแท็บดูเหมือนไม่มีอะไรเกิดขึ้น
  bool _refreshing = false;

  /// ผู้ใช้กดแท็บขณะที่คำขอเดิมยังค้างอยู่ — เก็บไว้ยิงต่อเมื่อคำขอเดิมเสร็จ
  /// เดิมกดแล้ว `return` ทิ้งทันที กดกี่ครั้งก็ไม่มีผลจนกว่าคำขอเดิมจะเสร็จ
  bool _pendingTabRefresh = false;
  String? _error;
  String _selectedStatus = '';
  String _selectedFileType = '';
  String _search = '';
  String _sortField = 'created_at';
  int _sortDirection = -1;
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    TabRefreshBus.addListener(_onTabSelected);
    _loadFirstPage();
  }

  @override
  void dispose() {
    TabRefreshBus.removeListener(_onTabSelected);
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

  /// ผู้ใช้เพิ่งกดแท็บ Reports
  ///
  /// รีเฟรชแบบเงียบ (ไม่ล้างรายการเดิม) แต่ยังขึ้นแถบบาง ๆ ให้เห็นว่ากำลังยิงใหม่ —
  /// เดิมไม่มีสัญญาณใด ๆ เลย ผู้ใช้จึงเหมือนกดไม่ได้ผล แม้คำขอจะยิงออกไปแล้ว
  /// ส่วนจะใช้แคชในหน่วยความจำหรือยิงใหม่ ปล่อยให้ `TabCache` (อายุ 4 วินาที) ตัดสิน
  void _onTabSelected() {
    if (TabRefreshBus.currentIndex != TabRefreshBus.reportsTab) return;
    // คำขอเดิมยังค้าง — Dio รอได้ถึง 30 วินาที ถ้าทิ้งการกดไปเฉย ๆ ผู้ใช้จะ
    // กดซ้ำอีกกี่ครั้งก็ยังไม่มีผล จำไว้ยิงต่อเมื่อคำขอเดิมเสร็จแทน
    if (_loading || _loadingMore) {
      _pendingTabRefresh = true;
      return;
    }
    _loadFirstPage(silent: true);
  }

  /// ยิงหน้าที่ [page] ด้วยตัวกรองปัจจุบัน — เส้นทางเดียวทั้งเทสต์และตัวจริง
  Future<AnalysisHistoryPage> _fetch(int page, {bool force = false}) {
    final loader = widget.loadHistory;
    if (loader != null) {
      return loader(
        page: page,
        limit: _pageSize,
        s: _search,
        status: _selectedStatus,
        fileType: _selectedFileType,
        sortField: _sortField,
        sortDirection: _sortDirection,
        force: force,
      );
    }
    return _service.getHistory(
      page: page,
      limit: _pageSize,
      s: _search,
      status: _selectedStatus,
      fileType: _selectedFileType,
      sortField: _sortField,
      sortDirection: _sortDirection,
      force: force,
    );
  }

  /// [force] = ผู้ใช้สั่งเอง (ดึงลง/ปุ่มลองใหม่) ข้ามแคช 4 วินาที
  /// [silent] = ไม่ล้างรายการเดิมถ้าดึงใหม่ไม่สำเร็จ
  Future<void> _loadFirstPage({bool force = false, bool silent = false}) async {
    if (!silent && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      if (silent) {
        _refreshing = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    final page = await _fetch(1, force: force);
    if (!mounted) return;

    // token ยังไม่หมดอายุแต่ผู้ใช้ไม่มีในฐานข้อมูลแล้ว — กดลองใหม่ไม่มีทางสำเร็จ
    // ต้องล้าง session และให้ล็อกใหม่ ไม่งั้นค้างเป็นหน้าจอ error ที่กู้ไม่ได้
    if (!page.success && (page.status == 401 || page.status == 403)) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      Get.snackbar(
        'ต้องเข้าสู่ระบบใหม่',
        page.message.isNotEmpty ? page.message : 'บัญชีนี้ไม่มีอยู่แล้ว',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AnalysisColors.failed.withValues(alpha: 0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
      await SessionGuard.handleSessionDead();
      return;
    }

    setState(() {
      _loading = false;
      _refreshing = false;
      if (!page.success) {
        // ของเดิมที่แสดงอยู่ยังมีค่ากว่า error — ไม่ทับด้วยหน้าจอว่าง
        if (silent && _items.isNotEmpty) return;
        _items = const [];
        _pagination = null;
        _error = page.message.isNotEmpty
            ? page.message
            : 'ไม่สามารถดึงประวัติได้';
      } else {
        _items = page.items;
        _pagination = page.pagination;
        _error = null;
      }
    });

    // ปลดบัสที่กดแท็บไว้ระหว่างรอ — กดหลายครั้งรวมเป็นคำขอเดียว
    if (_pendingTabRefresh) {
      _pendingTabRefresh = false;
      _loadFirstPage(silent: true);
    }
  }

  Future<void> _loadNextPage() async {
    final pagination = _pagination;
    if (_loading || _loadingMore || pagination == null || !pagination.hasNext) {
      return;
    }
    setState(() => _loadingMore = true);
    final page = await _fetch(pagination.page + 1);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (page.success) {
        _items = [..._items, ...page.items];
        _pagination = page.pagination;
      }
    });

    // ผู้ใช้อาจกดแท็บระหว่างที่เลื่อนโหลดหน้าถัดไปอยู่ — ปลดบัสนั้นตรงนี้
    if (_pendingTabRefresh) {
      _pendingTabRefresh = false;
      _loadFirstPage(silent: true);
    }
  }

  void _onSearchChanged(String value) {
    _search = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadFirstPage);
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

  void _selectSort(_FilterOption option) {
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

  Future<void> _downloadReport(AnalysisHistoryItem report) async {
    if (report.md5 == null) return;

    final toolList = report.toolList;
    final tool = toolList.isNotEmpty ? toolList.first : 'virustotal';

    setState(() => _downloading.add(report.aid));

    try {
      final result = await ReportDownloadService.instance.download(
        tool: tool,
        md5: report.md5!,
        fileName: report.fileName,
      );

      if (!mounted) return;

      setState(() => _downloading.remove(report.aid));

      if (result.success && result.path != null) {
        Get.snackbar(
          'ดาวน์โหลดสำเร็จ',
          'บันทึกไฟล์ที่: ${result.path}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AnalysisColors.completed.withValues(alpha: 0.9),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'ดาวน์โหลดล้มเหลว',
          result.message.isNotEmpty
              ? result.message
              : 'ไม่สามารถดาวน์โหลดรายงานได้',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AnalysisColors.failed.withValues(alpha: 0.9),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloading.remove(report.aid));

      Get.snackbar(
        'ดาวน์โหลดล้มเหลว',
        'เกิดข้อผิดพลาด: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AnalysisColors.failed.withValues(alpha: 0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
    }
  }

  void _openItem(AnalysisHistoryItem item) {
    if (item.taskId.isEmpty) return;
    if (item.status.toLowerCase() == 'success') {
      Get.toNamed('/analysis-result', arguments: item.taskId);
    } else {
      Get.toNamed('/analysis-progress', arguments: item.taskId);
    }
  }

  ({Color color, String label}) _statusMeta(String status) {
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
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  List<_ToolChip> _toolChips(AnalysisHistoryItem report) {
    final listed = report.toolList.toSet();
    final ai = report.rampartAiScore?.malwareProbability;
    final aiScore = ai == null
        ? report.rampartScore
        : ai <= 1
        ? ai * 100
        : ai;
    final chips = <_ToolChip>[
      _ToolChip('virustotal', report.virustotalScore?.toDouble()),
      _ToolChip('mobsf', report.mobsfScore),
      _ToolChip('cape', report.capeScore),
      _ToolChip('rampart_ai', aiScore),
    ];
    return chips
        .where((chip) => listed.isEmpty || listed.contains(chip.tool))
        .where((chip) => listed.isNotEmpty || chip.score != null)
        .toList(growable: false);
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
              Expanded(child: _buildReportsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final total = _pagination?.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'รายงานทั้งหมด',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              if (total != null)
                Text(
                  '$total รายการ',
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'ค้นหาและตรวจสอบประวัติการวิเคราะห์ไฟล์ของคุณ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              color: AnalysisColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          _buildSearchField(),
          const SizedBox(height: 10),
          _buildFilterBar(),
          // สัญญาณว่ากดแท็บแล้วกำลังยิงใหม่ — เหมือนแถบบาง ๆ ที่ Dashboard ใช้
          // ปรากฏเฉพาะตอนคำขอค้างอยู่เท่านั้น ไม่มี ticker ค้างตอนว่าง (R2)
          if (_refreshing) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(
              minHeight: 2,
              color: AnalysisColors.cyan,
              backgroundColor: Color(0x2200E5FF),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      onSubmitted: (_) {
        _searchDebounce?.cancel();
        _loadFirstPage();
      },
      style: const TextStyle(fontFamily: 'Kanit', color: Colors.white),
      decoration: InputDecoration(
        hintText: 'ค้นหาด้วยชื่อไฟล์ หรือ Task ID...',
        hintStyle: const TextStyle(
          fontFamily: 'Kanit',
          color: AnalysisColors.textMuted,
        ),
        prefixIcon: const Icon(Icons.search, color: AnalysisColors.cyan),
        suffixIcon: _search.isEmpty
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                icon: const Icon(
                  Icons.close,
                  color: AnalysisColors.textSecondary,
                ),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
        filled: true,
        fillColor: AnalysisColors.surface.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.cyan),
        ),
      ),
    );
  }

  /// ตัวกรองทั้งสามแบบรวมอยู่ในแถวเดียวที่เลื่อนแนวนอนได้
  ///
  /// เดิมกระจายเป็นชิป 17 ปุ่ม (สถานะ 5 + ประเภทไฟล์ 8 + เรียงตาม 4) กินพื้นที่
  /// เกือบครึ่งจอทั้งที่ค่าส่วนใหญ่ยังเป็นค่าเริ่มต้น — ตอนนี้แต่ละปุ่มบอกค่าที่ใช้อยู่
  /// ในตัว แล้วเปิดเมนูให้เลือก ส่วนปุ่มที่ถูกเปลี่ยนจะติดสีให้เห็นว่ากรองอยู่
  Widget _buildFilterBar() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _buildStatusPill(),
          const SizedBox(width: 8),
          _buildFileTypePill(),
          const SizedBox(width: 8),
          _buildSortPill(),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final current = _statusFilters.firstWhere(
      (option) => option.value == _selectedStatus,
      orElse: () => _statusFilters.first,
    );
    return PopupMenuButton<_FilterOption>(
      tooltip: 'กรองตามสถานะ',
      color: AnalysisColors.surfaceElevated,
      onSelected: (option) => _selectStatus(option.value),
      itemBuilder: (context) => [
        for (final option in _statusFilters)
          _menuItem(option, option.value == _selectedStatus),
      ],
      child: _pillShell(
        text: 'สถานะ: ${current.label}',
        isActive: _selectedStatus.isNotEmpty,
      ),
    );
  }

  Widget _buildFileTypePill() {
    return PopupMenuButton<_FilterOption>(
      tooltip: 'กรองตามประเภทไฟล์',
      color: AnalysisColors.surfaceElevated,
      onSelected: (option) => _selectFileType(option.value),
      itemBuilder: (context) => [
        _menuItem(const _FilterOption('', 'ทั้งหมด'), _selectedFileType.isEmpty),
        for (final type in _fileTypes)
          _menuItem(
            _FilterOption(type, type.toUpperCase()),
            _selectedFileType == type,
          ),
      ],
      child: _pillShell(
        text: 'ประเภท: ${_selectedFileType.isEmpty ? 'ทั้งหมด' : _selectedFileType.toUpperCase()}',
        isActive: _selectedFileType.isNotEmpty,
      ),
    );
  }

  /// ปุ่มเรียงลำดับ — แตะรายการที่เลือกอยู่อีกครั้งเพื่อสลับทิศทาง (พฤติกรรมเดิม)
  Widget _buildSortPill() {
    final current = _sortOptions.firstWhere(
      (option) => option.value == _sortField,
      orElse: () => _sortOptions.first,
    );
    final arrow = _sortDirection == 1 ? '↑' : '↓';

    return PopupMenuButton<_FilterOption>(
      tooltip: 'เรียงลำดับ',
      color: AnalysisColors.surfaceElevated,
      onSelected: _selectSort,
      itemBuilder: (context) => [
        for (final option in _sortOptions)
          _menuItem(
            option,
            option.value == _sortField,
            suffix: option.value == _sortField
                ? '$arrow ${_sortDirection == 1 ? 'เก่าสุดก่อน' : 'ใหม่สุดก่อน'}'
                : null,
          ),
      ],
      child: _pillShell(
        text: 'เรียงตาม: ${current.label} $arrow',
        isActive: _sortField != 'created_at' || _sortDirection != -1,
      ),
    );
  }

  PopupMenuItem<_FilterOption> _menuItem(
    _FilterOption option,
    bool selected, {
    String? suffix,
  }) {
    return PopupMenuItem<_FilterOption>(
      value: option,
      height: 40,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.check_box_outline_blank,
            size: 16,
            color: selected ? AnalysisColors.cyan : AnalysisColors.textMuted,
          ),
          const SizedBox(width: 10),
          Text(
            suffix == null ? option.label : '${option.label} · $suffix',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AnalysisColors.cyan : AnalysisColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillShell({required String text, required bool isActive}) {
    final color = isActive ? AnalysisColors.cyan : AnalysisColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? AnalysisColors.cyan.withValues(alpha: 0.14)
            : AnalysisColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? AnalysisColors.cyan.withValues(alpha: 0.5)
              : AnalysisColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 16, color: color),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, size: 32, color: AnalysisColors.cyan),
            SizedBox(height: 10),
            Text(
              'กำลังโหลดรายงาน...',
              style: TextStyle(
                fontFamily: 'Kanit',
                color: AnalysisColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null) return _buildError(_error!);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadFirstPage(force: true),
        color: AnalysisColors.cyan,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            const Icon(
              Icons.search_off,
              size: 56,
              color: AnalysisColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'ไม่พบรายการ',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  color: AnalysisColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final hasNext = _pagination?.hasNext ?? false;
    // หางของรายการคือ แถวโหลดเพิ่ม/สปินเนอร์ (ถ้ามี) + บรรทัดนับ "แสดง X จาก Y"
    // เดิมการแบ่งหน้าทำงานเงียบมาก ผู้ใช้มองไม่ออกว่ามีหน้าถัดไปหรือรายการหมดแล้ว
    final tailCount = 1 + ((hasNext || _loadingMore) ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(force: true),
      color: AnalysisColors.cyan,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + tailCount,
        itemBuilder: (context, index) {
          if (index < _items.length) return _buildReportCard(_items[index]);
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

  /// ปุ่มโหลดหน้าถัดไป — infinite scroll ยังทำงานอยู่เหมือนเดิม แต่ปุ่มนี้ทำให้
  /// ผู้ใช้เห็นว่ายังมีรายการต่อ และกดเองได้โดยไม่ต้องเลื่อนให้สุดจอ
  Widget _buildLoadMoreRow() {
    final pagination = _pagination;
    final next = (pagination?.page ?? 1) + 1;
    final last = pagination?.totalPages ?? next;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Center(
        child: OutlinedButton.icon(
          key: const Key('reports-load-more'),
          onPressed: _loadNextPage,
          icon: const Icon(Icons.expand_more, size: 18),
          label: Text('โหลดเพิ่มเติม (หน้า $next/$last)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AnalysisColors.cyan,
            side: BorderSide(
              color: AnalysisColors.cyan.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  /// บรรทัดสรุปว่าดูมาแล้วกี่รายการจากทั้งหมดกี่รายการ
  Widget _buildPageFooter() {
    final pagination = _pagination;
    if (pagination == null) return const SizedBox.shrink();
    final pageInfo = pagination.totalPages > 1
        ? ' • หน้า ${pagination.page}/${pagination.totalPages}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Text(
          'แสดง ${_items.length} จาก ${pagination.total} รายการ$pageInfo',
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

  /// หน้าจอ error ต้องดึงลงรีเฟรชได้ด้วย — เดิมเป็น `Center` ธรรมดาที่ไม่เลื่อนได้
  /// ผู้ใช้จึงกู้จากหน้านี้ได้ทางเดียวคือกดปุ่มเล็ก ๆ "ลองใหม่"
  Widget _buildError(String message) {
    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(force: true),
      color: AnalysisColors.cyan,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
          const Icon(Icons.cloud_off, size: 50, color: AnalysisColors.failed),
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
              onPressed: () => _loadFirstPage(force: true),
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

  Widget _buildReportCard(AnalysisHistoryItem report) {
    final status = _statusMeta(report.status);
    final score = report.score;
    final tier = score == null
        ? AnalysisScoreTier.fromRisk(report.riskLevel)
        : AnalysisScoreTier.fromScore(score);
    final canDownload =
        report.status.toLowerCase() == 'success' && report.md5 != null;
    final isDownloading = _downloading.contains(report.aid);

    return InkWell(
      onTap: () => _openItem(report),
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
                if (canDownload) ...[
                  IconButton(
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AnalysisColors.cyan,
                            ),
                          )
                        : const Icon(
                            Icons.download_outlined,
                            color: AnalysisColors.cyan,
                          ),
                    iconSize: 20,
                    onPressed: isDownloading
                        ? null
                        : () => _downloadReport(report),
                    tooltip: 'ดาวน์โหลดรายงาน',
                  ),
                ] else
                  const Icon(
                    Icons.chevron_right,
                    color: AnalysisColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _tag(
                  report.privacy ? 'ส่วนตัว' : 'สาธารณะ',
                  AnalysisColors.purple,
                ),
                if (score != null)
                  _tag('${score.toStringAsFixed(0)}/100', tier.textColor),
                if (score != null || report.riskLevel?.isNotEmpty == true)
                  _tag(tier.label, tier.textColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _meta(
                  Icons.insert_drive_file_outlined,
                  _formatSize(report.fileSize),
                ),
                _meta(Icons.schedule, _formatDate(report.createdAt)),
              ],
            ),
            if (_toolChips(report).isNotEmpty) ...[
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in _toolChips(report)) _toolChip(chip),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolChip(_ToolChip chip) {
    final tier = AnalysisScoreTier.fromScore(chip.score);
    final shortLabel = switch (chip.tool) {
      'virustotal' => 'VT',
      'mobsf' => 'MobSF',
      'cape' => 'CAPE',
      'rampart_ai' => 'AI',
      _ => analysisToolLabel(chip.tool),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: chip.score == null
            ? AnalysisColors.surfaceElevated
            : tier.backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: chip.score == null ? AnalysisColors.border : tier.borderColor,
        ),
      ),
      child: Text(
        '$shortLabel ${chip.score?.toStringAsFixed(0) ?? '–'}',
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: chip.score == null ? AnalysisColors.textMuted : tier.textColor,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AnalysisColors.textMuted),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            color: AnalysisColors.textSecondary,
          ),
        ),
      ],
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
