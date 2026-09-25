import 'package:flutter/material.dart';

import '../models/analysis.dart';

class AnalysisColors {
  const AnalysisColors._();

  static const Color background = Color(0xFF050510);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF111827);
  static const Color border = Color(0x1AFFFFFF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color blue = Color(0xFF60A5FA);
  static const Color purple = Color(0xFFA78BFA);
  static const Color waiting = Color(0xFF64748B);
  static const Color running = Color(0xFFF59E0B);
  static const Color completed = Color(0xFF34D399);
  static const Color failed = Color(0xFFF87171);
  static const Color skipped = Color(0xFF475569);

  static Color status(ToolRunStatus status) {
    switch (status) {
      case ToolRunStatus.running:
        return running;
      case ToolRunStatus.completed:
        return completed;
      case ToolRunStatus.failed:
        return failed;
      case ToolRunStatus.skipped:
        return skipped;
      case ToolRunStatus.waiting:
        return waiting;
    }
  }
}

class AnalysisScoreTier {
  const AnalysisScoreTier({
    required this.label,
    required this.textColor,
    required this.barColor,
    required this.borderColor,
    required this.backgroundColor,
  });

  final String label;
  final Color textColor;
  final Color barColor;
  final Color borderColor;
  final Color backgroundColor;

  static AnalysisScoreTier fromScore(num? score) {
    final value = score?.toDouble() ?? 0;
    if (value >= 80) {
      return const AnalysisScoreTier(
        label: 'อันตรายร้ายแรง',
        textColor: Color(0xFFF87171),
        barColor: Color(0xFFEF4444),
        borderColor: Color(0x33EF4444),
        backgroundColor: Color(0x1AEF4444),
      );
    }
    if (value >= 60) {
      return const AnalysisScoreTier(
        label: 'อันตราย',
        textColor: Color(0xFFFB923C),
        barColor: Color(0xFFF97316),
        borderColor: Color(0x33F97316),
        backgroundColor: Color(0x1AF97316),
      );
    }
    if (value >= 30) {
      return const AnalysisScoreTier(
        label: 'ความเสี่ยงปานกลาง',
        textColor: Color(0xFFFBBF24),
        barColor: Color(0xFFF59E0B),
        borderColor: Color(0x33F59E0B),
        backgroundColor: Color(0x1AF59E0B),
      );
    }
    return const AnalysisScoreTier(
      label: 'ปลอดภัย',
      textColor: Color(0xFF34D399),
      barColor: Color(0xFF10B981),
      borderColor: Color(0x3310B981),
      backgroundColor: Color(0x1A10B981),
    );
  }

  static AnalysisScoreTier fromRisk(String? risk) {
    switch (risk?.trim().toLowerCase()) {
      case 'high':
        return fromScore(60);
      case 'severe':
      case 'critical':
        return fromScore(80);
      case 'medium':
      case 'caution':
        return fromScore(30);
      case 'low':
        return fromScore(0);
      default:
        return fromScore(null);
    }
  }
}

String analysisToolLabel(String tool) {
  switch (tool) {
    case 'virustotal':
      return 'VirusTotal';
    case 'mobsf':
      return 'MobSF';
    case 'cape':
      return 'CAPE';
    case 'rampart_ai':
    case 'rampartai':
    case 'rampart':
      return 'RampartAI';
    case 'gemini':
      return 'Gemini AI';
    default:
      return tool;
  }
}

IconData analysisToolIcon(String tool) {
  switch (tool) {
    case 'virustotal':
      return Icons.shield_outlined;
    case 'mobsf':
      return Icons.description_outlined;
    case 'cape':
      return Icons.insights_outlined;
    case 'rampart_ai':
    case 'rampartai':
    case 'rampart':
      return Icons.hub_outlined;
    case 'gemini':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.analytics_outlined;
  }
}

String? analysisToolAsset(String tool) {
  switch (tool) {
    case 'virustotal':
      return 'assets/images/virustotal_logo.png';
    case 'mobsf':
      return 'assets/images/mobsf_logo.png';
    case 'cape':
      return 'assets/images/cape_logo.png';
    case 'rampart_ai':
    case 'rampartai':
    case 'rampart':
      return 'assets/images/logo_bg_white.png';
    case 'gemini':
      return 'assets/images/gemini_logo_bg.png';
    default:
      return null;
  }
}

String analysisStatusLabel(ToolRunStatus status) {
  switch (status) {
    case ToolRunStatus.waiting:
      return 'รอดำเนินการ';
    case ToolRunStatus.running:
      return 'กำลังทำงาน';
    case ToolRunStatus.completed:
      return 'เสร็จสมบูรณ์';
    case ToolRunStatus.failed:
      return 'ล้มเหลว';
    case ToolRunStatus.skipped:
      return 'ข้าม';
  }
}

ToolRunStatus deriveAnalysisStageStatus(Iterable<ToolRunStatus> statuses) {
  final values = statuses.toList(growable: false);
  if (values.isEmpty ||
      values.every((status) => status == ToolRunStatus.waiting)) {
    return ToolRunStatus.waiting;
  }
  if (values.any((status) => status == ToolRunStatus.running)) {
    return ToolRunStatus.running;
  }
  if (values.any((status) => status == ToolRunStatus.completed)) {
    return ToolRunStatus.completed;
  }
  if (values.every((status) => status == ToolRunStatus.skipped)) {
    return ToolRunStatus.skipped;
  }
  if (values.every(
    (status) =>
        status == ToolRunStatus.failed || status == ToolRunStatus.skipped,
  )) {
    return ToolRunStatus.failed;
  }
  return ToolRunStatus.waiting;
}

class AnalysisStatusBadge extends StatelessWidget {
  const AnalysisStatusBadge({
    super.key,
    required this.status,
    this.label,
    this.compact = false,
  });

  final ToolRunStatus status;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AnalysisColors.status(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label ?? analysisStatusLabel(status),
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisScoreBar extends StatelessWidget {
  const AnalysisScoreBar({
    super.key,
    required this.score,
    this.height = 6,
    this.backgroundColor = const Color(0xFF334155),
  });

  final num? score;
  final double height;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final value = ((score ?? 0).toDouble() / 100).clamp(0.0, 1.0);
    final tier = AnalysisScoreTier.fromScore(score);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: const Duration(milliseconds: 500),
        builder: (context, current, child) {
          return LinearProgressIndicator(
            value: current,
            minHeight: height,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(tier.barColor),
          );
        },
      ),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  const AnalysisCard({
    super.key,
    required this.child,
    this.status,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final ToolRunStatus? status;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final statusColor = status == null
        ? AnalysisColors.border
        : AnalysisColors.status(status!).withValues(alpha: 0.28);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AnalysisColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
        gradient: status == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AnalysisColors.status(status!).withValues(alpha: 0.08),
                  AnalysisColors.surface.withValues(alpha: 0.72),
                ],
              ),
      ),
      child: child,
    );
  }
}

class AnalysisSectionTitle extends StatelessWidget {
  const AnalysisSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AnalysisColors.textMuted,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              color: AnalysisColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class AnalysisToolLogo extends StatelessWidget {
  const AnalysisToolLogo({super.key, required this.tool, this.size = 24});

  final String tool;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = analysisToolAsset(tool);
    if (asset == null) {
      return Icon(
        analysisToolIcon(tool),
        size: size,
        color: AnalysisColors.cyan,
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          Icon(analysisToolIcon(tool), size: size, color: AnalysisColors.cyan),
    );
  }
}

class AnalysisMetricTile extends StatelessWidget {
  const AnalysisMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AnalysisColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AnalysisColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AnalysisColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class AnalysisToolCard extends StatelessWidget {
  const AnalysisToolCard({
    super.key,
    required this.tool,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.child,
    this.message,
    this.danger = false,
  });

  final String tool;
  final String title;
  final String subtitle;
  final ToolRunStatus status;
  final Widget child;
  final String? message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final statusColor = danger
        ? AnalysisColors.failed
        : AnalysisColors.status(status);
    return AnalysisCard(
      status: status,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: AnalysisToolLogo(tool: tool, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AnalysisColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Kanit',
                        fontSize: 10.5,
                        color: AnalysisColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnalysisStatusBadge(status: status, compact: true),
            ],
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              message!,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class AnalysisPipelineStage extends StatelessWidget {
  const AnalysisPipelineStage({
    super.key,
    required this.title,
    required this.status,
    required this.children,
    this.inputLabel,
  });

  final String title;
  final ToolRunStatus status;
  final List<Widget> children;
  final String? inputLabel;

  @override
  Widget build(BuildContext context) {
    return AnalysisCard(
      status: status,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AnalysisColors.textMuted,
                  ),
                ),
              ),
              if (inputLabel != null)
                Text(
                  inputLabel!,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 10,
                    color: AnalysisColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
