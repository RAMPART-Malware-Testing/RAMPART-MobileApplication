import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:rampart/services/network_monitor_service.dart';
import 'package:rampart/services/tab_cache.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final monitor = Get.find<NetworkMonitorService>();

    return Obx(() {
      if (monitor.isOnline.value) return const SizedBox.shrink();

      return ValueListenableBuilder<DateTime?>(
        valueListenable: TabCache.instance.lastSyncedAt,
        builder: (context, syncedAt, _) => _buildBanner(context, syncedAt),
      );
    });
  }

  Widget _buildBanner(BuildContext context, DateTime? syncedAt) {
    final theme = Theme.of(context);
    final detail = syncedAt == null
        ? 'ข้อมูลที่แสดงเป็นข้อมูลที่บันทึกไว้ล่าสุด'
        : 'ข้อมูลที่แสดงเป็นข้อมูลล่าสุดเมื่อ ${_formatTime(syncedAt)} น.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.amber.shade300),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ไม่ได้เชื่อมต่ออินเทอร์เน็ต',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade200,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime value) =>
      DateFormat('HH:mm').format(value.toLocal());
}
