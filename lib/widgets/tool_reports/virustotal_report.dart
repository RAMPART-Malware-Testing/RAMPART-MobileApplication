import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/tool_reports.dart';
import '../analysis_components.dart';

class VirusTotalReportWidget extends StatefulWidget {
  const VirusTotalReportWidget({super.key, required this.report});

  final VirusTotalReport report;

  @override
  State<VirusTotalReportWidget> createState() => _VirusTotalReportWidgetState();
}

class _VirusTotalReportWidgetState extends State<VirusTotalReportWidget> {
  String _query = '';
  int _tab = 0; // 0 = Detection, 1 = Details

  static const _maliciousColor = Color(0xFFF87171);
  static const _suspiciousColor = Color(0xFFFBBF24);
  static const _undetectedColor = Color(0xFF34D399);
  static const _timeoutColor = Color(0xFFFB923C);
  static const _unsupportedColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStats(),
        const SizedBox(height: 16),
        _buildSearchAndTabs(),
        const SizedBox(height: 12),
        if (_tab == 0) _buildDetection() else _buildDetails(),
      ],
    );
  }

  Widget _buildStats() {
    return AnalysisCard(
      child: Row(
        children: [
          _statTile('Malicious', widget.report.malicious, _maliciousColor),
          _statTile('Suspicious', widget.report.suspicious, _suspiciousColor),
          _statTile('Undetected', widget.report.undetected, _undetectedColor),
          _statTile('Timeout', widget.report.timeout, _timeoutColor),
          _statTile('Unsupported', widget.report.unsupported, _unsupportedColor),
        ],
      ),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 9,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndTabs() {
    return AnalysisCard(
      child: Column(
        children: [
          TextField(
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              color: AnalysisColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'ค้นหาเครื่องมือตรวจจับ...',
              hintStyle: const TextStyle(
                fontFamily: 'Kanit',
                color: AnalysisColors.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AnalysisColors.cyan,
                size: 20,
              ),
              filled: true,
              fillColor: AnalysisColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tabChoice('Detection', 0),
              const SizedBox(width: 8),
              _tabChoice('Details', 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabChoice(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AnalysisColors.cyan.withValues(alpha: 0.15)
                : AnalysisColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AnalysisColors.cyan.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AnalysisColors.cyan : AnalysisColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetection() {
    final filtered = widget.report.whereEngine(_query);
    if (filtered.isEmpty) {
      return AnalysisCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _query.isEmpty
                  ? 'ไม่มีข้อมูลการตรวจจาก engine'
                  : 'ไม่พบ engine ที่ตรงกับการค้นหา',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final grouped = widget.report.grouped();
    return AnalysisCard(
      child: SizedBox(
        height: 400,
        child: ListView.builder(
          itemCount: grouped.length,
          itemBuilder: (context, groupIndex) {
            final group = grouped[groupIndex];
            final engines = group.value
                .where(
                  (e) =>
                      _query.isEmpty ||
                      e.engine.toLowerCase().contains(_query.toLowerCase()),
                )
                .toList(growable: false);
            if (engines.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (groupIndex > 0) const SizedBox(height: 12),
                Text(
                  '${_categoryLabel(group.key)} (${engines.length})',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _categoryColor(group.key),
                  ),
                ),
                const SizedBox(height: 6),
                for (final engine in engines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            engine.engine,
                            style: const TextStyle(
                              fontFamily: 'Kanit',
                              fontSize: 11,
                              color: AnalysisColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          engine.result.isEmpty
                              ? _categoryFallback(group.key)
                              : engine.result,
                          style: const TextStyle(
                            fontFamily: 'Courier New',
                            fontSize: 10,
                            color: AnalysisColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final json = widget.report.attributesJson;
    if (json == null || json.isEmpty) {
      return const AnalysisCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ไม่มีข้อมูล attributes',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final encoder = const JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(json);

    return AnalysisCard(
      child: SizedBox(
        height: 400,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'malicious':
        return 'Malicious';
      case 'suspicious':
        return 'Suspicious';
      case 'undetected':
        return 'Undetected';
      case 'timeout':
        return 'Timeout';
      case 'type-unsupported':
        return 'Unsupported';
      default:
        return category;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'malicious':
        return _maliciousColor;
      case 'suspicious':
        return _suspiciousColor;
      case 'undetected':
        return _undetectedColor;
      case 'timeout':
        return _timeoutColor;
      case 'type-unsupported':
        return _unsupportedColor;
      default:
        return AnalysisColors.textSecondary;
    }
  }

  String _categoryFallback(String category) {
    switch (category) {
      case 'malicious':
        return 'Detected';
      case 'suspicious':
        return 'Suspicious';
      case 'undetected':
        return 'Undetected';
      case 'timeout':
        return 'Timeout';
      case 'type-unsupported':
        return 'Unsupported';
      default:
        return '-';
    }
  }
}
