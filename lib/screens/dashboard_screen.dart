import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/analysis.dart';
import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';
import '../services/tab_refresh_bus.dart';
import '../theme/app_theme.dart';

/// หน้า Dashboard — ดึงสถิติจาก `/api/analy/v1/dashboard/*`
///
/// โครงสร้างข้อมูลยึดตามที่หน้าเว็บ (`RAMPART-WebApplication`) ใช้จริง
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    Key? key,
    this.load = defaultLoad,
    this.loadFresh = defaultLoadFresh,
  }) : super(key: key);

  /// จุดเชื่อมสำหรับเทสต์ — ค่าเริ่มต้นยิงเซิร์ฟเวอร์จริง (ใช้แคช 4 วินาทีได้)
  final Future<DashboardBundle> Function() load;

  /// เหมือน [load] แต่ข้ามแคช — ใช้เมื่อผู้ใช้สั่งเอง (ดึงลงเพื่อรีเฟรช / ลองอีกครั้ง)
  final Future<DashboardBundle> Function() loadFresh;

  static Future<DashboardBundle> defaultLoad() => dashboardService.loadDashboard();

  static Future<DashboardBundle> defaultLoadFresh() =>
      dashboardService.loadDashboard(force: true);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _isFirstLoad = true;
  String _error = '';
  DashboardBundle? _bundle;

  // ---------- รายงานสาธารณะ ----------
  //
  // dashboard โชว์แค่ 5 อันดับแรก ส่วนที่เหลือไปดูต่อที่หน้า "Public Reports"
  // ซึ่งแบ่งหน้าเอง (ปุ่ม "ดูทั้งหมด") — เหมือนกิจกรรมล่าสุดที่พาไปแท็บ Reports
  List<AnalysisHistoryItem> _publicReports = const [];
  int _publicTotal = 0;

  /// 'daily' หรือ 'monthly' — สองชุดนี้มาพร้อมกันใน response เดียวกัน
  /// การสลับจึงเป็นแค่ setState ไม่ต้องยิงซ้ำ
  String _selectedRange = 'daily';

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

  static final NumberFormat _numberFormat = NumberFormat('#,###');
  static final DateFormat _dateFormat = DateFormat('d MMM HH:mm');

  static String _formatNumber(int number) => _numberFormat.format(number);

  /// ขนาดไฟล์เป็น KB/MB/GB — โครงสร้างเดียวกับ fmtSize ในหน้าเว็บ
  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const sizes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && i < sizes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(i == 0 ? 0 : 2)} ${sizes[i]}';
  }

  @override
  void initState() {
    super.initState();
    TabRefreshBus.addListener(_onTabSelected);
    // ยิงหลังเฟรมแรกเสร็จ เพื่อไม่ให้รอเครือข่ายก่อนหน้าจอแรกวาด (ดู R1 ใน AGENTS.md)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  @override
  void dispose() {
    TabRefreshBus.removeListener(_onTabSelected);
    super.dispose();
  }

  /// ผู้ใช้เพิ่งกดแท็บ — เรียกเฉพาะตอนที่เป็นแท็บนี้ แล้วปล่อยให้ [DashboardService]
  /// ตัดสินใจอีกชั้นว่าจะยิงเซิร์ฟเวอร์หรือคืนแคชเดิม (ยังไม่ครบ 4 วินาที)
  void _onTabSelected() {
    if (TabRefreshBus.currentIndex != TabRefreshBus.dashboardTab) return;
    _loadDashboardData();
  }

  /// [force] = ผู้ใช้สั่งเอง ข้ามแคชในหน่วยความจำ
  Future<void> _loadDashboardData({bool force = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    final bundle = await (force ? widget.loadFresh() : widget.load());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isFirstLoad = false;
      _bundle = bundle;
      _error = bundle.error;

      // รีเฟรชทุกครั้งเริ่มนับหน้าใหม่ที่ 1 — รายการเดิมถูกแทนที่ด้วยหน้าแรก
      // ล่าสุดจากเซิร์ฟเวอร์
      _publicReports = bundle.publicReports;
      _publicTotal = bundle.publicReportsTotal;
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
          child: RefreshIndicator(
            onRefresh: () => _loadDashboardData(force: true),
            color: _cyanColor,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        if (_isLoading && !_isFirstLoad)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: _cyanColor,
                              backgroundColor: _cyanColor.withValues(alpha: 0.15),
                            ),
                          ),
                        _buildBody(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isFirstLoad) return _buildLoadingIndicator();

    final summary = _bundle?.summary;
    if (summary == null) {
      return Column(
        children: [
          _buildErrorCard(),
          const SizedBox(height: 24),
          _buildPublicReportsSection(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatGrid(summary),
        const SizedBox(height: 24),
        _buildPublicReportsSection(),
        const SizedBox(height: 24),
        _buildRecentActivitiesSection(),
        const SizedBox(height: 24),
        _buildRiskScoresSection(summary),
        const SizedBox(height: 24),
        _buildTopMalwareSection(summary),
        const SizedBox(height: 24),
      ],
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
          child: const Text(
            'RAMPART',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
        Text(
          'Dashboard Analytics',
          style: TextStyle(fontSize: 12, color: _hintColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            'เกิดข้อผิดพลาด',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: TextStyle(fontSize: 13, color: _hintColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadDashboardData(force: true),
            icon: const Icon(Icons.refresh),
            label: const Text(
              'ลองอีกครั้ง',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cyanColor,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- การ์ดสรุป 4 ใบ ----------

  Widget _buildStatGrid(DashboardSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'ไฟล์ทั้งหมด',
                value: _formatNumber(summary.totalFiles.resolvedTotal),
                color: _cyanColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.person,
                label: 'ไฟล์ของฉัน',
                value: _formatNumber(summary.userFiles.resolvedTotal),
                color: _blueColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.trending_up,
                label: 'อัตราความสำเร็จ',
                value: '${summary.totalFiles.successRate.toStringAsFixed(1)}%',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                label: 'ผู้ใช้งานทั้งหมด',
                value: _formatNumber(summary.totalUsers),
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusBreakdown(summary),
      ],
    );
  }

  /// แถบสรุปสถานะไฟล์ของผู้ใช้ (สำเร็จ / รอวิเคราะห์ / ไม่สำเร็จ)
  Widget _buildStatusBreakdown(DashboardSummary summary) {
    final files = summary.userFiles;
    final total = files.resolvedTotal;
    final segments = <({String label, int count, Color color})>[
      (label: 'สำเร็จ', count: files.success, color: Colors.green),
      (label: 'รอวิเคราะห์', count: files.pending, color: Colors.orange),
      (label: 'ไม่สำเร็จ', count: files.failed, color: Colors.red),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'สถานะไฟล์ของฉัน',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatNumber(total)} ไฟล์',
                style: TextStyle(fontSize: 13, color: _hintColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final s in segments)
                      if (s.count > 0)
                        Expanded(
                          flex: s.count,
                          child: ColoredBox(color: s.color),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final s in segments)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${s.label} ${_formatNumber(s.count)}',
                        style: TextStyle(fontSize: 12, color: _hintColor),
                      ),
                    ],
                  ),
              ],
            ),
          ] else
            Text(
              'ยังไม่มีไฟล์ในระบบ',
              style: TextStyle(fontSize: 12, color: _hintColor),
            ),
        ],
      ),
    );
  }

  // ---------- รายงานสาธารณะ ----------

  Widget _buildPublicReportsSection() {
    final reports = _publicReports;

    return _buildSection(
      title: 'ไฟล์สาธารณะ (Public)',
      subtitle: _publicTotal > 0
          ? 'รายงานที่เปิดให้ทุกคนดูได้ • ทั้งหมด ${_formatNumber(_publicTotal)} รายการ'
          : 'รายงานที่เปิดให้ทุกคนดูได้',
      icon: Icons.public,
      iconColor: _blueColor,
      isEmpty: reports.isEmpty,
      emptyMessage: 'ไม่มีไฟล์',
      child: Column(
        children: [
          for (var i = 0; i < reports.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildPublicReportRow(reports[i]),
          ],
          if (_publicTotal > reports.length) ...[
            const SizedBox(height: 12),
            _buildViewMoreButton(
              key: const Key('public-view-more'),
              label: 'ดูทั้งหมด',
              icon: Icons.arrow_forward,
              isLoading: false,
              onTap: () => Get.toNamed('/public-reports'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPublicReportRow(AnalysisHistoryItem report) {
    final score = report.score;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _cyanColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cyanColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  (report.fileType ?? '?').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _cyanColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.fileName ?? 'ไม่ทราบชื่อไฟล์',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleFor(report),
                      style: TextStyle(fontSize: 11, color: _hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (report.status.isNotEmpty)
                _buildStatusBadge(report.status),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${score.round()}/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: _tierColor(score),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTierChip(score),
              ],
            ),
            ..._toolChipsFor(report).isEmpty
                ? const []
                : [
                    const SizedBox(height: 8),
                    // Wrap ไม่ใช่ Row — บนจอแคบชิปครบทุกเครื่องมือต้องตัดบรรทัดได้
                    // ไม่เช่นนั้นแถวจะล้นการ์ด (RenderFlex overflow)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _toolChipsFor(report),
                    ),
                  ],
          ],
        ],
      ),
    );
  }

  /// บรรทัดรอง: ขนาดไฟล์ · เวลา · ผู้อัปโหลด
  String _subtitleFor(AnalysisHistoryItem report) {
    final parts = <String>[];
    final size = _formatSize(report.fileSize);
    if (size.isNotEmpty) parts.add(size);
    final created = report.createdAt;
    if (created != null) {
      parts.add(_dateFormat.format(created.toLocal()));
    }
    final uploader = report.uploadedByUsername;
    if (uploader != null && uploader.isNotEmpty) parts.add(uploader);
    return parts.isEmpty ? '-' : parts.join(' • ');
  }

  /// เวลาของกิจกรรมล่าสุด ใช้รูปแบบเดียวกับรายงานสาธารณะ
  ///
  /// ถ้า parse ไม่ได้ให้แสดงสตริงดิบที่ backend ส่งมา — ข้อมูลผิดรูปแบบ
  /// ไม่ควรทำให้ทั้งแถวหาย
  String _activityTime(RecentActivity activity) {
    final created = activity.createdAt;
    if (created != null) return _dateFormat.format(created.toLocal());
    return activity.timestamp;
  }

  /// ชิปคะแนนรายเครื่องมือ — แสดงเฉพาะเครื่องมือที่รายงานนั้นมีคะแนนจริง
  ///
  /// เว้นระยะด้วย `Wrap(spacing:)` ของผู้เรียก วิดเจ็ตที่คืนจึงไม่มี padding ซ้ายต่อชิป
  List<Widget> _toolChipsFor(AnalysisHistoryItem report) {
    final aiScore = report.rampartAiScore?.malwareProbability;
    final chips = <({String label, double value})>[
      if (report.virustotalScore != null)
        (label: 'VT', value: report.virustotalScore!.toDouble()),
      if (report.mobsfScore != null)
        (label: 'MobSF', value: report.mobsfScore!),
      if (report.capeScore != null)
        (label: 'CAPE', value: report.capeScore!),
      if (aiScore != null)
        (label: 'AI', value: aiScore > 1 ? aiScore * 100 : aiScore),
    ];

    return [
      for (final chip in chips)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _tierColor(chip.value).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _tierColor(chip.value).withValues(alpha: 0.2)),
          ),
          child: Text(
            '${chip.label} ${chip.value.round()}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _tierColor(chip.value),
            ),
          ),
        ),
    ];
  }

  // ---------- กิจกรรมล่าสุด ----------

  Widget _buildRecentActivitiesSection() {
    final all = _bundle?.recentActivities ?? const <RecentActivity>[];
    // backend คืนมาได้ถึง 10 รายการ แต่ dashboard โชว์แค่ 5 อันดับแรก
    final activities = all.take(DashboardService.recentActivityLimit).toList();

    return _buildSection(
      title: 'กิจกรรมล่าสุด',
      subtitle: 'งานวิเคราะห์ที่เพิ่งเสร็จหรือกำลังทำ',
      icon: Icons.history,
      iconColor: _cyanColor,
      isEmpty: activities.isEmpty,
      emptyMessage: 'ยังไม่มีกิจกรรม',
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildActivityRow(activities[i]),
          ],
          if (activities.isNotEmpty) ...[
            const SizedBox(height: 12),
            // backend ให้แค่ 10 กิจกรรมล่าสุดตายตัว (endpoint ไม่รับ page/limit)
            // ประวัติฉบับเต็มที่เลื่อนโหลดเพิ่มได้อยู่ที่แท็บ Reports จึงพาไปที่นั่น
            _buildViewMoreButton(
              key: const Key('activities-view-more'),
              label: 'ดูเพิ่มเติม',
              icon: Icons.arrow_forward,
              isLoading: false,
              onTap: () => TabRefreshBus.select(TabRefreshBus.reportsTab),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityRow(RecentActivity activity) {
    final (icon, color, label) = switch (activity.status) {
      ActivityStatus.success => (Icons.check_circle, Colors.green, 'สำเร็จ'),
      ActivityStatus.processing => (
        Icons.autorenew,
        Colors.amber,
        'กำลังวิเคราะห์',
      ),
      ActivityStatus.pending => (Icons.hourglass_bottom, Colors.orange, 'รอวิเคราะห์'),
      ActivityStatus.failed => (Icons.cancel, Colors.red, 'ไม่สำเร็จ'),
      ActivityStatus.unknown => (Icons.help_outline, Colors.grey, activity.status.name),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.fileName.isEmpty ? '-' : activity.fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_activityTime(activity).isNotEmpty)
                  Text(
                    _activityTime(activity),
                    style: TextStyle(fontSize: 11, color: _hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- คะแนนความอันตรายตามประเภทไฟล์ ----------

  Widget _buildRiskScoresSection(DashboardSummary summary) {
    // เอาแค่ 10 ประเภทที่คะแนนสูงสุด (backend เรียง desc แล้ว, ปกติส่งมาไม่เกิน 5)
    final entries = summary.riskScores.take(10).toList();
    final average = _averageRisk(entries);

    return _buildSection(
      title: 'คะแนนความอันตราย',
      subtitle: 'ค่าเฉลี่ยจำแนกตามประเภทไฟล์',
      icon: Icons.shield,
      iconColor: Colors.amber,
      isEmpty: entries.isEmpty,
      emptyMessage: 'ไม่มีข้อมูลความเสี่ยง',
      child: Column(
        children: [
          _buildRiskGauge(average),
          const SizedBox(height: 16),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _buildRiskScoreRow(entries[i]),
          ],
        ],
      ),
    );
  }

  /// ค่าเฉลี่ยถ่วงน้ำหนักตามจำนวนไฟล์ของแต่ละประเภท
  double _averageRisk(List<RiskScoreEntry> entries) {
    if (entries.isEmpty) return 0;
    var total = 0.0;
    for (final e in entries) {
      total += e.riskScore;
    }
    return (total / entries.length).clamp(0, 100);
  }

  Widget _buildRiskGauge(double score) {
    final color = _tierColor(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CircularProgressIndicator(
                    value: (score / 100).clamp(0, 1),
                    strokeWidth: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1,
                      ),
                    ),
                    Text('/100', style: TextStyle(fontSize: 10, color: _hintColor)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'คะแนนเฉลี่ยทั้งระบบ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTierChip(score),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskScoreRow(RiskScoreEntry entry) {
    final score = entry.riskScore;
    final color = _tierColor(score);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
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
                entry.fileType.isEmpty ? '-' : entry.fileType,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (entry.toolScores.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tool in entry.toolScores)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tierColor(tool.value).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _tierColor(tool.value).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${tool.label} ${tool.value.round()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _tierColor(tool.value),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------- TOP 10 มัลแวร์ ----------

  Widget _buildTopMalwareSection(DashboardSummary summary) {
    final list = summary.topMalwareTypes.forRange(_selectedRange);

    return _buildSection(
      title: 'TOP 10 มัลแวร์',
      subtitle: '10 อันดับมัลแวร์ที่พบมากที่สุด',
      icon: Icons.bug_report,
      iconColor: Colors.red,
      trailing: _buildPeriodSelector(),
      isEmpty: list.isEmpty,
      emptyMessage: 'ไม่มีข้อมูลในขณะนี้',
      child: Column(
        children: [
          _buildMalwareChart(list),
          const SizedBox(height: 16),
          for (var i = 0; i < list.length && i < 10; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildMalwareRow(list[i], i, list),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('รายวัน', 'daily'),
          _buildPeriodButton('รายเดือน', 'monthly'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String range) {
    final isSelected = _selectedRange == range;
    return InkWell(
      // สองชุดข้อมูลมาพร้อมกันใน response เดียวกัน จึงไม่ต้องยิงซ้ำ
      onTap: () => setState(() => _selectedRange = range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: _cyanColor.withValues(alpha: 0.5)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _cyanColor : _hintColor,
          ),
        ),
      ),
    );
  }

  static const List<Color> _malwareColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFFB923C),
    Color(0xFFEC4899),
    Color(0xFFA855F7),
    Color(0xFF6366F1),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFF84CC16),
  ];

  Widget _buildMalwareChart(List<MalwareTypeEntry> entries) {
    final data = entries.take(10).toList();
    final maxCount = data.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    if (maxCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final entry = data[groupIndex];
                return BarTooltipItem(
                  '${entry.type}\n${entry.count} ครั้ง',
                  TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final name = data[index].type;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      name.length > 6 ? name.substring(0, 6) : name,
                      style: TextStyle(fontSize: 9, color: _hintColor),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: 9, color: _hintColor),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: _malwareColors[i % _malwareColors.length],
                    width: 14,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMalwareRow(MalwareTypeEntry entry, int index, List<MalwareTypeEntry> all) {
    final maxCount = all.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    final ratio = maxCount == 0 ? 0.0 : entry.count / maxCount;
    final color = _malwareColors[index % _malwareColors.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_formatNumber(entry.count)} ครั้ง',
            style: TextStyle(fontSize: 12, color: _hintColor),
          ),
        ],
      ),
    );
  }

  // ---------- ส่วนประกอบร่วม ----------

  /// ปุ่ม "ดูเพิ่มเติม" เต็มความกว้างของการ์ด
  ///
  /// [isLoading] = กำลังดึงหน้าถัดไป ปุ่มจะถูกปิดและโชว์ตัวหมุนแทนลูกศร
  Widget _buildViewMoreButton({
    required VoidCallback onTap,
    required bool isLoading,
    Key? key,
    String label = 'ดูเพิ่มเติม',
    IconData icon = Icons.expand_more,
  }) {
    return SizedBox(
      width: double.infinity,
      key: key,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _cyanColor,
          backgroundColor: _cardColor,
          side: BorderSide(color: _cyanColor.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _cyanColor),
              )
            : Icon(icon, size: 18),
        label: Text(
          isLoading ? 'กำลังโหลด...' : label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isEmpty,
    required String emptyMessage,
    required Widget child,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: _hintColor)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        if (isEmpty) _buildEmptyState(icon, emptyMessage) else child,
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: _hintColor.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _textColor,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _hintColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (color, label) = switch (status) {
      'success' => (Colors.green, status),
      'failed' => (Colors.red, status),
      'pending' => (Colors.orange, status),
      _ => (_hintColor, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildTierChip(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _tierColor(score).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tierColor(score).withValues(alpha: 0.2)),
      ),
      child: Text(
        _tierLabel(score),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _tierColor(score),
        ),
      ),
    );
  }

  /// เกณฑ์ระดับความอันตราย — ค่าเดียวกับที่หน้าเว็บใช้
  static String _tierLabel(double score) {
    if (score >= 80) return 'อันตรายร้ายแรง';
    if (score >= 60) return 'อันตราย';
    if (score >= 30) return 'ความเสี่ยงปานกลาง';
    return 'ปลอดภัย';
  }

  static Color _tierColor(double score) {
    if (score >= 80) return const Color(0xFFF87171);
    if (score >= 60) return const Color(0xFFFB923C);
    if (score >= 30) return const Color(0xFFFBBF24);
    return const Color(0xFF34D399);
  }
}
