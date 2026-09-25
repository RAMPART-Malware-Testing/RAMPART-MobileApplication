/// โมเดลของระบบวิเคราะห์ไฟล์ (RAMPART analysis API)
///
/// โครงสร้าง response ยึดตามซอร์สของ backend (RAMPART-API-SERVERv1) เพราะ
/// OpenAPI spec ระบุแค่ request ส่วน response เป็น `"schema":{}` ว่างเปล่า
/// ทุก fromJson จึงต้องทนทาน: key หาย, ค่า null, ตัวเลขมาเป็น int/double/String
/// และค่าที่บางครั้งเป็น string บางครั้งเป็น list ต้องไม่ทำให้ throw
library;

import 'dart:convert';

// ---------- helper สำหรับ parse แบบทนทาน ----------

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}

DateTime? _asDate(dynamic v) {
  final s = _asString(v);
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s.trim());
}

List<String> _asStringList(dynamic v) {
  if (v == null) return const [];
  if (v is List) {
    return v
        .where((e) => e != null)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final s = _asString(v);
  if (s != null && s.trim().isNotEmpty) return [s];
  return const [];
}

Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, value) => MapEntry(k.toString(), value));
  return null;
}

/// tool_notes บางครั้งมาเป็น JSON string บางครั้งมาเป็น map
Map<String, String> _asStringMap(dynamic v) {
  final out = <String, String>{};
  dynamic source = v;

  if (source is String) {
    final text = source.trim();
    if (text.isEmpty) return out;
    try {
      source = jsonDecode(text);
    } catch (_) {
      return out;
    }
  }

  final map = _asMap(source);
  if (map == null) return out;
  map.forEach((key, value) {
    if (value == null) return;
    if (value is Map) {
      final nested = _asMap(value);
      final status = _asString(nested?['status'] ?? nested?['message']);
      if (status != null && status.isNotEmpty) out[key] = status;
      return;
    }
    final s = _asString(value);
    if (s != null && s.isNotEmpty) out[key] = s;
  });
  return out;
}

// ---------- สถานะของงานวิเคราะห์ ----------

enum AnalysisTaskStatus {
  dispatching,
  queued,
  processing,
  success,
  failed,
  unknown;

  static AnalysisTaskStatus fromRaw(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'dispatching':
        return AnalysisTaskStatus.dispatching;
      case 'queued':
        return AnalysisTaskStatus.queued;
      case 'processing':
        return AnalysisTaskStatus.processing;
      case 'success':
        return AnalysisTaskStatus.success;
      case 'failed':
        return AnalysisTaskStatus.failed;
      default:
        return AnalysisTaskStatus.unknown;
    }
  }

  bool get isTerminal =>
      this == AnalysisTaskStatus.success || this == AnalysisTaskStatus.failed;
}

/// สถานะของเครื่องมือแต่ละตัว — normalize ค่าที่ backend ส่งมาแบบปนกัน
/// (true/"success"/"completed"/false/"skipped"/"processing"...) ให้เป็นชุดเดียว
enum ToolRunStatus {
  waiting,
  running,
  completed,
  failed,
  skipped;

  static ToolRunStatus fromRaw(dynamic raw) {
    if (raw == null) return ToolRunStatus.waiting;
    if (raw is bool) {
      return raw ? ToolRunStatus.completed : ToolRunStatus.failed;
    }
    if (raw is num) {
      return raw != 0 ? ToolRunStatus.completed : ToolRunStatus.failed;
    }

    switch (raw.toString().trim().toLowerCase()) {
      case 'true':
      case 'success':
      case 'completed':
        return ToolRunStatus.completed;
      case 'false':
        return ToolRunStatus.failed;
      case 'skipped':
        return ToolRunStatus.skipped;
      case 'processing':
      case 'pending':
      case 'running':
      case 'queued':
        return ToolRunStatus.running;
      default:
        return ToolRunStatus.waiting;
    }
  }
}

// ---------- อัปโหลด ----------

class UploadTokenResult {
  final bool success;
  final String? uploadToken;
  final int? expiresIn;
  final String message;
  final int status;

  UploadTokenResult({
    required this.success,
    this.uploadToken,
    this.expiresIn,
    this.message = '',
    this.status = 0,
  });

  factory UploadTokenResult.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    return UploadTokenResult(
      success: _asBool(json['success']),
      uploadToken: _asString(data?['upload_token'] ?? json['upload_token']),
      expiresIn: _asInt(data?['expires_in'] ?? json['expires_in']),
      message: _asString(json['message']) ?? '',
      status: _asInt(json['status']) ?? 0,
    );
  }

  factory UploadTokenResult.failure(String message, {int status = 0}) =>
      UploadTokenResult(success: false, message: message, status: status);
}

class UploadResult {
  final bool success;
  final String? taskId;
  final String? status;
  final String? md5;
  final String? sha256;
  final String? filename;
  final bool deduplicated;
  final String? queueState;
  final bool? found;
  final bool gapFilled;
  final String message;
  final int statusCode;

  UploadResult({
    required this.success,
    this.taskId,
    this.status,
    this.md5,
    this.sha256,
    this.filename,
    this.deduplicated = false,
    this.queueState,
    this.found,
    this.gapFilled = false,
    this.message = '',
    this.statusCode = 0,
  });

  /// Server attached this call to an already-analysed file: no new worker job
  /// was created and [taskId] points at the existing analysis.
  bool get isDuplicate => deduplicated || (found == true && !gapFilled);

  /// check-hash hit, or an upload response marked `queue_state: reused`.
  bool get isReused =>
      (deduplicated && queueState?.trim().toLowerCase() == 'reused') ||
      (found == true && !gapFilled);

  bool get isCompletedReuse =>
      isReused && status?.trim().toLowerCase() == 'success';

  /// Prior analysis had gaps in one or more tools, so the backend re-dispatched
  /// only the missing ones under a fresh task id.
  bool get isGapFilled =>
      gapFilled || queueState?.trim().toLowerCase() == 'gap_filled';

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      success: _asBool(json['success']),
      taskId: _asString(json['task_id']),
      status: _asString(json['status']),
      md5: _asString(json['md5']),
      sha256: _asString(json['sha256']),
      filename: _asString(json['filename'] ?? json['file_name']),
      deduplicated: _asBool(json['deduplicated']),
      queueState: _asString(json['queue_state']),
      found: json['found'] == null ? null : _asBool(json['found']),
      gapFilled: _asBool(json['gap_filled']),
      message: _asString(json['message']) ?? '',
      statusCode: _asInt(json['status']) ?? 0,
    );
  }

  factory UploadResult.failure(String message, {int status = 0}) =>
      UploadResult(success: false, message: message, statusCode: status);
}

// ---------- ความคืบหน้า ----------

class ToolProgress {
  final ToolRunStatus status;
  final num? score;
  final String? taskId;

  ToolProgress({this.status = ToolRunStatus.waiting, this.score, this.taskId});

  factory ToolProgress.fromJson(Map<String, dynamic> json) {
    return ToolProgress(
      status: ToolRunStatus.fromRaw(json['status']),
      score: _asDouble(json['score']),
      taskId: _asString(json['task_id']),
    );
  }
}

class AnalysisProgress {
  final String? stage;
  final String? message;
  final String? updatedAt;
  final String? error;
  final Map<String, ToolProgress> tools;

  AnalysisProgress({
    this.stage,
    this.message,
    this.updatedAt,
    this.error,
    Map<String, ToolProgress>? tools,
  }) : tools = tools ?? const {};

  factory AnalysisProgress.fromJson(Map<String, dynamic> json) {
    final tools = <String, ToolProgress>{};
    final rawTools = _asMap(json['tools']);
    rawTools?.forEach((key, value) {
      final map = _asMap(value);
      if (map != null) tools[key] = ToolProgress.fromJson(map);
    });

    return AnalysisProgress(
      stage: _asString(json['stage']),
      message: _asString(json['message']),
      updatedAt: _asString(json['updated_at']),
      error: _asString(json['error']),
      tools: tools,
    );
  }

  ToolProgress? tool(String name) => tools[name];
}

// ---------- คะแนนจากโมเดล ML ----------

class RampartAiScore {
  final double? malwareProbability;
  final double? benignProbability;
  final String? prediction;
  final num? confidence;

  RampartAiScore({
    this.malwareProbability,
    this.benignProbability,
    this.prediction,
    this.confidence,
  });

  /// backend ส่งมาได้ทั้ง object {malware_probability, prediction, ...} และเลขล้วน
  /// ถ้าเป็นเลขล้วนให้ถือว่าเป็นเปอร์เซ็นต์ (หาร 100 เมื่อเกิน 1)
  factory RampartAiScore.fromJson(dynamic raw) {
    final map = _asMap(raw);
    if (map != null) {
      return RampartAiScore(
        malwareProbability: _asDouble(map['malware_probability']),
        benignProbability: _asDouble(map['benign_probability']),
        prediction: _asString(map['prediction']),
        confidence: _asDouble(map['confidence']),
      );
    }

    final number = _asDouble(raw);
    if (number != null) {
      return RampartAiScore(
        malwareProbability: number > 1 ? number / 100 : number,
      );
    }

    return RampartAiScore();
  }
}

// ---------- รายงานผลวิเคราะห์ ----------

class AnalysisReport {
  final String taskId;
  final String aid;
  final String rid;
  final String uid;
  final bool privacy;
  final String status;
  final String? fileName;
  final int? fileSize;
  final String? fileHash;
  final String? filePath;
  final String? fileType;
  final String? md5;
  final String? tools;
  final Map<String, String> toolNotes;
  final DateTime? createdAt;
  final int? virustotalScore;
  final double? mobsfScore;
  final double? capeScore;
  final RampartAiScore? rampartAiScore;
  final double? score;
  final String? riskLevel;
  final String? recommendation;
  final String? analysisSummary;
  final String? geminiRecommendation;
  final String? threatAssessment;
  final String? behavior;
  final List<String> riskIndicators;
  final List<String> malwareSignatures;

  AnalysisReport({
    required this.taskId,
    this.aid = '',
    this.rid = '',
    this.uid = '',
    this.privacy = true,
    this.status = '',
    this.fileName,
    this.fileSize,
    this.fileHash,
    this.filePath,
    this.fileType,
    this.md5,
    this.tools,
    this.toolNotes = const {},
    this.createdAt,
    this.virustotalScore,
    this.mobsfScore,
    this.capeScore,
    this.rampartAiScore,
    this.score,
    this.riskLevel,
    this.recommendation,
    this.analysisSummary,
    this.geminiRecommendation,
    this.threatAssessment,
    this.behavior,
    this.riskIndicators = const [],
    this.malwareSignatures = const [],
  });

  factory AnalysisReport.fromJson(Map<String, dynamic> json) {
    return AnalysisReport(
      taskId: _asString(json['task_id']) ?? '',
      aid: _asString(json['aid']) ?? '',
      rid: _asString(json['rid']) ?? '',
      uid: _asString(json['uid']) ?? '',
      privacy: _asBool(json['privacy'], fallback: true),
      status: _asString(json['status']) ?? '',
      fileName: _asString(json['file_name']),
      fileSize: _asInt(json['file_size']),
      fileHash: _asString(json['file_hash']),
      filePath: _asString(json['file_path']),
      fileType: _asString(json['file_type'] ?? json['report_file_type']),
      md5: _asString(json['md5']),
      tools: _asString(json['tools']),
      toolNotes: _asStringMap(json['tool_notes']),
      createdAt: _asDate(json['created_at'] ?? json['report_created_at']),
      virustotalScore: _asInt(json['virustotal_score']),
      mobsfScore: _asDouble(json['mobsf_score']),
      capeScore: _asDouble(json['cape_score']),
      rampartAiScore: json['rampart_ai_score'] == null
          ? null
          : RampartAiScore.fromJson(json['rampart_ai_score']),
      score: _asDouble(json['score']),
      riskLevel: _asString(json['risk_level']),
      recommendation: _asString(json['recommendation']),
      analysisSummary: _asString(json['analysis_summary']),
      geminiRecommendation: _asString(json['gemini_recommendation']),
      threatAssessment: _asString(
        json['threat_assessment'] ?? json['threatAssessment'],
      ),
      behavior: _asString(json['behavior']),
      riskIndicators: _asStringList(json['risk_indicators']),
      malwareSignatures: _asStringList(json['malware_signatures']),
    );
  }

  /// tools มาเป็น CSV เช่น "virustotal,mobsf,cape,rampart_ai,gemini"
  List<String> get toolList {
    final raw = tools;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Gemini ถูกส่งกลับในรายงานงานหลัก ไม่ต้องเรียก report_target แยก
  static bool usesEmbeddedReport(String tool) => toolRouteKey(tool) == 'gemini';

  /// ชื่อ route ของ report_target/download ใช้ "rampartai" ไม่มี underscore
  static String toolRouteKey(String tool) =>
      tool.trim() == 'rampart_ai' ? 'rampartai' : tool.trim();
}

// ---------- สถานะงาน (poll) ----------

class TaskStatusResult {
  final bool success;
  final String? taskId;
  final String? status;
  final String? message;
  final AnalysisReport? report;
  final AnalysisProgress? progress;
  final Map<String, String> toolNotes;
  final int httpStatus;

  TaskStatusResult({
    required this.success,
    this.taskId,
    this.status,
    this.message,
    this.report,
    this.progress,
    this.toolNotes = const {},
    this.httpStatus = 0,
  });

  factory TaskStatusResult.fromJson(
    Map<String, dynamic> json, {
    int httpStatus = 200,
  }) {
    final progress = _asMap(json['progress']);
    final report = _asMap(json['report']);

    return TaskStatusResult(
      success: _asBool(json['success']),
      taskId: _asString(json['task_id']),
      status: _asString(json['status']),
      message: _asString(json['message']),
      report: report == null ? null : AnalysisReport.fromJson(report),
      progress: progress == null ? null : AnalysisProgress.fromJson(progress),
      toolNotes: _asStringMap(json['tool_notes'] ?? progress?['tool_notes']),
      httpStatus: httpStatus,
    );
  }

  factory TaskStatusResult.failure(String message, {int httpStatus = 0}) =>
      TaskStatusResult(
        success: false,
        message: message,
        httpStatus: httpStatus,
      );

  AnalysisTaskStatus get taskStatus => AnalysisTaskStatus.fromRaw(status);

  /// backend บอกว่าไม่พบงานด้วย success:false (message = TASK_NOT_FOUND)
  bool get isNotFound => !success;

  bool get isSuccess => success && status?.toLowerCase() == 'success';

  bool get isFailed => success && status?.toLowerCase() == 'failed';

  bool get isRunning => success && !isSuccess && !isFailed;
}

// ---------- ผลรายเครื่องมือ ----------

class ToolReportResult {
  final bool success;
  final String? taskId;
  final String? status;
  final String? tool;
  final String? message;
  final Map<String, dynamic>? report;
  final int httpStatus;

  ToolReportResult({
    required this.success,
    this.taskId,
    this.status,
    this.tool,
    this.message,
    this.report,
    this.httpStatus = 0,
  });

  factory ToolReportResult.fromJson(
    Map<String, dynamic> json, {
    int httpStatus = 200,
  }) {
    return ToolReportResult(
      success: _asBool(json['success']),
      taskId: _asString(json['task_id']),
      status: _asString(json['status']),
      tool: _asString(json['tool']),
      message: _asString(json['message']),
      report: _asMap(json['report']),
      httpStatus: httpStatus,
    );
  }

  factory ToolReportResult.failure(String message, {int httpStatus = 0}) =>
      ToolReportResult(
        success: false,
        message: message,
        httpStatus: httpStatus,
      );
}

// ---------- ประวัติการวิเคราะห์ ----------

class AnalysisHistoryItem {
  final String aid;
  final String taskId;
  final String status;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final String? fileHash;
  final String? tools;
  final String? md5;
  final bool privacy;
  final DateTime? createdAt;
  final double? score;
  final double? rampartScore;
  final String? riskLevel;
  final int? virustotalScore;
  final double? mobsfScore;
  final double? capeScore;
  final RampartAiScore? rampartAiScore;

  AnalysisHistoryItem({
    required this.aid,
    required this.taskId,
    this.status = '',
    this.fileName,
    this.fileSize,
    this.fileType,
    this.fileHash,
    this.tools,
    this.md5,
    this.privacy = true,
    this.createdAt,
    this.score,
    this.rampartScore,
    this.riskLevel,
    this.virustotalScore,
    this.mobsfScore,
    this.capeScore,
    this.rampartAiScore,
  });

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    final report = _asMap(json['report']);
    return AnalysisHistoryItem(
      aid: _asString(json['aid']) ?? '',
      taskId: _asString(json['task_id']) ?? '',
      status: _asString(json['status']) ?? '',
      fileName: _asString(json['file_name']),
      fileSize: _asInt(json['file_size']),
      fileType: _asString(json['file_type']),
      fileHash: _asString(json['file_hash']),
      tools: _asString(json['tools']),
      md5: _asString(json['md5']),
      privacy: _asBool(json['privacy'], fallback: true),
      createdAt: _asDate(json['created_at']),
      score: _asDouble(report?['score']),
      rampartScore: _asDouble(report?['rampart_score']),
      riskLevel: _asString(report?['risk_level']),
      virustotalScore: _asInt(report?['virustotal_score']),
      mobsfScore: _asDouble(report?['mobsf_score']),
      capeScore: _asDouble(report?['cape_score']),
      rampartAiScore: report?['rampart_ai_score'] == null
          ? null
          : RampartAiScore.fromJson(report?['rampart_ai_score']),
    );
  }

  List<String> get toolList {
    final raw = tools;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

class Pagination {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  Pagination({
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 0,
    this.hasNext = false,
    this.hasPrev = false,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: _asInt(json['page']) ?? 1,
      limit: _asInt(json['limit']) ?? 10,
      total: _asInt(json['total']) ?? 0,
      totalPages: _asInt(json['total_pages']) ?? 0,
      hasNext: _asBool(json['has_next']),
      hasPrev: _asBool(json['has_prev']),
    );
  }
}

class AnalysisHistoryPage {
  final bool success;
  final List<AnalysisHistoryItem> items;
  final Pagination? pagination;
  final String message;
  final int status;

  AnalysisHistoryPage({
    required this.success,
    this.items = const [],
    this.pagination,
    this.message = '',
    this.status = 0,
  });

  factory AnalysisHistoryPage.fromJson(Map<String, dynamic> json) {
    final items = <AnalysisHistoryItem>[];
    final rawList = json['data'];
    if (rawList is List) {
      for (final entry in rawList) {
        final map = _asMap(entry);
        if (map != null) items.add(AnalysisHistoryItem.fromJson(map));
      }
    }

    final page = _asMap(json['pagination']);

    return AnalysisHistoryPage(
      success: _asBool(json['success']),
      items: items,
      pagination: page == null ? null : Pagination.fromJson(page),
      message: _asString(json['message']) ?? '',
      status: _asInt(json['status']) ?? 0,
    );
  }

  factory AnalysisHistoryPage.failure(String message, {int status = 0}) =>
      AnalysisHistoryPage(success: false, message: message, status: status);
}
