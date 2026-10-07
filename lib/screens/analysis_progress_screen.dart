import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../services/network_monitor_service.dart';
import '../widgets/analysis_components.dart';

class AnalysisProgressScreen extends StatefulWidget {
  const AnalysisProgressScreen({super.key});

  @override
  State<AnalysisProgressScreen> createState() => _AnalysisProgressScreenState();
}

class _AnalysisProgressScreenState extends State<AnalysisProgressScreen> {
  static const Duration _pollInterval = Duration(milliseconds: 2500);

  final AnalysisService _service = AnalysisService();
  final String _taskId = (Get.arguments as String?)?.trim() ?? '';

  Timer? _timer;
  Worker? _netWorker;
  bool _requestInFlight = false;
  bool _finished = false;
  bool _offline = false;
  /// poll จบด้วยสถานะล้มเหลวถาวร (ไม่ใช่แค่สะดุดชั่วคราว) — ต้องมีทางไปต่อเสมอ
  bool _failed = false;
  TaskStatusResult? _last;
  String? _transientError;

  /// ตรวจสถานะซ้ำอัตโนมัติหลังเจอ "ล้มเหลว" — backend แคชสถานะไว้ 3 วินาที
  /// จึงมีโอกาสที่แอป อ่านค่าเก่า (failed) แล้วหยุด poll ทั้งที่งานสำเร็จจริง
  static const int _maxVerifyRetries = 3;
  int _verifyRetries = 0;
  Timer? _verifyTimer;

  static const Map<String, String> _stageLabels = {
    'worker': 'กำลังเตรียมคิววิเคราะห์',
    'virustotal': 'ตรวจสอบกับ VirusTotal',
    'sandboxes': 'วิเคราะห์ใน sandbox (MobSF / CAPE)',
    'cape': 'วิเคราะห์ด้วย CAPE',
    'rampart_ai': 'วิเคราะห์ด้วยโมเดล AI',
    'rampartai': 'วิเคราะห์ด้วยโมเดล AI',
    'gemini': 'สรุปผลด้วย Gemini',
    'complete': 'วิเคราะห์เสร็จสิ้น',
    'failed': 'การวิเคราะห์ล้มเหลว',
  };

  @override
  void initState() {
    super.initState();
    // ออฟไลน์คือปิดการ poll ไปก่อน แล้วค่อยกลับมา poll ต่อเมื่อเน็ตกลับมา
    // ไม่เช่นนั้นจะยิงคำขอที่ล้มเหลวว่างเปล่าทุก 2.5 วินาที
    _netWorker = ever<bool>(NetworkMonitorService().isOnline, (online) {
      if (online) {
        _startPolling();
      } else {
        _pausePolling();
      }
    });
    _startPolling();
  }

  @override
  void dispose() {
    _netWorker?.dispose();
    _timer?.cancel();
    _verifyTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    if (_finished || _taskId.isEmpty) return;
    if (_timer != null) return;
    if (mounted) setState(() => _offline = false);
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _pausePolling() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _offline = true);
  }

  Future<void> _poll() async {
    if (_finished || _requestInFlight || _taskId.isEmpty) return;
    if (!NetworkMonitorService().isOnline.value) return;
    _requestInFlight = true;
    final result = await _service.getTaskStatus(_taskId);
    _requestInFlight = false;
    if (!mounted) return;

    // ยังไม่สำเร็จและไม่ได้แปลว่า "จบ" (เซิร์ฟเวอร์สะดุด/เซสชันหมดอายุชั่วคราว)
    // → แสดงการ์ดชั่วคราวแล้ว poll ต่อ ไม่ตรึงหน้าจอทิ้งแบบเดิม
    if (!result.success && !_isTerminalFailure(result)) {
      setState(() => _transientError = result.message);
      return;
    }

    setState(() {
      _last = result;
      _transientError = null;
    });

    if (result.isSuccess) {
      _stopPolling();
      if (Get.currentRoute == '/analysis-progress') {
        Get.offNamed('/analysis-result', arguments: _taskId);
      } else {
        // ระหว่างรอผล มีหน้าอื่นขึ้นมาทับแล้ว (เช่น แตะแจ้งเตือนแล้วเปิด
        // /analysis-result ของงานนี้ก่อน poll จบ) — offNamed จะโดน
        // preventDuplicates กลืนเงียบ ๆ ทำให้หน้านี้ติดค้างในสแตก
        // ผู้ใช้กดย้อนกลับมาเจอหน้าค้าง — ถอดตัวเองออกจากสแตกแทน
        Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      }
      return;
    }

    if (result.isFailed || !result.success) {
      // งานล้มเหลวจริง/ไม่พบงาน — หยุด poll แต่ต้องเหลือทางไปต่อ (ลองใหม่/เปิดรายงาน)
      _stopPolling();
      setState(() => _failed = true);
      _scheduleVerifyRetry();
    }
  }

  /// ตรวจสถานะซ้ำเองอีกไม่กี่ครั้ง (ห่างกัน 3 วินาที = เกิน TTL ของแคชฝั่ง server)
  /// ถ้าจริง ๆ งานสำเร็จแล้ว จะพาไปหน้ารายงานให้อัตโนมัติ ไม่ต้องให้ผู้ใช้กด
  void _scheduleVerifyRetry() {
    if (_verifyRetries >= _maxVerifyRetries) return;
    _verifyRetries++;
    _verifyTimer?.cancel();
    _verifyTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || _taskId.isEmpty) return;
      final result = await _service.getTaskStatus(_taskId);
      if (!mounted) return;

      if (result.isSuccess) {
        _stopPolling();
        if (Get.currentRoute == '/analysis-progress') {
          Get.offNamed('/analysis-result', arguments: _taskId);
        }
        return;
      }
      if (result.isFailed || !result.success) {
        _scheduleVerifyRetry();
        return;
      }
      // กลับมารันต่อ (เช่น job ยังไม่จบจริง) — เริ่ม poll ปกติใหม่
      setState(() {
        _failed = false;
        _last = result;
      });
      _startPolling();
    });
  }

  /// ความล้มเหลวถาวร: งานถูกทำเครื่องหมาย failed, ไม่พบงาน, หรือถูกปฏิเสธสิทธิ์
  /// ส่วน 5xx/timeout/เน็ตสะดุด ถือว่าชั่วคราว — ต้อง poll ต่อเอง
  bool _isTerminalFailure(TaskStatusResult result) {
    if (result.success) return result.isFailed;
    final message = (result.message ?? '').toUpperCase();
    if (message.contains('TASK_NOT_FOUND')) return true;
    return const {401, 403, 404}.contains(result.httpStatus);
  }

  void _stopPolling() {
    _finished = true;
    _timer?.cancel();
    _timer = null;
  }

  void _restartPolling() {
    _stopPolling();
    _verifyTimer?.cancel();
    _verifyRetries = 0;
    _finished = false;
    setState(() {
      _failed = false;
      _transientError = null;
      _last = null;
    });
    if (!NetworkMonitorService().isOnline.value) {
      _offline = true;
      return;
    }
    _startPolling();
  }

  ToolProgress? _progressFor(String tool) => _last?.progress?.tools[tool];

  /// สถานะดิบจาก backend (ก่อนบังคับลำดับการแสดง)
  ToolRunStatus _rawStatusFor(String tool) {
    final progress = _progressFor(tool);
    if (progress != null) return progress.status;

    final stage = _last?.progress?.stage?.toLowerCase();
    if (stage == 'complete') return ToolRunStatus.completed;
    if (stage == 'failed') return ToolRunStatus.failed;
    if (stage == tool ||
        (stage == 'sandboxes' && (tool == 'mobsf' || tool == 'cape'))) {
      return ToolRunStatus.running;
    }
    if (stage == 'rampart_ai' && tool == 'rampart_ai') {
      return ToolRunStatus.running;
    }
    if (stage == 'rampartai' && tool == 'rampart_ai') {
      return ToolRunStatus.running;
    }
    if (stage == 'gemini' && tool == 'gemini') {
      return ToolRunStatus.running;
    }
    return ToolRunStatus.waiting;
  }

  String? _noteFor(String tool) {
    final note = _last?.toolNotes[tool];
    if (note != null && note.isNotEmpty) return note;
    final message = _last?.progress?.message;
    if (message != null &&
        message.isNotEmpty &&
        _last?.progress?.error == null) {
      return tool == 'gemini' ? message : null;
    }
    return null;
  }

  String _stageText() {
    final stage = _last?.progress?.stage;
    if (stage == null || stage.isEmpty) return 'กำลังเริ่มวิเคราะห์...';
    return _stageLabels[stage] ?? stage;
  }

  ToolRunStatus _pageStatus() {
    if (_finished && _failed) return ToolRunStatus.failed;
    return ToolRunStatus.running;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AnalysisColors.background,
              AnalysisColors.surface,
              Color(0xFF111827),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildPipelineHeader(),
                    const SizedBox(height: 16),
                    _buildPipeline(),
                    if (_last?.toolNotes.isNotEmpty ?? false) ...[
                      const SizedBox(height: 16),
                      _buildNotesCard(),
                    ],
                    if (_offline) ...[
                      const SizedBox(height: 12),
                      _buildOfflineCard(),
                    ],
                    if (_failed) ...[
                      const SizedBox(height: 12),
                      _buildFailedCard(),
                    ],
                    if (_transientError != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorCard(),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'ย้อนกลับ',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: popAnalysisScreen,
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Live Analysis',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          AnalysisStatusBadge(
            status: _pageStatus(),
            label: _finished ? 'จบการวิเคราะห์' : 'กำลังวิเคราะห์',
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'Analysis Pipeline',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(
            _last?.progress?.message ?? _stageText(),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipeline() {
    // สถานะทั้ง pipeline คำนวณเป็นชุดเดียวเพื่อบังคับให้ stage เปิดตามลำดับ —
    // Stage 1 เหลืองตั้งแต่เปิดหน้า, Stage 2 ฟ้าจน Stage 1 จบ, Stage 3 ฟ้าจน Stage 2 จบ
    final display = deriveSequentialPipelineStatuses(
      virustotal: _rawStatusFor('virustotal'),
      mobsf: _rawStatusFor('mobsf'),
      cape: _rawStatusFor('cape'),
      rampartAi: _rawStatusFor('rampart_ai'),
      gemini: _rawStatusFor('gemini'),
      stillRunning: !_finished,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnector([display.virustotal, display.engine, display.gemini]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildStage(
                number: 1,
                title: 'Stage 1 — Initial Triage',
                status: display.virustotal,
                child: _buildToolCard('virustotal', display.virustotal),
              ),
              const SizedBox(height: 12),
              _buildStage(
                number: 2,
                title: 'Stage 2 — Multi-Engine Analysis',
                status: display.engine,
                child: Column(
                  children: [
                    const Text(
                      'Parallel Processing',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 11,
                        color: AnalysisColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildToolCard('mobsf', display.mobsf),
                    const SizedBox(height: 8),
                    _buildToolCard('cape', display.cape),
                    const SizedBox(height: 8),
                    _buildToolCard('rampart_ai', display.rampartAi),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStage(
                number: 3,
                title: 'Stage 3 — AI Recommendation',
                status: display.gemini,
                inputLabel: _geminiInputLabel(),
                child: _buildToolCard('gemini', display.gemini),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(List<ToolRunStatus> statuses) {
    return Column(
      children: [
        for (var index = 0; index < statuses.length; index++) ...[
          _buildConnectorNode(statuses[index], index + 1),
          if (index < statuses.length - 1)
            Container(
              width: 2,
              height: 126,
              color: AnalysisColors.status(
                statuses[index + 1],
              ).withValues(alpha: 0.3),
            ),
        ],
      ],
    );
  }

  Widget _buildConnectorNode(ToolRunStatus status, int number) {
    final color = AnalysisColors.status(status);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AnalysisColors.surface,
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStage({
    required int number,
    required String title,
    required ToolRunStatus status,
    required Widget child,
    String? inputLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: AnalysisColors.textMuted,
                ),
              ),
            ),
            if (inputLabel != null)
              Text(
                inputLabel,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 10,
                  color: AnalysisColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AnalysisCard(
          status: status,
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ],
    );
  }

  Widget _buildToolCard(String tool, ToolRunStatus status) {
    final progress = _progressFor(tool);
    final score = progress?.score;
    final message = _noteFor(tool);
    final title = switch (tool) {
      'virustotal' => 'VirusTotal Scan',
      'mobsf' => 'MobSF Static Analysis',
      'cape' => 'CAPE Analysis',
      'rampart_ai' => 'Machine Learning Detection',
      'gemini' => 'Gemini AI Analysis',
      _ => analysisToolLabel(tool),
    };
    final subtitle = switch (tool) {
      'virustotal' => 'Multi-engine antivirus detection',
      'mobsf' => 'Mobile Security Framework',
      'cape' => 'Automated malware sandbox',
      'rampart_ai' => 'ML-based prediction model',
      'gemini' => 'AI-powered security recommendation',
      _ => analysisToolLabel(tool),
    };

    return AnalysisToolCard(
      tool: tool,
      title: title,
      subtitle: subtitle,
      status: status,
      message: message,
      child: _buildToolBody(tool, status, score),
    );
  }

  Widget _buildToolBody(String tool, ToolRunStatus status, num? score) {
    if (status == ToolRunStatus.completed) {
      final value = score == null ? '-' : score.toStringAsFixed(0);
      return Row(
        children: [
          const Text(
            'คะแนน',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AnalysisColors.textPrimary,
            ),
          ),
        ],
      );
    }

    final text = switch (status) {
      ToolRunStatus.running => 'กำลังประมวลผล...',
      ToolRunStatus.failed => 'วิเคราะห์ไม่สำเร็จ',
      ToolRunStatus.skipped => 'ข้ามการวิเคราะห์',
      _ => 'รอเริ่มการวิเคราะห์',
    };
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Kanit',
        fontSize: 12,
        color: AnalysisColors.status(status),
      ),
    );
  }

  String _geminiInputLabel() {
    final inputs = <String>[];
    if (_rawStatusFor('mobsf') == ToolRunStatus.completed) inputs.add('MobSF');
    if (_rawStatusFor('cape') == ToolRunStatus.completed) inputs.add('CAPE');
    return 'Input: ${inputs.isEmpty ? 'None' : inputs.join(' + ')}';
  }

  Widget _buildNotesCard() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Tool Notes'),
          const SizedBox(height: 10),
          for (final entry in _last!.toolNotes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${analysisToolLabel(entry.key)}: ${entry.value}',
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// แจ้งว่าหยุดรอเพราะไม่มีเน็ต — จะกลับไป poll ต่อเองเมื่อเน็ตกลับมา
  /// จึงไม่ต้องมีปุ่ม "ลองใหม่" เหมือนการ์ด error ปกติ
  Widget _buildOfflineCard() {
    return AnalysisCard(
      status: ToolRunStatus.running,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: AnalysisColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ขาดการเชื่อมต่อ — กำลังรอสัญญาณเน็ตเพื่ออัปเดตสถานะ',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// งานล้มเหลว/ไม่พบงาน — ต้องไม่ทิ้งผู้ใช้ไว้กับป้ายแดงเฉย ๆ
  /// (เคสจริง: แจ้งเตือนบอกไม่สำเร็จ แต่รายงานถูกสร้างสำเร็จภายหลัง)
  Widget _buildFailedCard() {
    final message = _last?.message;
    return AnalysisCard(
      status: ToolRunStatus.failed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'การวิเคราะห์ไม่สำเร็จ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AnalysisColors.failed,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (message != null && message.isNotEmpty && message != 'TASK_NOT_FOUND')
                ? message
                : 'ไม่พบงานวิเคราะห์นี้ หรือระบบแจ้งว่าล้มเหลว',
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'หากระบบวิเคราะห์สำเร็จภายหลัง (มีการลองซ้ำ) รายงานจะเปิดได้จากปุ่มด้านล่างหรือแท็บรายงาน',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: _restartPolling,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnalysisColors.cyan,
                ),
                child: const Text('ลองใหม่',
                    style: TextStyle(fontFamily: 'Kanit')),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _openReport,
                style: FilledButton.styleFrom(
                  backgroundColor: AnalysisColors.cyan,
                  foregroundColor: AnalysisColors.background,
                ),
                child: const Text('เปิดรายงาน',
                    style: TextStyle(fontFamily: 'Kanit')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReport() {
    Get.toNamed('/analysis-result', arguments: _taskId);
  }

  Widget _buildErrorCard() {
    return AnalysisCard(
      status: ToolRunStatus.failed,
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: AnalysisColors.running),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _transientError!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.running,
              ),
            ),
          ),
          TextButton(
            onPressed: _restartPolling,
            child: const Text('ลองใหม่', style: TextStyle(fontFamily: 'Kanit')),
          ),
        ],
      ),
    );
  }
}
