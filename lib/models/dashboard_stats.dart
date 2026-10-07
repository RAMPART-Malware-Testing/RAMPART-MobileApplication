library;

import 'analysis.dart';


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

Map<String, dynamic>? _unwrapData(Map<String, dynamic> json) {
  final data = _map(json['data']);
  if (data != null) return data;
  if (json.containsKey('totalFiles') || json.containsKey('userFiles')) return json;
  return null;
}

bool _isFailure(dynamic raw) {
  if (raw is! Map) return false;
  final json = _map(raw);
  if (json == null) return false;
  if (json.containsKey('success')) return json['success'] != true;
  return json.containsKey('detail') && !json.containsKey('data');
}

dynamic _payloadOf(dynamic raw) {
  if (raw is List) return raw;
  final json = _map(raw);
  if (json == null) return null;
  final data = json['data'];
  if (data is List || data is Map) return data;
  return json;
}


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

class TopMalwareTypes {
  final List<MalwareTypeEntry> daily;
  final List<MalwareTypeEntry> monthly;
  final List<MalwareTypeEntry> all;

  const TopMalwareTypes({
    this.daily = const [],
    this.monthly = const [],
    this.all = const [],
  });

  factory TopMalwareTypes.fromJson(dynamic raw) {
    final json = _map(raw) ?? const {};
    return TopMalwareTypes(
      daily: _mapList(json['daily']).map(MalwareTypeEntry.fromJson).toList(),
      monthly: _mapList(json['monthly']).map(MalwareTypeEntry.fromJson).toList(),
      all: _mapList(json['all']).map(MalwareTypeEntry.fromJson).toList(),
    );
  }

  List<MalwareTypeEntry> forRange(String range) => switch (range) {
    'daily' => daily,
    'monthly' => monthly,
    _ => all,
  };
}


class RiskScoreEntry {
  final String fileType;

  final String label;

  final double riskScore;
  final double? virustotalScore;
  final double? mobsfScore;
  final double? capeScore;

  final double? aiScore;

  final int sampleCount;
  final int scoredCount;

  const RiskScoreEntry({
    this.fileType = '',
    this.label = '',
    this.riskScore = 0,
    this.virustotalScore,
    this.mobsfScore,
    this.capeScore,
    this.aiScore,
    this.sampleCount = 0,
    this.scoredCount = 0,
  });

  String get displayName => label.isNotEmpty ? label : fileType;

  factory RiskScoreEntry.fromJson(Map<String, dynamic> json) {
    final tools = _map(json['tools']) ?? const {};
    return RiskScoreEntry(
      fileType: _str(json['fileType']) ?? _str(json['file_type']) ?? '',
      label: _str(json['label']) ?? '',
      riskScore: _clampScore(_dbl(json['riskScore']) ?? _dbl(json['risk_score'])),
      virustotalScore: _dbl(json['virustotalScore']) ??
          _dbl(json['virustotal_score']) ??
          _dbl(tools['virustotal']),
      mobsfScore:
          _dbl(json['mobsfScore']) ?? _dbl(json['mobsf_score']) ?? _dbl(tools['mobsf']),
      capeScore:
          _dbl(json['capeScore']) ?? _dbl(json['cape_score']) ?? _dbl(tools['cape']),
      aiScore: _aiScore(json['aiScore'] ??
          json['ai_score'] ??
          json['rampart_ai_score'] ??
          tools['ai']),
      sampleCount: _int(json['sampleCount']) ?? _int(json['sample_count']) ?? 0,
      scoredCount: _int(json['scoredCount']) ?? _int(json['scored_count']) ?? 0,
    );
  }

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

  static DashboardSummary? tryParse(dynamic raw) {
    if (_isFailure(raw)) return null;
    final json = _map(raw);
    if (json == null) return null;
    final payload = _unwrapData(json);
    if (payload == null) return null;
    return DashboardSummary.fromJson(payload);
  }
}


enum ActivityStatus { success, processing, pending, failed, unknown }

class RecentActivity {
  final String id;
  final String fileName;
  final String timestamp;
  final String fileType;
  final ActivityStatus status;

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


class PublicReportsPage {
  final List<AnalysisHistoryItem> items;

  final bool hasMore;

  final int total;

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

class DashboardBundle {
  final DashboardSummary? summary;
  final List<RecentActivity> recentActivities;
  final List<AnalysisHistoryItem> publicReports;

  final bool publicReportsHasMore;

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
