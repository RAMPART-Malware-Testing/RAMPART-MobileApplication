import 'dart:io';

/// Model สำหรับ Upload File Request
class FileUploadRequest {
  final File file;
  final String fileName;
  final bool isPublic;
  final String? description;

  FileUploadRequest({
    required this.file,
    required this.fileName,
    this.isPublic = false, // Default เป็น private
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'is_public': isPublic,
      if (description != null) 'description': description,
    };
  }
}

/// Model สำหรับ Upload File Response
class FileUploadResponse {
  final String fileId;
  final String fileName;
  final String status;
  final bool isPublic;
  final String uploadedAt;
  final int fileSize;
  final String? message;

  FileUploadResponse({
    required this.fileId,
    required this.fileName,
    required this.status,
    required this.isPublic,
    required this.uploadedAt,
    required this.fileSize,
    this.message,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      fileId: json['file_id'] ?? '',
      fileName: json['file_name'] ?? '',
      status: json['status'] ?? 'pending',
      isPublic: json['is_public'] ?? false,
      uploadedAt: json['uploaded_at'] ?? '',
      fileSize: json['file_size'] ?? 0,
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'file_name': fileName,
      'status': status,
      'is_public': isPublic,
      'uploaded_at': uploadedAt,
      'file_size': fileSize,
      if (message != null) 'message': message,
    };
  }
}

/// Model สำหรับแสดงข้อมูลไฟล์ที่เลือก
class SelectedFileInfo {
  final String name;
  final String path;
  final int size;
  final String? extension;

  SelectedFileInfo({
    required this.name,
    required this.path,
    required this.size,
    this.extension,
  });

  String get sizeInMB => (size / (1024 * 1024)).toStringAsFixed(2);

  String get displaySize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
