import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/report_download_service.dart';
import 'analysis_components.dart';

class DownloadProgressDialog extends StatelessWidget {
  const DownloadProgressDialog({
    super.key,
    required this.title,
    required this.progress,
  });

  final String title;
  final ValueListenable<DownloadProgress?> progress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AnalysisColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AnalysisColors.border),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Kanit',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AnalysisColors.textPrimary,
          ),
        ),
        content: ValueListenableBuilder<DownloadProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final percent = value?.percent;
            final received = value?.receivedLabel ?? formatBytes(0);
            final total = value?.totalLabel;
            final detail = percent != null
                ? '$percent%  •  $received / $total'
                : 'กำลังรับข้อมูล…  $received';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent == null ? null : percent / 100,
                    minHeight: 8,
                    backgroundColor: AnalysisColors.cyan.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AnalysisColors.cyan),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  detail,
                  style: const TextStyle(
                    fontFamily: 'Kanit',
                    fontSize: 13,
                    color: AnalysisColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DownloadResultDialog extends StatelessWidget {
  const DownloadResultDialog({
    super.key,
    required this.outcome,
    this.onRetry,
  });

  final DownloadOutcome outcome;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final success = outcome.success;
    final color = success ? AnalysisColors.completed : AnalysisColors.failed;

    return AlertDialog(
      backgroundColor: AnalysisColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AnalysisColors.border),
      ),
      title: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              success ? 'ดาวน์โหลดสำเร็จ' : 'ดาวน์โหลดไม่สำเร็จ',
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AnalysisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            success
                ? 'บันทึกไฟล์ ${outcome.fileName ?? 'รายงาน'} '
                      '(${formatBytes(outcome.sizeBytes)}) เรียบร้อยแล้ว'
                : outcome.message,
            style: TextStyle(
              fontFamily: 'Kanit',
              fontSize: 13,
              color: success
                  ? AnalysisColors.textSecondary
                  : AnalysisColors.failed,
            ),
          ),
          if (success && outcome.path != null) ...[
            const SizedBox(height: 10),
            Text(
              outcome.path!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Kanit',
                fontSize: 11,
                color: AnalysisColors.textMuted,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!success && onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AnalysisColors.cyan),
            child: const Text(
              'ลองใหม่',
              style: TextStyle(fontFamily: 'Kanit'),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor:
                success ? AnalysisColors.completed : AnalysisColors.textSecondary,
          ),
          child: const Text(
            'ปิด',
            style: TextStyle(fontFamily: 'Kanit'),
          ),
        ),
      ],
    );
  }
}
