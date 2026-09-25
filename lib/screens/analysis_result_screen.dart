import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/authService.dart';
import '../services/analysis_service.dart';
import '../widgets/analysis_components.dart';

class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({super.key});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _ToolDetailState {
  const _ToolDetailState({this.loading = false, this.error, this.data});

  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;
}

class _ToolScore {
  const _ToolScore(this.tool, this.score);

  final String tool;
  final num? score;
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final AnalysisService _service = AnalysisService();
  final AuthService _authService = AuthService();
  final String _taskId = (Get.arguments as String?)?.trim() ?? '';
  final Map<String, _ToolDetailState> _toolDetails = {};

  bool _loading = true;
  String? _error;
  AnalysisReport? _report;
  String? _profileUid;
  bool _privacySaving = false;
  late bool _isPrivate = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _toolDetails.clear();
    });

    final values = await Future.wait<Object>([
      _service.getTaskStatus(_taskId),
      _authService.getProfile(),
    ]);
    if (!mounted) return;

    final status = values[0] as TaskStatusResult;
    final profile = values[1] as Map<String, dynamic>;
    if (!status.isSuccess || status.report == null) {
      setState(() {
        _loading = false;
        _error = status.message?.isNotEmpty == true
            ? status.message
            : 'ไม่พบรายงานนี้';
      });
      return;
    }

    final report = status.report!;
    final profileData = profile['data'];
    _profileUid = profileData is Map
        ? profileData['uid']?.toString()
        : profile['uid']?.toString();
    setState(() {
      _report = report;
      _isPrivate = report.privacy;
      _loading = false;
    });

    final tools = report.toolList.where((tool) => tool.isNotEmpty).toList();
    if (tools.isNotEmpty) {
      await Future.wait(tools.map(_loadTool));
    }
  }

  Future<void> _loadTool(String tool) async {
    final current = _toolDetails[tool];
    if (current?.loading == true || current?.data != null) return;
    if (AnalysisReport.usesEmbeddedReport(tool)) {
      if (!mounted) return;
      setState(() => _toolDetails[tool] = const _ToolDetailState(data: {}));
      return;
    }
    if (mounted) {
      setState(
        () => _toolDetails[tool] = const _ToolDetailState(loading: true),
      );
    }

    final result = await _service.getToolReport(taskId: _taskId, tool: tool);
    if (!mounted) return;
    setState(() {
      _toolDetails[tool] = result.success
          ? _ToolDetailState(data: result.report)
          : _ToolDetailState(
              error: result.message?.isNotEmpty == true
                  ? result.message
                  : 'โหลดรายละเอียดไม่สำเร็จ',
            );
    });
  }

  bool get _isOwner {
    final uid = _report?.uid.trim() ?? '';
    return uid.isNotEmpty && uid == _profileUid;
  }

  Future<void> _setPrivacy(bool isPrivate) async {
    final report = _report;
    if (report == null ||
        !_isOwner ||
        _privacySaving ||
        isPrivate == _isPrivate) {
      return;
    }
    final previous = _isPrivate;
    setState(() {
      _isPrivate = isPrivate;
      _privacySaving = true;
    });
    final result = await _service.updatePrivacy(
      taskId: report.taskId,
      privacy: isPrivate,
    );
    if (!mounted) return;
    setState(() => _privacySaving = false);
    if (result['success'] != true) {
      setState(() => _isPrivate = previous);
    }
  }

  static Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static dynamic _dig(dynamic value, List<String> path) {
    var current = value;
    for (final key in path) {
      final map = _map(current);
      if (map == null) return null;
      current = map[key];
    }
    return current;
  }

  static String _text(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is double) return value.toStringAsFixed(2);
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static num? _number(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  static int _count(dynamic value) {
    if (value is List) return value.length;
    final map = _map(value);
    return map?.length ?? 0;
  }

  static String _percent(num? value) =>
      value == null ? '-' : '${(value * 100).toStringAsFixed(1)}%';

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
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

  static String _toolTitle(String tool) {
    switch (AnalysisReport.toolRouteKey(tool)) {
      case 'virustotal':
        return 'VirusTotal Scan';
      case 'mobsf':
        return 'MobSF Static Analysis';
      case 'cape':
        return 'CAPE Analysis';
      case 'rampartai':
        return 'Machine Learning Detection';
      case 'gemini':
        return 'Gemini AI Analysis';
      default:
        return analysisToolLabel(tool);
    }
  }

  static String _toolSubtitle(String tool) {
    switch (AnalysisReport.toolRouteKey(tool)) {
      case 'virustotal':
        return 'Multi-engine antivirus detection';
      case 'mobsf':
        return 'Mobile Security Framework';
      case 'cape':
        return 'Automated malware sandbox';
      case 'rampartai':
        return 'ML-based prediction model';
      case 'gemini':
        return 'AI-powered security recommendation';
      default:
        return 'Security analysis';
    }
  }

  static String _toolKey(String tool) {
    final route = AnalysisReport.toolRouteKey(tool);
    return route == 'rampartai' ? 'rampart_ai' : route;
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
            onPressed: Get.back,
          ),
          const Expanded(
            child: Text(
              'ผลการวิเคราะห์',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            tooltip: 'โหลดใหม่',
            icon: const Icon(Icons.refresh, color: AnalysisColors.cyan),
            onPressed: _loading ? null : _load,
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
    if (_error != null) return _buildError(_error!);
    final report = _report;
    if (report == null) return _buildError('ไม่พบรายงานนี้');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _buildOverallResult(report),
        const SizedBox(height: 14),
        _buildToolScores(report),
        const SizedBox(height: 14),
        if (_isOwner) ...[_buildPrivacyCard(), const SizedBox(height: 14)],
        _buildRiskIndicators(report),
        const SizedBox(height: 14),
        _buildToolDetails(report),
        const SizedBox(height: 14),
        _buildFileCard(report),
        if (report.malwareSignatures.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildSignatures(report),
        ],
        if (report.toolNotes.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildNotes(report),
        ],
      ],
    );
  }

  Widget _buildError(String message) {
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Kanit',
                color: AnalysisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
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

  Widget _buildOverallResult(AnalysisReport report) {
    final score = report.score;
    final tier = score == null
        ? AnalysisScoreTier.fromRisk(report.riskLevel)
        : AnalysisScoreTier.fromScore(score);
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle(
            'คะแนนความอันตรายรวม',
            subtitle: 'Overall Danger Score',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score?.toStringAsFixed(0) ?? '-',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: tier.textColor,
                ),
              ),
              if (score != null)
                const Text(
                  ' / 100',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 10),
            AnalysisScoreBar(score: score),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(tier.label, tier.textColor),
              if (report.riskLevel?.isNotEmpty == true)
                _tag(report.riskLevel!, AnalysisColors.textSecondary),
            ],
          ),
          if (report.analysisSummary?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(
              report.analysisSummary!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                height: 1.5,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ],
          if (report.recommendation?.isNotEmpty == true ||
              report.geminiRecommendation?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 17,
                  color: AnalysisColors.cyan,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.geminiRecommendation ?? report.recommendation!,
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 13,
                      height: 1.4,
                      color: AnalysisColors.cyan,
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

  Widget _buildToolScores(AnalysisReport report) {
    final scores = _scores(report);
    if (scores.isEmpty) return const SizedBox.shrink();
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('คะแนนความเสี่ยงรายเครื่องมือ'),
          const SizedBox(height: 12),
          for (final item in scores) ...[
            Row(
              children: [
                AnalysisToolLogo(tool: item.tool, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysisToolLabel(item.tool),
                    style: const TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 12,
                      color: AnalysisColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  item.score == null
                      ? '-'
                      : '${item.score!.toStringAsFixed(0)}/100',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnalysisScoreTier.fromScore(item.score).textColor,
                  ),
                ),
              ],
            ),
            if (item.score != null) ...[
              const SizedBox(height: 6),
              AnalysisScoreBar(score: item.score, height: 5),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  List<_ToolScore> _scores(AnalysisReport report) {
    final listed = report.toolList.map(_toolKey).toSet();
    final all = <_ToolScore>[
      _ToolScore('virustotal', report.virustotalScore),
      _ToolScore('mobsf', report.mobsfScore),
      _ToolScore('cape', report.capeScore),
      _ToolScore(
        'rampart_ai',
        report.rampartAiScore?.malwareProbability == null
            ? null
            : report.rampartAiScore!.malwareProbability! <= 1
            ? report.rampartAiScore!.malwareProbability! * 100
            : report.rampartAiScore!.malwareProbability,
      ),
    ];
    return all
        .where(
          (item) =>
              item.score != null &&
              (listed.isEmpty || listed.contains(item.tool)),
        )
        .toList(growable: false);
  }

  Widget _buildPrivacyCard() {
    return AnalysisCard(
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined, color: AnalysisColors.cyan),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ความเป็นส่วนตัวของรายงาน',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'สาธารณะ: ทุกคนมองเห็น • ส่วนตัว: เฉพาะคุณ',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_privacySaving)
            const SizedBox(
              width: 18,
              height: 18,
              child: Icon(
                Icons.hourglass_top,
                size: 18,
                color: AnalysisColors.cyan,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _privacyChoice('สาธารณะ', !_isPrivate),
                _privacyChoice('ส่วนตัว', _isPrivate),
              ],
            ),
        ],
      ),
    );
  }

  Widget _privacyChoice(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _setPrivacy(label == 'ส่วนตัว'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (label == 'ส่วนตัว'
                      ? AnalysisColors.purple
                      : AnalysisColors.blue)
                : AnalysisColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.transparent : AnalysisColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AnalysisColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskIndicators(AnalysisReport report) {
    if (report.riskIndicators.isEmpty) return const SizedBox.shrink();
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Risk Indicators'),
          const SizedBox(height: 10),
          for (final indicator in report.riskIndicators)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AnalysisColors.purple,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      indicator,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        height: 1.4,
                        color: AnalysisColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolDetails(AnalysisReport report) {
    if (report.toolList.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: AnalysisSectionTitle('รายละเอียดรายเครื่องมือ'),
        ),
        for (final tool in report.toolList)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildToolTile(tool, report),
          ),
      ],
    );
  }

  Widget _buildToolTile(String tool, AnalysisReport report) {
    final detail = _toolDetails[tool];
    final status = detail?.data == null
        ? (detail?.loading == true
              ? ToolRunStatus.running
              : ToolRunStatus.waiting)
        : ToolRunStatus.completed;
    return AnalysisCard(
      status: status,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AnalysisColors.cyan,
          collapsedIconColor: AnalysisColors.textSecondary,
          title: Row(
            children: [
              AnalysisToolLogo(tool: _toolKey(tool), size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _toolTitle(tool),
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            _toolSubtitle(tool),
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 10.5,
              color: AnalysisColors.textSecondary,
            ),
          ),
          onExpansionChanged: (expanded) {
            if (expanded && detail == null) _loadTool(tool);
          },
          children: [
            if (detail?.loading == true)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.hourglass_top,
                      size: 16,
                      color: AnalysisColors.cyan,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'กำลังโหลดรายละเอียด...',
                      style: TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 12,
                        color: AnalysisColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (detail?.error != null)
              Text(
                detail!.error!,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.failed,
                ),
              )
            else if (detail?.data != null)
              _toolSummary(_toolKey(tool), detail!.data!, report)
            else
              TextButton.icon(
                onPressed: () => _loadTool(tool),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('โหลดรายละเอียด'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolSummary(
    String tool,
    Map<String, dynamic> data,
    AnalysisReport report,
  ) {
    switch (tool) {
      case 'virustotal':
        return _virusTotalSummary(data, report);
      case 'mobsf':
        return _mobSfSummary(data, report);
      case 'cape':
        return _capeSummary(data, report);
      case 'rampart_ai':
        return _rampartSummary(data, report);
      case 'gemini':
        return _geminiSummary(data, report);
      default:
        return Text(
          'ไม่มีรายละเอียดสำหรับเครื่องมือนี้',
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 12,
            color: AnalysisColors.textSecondary,
          ),
        );
    }
  }

  Widget _virusTotalSummary(Map<String, dynamic> data, AnalysisReport report) {
    final stats = _map(
      _dig(data, ['data', 'attributes', 'last_analysis_stats']),
    );
    final malicious = _number(stats?['malicious'])?.toInt() ?? 0;
    final total = stats == null
        ? 0
        : stats.values.fold<num>(
            0,
            (sum, value) => sum + (_number(value) ?? 0),
          );
    final score =
        report.virustotalScore ??
        _number(
          _dig(data, [
            'data',
            'attributes',
            'last_analysis_stats',
            'malicious',
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats != null)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnalysisMetricTile(
                label: 'Detection',
                value: '$malicious / $total',
                icon: Icons.shield_outlined,
              ),
              AnalysisMetricTile(
                label: 'Threat Score',
                value: score == null
                    ? '-'
                    : '${score.toStringAsFixed(0)} / 100',
              ),
            ],
          )
        else
          Text(
            'ไม่พบสถิติการตรวจจาก VirusTotal',
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
            ),
          ),
        if (data['data'] != null && data['data'] is Map) ...[
          const SizedBox(height: 10),
          const Text(
            'ผลการตรวจจากเอนจินตรวจพบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          ..._detectedEngines(data),
        ],
      ],
    );
  }

  List<Widget> _detectedEngines(Map<String, dynamic> data) {
    final results = _dig(data, ['data', 'attributes', 'last_analysis_results']);
    if (results is! List) return const [];
    final lines = <String>[];
    for (final entry in results) {
      final map = _map(entry);
      final category = map?['category']?.toString().toLowerCase();
      if (category != 'malicious' && category != 'suspicious') continue;
      lines.add(
        '${_text(map?['engine_name'] ?? map?['engine'])}: ${_text(map?['result'])}',
      );
      if (lines.length == 12) break;
    }
    return lines
        .map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              line,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11.5,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _mobSfSummary(Map<String, dynamic> data, AnalysisReport report) {
    final security = _number(_dig(data, ['appsec', 'security_score']));
    final risk =
        _number(data['risk_score']) ??
        (security == null
            ? report.mobsfScore
            : (100 - security).clamp(0, 100).toDouble());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AnalysisMetricTile(
              label: 'Permissions',
              value: '${_count(data['permissions'])}',
            ),
            AnalysisMetricTile(
              label: 'Activities',
              value: '${_count(data['activities'])}',
            ),
            AnalysisMetricTile(
              label: 'Services',
              value: '${_count(data['services'])}',
            ),
            AnalysisMetricTile(
              label: 'Receivers',
              value: '${_count(data['receivers'])}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Risk Score',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.textSecondary,
                ),
              ),
            ),
            Text(
              risk == null ? '-' : '${risk.toStringAsFixed(0)} / 100',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AnalysisScoreTier.fromScore(risk).textColor,
              ),
            ),
          ],
        ),
        if (risk != null) ...[
          const SizedBox(height: 6),
          AnalysisScoreBar(score: risk, height: 5),
        ],
      ],
    );
  }

  Widget _capeSummary(Map<String, dynamic> data, AnalysisReport report) {
    final network = _dig(data, ['network']);
    final behavior = _dig(data, ['behavior']);
    final summary = _map(_dig(behavior, ['summary']));
    final danger = _number(data['danger_score']) ?? report.capeScore;
    final networkCount =
        _count(_map(network)?['http']) + _count(_map(network)?['dns']);
    final registry = _count(summary?['keys']);
    final files = _count(summary?['files']);
    final processes = _count(_map(behavior)?['processes']);
    final behaviorReport = _text(
      summary?['behavior'] ?? _dig(data, ['behavior', 'summary', 'text']),
      fallback: '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Danger Score',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12,
                  color: AnalysisColors.textSecondary,
                ),
              ),
            ),
            Text(
              danger == null ? '-' : '${danger.toStringAsFixed(0)} / 100',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AnalysisScoreTier.fromScore(danger).textColor,
              ),
            ),
          ],
        ),
        if (danger != null) ...[
          const SizedBox(height: 6),
          AnalysisScoreBar(score: danger, height: 5),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AnalysisMetricTile(
              label: 'Network',
              value: '$networkCount',
              icon: Icons.wifi,
            ),
            AnalysisMetricTile(
              label: 'Registry',
              value: '$registry',
              icon: Icons.storage_outlined,
            ),
            AnalysisMetricTile(
              label: 'Files',
              value: '$files',
              icon: Icons.folder_outlined,
            ),
            AnalysisMetricTile(
              label: 'Processes',
              value: '$processes',
              icon: Icons.memory_outlined,
            ),
          ],
        ),
        if (behaviorReport.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Behavior Report',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            behaviorReport,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _rampartSummary(Map<String, dynamic> data, AnalysisReport report) {
    final score = RampartAiScore.fromJson(
      data.isEmpty ? report.rampartAiScore : data,
    );
    final prediction = score.prediction ?? report.rampartAiScore?.prediction;
    final confidence = score.confidence ?? report.rampartAiScore?.confidence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnalysisMetricTile(
          label: 'Prediction',
          value: prediction ?? '-',
          valueColor: prediction?.toLowerCase().contains('malware') == true
              ? AnalysisColors.failed
              : AnalysisColors.completed,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AnalysisMetricTile(label: 'Confidence', value: _text(confidence)),
            AnalysisMetricTile(
              label: 'Malware Probability',
              value: _percent(score.malwareProbability),
            ),
            AnalysisMetricTile(
              label: 'Benign Probability',
              value: _percent(score.benignProbability),
            ),
          ],
        ),
      ],
    );
  }

  Widget _geminiSummary(Map<String, dynamic> data, AnalysisReport report) {
    final summary = _text(
      data['summary'],
      fallback: report.analysisSummary ?? '',
    );
    final threat = _text(
      data['threat_assessment'] ?? data['threatAssessment'],
      fallback: report.threatAssessment ?? '',
    );
    final behavior = _text(data['behavior'], fallback: report.behavior ?? '');
    final recommendation = _text(
      data['recommendation'],
      fallback: report.geminiRecommendation ?? report.recommendation ?? '',
    );
    final risk = _text(
      data['overall_risk'] ?? data['overallRisk'],
      fallback: report.riskLevel ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) _geminiMetric('Summary', summary),
        if (threat.isNotEmpty) _geminiMetric('Threat Assessment', threat),
        if (behavior.isNotEmpty) _geminiMetric('Behavior', behavior),
        if (recommendation.isNotEmpty)
          _geminiMetric('Recommendation', recommendation),
        if (risk.isNotEmpty) _geminiMetric('Overall Risk', risk),
        if (summary.isEmpty &&
            threat.isEmpty &&
            behavior.isEmpty &&
            recommendation.isEmpty &&
            risk.isEmpty)
          const Text(
            'ไม่มีรายละเอียดจาก Gemini',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _geminiMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 11,
              color: AnalysisColors.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              height: 1.35,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(AnalysisReport report) {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('ข้อมูลไฟล์'),
          const SizedBox(height: 10),
          _row('ชื่อไฟล์', report.fileName ?? '-'),
          _row('ขนาด', _formatSize(report.fileSize)),
          _row('ประเภท', report.fileType ?? '-'),
          _row('เวลาที่วิเคราะห์', _formatDate(report.createdAt)),
          _row('การมองเห็น', _isPrivate ? 'ส่วนตัว' : 'สาธารณะ'),
          if (report.md5?.isNotEmpty == true) _row('MD5', report.md5!),
          if (report.fileHash?.isNotEmpty == true)
            _row('SHA-256', report.fileHash!),
        ],
      ),
    );
  }

  Widget _buildSignatures(AnalysisReport report) {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('ลายเซ็นมัลแวร์ที่ตรวจพบ'),
          const SizedBox(height: 10),
          for (final signature in report.malwareSignatures)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $signature',
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12.5,
                  color: AnalysisColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotes(AnalysisReport report) {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('หมายเหตุจากระบบ'),
          const SizedBox(height: 10),
          for (final entry in report.toolNotes.entries)
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Kanit',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
