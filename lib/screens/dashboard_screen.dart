import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/dashboard_stats.dart';
import '../services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final DashboardService _dashboardService = DashboardService();

  // State variables
  bool _isLoading = true;
  String _error = '';
  DashboardStats? _stats;
  String _selectedPeriod = 'monthly'; // 'daily' or 'monthly'

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
    _loadDashboardData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // TODO: ดึง token จาก storage หรือ state management
      const token = 'your_auth_token_here';

      // final stats = await _dashboardService.getDashboardStats(
      //   period: _selectedPeriod,
      //   token: token,
      // );

      setState(() {
        // _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _changePeriod(String period) async {
    setState(() {
      _selectedPeriod = period;
    });
    await _loadDashboardData();
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
            onRefresh: _loadDashboardData,
            color: _cyanColor,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildWelcomeCard(),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          _buildLoadingIndicator()
                        else if (_error.isNotEmpty)
                          _buildErrorCard()
                        else if (_stats != null) ...[
                          _buildPublicFilesSection(),
                          const SizedBox(height: 16),
                          _buildMyFilesSection(),
                          const SizedBox(height: 16),
                          _buildMembersCard(),
                          const SizedBox(height: 24),
                          _buildAverageRiskScore(),
                          const SizedBox(height: 24),
                          _buildTopMalwareSection(),
                        ],
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: [_cyanColor, _blueColor],
                ).createShader(bounds);
              },
              child: Text(
                'RAMPART',
                style: GoogleFonts.kanit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            Text(
              'Dashboard Analytics',
              style: GoogleFonts.kanit(
                fontSize: 12,
                color: _hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: _cyanColor.withOpacity(0.2),
                blurRadius: 15,
              ),
            ],
          ),
          child: Icon(
            Icons.dashboard,
            color: _cyanColor,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _cyanColor.withOpacity(0.2),
                _blueColor.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _cyanColor.withOpacity(0.3 + (_pulseController.value * 0.2)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _cyanColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cyanColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  color: _cyanColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ภาพรวมระบบ',
                      style: GoogleFonts.kanit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'สถิติการวิเคราะห์ไฟล์และมัลแวร์',
                      style: GoogleFonts.kanit(
                        fontSize: 13,
                        color: _hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_cyanColor),
          ),
          const SizedBox(height: 16),
          Text(
            'กำลังโหลดข้อมูล...',
            style: GoogleFonts.kanit(
              color: _hintColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(
            'เกิดข้อผิดพลาด',
            style: GoogleFonts.kanit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error,
            style: GoogleFonts.kanit(
              fontSize: 13,
              color: _hintColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            label: Text(
              'ลองอีกครั้ง',
              style: GoogleFonts.kanit(fontWeight: FontWeight.w600),
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

  // ส่วนแสดงจำนวนไฟล์ Public
  Widget _buildPublicFilesSection() {
    final publicFiles = _stats!.publicFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ไฟล์ Public ในระบบ',
          style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'สำเร็จ',
                value: _formatNumber(publicFiles.success),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending,
                label: 'รอวิเคราะห์',
                value: _formatNumber(publicFiles.pending),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.error,
                label: 'ไม่สำเร็จ',
                value: _formatNumber(publicFiles.failed),
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTotalCard(
          'ไฟล์ Public ทั้งหมด',
          publicFiles.total,
          _cyanColor,
        ),
      ],
    );
  }

  // ส่วนแสดงจำนวนไฟล์ของตัวเอง
  Widget _buildMyFilesSection() {
    final myFiles = _stats!.myFiles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ไฟล์ของฉัน',
          style: GoogleFonts.kanit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'สำเร็จ',
                value: _formatNumber(myFiles.success),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.pending,
                label: 'รอวิเคราะห์',
                value: _formatNumber(myFiles.pending),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.error,
                label: 'ไม่สำเร็จ',
                value: _formatNumber(myFiles.failed),
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTotalCard(
          'ไฟล์ของฉันทั้งหมด',
          myFiles.total,
          _blueColor,
        ),
      ],
    );
  }

  Widget _buildTotalCard(String label, int total, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.kanit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          Text(
            _formatNumber(total),
            style: GoogleFonts.kanit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ส่วนแสดงจำนวนสมาชิก
  Widget _buildMembersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _blueColor.withOpacity(0.2),
            _cyanColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _blueColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _blueColor.withOpacity(0.2),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _blueColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.people,
              color: _blueColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สมาชิกในระบบ',
                  style: GoogleFonts.kanit(
                    fontSize: 14,
                    color: _hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(_stats!.totalMembers),
                  style: GoogleFonts.kanit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ผู้ใช้งานทั้งหมด (ไม่รวม admin)',
                  style: GoogleFonts.kanit(
                    fontSize: 11,
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

  // ส่วนแสดงคะแนนความเสี่ยงเฉลี่ย
  Widget _buildAverageRiskScore() {
    final score = _stats!.averageRiskScore;
    final percentage = score / 100;

    Color scoreColor;
    String riskLevel;

    if (score >= 70) {
      scoreColor = Colors.red;
      riskLevel = 'สูง';
    } else if (score >= 40) {
      scoreColor = Colors.orange;
      riskLevel = 'ปานกลาง';
    } else {
      scoreColor = Colors.green;
      riskLevel = 'ต่ำ';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'คะแนนความเสี่ยงเฉลี่ย',
                style: GoogleFonts.kanit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scoreColor.withOpacity(0.5)),
                ),
                child: Text(
                  riskLevel,
                  style: GoogleFonts.kanit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scoreColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 150,
              width: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percentage,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toStringAsFixed(1),
                        style: GoogleFonts.kanit(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/ 100',
                        style: GoogleFonts.kanit(
                          fontSize: 16,
                          color: _hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'คะแนนเฉลี่ยของไฟล์มัลแวร์ที่ตรวจพบในระบบ',
            style: GoogleFonts.kanit(
              fontSize: 12,
              color: _hintColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ส่วนแสดง TOP 10 มัลแวร์
  Widget _buildTopMalwareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOP 10 มัลแวร์',
              style: GoogleFonts.kanit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
            _buildPeriodSelector(),
          ],
        ),
        const SizedBox(height: 16),
        if (_stats!.topMalwareTypes.isEmpty)
          _buildEmptyMalwareCard()
        else ...[
          _buildMalwareChart(),
          const SizedBox(height: 16),
          _buildMalwareList(),
        ],
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
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

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () => _changePeriod(period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: _cyanColor.withOpacity(0.5))
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.kanit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _cyanColor : _hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMalwareCard() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: _hintColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีข้อมูลมัลแวร์',
              style: GoogleFonts.kanit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มีการตรวจพบมัลแวร์ในช่วงเวลานี้',
              style: GoogleFonts.kanit(
                fontSize: 12,
                color: _hintColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMalwareChart() {
    final malwareData = _stats!.topMalwareTypes.take(10).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: malwareData.isNotEmpty
              ? malwareData.first.count.toDouble() * 1.2
              : 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final malware = malwareData[groupIndex];
                return BarTooltipItem(
                  '${malware.name}\n${malware.count} ไฟล์\n${malware.percentage.toStringAsFixed(1)}%',
                  GoogleFonts.kanit(
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
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= malwareData.length) {
                    return const SizedBox();
                  }
                  final name = malwareData[value.toInt()].name;
                  final displayName = name.length > 8
                      ? '${name.substring(0, 8)}...'
                      : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      displayName,
                      style: GoogleFonts.kanit(
                        fontSize: 10,
                        color: _hintColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.kanit(
                      fontSize: 10,
                      color: _hintColor,
                    ),
                  );
                },
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
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: malwareData.asMap().entries.map((entry) {
            final index = entry.key;
            final malware = entry.value;

            // สีต่างๆ สำหรับแต่ละ bar
            final colors = [
              Colors.red,
              Colors.orange,
              Colors.deepOrange,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.cyan,
              Colors.teal,
            ];

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: malware.count.toDouble(),
                  color: colors[index % colors.length],
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMalwareList() {
    final malwareData = _stats!.topMalwareTypes.take(10).toList();

    return Column(
      children: malwareData.asMap().entries.map((entry) {
        final index = entry.key;
        final malware = entry.value;

        final colors = [
          Colors.red,
          Colors.orange,
          Colors.deepOrange,
          Colors.pink,
          Colors.purple,
          Colors.deepPurple,
          Colors.indigo,
          Colors.blue,
          Colors.cyan,
          Colors.teal,
        ];

        final color = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: GoogleFonts.kanit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      malware.name,
                      style: GoogleFonts.kanit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${malware.count} ไฟล์',
                          style: GoogleFonts.kanit(
                            fontSize: 12,
                            color: _hintColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${malware.percentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.kanit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: _hintColor,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.kanit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _textColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.kanit(
              fontSize: 10,
              color: _hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }
}
