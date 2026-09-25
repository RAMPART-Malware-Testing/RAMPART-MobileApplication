import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const int _pageSize = 10;
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
  String? _error;
  String _selectedStatus = '';
  String _selectedFileType = '';
  String _search = '';
  String _sortField = 'created_at';
  int _sortDirection = -1;

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

  Future<void> _loadFirstPage() async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final page = await _service.getHistory(
      page: 1,
      limit: _pageSize,
      s: _search,
      status: _selectedStatus,
      fileType: _selectedFileType,
      sortField: _sortField,
      sortDirection: _sortDirection,
    );
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (!page.success) {
        _items = const [];
        _pagination = null;
        _error = page.message.isNotEmpty
            ? page.message
            : 'ไม่สามารถดึงประวัติได้';
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
      s: _search,
      status: _selectedStatus,
      fileType: _selectedFileType,
      sortField: _sortField,
      sortDirection: _sortDirection,
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
          const SizedBox(height: 16),
          TextField(
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
          ),
          const SizedBox(height: 12),
          _buildFilterSection(
            'สถานะ',
            _statusFilters,
            _selectedStatus,
            _selectStatus,
          ),
          const SizedBox(height: 10),
          _buildFileTypeFilters(),
          const SizedBox(height: 10),
          _buildSortFilters(),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    String label,
    List<_FilterOption> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            color: AnalysisColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final option in options)
              _filterChip(
                option.label,
                selected == option.value,
                () => onSelected(option.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFileTypeFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ประเภทไฟล์',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            color: AnalysisColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _filterChip(
              'ทั้งหมด',
              _selectedFileType.isEmpty,
              () => _selectFileType(''),
            ),
            for (final type in _fileTypes)
              _filterChip(
                type.toUpperCase(),
                _selectedFileType == type,
                () => _selectFileType(type),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortFilters() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, right: 8),
          child: Text(
            'เรียงตาม:',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final option in _sortOptions)
                _filterChip(
                  _sortField == option.value
                      ? '${option.label} ${_sortDirection == 1 ? '↑' : '↓'}'
                      : option.label,
                  _sortField == option.value,
                  () => _selectSort(option),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AnalysisColors.cyan.withValues(alpha: 0.16)
              : AnalysisColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AnalysisColors.cyan.withValues(alpha: 0.5)
                : AnalysisColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? AnalysisColors.cyan
                : AnalysisColors.textSecondary,
          ),
        ),
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
        onRefresh: _loadFirstPage,
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
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: AnalysisColors.cyan,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Icon(Icons.hourglass_top, color: AnalysisColors.cyan),
              ),
            );
          }
          return _buildReportCard(_items[index]);
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            OutlinedButton(
              onPressed: _loadFirstPage,
              style: OutlinedButton.styleFrom(
                foregroundColor: AnalysisColors.cyan,
              ),
              child: const Text(
                'ลองใหม่',
                style: TextStyle(fontFamily: 'Kanit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(AnalysisHistoryItem report) {
    final status = _statusMeta(report.status);
    final score = report.score;
    final tier = score == null
        ? AnalysisScoreTier.fromRisk(report.riskLevel)
        : AnalysisScoreTier.fromScore(score);
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
