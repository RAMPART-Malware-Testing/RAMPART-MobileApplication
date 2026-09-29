/// โมเดลข้อมูลหน้า Dashboard (RAMPART dashboard API)
///
/// โครงสร้างยึดตาม contract ที่แอปเว็บ (`RAMPART-WebApplication`) ใช้จริง ไม่ใช่
/// schema ใน OpenAPI ของ backend ซึ่งระบุ response เป็น `"schema":{}` ว่างเปล่า
///
/// หน้าเว็บอ่านค่าจาก `/api/analy/v1/dashboard/summary` ผ่าน
/// `NextResponse.json({ success: true, data: res })` แล้วห่อ `data` อีกชั้น เช่นนั้น
/// ฝั่งมือถือที่ยิง backend ตรงจะได้ `{ success, status, message, data: {...} }`
/// โดยเนื้อ summary อยู่ใน `data` — ตัวแยกชั้นทำให้รองรับทั้งสองแบบ
library;

import 'analysis.dart';

// ---------- helper สำหรับ parse แบบทนทาน ----------
// ซ้ำกับที่อยู่ใน analysis.dart เพราะไฟล์นั้นประกาศเป็น private (ขีดกลางนำหน้า)
// และแต่ละไฟล์ Dart เป็นคนละ library จึง import ใช้ไม่ได้

String? _str(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? null : v;
  return v.toString();
}

int? _int(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

bool? _bool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
  }
  return null;
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

Map<String, dynamic>? _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, value) => MapEntry(k.toString(), value));
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in v) {
    final m = _map(item);
    if (m != null) out.add(m);
  }
  return out;
}

/// แตก envelope `{success, data}` ให้เหลือ payload จริง
///
/// backend ไม่ได้ห่อทุก endpoint เหมือนกัน:
/// - `summary` คืน dict ตรง ๆ ที่ระดับบนสุด
/// - `recent-activities` คืน **list** ตรง ๆ ไม่มี envelope เลย
/// - `reports` คืน `{data: [...]}` เหมือนหน้าเว็บคาดไว้
Map<String, dynamic>? _unwrapData(Map<String, dynamic> json) {
  final data = _map(json['data']);
  if (data != null) return data;
  if (json.containsKey('totalFiles') || json.containsKey('userFiles')) return json;
  return null;
}

/// ถือว่าเป็น error เมื่อ backend บอกตรง ๆ ว่าไม่สำเร็จเท่านั้น
///
/// ชั้น service ใส่ `success: false` ตอน exception และ FastAPI ใส่ `detail`
/// ตอน 401/422 ส่วน payload ที่สำเร็จจะไม่มีคีย์ `success` เลย ถ้าเอา "ต้องมี
/// success == true" เป็นเงื่อนไข จะทำให้ทุก endpoint ที่คืน payload ตรง ๆ
/// ถูกตีความว่าล้มเหลว
bool _isFailure(dynamic raw) {
  if (raw is! Map) return false;
  final json = _map(raw);
  if (json == null) return false;
  if (json.containsKey('success')) return json['success'] != true;
  return json.containsKey('detail') && !json.containsKey('data');
}

/// ดึง payload ที่อยู่ใน envelope หรือคืนตัวมันเองถ้าไม่มี envelope
dynamic _payloadOf(dynamic raw) {
  if (raw is List) return raw;
  final json = _map(raw);
  if (json == null) return null;
  final data = json['data'];
  if (data is List || data is Map) return data;
  return json;
}

// ---------- ตัวนับไฟล์ ----------

/// จำนวนไฟล์แยกตามสถานะ ทั้งระบบ (`totalFiles`) และของผู้ใช้คนนี้ (`userFiles`)
class FileCounts {
  final int total;
  final int success;
  final int pending;
  final int failed;

  const FileCounts({
    this.total = 0,
    this.success = 0,
    this.pending = 0,
    this.failed = 0,
  });

  /// `total` ที่ backend ส่งมาอาจไม่ตรงกับผลบวกของสามสถานะ (เช่นมีสถานะอื่น
  /// ที่หน้าเว็บไม่ได้แสดง) ถ้าไม่มีค่านี้ค่อยคำนวณจากสามสถานะแทน
  int get resolvedTotal => total > 0 ? total : success + pending + failed;

  double get successRate =>
      resolvedTotal > 0 ? (success / resolvedTotal) * 100 : 0;

  factory FileCounts.fromJson(dynamic raw) {
    final json = _map(raw) ?? const {};
    return FileCounts(
      total: _int(json['total']) ?? 0,
      success: _int(json['success']) ?? 0,
      pending: _int(json['pending']) ?? 0,
      failed: _int(json['failed']) ?? 0,
    );
  }
}

// ---------- ประเภทมัลแวร์ยอดนิยม ----------

class MalwareTypeEntry {
  final String type;
  final int count;

  const MalwareTypeEntry({this.type = '', this.count = 0});

  factory MalwareTypeEntry.fromJson(Map<String, dynamic> json) {
    return MalwareTypeEntry(
      type: _str(json['type']) ?? _str(json['name']) ?? '',
      count: _int(json['count']) ?? 0,
    );
  }
}

/// หน้าเว็บสลับระหว่างสองชุดนี้ด้วยปุ่ม 'รายวัน' / 'รายเดือน'
class TopMalwareTypes {
  final List<MalwareTypeEntry> daily;
  final List<MalwareTypeEntry> monthly;

  const TopMalwareTypes({this.daily = const [], this.monthly = const []});

  factory TopMalwareTypes.fromJson(dynamic raw) {
    final json = _map(raw) ?? const {};
    return TopMalwareTypes(
      daily: _mapList(json['daily']).map(MalwareTypeEntry.fromJson).toList(),
      monthly: _mapList(json['monthly']).map(MalwareTypeEntry.fromJson).toList(),
    );
  }

  List<MalwareTypeEntry> forRange(String range) =>
      range == 'daily' ? daily : monthly;
}

// ---------- คะแนนความอันตรายตามประเภทไฟล์ ----------

/// ค่าเฉลี่ยจำแนกตามประเภทไฟล์ พร้อมค่าเฉลี่ยรายเครื่องมือ
class RiskScoreEntry {
  final String fileType;

  /// คะแนนรวม 0-100
  final double riskScore;
  final double? virustotalScore;
  final double? mobsfScore;
  final double? capeScore;

  /// คะแนนจากโมเดล ML — backend ส่งมาเป็น `{malware_probability: 0..1}`
  /// หรือเป็นตัวเลข 0-100 ตรง ๆ ก็ได้
  final double? aiScore;

  const RiskScoreEntry({
    this.fileType = '',
    this.riskScore = 0,
    this.virustotalScore,
    this.mobsfScore,
    this.capeScore,
    this.aiScore,
  });

  factory RiskScoreEntry.fromJson(Map<String, dynamic> json) {
    return RiskScoreEntry(
      fileType: _str(json['fileType']) ?? _str(json['file_type']) ?? '',
      riskScore: _clampScore(_dbl(json['riskScore']) ?? _dbl(json['risk_score'])),
      virustotalScore: _dbl(json['virustotalScore']) ?? _dbl(json['virustotal_score']),
      mobsfScore: _dbl(json['mobsfScore']) ?? _dbl(json['mobsf_score']),
      capeScore: _dbl(json['capeScore']) ?? _dbl(json['cape_score']),
      aiScore: _aiScore(json['aiScore'] ?? json['ai_score'] ??
          json['rampart_ai_score']),
    );
  }

  /// เครื่องมือที่มีคะแนนจริง เรียงตามลำดับที่หน้าเว็บแสดง
  List<({String key, String label, String title, double value})>
      get toolScores => [
    if (virustotalScore != null)
      (key: 'virustotal', label: 'VT', title: 'VirusTotal', value: virustotalScore!),
    if (mobsfScore != null)
      (key: 'mobsf', label: 'MobSF', title: 'MobSF Static Analysis', value: mobsfScore!),
    if (capeScore != null)
      (key: 'cape', label: 'CAPE', title: 'CAPE Sandbox', value: capeScore!),
    if (aiScore != null)
      (key: 'rampart_ai', label: 'AI', title: 'RampartAI', value: aiScore!),
  ];
}

/// backend อาจส่ง `rampart_ai_score` มาเป็น object `{malware_probability: 0..1}`
/// หรือเป็นตัวเลขตรง ๆ — ถ้าเป็น object ต้องคูณ 100 ให้เป็นสเกล 0-100 เหมือนกัน
///
/// ถ้าเป็นเลขล้วน ให้ถือว่าเป็นสเกล 0-100 อยู่แล้ว ไม่คูณซ้ำ — เป็นพฤติกรรมเดียวกับ
/// `aiChipValue()` ใน useDashboard.ts ที่หน้าเว็บใช้จริง
/// (ส่วน [RampartAiScore] ใน analysis.dart ตีความเลขล้วนเป็นสัดส่วน ซึ่งต่างกัน
///  เว้นแต่กรณีนี้ backend ส่ง object ซึ่งทั้งสองฝั่งตีความตรงกัน)
double? _aiScore(dynamic raw) {
  if (raw == null) return null;
  final map = _map(raw);
  if (map != null) {
    final p = _dbl(map['malware_probability']);
    if (p == null) return null;
    return _clampScore(p * 100);
  }
  final n = _dbl(raw);
  if (n == null) return null;
  return _clampScore(n);
}

double _clampScore(double? v) {
  if (v == null) return 0;
  return v.clamp(0, 100).toDouble();
}

// ---------- สรุปทั้งหมด ----------

class DashboardSummary {
  final FileCounts totalFiles;
  final FileCounts userFiles;
  final int totalUsers;
  final TopMalwareTypes topMalwareTypes;
  final List<RiskScoreEntry> riskScores;

  const DashboardSummary({
    this.totalFiles = const FileCounts(),
    this.userFiles = const FileCounts(),
    this.totalUsers = 0,
    this.topMalwareTypes = const TopMalwareTypes(),
    this.riskScores = const [],
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalFiles: FileCounts.fromJson(json['totalFiles'] ?? json['total_files']),
      userFiles: FileCounts.fromJson(json['userFiles'] ?? json['user_files']),
      totalUsers: _int(json['totalUsers'] ?? json['total_users']) ?? 0,
      topMalwareTypes: TopMalwareTypes.fromJson(
        json['topMalwareTypes'] ?? json['top_malware_types'],
      ),
      riskScores: _mapList(json['riskScores'] ?? json['risk_scores'])
          .map(RiskScoreEntry.fromJson)
          .toList(),
    );
  }

  /// คืน null เมื่อ response เป็น error — payload ที่ backend คืนตรง ๆ
  /// (ไม่มี envelope) ต้องผ่าน ไม่เช่นนั้นหน้าจะว่างทั้งที่เซิร์ฟเวอร์ทำงานปกติ
  static DashboardSummary? tryParse(dynamic raw) {
    if (_isFailure(raw)) return null;
    final json = _map(raw);
    if (json == null) return null;
    final payload = _unwrapData(json);
    if (payload == null) return null;
    return DashboardSummary.fromJson(payload);
  }
}

// ---------- กิจกรรมล่าสุด ----------

/// สถานะที่ backend ใช้ — ระหว่างวิเคราะห์ `Analysis.status` วิ่ง
/// `dispatching → queued → processing` ก่อนจบด้วย `success|failed`
enum ActivityStatus { success, processing, pending, failed, unknown }

class RecentActivity {
  final String id;
  final String fileName;
  final String timestamp;
  final String fileType;
  final ActivityStatus status;

  /// เวลาที่ parse เป็น `DateTime` แล้ว ใช้แสดงผลในเขตเวลาของเครื่องผู้ใช้
  ///
  /// backend ส่งมาเป็นสตริง `"%Y-%m-%d %H:%M:%S"` ที่ไม่มีโซนเวลา แต่ค่าในฐานข้อมูล
  /// เป็น UTC ถ้าเอาไปแสดงตรง ๆ เวลาจะเพี้ยนไปหลายชั่วโมง
  /// ต่างจากรายงานสาธารณะที่ส่ง ISO 8601 มา — ทั้งสองต้องแสดงตรงกัน
  final DateTime? createdAt;

  const RecentActivity({
    this.id = '',
    this.fileName = '',
    this.timestamp = '',
    this.fileType = '',
    this.status = ActivityStatus.unknown,
    this.createdAt,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    final raw = _str(json['timestamp']) ?? _str(json['created_at']) ?? '';
    return RecentActivity(
      id: _str(json['id']) ?? '',
      fileName: _str(json['fileName']) ?? _str(json['file_name']) ?? '',
      timestamp: raw,
      fileType: _str(json['fileType']) ?? _str(json['file_type']) ?? '',
      status: _activityStatus(_str(json['status'])),
      createdAt: _parseActivityTime(raw),
    );
  }
}

/// backend ส่งเวลามาโดยไม่มีโซน จึงต้องถือว่าเป็น UTC
DateTime? _parseActivityTime(String raw) {
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed : DateTime.parse('${raw}Z').toUtc();
}

ActivityStatus _activityStatus(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'success':
      return ActivityStatus.success;
    // ระหว่างวิเคราะห์ backend ส่ง processing — ไม่ใช่ unknown
    case 'processing':
      return ActivityStatus.processing;
    case 'pending':
    case 'dispatching':
    case 'queued':
      return ActivityStatus.pending;
    case 'failed':
      return ActivityStatus.failed;
    default:
      return ActivityStatus.unknown;
  }
}

// ---------- ผลรวมที่หน้าจอใช้ ----------

/// หนึ่งหน้าของรายงานสาธารณะ (ปุ่ม "ดูเพิ่มเติม" ใช้ชั้นนี้ต่อทีละหน้า)
///
/// endpoint `dashboard/reports` คืน `{success, data, pagination:{has_next, total}}`
/// — ถ้า response ไม่มี `pagination` (payload เก่า/แคชเก่า) ให้เดาจากจำนวนชิ้นแทน:
/// ได้ครบตาม limit ถือว่ายังมีหน้าต่อไป
class PublicReportsPage {
  final List<AnalysisHistoryItem> items;

  /// ยังมีหน้าถัดไปให้กด "ดูเพิ่มเติม" อีกหรือไม่
  final bool hasMore;

  /// จำนวนรายงานสาธารณะทั้งหมด (0 เมื่อเซิร์ฟเวอร์ไม่บอก)
  final int total;

  /// ข้อความ error — สตริงว่างเมื่อโหลดสำเร็จ
  final String error;

  const PublicReportsPage({
    this.items = const [],
    this.hasMore = false,
    this.total = 0,
    this.error = '',
  });

  factory PublicReportsPage.fromResponse(dynamic raw, {int limit = 10}) {
    if (_isFailure(raw)) {
      final json = _map(raw);
      final message = json?['message'] ?? json?['detail'];
      return PublicReportsPage(
        error: message is String && message.isNotEmpty
            ? message
            : 'โหลดรายงานเพิ่มเติมไม่สำเร็จ',
      );
    }

    final json = _map(raw);
    if (json == null) return const PublicReportsPage(error: 'โหลดรายงานเพิ่มเติมไม่สำเร็จ');

    final payload = _payloadOf(json);
    final items = <AnalysisHistoryItem>[];
    if (payload is List) {
      for (final item in payload) {
        final m = _map(item);
        if (m != null) items.add(AnalysisHistoryItem.fromJson(m));
      }
    }

    final pagination = _map(json['pagination']);
    return PublicReportsPage(
      items: items,
      hasMore: _bool(pagination?['has_next']) ?? items.length >= limit,
      total: _int(pagination?['total']) ?? items.length,
    );
  }
}

/// ข้อมูลทั้งชุดที่หน้า dashboard ต้องใช้ รวมสถานะ error ของแต่ละ endpoint
class DashboardBundle {
  final DashboardSummary? summary;
  final List<RecentActivity> recentActivities;
  final List<AnalysisHistoryItem> publicReports;

  /// ยังมีรายงานสาธารณะหน้าถัดไป (จาก `pagination.has_next` ของหน้าแรก)
  final bool publicReportsHasMore;

  /// จำนวนรายงานสาธารณะทั้งหมด ใช้โชว์ในหัวข้อ "ไฟล์สาธารณะ"
  final int publicReportsTotal;

  final String error;
  final bool hasAnyData;

  const DashboardBundle({
    this.summary,
    this.recentActivities = const [],
    this.publicReports = const [],
    this.publicReportsHasMore = false,
    this.publicReportsTotal = 0,
    this.error = '',
    this.hasAnyData = false,
  });

  const DashboardBundle.empty({this.error = ''})
      : summary = null,
        recentActivities = const [],
        publicReports = const [],
        publicReportsHasMore = false,
        publicReportsTotal = 0,
        hasAnyData = false;

  factory DashboardBundle.fromResponses({
    dynamic summary,
    dynamic recentActivities,
    dynamic publicReports,
  }) {
    final parsedSummary = DashboardSummary.tryParse(summary);

    // recent-activities คืน list ตรง ๆ (ไม่มี envelope) จึงต้องอ่านผ่าน
    // _payloadOf เหมือนกัน ไม่งั้น list จะถูกทิ้งและกลายเป็นหน้าว่าง
    final activities = <RecentActivity>[];
    if (!_isFailure(recentActivities)) {
      final payload = _payloadOf(recentActivities);
      if (payload is List) {
        for (final item in payload) {
          final m = _map(item);
          if (m != null) activities.add(RecentActivity.fromJson(m));
        }
      }
    }

    final reportsPage = PublicReportsPage.fromResponse(publicReports);

    return DashboardBundle(
      summary: parsedSummary,
      recentActivities: activities,
      publicReports: reportsPage.items,
      publicReportsHasMore: reportsPage.hasMore,
      publicReportsTotal: reportsPage.total,
      hasAnyData:
          parsedSummary != null || activities.isNotEmpty || reportsPage.items.isNotEmpty,
    );
  }
}
