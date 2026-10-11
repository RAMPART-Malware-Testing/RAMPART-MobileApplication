library;


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


class PasswordHistoryEntry {
  final String id;
  final String? ip;
  final String? userAgent;
  final DateTime? createdAt;

  PasswordHistoryEntry({
    required this.id,
    this.ip,
    this.userAgent,
    this.createdAt,
  });

  factory PasswordHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PasswordHistoryEntry(
      id: _asString(json['id']) ?? '',
      ip: _asString(json['ip']),
      userAgent: _asString(json['user_agent']),
      createdAt: _asDate(json['created_at']),
    );
  }
}

class PasswordHistoryResult {
  final bool success;
  final List<PasswordHistoryEntry> entries;
  final String message;
  final int status;

  PasswordHistoryResult({
    required this.success,
    this.entries = const [],
    this.message = '',
    this.status = 0,
  });

  factory PasswordHistoryResult.fromJson(Map<String, dynamic> json) {
    final items = <PasswordHistoryEntry>[];
    final rawList = json['data'];
    if (rawList is List) {
      for (final entry in rawList) {
        if (entry is Map) {
          items.add(
            PasswordHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    return PasswordHistoryResult(
      success: json['success'] == true,
      entries: items,
      message: _asString(json['message']) ?? '',
      status: json['status'] is int ? json['status'] as int : 0,
    );
  }

  factory PasswordHistoryResult.failure(String message, {int status = 0}) =>
      PasswordHistoryResult(success: false, message: message, status: status);
}


class NotificationCountsResult {
  final bool success;
  final int reports;
  final int publicCount;
  final String message;
  final int status;

  NotificationCountsResult({
    required this.success,
    this.reports = 0,
    this.publicCount = 0,
    this.message = '',
    this.status = 0,
  });

  factory NotificationCountsResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    int readCount(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return NotificationCountsResult(
      success: json['success'] == true,
      reports: data is Map ? readCount(data['reports']) : 0,
      publicCount: data is Map ? readCount(data['public']) : 0,
      message: _asString(json['message']) ?? '',
      status: json['status'] is int ? json['status'] as int : 0,
    );
  }

  factory NotificationCountsResult.failure(String message, {int status = 0}) =>
      NotificationCountsResult(
        success: false,
        message: message,
        status: status,
      );
}
