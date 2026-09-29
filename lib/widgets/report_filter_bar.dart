import 'package:flutter/material.dart';

import 'analysis_components.dart';

class ReportFilterOption {
  const ReportFilterOption(this.value, this.label);

  final String value;
  final String label;
}

/// ตัวเลือกตัวกรองของหน้ารายงาน — ใช้ร่วมกันทั้งแท็บ Reports (รายงานของฉัน)
/// และหน้า Public Reports ค่าและลำดับต้องเหมือนกันทั้งสองหน้า
const List<ReportFilterOption> kStatusFilters = [
  ReportFilterOption('', 'ทั้งหมด'),
  ReportFilterOption('success', 'สำเร็จ'),
  ReportFilterOption('processing', 'กำลังวิเคราะห์'),
  ReportFilterOption('failed', 'ไม่สำเร็จ'),
  ReportFilterOption('pending', 'รอดำเนินการ'),
];

const List<String> kFileTypes = [
  'apk',
  'exe',
  'msi',
  'bat',
  'dmg',
  'ipa',
  'zip',
];

const List<ReportFilterOption> kSortOptions = [
  ReportFilterOption('created_at', 'วันที่'),
  ReportFilterOption('file_name', 'ชื่อไฟล์'),
  ReportFilterOption('file_size', 'ขนาด'),
  ReportFilterOption('score', 'ความเสี่ยง'),
];

/// ช่องค้นหา — คำค้นถูก debounce ที่หน้าจอเรียกใช้ ไม่ใช่ที่นี่
class ReportSearchField extends StatelessWidget {
  const ReportSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.hasQuery,
    this.hintText = 'ค้นหาด้วยชื่อไฟล์ หรือ Task ID...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool hasQuery;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontFamily: 'Kanit', color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'Kanit',
          color: AnalysisColors.textMuted,
        ),
        prefixIcon: const Icon(Icons.search, color: AnalysisColors.cyan),
        suffixIcon: !hasQuery
            ? null
            : IconButton(
                tooltip: 'ล้างคำค้นหา',
                icon: const Icon(
                  Icons.close,
                  color: AnalysisColors.textSecondary,
                ),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: AnalysisColors.surface.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnalysisColors.cyan),
        ),
      ),
    );
  }
}

/// แถบตัวกรองสามตัว (สถานะ / ประเภทไฟล์ / เรียงตาม) แบบชิปที่เปิดเมนูได้
///
/// เดิมกระจายเป็นชิป 17 ปุ่ม กินพื้นที่เกือบครึ่งจอทั้งที่ค่าส่วนใหญ่ยังเป็นค่าเริ่มต้น
/// ตอนนี้แต่ละปุ่มบอกค่าที่ใช้อยู่ในตัว แล้วเปิดเมนูให้เลือก ส่วนปุ่มที่ถูก
/// เปลี่ยนจะติดสีให้เห็นว่ากรองอยู่
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.status,
    required this.onStatus,
    required this.fileType,
    required this.onFileType,
    required this.sortField,
    required this.sortDirection,
    required this.onSort,
  });

  final String status;
  final ValueChanged<String> onStatus;
  final String fileType;
  final ValueChanged<String> onFileType;
  final String sortField;
  final int sortDirection;
  final ValueChanged<ReportFilterOption> onSort;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          _buildStatusPill(),
          const SizedBox(width: 8),
          _buildFileTypePill(),
          const SizedBox(width: 8),
          _buildSortPill(),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    final current = kStatusFilters.firstWhere(
      (option) => option.value == status,
      orElse: () => kStatusFilters.first,
    );
    return PopupMenuButton<ReportFilterOption>(
      tooltip: 'กรองตามสถานะ',
      color: AnalysisColors.surfaceElevated,
      onSelected: (option) => onStatus(option.value),
      itemBuilder: (context) => [
        for (final option in kStatusFilters)
          _menuItem(option, option.value == status),
      ],
      child: _pillShell(
        text: 'สถานะ: ${current.label}',
        isActive: status.isNotEmpty,
      ),
    );
  }

  Widget _buildFileTypePill() {
    return PopupMenuButton<ReportFilterOption>(
      tooltip: 'กรองตามประเภทไฟล์',
      color: AnalysisColors.surfaceElevated,
      onSelected: (option) => onFileType(option.value),
      itemBuilder: (context) => [
        _menuItem(const ReportFilterOption('', 'ทั้งหมด'), fileType.isEmpty),
        for (final type in kFileTypes)
          _menuItem(ReportFilterOption(type, type.toUpperCase()), fileType == type),
      ],
      child: _pillShell(
        text: 'ประเภท: ${fileType.isEmpty ? 'ทั้งหมด' : fileType.toUpperCase()}',
        isActive: fileType.isNotEmpty,
      ),
    );
  }

  /// ปุ่มเรียงลำดับ — แตะรายการที่เลือกอยู่อีกครั้งเพื่อสลับทิศทาง
  Widget _buildSortPill() {
    final current = kSortOptions.firstWhere(
      (option) => option.value == sortField,
      orElse: () => kSortOptions.first,
    );
    final arrow = sortDirection == 1 ? '↑' : '↓';

    return PopupMenuButton<ReportFilterOption>(
      tooltip: 'เรียงลำดับ',
      color: AnalysisColors.surfaceElevated,
      onSelected: onSort,
      itemBuilder: (context) => [
        for (final option in kSortOptions)
          _menuItem(
            option,
            option.value == sortField,
            suffix: option.value == sortField
                ? '$arrow ${sortDirection == 1 ? 'เก่าสุดก่อน' : 'ใหม่สุดก่อน'}'
                : null,
          ),
      ],
      child: _pillShell(
        text: 'เรียงตาม: ${current.label} $arrow',
        isActive: sortField != 'created_at' || sortDirection != -1,
      ),
    );
  }

  PopupMenuItem<ReportFilterOption> _menuItem(
    ReportFilterOption option,
    bool selected, {
    String? suffix,
  }) {
    return PopupMenuItem<ReportFilterOption>(
      value: option,
      height: 40,
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.check_box_outline_blank,
            size: 16,
            color: selected ? AnalysisColors.cyan : AnalysisColors.textMuted,
          ),
          const SizedBox(width: 10),
          // ข้อความเมนูบางรายการยาวมาก (เช่น "ความเสี่ยง ↓ ใหม่สุดก่อน")
          // บนจอแคบจะล้นเมนูออกไปนอกจอ — ยอมให้ตัดท้ายแทนการล้น
          Expanded(
            child: Text(
              suffix == null ? option.label : '${option.label} · $suffix',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AnalysisColors.cyan
                    : AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillShell({required String text, required bool isActive}) {
    final color = isActive ? AnalysisColors.cyan : AnalysisColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? AnalysisColors.cyan.withValues(alpha: 0.14)
            : AnalysisColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? AnalysisColors.cyan.withValues(alpha: 0.5)
              : AnalysisColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.expand_more, size: 16, color: color),
        ],
      ),
    );
  }
}
