import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  String _selectedFilter = 'all'; // all, malware, safe, pending

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
    super.dispose();
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
              Expanded(
                child: _buildReportsList(),
              ),
            ],
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
            'รายงานทั้งหมด',
            style: GoogleFonts.kanit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'ประวัติการวิเคราะห์ไฟล์ของคุณ',
          style: GoogleFonts.kanit(
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
          _buildFilterChip('all', 'ทั้งหมด', Icons.folder_outlined),
          const SizedBox(width: 12),
          _buildFilterChip('malware', 'มัลแวร์', Icons.bug_report),
          const SizedBox(width: 12),
          _buildFilterChip('safe', 'ปลอดภัย', Icons.verified_user),
          const SizedBox(width: 12),
          _buildFilterChip('pending', 'กำลังวิเคราะห์', Icons.pending),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _cyanColor.withOpacity(0.2) : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _cyanColor : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? _cyanColor : _hintColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.kanit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _cyanColor : _hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    final reports = _getFilteredReports();

    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: _hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่พบรายงาน',
              style: GoogleFonts.kanit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _hintColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _buildReportCard(reports[index]);
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (report['status']) {
      case 'malware':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        statusLabel = 'Malware Detected';
        break;
      case 'safe':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'Safe';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusLabel = 'Analyzing';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusLabel = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['fileName'],
                      style: GoogleFonts.kanit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['time'],
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        color: _hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.kanit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (report['status'] == 'malware') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ตรวจพบ ${report['threatsFound']} ภัยคุกคาม',
                      style: GoogleFonts.kanit(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // View details
                  },
                  icon: Icon(Icons.visibility_outlined, size: 18),
                  label: Text(
                    'ดูรายละเอียด',
                    style: GoogleFonts.kanit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cyanColor,
                    side: BorderSide(color: _cyanColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {
                  // Download report
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _cyanColor,
                  side: BorderSide(color: _cyanColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                child: Icon(Icons.download, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    final allReports = [
      {
        'fileName': 'suspicious_app.apk',
        'status': 'malware',
        'time': '2 ชั่วโมงที่แล้ว',
        'threatsFound': 3,
      },
      {
        'fileName': 'document.pdf',
        'status': 'safe',
        'time': '5 ชั่วโมงที่แล้ว',
      },
      {
        'fileName': 'installer.exe',
        'status': 'pending',
        'time': '1 วันที่แล้ว',
      },
      {
        'fileName': 'malware_sample.bin',
        'status': 'malware',
        'time': '2 วันที่แล้ว',
        'threatsFound': 5,
      },
      {
        'fileName': 'clean_app.apk',
        'status': 'safe',
        'time': '3 วันที่แล้ว',
      },
      {
        'fileName': 'testing.zip',
        'status': 'pending',
        'time': '4 วันที่แล้ว',
      },
    ];

    if (_selectedFilter == 'all') {
      return allReports;
    }

    return allReports
        .where((report) => report['status'] == _selectedFilter)
        .toList();
  }
}
