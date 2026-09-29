/// โมเดลข้อมูลโปรไฟล์ผู้ใช้และประวัติการใช้งาน
library;

// ---------- helper สำหรับ parse แบบทนทาน ----------

String? _asString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

DateTime? _asDate(dynamic v) {
  final s = _asString(v);
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s.trim());
}

// ---------- โปรไฟล์ผู้ใช้ ----------

class RampartProfile {
  final String uid;
  final String username;
  final String email;
  final String? avatarUrl;
  final String role;
  final String status;
  final DateTime? createdAt;

  RampartProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.role = 'user',
    this.status = '',
    this.createdAt,
  });

  factory RampartProfile.fromJson(Map<String, dynamic> json) {
    return RampartProfile(
      uid: _asString(json['uid']) ?? '',
      username: _asString(json['username']) ?? '',
      email: _asString(json['email']) ?? '',
      avatarUrl: _asString(json['avatar_url']),
      role: _asString(json['role']) ?? 'user',
      status: _asString(json['status']) ?? '',
      createdAt: _asDate(json['created_at']),
    );
  }

  String get roleLabel {
    switch (role.trim().toLowerCase()) {
      case 'user':
        return 'สมาชิกทั่วไป';
      case 'admin':
        return 'ผู้ดูแลระบบ';
      case 'master':
        return 'ผู้ดูแลระบบสูงสุด';
      default:
        return role;
    }
  }
}

class ProfileResult {
  final bool success;
  final RampartProfile? profile;
  final String message;
  final int status;

  ProfileResult({
    required this.success,
    this.profile,
    this.message = '',
    this.status = 0,
  });

  factory ProfileResult.fromJson(Map<String, dynamic> json) {
    final dataMap = json['data'];
    return ProfileResult(
      success: json['success'] == true,
      profile: dataMap is Map
          ? RampartProfile.fromJson(Map<String, dynamic>.from(dataMap))
          : null,
      message: _asString(json['message']) ?? '',
      status: json['status'] is int ? json['status'] as int : 0,
    );
  }

  factory ProfileResult.failure(String message, {int status = 0}) =>
      ProfileResult(success: false, message: message, status: status);
}

// ---------- ประวัติการเข้าสู่ระบบ ----------

class LoginHistoryEntry {
  final String id;
  final String? provider;
  final String? ip;
  final String? userAgent;
  final String? status;
  final DateTime? createdAt;

  LoginHistoryEntry({
    required this.id,
    this.provider,
    this.ip,
    this.userAgent,
    this.status,
    this.createdAt,
  });

  factory LoginHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoginHistoryEntry(
      id: _asString(json['id']) ?? '',
      provider: _asString(json['provider']),
      ip: _asString(json['ip']),
      userAgent: _asString(json['user_agent']),
      status: _asString(json['status']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

class LoginHistoryResult {
  final bool success;
  final List<LoginHistoryEntry> entries;
  final String message;
  final int status;

  LoginHistoryResult({
    required this.success,
    this.entries = const [],
    this.message = '',
    this.status = 0,
  });

  factory LoginHistoryResult.fromJson(Map<String, dynamic> json) {
    final items = <LoginHistoryEntry>[];
    final rawList = json['data'];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is Map) {
          items.add(LoginHistoryEntry.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return LoginHistoryResult(
      success: json['success'] == true,
      entries: items,
      message: _asString(json['message']) ?? '',
      status: json['status'] is int ? json['status'] as int : 0,
    );
  }

  factory LoginHistoryResult.failure(String message, {int status = 0}) =>
      LoginHistoryResult(success: false, message: message, status: status);
}

// ---------- ประวัติการดาวน์โหลด ----------

class DownloadHistoryEntry {
  final String id;
  final String? fileName;
  final String? tool;
  final String? md5;
  final DateTime? createdAt;

  DownloadHistoryEntry({
    required this.id,
    this.fileName,
    this.tool,
    this.md5,
    this.createdAt,
  });

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryEntry(
      id: _asString(json['id']) ?? '',
      fileName: _asString(json['file_name']),
      tool: _asString(json['tool']),
      md5: _asString(json['md5']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

class DownloadHistoryResult {
  final bool success;
  final List<DownloadHistoryEntry> entries;
  final String message;
  final int status;

  DownloadHistoryResult({
    required this.success,
    this.entries = const [],
    this.message = '',
    this.status = 0,
  });

  factory DownloadHistoryResult.fromJson(Map<String, dynamic> json) {
    final items = <DownloadHistoryEntry>[];
    final rawList = json['data'];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is Map) {
          items.add(DownloadHistoryEntry.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return DownloadHistoryResult(
      success: json['success'] == true,
      entries: items,
      message: _asString(json['message']) ?? '',
      status: json['status'] is int ? json['status'] as int : 0,
    );
  }

  factory DownloadHistoryResult.failure(String message, {int status = 0}) =>
      DownloadHistoryResult(success: false, message: message, status: status);
}
