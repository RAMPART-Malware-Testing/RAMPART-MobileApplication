import 'package:flutter/material.dart';

import '../../models/tool_reports.dart';
import '../analysis_components.dart';

class MobsfReportWidget extends StatelessWidget {
  const MobsfReportWidget({super.key, required this.report});

  final MobsfReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetadata(),
        const SizedBox(height: 12),
        _buildScore(),
        const SizedBox(height: 12),
        _buildSeverityDistribution(),
        const SizedBox(height: 12),
        _buildTrackers(),
        const SizedBox(height: 12),
        _buildCertificate(),
        const SizedBox(height: 12),
        _buildDomains(),
        const SizedBox(height: 12),
        _buildFindings(),
      ],
    );
  }

  Widget _buildMetadata() {
    final name = report.appName?.isNotEmpty == true
        ? report.appName
        : report.fileName ?? '-';
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name!,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
              ),
              if (report.version?.isNotEmpty == true)
                Text(
                  'v${report.version}',
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (report.size != null) _metaRow('Size', report.size!),
          if (report.title != null) _metaRow('Title', report.title!),
          if (report.versionName != null)
            _metaRow('Version Name', report.versionName!),
          if (report.appType != null) _metaRow('App Type', report.appType!),
          if (report.packageName != null)
            _metaRow('Package', report.packageName!),
          if (report.md5 != null) _hashRow('MD5', report.md5!),
          if (report.sha1 != null) _hashRow('SHA1', report.sha1!),
          if (report.sha256 != null) _hashRow('SHA256', report.sha256!),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 9,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScore() {
    final score = report.displayScore;
    final color = _scoreColor(score);
    final risk = _riskLabel(score);

    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Security Score'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const Text(
                ' / 100',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 14,
                  color: AnalysisColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  risk,
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnalysisScoreBar(score: score.toDouble()),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score < 30) return const Color(0xFFF87171);
    if (score < 40) return const Color(0xFFFBBF24);
    if (score < 60) return const Color(0xFF60A5FA);
    return const Color(0xFF34D399);
  }

  String _riskLabel(int score) {
    if (score < 30) return 'Critical Risk';
    if (score < 40) return 'High Risk';
    if (score < 60) return 'Medium Risk';
    return 'Low Risk';
  }

  Widget _buildSeverityDistribution() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Severity Distribution'),
          const SizedBox(height: 10),
          _severityBar('High', report.high, const Color(0xFFF87171)),
          _severityBar('Medium', report.medium, const Color(0xFFFBBF24)),
          _severityBar('Info', report.info, const Color(0xFF60A5FA)),
          _severityBar('Secure', report.secure, const Color(0xFF34D399)),
        ],
      ),
    );
  }

  Widget _severityBar(String label, int count, Color color) {
    final percent = report.severityPercent(count);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: AnalysisColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackers() {
    final count = report.trackers ?? 0;
    final color = count == 0
        ? const Color(0xFF34D399)
        : count > 4
            ? const Color(0xFFF87171)
            : const Color(0xFF64748B);
    final caption = report.totalTrackers != null
        ? 'User/Device Trackers'
        : 'Not Scanned';

    return AnalysisCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trackers',
                  style: TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 10,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificate() {
    final info = report.certificateInfo;
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Certificate Information'),
          const SizedBox(height: 10),
          if (info == null || info.isEmpty)
            const Text(
              'ไม่มีข้อมูลใบรับรอง',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            )
          else
            SelectableText(
              info,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10,
                color: AnalysisColors.textPrimary,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDomains() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Domains'),
          const SizedBox(height: 10),
          Row(
            children: [
              _domainStat('Total', report.totalServers, AnalysisColors.cyan),
              _domainStat('Bad', report.badServers, const Color(0xFFF87171)),
              _domainStat(
                'Healthy',
                report.healthyServers,
                const Color(0xFF34D399),
              ),
            ],
          ),
          if (report.domains.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: report.domains.length,
                itemBuilder: (context, index) {
                  final domain = report.domains[index];
                  return _domainCard(domain);
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'ไม่มีข้อมูล domain',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _domainStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AnalysisColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 10,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _domainCard(MobsfDomain domain) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AnalysisColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AnalysisColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  domain.domain,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AnalysisColors.textPrimary,
                  ),
                ),
              ),
              if (domain.bad != 'no')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFF87171).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Bad',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF87171),
                    ),
                  ),
                ),
              if (domain.ofac)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB923C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFFB923C).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'OFAC',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFB923C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (domain.ip != null)
            Text(
              domain.ip!,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10,
                color: AnalysisColors.textSecondary,
              ),
            ),
          if (domain.city != null || domain.region != null)
            Text(
              [domain.city, domain.region]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(', '),
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 10,
                color: AnalysisColors.textSecondary,
              ),
            ),
          if (domain.countryLong != null)
            Text(
              domain.countryLong!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 10,
                color: AnalysisColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFindings() {
    return AnalysisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AnalysisSectionTitle('Security Findings'),
          const SizedBox(height: 10),
          Row(
            children: [
              _findingStat('High', report.high, const Color(0xFFF87171)),
              _findingStat('Medium', report.medium, const Color(0xFFFBBF24)),
              _findingStat('Info', report.info, const Color(0xFF60A5FA)),
              _findingStat('Secure', report.secure, const Color(0xFF34D399)),
              _findingStat('Hotspot', report.hotspot, const Color(0xFFA78BFA)),
            ],
          ),
          if (report.findings.isEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'ไม่พบปัญหาในการวิเคราะห์',
              style: TextStyle(
                fontFamily: 'Kanit',
                fontSize: 12,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: report.findings.length,
                itemBuilder: (context, index) =>
                    _findingTile(report.findings[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _findingStat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
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

  Widget _findingTile(MobsfFinding finding) {
    final color = _findingColor(finding.category);
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: AnalysisColors.cyan,
        collapsedIconColor: AnalysisColors.textSecondary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                finding.category,
                style: TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                finding.title,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 11,
                  color: AnalysisColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        subtitle: finding.section.isNotEmpty
            ? Text(
                finding.section,
                style: const TextStyle(
                  fontFamily: 'Kanit',
                  fontSize: 9,
                  color: AnalysisColors.textSecondary,
                ),
              )
            : null,
        children: [
          if (finding.description.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AnalysisColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                finding.description,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 10,
                  color: AnalysisColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _findingColor(String category) {
    switch (category) {
      case 'High':
        return const Color(0xFFF87171);
      case 'Medium':
        return const Color(0xFFFBBF24);
      case 'Info':
        return const Color(0xFF60A5FA);
      case 'Secure':
        return const Color(0xFF34D399);
      case 'Hotspot':
        return const Color(0xFFA78BFA);
      default:
        return AnalysisColors.textSecondary;
    }
  }
}
