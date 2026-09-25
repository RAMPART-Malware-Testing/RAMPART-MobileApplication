import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/analysis.dart';
import '../services/analysis_service.dart';
import '../theme/app_theme.dart';

/// ผลการวิเคราะห์ไฟล์จากหลายเครื่องมือ
///
/// ตัวเลขสรุป (score / risk_level / *_score) มาจาก backend แล้ว หน้าจอนี้แค่
/// แสดงผลและโหลดรายละเอียดรายเครื่องมือเมื่อผู้ใช้กดดู
class AnalysisResultScreen extends StatefulWidget {
  const AnalysisResultScreen({Key? key}) : super(key: key);

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _ToolDetailState {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;

  const _ToolDetailState({this.loading = false, this.error, this.data});
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  final AnalysisService _service = AnalysisService();
  final String _taskId = (Get.arguments as String?)?.trim() ?? '';

  bool _loading = true;
  String? _error;
  AnalysisReport? _report;
  final Map<String, _ToolDetailState> _toolDetails = {};

  Color get _cyan =>
      Theme.of(context).extension<CustomColors>()?.cyanColor ??
      const Color(0xff06b6d4);
  Color get _hint =>
      Theme.of(context).extension<CustomColors>()?.hintColor ??
      const Color(0xff94a3b8);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _service.getTaskStatus(_taskId);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.isSuccess && result.report != null) {
        _report = result.report;
      } else {
        _error = (result.message?.isNotEmpty ?? false)
            ? result.message
            : 'ไม่พบรายงานนี้';
      }
    });
  }

  Future<void> _loadTool(String tool) async {
    setState(() => _toolDetails[tool] = const _ToolDetailState(loading: true));

    final result = await _service.getToolReport(taskId: _taskId, tool: tool);
    if (!mounted) return;

    setState(() {
      _toolDetails[tool] = result.success
          ? _ToolDetailState(data: result.report)
          : _ToolDetailState(
              error: (result.message?.isNotEmpty ?? false)
                  ? result.message
                  : 'โหลดรายละเอียดไม่สำเร็จ',
            );
    });
  }

  // ---------- helpers อ่านค่าจาก blob ของแต่ละเครื่องมือ ----------

  static Map<String, dynamic>? _mapAt(dynamic node) {
    if (node is Map) {
      return node.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static dynamic _dig(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      final map = _mapAt(current);
      if (map == null) return null;
      current = map[key];
    }
    return current;
  }

  static String _text(dynamic value) {
    if (value == null) return '-';
    if (value is double) return value.toStringAsFixed(2);
    return value.toString();
  }

  static int _countOf(dynamic value) => value is List ? value.length : 0;

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
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static const Map<String, String> _toolLabels = {
    'virustotal': 'VirusTotal',
    'mobsf': 'MobSF',
    'cape': 'CAPE',
    'rampart_ai': 'RampartAI',
    'gemini': 'Gemini',
  };

  String _riskLabel(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return 'ต่ำ (ปลอดภัย)';
      case 'caution':
        return 'ควรระวัง';
      case 'high':
        return 'สูง';
      case 'critical':
        return 'วิกฤต';
      default:
        return risk ?? '-';
    }
  }

  Color _riskColor(String? risk) {
    switch (risk?.toLowerCase()) {
      case 'low':
        return const Color(0xff22c55e);
      case 'caution':
        return const Color(0xfff59e0b);
      case 'high':
        return const Color(0xfff97316);
      case 'critical':
        return const Color(0xffef4444);
      default:
        return _hint;
    }
  }

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
              Expanded(child: _buildBody()),
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
            icon: Icon(Icons.refresh, color: _cyan),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff06b6d4)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Color(0xffef4444), size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Kanit', color: _hint),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(foregroundColor: _cyan),
                child: const Text('ลองใหม่', style: TextStyle(fontFamily: 'Kanit')),
              ),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return Center(
        child: Text(
          'ไม่พบรายงานนี้',
          style: TextStyle(fontFamily: 'Kanit', color: _hint),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildVerdictCard(report),
        const SizedBox(height: 16),
        _buildFileCard(report),
        if (report.toolList.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildToolDetailSection(report),
        ],
        if (report.malwareSignatures.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSignaturesCard(report),
        ],
        if (report.toolNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildNotesCard(report),
        ],
      ],
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Kanit',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdictCard(AnalysisReport report) {
    final riskColor = _riskColor(report.riskLevel);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('ผลสรุป')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  _riskLabel(report.riskLevel),
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          if (report.score != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  report.score!.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: riskColor,
                  ),
                ),
                Text(
                  ' / 100',
                  style: TextStyle(fontFamily: 'Kanit', fontSize: 14, color: _hint),
                ),
              ],
            ),
          ],
          if (report.analysisSummary != null &&
              report.analysisSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              report.analysisSummary!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
          if (report.recommendation != null &&
              report.recommendation!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: _cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.recommendation!,
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 13,
                      color: _cyan,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (report.riskIndicators.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final indicator in report.riskIndicators)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xfff97316),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        indicator,
                        style: TextStyle(
                          fontFamily: 'Kanit',
                          fontSize: 12.5,
                          color: _hint,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 12),
          _row(
            'VirusTotal',
            report.virustotalScore == null
                ? '-'
                : (report.virustotalScore! > 0 ? 'ตรวจพบมัลแวร์' : 'ไม่พบ'),
            valueColor: report.virustotalScore != null &&
                    report.virustotalScore! > 0
                ? const Color(0xffef4444)
                : null,
          ),
          _row(
            'MobSF',
            report.mobsfScore == null
                ? '-'
                : '${report.mobsfScore!.toStringAsFixed(1)} / 100',
          ),
          _row(
            'CAPE',
            report.capeScore == null
                ? '-'
                : '${report.capeScore!.toStringAsFixed(1)} / 100',
          ),
          if (report.rampartAiScore != null)
            _row(
              'RampartAI',
              report.rampartAiScore!.malwareProbability == null
                  ? (report.rampartAiScore!.prediction ?? '-')
                  : '${(report.rampartAiScore!.malwareProbability! * 100).toStringAsFixed(1)}%'
                      '${report.rampartAiScore!.prediction == null ? '' : ' (${report.rampartAiScore!.prediction})'}',
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(AnalysisReport report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ข้อมูลไฟล์'),
          const SizedBox(height: 10),
          _row('ชื่อไฟล์', report.fileName ?? '-'),
          _row('ขนาด', _formatSize(report.fileSize)),
          _row('ประเภท', report.fileType ?? '-'),
          _row('เวลาที่วิเคราะห์', _formatDate(report.createdAt)),
          _row('การมองเห็น', report.privacy ? 'ส่วนตัว' : 'สาธารณะ'),
          if (report.md5 != null && report.md5!.isNotEmpty)
            _row('MD5', report.md5!),
          if (report.fileHash != null && report.fileHash!.isNotEmpty)
            _row('SHA-256', report.fileHash!),
        ],
      ),
    );
  }

  Widget _buildToolDetailSection(AnalysisReport report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('รายละเอียดรายเครื่องมือ'),
          const SizedBox(height: 4),
          for (final tool in report.toolList)
            _buildToolTile(tool, report.toolNotes[tool]),
        ],
      ),
    );
  }

  Widget _buildToolTile(String tool, String? note) {
    final detail = _toolDetails[tool];
    final label = _toolLabels[tool] ?? tool;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        iconColor: _cyan,
        collapsedIconColor: _hint,
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: note == null
            ? null
            : Text(
                note,
                style: TextStyle(fontFamily: 'Kanit', fontSize: 12, color: _hint),
              ),
        onExpansionChanged: (expanded) {
          if (expanded && detail == null) _loadTool(tool);
        },
        children: [
          if (detail == null || detail.loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xff06b6d4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'กำลังโหลด...',
                    style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
                  ),
                ],
              ),
            )
          else if (detail.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                detail.error!,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 13,
                  color: Color(0xffef4444),
                ),
              ),
            )
          else
            ..._toolSummaryRows(tool, detail.data ?? const {}),
        ],
      ),
    );
  }

  List<Widget> _toolSummaryRows(String tool, Map<String, dynamic> data) {
    switch (tool) {
      case 'virustotal':
        return _virustotalRows(data);
      case 'mobsf':
        return _mobsfRows(data);
      case 'cape':
        return _capeRows(data);
      case 'rampart_ai':
        return _rampartAiRows(data);
      default:
        return [
          Text(
            'ไม่มีรายละเอียดสำหรับเครื่องมือนี้',
            style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
          ),
        ];
    }
  }

  List<Widget> _virustotalRows(Map<String, dynamic> data) {
    final stats = _mapAt(_dig(data, ['data', 'attributes', 'last_analysis_stats']));
    final results = _dig(data, ['data', 'attributes', 'last_analysis_results']);

    final rows = <Widget>[];
    if (stats != null) {
      rows.add(_row('ตรวจพบ (malicious)', _text(stats['malicious'])));
      rows.add(_row('น่าสงสัย', _text(stats['suspicious'])));
      rows.add(_row('ไม่พบ', _text(stats['undetected'])));
      if (stats['timeout'] != null) {
        rows.add(_row('หมดเวลา', _text(stats['timeout'])));
      }
    }

    if (results is List && results.isNotEmpty) {
      final detected = <String>[];
      for (final entry in results) {
        final map = _mapAt(entry);
        if (map == null) continue;
        final category = map['category']?.toString().toLowerCase();
        if (category != 'malicious' && category != 'suspicious') continue;
        final engine = map['engine_name'] ?? map['engine'];
        final result = map['result'];
        detected.add('${_text(engine)}: ${_text(result)}');
        if (detected.length >= 15) break;
      }
      if (detected.isNotEmpty) {
        rows.add(const SizedBox(height: 10));
        rows.add(
          Text(
            'เครื่องมือที่ตรวจพบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _hint,
            ),
          ),
        );
        for (final line in detected) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
      }
    }

    if (rows.isEmpty) {
      rows.add(
        Text(
          'ไม่พบข้อมูลจาก VirusTotal',
          style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
        ),
      );
    }
    return rows;
  }

  List<Widget> _mobsfRows(Map<String, dynamic> data) {
    final appsec = _mapAt(data['appsec']);
    final rows = <Widget>[
      _row('คะแนนความปลอดภัย', _text(data['security_score'])),
      _row('ชื่อแอป', _text(data['app_name'])),
      _row('แพ็กเกจ', _text(data['package_name'])),
      _row('เวอร์ชัน', _text(data['version_name'] ?? data['version'])),
      _row('ประเภท', _text(data['app_type'])),
    ];

    if (appsec != null) {
      rows.add(const SizedBox(height: 10));
      rows.add(
        Text(
          'ผลตรวจความปลอดภัย',
          style: TextStyle(
            fontFamily: 'Kanit',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _hint,
          ),
        ),
      );
      rows.add(_row('ระดับสูง', '${_countOf(appsec['high'])} รายการ'));
      rows.add(_row('ระดับเตือน', '${_countOf(appsec['warning'])} รายการ'));
      rows.add(_row('ข้อมูล', '${_countOf(appsec['info'])} รายการ'));
      rows.add(_row('ปลอดภัย', '${_countOf(appsec['secure'])} รายการ'));
    }

    if (data['total_trackers'] != null) {
      rows.add(_row('ตัวติดตาม', _text(data['total_trackers'])));
    }
    return rows;
  }

  List<Widget> _capeRows(Map<String, dynamic> data) {
    final signatures = data['signatures'];
    final rows = <Widget>[
      _row('MalScore', _text(data['malscore'])),
      _row('ชื่อไฟล์เป้าหมาย', _text(_dig(data, ['target', 'file', 'name']))),
      _row('แพ็กเกจ', _text(_dig(data, ['info', 'package']))),
      _row('เครื่องที่รัน', _text(_dig(data, ['info', 'machine']))),
      _row('จำนวน signature', '${_countOf(signatures)} รายการ'),
      _row('โปรเซส', '${_countOf(_dig(data, ['behavior', 'processes']))} รายการ'),
      _row('โฮสต์ที่เชื่อมต่อ', '${_countOf(_dig(data, ['network', 'hosts']))} รายการ'),
    ];

    if (signatures is List && signatures.isNotEmpty) {
      final names = <String>[];
      for (final entry in signatures) {
        final map = _mapAt(entry);
        final name = map == null ? null : map['name'];
        if (name != null) names.add(name.toString());
        if (names.length >= 10) break;
      }
      if (names.isNotEmpty) {
        rows.add(const SizedBox(height: 10));
        rows.add(
          Text(
            'Signature ที่พบ',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _hint,
            ),
          ),
        );
        for (final name in names) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
      }
    }
    return rows;
  }

  List<Widget> _rampartAiRows(Map<String, dynamic> data) {
    final score = RampartAiScore.fromJson(data);
    return [
      _row(
        'โอกาสเป็นมัลแวร์',
        score.malwareProbability == null
            ? '-'
            : '${(score.malwareProbability! * 100).toStringAsFixed(2)}%',
      ),
      _row(
        'โอกาสปลอดภัย',
        score.benignProbability == null
            ? '-'
            : '${(score.benignProbability! * 100).toStringAsFixed(2)}%',
      ),
      _row('คำทำนาย', score.prediction ?? '-'),
      if (score.confidence != null) _row('ความเชื่อมั่น', _text(score.confidence)),
    ];
  }

  Widget _buildSignaturesCard(AnalysisReport report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ลายเซ็นมัลแวร์ที่ตรวจพบ'),
          const SizedBox(height: 10),
          for (final signature in report.malwareSignatures)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $signature',
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 12.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(AnalysisReport report) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('หมายเหตุจากระบบ'),
          const SizedBox(height: 10),
          for (final entry in report.toolNotes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_toolLabels[entry.key] ?? entry.key}: ${entry.value}',
                style: TextStyle(fontFamily: 'Kanit', fontSize: 13, color: _hint),
              ),
            ),
        ],
      ),
    );
  }
}
