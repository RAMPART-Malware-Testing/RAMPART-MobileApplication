import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/tool_reports.dart';
import '../analysis_components.dart';

class CapeReportWidget extends StatefulWidget {
  const CapeReportWidget({super.key, required this.report});

  final CapeReport report;

  @override
  State<CapeReportWidget> createState() => _CapeReportWidgetState();
}

class _CapeReportWidgetState extends State<CapeReportWidget> {
  bool _showingJson = false;
  String? _prettyJson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.report.isFatal) _buildFatalBanner(),
        if (!widget.report.isFatal && widget.report.warnings.isNotEmpty)
          _buildWarningBanner(),
        if (widget.report.isFatal || widget.report.warnings.isNotEmpty)
          const SizedBox(height: 12),
        _buildDetails(),
        const SizedBox(height: 12),
        _buildMetrics(),
        const SizedBox(height: 12),
        _buildRawJsonToggle(),
        if (_showingJson && _prettyJson != null) ...[
          const SizedBox(height: 12),
          _buildRawJsonViewer(),
        ],
      ],
    );
  }

  Widget _buildFatalBanner() {
    return AnalysisCard(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFF87171), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFF87171), size: 20),
                SizedBox(width: 8),
                Text(
                  '⚠️ การวิเคราะห์ล้มเหลว',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF87171),
                  ),
                ),
              ],
            ),
            if (widget.report.fatalMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.report.fatalMessage!,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
            if (widget.report.isJarPackageMismatch) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'ไฟล์ APK ของคุณถูกวิเคราะห์ในรูปแบบ JAR ซึ่งไม่เหมาะสม '
                  'แนะนำให้วิเคราะห์ใหม่โดยระบุ package type เป็น "apk" หรือ "android"',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    color: AnalysisColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return AnalysisCard(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ℹ️ การวิเคราะห์สำเร็จ แต่มีบางส่วนทำงานไม่ครบ',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ผลการวิเคราะห์หลักยังคงใช้งานได้ แต่มีส่วนประกอบบางอย่างที่ทำงานไม่สมบูรณ์:',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            for (final warning in widget.report.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning.contains('ไม่สำเร็จ') ? '⚠️' : '✅',
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 10,
                          color: AnalysisColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Analysis Details'),
          const SizedBox(height: 10),
          _detailRow('Task ID', _truncateTaskId(widget.report.rawJson['task_id'])),
          if (widget.report.started != null)
            _detailRow('Started', widget.report.started!),
          if (widget.report.duration != null)
            _detailRow('Duration', widget.report.duration!),
          if (widget.report.package != null)
            _detailRow('Package', widget.report.package!),
          if (widget.report.machineName != null)
            _detailRow('Machine', widget.report.machineName!),
          if (widget.report.malscore != null)
            _detailRow(
              'Score',
              '${widget.report.malscore!.toStringAsFixed(1)}/10',
            ),
          _detailRow('Status', widget.report.isFatal ? 'Failed' : 'Success'),
          if (widget.report.capeVersion != null)
            _detailRow('CAPE Version', widget.report.capeVersion!),
        ],
      ),
    );
  }

  String _truncateTaskId(dynamic taskId) {
    final id = taskId?.toString() ?? '';
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Captured Data'),
          const SizedBox(height: 10),
          _metricTile(
            'Processes',
            widget.report.processCount ?? 0,
            widget.report.processCount != null && widget.report.processCount! > 0
                ? 'บันทึกพฤติกรรมได้ ${widget.report.processCount} process'
                : 'ไม่มีข้อมูลพฤติกรรมถูกบันทึก',
            Icons.memory_outlined,
          ),
          const SizedBox(height: 8),
          _metricTile(
            'Network',
            widget.report.networkCount ?? 0,
            widget.report.networkCount != null && widget.report.networkCount! > 0
                ? 'จับทราฟฟิกเครือข่ายได้ตามปกติ'
                : 'ไม่มีข้อมูลเครือข่ายถูกบันทึก',
            Icons.wifi,
          ),
          const SizedBox(height: 8),
          _metricTile(
            'Signatures',
            widget.report.signatureCount ?? 0,
            widget.report.signatureCount != null &&
                    widget.report.signatureCount! > 0
                ? 'ตรวจพบ ${widget.report.signatureCount} signature'
                : 'ไม่มี signature ที่ตรงเงื่อนไข',
            Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, int value, String description, IconData icon) {
    final hasData = value > 0;
    final color = hasData ? AnalysisColors.cyan : AnalysisColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AnalysisColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasData
              ? AnalysisColors.cyan.withValues(alpha: 0.3)
              : AnalysisColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        color: AnalysisColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 10,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawJsonToggle() {
    return AnalysisCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _toggleJson,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _showingJson ? Icons.visibility_off : Icons.code,
                color: AnalysisColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _showingJson ? 'ซ่อน Raw JSON' : 'ดู Raw JSON',
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AnalysisColors.cyan,
                  ),
                ),
              ),
              Icon(
                _showingJson ? Icons.expand_less : Icons.expand_more,
                color: AnalysisColors.cyan,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleJson() async {
    if (_showingJson) {
      setState(() => _showingJson = false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AnalysisColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'แสดง Raw JSON',
          style: TextStyle(
            fontFamily: 'Kanit',
            color: AnalysisColors.textPrimary,
          ),
        ),
        content: const Text(
          'รายงานนี้มีขนาดใหญ่ การแสดงผลอาจใช้เวลาสักครู่',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 13,
            color: AnalysisColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(fontFamily: 'Kanit', color: AnalysisColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'แสดง',
              style: TextStyle(fontFamily: 'Kanit', color: AnalysisColors.cyan),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // สร้าง JSON หลังผู้ใช้ยืนยัน เพื่อไม่ให้ block UI
    final encoder = const JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(widget.report.rawJson);

    if (!mounted) return;
    setState(() {
      _prettyJson = pretty;
      _showingJson = true;
    });
  }

  Widget _buildRawJsonViewer() {
    return AnalysisCard(
      child: SizedBox(
        height: 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              _prettyJson!,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
