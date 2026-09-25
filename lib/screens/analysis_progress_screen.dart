import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
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
  bool _requestInFlight = false;
  bool _finished = false;
  TaskStatusResult? _last;
  String? _transientError;

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

  ToolProgress? _progressFor(String tool) => _last?.progress?.tools[tool];

  ToolRunStatus _statusFor(String tool) {
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
    if (_finished && (_last?.isFailed ?? false)) return ToolRunStatus.failed;
    if (_finished && (_last?.isNotFound ?? false)) return ToolRunStatus.failed;
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
            onPressed: () => Get.back(),
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
    final vtStatus = _statusFor('virustotal');
    final mobsfStatus = _statusFor('mobsf');
    final capeStatus = _statusFor('cape');
    final aiStatus = _statusFor('rampart_ai');
    final geminiStatus = _statusFor('gemini');
    final engineStatus = deriveAnalysisStageStatus([
      mobsfStatus,
      capeStatus,
      aiStatus,
    ]);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConnector([vtStatus, engineStatus, geminiStatus]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildStage(
                number: 1,
                title: 'Stage 1 — Initial Triage',
                status: vtStatus,
                child: _buildToolCard('virustotal'),
              ),
              const SizedBox(height: 12),
              _buildStage(
                number: 2,
                title: 'Stage 2 — Multi-Engine Analysis',
                status: engineStatus,
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
                    _buildToolCard('mobsf'),
                    const SizedBox(height: 8),
                    _buildToolCard('cape'),
                    const SizedBox(height: 8),
                    _buildToolCard('rampart_ai'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStage(
                number: 3,
                title: 'Stage 3 — AI Recommendation',
                status: geminiStatus,
                inputLabel: _geminiInputLabel(),
                child: _buildToolCard('gemini'),
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

  Widget _buildToolCard(String tool) {
    final status = _statusFor(tool);
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
    if (_statusFor('mobsf') == ToolRunStatus.completed) inputs.add('MobSF');
    if (_statusFor('cape') == ToolRunStatus.completed) inputs.add('CAPE');
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
