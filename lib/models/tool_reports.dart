library;


Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, value) => MapEntry(k.toString(), value));
  return null;
}

String? _asString(dynamic v) =>
    v == null ? null : (v is String ? v : v.toString());

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}

int _count(dynamic v) {
  if (v is List) return v.length;
  if (v is Map) return v.length;
  return 0;
}


class EngineResult {
  const EngineResult({
    required this.engine,
    required this.category,
    required this.result,
  });

  final String engine;
  final String category;
  final String result;

  @override
  String toString() => '$engine: $result ($category)';
}

class VirusTotalReport {
  const VirusTotalReport({
    required this.stats,
    required this.engines,
    this.md5,
    this.attributesJson,
  });

  final Map<String, int> stats;
  final List<EngineResult> engines;
  final String? md5;
  final Map<String, dynamic>? attributesJson;

  int get malicious => stats['malicious'] ?? 0;
  int get suspicious => stats['suspicious'] ?? 0;
  int get undetected => stats['undetected'] ?? 0;
  int get timeout => stats['timeout'] ?? 0;
  int get unsupported => stats['type-unsupported'] ?? 0;
  int get total =>
      stats.values.fold<int>(0, (sum, value) => sum + value);

  List<MapEntry<String, List<EngineResult>>> grouped() {
    final groups = <String, List<EngineResult>>{};
    for (final engine in engines) {
      (groups[engine.category] ??= []).add(engine);
    }
    final order = [
      'malicious',
      'suspicious',
      'undetected',
      'timeout',
      'type-unsupported',
    ];
    return [
      for (final key in order)
        if (groups.containsKey(key) && groups[key]!.isNotEmpty)
          MapEntry(key, groups[key]!),
    ];
  }

  List<EngineResult> whereEngine(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return engines;
    return engines
        .where((e) => e.engine.toLowerCase().contains(q))
        .toList(growable: false);
  }

  factory VirusTotalReport.fromMap(Map<String, dynamic> raw) {
    final attrs = _asMap(raw['data']?['attributes']) ?? const {};
    final stats = _asMap(attrs['last_analysis_stats']) ?? const {};
    final results = _asMap(attrs['last_analysis_results']) ?? const {};

    final statMap = <String, int>{};
    stats.forEach((key, value) {
      final n = _asInt(value);
      if (n != null) statMap[key] = n;
    });

    final engines = <EngineResult>[];
    results.forEach((engineName, value) {
      final map = _asMap(value);
      if (map == null) return;
      final category = _asString(map['category'])?.trim().toLowerCase() ?? '';
      final result = _asString(map['result'])?.trim() ?? '';
      if (category.isEmpty) return;
      engines.add(
        EngineResult(engine: engineName, category: category, result: result),
      );
    });

    return VirusTotalReport(
      stats: statMap,
      engines: List.unmodifiable(engines),
      md5: _asString(attrs['md5']),
      attributesJson: attrs.isEmpty ? null : attrs,
    );
  }
}


class MobsfFinding {
  const MobsfFinding({
    required this.title,
    required this.section,
    required this.description,
    required this.category,
  });

  final String title;
  final String section;
  final String description;
  final String category;
}

class MobsfDomain {
  const MobsfDomain({
    required this.domain,
    required this.bad,
    required this.ofac,
    this.ip,
    this.countryShort,
    this.countryLong,
    this.region,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String domain;
  final String bad;
  final bool ofac;
  final String? ip;
  final String? countryShort;
  final String? countryLong;
  final String? region;
  final String? city;
  final String? latitude;
  final String? longitude;
}

class MobsfReport {
  const MobsfReport({
    this.appName,
    this.fileName,
    this.versionName,
    this.size,
    this.title,
    this.version,
    this.appType,
    this.md5,
    this.sha1,
    this.sha256,
    this.packageName,
    this.securityScore,
    required this.findings,
    this.trackers,
    this.totalTrackers,
    this.certificateInfo,
    required this.domains,
  });

  final String? appName;
  final String? fileName;
  final String? versionName;
  final String? size;
  final String? title;
  final String? version;
  final String? appType;
  final String? md5;
  final String? sha1;
  final String? sha256;
  final String? packageName;
  final double? securityScore;
  final List<MobsfFinding> findings;
  final int? trackers;
  final dynamic totalTrackers;
  final String? certificateInfo;
  final List<MobsfDomain> domains;

  int get displayScore {
    if (securityScore == null) return 0;
    return (100 - securityScore!).round().clamp(0, 100);
  }

  int get high => findings.where((f) => f.category == 'High').length;
  int get medium => findings.where((f) => f.category == 'Medium').length;
  int get info => findings.where((f) => f.category == 'Info').length;
  int get secure => findings.where((f) => f.category == 'Secure').length;
  int get hotspot => findings.where((f) => f.category == 'Hotspot').length;

  int severityPercent(int count) {
    final sum = high + medium + info + secure;
    if (sum == 0) return 0;
    return (count / sum * 100).floor();
  }

  int get totalServers => domains.length;
  int get badServers => domains.where((d) => d.bad != 'no').length;
  int get healthyServers =>
      domains.where((d) => d.bad == 'no' && !d.ofac).length;

  factory MobsfReport.fromMap(Map<String, dynamic> raw) {
    final appsec = _asMap(raw['appsec']) ?? const {};
    final cert = _asMap(raw['certificate_analysis']) ?? const {};
    final domainsMap = _asMap(raw['domains']) ?? const {};

    final findings = <MobsfFinding>[];
    void _addFindings(String key, String categoryLabel) {
      final list = appsec[key];
      if (list is! List) return;
      for (final item in list) {
        final map = _asMap(item);
        if (map == null) continue;
        findings.add(
          MobsfFinding(
            title: _asString(map['title']) ?? '',
            section: _asString(map['section']) ?? '',
            description: _asString(map['description']) ?? '',
            category: categoryLabel,
          ),
        );
      }
    }

    _addFindings('high', 'High');
    _addFindings('warning', 'Medium');
    _addFindings('info', 'Info');
    _addFindings('secure', 'Secure');
    _addFindings('hotspot', 'Hotspot');

    final domains = <MobsfDomain>[];
    domainsMap.forEach((domain, value) {
      final map = _asMap(value);
      if (map == null) return;
      final geo = _asMap(map['geolocation']) ?? const {};
      domains.add(
        MobsfDomain(
          domain: domain,
          bad: _asString(map['bad']) ?? 'no',
          ofac: _asBool(map['ofac']),
          ip: _asString(geo['ip']),
          countryShort: _asString(geo['country_short']),
          countryLong: _asString(geo['country_long']),
          region: _asString(geo['region']),
          city: _asString(geo['city']),
          latitude: _asString(geo['latitude']),
          longitude: _asString(geo['longitude']),
        ),
      );
    });

    return MobsfReport(
      appName: _asString(raw['app_name']),
      fileName: _asString(raw['file_name']),
      versionName: _asString(raw['version_name']),
      size: _asString(raw['size']),
      title: _asString(raw['title']),
      version: _asString(raw['version']),
      appType: _asString(raw['app_type']),
      md5: _asString(raw['md5']),
      sha1: _asString(raw['sha1']),
      sha256: _asString(raw['sha256']),
      packageName: _asString(raw['package_name']),
      securityScore: _asDouble(appsec['security_score']),
      findings: List.unmodifiable(findings),
      trackers: _asInt(appsec['trackers']),
      totalTrackers: appsec['total_trackers'],
      certificateInfo: _asString(cert['certificate_info']),
      domains: List.unmodifiable(domains),
    );
  }
}


class CapeReport {
  const CapeReport({
    this.debugLog,
    this.debugErrors,
    this.started,
    this.duration,
    this.package,
    this.machineName,
    this.capeVersion,
    this.malscore,
    this.processCount,
    this.networkCount,
    this.signatureCount,
    this.targetMd5,
    required this.rawJson,
  });

  final String? debugLog;
  final List<String>? debugErrors;
  final String? started;
  final String? duration;
  final String? package;
  final String? machineName;
  final String? capeVersion;
  final double? malscore;
  final int? processCount;
  final int? networkCount;
  final int? signatureCount;
  final String? targetMd5;
  final Map<String, dynamic> rawJson;

  bool get isFatal {
    final log = debugLog ?? '';
    if (log.contains('Invalid package type') && log.contains('jar')) return true;
    if (RegExp(r'CuckooPackageError|failed_analysis|analysis failed')
        .hasMatch(log)) {
      return true;
    }
    if (debugErrors != null && debugErrors!.isNotEmpty) return true;
    return false;
  }

  bool get isJarPackageMismatch {
    final log = debugLog ?? '';
    return log.contains('Invalid package type') && log.contains('jar');
  }

  String? get fatalMessage {
    if (debugErrors != null && debugErrors!.isNotEmpty) {
      return debugErrors!.first;
    }
    if (isJarPackageMismatch) {
      return 'ไฟล์ APK ถูกวิเคราะห์เป็น JAR package ซึ่งไม่เหมาะสม กรุณาวิเคราะห์ใหม่ด้วย package type "apk" หรือ "android"';
    }
    final log = debugLog ?? '';
    final cuckoo =
        RegExp(r'CuckooPackageError: (.+?)(?:\n|$)').firstMatch(log);
    if (cuckoo != null) return cuckoo.group(1)?.trim();

    final patterns = [
      'Failed to execute process',
      'Access is denied',
      'Unable to execute the initial process',
      r'Error: \d+',
      'Invalid package type',
    ];
    for (final p in patterns) {
      final match = RegExp(p).firstMatch(log);
      if (match != null) return match.group(0);
    }
    return null;
  }

  List<String> get warnings {
    final log = debugLog ?? '';
    if (log.isEmpty) return const [];
    final out = <String>[];

    final auxPattern = RegExp(
      r'Cannot execute auxiliary module modules\.auxiliary\.(\w+): (.+)',
    );
    for (final match in auxPattern.allMatches(log)) {
      final module = match.group(1) ?? '';
      final detail = match.group(2) ?? '';
      out.add(
        'เริ่มทำงานไม่สำเร็จ ($detail) — เป็นโมดูลเสริม $module ไม่กระทบผลวิเคราะห์หลัก',
      );
    }

    final withoutAux = log.replaceAll(auxPattern, '');
    final hookPattern = RegExp(r'Unable to place hook on ([\w:]+)');
    final seen = <String>{};
    for (final match in hookPattern.allMatches(withoutAux)) {
      final hook = match.group(1);
      if (hook != null && seen.add(hook)) {
        out.add('วาง hook ไม่สำเร็จสำหรับ: $hook');
      }
    }

    return List.unmodifiable(out);
  }

  factory CapeReport.fromMap(Map<String, dynamic> raw) {
    final debug = _asMap(raw['debug']) ?? const {};
    final info = _asMap(raw['info']) ?? const {};
    final machine = _asMap(info['machine']) ?? const {};
    final behavior = _asMap(raw['behavior']) ?? const {};
    final network = _asMap(raw['network']) ?? const {};
    final target = _asMap(raw['target']) ?? const {};
    final file = _asMap(target['file']) ?? const {};

    final errors = debug['errors'];
    List<String>? errorList;
    if (errors is List) {
      errorList = errors.map((e) => e.toString()).toList(growable: false);
    }

    final httpCount = _count(network['http']);
    final dnsCount = _count(network['dns']);

    return CapeReport(
      debugLog: _asString(debug['log']),
      debugErrors: errorList,
      started: _asString(info['started']),
      duration: _asString(info['duration']),
      package: _asString(info['package']),
      machineName: _asString(machine['name']),
      capeVersion: _asString(raw['CAPE']),
      malscore: _asDouble(raw['malscore']),
      processCount: _count(behavior['processes']),
      networkCount: httpCount + dnsCount,
      signatureCount: _count(raw['signatures']),
      targetMd5: _asString(file['md5']),
      rawJson: raw,
    );
  }
}


class ToolReport {
  const ToolReport({
    required this.tool,
    required this.taskId,
    required this.status,
    this.raw,
    this.virustotal,
    this.mobsf,
    this.cape,
  });

  final String tool;
  final String taskId;
  final String status;
  final Map<String, dynamic>? raw;
  final VirusTotalReport? virustotal;
  final MobsfReport? mobsf;
  final CapeReport? cape;

  static ToolReport? parse(
    String tool,
    String taskId,
    String? status,
    Map<String, dynamic>? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return ToolReport(
        tool: tool,
        taskId: taskId,
        status: status ?? '',
        raw: raw,
      );
    }

    final normalised = tool.trim().toLowerCase();
    switch (normalised) {
      case 'virustotal':
        return ToolReport(
          tool: tool,
          taskId: taskId,
          status: status ?? '',
          raw: raw,
          virustotal: VirusTotalReport.fromMap(raw),
        );
      case 'mobsf':
        return ToolReport(
          tool: tool,
          taskId: taskId,
          status: status ?? '',
          raw: raw,
          mobsf: MobsfReport.fromMap(raw),
        );
      case 'cape':
        return ToolReport(
          tool: tool,
          taskId: taskId,
          status: status ?? '',
          raw: raw,
          cape: CapeReport.fromMap(raw),
        );
      default:
        return ToolReport(
          tool: tool,
          taskId: taskId,
          status: status ?? '',
          raw: raw,
        );
    }
  }
}
