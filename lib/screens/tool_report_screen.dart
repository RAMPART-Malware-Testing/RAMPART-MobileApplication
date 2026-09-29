import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/tool_reports.dart';
import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../services/report_download_service.dart';
import '../widgets/analysis_components.dart';
import '../widgets/download_progress_dialog.dart';
import '../widgets/tool_reports/virustotal_report.dart';
import '../widgets/tool_reports/mobsf_report.dart';
import '../widgets/tool_reports/cape_report.dart';

class ToolReportScreen extends StatefulWidget {
  const ToolReportScreen({super.key});

  /// ดาวน์โหลด JSON ได้เฉพาะสามเครื่องมือที่รายงานถูกเก็บแยกเป็นไฟล์
  /// `.json` ต่อหนึ่งเครื่องมือ ส่วน `rampart_ai` / `gemini` ไม่มีไฟล์ของตัวเอง
  /// (Gemini ถูกรวมอยู่ในรายงานหลักอยู่แล้ว) จึงไม่ต้องมีปุ่มดาวน์โหลด
  static const Set<String> downloadableTools = {
    'virustotal',
    'mobsf',
    'cape',
  };

  /// เครื่องมือนี้มีไฟล์ JSON ให้ดาวน์โหลดหรือไม่
  static bool supportsJsonDownload(String tool) =>
      downloadableTools.contains(AnalysisReport.toolRouteKey(tool));

  @override
  State<ToolReportScreen> createState() => _ToolReportScreenState();
}

class _ToolReportScreenState extends State<ToolReportScreen> {
  final AnalysisService _service = AnalysisService();

  late final String _taskId;
  late final String _tool;
  late final String? _md5;
  late final String? _fileName;
  Map<String, dynamic>? _report;

  bool _loading = false;
  String? _error;
  bool _downloading = false;

  /// ใช้ค่าที่กล่องความคืบหน้าฟังอยู่ — กล่อง rebuild เฉพาะตัวเอง
  /// ไม่ดึงทั้งหน้าจอมาวาดใหม่ทุกครั้งที่เข้ามีข้อมูล (ดู R3 ใน AGENTS.md)
  final ValueNotifier<DownloadProgress?> _downloadProgress =
      ValueNotifier<DownloadProgress?>(null);

  @override
  void dispose() {
    _downloadProgress.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _taskId = args?['taskId']?.toString() ?? '';
    _tool = args?['tool']?.toString() ?? '';
    _md5 = args?['md5']?.toString();
    _fileName = args?['fileName']?.toString();
    _report = args?['report'] as Map<String, dynamic>?;

    if (_report == null) {
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.getToolReport(taskId: _taskId, tool: _tool);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.success && result.report != null) {
        _report = result.report;
      } else {
        _error = result.message?.isNotEmpty == true
            ? result.message
            : 'ไม่สามารถโหลดรายงานได้';
      }
    });
  }

  bool get _canDownload {
    final md5 = _md5;
    if (md5 == null || md5.isEmpty) return false;
    return ToolReportScreen.supportsJsonDownload(_tool);
  }

  Future<void> _download() async {
    final md5 = _md5;
    if (md5 == null || md5.isEmpty || _downloading) return;

    setState(() => _downloading = true);
    _downloadProgress.value = DownloadProgress.zero;

    // กล่องความคืบหน้าปิดเองไม่ได้ (barrierDismissible: false + PopScope) แต่ต้องการ
    // flag กันเผื่อว่ามันถูกปิดไปทางอื่นแล้ว จะได้ไม่ไป pop หน้าจอหลักทั้งที่ตั้งใจปิดกล่อง
    var progressOpen = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DownloadProgressDialog(
          title: 'กำลังดาวน์โหลดรายงาน ${analysisToolLabel(_tool)}',
          progress: _downloadProgress,
        ),
      ).whenComplete(() => progressOpen = false),
    );

    DownloadOutcome outcome;
    try {
      outcome = await ReportDownloadService.instance.download(
        tool: _tool,
        md5: md5,
        fileName: _fileName,
        onProgress: (value) => _downloadProgress.value = value,
      );
    } catch (e) {
      outcome = DownloadOutcome(
        success: false,
        fileName: _fileName,
        message: 'เกิดข้อผิดพลาด: $e',
      );
    }

    // หน้าจอถูกปิดไประหว่างดาวน์โหลด — กล่องความคืบหน้าถูกปิดไปพร้อม route แล้ว
    // และไม่ต้อง setState บน widget ที่ตายแล้ว
    if (!mounted) return;
    setState(() => _downloading = false);

    if (progressOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    await showDialog<void>(
      context: context,
      builder: (_) => DownloadResultDialog(
        outcome: outcome,
        onRetry: outcome.success ? null : _download,
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
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'ย้อนกลับ',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: popAnalysisScreen,
          ),
          Expanded(
            child: Text(
              analysisToolLabel(_tool),
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (_canDownload)
            IconButton(
              tooltip: 'ดาวน์โหลดรายงาน',
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AnalysisColors.cyan,
                      ),
                    )
                  : const Icon(Icons.download, color: AnalysisColors.cyan),
              onPressed: _downloading ? null : _download,
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, color: AnalysisColors.cyan, size: 34),
            SizedBox(height: 12),
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

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AnalysisColors.failed,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  color: AnalysisColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loadReport,
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

    final report = _report;
    if (report == null) {
      return const Center(
        child: Text(
          'ไม่พบรายงาน',
          style: TextStyle(
            fontFamily: 'Kanit',
            color: AnalysisColors.textSecondary,
          ),
        ),
      );
    }

    return _buildReportContent(report);
  }

  Widget _buildReportContent(Map<String, dynamic> report) {
    final normalised = AnalysisReport.toolRouteKey(_tool);

    switch (normalised) {
      case 'virustotal':
        final parsed = ToolReport.parse(_tool, _taskId, null, report);
        if (parsed?.virustotal == null) return _buildUnsupported();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            VirusTotalReportWidget(report: parsed!.virustotal!),
          ],
        );

      case 'mobsf':
        final parsed = ToolReport.parse(_tool, _taskId, null, report);
        if (parsed?.mobsf == null) return _buildUnsupported();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            MobsfReportWidget(report: parsed!.mobsf!),
          ],
        );

      case 'cape':
        final parsed = ToolReport.parse(_tool, _taskId, null, report);
        if (parsed?.cape == null) return _buildUnsupported();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            CapeReportWidget(report: parsed!.cape!),
          ],
        );

      case 'rampartai':
        return _buildRampartAiSummary(report);

      case 'gemini':
        return _buildGeminiNotice();

      default:
        return _buildUnsupported();
    }
  }

  Widget _buildRampartAiSummary(Map<String, dynamic> report) {
    final prediction = report['prediction']?.toString();
    final malwareProb = _asDouble(report['malware_probability']);
    final benignProb = _asDouble(report['benign_probability']);
    final confidence = report['confidence'];

    String displayPrediction = prediction ?? 'Unknown';
    if (prediction == null) {
      final score = malwareProb ?? _asDouble(report) ?? 0;
      displayPrediction = score >= 0.5 ? 'Malware' : 'Benign';
    }

    final isMalware = displayPrediction.toLowerCase().contains('malware');
    final displayConfidence = malwareProb != null
        ? '${(malwareProb * 100).round()}%'
        : confidence?.toString() ?? '-';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isMalware
                        ? AnalysisColors.failed
                        : AnalysisColors.completed)
                    .withValues(alpha: 0.15),
                border: Border.all(
                  color: (isMalware
                          ? AnalysisColors.failed
                          : AnalysisColors.completed)
                      .withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: Center(
                child: Icon(
                  isMalware ? Icons.warning : Icons.check_circle,
                  size: 40,
                  color:
                      isMalware ? AnalysisColors.failed : AnalysisColors.completed,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayPrediction,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color:
                    isMalware ? AnalysisColors.failed : AnalysisColors.completed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: $displayConfidence',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                color: AnalysisColors.textSecondary,
              ),
            ),
            if (malwareProb != null || benignProb != null) ...[
              const SizedBox(height: 20),
              AnalysisCard(
                child: Column(
                  children: [
                    if (malwareProb != null)
                      _probRow(
                        'Malware Probability',
                        malwareProb,
                        AnalysisColors.failed,
                      ),
                    if (malwareProb != null && benignProb != null)
                      const SizedBox(height: 8),
                    if (benignProb != null)
                      _probRow(
                        'Benign Probability',
                        benignProb,
                        AnalysisColors.completed,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _probRow(String label, double value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ),
        Text(
          '${(value * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildGeminiNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AnalysisColors.purple,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'ผลการวิเคราะห์จาก Gemini AI',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AnalysisColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ผลการวิเคราะห์จาก Gemini AI รวมอยู่ในรายงานหลักแล้ว '
              'กรุณากลับไปดูในหน้าผลการวิเคราะห์',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                color: AnalysisColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: popAnalysisScreen,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('ย้อนกลับ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AnalysisColors.purple,
                side: const BorderSide(color: AnalysisColors.purple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupported() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.help_outline,
              color: AnalysisColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'ไม่รองรับการแสดงรายงานนี้',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 14,
                color: AnalysisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: popAnalysisScreen,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('ย้อนกลับ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AnalysisColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }
}
