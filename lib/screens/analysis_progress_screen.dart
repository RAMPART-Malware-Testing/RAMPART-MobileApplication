import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../theme/app_theme.dart';

/// ติดตามความคืบหน้าการวิเคราะห์
///
/// poll สถานะจาก backend ทุก 2.5 วินาที (จังหวะเดียวกับฝั่งเว็บ) แล้วพาไปหน้า
/// ผลลัพธ์เมื่อสถานะเป็น success — ระหว่างที่ยังไม่เสร็จจะแสดง stage และสถานะ
/// ของเครื่องมือแต่ละตัวจาก `progress.tools`
class AnalysisProgressScreen extends StatefulWidget {
  const AnalysisProgressScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisProgressScreen> createState() => _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState extends State<AnalysisProgressScreen> {
  static const Duration _pollInterval = Duration(milliseconds: 2500);

  final AnalysisService _service = AnalysisService();
  final String _taskId = (Get.arguments as String?)?.trim() ?? '';

  Timer? _timer;
  bool _requestInFlight = false;
  bool _finished = false;
  TaskStatusResult? _last;
  String? _transientError;

  Color get _cyan =>
      Theme.of(context).extension<CustomColors>()?.cyanColor ??
      const Color(0xff06b6d4);
  Color get _hint =>
      Theme.of(context).extension<CustomColors>()?.hintColor ??
      const Color(0xff94a3b8);

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_finished || _requestInFlight || _taskId.isEmpty) return;
    _requestInFlight = true;
    final result = await _service.getTaskStatus(_taskId);
    _requestInFlight = false;
    if (!mounted) return;

    // เครือข่ายสะดุด: คงสถานะล่าสุดไว้ ไม่หยุด polling และไม่ล้างผลที่ได้มาแล้ว
    if (!result.success && result.httpStatus == 0) {
      setState(() => _transientError = result.message);
      return;
    }

    setState(() {
      _last = result;
      _transientError = null;
    });

    if (result.isSuccess) {
      _stopPolling();
      Get.offNamed('/analysis-result', arguments: _taskId);
    } else if (result.isFailed || result.isNotFound) {
      _stopPolling();
    }
  }

  void _stopPolling() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
  }

  void _restartPolling() {
    _stopPolling();
    _finished = false;
    setState(() {
      _transientError = null;
      _last = null;
    });
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  static const Map<String, String> _toolLabels = {
    'virustotal': 'VirusTotal',
    'mobsf': 'MobSF',
    'cape': 'CAPE',
    'rampart_ai': 'RampartAI',
    'gemini': 'Gemini',
  };

  static const Map<String, String> _stageLabels = {
    'worker': 'กำลังเตรียมคิววิเคราะห์',
    'virustotal': 'ตรวจสอบกับ VirusTotal',
    'sandboxes': 'วิเคราะห์ใน sandbox (MobSF / CAPE)',
    'rampart_ai': 'วิเคราะห์ด้วยโมเดล AI',
    'gemini': 'สรุปผลด้วย Gemini',
    'complete': 'วิเคราะห์เสร็จสิ้น',
    'failed': 'การวิเคราะห์ล้มเหลว',
  };

  static const Map<ToolRunStatus, String> _toolStatusLabels = {
    ToolRunStatus.waiting: 'รอดำเนินการ',
    ToolRunStatus.running: 'กำลังทำงาน',
    ToolRunStatus.completed: 'สำเร็จ',
    ToolRunStatus.failed: 'ล้มเหลว',
    ToolRunStatus.skipped: 'ข้าม',
  };

  static const Map<ToolRunStatus, Color> _toolStatusColors = {
    ToolRunStatus.waiting: Color(0xff94a3b8),
    ToolRunStatus.running: Color(0xff06b6d4),
    ToolRunStatus.completed: Color(0xff22c55e),
    ToolRunStatus.failed: Color(0xffef4444),
    ToolRunStatus.skipped: Color(0xfff59e0b),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0f172a), Color(0xFF1e293b)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildToolCard(),
                    if (_last?.toolNotes.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      _buildNotesCard(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'กำลังวิเคราะห์ไฟล์',
              style: TextStyle(
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildStatusCard() {
    final task = _last;
    final stage = task?.progress?.stage;
    final stageText = stage == null
        ? 'กำลังเริ่มวิเคราะห์...'
        : (_stageLabels[stage] ?? stage);
    final message = task?.progress?.message ?? task?.message;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!_finished)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xff06b6d4),
                  ),
                ),
              if (!_finished) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stageText,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'task: $_taskId',
            style: TextStyle(fontFamily: 'Kanit', fontSize: 11, color: _hint),
          ),
          if (_last?.progress?.error != null &&
              _last!.progress!.error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _last!.progress!.error!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                color: Color(0xffef4444),
              ),
            ),
          ],
          if (_transientError != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.wifi_off, size: 16, color: Color(0xfff59e0b)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _transientError!,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: Color(0xfff59e0b),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_last?.isNotFound ?? false) ...[
            const SizedBox(height: 12),
            Text(
              'ไม่พบงานวิเคราะห์นี้',
              style: TextStyle(fontFamily: 'Kanit', fontSize: 14, color: _hint),
            ),
          ],
          if (_last?.isFailed ?? false) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _restartPolling,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text(
                  'ลองใหม่',
                  style: TextStyle(fontFamily: 'Kanit'),
                ),
                style: OutlinedButton.styleFrom(foregroundColor: _cyan),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolCard() {
    final tools = _last?.progress?.tools ?? const <String, ToolProgress>{};

    // ระหว่างที่ยังไม่มี progress ให้แสดงเครื่องมือทั้งหมดในสถานะรอ
    final names = tools.isNotEmpty ? tools.keys.toList() : _toolLabels.keys.toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เครื่องมือวิเคราะห์',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          for (final name in names) _buildToolRow(name, tools[name]),
        ],
      ),
    );
  }

  Widget _buildToolRow(String name, ToolProgress? progress) {
    final status = progress?.status ?? ToolRunStatus.waiting;
    final color = _toolStatusColors[status] ?? _hint;
    final score = progress?.score;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _toolLabels[name] ?? name,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          if (score != null) ...[
            Text(
              '${score is int ? score : score.toStringAsFixed(1)}',
              style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            _toolStatusLabels[status] ?? '',
            style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'หมายเหตุจากระบบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          for (final entry in _last!.toolNotes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_toolLabels[entry.key] ?? entry.key}: ${entry.value}',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 13,
                  color: _hint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
