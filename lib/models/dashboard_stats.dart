class DashboardStats {
  final FileStats publicFiles;
  final FileStats myFiles;
  final int totalMembers;
  final List<MalwareType> topMalwareTypes;
  final double averageRiskScore;

  DashboardStats({
    required this.publicFiles,
    required this.myFiles,
    required this.totalMembers,
    required this.topMalwareTypes,
    required this.averageRiskScore,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      publicFiles: FileStats.fromJson(json['public_files'] ?? {}),
      myFiles: FileStats.fromJson(json['my_files'] ?? {}),
      totalMembers: json['total_members'] ?? 0,
      topMalwareTypes: (json['top_malware_types'] as List?)
              ?.map((item) => MalwareType.fromJson(item))
              .toList() ??
          [],
      averageRiskScore: (json['average_risk_score'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'public_files': publicFiles.toJson(),
      'my_files': myFiles.toJson(),
      'total_members': totalMembers,
      'top_malware_types': topMalwareTypes.map((e) => e.toJson()).toList(),
      'average_risk_score': averageRiskScore,
    };
  }
}

class FileStats {
  final int success;
  final int pending;
  final int failed;

  FileStats({
    required this.success,
    required this.pending,
    required this.failed,
  });

  int get total => success + pending + failed;

  factory FileStats.fromJson(Map<String, dynamic> json) {
    return FileStats(
      success: json['success'] ?? 0,
      pending: json['pending'] ?? 0,
      failed: json['failed'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'pending': pending,
      'failed': failed,
    };
  }
}

class MalwareType {
  final String name;
  final int count;
  final double percentage;

  MalwareType({
    required this.name,
    required this.count,
    required this.percentage,
  });

  factory MalwareType.fromJson(Map<String, dynamic> json) {
    return MalwareType(
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'count': count,
      'percentage': percentage,
    };
  }
}
